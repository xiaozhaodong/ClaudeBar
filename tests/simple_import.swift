#!/usr/bin/env swift

import Foundation
import SQLite3

// 简化的配置导入脚本

print("=== 配置数据导入工具 ===")

// 1. 配置数据（从 JSON 文件中提取）
let configs = [
    ("chatai", "https://www.chataiapi.com", "sk-bTY7B7Y0LVuy1SGoDlcwnvHy0f5uHctyEjYQu2PlbxljlP0U", false),
    ("duck", "https://api.duckcode.top/api/claude", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjo2ODEsImVtYWlsIjoiNDA0NjI1OTM4QHFxLmNvbSIsInN1YiI6IjY4MSIsImlhdCI6MTc1MzE3MzIwMH0.GhsPaMvOMOIMn3--t30Ki9C03GQr0tlHIYN2nQoKGag", true),
    ("insthk", "https://hk.instcopilot-api.com", "sk-UUqlTlGquGjs3zlKXKIXsGQf5XQeXoxiRqKGUZvjb3yq8U0e", false),
    ("instsg", "https://sg.instcopilot-api.com", "sk-UUqlTlGquGjs3zlKXKIXsGQf5XQeXoxiRqKGUZvjb3yq8U0e", false),
    ("yourapi", "https://yourapi.cn", "sk-FTR0IHWejbuBKPnilTsBl6M680cxlB1Tyv82cvvFW8GgCtbe", false),
    ("instjp", "https://jp.instcopilot-api.com", "sk-UUqlTlGquGjs3zlKXKIXsGQf5XQeXoxiRqKGUZvjb3yq8U0e", false)
]

// 2. 连接数据库
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDir = appSupport.appendingPathComponent("ClaudeBar")
let dbPath = appDir.appendingPathComponent("configs.db").path

var db: OpaquePointer?
guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
    print("❌ 无法打开数据库")
    exit(1)
}

// 3. 清空现有数据
sqlite3_exec(db, "DELETE FROM api_configs", nil, nil, nil)
print("✅ 清空现有数据")

// 4. 逐个插入配置
for (name, baseURL, token, isActive) in configs {
    let sql = """
        INSERT INTO api_configs (name, base_url, auth_token, is_active) 
        VALUES ('\(name)', '\(baseURL)', '\(token)', \(isActive ? 1 : 0))
    """
    
    if sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK {
        let status = isActive ? " (活动)" : ""
        print("✅ 导入: \(name)\(status)")
    } else {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        print("❌ 导入失败 \(name): \(errmsg)")
    }
}

// 5. 验证结果
let selectSQL = "SELECT name, base_url, is_active FROM api_configs ORDER BY name"
var statement: OpaquePointer?

if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
    print("\n=== 数据库验证 ===")
    while sqlite3_step(statement) == SQLITE_ROW {
        let namePtr = sqlite3_column_text(statement, 0)
        let name = namePtr != nil ? String(cString: namePtr!) : ""
        
        let urlPtr = sqlite3_column_text(statement, 1)
        let url = urlPtr != nil ? String(cString: urlPtr!) : ""
        
        let isActive = sqlite3_column_int(statement, 2) == 1
        let status = isActive ? " ✅" : ""
        
        print("📋 \(name): \(url)\(status)")
    }
}

sqlite3_finalize(statement)
sqlite3_close(db)

print("\n🎉 导入完成！请重新启动应用程序")