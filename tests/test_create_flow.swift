#!/usr/bin/env swift

import Foundation
import SQLite3

print("=== 测试新建配置流程 ===")

// 连接数据库
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDir = appSupport.appendingPathComponent("ClaudeBar")
let dbPath = appDir.appendingPathComponent("configs.db").path

var db: OpaquePointer?
guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
    print("❌ 无法打开数据库")
    exit(1)
}

// 1. 显示创建前的配置
print("=== 创建前配置列表 ===")
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

// 2. 测试创建新配置
print("\n=== 创建新配置 ===")
let testConfigName = "test-create-\(Int(Date().timeIntervalSince1970))"
let testBaseURL = "https://api.anthropic.com"
let testToken = "sk-test-token-123456"

print("配置信息:")
print("  Name: \(testConfigName)")
print("  BaseURL: \(testBaseURL)")
print("  Token: \(testToken)")

let insertSQL = "INSERT INTO api_configs (name, base_url, auth_token, is_active) VALUES (?, ?, ?, ?)"
var insertStatement: OpaquePointer?

if sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil) == SQLITE_OK {
    // 使用正确的字符串绑定方式
    testConfigName.withCString { cString in
        sqlite3_bind_text(insertStatement, 1, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
    
    testBaseURL.withCString { cString in
        sqlite3_bind_text(insertStatement, 2, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
    
    testToken.withCString { cString in
        sqlite3_bind_text(insertStatement, 3, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
    
    sqlite3_bind_int(insertStatement, 4, 0) // is_active = false
    
    if sqlite3_step(insertStatement) == SQLITE_DONE {
        let newId = sqlite3_last_insert_rowid(db)
        print("✅ 配置创建成功，新ID: \(newId)")
    } else {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        print("❌ 创建配置失败: \(errmsg)")
    }
} else {
    let errmsg = String(cString: sqlite3_errmsg(db)!)
    print("❌ 准备创建语句失败: \(errmsg)")
}

sqlite3_finalize(insertStatement)

// 3. 显示创建后的配置
print("\n=== 创建后配置列表 ===")
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