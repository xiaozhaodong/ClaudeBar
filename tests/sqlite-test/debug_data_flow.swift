import Foundation

// 模拟测试文件中的数据结构
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
    
    func toTestUsageEntry() -> (modelName: String, messageType: String) {
        // 完全复制测试文件的逻辑
        let messageType = type ?? self.messageType ?? ""
        let modelName = model ?? message?.model ?? ""
        
        return (modelName: modelName, messageType: messageType)
    }
}

// 使用你提供的JSONL文件中的实际数据
let jsonString = """
{
    "type": "assistant",
    "message": {
        "model": "gemini-2.5-pro"
    }
}
"""

print("🔍 追踪数据流：从JSONL到数据库")
print(String(repeating: "=", count: 60))

if let jsonData = jsonString.data(using: .utf8) {
    do {
        let rawEntry = try JSONDecoder().decode(TestRawJSONLEntry.self, from: jsonData)
        
        print("1️⃣ JSONL解析结果:")
        print("   - type: '\(rawEntry.type ?? "nil")'")
        print("   - messageType: '\(rawEntry.messageType ?? "nil")'")
        print("   - model (顶级): '\(rawEntry.model ?? "nil")'")
        print("   - message.model: '\(rawEntry.message?.model ?? "nil")'")
        
        let result = rawEntry.toTestUsageEntry()
        
        print("\n2️⃣ toUsageEntry转换结果:")
        print("   - 提取的modelName: '\(result.modelName)'")
        print("   - 提取的messageType: '\(result.messageType)'")
        
        print("\n3️⃣ TestUsageEntry创建:")
        print("   - model字段将设置为: '\(result.modelName)'")
        print("   - messageType字段将设置为: '\(result.messageType)'")
        
        print("\n4️⃣ 数据库插入参数绑定:")
        print("   - 参数2 (model字段): '\(result.modelName)'")
        print("   - 参数13 (message_type字段): '\(result.messageType)'")
        
        print("\n❗ 问题分析:")
        if result.modelName == "gemini-2.5-pro" && result.messageType == "assistant" {
            print("✅ 数据流逻辑正确!")
            print("   - model应该存储: 'gemini-2.5-pro'")
            print("   - message_type应该存储: 'assistant'")
            print("")
            print("🤔 如果数据库中model字段是'assistant'，问题可能在:")
            print("   1. 数据库表结构定义错误")
            print("   2. 其他代码路径覆盖了数据")
            print("   3. 数据库查询时字段混淆")
            print("   4. 并发写入导致的数据竞争")
        } else {
            print("❌ 数据流逻辑有问题!")
        }
        
    } catch {
        print("❌ JSON解析失败: \(error)")
    }
} else {
    print("❌ JSON数据创建失败")
}
