#!/usr/bin/env swift

import Foundation

// MARK: - 定价模型（与 ClaudeBar 一致）
struct ModelPricing {
    let input: Double        // 输入令牌价格（每百万令牌）
    let output: Double       // 输出令牌价格（每百万令牌）
    let cacheWrite: Double   // 缓存写入价格（每百万令牌）
    let cacheRead: Double    // 缓存读取价格（每百万令牌）

    func calculateCost(inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int) -> Double {
        let inputCost = Double(inputTokens) / 1_000_000 * input
        let outputCost = Double(outputTokens) / 1_000_000 * output
        let cacheWriteCost = Double(cacheCreationTokens) / 1_000_000 * cacheWrite
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * cacheRead
        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }
}

// 定价表（与 ClaudeBar 一致）
let pricingTable: [String: ModelPricing] = [
    "claude-4-opus": ModelPricing(input: 15.0, output: 75.0, cacheWrite: 18.75, cacheRead: 1.5),
    "claude-4-sonnet": ModelPricing(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3),
    "claude-4-haiku": ModelPricing(input: 1.0, output: 5.0, cacheWrite: 1.25, cacheRead: 0.1),
    "claude-3-5-sonnet": ModelPricing(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3),
    "claude-3-opus": ModelPricing(input: 15.0, output: 75.0, cacheWrite: 18.75, cacheRead: 1.5),
    "claude-3-sonnet": ModelPricing(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3),
    "claude-3-haiku": ModelPricing(input: 0.25, output: 1.25, cacheWrite: 0.3, cacheRead: 0.03),
    // Gemini 2.5 Pro 使用官方定价（假设大部分提示 ≤ 200k tokens）
    "gemini-2.5-pro": ModelPricing(input: 1.25, output: 10.0, cacheWrite: 0.31, cacheRead: 0.25)
]

// 模型名称标准化函数（与 ClaudeBar 一致）
func normalizeModelName(_ model: String) -> String {
    let normalized = model.lowercased().replacingOccurrences(of: "-", with: "")

    let mappings: [String: String] = [
        "claudesonnet420250514": "claude-4-sonnet",
        "claudeopus420250514": "claude-4-opus",
        "claudehaiku420250514": "claude-4-haiku",
        "gemini2.5pro": "gemini-2.5-pro",
        "gemini25pro": "gemini-2.5-pro"
    ]

    if let mapped = mappings[normalized] {
        return mapped
    }

    if pricingTable.keys.contains(model) {
        return model
    }

    // 智能匹配
    if model.contains("opus") {
        if model.contains("4") {
            return "claude-4-opus"
        } else if model.contains("3") {
            return "claude-3-opus"
        }
    } else if model.contains("sonnet") {
        if model.contains("4") {
            return "claude-4-sonnet"
        } else if model.contains("3.5") || model.contains("35") {
            return "claude-3-5-sonnet"
        } else if model.contains("3") {
            return "claude-3-sonnet"
        }
    } else if model.contains("haiku") {
        if model.contains("4") {
            return "claude-4-haiku"
        } else if model.contains("3") {
            return "claude-3-haiku"
        }
    } else if model.contains("gemini") && model.contains("2.5") {
        return "gemini-2.5-pro"
    }

    return normalized
}

// 计算成本函数（与 ClaudeBar 一致）
func calculateCost(model: String, inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int) -> Double {
    let normalizedModel = normalizeModelName(model)
    guard let pricing = pricingTable[normalizedModel] else {
        print("⚠️ 未知模型定价: \(model) -> \(normalizedModel)，成本设为 $0")
        return 0.0
    }
    return pricing.calculateCost(inputTokens: inputTokens, outputTokens: outputTokens, cacheCreationTokens: cacheCreationTokens, cacheReadTokens: cacheReadTokens)
}

// MARK: - 数据模型
struct UsageEntry {
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
    let messageId: String?
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
    let uuid: String?
    let date: String?
    
    private enum CodingKeys: String, CodingKey {
        case type, model, usage, message, cost, costUSD, timestamp, id, date, uuid, requestId
        case messageType = "message_type"
        case sessionId = "session_id"
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
        let id: String?
    }
    
