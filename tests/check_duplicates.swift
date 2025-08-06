#!/usr/bin/env swift

import Foundation

// 重复数据检查脚本

struct DuplicateCheckEntry {
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
    let filePath: String
    
    var totalTokens: Int {
        return inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
    
    var dateString: String {
        return String(timestamp.prefix(10))
    }
    
    // 用于去重的唯一标识符
    var uniqueKey: String {
        if let requestId = requestId, !requestId.isEmpty {
            return requestId
        }
        // 如果没有 requestId，使用时间戳+sessionId+token数组合
        return "\(timestamp)_\(sessionId)_\(totalTokens)"
    }
    
    // 内容相同性检查
    var contentHash: String {
        return "\(timestamp)_\(model)_\(inputTokens)_\(outputTokens)_\(cacheCreationTokens)_\(cacheReadTokens)_\(sessionId)_\(messageType)"
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
    
    func toEntry(filePath: String) -> DuplicateCheckEntry? {
        let messageType = type ?? self.messageType ?? ""
        let usageData = usage ?? message?.usage
        
        // 基本过滤
        if messageType == "user" {
            return nil
        }
        
        let modelName = model ?? message?.model ?? "unknown"
        if modelName == "<synthetic>" {
            return nil
        }
        
        let hasUsageData = usageData != nil
        let hasCostData = (cost ?? costUSD ?? 0) > 0
        if !hasUsageData && !hasCostData {
            return nil
        }
        
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        let cacheCreationTokens = usageData?.effectiveCacheCreationTokens ?? 0
        let cacheReadTokens = usageData?.effectiveCacheReadTokens ?? 0
        
        return DuplicateCheckEntry(
            timestamp: timestamp ?? date ?? Date().toISOString(),
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cost: cost ?? costUSD ?? 0,
            sessionId: sessionId ?? "unknown",
            messageType: messageType,
            requestId: requestId ?? messageId ?? id,
            filePath: filePath
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

class DuplicateChecker {
    private let decoder = JSONDecoder()
    
    func analyzeDuplicates(in projectsDirectory: URL) -> [DuplicateCheckEntry] {
        var allEntries: [DuplicateCheckEntry] = []
        
        guard let enumerator = FileManager.default.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("❌ 无法枚举目录: \(projectsDirectory.path)")
            return []
        }
        
        var jsonlFiles: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "jsonl" {
                jsonlFiles.append(fileURL)
            }
        }
        
        print("📁 找到 \(jsonlFiles.count) 个 JSONL 文件")
        
        for fileURL in jsonlFiles {
            let entries = parseFile(at: fileURL)
            allEntries.append(contentsOf: entries)
        }
        
        return allEntries
    }
    
    private func parseFile(at fileURL: URL) -> [DuplicateCheckEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        
        let filePath = fileURL.lastPathComponent
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var entries: [DuplicateCheckEntry] = []
        
        for line in lines {
            if let entry = parseLine(line, filePath: filePath) {
                entries.append(entry)
            }
        }
        
        return entries
    }
    
    private func parseLine(_ line: String, filePath: String) -> DuplicateCheckEntry? {
        guard let jsonData = line.data(using: .utf8),
              let rawEntry = try? decoder.decode(RawJSONLEntry.self, from: jsonData) else {
            return nil
        }
        
        return rawEntry.toEntry(filePath: filePath)
    }
}

func analyzeDuplicates(_ entries: [DuplicateCheckEntry]) {
    print("\n🔍 重复数据分析:")
    print("总条目数: \(entries.count)")
    
    // 按 uniqueKey 分组检查重复
    let groupedByKey = Dictionary(grouping: entries, by: { $0.uniqueKey })
    let duplicatesByKey = groupedByKey.filter { $0.value.count > 1 }
    
    print("按 uniqueKey 分组的重复项: \(duplicatesByKey.count) 组")
    
    var totalDuplicateEntries = 0
    var totalDuplicateTokens = 0
    
    for (key, duplicates) in duplicatesByKey.prefix(10) {
        totalDuplicateEntries += duplicates.count - 1  // 减去1因为第一个不算重复
        let tokensPerEntry = duplicates.first?.totalTokens ?? 0
        totalDuplicateTokens += tokensPerEntry * (duplicates.count - 1)
        
        print("  Key: \(key)")
        print("    重复次数: \(duplicates.count)")
        print("    Tokens per entry: \(formatNumber(tokensPerEntry))")
        print("    涉及文件: \(Set(duplicates.map { $0.filePath }).joined(separator: ", "))")
        print("")
    }
    
    // 按内容哈希分组检查完全相同的条目
    let groupedByContent = Dictionary(grouping: entries, by: { $0.contentHash })
    let duplicatesByContent = groupedByContent.filter { $0.value.count > 1 }
    
    print("按内容哈希分组的重复项: \(duplicatesByContent.count) 组")
    
    // 计算去重后的统计
    let uniqueEntries = Array(groupedByKey.values.map { $0.first! })
    let originalTotalTokens = entries.reduce(0) { $0 + $1.totalTokens }
    let uniqueTotalTokens = uniqueEntries.reduce(0) { $0 + $1.totalTokens }
    
    print("\n📊 去重统计:")
    print("原始数据: \(entries.count) 条, \(formatNumber(originalTotalTokens)) tokens")
    print("去重后: \(uniqueEntries.count) 条, \(formatNumber(uniqueTotalTokens)) tokens")
    print("重复数据: \(entries.count - uniqueEntries.count) 条, \(formatNumber(originalTotalTokens - uniqueTotalTokens)) tokens")
    
    // 查找可能的系统性重复
    let fileGroups = Dictionary(grouping: entries, by: { $0.filePath })
    print("\n📁 文件统计 (前10个最大的文件):")
    for (file, fileEntries) in fileGroups.sorted(by: { $0.value.count > $1.value.count }).prefix(10) {
        let totalTokens = fileEntries.reduce(0) { $0 + $1.totalTokens }
        print("  \(file): \(fileEntries.count) 条, \(formatNumber(totalTokens)) tokens")
    }
}

func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

// 主程序
func main() {
    print("🔍 重复数据检查工具")
    print("============================")
    
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    let claudeDirectory = homeDirectory.appendingPathComponent(".claude")
    let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
    
    guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
        print("❌ 找不到 projects 目录: \(projectsDirectory.path)")
        return
    }
    
    print("📂 项目目录: \(projectsDirectory.path)")
    
    let checker = DuplicateChecker()
    let entries = checker.analyzeDuplicates(in: projectsDirectory)
    
    print("🔄 解析完成")
    
    analyzeDuplicates(entries)
}

main()