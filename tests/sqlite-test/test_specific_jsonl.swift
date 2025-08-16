import Foundation

// 直接测试你提供的JSONL文件中的数据
let jsonlPath = "/Users/xiaozhaodong/.claude/projects/-Users-xiaozhaodong--claude/58280350-74c0-43a5-a960-419cda036497.jsonl"

print("🔍 分析具体JSONL文件中的模型提取问题")
print(String(repeating: "=", count: 60))

// 读取文件的前几行进行分析
if let fileContent = try? String(contentsOfFile: jsonlPath) {
    let lines = fileContent.components(separatedBy: .newlines)
    
    print("文件总行数: \(lines.count)")
    
    // 查找包含gemini-2.5-pro的行
    let geminiLines = lines.filter { $0.contains("gemini-2.5-pro") }
    print("包含'gemini-2.5-pro'的行数: \(geminiLines.count)")
    
    if let firstGeminiLine = geminiLines.first {
        print("\n📋 第一个包含gemini-2.5-pro的JSON行:")
        print(String(repeating: "-", count: 60))
        
        // 尝试解析这一行
        if let jsonData = firstGeminiLine.data(using: .utf8) {
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    print("✅ JSON解析成功")
                    
                    // 检查关键字段
                    print("\n🔍 关键字段分析:")
                    print("- type: \(jsonObject["type"] ?? "nil")")
                    print("- model (顶级): \(jsonObject["model"] ?? "nil")")
                    print("- message_type: \(jsonObject["message_type"] ?? "nil")")
                    
                    if let message = jsonObject["message"] as? [String: Any] {
                        print("- message.model: \(message["model"] ?? "nil")")
                        print("- message.role: \(message["role"] ?? "nil")")
                    } else {
                        print("- message: nil 或不是字典")
                    }
                    
                    // 模拟当前代码的逻辑
                    print("\n🧮 模拟当前代码逻辑:")
                    let type = jsonObject["type"] as? String
                    let messageType = jsonObject["message_type"] as? String
                    let topLevelModel = jsonObject["model"] as? String
                    let messageModel = (jsonObject["message"] as? [String: Any])?["model"] as? String
                    
                    let extractedMessageType = type ?? messageType ?? ""
                    let extractedModelName = topLevelModel ?? messageModel ?? ""
                    
                    print("- 提取的messageType: '\(extractedMessageType)'")
                    print("- 提取的modelName: '\(extractedModelName)'")
                    
                    // 分析问题
                    print("\n❗ 问题分析:")
                    if extractedModelName == "gemini-2.5-pro" {
                        print("✅ 模型提取正确: \(extractedModelName)")
                        print("🤔 问题可能在数据库存储或其他处理环节")
                    } else {
                        print("❌ 模型提取错误!")
                        print("   期望: gemini-2.5-pro")
                        print("   实际: \(extractedModelName)")
                    }
                    
                    if extractedMessageType == "assistant" {
                        print("⚠️  messageType是'assistant'，这可能被错误地存储为模型名称")
                    }
                }
            } catch {
                print("❌ JSON解析失败: \(error)")
            }
        }
    } else {
        print("❌ 没有找到包含'gemini-2.5-pro'的行")
    }
} else {
    print("❌ 无法读取文件: \(jsonlPath)")
}