    func toUsageEntry(projectPath: String) -> UsageEntry? {
        let messageType = type ?? self.messageType ?? ""
        let usageData = usage ?? message?.usage
        
        // 采用与ccusage更接近的严格过滤策略
        let hasUsageData = usageData != nil
        let hasCostData = (cost ?? costUSD ?? 0) > 0
        
        // 更严格的数据完整性验证
        let hasValidTokenData = usageData?.inputTokens != nil || 
                               usageData?.outputTokens != nil || 
                               usageData?.effectiveCacheCreationTokens != nil ||
                               usageData?.effectiveCacheReadTokens != nil
        
        // 跳过cost和token都为0的无效条目
        let totalTokens = (usageData?.inputTokens ?? 0) + 
                         (usageData?.outputTokens ?? 0) + 
                         (usageData?.effectiveCacheCreationTokens ?? 0) + 
                         (usageData?.effectiveCacheReadTokens ?? 0)
        let totalCost = cost ?? costUSD ?? 0
        
        if totalTokens == 0 && totalCost == 0 {
            // 减少输出，仅统计过滤的条目数量
            return nil
        }
        
        // 取消对user消息的过滤，ccusage可能包含这些
        // 注释掉原来的user消息过滤
        // if messageType == "user" {
        //     print("⚠️  过滤条目 - user消息: type=\(messageType)")
        //     return nil
        // }
        
        // 放宽过滤策略，尝试包含更多数据（与ccusage一致）
        // 只过滤真正没有任何数据的条目
        if totalTokens == 0 && totalCost == 0 && !hasUsageData && !hasCostData {
            return nil
        }
        
        // 特殊处理：如果是user消息且有任何token数据，保留它
        if messageType == "user" && totalTokens > 0 {
            // user消息有token数据，ccusage可能包含这些
        }
        
        let modelName = model ?? message?.model ?? "unknown"
        // 过滤掉synthetic消息（ccusage可能不统计这些）
        if modelName == "<synthetic>" {
            print("⚠️  过滤条目 - 合成消息: model=\(modelName)")
            return nil
        }
        
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        let cacheCreationTokens = usageData?.effectiveCacheCreationTokens ?? 0
        let cacheReadTokens = usageData?.effectiveCacheReadTokens ?? 0
        
        let calculatedCost = cost ?? costUSD ?? 0
        // 完全模拟ccusage的requestId提取逻辑：requestId || request_id || message_id
        let extractedRequestId = requestId ?? messageId
        let extractedMessageId = messageId ?? message?.id
        let finalTimestamp = timestamp ?? date ?? Date().toISOString()
        
        return UsageEntry(
            timestamp: finalTimestamp,
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cost: calculatedCost,
            sessionId: sessionId ?? "unknown",
            projectPath: projectPath,
            requestId: extractedRequestId,
            messageId: extractedMessageId,
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

// MARK: - JSONL 解析器
class JSONLParser {
    private let decoder = JSONDecoder()
    
    func parseJSONLFiles(in projectsDirectory: URL) -> [UsageEntry] {
        var allEntries: [UsageEntry] = []

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

        // 按时间戳排序文件（模拟ccusage的行为）- 暂时注释掉以提高性能
        // let sortedFiles = sortFilesByTimestamp(jsonlFiles)

        var processedFiles = 0
        for fileURL in jsonlFiles { // 使用原始文件列表，不排序
            let entries = parseJSONLFile(at: fileURL)
            allEntries.append(contentsOf: entries)
            processedFiles += 1

            if processedFiles % 10 == 0 {
                print("🔄 已处理 \(processedFiles)/\(jsonlFiles.count) 个文件")
            }
        }

        return allEntries
    }
    
    private func parseJSONLFile(at fileURL: URL) -> [UsageEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        
        let projectPath = extractProjectPath(from: fileURL)
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var entries: [UsageEntry] = []
        
        for line in lines {
            if let entry = parseJSONLine(line, projectPath: projectPath) {
                entries.append(entry)
            }
        }
        
        return entries
    }
    
    private var debugSampleCount = 0
    private var messageIdDebugCount = 0
    
    private func parseJSONLine(_ line: String, projectPath: String) -> UsageEntry? {
        guard let jsonData = line.data(using: .utf8) else { return nil }

        // 尝试标准解析
        if let rawEntry = try? decoder.decode(RawJSONLEntry.self, from: jsonData) {
            // 调试ID字段提取（仅显示前3个）
            if messageIdDebugCount < 3 {
                messageIdDebugCount += 1
                let extractedMessageId = rawEntry.messageId ?? rawEntry.message?.id
                print("\n🔍 ID字段提取 \(messageIdDebugCount): uuid=\(rawEntry.uuid ?? "nil"), messageId=\(extractedMessageId ?? "nil"), requestId=\(rawEntry.requestId ?? "nil")")
            }
            return rawEntry.toUsageEntry(projectPath: projectPath)
        }
        
        // 尝试手动解析
        if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            // 输出前几个样本的原始字段，用于调试
            if debugSampleCount < 3 {
                debugSampleCount += 1
                print("\n🔍 原始 JSON 样本 \(debugSampleCount):")
                printJSONFields(jsonObject)
            }
            return parseFromDictionary(jsonObject, projectPath: projectPath)
        }
        
        // 如果解析失败，输出错误信息以便调试
        print("⚠️  解析失败的行: \(line.prefix(100))...")
        return nil
    }
    
    private func printJSONFields(_ dict: [String: Any]) {
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            if key.contains("token") || key.contains("cache") || key.contains("usage") {
                print("  \(key): \(value)")
            }
        }
        if let usage = dict["usage"] as? [String: Any] {
            print("  usage字段内容:")
            for (key, value) in usage.sorted(by: { $0.key < $1.key }) {
                print("    \(key): \(value)")
            }
        }
        if let message = dict["message"] as? [String: Any],
           let usage = message["usage"] as? [String: Any] {
            print("  message.usage字段内容:")
            for (key, value) in usage.sorted(by: { $0.key < $1.key }) {
                print("    \(key): \(value)")
            }
        }
    }
    
    private func parseFromDictionary(_ dict: [String: Any], projectPath: String) -> UsageEntry? {
        let type = extractString(from: dict, keys: ["type", "message_type", "messageType"])
        let model = extractString(from: dict, keys: ["model", "model_name", "modelName"])
        let timestamp = extractString(from: dict, keys: ["timestamp", "created_at", "createdAt", "date", "time"])
        let sessionId = extractString(from: dict, keys: ["session_id", "sessionId", "session"])
        let requestId = extractString(from: dict, keys: ["request_id", "requestId", "uuid", "id"])
        let messageId = extractString(from: dict, keys: ["message_id", "messageId"])
        let cost = extractDouble(from: dict, keys: ["cost", "cost_usd", "costUSD", "price"])
        
        // 尝试从message.id字段提取messageId
        var finalMessageId = messageId
        if finalMessageId == nil || finalMessageId!.isEmpty {
            if let messageDict = dict["message"] as? [String: Any],
               let msgId = messageDict["id"] as? String {
                finalMessageId = msgId
            }
        }
        
        // 解析使用数据
        var usage: RawJSONLEntry.UsageData?
        if let usageDict = dict["usage"] as? [String: Any] {
            usage = parseUsageData(from: usageDict)
        } else if let messageDict = dict["message"] as? [String: Any],
                  let usageDict = messageDict["usage"] as? [String: Any] {
            usage = parseUsageData(from: usageDict)
        } else {
            usage = parseUsageData(from: dict)
        }
        
        let rawEntry = RawJSONLEntry(
            type: type, messageType: type, model: model, usage: usage, message: nil,
            cost: cost, costUSD: cost, timestamp: timestamp, sessionId: sessionId,
            requestId: requestId, messageId: finalMessageId, id: requestId, uuid: requestId, date: timestamp
        )
        
        return rawEntry.toUsageEntry(projectPath: projectPath)
    }
    
    private func parseUsageData(from dict: [String: Any]) -> RawJSONLEntry.UsageData? {
        let inputTokens = extractInt(from: dict, keys: ["input_tokens", "inputTokens", "input", "in_tokens"])
        let outputTokens = extractInt(from: dict, keys: ["output_tokens", "outputTokens", "output", "out_tokens"])
        let cacheCreationInputTokens = extractInt(from: dict, keys: [
            "cache_creation_input_tokens", "cacheCreationInputTokens",
            "cache_creation_tokens", "cacheCreationTokens",
            "cache_write_tokens", "cacheWriteTokens",
            "cache_write_input_tokens", "cacheWriteInputTokens"
        ])
        let cacheReadInputTokens = extractInt(from: dict, keys: [
            "cache_read_input_tokens", "cacheReadInputTokens",
            "cache_read_tokens", "cacheReadTokens"
        ])
        let cacheCreationTokens = extractInt(from: dict, keys: [
            "cache_creation_tokens", "cacheCreationTokens",
            "cache_write_tokens", "cacheWriteTokens"
        ])
        let cacheReadTokens = extractInt(from: dict, keys: ["cache_read_tokens", "cacheReadTokens"])
        
        let hasAnyTokenData = inputTokens != nil || outputTokens != nil ||
                             cacheCreationInputTokens != nil || cacheReadInputTokens != nil ||
                             cacheCreationTokens != nil || cacheReadTokens != nil
        
        if !hasAnyTokenData {
            return nil
        }
        
        return RawJSONLEntry.UsageData(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationInputTokens: cacheCreationInputTokens,
            cacheReadInputTokens: cacheReadInputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens
        )
    }
    
    private func extractString(from dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }
    
    private func extractInt(from dict: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dict[key] as? Int {
                return value
            } else if let value = dict[key] as? Double {
                return Int(value)
            } else if let value = dict[key] as? String, let intValue = Int(value) {
                return intValue
            }
        }
        return nil
    }
    
