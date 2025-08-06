#!/usr/bin/env swift

import Foundation

// 测试修复后的 ClaudeBar 逻辑

func main() {
    print("🚀 测试修复后的 ClaudeBar 逻辑")
    print("================================")
    
    let projectsDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude")
        .appendingPathComponent("projects")
    
    print("📂 项目目录: \(projectsDirectory.path)")
    
    // 解析所有 JSONL 文件
    let entries = parseAllJSONLFiles(in: projectsDirectory)
    print("📈 解析完成，获得 \(entries.count) 条原始记录")
    
    // 应用激进去重逻辑（与测试脚本一致）
    let result = applyAggressiveDeduplication(entries: entries)
    
    print("\n================================================================================")
    print("📊 修复后的 ClaudeBar 统计结果")
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
    
    // 与 ccusage 和测试脚本对比
    let ccusageTarget = 1199212354
    let difference = totalTokens - ccusageTarget
    let percentDiff = Double(abs(difference)) / Double(ccusageTarget) * 100
    
    print("\n🎯 与ccusage/测试脚本对比:")
    print("ccusage统计:     \(formatNumber(ccusageTarget)) tokens")
    print("测试脚本统计:    \(formatNumber(ccusageTarget)) tokens")
    print("修复后ClaudeBar: \(formatNumber(totalTokens)) tokens")
    print("差异:           \(formatNumber(difference)) tokens (\(String(format: "%.3f", percentDiff))%)")
    
    if abs(difference) == 0 {
        print("🎉 完美匹配！差异为 0")
    } else if abs(difference) < ccusageTarget / 1000 {
        print("✅ 差异小于0.1%，非常接近！")
    } else if abs(difference) < ccusageTarget / 100 {
        print("✅ 差异小于1%，达到目标精度！")
    } else {
        print("❌ 差异超过1%，需要进一步调整")
    }
}

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
    let messageId: String?
    let messageType: String
    
    var totalTokens: Int {
        return inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
}

func parseAllJSONLFiles(in directory: URL) -> [SimpleUsageEntry] {
    var allEntries: [SimpleUsageEntry] = []
    
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
                  let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let entry = parseEntry(jsonObject, projectPath: projectPath) else {
                continue
            }
            allEntries.append(entry)
        }
    }
    
    return allEntries
}

func parseEntry(_ json: [String: Any], projectPath: String) -> SimpleUsageEntry? {
    // 使用修复后的 ClaudeBar 解析逻辑
    let messageType = json["type"] as? String ?? json["message_type"] as? String ?? ""
    
    // 获取 usage 数据
    var usage: [String: Any]?
    if let usageDict = json["usage"] as? [String: Any] {
        usage = usageDict
    } else if let messageDict = json["message"] as? [String: Any],
              let usageDict = messageDict["usage"] as? [String: Any] {
        usage = usageDict
    }
    
    guard let usageData = usage else { return nil }
    
    let inputTokens = usageData["input_tokens"] as? Int ?? 0
    let outputTokens = usageData["output_tokens"] as? Int ?? 0
    let cacheCreationTokens = usageData["cache_creation_input_tokens"] as? Int ?? 0
    let cacheReadTokens = usageData["cache_read_input_tokens"] as? Int ?? 0
    
    let totalTokens = inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    let totalCost = json["cost"] as? Double ?? json["costUSD"] as? Double ?? 0
    
    // 过滤逻辑
    if totalTokens == 0 && totalCost == 0 {
        return nil
    }
    
    let model = json["model"] as? String ?? (json["message"] as? [String: Any])?["model"] as? String ?? "unknown"
    if model == "<synthetic>" {
        return nil
    }
    
    let timestamp = json["timestamp"] as? String ?? json["date"] as? String ?? ""
    let sessionId = json["session_id"] as? String ?? "unknown"
    
    // 修复后的 ID 提取逻辑
    let requestId = json["requestId"] as? String ?? json["request_id"] as? String ?? json["message_id"] as? String
    let messageId = json["message_id"] as? String ?? (json["message"] as? [String: Any])?["id"] as? String
    
    return SimpleUsageEntry(
        timestamp: timestamp,
        model: model,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        cacheCreationTokens: cacheCreationTokens,
        cacheReadTokens: cacheReadTokens,
        cost: totalCost,
        sessionId: sessionId,
        projectPath: projectPath,
        requestId: requestId,
        messageId: messageId,
        messageType: messageType
    )
}

func applyAggressiveDeduplication(entries: [SimpleUsageEntry]) -> [SimpleUsageEntry] {
    print("🧹 应用激进去重逻辑（与测试脚本一致）")
    
    var uniqueEntries: [String: SimpleUsageEntry] = [:]
    var duplicateCount = 0
    var skippedCount = 0
    
    for entry in entries {
        var uniqueKey: String?
        
        // 只有当同时有messageId和requestId时才创建去重键
        if let messageId = entry.messageId, !messageId.isEmpty,
           let requestId = entry.requestId, !requestId.isEmpty {
            uniqueKey = "\(messageId):\(requestId)"
        }
        
        if let finalUniqueKey = uniqueKey {
            if uniqueEntries[finalUniqueKey] != nil {
                duplicateCount += 1
            } else {
                uniqueEntries[finalUniqueKey] = entry
            }
        } else {
            // 没有完整ID的条目直接添加，不去重
            let fallbackKey = "\(entry.timestamp):\(entry.model):\(entry.totalTokens):\(UUID().uuidString)"
            uniqueEntries[fallbackKey] = entry
            skippedCount += 1
        }
    }
    
    print("📊 去重统计: 原始 \(entries.count) 条，去重后 \(uniqueEntries.count) 条")
    print("📊 重复记录: \(duplicateCount) 条")
    print("📊 跳过的null记录: \(skippedCount) 条")
    
    return Array(uniqueEntries.values)
}

func extractProjectPath(from fileURL: URL) -> String {
    return fileURL.deletingLastPathComponent().lastPathComponent
}

func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

main()
