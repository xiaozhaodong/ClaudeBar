#!/usr/bin/env swift

import Foundation
import SQLite3

// 从 api_configs.json 导入配置数据到 SQLite 数据库

print("=== 配置数据导入工具 ===")

// 1. 读取 JSON 配置文件
let configFilePath = "/Users/xiaozhaodong/.claude/api_configs.json"
guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: configFilePath)) else {
    print("❌ 无法读取配置文件: \(configFilePath)")
    exit(1)
}

// 2. 解析 JSON 数据
struct ApiConfigData: Codable {
    let api_configs: [String: ApiConfig]
    let current: String
}

struct ApiConfig: Codable {
    let ANTHROPIC_AUTH_TOKEN: String
    let ANTHROPIC_BASE_URL: String
}

guard let configData = try? JSONDecoder().decode(ApiConfigData.self, from: jsonData) else {
    print("❌ 无法解析 JSON 配置文件")
    exit(1)
}

print("✅ 成功读取 \(configData.api_configs.count) 个配置")
print("✅ 当前活动配置: \(configData.current)")

// 3. 连接 SQLite 数据库
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDir = appSupport.appendingPathComponent("ClaudeBar")
try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
let dbPath = appDir.appendingPathComponent("configs.db").path

var db: OpaquePointer?
guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
    print("❌ 无法打开数据库: \(dbPath)")
    exit(1)
}

print("✅ 成功连接数据库: \(dbPath)")

// 4. 清空现有数据
let deleteSQL = "DELETE FROM api_configs"
if sqlite3_exec(db, deleteSQL, nil, nil, nil) == SQLITE_OK {
    print("✅ 清空现有配置数据")
} else {
    print("⚠️ 清空数据库失败，但继续执行")
}

// 5. 插入配置数据
let insertSQL = "INSERT INTO api_configs (name, base_url, auth_token, is_active) VALUES (?, ?, ?, ?)"
var insertStatement: OpaquePointer?

if sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil) == SQLITE_OK {
    print("\n开始导入配置...")
    
    for (name, config) in configData.api_configs {
        // 绑定参数
        sqlite3_bind_text(insertStatement, 1, name, -1, nil)
        sqlite3_bind_text(insertStatement, 2, config.ANTHROPIC_BASE_URL, -1, nil)
        sqlite3_bind_text(insertStatement, 3, config.ANTHROPIC_AUTH_TOKEN, -1, nil)
        sqlite3_bind_int(insertStatement, 4, name == configData.current ? 1 : 0)
        
        // 执行插入
        if sqlite3_step(insertStatement) == SQLITE_DONE {
            let status = name == configData.current ? " (活动)" : ""
            print("✅ 导入配置: \(name)\(status)")
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("❌ 导入配置失败: \(name) - \(errmsg)")
        }
        
        // 重置语句以便下次使用
        sqlite3_reset(insertStatement)
    }
    
    sqlite3_finalize(insertStatement)
} else {
    let errmsg = String(cString: sqlite3_errmsg(db)!)
    print("❌ 准备插入语句失败: \(errmsg)")
}

// 6. 验证导入结果
let selectSQL = "SELECT name, base_url, is_active FROM api_configs ORDER BY name"
var selectStatement: OpaquePointer?

if sqlite3_prepare_v2(db, selectSQL, -1, &selectStatement, nil) == SQLITE_OK {
    print("\n=== 数据库中的配置 ===")
    while sqlite3_step(selectStatement) == SQLITE_ROW {
        let namePtr = sqlite3_column_text(selectStatement, 0)
        let name = namePtr != nil ? String(cString: namePtr!) : ""
        
        let urlPtr = sqlite3_column_text(selectStatement, 1)
        let baseURL = urlPtr != nil ? String(cString: urlPtr!) : ""
        
        let isActive = sqlite3_column_int(selectStatement, 2) == 1
        let status = isActive ? " (活动)" : ""
        
        print("📋 \(name): \(baseURL)\(status)")
    }
    sqlite3_finalize(selectStatement)
}

// 7. 关闭数据库连接
sqlite3_close(db)

print("\n=== 导入完成 ===")
print("数据已成功导入到 SQLite 数据库中")
print("请重新启动应用程序以查看效果")