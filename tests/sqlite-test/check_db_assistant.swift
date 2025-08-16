import Foundation
import SQLite3

let dbPath = "/Users/xiaozhaodong/Library/Application Support/ClaudeBar/usage_statistics.db"
var db: OpaquePointer?

if sqlite3_open(dbPath, &db) == SQLITE_OK {
    print("🔍 检查数据库中模型为'assistant'的记录")
    print(String(repeating: "=", count: 60))
    
    // 查询模型为 "assistant" 的记录
    let query = """
    SELECT timestamp, model, date_string, input_tokens, output_tokens, cost, message_type
    FROM usage_entries 
    WHERE model = 'assistant' 
    ORDER BY timestamp 
    LIMIT 10
    """
    
    var statement: OpaquePointer?
    
    if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
        print("找到模型为'assistant'的记录:")
        print("时间戳\t\t\t\t模型\t\t日期\t\t输入Token\t输出Token\t成本\t\t消息类型")
        print(String(repeating: "-", count: 120))
        
        var count = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            let timestamp = String(cString: sqlite3_column_text(statement, 0))
            let model = String(cString: sqlite3_column_text(statement, 1))
            let dateString = String(cString: sqlite3_column_text(statement, 2))
            let inputTokens = sqlite3_column_int64(statement, 3)
            let outputTokens = sqlite3_column_int64(statement, 4)
            let cost = sqlite3_column_double(statement, 5)
            let messageType = String(cString: sqlite3_column_text(statement, 6))
            
            print("\(timestamp)\t\(model)\t\t\(dateString)\t\(inputTokens)\t\t\(outputTokens)\t\t$\(String(format: "%.6f", cost))\t\t\(messageType)")
            count += 1
        }
        
        if count == 0 {
            print("❌ 没有找到模型为'assistant'的记录")
        } else {
            print("\n✅ 找到 \(count) 条模型为'assistant'的记录")
        }
    } else {
        print("❌ 查询准备失败")
    }
    
    sqlite3_finalize(statement)
    
    // 查询2025年7月19-20日的所有记录，看看有哪些模型
    print("\n🔍 检查2025年7月19-20日的所有模型")
    print(String(repeating: "=", count: 60))
    
    let dateQuery = """
    SELECT model, COUNT(*) as count, date_string, 
           SUM(input_tokens) as total_input, SUM(output_tokens) as total_output
    FROM usage_entries 
    WHERE date_string IN ('2025-07-19', '2025-07-20')
    GROUP BY model, date_string
    ORDER BY date_string, count DESC
    """
    
    if sqlite3_prepare_v2(db, dateQuery, -1, &statement, nil) == SQLITE_OK {
        print("模型\t\t\t\t数量\t日期\t\t输入Token\t输出Token")
        print(String(repeating: "-", count: 80))
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let model = String(cString: sqlite3_column_text(statement, 0))
            let count = sqlite3_column_int64(statement, 1)
            let dateString = String(cString: sqlite3_column_text(statement, 2))
            let totalInput = sqlite3_column_int64(statement, 3)
            let totalOutput = sqlite3_column_int64(statement, 4)
            
            print("\(model)\t\t\(count)\t\(dateString)\t\(totalInput)\t\t\(totalOutput)")
        }
    }
    
    sqlite3_finalize(statement)
    sqlite3_close(db)
} else {
    print("❌ 无法打开数据库: \(dbPath)")
}
