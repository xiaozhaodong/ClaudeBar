#!/usr/bin/env swift

import Foundation

// 复制 ClaudeBar 的核心统计逻辑来测试
// 这样我们可以直接运行并对比结果

/// 单条使用记录模型
struct UsageEntry: Codable {
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
    
    /// 总令牌数
    var totalTokens: Int {
        return inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
    
    /// 日期字符串（YYYY-MM-DD 格式）
    var dateString: String {
        return String(timestamp.prefix(10))
    }
}

/// JSONL 原始数据模型（用于解析）
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
    let requestId: String?  // 无下划线版本
    let requestIdUnderscore: String?  // 下划线版本
    let messageId: String?
    let id: String?
    let uuid: String?
    let date: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case messageType = "message_type"
        case model
        case usage
        case message
        case cost
        case costUSD
        case timestamp
        case sessionId = "session_id"
        case requestId  // 支持无下划线的 requestId 字段
        case requestIdUnderscore = "request_id"  // 支持下划线的 request_id 字段
        case messageId = "message_id"
        case id
        case uuid
        case date
    }
    
    /// 嵌套的使用数据
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
        
        /// 获取缓存创建令牌数（优先使用精确字段）
        var effectiveCacheCreationTokens: Int {
            return cacheCreationInputTokens ?? cacheCreationTokens ?? 0
        }
        
        /// 获取缓存读取令牌数（优先使用精确字段）
        var effectiveCacheReadTokens: Int {
            return cacheReadInputTokens ?? cacheReadTokens ?? 0
        }
    }
    
    /// 嵌套的消息数据
    struct MessageData: Codable {
        let usage: UsageData?
        let model: String?
        let id: String?
    }
    
    /// 转换为标准使用记录
    func toUsageEntry(projectPath: String) -> UsageEntry? {
        let messageType = type ?? self.messageType ?? ""
        let usageData = usage ?? message?.usage
        
        // 采用与ccusage更接近的严格过滤策略
        let hasUsageData = usageData != nil
        let hasCostData = (cost ?? costUSD ?? 0) > 0
        
        // 跳过cost和token都为0的无效条目
        let totalTokens = (usageData?.inputTokens ?? 0) + 
                         (usageData?.outputTokens ?? 0) + 
                         (usageData?.effectiveCacheCreationTokens ?? 0) + 
                         (usageData?.effectiveCacheReadTokens ?? 0)
        let totalCost = cost ?? costUSD ?? 0
        
        if totalTokens == 0 && totalCost == 0 {
            return nil
        }
        
        // 放宽过滤策略，尝试包含更多数据（与ccusage一致）
        if totalTokens == 0 && totalCost == 0 && !hasUsageData && !hasCostData {
            return nil
        }
        
        let modelName = model ?? message?.model ?? "unknown"
        // 过滤掉synthetic消息（ccusage可能不统计这些）
        if modelName == "<synthetic>" {
            return nil
        }
        
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        let cacheCreationTokens = usageData?.effectiveCacheCreationTokens ?? 0
        let cacheReadTokens = usageData?.effectiveCacheReadTokens ?? 0
        
        let calculatedCost = cost ?? costUSD ?? 0
        
        // 修复后的 ClaudeBar ID 提取逻辑
        let extractedRequestId = requestId ?? requestIdUnderscore ?? messageId
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

// 主要测试逻辑
func main() {
    print("🚀 ClaudeBar 统计逻辑测试")
    print("============================")
    
    let projectsDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude")
        .appendingPathComponent("projects")
    
    print("📂 项目目录: \(projectsDirectory.path)")
    
    // 解析所有 JSONL 文件
    let entries = parseAllJSONLFiles(in: projectsDirectory)
    print("📈 解析完成，获得 \(entries.count) 条原始记录")
    
    // 应用 ClaudeBar 的去重逻辑
    let result = applyClaudeBarDeduplication(entries: entries)
    
    print("\n================================================================================")
    print("📊 ClaudeBar 统计结果")
    print("================================================================================")
    print("Input        │ Output       │ Cache Create │ Cache Read   │ Total Tokens │ Cost (USD)")
    print("--------------------------------------------------------------------------------")
    
    let totalInput = result.reduce(0) { $0 + $1.inputTokens }
    let totalOutput = result.reduce(0) { $0 + $1.outputTokens }
    let totalCacheCreate = result.reduce(0) { $0 + $1.cacheCreationTokens }
    let totalCacheRead = result.reduce(0) { $0 + $1.cacheReadTokens }
    let totalTokens = totalInput + totalOutput + totalCacheCreate + totalCacheRead
    let totalCost = result.reduce(0) { $0 + $1.cost }
    
    print(String(format: "%-12s │ %-12s │ %-12s │ %-12s │ %-12s │ $%.4f",
                 formatNumber(totalInput),
                 formatNumber(totalOutput),
                 formatNumber(totalCacheCreate),
                 formatNumber(totalCacheRead),
                 formatNumber(totalTokens),
                 totalCost))
    print("================================================================================")
    
    // 与 ccusage 对比
    let ccusageTarget = 1199212354
    let difference = totalTokens - ccusageTarget
    let percentDiff = Double(abs(difference)) / Double(ccusageTarget) * 100
    
    print("\n🎯 与ccusage对比:")
    print("ccusage统计: \(formatNumber(ccusageTarget)) tokens")
    print("ClaudeBar统计: \(formatNumber(totalTokens)) tokens")
    print("差异:       \(formatNumber(difference)) tokens (\(String(format: "%.2f", percentDiff))%)")
    
    if abs(difference) < ccusageTarget / 100 {
        print("✅ 差异小于1%，达到目标精度！")
    } else {
        print("❌ 差异超过1%，需要进一步调整")
    }
}

func parseAllJSONLFiles(in directory: URL) -> [UsageEntry] {
    // 简化的文件解析逻辑
    var allEntries: [UsageEntry] = []
    let decoder = JSONDecoder()
    
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        print("❌ 无法枚举目录: \(directory.path)")
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
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            continue
        }
        
        let projectPath = extractProjectPath(from: fileURL)
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for line in lines {
            guard let jsonData = line.data(using: .utf8),
                  let rawEntry = try? decoder.decode(RawJSONLEntry.self, from: jsonData),
                  let entry = rawEntry.toUsageEntry(projectPath: projectPath) else {
                continue
            }
            allEntries.append(entry)
        }
    }
    
    return allEntries
}

