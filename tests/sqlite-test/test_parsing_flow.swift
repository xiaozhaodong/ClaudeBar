#!/usr/bin/env swift

import Foundation

// 创建一个临时JSONL文件来测试
let testJSONL = """
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"你好"}]},"sessionId":"58280350-74c0-43a5-a960-419cda036497","timestamp":"2025-07-20T05:26:36.054Z"}
{"type":"assistant","timestamp":"2025-07-20T05:46:25.208Z","message":{"id":"chatcmpl-20250720132640414526753dBNqGU2F","type":"message","role":"assistant","content":[{"type":"text","text":"你好！我能为你做些什么？"}],"model":"gemini-2.5-pro","stop_reason":"stop","stop_sequence":null,"usage":{"input_tokens":11060,"output_tokens":37}},"sessionId":"58280350-74c0-43a5-a960-419cda036497"}
{"type":"assistant","timestamp":"2025-07-20T05:46:25.208Z","message":{"id":"chatcmpl-20250720132721556854052wNjGBhI3","type":"message","role":"assistant","model":"gemini-2.5-pro","usage":{"input_tokens":11227,"output_tokens":379}},"sessionId":"58280350-74c0-43a5-a960-419cda036497"}
"""

// 定义数据结构（与项目保持一致）
struct RawJSONLEntry: Codable {
    let type: String?
    let messageType: String?
    let model: String?
    let usage: UsageData?
    let message: MessageData?
    let timestamp: String?
    let sessionId: String?
    
    private enum CodingKeys: String, CodingKey {
        case type
        case messageType = "message_type"
        case model
        case usage
        case message
        case timestamp
        case sessionId
    }
    
    struct UsageData: Codable {
        let inputTokens: Int?
        let outputTokens: Int?
        
        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
    
    struct MessageData: Codable {
        let usage: UsageData?
        let model: String?
    }
    
    func toUsageEntry() -> (model: String, type: String, messageType: String)? {
        // 模拟项目的解析逻辑
        let messageType = type ?? self.messageType ?? ""
        let usageData = usage ?? message?.usage
        
        // 计算总量
        let totalTokens = (usageData?.inputTokens ?? 0) + (usageData?.outputTokens ?? 0)
        
        // 检查是否有有效数据
        if totalTokens == 0 && sessionId == nil {
            return nil
        }
        
        // 关键：这里是模型名称的提取逻辑
        let modelName = model ?? message?.model ?? ""
        
        // 过滤无效模型
        if modelName.isEmpty || modelName == "unknown" || modelName == "<synthetic>" {
            return nil
        }
        
        return (model: modelName, type: type ?? "", messageType: messageType)
    }
}

// 测试解析
let lines = testJSONL.components(separatedBy: .newlines).filter { !$0.isEmpty }
let decoder = JSONDecoder()

print("===== 解析测试 =====\n")

for (index, line) in lines.enumerated() {
    print("第 \(index + 1) 条记录：")
    
    guard let jsonData = line.data(using: .utf8) else {
        print("  ❌ 无法转换为 Data\n")
        continue
    }
    
    do {
        let entry = try decoder.decode(RawJSONLEntry.self, from: jsonData)
        
        print("  原始数据：")
        print("    type: \(entry.type ?? "nil")")
        print("    model: \(entry.model ?? "nil")")
        print("    message.model: \(entry.message?.model ?? "nil")")
        print("    sessionId: \(entry.sessionId ?? "nil")")
        
        if let result = entry.toUsageEntry() {
            print("  解析结果：")
            print("    最终模型: \(result.model)")
            print("    类型: \(result.type)")
            print("    消息类型: \(result.messageType)")
            
            if result.model == "assistant" {
                print("  ❌ 错误：模型被识别为 'assistant'！")
            } else if result.model == "gemini-2.5-pro" {
                print("  ✅ 正确：模型正确识别为 'gemini-2.5-pro'")
            }
        } else {
            print("  ⚠️ 记录被过滤")
        }
        
    } catch {
        print("  ❌ 解析错误: \(error)")
    }
    
    print()
}

print("\n===== 总结 =====")
print("测试完成。如果有条目被错误地识别为 'assistant'，")
print("那说明解析逻辑有问题。否则问题可能在数据导入阶段。")