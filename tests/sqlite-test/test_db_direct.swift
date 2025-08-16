#!/usr/bin/env swift

import Foundation
import SQLite3

// 简化的测试脚本，直接测试数据库读取
print("🔍 测试数据库数据读取...")

let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let dbPath = appSupport.appendingPathComponent("ClaudeBar/usage_statistics.db").path

print("📁 数据库路径: \(dbPath)")

// 检查文件是否存在
if !FileManager.default.fileExists(atPath: dbPath) {
    print("❌ 数据库文件不存在")
    exit(1)
}

// 打开数据库
var db: OpaquePointer?
if sqlite3_open(dbPath, &db) != SQLITE_OK {
    print("❌ 无法打开数据库")
    exit(1)
}

defer { sqlite3_close(db) }

// 执行简单的统计查询
let sql = """
SELECT 
    COUNT(*) as total_requests,
    COUNT(DISTINCT session_id) as total_sessions,
    SUM(cost) as total_cost
FROM usage_entries
"""

var statement: OpaquePointer?
if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
    let errmsg = String(cString: sqlite3_errmsg(db)!)
    print("❌ SQL 准备失败: \(errmsg)")
    exit(1)
}

defer { sqlite3_finalize(statement) }

if sqlite3_step(statement) == SQLITE_ROW {
    let totalRequests = sqlite3_column_int(statement, 0)
    let totalSessions = sqlite3_column_int(statement, 1)
    let totalCost = sqlite3_column_double(statement, 2)
    
    print("✅ 数据库查询成功:")
    print("   总请求数: \(totalRequests)")
    print("   总会话数: \(totalSessions)")
    print("   总成本: $\(String(format: "%.4f", totalCost))")
    
    // 验证数据库有数据的逻辑
    let hasData = totalRequests > 0 || totalSessions > 0
    print("   数据库有数据: \(hasData)")
    
    if hasData {
        print("🎯 数据库中有数据，应该优先使用数据库而不是降级到JSONL")
    } else {
        print("⚠️ 数据库中无有效数据，会降级到JSONL解析")
    }
    
} else {
    print("❌ 查询执行失败")
    exit(1)
}

// 测试按模型统计
print("\n📊 测试按模型统计:")
let modelSQL = """
SELECT 
    model,
    COUNT(*) as count,
    SUM(cost) as total_cost
FROM usage_entries 
GROUP BY model 
ORDER BY total_cost DESC 
LIMIT 5
"""

var modelStatement: OpaquePointer?
if sqlite3_prepare_v2(db, modelSQL, -1, &modelStatement, nil) == SQLITE_OK {
    defer { sqlite3_finalize(modelStatement) }
    
    while sqlite3_step(modelStatement) == SQLITE_ROW {
        guard let modelPtr = sqlite3_column_text(modelStatement, 0) else { continue }
        let model = String(cString: modelPtr)
        let count = sqlite3_column_int(modelStatement, 1)
        let cost = sqlite3_column_double(modelStatement, 2)
        
        print("   \(model): \(count) 次, $\(String(format: "%.4f", cost))")
    }
} else {
    print("❌ 模型统计查询失败")
}

print("\n🎯 结论: 数据库功能正常，如果混合服务还是降级，问题可能在于:")
print("   1. 数据库类编译失败")
print("   2. 异常处理逻辑有问题") 
print("   3. 日志级别设置导致debug信息不显示")