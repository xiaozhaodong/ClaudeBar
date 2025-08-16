#!/usr/bin/env swift

import Foundation
import SQLite3

// 数据库路径
let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let dbDirectory = appSupportPath.appendingPathComponent("ClaudeBar")
let dbPath = dbDirectory.appendingPathComponent("usage_statistics.db").path

print("🧪 开始测试统计生成（ID重置）...")
print("📄 数据库位置: \(dbPath)")

// 数据库连接
var db: OpaquePointer?

func executeSQL(_ sql: String) throws {
    var statement: OpaquePointer?
    
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        throw NSError(domain: "SQLError", code: 1, userInfo: [NSLocalizedDescriptionKey: "准备语句失败: \(errmsg)"])
    }
    
    defer { sqlite3_finalize(statement) }
    
    guard sqlite3_step(statement) == SQLITE_DONE else {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        throw NSError(domain: "SQLError", code: 2, userInfo: [NSLocalizedDescriptionKey: "执行语句失败: \(errmsg)"])
    }
}

// 连接数据库
guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
    print("❌ 无法打开数据库")
    exit(1)
}

defer { sqlite3_close(db) }

print("✅ 数据库连接成功")

do {
    // 检查原始状态
    print("\n📊 检查原始统计表状态:")
    var statement: OpaquePointer?
    let query = "SELECT id, date_string FROM daily_statistics ORDER BY id LIMIT 5"
    
    if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
        print("原始日报表前5条:")
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int(statement, 0)
            let dateString = String(cString: sqlite3_column_text(statement, 1))
            print("  ID: \(id), 日期: \(dateString)")
        }
        sqlite3_finalize(statement)
    }
    
    // 重新生成统计
    print("\n🔄 开始重新生成日报统计...")
    
    // 1. 删除现有数据
    try executeSQL("DELETE FROM daily_statistics")
    print("✅ 删除现有日报数据")
    
    // 2. 重置序列
    try executeSQL("DELETE FROM sqlite_sequence WHERE name='daily_statistics'")
    try executeSQL("INSERT INTO sqlite_sequence (name, seq) VALUES ('daily_statistics', 0)")
    print("✅ 重置日报表ID序列为0")
    
    // 3. 重新生成统计
    let insertSQL = """
    INSERT INTO daily_statistics (
        date_string, total_cost, total_tokens, input_tokens, output_tokens,
        cache_creation_tokens, cache_read_tokens, session_count, request_count,
        models_used, last_updated
    )
    SELECT 
        date_string,
        SUM(cost) as total_cost,
        SUM(total_tokens) as total_tokens,
        SUM(input_tokens) as input_tokens,
        SUM(output_tokens) as output_tokens,
        SUM(cache_creation_tokens) as cache_creation_tokens,
        SUM(cache_read_tokens) as cache_read_tokens,
        COUNT(DISTINCT session_id) as session_count,
        COUNT(*) as request_count,
        GROUP_CONCAT(DISTINCT model) as models_used,
        CURRENT_TIMESTAMP as last_updated
    FROM usage_entries
    GROUP BY date_string
    ORDER BY date_string
    """
    
    try executeSQL(insertSQL)
    print("✅ 重新生成日报统计数据")
    
    // 4. 检查结果
    print("\n📊 检查重新生成后的统计表状态:")
    
    if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
        print("重新生成后日报表前5条:")
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int(statement, 0)
            let dateString = String(cString: sqlite3_column_text(statement, 1))
            print("  ID: \(id), 日期: \(dateString)")
        }
        sqlite3_finalize(statement)
    }
    
    // 5. 检查sqlite_sequence状态
    let seqQuery = "SELECT name, seq FROM sqlite_sequence WHERE name='daily_statistics'"
    if sqlite3_prepare_v2(db, seqQuery, -1, &statement, nil) == SQLITE_OK {
        print("\nsqlite_sequence状态:")
        while sqlite3_step(statement) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(statement, 0))
            let seq = sqlite3_column_int(statement, 1)
            print("  表名: \(name), 当前序列: \(seq)")
        }
        sqlite3_finalize(statement)
    }
    
    print("\n✅ 统计生成测试完成！")
    
} catch {
    print("❌ 测试失败: \(error)")
    exit(1)
}