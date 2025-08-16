#!/usr/bin/env swift

import Foundation

// 测试 JSONL 条目
let jsonString = """
{
  "parentUuid": "c9f1de08-6bc6-489b-a067-607b909a8731",
  "isSidechain": false,
  "userType": "external",
  "cwd": "/Users/xiaozhaodong/.claude",
  "sessionId": "58280350-74c0-43a5-a960-419cda036497",
  "version": "1.0.56",
  "gitBranch": "",
  "type": "assistant",
  "timestamp": "2025-07-20T05:46:25.208Z",
  "message": {
    "id": "chatcmpl-20250720132640414526753dBNqGU2F",
    "type": "message",
    "role": "assistant",
    "content": [
      {
        "type": "text",
        "text": "你好！我能为你做些什么？"
      }
    ],
    "model": "gemini-2.5-pro",
    "stop_reason": "stop",
    "stop_sequence": null,
    "usage": {
      "input_tokens": 11060,
      "output_tokens": 37
    }
  },
  "uuid": "f8734228-a3f1-4e70-9a26-f885cc4846ea"
}
"""

// 定义数据结构
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
}

// 解析 JSON
let decoder = JSONDecoder()
let jsonData = jsonString.data(using: .utf8)!

do {
    let entry = try decoder.decode(RawJSONLEntry.self, from: jsonData)
    
    print("解析结果：")
    print("  外层 type: \(entry.type ?? "nil")")
    print("  外层 model: \(entry.model ?? "nil")")
    print("  message.model: \(entry.message?.model ?? "nil")")
    print("  sessionId: \(entry.sessionId ?? "nil")")
    
    // 模拟实际的模型名称提取逻辑
    let modelName = entry.model ?? entry.message?.model ?? ""
    print("\n最终提取的模型名称: '\(modelName)'")
    
    // 检查为什么会变成 "assistant"
    if modelName.isEmpty || modelName == "unknown" {
        print("⚠️ 模型名称为空或未知")
    } else if modelName == "assistant" {
        print("❌ 错误：模型名称被识别为 'assistant'")
        print("   这可能是因为外层的 type 字段被错误地当作了 model")
    } else if modelName == "gemini-2.5-pro" {
        print("✅ 正确：模型名称被正确识别为 'gemini-2.5-pro'")
    }
    
} catch {
    print("解析错误: \(error)")
}