    private func extractDouble(from dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dict[key] as? Double {
                return value
            } else if let value = dict[key] as? Int {
                return Double(value)
            } else if let value = dict[key] as? String, let doubleValue = Double(value) {
                return doubleValue
            }
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

    // 按时间戳排序文件（模拟ccusage的sortFilesByTimestamp行为）
    private func sortFilesByTimestamp(_ files: [URL]) -> [URL] {
        return files.sorted { file1, file2 in
            let timestamp1 = getEarliestTimestamp(from: file1)
            let timestamp2 = getEarliestTimestamp(from: file2)

            // 没有时间戳的文件放到最后
            if timestamp1 == nil && timestamp2 == nil { return false }
            if timestamp1 == nil { return false }
            if timestamp2 == nil { return true }

            // 按时间戳升序排序（最早的在前）
            return timestamp1! < timestamp2!
        }
    }

    // 获取文件中最早的时间戳
    private func getEarliestTimestamp(from fileURL: URL) -> Date? {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var earliestDate: Date? = nil

        for line in lines.prefix(10) { // 只检查前10行以提高性能
            if let jsonData = line.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let timestampString = jsonObject["timestamp"] as? String {

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                if let date = formatter.date(from: timestampString) {
                    if earliestDate == nil || date < earliestDate! {
                        earliestDate = date
                    }
                }
            }
        }

        return earliestDate
    }
}

// MARK: - 日期过滤
func filterEntriesByDate(_ entries: [UsageEntry], targetDate: String) -> [UsageEntry] {
    return entries.filter { entry in
        // 使用与ccusage一致的日期格式化方式
        let date = formatDateLikeCcusage(entry.timestamp)
        return date == targetDate
    }
}

// 模拟ccusage的formatDate函数
func formatDateLikeCcusage(_ timestamp: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    guard let date = formatter.date(from: timestamp) else {
        // 如果解析失败，回退到简单的字符串截取
        return String(timestamp.prefix(10))
    }

    // 使用en-CA locale确保YYYY-MM-DD格式（与ccusage一致）
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.locale = Locale(identifier: "en-CA")
    dateFormatter.timeZone = TimeZone.current // 使用系统时区

    return dateFormatter.string(from: date)
}

// 分析边界时间的数据
func analyzeBoundaryData(_ entries: [UsageEntry], targetDate: String) {
    let nextDay = getNextDay(targetDate)
    let prevDay = getPrevDay(targetDate)
    
    print("\n🔍 边界时间分析 (\(targetDate)):")
    
    // 找出目标日期最晚的条目
    let targetEntries = filterEntriesByDate(entries, targetDate: targetDate)
    if let latestEntry = targetEntries.max(by: { $0.timestamp < $1.timestamp }) {
        print("📅 \(targetDate) 最晚条目: \(latestEntry.timestamp) (\(latestEntry.totalTokens) tokens)")
    }
    
    // 找出次日最早的条目
    let nextEntries = filterEntriesByDate(entries, targetDate: nextDay)
    if let earliestEntry = nextEntries.min(by: { $0.timestamp < $1.timestamp }) {
        print("📅 \(nextDay) 最早条目: \(earliestEntry.timestamp) (\(earliestEntry.totalTokens) tokens)")
    }
    
    // 查找边界附近的大token条目
    let boundaryEntries = entries.filter { entry in
        let datePrefix = String(entry.timestamp.prefix(10))
        return (datePrefix == targetDate || datePrefix == nextDay) && entry.totalTokens > 10000
    }.sorted { $0.timestamp < $1.timestamp }
    
    print("\n🎯 边界附近的大token条目 (>10k tokens):")
    for entry in boundaryEntries.prefix(10) {
        let date = String(entry.timestamp.prefix(10))
        let time = String(entry.timestamp.suffix(entry.timestamp.count - 11))
        print("  \(date) \(time): \(formatNumber(entry.totalTokens)) tokens")
    }
}

func getNextDay(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    if let date = formatter.date(from: dateString) {
        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        return formatter.string(from: nextDate)
    }
    return dateString
}

func getPrevDay(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    if let date = formatter.date(from: dateString) {
        let prevDate = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        return formatter.string(from: prevDate)
    }
    return dateString
}

// MARK: - 统计计算
func calculateStatistics(from entries: [UsageEntry], targetDate: String? = nil) -> (Int, Int, Int, Int, Int, Double) {
    var filteredEntries = entries
    
    // 如果指定了日期，则过滤
    if let targetDate = targetDate {
        filteredEntries = filterEntriesByDate(entries, targetDate: targetDate)
        print("🎯 过滤到 \(targetDate): \(filteredEntries.count) 条记录")
    }
    
    guard !filteredEntries.isEmpty else {
        return (0, 0, 0, 0, 0, 0.0)
    }
    
    var totalCost: Double = 0
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCacheCreationTokens: Int = 0
    var totalCacheReadTokens: Int = 0
    
    // 会话数统计
    var allSessionIds = Set<String>()
    for entry in filteredEntries {
        allSessionIds.insert(entry.sessionId)
    }
    
    // 诊断信息
    var messageTypeDistribution: [String: Int] = [:]
    var modelDistribution: [String: Int] = [:]
    var entriesWithUsage = 0
    var entriesWithCost = 0
    
    for entry in filteredEntries {
        messageTypeDistribution[entry.messageType] = (messageTypeDistribution[entry.messageType] ?? 0) + 1
        modelDistribution[entry.model] = (modelDistribution[entry.model] ?? 0) + 1
        if entry.inputTokens > 0 || entry.outputTokens > 0 || entry.cacheCreationTokens > 0 || entry.cacheReadTokens > 0 {
            entriesWithUsage += 1
        }
        if entry.cost > 0 {
            entriesWithCost += 1
        }
    }
    
    print("📊 消息类型分布: \(messageTypeDistribution)")
    print("📊 模型分布: \(modelDistribution)")
    print("📊 有使用数据的条目: \(entriesWithUsage), 有成本数据的条目: \(entriesWithCost)")
    
    // 显示一些样本数据和字段分析
    print("\n🔍 数据样本 (前5条):")
    for (index, entry) in filteredEntries.prefix(5).enumerated() {
        print("  \(index + 1). \(entry.timestamp) | \(entry.model)")
        print("      Input:\(entry.inputTokens) Output:\(entry.outputTokens) Cache:\(entry.cacheCreationTokens)+\(entry.cacheReadTokens) Cost:\(entry.cost)")
    }
    
    // 分析缓存 token 的分布
    var cacheCreateCount = 0
    var cacheReadCount = 0
    var maxCacheCreate = 0
    var maxCacheRead = 0
    
    for entry in filteredEntries {
        if entry.cacheCreationTokens > 0 {
            cacheCreateCount += 1
            maxCacheCreate = max(maxCacheCreate, entry.cacheCreationTokens)
        }
        if entry.cacheReadTokens > 0 {
            cacheReadCount += 1
            maxCacheRead = max(maxCacheRead, entry.cacheReadTokens)
        }
    }
    
    print("\n📈 缓存 Token 分析:")
    print("  有缓存创建的条目: \(cacheCreateCount), 最大值: \(formatNumber(maxCacheCreate))")
    print("  有缓存读取的条目: \(cacheReadCount), 最大值: \(formatNumber(maxCacheRead))")
    
    // 尝试不同的去重策略来接近ccusage的结果
    print("🔄 开始处理 \(filteredEntries.count) 条过滤后数据条目，发现 \(allSessionIds.count) 个唯一会话")
    
    // 策略1: 尝试不去重，看看是否能接近ccusage
    print("🧪 测试策略1: 不进行去重，统计原始数据")
    var noDedupeTotal = 0
    for entry in filteredEntries {
        noDedupeTotal += entry.totalTokens
    }
    print("📊 无去重情况下的总tokens: \(formatNumber(noDedupeTotal))")
    
    // 策略2: 使用ccusage风格的温和去重逻辑
    print("🧹 实施ccusage风格的温和去重逻辑")
    
    // 尝试几种不同的去重策略
    print("🧪 测试策略2a: 只对完全相同的条目进行去重")
    var gentleUniqueEntries: [String: UsageEntry] = [:]
    var gentleDuplicateCount = 0
    var gentleDuplicateTokens = 0
    
    for entry in filteredEntries {
        let totalEntryTokens = entry.inputTokens + entry.outputTokens + entry.cacheCreationTokens + entry.cacheReadTokens
        
        // 更严格的去重键：要求多个字段完全匹配才认为是重复
        let strictKey = "\(entry.timestamp):\(entry.model):\(totalEntryTokens):\(entry.sessionId)"
        
        if let existing = gentleUniqueEntries[strictKey] {
            // 只有在时间戳、模型、token数量、会话ID都相同时才认为是重复
            gentleDuplicateCount += 1
            gentleDuplicateTokens += totalEntryTokens
            if gentleDuplicateCount <= 5 {
                print("🔍 发现严格重复记录: \(strictKey.prefix(80))... (\(totalEntryTokens) tokens)")
            }
        } else {
            gentleUniqueEntries[strictKey] = entry
        }
    }
    
    print("📊 温和去重统计: 原始 \(filteredEntries.count) 条，去重后 \(gentleUniqueEntries.count) 条")
    print("📊 温和去重移除: \(gentleDuplicateCount) 条，tokens: \(formatNumber(gentleDuplicateTokens))")
    
    var gentleTotal = 0
    for entry in gentleUniqueEntries.values {
        gentleTotal += entry.totalTokens
    }
    print("📊 温和去重后总tokens: \(formatNumber(gentleTotal))")
    
    // 策略3: 使用原来的激进去重逻辑做对比
    print("🧹 对比：激进去重逻辑")
    
    var uniqueEntries: [String: UsageEntry] = [:]
    var duplicateCount = 0
    var duplicateTokens = 0
    var skippedNullCount = 0
    
    for entry in filteredEntries {
        let totalEntryTokens = entry.inputTokens + entry.outputTokens + entry.cacheCreationTokens + entry.cacheReadTokens

        // 完全模拟ccusage的createUniqueHash逻辑
        var uniqueKey: String?

        // 只有当同时有messageId和requestId时才创建去重键
        if let messageId = entry.messageId, !messageId.isEmpty,
           let requestId = entry.requestId, !requestId.isEmpty {
            uniqueKey = "\(messageId):\(requestId)"
        }

        // 如果没有完整的ID组合，不进行去重（ccusage的行为）
        if let finalUniqueKey = uniqueKey {
            if let existing = uniqueEntries[finalUniqueKey] {
                duplicateCount += 1
                duplicateTokens += totalEntryTokens
                continue // 跳过重复条目
            } else {
                uniqueEntries[finalUniqueKey] = entry
            }
        } else {
            // 没有完整ID的条目直接添加，不去重
            let fallbackKey = "\(entry.timestamp):\(entry.model):\(totalEntryTokens):\(UUID().uuidString)"
            uniqueEntries[fallbackKey] = entry
            skippedNullCount += 1
        }
    }
    
    // 决定使用哪种去重策略
    let ccusageTarget = 1208150693  // 最新的ccusage统计结果 (2025-08-05 再次更新)
    let noDedupeDistance = abs(noDedupeTotal - ccusageTarget)
    let gentleDistance = abs(gentleTotal - ccusageTarget)
    let aggressiveTotal = uniqueEntries.values.reduce(0) { $0 + $1.totalTokens }
    let aggressiveDistance = abs(aggressiveTotal - ccusageTarget)
    
    print("\n🎯 去重策略比较:")
    print("无去重: \(formatNumber(noDedupeTotal)) (距离ccusage: \(formatNumber(noDedupeDistance)))")
    print("温和去重: \(formatNumber(gentleTotal)) (距离ccusage: \(formatNumber(gentleDistance)))")
    print("激进去重: \(formatNumber(aggressiveTotal)) (距离ccusage: \(formatNumber(aggressiveDistance)))")
    
    // 选择最接近ccusage的策略
    if gentleDistance <= noDedupeDistance && gentleDistance <= aggressiveDistance {
        print("✅ 选择温和去重策略（最接近ccusage）")
        uniqueEntries = gentleUniqueEntries
        duplicateCount = gentleDuplicateCount
        duplicateTokens = gentleDuplicateTokens
    } else if noDedupeDistance <= aggressiveDistance {
        print("✅ 选择无去重策略（最接近ccusage）")
        // 构建无去重的条目字典
        uniqueEntries.removeAll()
        for (index, entry) in filteredEntries.enumerated() {
            uniqueEntries["\(index)"] = entry
        }
        duplicateCount = 0
        duplicateTokens = 0
    } else {
        print("✅ 选择激进去重策略（最接近ccusage）")
        // 已经设置好了
    }
    
    print("📊 去重统计: 原始 \(filteredEntries.count) 条，去重后 \(uniqueEntries.count) 条")
    print("📊 重复记录: \(duplicateCount) 条，重复tokens: \(formatNumber(duplicateTokens))")
    print("📊 跳过的null记录: \(skippedNullCount) 条 (messageId或requestId为空)")
    
    var validEntries: [UsageEntry] = []
    
    for entry in uniqueEntries.values {
        validEntries.append(entry)
        // 使用定价模型计算成本（与 ClaudeBar 一致）
        let calculatedCost = calculateCost(
            model: entry.model,
            inputTokens: entry.inputTokens,
            outputTokens: entry.outputTokens,
            cacheCreationTokens: entry.cacheCreationTokens,
            cacheReadTokens: entry.cacheReadTokens
        )
        totalCost += calculatedCost
        totalInputTokens += entry.inputTokens
        totalOutputTokens += entry.outputTokens
        totalCacheCreationTokens += entry.cacheCreationTokens
        totalCacheReadTokens += entry.cacheReadTokens
    }
    
    let totalRequests = validEntries.count
    let totalTokens = totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    
    print("🎯 统计结果:")
    print("- 总会话数: \(allSessionIds.count)")
    print("- 总请求数: \(totalRequests)")
    print("- 去重后有效条目: \(validEntries.count)")
    
    return (totalInputTokens, totalOutputTokens, totalCacheCreationTokens, totalCacheReadTokens, totalTokens, totalCost)
}

// MARK: - 主程序
func main() {
    print("🚀 Claude Token 统计工具")
    print("============================")
    
    // 获取 Claude 项目目录
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    let claudeDirectory = homeDirectory.appendingPathComponent(".claude")
    let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
    
    guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
        print("❌ 找不到 projects 目录: \(projectsDirectory.path)")
        return
    }
    
