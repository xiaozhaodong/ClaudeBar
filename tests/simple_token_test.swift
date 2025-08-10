#!/usr/bin/env swift

import Foundation

// 简化的使用记录模型
struct SimpleUsageEntry {
    let timestamp: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Double
    let sessionId: String
    let projectPath: String
    let requestId: String?
    let messageType: String
    
    var totalTokens: Int {
        return inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
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
    
    func toUsageEntry(projectPath: String) -> SimpleUsageEntry? {
        let messageType = type ?? self.messageType ?? ""
        let usageData = usage ?? message?.usage
        
        // 采用与ccusage更接近的严格过滤策略（不输出过滤日志）
        let hasUsageData = usageData != nil
        let hasCostData = (cost ?? costUSD ?? 0) > 0
        
        // 过滤掉user消息、合成消息和summary消息
        if messageType == "user" || (model ?? message?.model ?? "unknown") == "<synthetic>" {
            return nil
        }
        
        if !hasUsageData && !hasCostData {
            return nil
        }
        
        let modelName = model ?? message?.model ?? "unknown"
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        let cacheCreationTokens = usageData?.effectiveCacheCreationTokens ?? 0
        let cacheReadTokens = usageData?.effectiveCacheReadTokens ?? 0
        
        let calculatedCost = cost ?? costUSD ?? 0
        let uniqueId = requestId ?? messageId ?? id
        let finalTimestamp = timestamp ?? date ?? Date().toISOString()
        
        return SimpleUsageEntry(
            timestamp: finalTimestamp,
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cost: calculatedCost,
            sessionId: sessionId ?? "unknown",
            projectPath: projectPath,
            requestId: uniqueId,
            messageType: messageType
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

// 简化的JSONL解析器
class SimpleJSONLParser {
    private let decoder = JSONDecoder()
    
    func parseJSONLFiles(in projectsDirectory: URL) -> [SimpleUsageEntry] {
        var allEntries: [SimpleUsageEntry] = []
        
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
            let entries = parseJSONLFile(at: fileURL)
            allEntries.append(contentsOf: entries)
        }
        
        return allEntries
    }
    
    private func parseJSONLFile(at fileURL: URL) -> [SimpleUsageEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        
        let projectPath = extractProjectPath(from: fileURL)
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var entries: [SimpleUsageEntry] = []
        
        for line in lines {
            if let entry = parseJSONLine(line, projectPath: projectPath) {
                entries.append(entry)
            }
        }
        
        return entries
    }
    
    private func parseJSONLine(_ line: String, projectPath: String) -> SimpleUsageEntry? {
        guard let jsonData = line.data(using: .utf8) else { return nil }
        
        // 尝试标准解析
        if let rawEntry = try? decoder.decode(RawJSONLEntry.self, from: jsonData) {
            return rawEntry.toUsageEntry(projectPath: projectPath)
        }
        
        return nil
    }
    
    private func extractProjectPath(from fileURL: URL) -> String {
        let pathComponents = fileURL.pathComponents
        
        if let projectsIndex = pathComponents.firstIndex(of: "projects"),
           projectsIndex + 1 < pathComponents.count {
            let projectComponents = Array(pathComponents[(projectsIndex + 1)...])
            let directoryComponents = projectComponents.dropLast()
            
            if !directoryComponents.isEmpty {
                return "/" + directoryComponents.joined(separator: "/")
            }
        }
        
        return fileURL.deletingLastPathComponent().path
    }
}

// 日期过滤 - 支持时区转换
func filterEntriesByDate(_ entries: [SimpleUsageEntry], targetDate: String) -> [SimpleUsageEntry] {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    let localDateFormatter = DateFormatter()
    localDateFormatter.dateFormat = "yyyy-MM-dd"
    localDateFormatter.timeZone = TimeZone.current
    
    return entries.filter { entry in
        // 尝试解析时间戳
        guard let date = formatter.date(from: entry.timestamp) else {
            // 如果解析失败，回退到简单的字符串比较
            let datePrefix = String(entry.timestamp.prefix(10))
            return datePrefix == targetDate
        }
        
        // 转换到本地时区并格式化为日期字符串
        let localDateString = localDateFormatter.string(from: date)
        return localDateString == targetDate
    }
}

// 统计计算
func calculateStatistics(from entries: [SimpleUsageEntry], targetDate: String? = nil) -> (Int, Int, Int, Int, Int, Double) {
    var filteredEntries = entries
    
    if let targetDate = targetDate {
        filteredEntries = filterEntriesByDate(entries, targetDate: targetDate)
    }
    
    guard !filteredEntries.isEmpty else {
        return (0, 0, 0, 0, 0, 0.0)
    }
    
    var totalCost: Double = 0
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCacheCreationTokens: Int = 0
    var totalCacheReadTokens: Int = 0
    
    for entry in filteredEntries {
        totalCost += entry.cost
        totalInputTokens += entry.inputTokens
        totalOutputTokens += entry.outputTokens
        totalCacheCreationTokens += entry.cacheCreationTokens
        totalCacheReadTokens += entry.cacheReadTokens
    }
    
    let totalTokens = totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    
    return (totalInputTokens, totalOutputTokens, totalCacheCreationTokens, totalCacheReadTokens, totalTokens, totalCost)
}

func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

// 主程序
func main() {
    print("🚀 简化的 Claude Token 统计工具")
    print("============================")
    
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    let claudeDirectory = homeDirectory.appendingPathComponent(".claude")
    let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
    
    guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
        print("❌ 找不到 projects 目录: \(projectsDirectory.path)")
        return
    }
    
    print("📂 项目目录: \(projectsDirectory.path)")
    
    let parser = SimpleJSONLParser()
    let entries = parser.parseJSONLFiles(in: projectsDirectory)
    
    print("📈 解析完成，获得 \(entries.count) 条有效记录")
    
    // 获取命令行参数
    let arguments = CommandLine.arguments
    
    if arguments.count > 1 {
        let targetDate = arguments[1]
        
        if targetDate == "total" {
            let (inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens, totalTokens, totalCost) = calculateStatistics(from: entries, targetDate: nil)
            
            print("\n" + String(repeating: "=", count: 80))
            print("📊 总量统计结果")
            print(String(repeating: "=", count: 80))
            print("Input        │ Output       │ Cache Create │ Cache Read   │ Total Tokens │ Cost (USD)")
            print(String(repeating: "-", count: 80))
            print("\(formatNumber(inputTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(outputTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(cacheCreationTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(cacheReadTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(totalTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ $\(String(format: "%.4f", totalCost))")
            print(String(repeating: "=", count: 80))
        } else {
            let (inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens, totalTokens, totalCost) = calculateStatistics(from: entries, targetDate: targetDate)
            
            print("\n" + String(repeating: "=", count: 80))
            print("📊 \(targetDate) 统计结果")
            print(String(repeating: "=", count: 80))
            print("Input        │ Output       │ Cache Create │ Cache Read   │ Total Tokens │ Cost (USD)")
            print(String(repeating: "-", count: 80))
            print("\(formatNumber(inputTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(outputTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(cacheCreationTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(cacheReadTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(totalTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ $\(String(format: "%.4f", totalCost))")
            print(String(repeating: "=", count: 80))
        }
    } else {
        print("📋 使用说明：")
        print("  swift simple_token_test.swift total          # 显示总量统计")
        print("  swift simple_token_test.swift 2025-08-04     # 显示特定日期统计")
    }
}

main()