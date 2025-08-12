#!/usr/bin/env swift

import Foundation
import SQLite3

print("=== 测试修复后的字符串绑定 ===")

// 连接数据库
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDir = appSupport.appendingPathComponent("ClaudeBar")
let dbPath = appDir.appendingPathComponent("configs.db").path

var db: OpaquePointer?
guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
    print("❌ 无法打开数据库")
    exit(1)
}

// 测试使用修复后的字符串绑定方式
let targetName = "test-delete"
print("查找配置: \(targetName)")

let query = "SELECT id, name, base_url FROM api_configs WHERE name = ? LIMIT 1"
var statement: OpaquePointer?

if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
    // 使用修复后的字符串绑定方式
    targetName.withCString { cString in
        sqlite3_bind_text(statement, 1, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
    
    if sqlite3_step(statement) == SQLITE_ROW {
        let id = sqlite3_column_int64(statement, 0)
        let namePtr = sqlite3_column_text(statement, 1)
        let name = namePtr != nil ? String(cString: namePtr!) : ""
        let urlPtr = sqlite3_column_text(statement, 2)
        let url = urlPtr != nil ? String(cString: urlPtr!) : ""
        
        print("✅ 找到配置: ID=\(id), Name=\(name), URL=\(url)")
    } else {
        print("❌ 未找到配置: \(targetName)")
    }
} else {
    let errmsg = String(cString: sqlite3_errmsg(db)!)
    print("❌ 查询失败: \(errmsg)")
}

sqlite3_finalize(statement)
sqlite3_close(db)

print("=== 测试完成 ===")