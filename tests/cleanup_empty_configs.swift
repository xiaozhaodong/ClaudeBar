#!/usr/bin/env swift

import Foundation
import SQLite3

print("=== 清理空配置记录 ===")

// 连接数据库
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDir = appSupport.appendingPathComponent("ClaudeBar")
let dbPath = appDir.appendingPathComponent("configs.db").path

var db: OpaquePointer?
guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
    print("❌ 无法打开数据库")
    exit(1)
}

// 查找空配置记录
print("=== 查找空配置记录 ===")
let findEmptySQL = "SELECT id, name, base_url FROM api_configs WHERE name = '' OR name IS NULL"
var statement: OpaquePointer?

var emptyIds: [Int64] = []
if sqlite3_prepare_v2(db, findEmptySQL, -1, &statement, nil) == SQLITE_OK {
    while sqlite3_step(statement) == SQLITE_ROW {
        let id = sqlite3_column_int64(statement, 0)
        let namePtr = sqlite3_column_text(statement, 1)
        let name = namePtr != nil ? String(cString: namePtr!) : ""
        let urlPtr = sqlite3_column_text(statement, 2)
        let url = urlPtr != nil ? String(cString: urlPtr!) : ""
        
        print("🗑️ 找到空配置 [\(id)] '\(name)': '\(url)'")
        emptyIds.append(id)
    }
}
sqlite3_finalize(statement)

// 删除空配置记录
if !emptyIds.isEmpty {
    print("\n=== 删除空配置记录 ===")
    for emptyId in emptyIds {
        let deleteSQL = "DELETE FROM api_configs WHERE id = ?"
        var deleteStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_int64(deleteStatement, 1, emptyId)
            
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                print("✅ 删除空配置 ID: \(emptyId)")
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("❌ 删除失败 ID \(emptyId): \(errmsg)")
            }
        }
        sqlite3_finalize(deleteStatement)
    }
} else {
    print("✅ 没有找到空配置记录")
}

// 显示清理后的配置
print("\n=== 清理后配置列表 ===")
let selectSQL = "SELECT id, name, base_url FROM api_configs ORDER BY name"
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
print("\n=== 清理完成 ===")