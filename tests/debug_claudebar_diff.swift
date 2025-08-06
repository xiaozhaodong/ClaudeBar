#!/usr/bin/env swift

import Foundation

// 简化的调试脚本，专门用于找出 ClaudeBar 和测试脚本的差异

struct SimpleEntry {
    let timestamp: String
    let model: String
    let totalTokens: Int
    let messageType: String
    let requestId: String?
    let messageId: String?
}

func main() {
    print("🔍 调试 ClaudeBar 与测试脚本的差异")
    print("=====================================")
    
    let projectsDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude")
        .appendingPathComponent("projects")
    
    // 解析所有文件，统计基本信息
    let (testScriptEntries, claudeBarEntries) = parseWithBothLogics(in: projectsDirectory)
    
    print("📊 记录数量对比:")
    print("测试脚本: \(testScriptEntries.count) 条")
    print("ClaudeBar: \(claudeBarEntries.count) 条")
    print("差异: \(claudeBarEntries.count - testScriptEntries.count) 条")
    
    // 分析差异
    let testScriptTotal = testScriptEntries.reduce(0) { $0 + $1.totalTokens }
    let claudeBarTotal = claudeBarEntries.reduce(0) { $0 + $1.totalTokens }
    
    print("\n📊 Token 总量对比:")
    print("测试脚本: \(formatNumber(testScriptTotal)) tokens")
    print("ClaudeBar: \(formatNumber(claudeBarTotal)) tokens")
    print("差异: \(formatNumber(claudeBarTotal - testScriptTotal)) tokens")
    
    // 找出只在一个脚本中存在的记录
    let testScriptSet = Set(testScriptEntries.map { "\($0.timestamp):\($0.model):\($0.totalTokens)" })
    let claudeBarSet = Set(claudeBarEntries.map { "\($0.timestamp):\($0.model):\($0.totalTokens)" })
    
    let onlyInTestScript = testScriptSet.subtracting(claudeBarSet)
    let onlyInClaudeBar = claudeBarSet.subtracting(testScriptSet)
    
    print("\n🔍 差异分析:")
    print("只在测试脚本中: \(onlyInTestScript.count) 条")
    print("只在ClaudeBar中: \(onlyInClaudeBar.count) 条")
    
    if !onlyInTestScript.isEmpty {
        print("\n只在测试脚本中的记录样本:")
        for (index, entry) in onlyInTestScript.prefix(5).enumerated() {
            print("  \(index + 1). \(entry)")
        }
    }
    
    if !onlyInClaudeBar.isEmpty {
        print("\n只在ClaudeBar中的记录样本:")
        for (index, entry) in onlyInClaudeBar.prefix(5).enumerated() {
            print("  \(index + 1). \(entry)")
        }
    }
    
    // 分析 ID 字段的差异
    analyzeIdFields(testScriptEntries: testScriptEntries, claudeBarEntries: claudeBarEntries)
}

func parseWithBothLogics(in directory: URL) -> ([SimpleEntry], [SimpleEntry]) {
    var testScriptEntries: [SimpleEntry] = []
    var claudeBarEntries: [SimpleEntry] = []
    
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
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
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            continue
        }
        
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for line in lines {
            guard let jsonData = line.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }
            
            // 测试脚本逻辑
            if let testEntry = parseWithTestScriptLogic(jsonObject) {
                testScriptEntries.append(testEntry)
            }
            
            // ClaudeBar 逻辑
            if let claudeBarEntry = parseWithClaudeBarLogic(jsonObject) {
                claudeBarEntries.append(claudeBarEntry)
            }
        }
    }
    
    return (testScriptEntries, claudeBarEntries)
}

func parseWithTestScriptLogic(_ json: [String: Any]) -> SimpleEntry? {
    // 模拟测试脚本的解析逻辑
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
    
    // 测试脚本的过滤逻辑
    if totalTokens == 0 && totalCost == 0 {
        return nil
    }
    
    let model = json["model"] as? String ?? (json["message"] as? [String: Any])?["model"] as? String ?? "unknown"
    if model == "<synthetic>" {
        return nil
    }
    
    let timestamp = json["timestamp"] as? String ?? json["date"] as? String ?? ""
    
    // ID 提取逻辑（测试脚本风格）
    let requestId = json["requestId"] as? String ?? json["message_id"] as? String
    let messageId = json["message_id"] as? String ?? (json["message"] as? [String: Any])?["id"] as? String
    
    return SimpleEntry(
        timestamp: timestamp,
        model: model,
        totalTokens: totalTokens,
        messageType: messageType,
        requestId: requestId,
        messageId: messageId
    )
}

func parseWithClaudeBarLogic(_ json: [String: Any]) -> SimpleEntry? {
    // 模拟 ClaudeBar 的解析逻辑
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
    
    // ClaudeBar 的过滤逻辑（应该与测试脚本一致）
    if totalTokens == 0 && totalCost == 0 {
        return nil
    }
    
    let model = json["model"] as? String ?? (json["message"] as? [String: Any])?["model"] as? String ?? "unknown"
    if model == "<synthetic>" {
        return nil
    }
    
    let timestamp = json["timestamp"] as? String ?? json["date"] as? String ?? ""
    
    // ID 提取逻辑（修复后的 ClaudeBar 风格）
    let requestId = json["requestId"] as? String ?? json["request_id"] as? String ?? json["message_id"] as? String
    let messageId = json["message_id"] as? String ?? (json["message"] as? [String: Any])?["id"] as? String
    
    return SimpleEntry(
        timestamp: timestamp,
        model: model,
        totalTokens: totalTokens,
        messageType: messageType,
        requestId: requestId,
        messageId: messageId
    )
}

func analyzeIdFields(testScriptEntries: [SimpleEntry], claudeBarEntries: [SimpleEntry]) {
    print("\n🔍 ID 字段分析:")
    
    let testScriptWithRequestId = testScriptEntries.filter { $0.requestId != nil }.count
    let claudeBarWithRequestId = claudeBarEntries.filter { $0.requestId != nil }.count
    
    let testScriptWithMessageId = testScriptEntries.filter { $0.messageId != nil }.count
    let claudeBarWithMessageId = claudeBarEntries.filter { $0.messageId != nil }.count
    
    print("有 requestId 的记录:")
    print("  测试脚本: \(testScriptWithRequestId)")
    print("  ClaudeBar: \(claudeBarWithRequestId)")
    
    print("有 messageId 的记录:")
    print("  测试脚本: \(testScriptWithMessageId)")
    print("  ClaudeBar: \(claudeBarWithMessageId)")
}

func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

main()
