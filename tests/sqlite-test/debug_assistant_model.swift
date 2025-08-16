import Foundation

// 模拟JSONL数据结构
struct TestRawJSONLEntry: Codable {
    let type: String?
    let messageType: String?
    let model: String?
    let message: TestMessageData?
    
    struct TestMessageData: Codable {
        let model: String?
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case messageType = "message_type"
        case model
        case message
    }
}

// 测试JSONL数据
let jsonString = """
{
    "type": "assistant",
    "message": {
        "model": "claude-sonnet-4-20250514"
    }
}
"""

print("🔍 调试模型提取逻辑")
print(String(repeating: "=", count: 50))

if let jsonData = jsonString.data(using: .utf8) {
    do {
        let entry = try JSONDecoder().decode(TestRawJSONLEntry.self, from: jsonData)
        
        print("解析结果:")
        print("- type: \(entry.type ?? "nil")")
        print("- messageType: \(entry.messageType ?? "nil")")
        print("- model (顶级): \(entry.model ?? "nil")")
        print("- message.model: \(entry.message?.model ?? "nil")")
        
        print("\n当前项目逻辑:")
        let messageType = entry.type ?? entry.messageType ?? ""
        let modelName = entry.model ?? entry.message?.model ?? ""
        
        print("- 提取的messageType: '\(messageType)'")
        print("- 提取的modelName: '\(modelName)'")
        
        print("\n❌ 问题分析:")
        print("- JSONL中type='assistant'，但这不是模型名称")
        print("- 真正的模型名称在message.model='claude-sonnet-4-20250514'")
        print("- 当前逻辑正确提取了modelName='\(modelName)'")
        
        if modelName == "claude-sonnet-4-20250514" {
            print("✅ 模型提取逻辑是正确的！")
            print("🤔 问题可能在其他地方...")
        } else {
            print("❌ 模型提取逻辑有问题！")
        }
        
    } catch {
        print("解析失败: \(error)")
    }
} else {
    print("JSON数据创建失败")
}

print("\n🔍 检查数据库中的实际数据...")
print("建议运行SQL查询来查看实际存储的数据")