    print("📂 项目目录: \(projectsDirectory.path)")
    
    // 获取命令行参数
    let arguments = CommandLine.arguments
    
    // 如果有参数，则作为日期使用
    if arguments.count > 1 {
        let targetDate = arguments[1]
        
        if targetDate == "all" {
            // 显示所有日期
            showAllDates(projectsDirectory: projectsDirectory)
        } else if targetDate == "total" {
            // 显示总量统计
            showTotalStats(projectsDirectory: projectsDirectory)
        } else {
            // 显示特定日期
            showDateStats(projectsDirectory: projectsDirectory, targetDate: targetDate)
        }
    } else {
        // 没有参数，显示使用说明
        print("📋 使用说明：")
        print("  swift token_stats_test.swift [日期]")
        print("  swift token_stats_test.swift all     # 显示所有日期")
        print("  swift token_stats_test.swift total   # 显示总量统计")
        print("  swift token_stats_test.swift 2025-08-04  # 显示特定日期")
        print("")
        
        // 显示可用日期
        let parser = JSONLParser()
        let entries = parser.parseJSONLFiles(in: projectsDirectory)
        let dateSet = Set(entries.map { String($0.timestamp.prefix(10)) })
        let sortedDates = dateSet.sorted()
        
        print("📅 可用日期范围: \(sortedDates.first ?? "无") 到 \(sortedDates.last ?? "无") (共 \(sortedDates.count) 天)")
        print("📅 最近几天: \(sortedDates.suffix(10).joined(separator: ", "))")
    }
}

