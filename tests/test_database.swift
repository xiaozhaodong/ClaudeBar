#!/usr/bin/env swift

import Foundation
import SQLite3

// 测试数据库创建和基本操作
print("=== 测试 SQLite 数据库管理器 ===")

// 数据库路径
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDir = appSupport.appendingPathComponent("ClaudeBar")
let dbPath = appDir.appendingPathComponent("configs.db").path

// 确保目录存在
try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

print("数据库路径: \(dbPath)")

// 打开数据库连接
var db: OpaquePointer?
if sqlite3_open(dbPath, &db) == SQLITE_OK {
    print("✅ 数据库连接成功")
    
    // 创建表结构
    let createTableSQL = """
    CREATE TABLE IF NOT EXISTS api_configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        base_url TEXT NOT NULL,
        auth_token TEXT NOT NULL,
        is_active INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    );
    """
    
    if sqlite3_exec(db, createTableSQL, nil, nil, nil) == SQLITE_OK {
        print("✅ 表创建成功")
        
        // 创建索引
        let createIndexSQL = """
        CREATE INDEX IF NOT EXISTS idx_api_configs_name ON api_configs(name);
        CREATE INDEX IF NOT EXISTS idx_api_configs_active ON api_configs(is_active);
        """
        
        if sqlite3_exec(db, createIndexSQL, nil, nil, nil) == SQLITE_OK {
            print("✅ 索引创建成功")
        } else {
            print("⚠️ 索引创建警告")
        }
        
        // 插入测试数据
        let insertSQL = "INSERT INTO api_configs (name, base_url, auth_token, is_active) VALUES (?, ?, ?, ?)"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, "test-config", -1, nil)
            sqlite3_bind_text(statement, 2, "https://api.anthropic.com", -1, nil)
            sqlite3_bind_text(statement, 3, "test-token", -1, nil)
            sqlite3_bind_int(statement, 4, 1)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ 测试数据插入成功")
            } else {
                print("❌ 测试数据插入失败")
            }
            
            sqlite3_finalize(statement)
        }
        
        // 查询测试数据
        let selectSQL = "SELECT id, name, base_url, is_active FROM api_configs"
        var selectStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &selectStatement, nil) == SQLITE_OK {
            print("\n=== 数据库中的配置 ===")
            while sqlite3_step(selectStatement) == SQLITE_ROW {
                let id = sqlite3_column_int64(selectStatement, 0)
                let name = String(cString: sqlite3_column_text(selectStatement, 1))
                let baseURL = String(cString: sqlite3_column_text(selectStatement, 2))
                let isActive = sqlite3_column_int(selectStatement, 3) == 1
                
                print("ID: \(id), 名称: \(name), URL: \(baseURL), 活动: \(isActive)")
            }
            sqlite3_finalize(selectStatement)
        }
        
    } else {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        print("❌ 表创建失败: \(errmsg)")
    }
    
    sqlite3_close(db)
} else {
    let errmsg = String(cString: sqlite3_errmsg(db)!)
    print("❌ 数据库连接失败: \(errmsg)")
}

print("\n=== 测试完成 ===")