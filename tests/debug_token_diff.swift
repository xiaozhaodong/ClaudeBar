#!/usr/bin/env swift

import Foundation

// 用于对比分析的调试脚本

struct DebugUsageEntry {
    let timestamp: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Double
    let sessionId: String
    let messageType: String
    let requestId: String?
    
    var totalTokens: Int {
        return inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
    
    var dateString: String {
        return String(timestamp.prefix(10))
    }
}

struct RawJSONLEntry: Codable {
    let type: String?
    let messageType: String?
    let model: String?
    let usage: UsageData?
    let message: MessageData?
    let cost: Double?
    let costUSD: Double?
    let timestamp: String?
    let sessionId: String?
    let requestId: String?
    let messageId: String?
    let id: String?
    let date: String?
    
    private enum CodingKeys: String, CodingKey {
        case type, model, usage, message, cost, costUSD, timestamp, id, date
        case messageType = "message_type"
        case sessionId = "session_id"
        case requestId = "request_id"
        case messageId = "message_id"
    }
    
    struct UsageData: Codable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?
        let cacheCreationTokens: Int?
        let cacheReadTokens: Int?
        
        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case cacheCreationTokens = "cache_creation_tokens"
            case cacheReadTokens = "cache_read_tokens"
        }
        
        var effectiveCacheCreationTokens: Int {
            return cacheCreationInputTokens ?? cacheCreationTokens ?? 0
        }
        
        var effectiveCacheReadTokens: Int {
            return cacheReadInputTokens ?? cacheReadTokens ?? 0
        }
    }
    
    struct MessageData: Codable {
        let usage: UsageData?
        let model: String?
    }
}

class DebugJSONLParser {
    private let decoder = JSONDecoder()
    
    func parseWithMultipleStrategies(in projectsDirectory: URL) -> (strategy1: [DebugUsageEntry], strategy2: [DebugUsageEntry]) {
        var strategy1Entries: [DebugUsageEntry] = []
        var strategy2Entries: [DebugUsageEntry] = []
        
        guard let enumerator = FileManager.default.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("❌ 无法枚举目录: \(projectsDirectory.path)")
            return ([], [])
        }
        
        var jsonlFiles: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "jsonl" {
                jsonlFiles.append(fileURL)
            }
        }
        
        print("📁 找到 \(jsonlFiles.count) 个 JSONL 文件")
        
        for fileURL in jsonlFiles {
            let (s1, s2) = parseFileWithStrategies(at: fileURL)
            strategy1Entries.append(contentsOf: s1)
            strategy2Entries.append(contentsOf: s2)
        }
        
        return (strategy1Entries, strategy2Entries)
    }
    
    private func parseFileWithStrategies(at fileURL: URL) -> ([DebugUsageEntry], [DebugUsageEntry]) {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return ([], [])
        }
        
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var strategy1: [DebugUsageEntry] = []
        var strategy2: [DebugUsageEntry] = []
        
        for line in lines {
            if let entry1 = parseWithStrategy1(line) {
                strategy1.append(entry1)
            }
            if let entry2 = parseWithStrategy2(line) {
                strategy2.append(entry2)
            }
        }
        
        return (strategy1, strategy2)
    }
    
    // 策略1：严格过滤（类似 ccusage 可能的行为）
    private func parseWithStrategy1(_ line: String) -> DebugUsageEntry? {
        guard let jsonData = line.data(using: .utf8),
              let rawEntry = try? decoder.decode(RawJSONLEntry.self, from: jsonData) else {
            return nil
        }
        
        let messageType = rawEntry.type ?? rawEntry.messageType ?? ""
        let usageData = rawEntry.usage ?? rawEntry.message?.usage
        
        // 严格过滤
        if messageType == "user" {
            return nil  // 过滤用户消息
        }
        
        let modelName = rawEntry.model ?? rawEntry.message?.model ?? "unknown"
        if modelName == "<synthetic>" {
            return nil  // 过滤合成消息
        }
        
        // 必须有使用数据或成本数据
        let hasUsageData = usageData != nil
        let hasCostData = (rawEntry.cost ?? rawEntry.costUSD ?? 0) > 0
        if !hasUsageData && !hasCostData {
            return nil
        }
        
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        let cacheCreationTokens = usageData?.effectiveCacheCreationTokens ?? 0
        let cacheReadTokens = usageData?.effectiveCacheReadTokens ?? 0
        
        return DebugUsageEntry(
            timestamp: rawEntry.timestamp ?? rawEntry.date ?? Date().toISOString(),
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cost: rawEntry.cost ?? rawEntry.costUSD ?? 0,
            sessionId: rawEntry.sessionId ?? "unknown",
            messageType: messageType,
            requestId: rawEntry.requestId ?? rawEntry.messageId ?? rawEntry.id
        )
    }
    
    // 策略2：宽松过滤（可能包含更多数据）
    private func parseWithStrategy2(_ line: String) -> DebugUsageEntry? {
        guard let jsonData = line.data(using: .utf8),
              let rawEntry = try? decoder.decode(RawJSONLEntry.self, from: jsonData) else {
            return nil
        }
        
        let messageType = rawEntry.type ?? rawEntry.messageType ?? ""
        let usageData = rawEntry.usage ?? rawEntry.message?.usage
        let modelName = rawEntry.model ?? rawEntry.message?.model ?? "unknown"
        
        // 只过滤明显无用的数据
        if messageType == "user" || modelName == "<synthetic>" {
            return nil
        }
        
        // 更宽松的过滤条件：任何有token数据的都保留
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        let cacheCreationTokens = usageData?.effectiveCacheCreationTokens ?? 0
        let cacheReadTokens = usageData?.effectiveCacheReadTokens ?? 0
        let cost = rawEntry.cost ?? rawEntry.costUSD ?? 0
        
        // 如果所有数据都是0，才跳过
        if inputTokens == 0 && outputTokens == 0 && cacheCreationTokens == 0 && cacheReadTokens == 0 && cost == 0 {
            return nil
        }
        
        return DebugUsageEntry(
            timestamp: rawEntry.timestamp ?? rawEntry.date ?? Date().toISOString(),
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cost: cost,
            sessionId: rawEntry.sessionId ?? "unknown",
            messageType: messageType,
            requestId: rawEntry.requestId ?? rawEntry.messageId ?? rawEntry.id
        )
    }
}

extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

func calculateTotalTokens(_ entries: [DebugUsageEntry]) -> Int {
    return entries.reduce(0) { $0 + $1.totalTokens }
}

func analyzeFilteringDifferences(_ entries1: [DebugUsageEntry], _ entries2: [DebugUsageEntry]) {
    let total1 = calculateTotalTokens(entries1)
    let total2 = calculateTotalTokens(entries2)
    
    print("\n📊 策略对比分析:")
    print("策略1 (严格过滤): \(entries1.count) 条记录, \(formatNumber(total1)) tokens")
    print("策略2 (宽松过滤): \(entries2.count) 条记录, \(formatNumber(total2)) tokens")
    print("差异: \(entries2.count - entries1.count) 条记录, \(formatNumber(total2 - total1)) tokens")
    
    // 分析消息类型分布
    let messageTypes1 = Dictionary(grouping: entries1, by: { $0.messageType })
    let messageTypes2 = Dictionary(grouping: entries2, by: { $0.messageType })
    
    print("\n📋 消息类型分布对比:")
    let allTypes = Set(messageTypes1.keys).union(Set(messageTypes2.keys))
    for type in allTypes.sorted() {
        let count1 = messageTypes1[type]?.count ?? 0
        let count2 = messageTypes2[type]?.count ?? 0
        let tokens1 = messageTypes1[type]?.reduce(0) { $0 + $1.totalTokens } ?? 0
        let tokens2 = messageTypes2[type]?.reduce(0) { $0 + $1.totalTokens } ?? 0
        
        print("  \(type): 策略1=\(count1)条(\(formatNumber(tokens1))tokens), 策略2=\(count2)条(\(formatNumber(tokens2))tokens)")
    }
}

func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

// 主程序
func main() {
    print("🔍 Token 统计差异调试工具")
    print("============================")
    
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    let claudeDirectory = homeDirectory.appendingPathComponent(".claude")
    let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
    
    guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
        print("❌ 找不到 projects 目录: \(projectsDirectory.path)")
        return
    }
    
    print("📂 项目目录: \(projectsDirectory.path)")
    
    let parser = DebugJSONLParser()
    let (strategy1, strategy2) = parser.parseWithMultipleStrategies(in: projectsDirectory)
    
    print("🔄 解析完成")
    
    analyzeFilteringDifferences(strategy1, strategy2)
    
    // 检查是否存在大量缓存 token 的异常数据
    let highCacheEntries = strategy2.filter { $0.cacheCreationTokens > 1000000 || $0.cacheReadTokens > 1000000 }
    if !highCacheEntries.isEmpty {
        print("\n⚠️  发现 \(highCacheEntries.count) 条高缓存 token 记录:")
        for entry in highCacheEntries.prefix(10) {
            print("  \(entry.dateString): 缓存创建=\(formatNumber(entry.cacheCreationTokens)), 缓存读取=\(formatNumber(entry.cacheReadTokens))")
        }
    }
}

main()