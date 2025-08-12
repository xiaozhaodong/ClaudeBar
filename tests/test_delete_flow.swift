#!/usr/bin/env swift

import Foundation
import SQLite3

print("=== 模拟应用程序删除流程测试 ===")

// 连接数据库
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDir = appSupport.appendingPathComponent("ClaudeBar")
let dbPath = appDir.appendingPathComponent("configs.db").path

var db: OpaquePointer?
guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
    print("❌ 无法打开数据库")
    exit(1)
}

// 1. 显示当前配置
print("=== 当前配置列表 ===")
let selectSQL = "SELECT id, name, base_url FROM api_configs ORDER BY name"
var statement: OpaquePointer?

if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
    while sqlite3_step(statement) == SQLITE_ROW {
        let id = sqlite3_column_int64(statement, 0)
        let namePtr = sqlite3_column_text(statement, 1)
        let name = namePtr != nil ? String(cString: namePtr!) : ""
        let urlPtr = sqlite3_column_text(statement, 2)
        let url = urlPtr != nil ? String(cString: urlPtr!) : ""
        
        print("📋 [\(id)] \(name): \(url)")
    }
}
sqlite3_finalize(statement)

// 2. 模拟 getConfig(byName:) 查找
let targetName = "test-delete"
print("\n=== 查找配置: \(targetName) ===")

let findSQL = "SELECT id, name, base_url, auth_token, is_active, created_at, updated_at FROM api_configs WHERE name = ? LIMIT 1"
var findStatement: OpaquePointer?

if sqlite3_prepare_v2(db, findSQL, -1, &findStatement, nil) == SQLITE_OK {
    sqlite3_bind_text(findStatement, 1, targetName, -1, nil)
    
    if sqlite3_step(findStatement) == SQLITE_ROW {
        let id = sqlite3_column_int64(findStatement, 0)
        let namePtr = sqlite3_column_text(findStatement, 1)
        let name = namePtr != nil ? String(cString: namePtr!) : ""
        
        print("✅ 找到配置: ID=\(id), Name=\(name)")
        
        // 3. 模拟删除操作
        print("\n=== 删除配置 ID=\(id) ===")
        let deleteSQL = "DELETE FROM api_configs WHERE id = ?"
        var deleteStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_int64(deleteStatement, 1, id)
            
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                let changes = sqlite3_changes(db)
                print("✅ 删除成功，影响行数: \(changes)")
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("❌ 删除失败: \(errmsg)")
            }
        }
        sqlite3_finalize(deleteStatement)
        
    } else {
        print("❌ 未找到配置: \(targetName)")
    }
}
sqlite3_finalize(findStatement)

// 4. 显示删除后的配置
print("\n=== 删除后配置列表 ===")
if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
    while sqlite3_step(statement) == SQLITE_ROW {
        let id = sqlite3_column_int64(statement, 0)
        let namePtr = sqlite3_column_text(statement, 1)
        let name = namePtr != nil ? String(cString: namePtr!) : ""
        let urlPtr = sqlite3_column_text(statement, 2)
        let url = urlPtr != nil ? String(cString: urlPtr!) : ""
        
        print("📋 [\(id)] \(name): \(url)")
    }
}
sqlite3_finalize(statement)

sqlite3_close(db)
print("\n=== 测试完成 ===")