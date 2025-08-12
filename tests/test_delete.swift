#!/usr/bin/env swift

import Foundation
import SQLite3

print("=== 测试 SQLite 删除功能 ===")

// 连接数据库
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDir = appSupport.appendingPathComponent("ClaudeBar")
let dbPath = appDir.appendingPathComponent("configs.db").path

var db: OpaquePointer?
guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
    print("❌ 无法打开数据库")
    exit(1)
}

// 1. 清理空记录
let cleanupSQL = "DELETE FROM api_configs WHERE name = '' OR name IS NULL"
if sqlite3_exec(db, cleanupSQL, nil, nil, nil) == SQLITE_OK {
    print("✅ 清理空记录成功")
} else {
    let errmsg = String(cString: sqlite3_errmsg(db)!)
    print("⚠️ 清理空记录失败: \(errmsg)")
}

// 2. 显示当前配置
print("\n=== 当前配置列表 ===")
let selectSQL = "SELECT id, name, base_url, is_active FROM api_configs ORDER BY name"
var statement: OpaquePointer?

if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
    while sqlite3_step(statement) == SQLITE_ROW {
        let id = sqlite3_column_int64(statement, 0)
        let namePtr = sqlite3_column_text(statement, 1)
        let name = namePtr != nil ? String(cString: namePtr!) : ""
        let urlPtr = sqlite3_column_text(statement, 2)
        let url = urlPtr != nil ? String(cString: urlPtr!) : ""
        let isActive = sqlite3_column_int(statement, 3) == 1
        let status = isActive ? " ✅" : ""
        
        print("📋 [\(id)] \(name): \(url)\(status)")
    }
}
sqlite3_finalize(statement)

// 3. 测试删除一个配置（删除 yourapi）
print("\n=== 测试删除配置 ===")
let deleteSQL = "DELETE FROM api_configs WHERE name = ?"
var deleteStatement: OpaquePointer?

if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStatement, nil) == SQLITE_OK {
    sqlite3_bind_text(deleteStatement, 1, "yourapi", -1, nil)
    
    if sqlite3_step(deleteStatement) == SQLITE_DONE {
        let changes = sqlite3_changes(db)
        print("✅ 删除成功，影响行数: \(changes)")
    } else {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        print("❌ 删除失败: \(errmsg)")
    }
}
sqlite3_finalize(deleteStatement)

// 4. 显示删除后的配置
print("\n=== 删除后配置列表 ===")
if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
    while sqlite3_step(statement) == SQLITE_ROW {
        let id = sqlite3_column_int64(statement, 0)
        let namePtr = sqlite3_column_text(statement, 1)
        let name = namePtr != nil ? String(cString: namePtr!) : ""
        let urlPtr = sqlite3_column_text(statement, 2)
        let url = urlPtr != nil ? String(cString: urlPtr!) : ""
        let isActive = sqlite3_column_int(statement, 3) == 1
        let status = isActive ? " ✅" : ""
        
        print("📋 [\(id)] \(name): \(url)\(status)")
    }
}
sqlite3_finalize(statement)

sqlite3_close(db)
print("\n=== 测试完成 ===")