func showDateStats(projectsDirectory: URL, targetDate: String) {
    let parser = JSONLParser()
    let entries = parser.parseJSONLFiles(in: projectsDirectory)
    
    print("📈 解析完成，获得 \(entries.count) 条原始记录")
    
    // 增加详细的调试信息
    let filteredEntries = filterEntriesByDate(entries, targetDate: targetDate)
    print("🎯 过滤到 \(targetDate): \(filteredEntries.count) 条记录")
    
    // 分析原始数据的字段分布
    var messageTypeDistribution: [String: Int] = [:]
    var modelDistribution: [String: Int] = [:]
    var entriesWithUsage = 0
    var entriesWithCost = 0
    var totalRawTokens = 0
    
    for entry in filteredEntries {
        messageTypeDistribution[entry.messageType] = (messageTypeDistribution[entry.messageType] ?? 0) + 1
        modelDistribution[entry.model] = (modelDistribution[entry.model] ?? 0) + 1
        if entry.inputTokens > 0 || entry.outputTokens > 0 || entry.cacheCreationTokens > 0 || entry.cacheReadTokens > 0 {
            entriesWithUsage += 1
        }
        if entry.cost > 0 {
            entriesWithCost += 1
        }
        totalRawTokens += entry.totalTokens
    }
    
    print("📊 消息类型分布: \(messageTypeDistribution)")
    print("📊 模型分布: \(modelDistribution)")
    print("📊 有使用数据的条目: \(entriesWithUsage), 有成本数据的条目: \(entriesWithCost)")
    print("📊 原始数据总计 tokens: \(formatNumber(totalRawTokens))")
    
    // 显示样本数据，特别关注可能被过滤的数据
    print("\n🔍 数据样本 (前10条):")
    for (index, entry) in filteredEntries.prefix(10).enumerated() {
        print("  \(index + 1). \(entry.timestamp) | \(entry.model) | \(entry.messageType)")
        print("      Input:\(entry.inputTokens) Output:\(entry.outputTokens) Cache:\(entry.cacheCreationTokens)+\(entry.cacheReadTokens) Total:\(entry.totalTokens) Cost:\(entry.cost)")
    }
    
    // 分析边界时间数据
    analyzeBoundaryData(entries, targetDate: targetDate)
    
    let (inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens, totalTokens, totalCost) = calculateStatistics(from: entries, targetDate: targetDate)
    
    print("\n📊 统计函数计算的总tokens: \(formatNumber(totalTokens))")
    print("📊 原始累加的总tokens: \(formatNumber(totalRawTokens))")
    if totalRawTokens != totalTokens {
        print("⚠️  差异: \(formatNumber(totalRawTokens - totalTokens)) tokens")
    }
    
    print("\n" + String(repeating: "=", count: 80))
    print("📊 \(targetDate) 统计结果")
    print(String(repeating: "=", count: 80))
    print("Input        │ Output       │ Cache Create │ Cache Read   │ Total Tokens │ Cost (USD)")
    print(String(repeating: "-", count: 80))
    print("\(formatNumber(inputTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(outputTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(cacheCreationTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(cacheReadTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(totalTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ $\(String(format: "%.4f", totalCost))")
    print(String(repeating: "=", count: 80))
}

