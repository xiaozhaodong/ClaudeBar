#!/usr/bin/env swift

import Foundation
import SQLite3

print("=== 检查所有配置记录详情 ===")

let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDir = appSupport.appendingPathComponent("ClaudeBar")
let dbPath = appDir.appendingPathComponent("configs.db").path

var db: OpaquePointer?
sqlite3_open(dbPath, &db)

let selectSQL = "SELECT id, length(name) as name_len, name, base_url FROM api_configs ORDER BY id"
var statement: OpaquePointer?

if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
    while sqlite3_step(statement) == SQLITE_ROW {
        let id = sqlite3_column_int64(statement, 0)
        let nameLen = sqlite3_column_int(statement, 1)
        let namePtr = sqlite3_column_text(statement, 2)
        let name = namePtr != nil ? String(cString: namePtr!) : "NULL"
        let urlPtr = sqlite3_column_text(statement, 3)
        let url = urlPtr != nil ? String(cString: urlPtr!) : "NULL"
        
        print("📋 [\(id)] name_len=\(nameLen) name='\(name)' url='\(url)'")
        
        if nameLen == 0 {
            print("  🗑️ 这是一个空配置记录，将删除")
            
            let deleteSQL = "DELETE FROM api_configs WHERE id = ?"
            var deleteStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStatement, nil) == SQLITE_OK {
                sqlite3_bind_int64(deleteStatement, 1, id)
                
                if sqlite3_step(deleteStatement) == SQLITE_DONE {
                    print("  ✅ 删除成功")
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(db)!)
                    print("  ❌ 删除失败: \(errmsg)")
                }
            }
            sqlite3_finalize(deleteStatement)
        }
    }
}
sqlite3_finalize(statement)
sqlite3_close(db)
print("=== 检查完成 ===")