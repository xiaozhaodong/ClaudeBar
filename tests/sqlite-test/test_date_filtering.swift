#!/usr/bin/env swift

import Foundation
import SQLite3

// 测试日期过滤功能
func testDateFiltering() {
    print("🔍 测试日期过滤功能...")
    
    // 数据库路径
    let dbPath = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Application Support/ClaudeBar/usage_statistics.db")
        .path
    
    var db: OpaquePointer?
    guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
        print("❌ 无法打开数据库")
        return
    }
    
    print("✅ 数据库连接成功")
    
    // 1. 检查数据库中的时间戳格式
    print("\n📅 检查数据库中的时间戳格式:")
    let sampleSQL = "SELECT timestamp FROM usage_entries ORDER BY timestamp DESC LIMIT 5"
    var statement: OpaquePointer?
    
    if sqlite3_prepare_v2(db, sampleSQL, -1, &statement, nil) == SQLITE_OK {
        var count = 0
        while sqlite3_step(statement) == SQLITE_ROW && count < 5 {
            if let timestampPtr = sqlite3_column_text(statement, 0) {
                let timestamp = String(cString: timestampPtr)
                print("  \(count + 1): \(timestamp)")
                count += 1
            }
        }
        sqlite3_finalize(statement)
    }
    
    // 2. 测试最近7天的查询条件
    print("\n📊 测试最近7天查询条件:")
    let calendar = Calendar.current
    let today = Date()
    let last7Days = calendar.date(byAdding: .day, value: -7, to: today)!
    
    let iso8601Formatter = ISO8601DateFormatter()
    let startDateString = iso8601Formatter.string(from: last7Days)
    
    print("  当前时间: \(iso8601Formatter.string(from: today))")
    print("  7天前时间: \(startDateString)")
    
    // 3. 使用查询条件测试
    let testSQL = """
    SELECT COUNT(*) as total_count,
           COUNT(CASE WHEN timestamp >= ? THEN 1 END) as filtered_count
    FROM usage_entries
    """
    
    if sqlite3_prepare_v2(db, testSQL, -1, &statement, nil) == SQLITE_OK {
        startDateString.withCString { cString in
            sqlite3_bind_text(statement, 1, cString, -1, nil)
        }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            let totalCount = sqlite3_column_int(statement, 0)
            let filteredCount = sqlite3_column_int(statement, 1)
            
            print("  总记录数: \(totalCount)")
            print("  符合7天条件的记录数: \(filteredCount)")
            print("  过滤率: \(Double(filteredCount) / Double(totalCount) * 100)%")
            
            if filteredCount == totalCount {
                print("⚠️  问题: 过滤后记录数等于总记录数，说明日期过滤没有生效")
            } else if filteredCount == 0 {
                print("⚠️  问题: 没有找到符合条件的记录，可能是日期格式不匹配")
            } else {
                print("✅ 日期过滤正常工作")
            }
        }
        sqlite3_finalize(statement)
    }
    
    // 4. 测试不同的日期格式
    print("\n🧪 测试不同日期格式的匹配:")
    let testFormats = [
        ("ISO8601", iso8601Formatter.string(from: last7Days)),
        ("简单格式", "2025-08-08T22:00:00"),
        ("SQLite格式", "datetime('now', '-7 days')")
    ]
    
    for (name, dateStr) in testFormats {
        var testStatement: OpaquePointer?
        let formatTestSQL = "SELECT COUNT(*) FROM usage_entries WHERE timestamp >= ?"
        
        if sqlite3_prepare_v2(db, formatTestSQL, -1, &testStatement, nil) == SQLITE_OK {
            if name == "SQLite格式" {
                // SQLite 内置函数，直接绑定
                sqlite3_bind_text(testStatement, 1, dateStr, -1, nil)
            } else {
                dateStr.withCString { cString in
                    sqlite3_bind_text(testStatement, 1, cString, -1, nil)
                }
            }
            
            if sqlite3_step(testStatement) == SQLITE_ROW {
                let count = sqlite3_column_int(testStatement, 0)
                print("  \(name) (\(dateStr)): \(count) 条记录")
            }
            sqlite3_finalize(testStatement)
        }
    }
    
    // 5. 直接测试SQLite的datetime函数
    print("\n⚡ 测试SQLite内置datetime函数:")
    let sqliteTestSQL = "SELECT COUNT(*) FROM usage_entries WHERE timestamp >= datetime('now', '-7 days')"
    
    if sqlite3_prepare_v2(db, sqliteTestSQL, -1, &statement, nil) == SQLITE_OK {
        if sqlite3_step(statement) == SQLITE_ROW {
            let count = sqlite3_column_int(statement, 0)
            print("  使用SQLite datetime('now', '-7 days'): \(count) 条记录")
        }
        sqlite3_finalize(statement)
    }
    
    sqlite3_close(db)
    print("\n🎯 测试完成!")
}

// 运行测试
testDateFiltering()