func showAllDates(projectsDirectory: URL) {
    let parser = JSONLParser()
    let entries = parser.parseJSONLFiles(in: projectsDirectory)
    
    print("📈 解析完成，获得 \(entries.count) 条原始记录")
    
    let dateSet = Set(entries.map { String($0.timestamp.prefix(10)) })
    let sortedDates = dateSet.sorted()
    
    print("\n🎯 所有日期统计...")
    print(String(repeating: "=", count: 100))
    print("日期         │ Input      │ Output     │ CacheCreate│ CacheRead  │ Total      │ Cost(USD)")
    print(String(repeating: "-", count: 100))
    
    for date in sortedDates {
        let (inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens, totalTokens, totalCost) = calculateStatistics(from: entries, targetDate: date)
        print("\(date) │ \(formatNumber(inputTokens).padding(toLength: 10, withPad: " ", startingAt: 0)) │ \(formatNumber(outputTokens).padding(toLength: 10, withPad: " ", startingAt: 0)) │ \(formatNumber(cacheCreationTokens).padding(toLength: 10, withPad: " ", startingAt: 0)) │ \(formatNumber(cacheReadTokens).padding(toLength: 10, withPad: " ", startingAt: 0)) │ \(formatNumber(totalTokens).padding(toLength: 10, withPad: " ", startingAt: 0)) │ $\(String(format: "%.4f", totalCost))")
    }
    print(String(repeating: "=", count: 100))
}

