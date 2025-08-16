#!/usr/bin/env swift

import Foundation
import SQLite3

// MARK: - 数据模型（简化版）

struct TestUsageEntry {
    let timestamp: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let sessionId: String
    let messageType: String
    let dateString: String
}

struct RawJSONLEntry: Codable {
    let type: String?
    let model: String?
    let usage: UsageData?
    let message: MessageData?
    let timestamp: String?
    let sessionId: String?
    
    private enum CodingKeys: String, CodingKey {
        case type
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
    
    func toUsageEntry() -> TestUsageEntry? {
        // 关键的解析逻辑 - 与项目代码完全一致
        let messageType = type ?? ""
        let usageData = usage ?? message?.usage
        
        // 获取 tokens
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        
        // 跳过没有使用数据的条目
        if inputTokens == 0 && outputTokens == 0 {
            return nil
        }
        
        // 关键：模型名称提取逻辑
        print("  [DEBUG] 解析条目:")
        print("    - type字段: '\(type ?? "nil")'")
        print("    - model字段: '\(model ?? "nil")'") 
        print("    - message.model字段: '\(message?.model ?? "nil")'")
        
        let modelName = model ?? message?.model ?? ""
        print("    - 最终模型名: '\(modelName)'")
        
        // 过滤无效模型
        if modelName.isEmpty || modelName == "unknown" || modelName == "<synthetic>" {
            print("    - 结果: 被过滤（无效模型）")
            return nil
        }
        
        // 时间戳处理
        let finalTimestamp = timestamp ?? Date().toISOString()
        let dateString = String(finalTimestamp.prefix(10))
        
        print("    - 结果: 保留记录，model='\(modelName)'")
        
        return TestUsageEntry(
            timestamp: finalTimestamp,
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            sessionId: sessionId ?? "unknown",
            messageType: messageType,
            dateString: dateString
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

// MARK: - 简化的数据库管理

class SimpleDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    
    init(path: String) {
        self.dbPath = path
        
        // 删除旧数据库
        try? FileManager.default.removeItem(atPath: dbPath)
        
        // 创建新数据库
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ 无法创建数据库")
            exit(1)
        }
        
        createTable()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func createTable() {
        let createSQL = """
        CREATE TABLE usage_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            model TEXT NOT NULL,
            input_tokens INTEGER DEFAULT 0,
            output_tokens INTEGER DEFAULT 0,
            session_id TEXT,
            message_type TEXT,
            date_string TEXT
        )
        """
        
        if sqlite3_exec(db, createSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ 无法创建表")
            exit(1)
        }
    }
    
    func insertEntry(_ entry: TestUsageEntry) -> Bool {
        let insertSQL = """
        INSERT INTO usage_entries 
        (timestamp, model, input_tokens, output_tokens, session_id, message_type, date_string)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 绑定参数 - 使用 SQLITE_TRANSIENT 确保字符串被复制
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        entry.timestamp.withCString { 
            sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) 
        }
        entry.model.withCString { 
            sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) 
        }
        sqlite3_bind_int(statement, 3, Int32(entry.inputTokens))
        sqlite3_bind_int(statement, 4, Int32(entry.outputTokens))
        entry.sessionId.withCString { 
            sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) 
        }
        entry.messageType.withCString { 
            sqlite3_bind_text(statement, 6, $0, -1, SQLITE_TRANSIENT) 
        }
        entry.dateString.withCString { 
            sqlite3_bind_text(statement, 7, $0, -1, SQLITE_TRANSIENT) 
        }
        
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    func getModelStats() -> [(model: String, count: Int)] {
        let sql = "SELECT model, COUNT(*) as count FROM usage_entries GROUP BY model ORDER BY count DESC"
        var statement: OpaquePointer?
        var results: [(String, Int)] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let model = String(cString: sqlite3_column_text(statement, 0))
                let count = Int(sqlite3_column_int(statement, 1))
                results.append((model, count))
            }
        }
        sqlite3_finalize(statement)
        
        return results
    }
}

// MARK: - 主程序

print("🚀 开始调试 gemini-2.5-pro 模型识别问题")
print("=" * 50)

// 目标文件
let jsonlPath = "/Users/xiaozhaodong/.claude/projects/-Users-xiaozhaodong--claude/58280350-74c0-43a5-a960-419cda036497.jsonl"

// 创建测试数据库
let dbPath = FileManager.default.currentDirectoryPath + "/test_gemini_debug.db"
let database = SimpleDatabase(path: dbPath)
print("✅ 创建测试数据库: \(dbPath)\n")

// 读取并解析 JSONL 文件
print("📄 读取文件: \(jsonlPath)")

guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonlPath)),
      let content = String(data: data, encoding: .utf8) else {
    print("❌ 无法读取文件")
    exit(1)
}

let lines = content.components(separatedBy: .newlines)
    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    .filter { !$0.isEmpty }

print("📊 文件包含 \(lines.count) 条记录\n")

// 解析每一行
let decoder = JSONDecoder()
var totalParsed = 0
var totalInserted = 0
var geminiCount = 0
var assistantCount = 0

print("开始解析...")
print("-" * 50)

for (index, line) in lines.enumerated() {
    guard let jsonData = line.data(using: .utf8) else { continue }
    
    do {
        let rawEntry = try decoder.decode(RawJSONLEntry.self, from: jsonData)
        
        // 只处理有 gemini 相关的条目
        if rawEntry.message?.model?.contains("gemini") == true ||
           rawEntry.model?.contains("gemini") == true ||
           rawEntry.type == "assistant" {
            
            print("\n条目 #\(index + 1):")
            
            if let entry = rawEntry.toUsageEntry() {
                totalParsed += 1
                
                if database.insertEntry(entry) {
                    totalInserted += 1
                    
                    if entry.model.contains("gemini") {
                        geminiCount += 1
                    } else if entry.model == "assistant" {
                        assistantCount += 1
                        print("    ⚠️ 警告: 模型被存储为 'assistant'!")
                    }
                }
            }
        }
    } catch {
        // 忽略解析错误
    }
}

print("\n" + "=" * 50)
print("📊 解析统计:")
print("  - 总解析记录: \(totalParsed)")
print("  - 成功插入: \(totalInserted)")
print("  - Gemini 记录: \(geminiCount)")
print("  - Assistant 记录: \(assistantCount)")

print("\n📈 数据库中的模型分布:")
let stats = database.getModelStats()
for (model, count) in stats {
    print("  - \(model): \(count) 条")
}

if assistantCount > 0 {
    print("\n❌ 发现问题: 有 \(assistantCount) 条记录被错误地识别为 'assistant'")
    print("   这说明解析逻辑存在问题")
} else if geminiCount > 0 {
    print("\n✅ 解析正常: 所有 gemini 模型都被正确识别")
} else {
    print("\n⚠️ 未找到 gemini 相关记录")
}

print("\n💡 测试数据库已创建: \(dbPath)")
print("   可以使用 sqlite3 查看详细数据:")
print("   sqlite3 \(dbPath) \"SELECT * FROM usage_entries WHERE model LIKE '%gemini%' OR model = 'assistant' LIMIT 10\"")

// 辅助函数
func *(left: String, right: Int) -> String {
    return String(repeating: left, count: right)
}