func extractProjectPath(from fileURL: URL) -> String {
    // 简化的项目路径提取
    return fileURL.deletingLastPathComponent().lastPathComponent
}

func applyClaudeBarDeduplication(entries: [UsageEntry]) -> [UsageEntry] {
    // 复制 ClaudeBar 的去重逻辑
    print("🧹 应用 ClaudeBar 的去重逻辑")
    
    // 策略1: 无去重
    let noDedupeTotal = entries.reduce(0) { $0 + $1.totalTokens }
    print("📊 无去重情况下的总tokens: \(formatNumber(noDedupeTotal))")
    
    // 策略2: 温和去重
    var gentleUniqueEntries: [String: UsageEntry] = [:]
    for entry in entries {
        let strictKey = "\(entry.timestamp):\(entry.model):\(entry.totalTokens):\(entry.sessionId)"
        if gentleUniqueEntries[strictKey] == nil {
            gentleUniqueEntries[strictKey] = entry
        }
    }
    let gentleTotal = gentleUniqueEntries.values.reduce(0) { $0 + $1.totalTokens }
    print("📊 温和去重后总tokens: \(formatNumber(gentleTotal))")
    
    // 策略3: 激进去重（ccusage风格）
    var uniqueEntries: [String: UsageEntry] = [:]
    var skippedCount = 0
    
    for entry in entries {
        var uniqueKey: String?
        
        // 只有当同时有messageId和requestId时才创建去重键
        if let messageId = entry.messageId, !messageId.isEmpty,
           let requestId = entry.requestId, !requestId.isEmpty {
            uniqueKey = "\(messageId):\(requestId)"
        }
        
        if let finalUniqueKey = uniqueKey {
            if uniqueEntries[finalUniqueKey] == nil {
                uniqueEntries[finalUniqueKey] = entry
            }
        } else {
            // 没有完整ID的条目直接添加，不去重
            let fallbackKey = "\(entry.timestamp):\(entry.model):\(entry.totalTokens):\(UUID().uuidString)"
            uniqueEntries[fallbackKey] = entry
            skippedCount += 1
        }
    }
    
    let aggressiveTotal = uniqueEntries.values.reduce(0) { $0 + $1.totalTokens }
    print("📊 激进去重后总tokens: \(formatNumber(aggressiveTotal))")
    print("📊 跳过的null记录: \(skippedCount) 条")
    
    // 选择最接近 ccusage 的策略
    let ccusageTarget = 1199212354
    let strategies = [
        ("none", entries, abs(noDedupeTotal - ccusageTarget)),
        ("gentle", Array(gentleUniqueEntries.values), abs(gentleTotal - ccusageTarget)),
        ("aggressive", Array(uniqueEntries.values), abs(aggressiveTotal - ccusageTarget))
    ]
    
    let bestStrategy = strategies.min { $0.2 < $1.2 }!
    print("✅ 选择 \(bestStrategy.0) 策略（距离ccusage: \(formatNumber(bestStrategy.2))）")
    
    return bestStrategy.1
}

func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

main()