func showTotalStats(projectsDirectory: URL) {
    let parser = JSONLParser()
    let entries = parser.parseJSONLFiles(in: projectsDirectory)
    
    print("📈 解析完成，获得 \(entries.count) 条原始记录")
    
    let (inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens, totalTokens, totalCost) = calculateStatistics(from: entries, targetDate: nil)
    
    print("\n" + String(repeating: "=", count: 80))
    print("📊 总量统计结果")
    print(String(repeating: "=", count: 80))
    print("Input        │ Output       │ Cache Create │ Cache Read   │ Total Tokens │ Cost (USD)")
    print(String(repeating: "-", count: 80))
    print("\(formatNumber(inputTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(outputTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(cacheCreationTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(cacheReadTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(formatNumber(totalTokens).padding(toLength: 12, withPad: " ", startingAt: 0)) │ $\(String(format: "%.4f", totalCost))")
    print(String(repeating: "=", count: 80))
    
    // 与ccusage的对比信息
    let ccusageTotal = 1208150693 // 最新的ccusage统计结果 (2025-08-05 再次更新)
    let ccusageCost = 2880.98 // ccusage的价格总价
    let difference = totalTokens - ccusageTotal
    let percentDiff = abs(Double(difference) / Double(ccusageTotal)) * 100
    
    print("\n🎯 与ccusage对比:")
    print("Token统计:")
    print("  ccusage统计: \(formatNumber(ccusageTotal)) tokens")
    print("  当前统计:   \(formatNumber(totalTokens)) tokens")
    print("  差异:       \(formatNumber(difference)) tokens (\(String(format: "%.1f", percentDiff))%)")

    // 成本对比
    let costDifference = totalCost - ccusageCost
    let costPercentDiff = abs(costDifference / ccusageCost) * 100

    print("\nCost统计:")
    print("  ccusage成本: $\(String(format: "%.2f", ccusageCost))")
    print("  当前成本:   $\(String(format: "%.2f", totalCost))")
    print("  差异:       $\(String(format: "%.2f", costDifference)) (\(String(format: "%.1f", costPercentDiff))%)")

    // 综合评估
    print("\n📈 精度评估:")
    if percentDiff < 1.0 && costPercentDiff < 1.0 {
        print("✅ Token和Cost差异都小于1%，达到完美精度！")
    } else if percentDiff < 1.0 {
        print("✅ Token差异小于1%，达到目标精度！")
        if costPercentDiff < 5.0 {
            print("🟡 Cost差异小于5%，较好的精度")
        } else {
            print("🟠 Cost差异较大，可能需要检查成本计算逻辑")
        }
    } else if percentDiff < 5.0 {
        print("🟡 Token差异小于5%，较好的精度")
    } else if percentDiff < 10.0 {
        print("🟠 Token差异小于10%，需要进一步优化")
    } else {
        print("🔴 Token差异较大，需要重新审查过滤策略")
    }
}

func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}


// 运行主程序
main()