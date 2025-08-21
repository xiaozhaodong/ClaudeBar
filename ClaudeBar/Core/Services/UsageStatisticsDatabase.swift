import Foundation
import SQLite3

/// 使用统计数据库管理器
/// 专门负责使用统计数据的存储和查询
class UsageStatisticsDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    private let dbQueue = DispatchQueue(label: "com.claude.usage-database", qos: .userInitiated)
    
    /// 预编译语句缓存 - 提升批量操作性能
    private var preparedStatements: [String: OpaquePointer?] = [:]
    private let preparedStatementsQueue = DispatchQueue(label: "com.claude.prepared-statements", qos: .utility)
    
    init() {
        // 数据库文件路径 - 与配置数据库放在同一目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                 in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ClaudeBar")
        
        // 确保应用支持目录存在
        try? FileManager.default.createDirectory(at: appDir, 
                                               withIntermediateDirectories: true)
        
        dbPath = appDir.appendingPathComponent("usage_statistics.db").path
        
        print("使用统计数据库路径: \(dbPath)")
        
        do {
            try openDatabase()
            try createTables()
        } catch {
            print("使用统计数据库初始化失败: \(error)")
        }
    }
    
    deinit {
        // 清理预编译语句
        for (_, statement) in preparedStatements {
            sqlite3_finalize(statement)
        }
        preparedStatements.removeAll()
        
        sqlite3_close(db)
    }
    
    /// 打开数据库连接
    private func openDatabase() throws {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            sqlite3_close(db)
            throw UsageStatisticsDBError.connectionFailed(errmsg)
        }
        
        // 配置高性能设置
        try configurePerformanceSettings()
        
        print("使用统计数据库连接成功")
    }
    
    /// 配置数据库性能设置
    /// 优化大数据集的插入和查询性能
    private func configurePerformanceSettings() throws {
        let performanceSettings = [
            // WAL模式 - 提升并发读写性能
            "PRAGMA journal_mode = WAL",
            
            // 外键约束
            "PRAGMA foreign_keys = ON",
            
            // 同步模式 - NORMAL模式在WAL模式下是安全且高性能的
            "PRAGMA synchronous = NORMAL", 
            
            // 缓存大小 - 设置为64MB缓存（默认值的64倍）
            "PRAGMA cache_size = -65536",
            
            // 临时存储 - 使用内存存储临时表和索引
            "PRAGMA temp_store = MEMORY",
            
            // 内存映射大小 - 256MB（提升大数据集性能）
            "PRAGMA mmap_size = 268435456",
            
            // 自动VACUUM - 增量模式，避免阻塞操作
            "PRAGMA auto_vacuum = INCREMENTAL",
            
            // 页面大小 - 4KB（适合现代SSD）
            "PRAGMA page_size = 4096",
            
            // 预分析 - 启用查询优化器统计信息
            "PRAGMA optimize"
        ]
        
        for setting in performanceSettings {
            if sqlite3_exec(db, setting, nil, nil, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("⚠️ 性能设置失败: \(setting) - \(errmsg)")
                // 不抛出异常，继续其他设置
            }
        }
        
        print("✅ 数据库性能设置完成")
    }
    
    // MARK: - 预编译语句管理
    
    /// 获取或创建预编译语句
    /// 使用缓存避免重复编译，提升批量操作性能
    private func getPreparedStatement(sql: String, key: String) -> OpaquePointer? {
        return preparedStatementsQueue.sync {
            // 检查缓存
            if let cachedStatement = preparedStatements[key] {
                return cachedStatement
            }
            
            // 创建新的预编译语句
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                preparedStatements[key] = statement
                return statement
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("❌ 预编译语句创建失败: \(key) - \(errmsg)")
                return nil
            }
        }
    }
    
    /// 清理预编译语句缓存
    /// 用于数据库重建等场景
    private func clearPreparedStatements() {
        preparedStatementsQueue.sync {
            for (_, statement) in preparedStatements {
                sqlite3_finalize(statement)
            }
            preparedStatements.removeAll()
        }
    }
    
    /// 强制重建数据库（临时方法，用于应用新的表结构）
    private func forceRebuildDatabase() throws {
        print("⚠️ 强制重建数据库以应用新的表结构")
        
        // 删除所有现有表
        let dropTables = [
            "DROP TABLE IF EXISTS usage_entries",
            "DROP TABLE IF EXISTS jsonl_files",
            "DROP TABLE IF EXISTS daily_statistics", 
            "DROP TABLE IF EXISTS model_statistics",
            "DROP TABLE IF EXISTS project_statistics",
            "DROP TABLE IF EXISTS schema_version"
        ]
        
        for dropSQL in dropTables {
            try executeSQL(dropSQL)
        }
        
        // 清理序列表
        try executeSQL("DELETE FROM sqlite_sequence")
        
        // 压缩数据库
        try executeSQL("VACUUM")
        
        print("✅ 数据库重建完成")
    }
    
    /// 强制重建数据库（不包含VACUUM，用于事务安全）
    private func forceRebuildDatabaseWithoutVacuum() throws {
        print("⚠️ 强制重建数据库以应用新的表结构（无VACUUM）")
        
        // 删除所有现有表
        let dropTables = [
            "DROP TABLE IF EXISTS usage_entries",
            "DROP TABLE IF EXISTS jsonl_files",
            "DROP TABLE IF EXISTS daily_statistics", 
            "DROP TABLE IF EXISTS model_statistics",
            "DROP TABLE IF EXISTS project_statistics",
            "DROP TABLE IF EXISTS schema_version"
        ]
        
        for dropSQL in dropTables {
            try executeSQL(dropSQL)
        }
        
        // 清理序列表
        try executeSQL("DELETE FROM sqlite_sequence")
        
        print("✅ 数据库表删除完成（VACUUM将在事务外执行）")
    }
    
    /// 创建所有数据库表
    private func createTables() throws {
        try createUsageEntriesTable()
        try createJSONLFilesTable()
        try createDailyStatisticsTable()
        try createModelStatisticsTable()
        try createProjectStatisticsTable()
        try createIndexes()
        
        print("使用统计数据库表创建成功")
    }
    
    /// 创建使用记录主表
    private func createUsageEntriesTable() throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS usage_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            model TEXT NOT NULL,
            input_tokens BIGINT DEFAULT 0,
            output_tokens BIGINT DEFAULT 0,
            cache_creation_tokens BIGINT DEFAULT 0,
            cache_read_tokens BIGINT DEFAULT 0,
            cost REAL DEFAULT 0.0,
            session_id TEXT,
            project_path TEXT,
            project_name TEXT,
            request_id TEXT,
            message_id TEXT,
            message_type TEXT,
            date_string TEXT,
            source_file TEXT,
            total_tokens BIGINT GENERATED ALWAYS AS
                (input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens) STORED,
            created_at TEXT DEFAULT (datetime('now', 'localtime')),
            updated_at TEXT DEFAULT (datetime('now', 'localtime'))
        );
        """
        
        try executeSQL(createTableSQL)
    }
    
    /// 创建JSONL文件跟踪表
    private func createJSONLFilesTable() throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS jsonl_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL UNIQUE,
            file_name TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            last_modified TEXT NOT NULL,
            last_processed TEXT,
            entry_count INTEGER DEFAULT 0,
            processing_status TEXT DEFAULT 'pending',
            error_message TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        """
        
        try executeSQL(createTableSQL)
    }
    
    /// 创建每日统计表
    private func createDailyStatisticsTable() throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS daily_statistics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date_string TEXT NOT NULL UNIQUE,
            total_cost REAL DEFAULT 0.0,
            total_tokens BIGINT DEFAULT 0,
            input_tokens BIGINT DEFAULT 0,
            output_tokens BIGINT DEFAULT 0,
            cache_creation_tokens BIGINT DEFAULT 0,
            cache_read_tokens BIGINT DEFAULT 0,
            session_count INTEGER DEFAULT 0,
            request_count INTEGER DEFAULT 0,
            models_used TEXT,
            created_at TEXT DEFAULT (datetime('now', 'localtime')),
            updated_at TEXT DEFAULT (datetime('now', 'localtime'))
        );
        """
        
        try executeSQL(createTableSQL)
    }
    
    /// 创建模型统计表
    private func createModelStatisticsTable() throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS model_statistics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            model TEXT NOT NULL,
            date_range TEXT NOT NULL,
            total_cost REAL DEFAULT 0.0,
            total_tokens BIGINT DEFAULT 0,
            input_tokens BIGINT DEFAULT 0,
            output_tokens BIGINT DEFAULT 0,
            cache_creation_tokens BIGINT DEFAULT 0,
            cache_read_tokens BIGINT DEFAULT 0,
            session_count INTEGER DEFAULT 0,
            request_count INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now', 'localtime')),
            updated_at TEXT DEFAULT (datetime('now', 'localtime')),
            UNIQUE(model, date_range)
        );
        """
        
        try executeSQL(createTableSQL)
    }
    
    /// 创建项目统计表
    private func createProjectStatisticsTable() throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS project_statistics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_path TEXT NOT NULL,
            project_name TEXT NOT NULL,
            date_range TEXT NOT NULL,
            total_cost REAL DEFAULT 0.0,
            total_tokens BIGINT DEFAULT 0,
            session_count INTEGER DEFAULT 0,
            request_count INTEGER DEFAULT 0,
            last_used TEXT,
            created_at TEXT DEFAULT (datetime('now', 'localtime')),
            updated_at TEXT DEFAULT (datetime('now', 'localtime')),
            UNIQUE(project_path, date_range)
        );
        """
        
        try executeSQL(createTableSQL)
    }
    
    /// 创建高性能索引
    /// 针对去重、查询和聚合操作进行优化
    private func createIndexes() throws {
        let indexes = [
            // usage_entries 表 - 基础索引
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_timestamp ON usage_entries(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_date_string ON usage_entries(date_string)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_model ON usage_entries(model)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_project_path ON usage_entries(project_path)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_session_id ON usage_entries(session_id)",
            
            // 高性能去重索引 - 针对 deduplicateEntriesOptimized
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_dedup ON usage_entries(message_id, request_id, id)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_message_id ON usage_entries(message_id) WHERE message_id IS NOT NULL",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_request_id ON usage_entries(request_id) WHERE request_id IS NOT NULL",
            
            // 复合索引 - 优化统计查询性能
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_date_model ON usage_entries(date_string, model)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_date_project ON usage_entries(date_string, project_path)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_model_tokens ON usage_entries(model, input_tokens, output_tokens)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_project_cost ON usage_entries(project_path, cost)",
            
            // 时间范围查询优化
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_timestamp_desc ON usage_entries(timestamp DESC)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_date_timestamp ON usage_entries(date_string, timestamp)",
            
            // 覆盖索引 - 包含常用的统计字段
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_stats_cover ON usage_entries(date_string, model, project_path, cost, input_tokens, output_tokens, cache_creation_tokens, cache_read_tokens)",
            
            // jsonl_files 表索引
            "CREATE INDEX IF NOT EXISTS idx_jsonl_files_path ON jsonl_files(file_path)",
            "CREATE INDEX IF NOT EXISTS idx_jsonl_files_modified ON jsonl_files(last_modified)",
            "CREATE INDEX IF NOT EXISTS idx_jsonl_files_status ON jsonl_files(processing_status)",
            
            // 统计表索引
            "CREATE INDEX IF NOT EXISTS idx_daily_stats_date ON daily_statistics(date_string)",
            "CREATE INDEX IF NOT EXISTS idx_model_stats_composite ON model_statistics(model, date_range)",
            "CREATE INDEX IF NOT EXISTS idx_project_stats_composite ON project_statistics(project_path, date_range)"
        ]
        
        for indexSQL in indexes {
            try executeSQL(indexSQL)
        }
        
        // 创建优化索引（需要单独处理以支持渐进式迁移）
        try createOptimizedIndexes()
    }
    
    /// 创建时间相关的优化索引
    private func createOptimizedIndexes() throws {
        // 检查数据库版本，实施渐进式索引升级
        let currentVersion = try getDatabaseSchemaVersion()
        
        if currentVersion < 2 {
            try createTimeOptimizedIndexes()
            try updateDatabaseSchemaVersion(to: 2)
            print("✅ 索引优化 v2.0 完成：时间字段优化索引")
        }
    }
    
    /// 创建时间优化索引 (v2.0)
    private func createTimeOptimizedIndexes() throws {
        let timeOptimizedIndexes = [
            // 时间范围查询优化索引（针对最近7天、30天查询）
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_timestamp_desc ON usage_entries(timestamp DESC)",
            
            // 复合索引：时间+模型（优化模型统计查询）
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_time_model ON usage_entries(timestamp, model)",
            
            // 复合索引：时间+会话（优化会话统计查询）
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_time_session ON usage_entries(timestamp, session_id)",
            
            // 复合索引：日期字符串+成本（优化成本分析查询）
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_date_cost ON usage_entries(date_string, cost)",
            
            // 复合索引：项目路径+时间（优化项目历史查询）
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_project_time ON usage_entries(project_path, timestamp DESC)",
            
            // 优化统计聚合查询的覆盖索引
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_stats_coverage ON usage_entries(timestamp, model, cost, total_tokens, session_id) WHERE cost > 0",
            
            // 时间分区索引（为未来的分区优化做准备）
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_time_partition ON usage_entries(date_string, timestamp, id)"
        ]
        
        print("🔧 开始创建时间优化索引...")
        for (index, indexSQL) in timeOptimizedIndexes.enumerated() {
            do {
                try executeSQL(indexSQL)
                print("✅ 索引 \(index + 1)/\(timeOptimizedIndexes.count) 创建成功")
            } catch {
                print("⚠️ 索引 \(index + 1) 创建失败（可能已存在）: \(error)")
                // 继续创建其他索引，不因单个索引失败而停止
            }
        }
        print("🎉 时间优化索引创建完成！")
    }
    
    /// 获取数据库架构版本
    private func getDatabaseSchemaVersion() throws -> Int {
        // 检查是否存在版本表
        let checkTableSQL = """
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name='schema_version'
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, checkTableSQL, -1, &statement, nil) == SQLITE_OK else {
            // 如果查询失败，假设是版本1
            return 1
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) != SQLITE_ROW {
            // 版本表不存在，创建并返回版本1
            try createVersionTable()
            return 1
        }
        
        // 查询当前版本
        let versionSQL = "SELECT version FROM schema_version LIMIT 1"
        var versionStatement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, versionSQL, -1, &versionStatement, nil) == SQLITE_OK else {
            return 1
        }
        
        defer { sqlite3_finalize(versionStatement) }
        
        if sqlite3_step(versionStatement) == SQLITE_ROW {
            return Int(sqlite3_column_int(versionStatement, 0))
        }
        
        return 1
    }
    
    /// 创建版本表
    private func createVersionTable() throws {
        let createVersionTableSQL = """
        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER NOT NULL,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        INSERT OR IGNORE INTO schema_version (version) VALUES (1);
        """
        
        try executeSQL(createVersionTableSQL)
    }
    
    /// 更新数据库架构版本
    private func updateDatabaseSchemaVersion(to version: Int) throws {
        let updateSQL = """
        INSERT OR REPLACE INTO schema_version (version, updated_at) 
        VALUES (?, CURRENT_TIMESTAMP)
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw UsageStatisticsDBError.operationFailed("无法准备版本更新语句")
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(version))
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw UsageStatisticsDBError.operationFailed("版本更新失败")
        }
        
        print("📊 数据库架构版本更新到 v\(version)")
    }
    
    /// 执行SQL语句的通用方法
    private func executeSQL(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("SQL执行失败: \(errmsg)")
            print("SQL: \(sql)")
            throw UsageStatisticsDBError.operationFailed(errmsg)
        }
    }
}

// MARK: - 使用记录操作

extension UsageStatisticsDatabase {
    
    /// 批量插入使用记录
    func insertUsageEntries(_ entries: [UsageEntry]) throws -> Int {
        return try dbQueue.sync {
            return try insertUsageEntriesInternal(entries)
        }
    }
    
    /// 内部实现 - 高性能批量插入使用记录（使用预编译语句缓存）
    private func insertUsageEntriesInternal(_ entries: [UsageEntry]) throws -> Int {
        guard !entries.isEmpty else { return 0 }
        
        // 使用缓存的预编译语句
        let insertSQL = """
        INSERT OR IGNORE INTO usage_entries (
            timestamp, model, input_tokens, output_tokens, 
            cache_creation_tokens, cache_read_tokens, cost,
            session_id, project_path, project_name, 
            request_id, message_id, message_type, date_string, source_file,
            created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        guard let statement = getPreparedStatement(sql: insertSQL, key: "insertUsageEntry") else {
            throw UsageStatisticsDBError.operationFailed("获取预编译语句失败")
        }
        
        var insertedCount = 0
        
        // 预计算时间戳以提升性能
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        let currentTime = formatter.string(from: Date())
        
        // 开始事务
        try executeSQL("BEGIN TRANSACTION")
        
        do {
            for entry in entries {
                sqlite3_reset(statement)
                
                // 高效参数绑定（减少字符串复制）
                try bindUsageEntryToStatementOptimized(statement, entry: entry, currentTime: currentTime)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    // 批量检查插入结果，减少sqlite3_changes调用
                    insertedCount += 1
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(db)!)
                    print("插入使用记录失败: \(errmsg)")
                }
            }
            
            // 最后检查实际插入数量
            let actualChanges = sqlite3_total_changes(db)
            
            // 提交事务
            try executeSQL("COMMIT")
            print("高性能批量插入完成: \(insertedCount)/\(entries.count) 条记录")
            
        } catch {
            // 回滚事务
            try? executeSQL("ROLLBACK")
            throw error
        }
        
        return insertedCount
    }
    
    /// 修复的参数绑定方法
    /// 恢复使用 SQLITE_TRANSIENT 确保字符串安全
    private func bindUsageEntryToStatementOptimized(_ statement: OpaquePointer?, entry: UsageEntry, currentTime: String) throws {
        // 修复：使用 SQLITE_TRANSIENT 确保字符串被正确复制，避免数据库损坏
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        _ = entry.timestamp.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.model.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 3, Int64(entry.inputTokens))
        sqlite3_bind_int64(statement, 4, Int64(entry.outputTokens))
        sqlite3_bind_int64(statement, 5, Int64(entry.cacheCreationTokens))
        sqlite3_bind_int64(statement, 6, Int64(entry.cacheReadTokens))
        sqlite3_bind_double(statement, 7, entry.cost)
        _ = entry.sessionId.withCString { sqlite3_bind_text(statement, 8, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.projectPath.withCString { sqlite3_bind_text(statement, 9, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.projectName.withCString { sqlite3_bind_text(statement, 10, $0, -1, SQLITE_TRANSIENT) }
        
        if let requestId = entry.requestId {
            _ = requestId.withCString { sqlite3_bind_text(statement, 11, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 11)
        }
        
        if let messageId = entry.messageId {
            _ = messageId.withCString { sqlite3_bind_text(statement, 12, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 12)
        }
        
        _ = entry.messageType.withCString { sqlite3_bind_text(statement, 13, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.dateString.withCString { sqlite3_bind_text(statement, 14, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.sourceFile.withCString { sqlite3_bind_text(statement, 15, $0, -1, SQLITE_TRANSIENT) }
        
        // 预计算的时间戳也使用 TRANSIENT
        _ = currentTime.withCString { sqlite3_bind_text(statement, 16, $0, -1, SQLITE_TRANSIENT) }
        _ = currentTime.withCString { sqlite3_bind_text(statement, 17, $0, -1, SQLITE_TRANSIENT) }
    }
    
    /// 绑定UsageEntry到SQL语句（直接复制测试文件中的完整逻辑）
    private func bindUsageEntryToStatement(_ statement: OpaquePointer?, entry: UsageEntry) throws {
        // 使用 SQLITE_TRANSIENT 确保字符串被复制
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        // 获取当前精确时间
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        let currentTime = formatter.string(from: Date())
        
        _ = entry.timestamp.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.model.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 3, Int64(entry.inputTokens))
        sqlite3_bind_int64(statement, 4, Int64(entry.outputTokens))
        sqlite3_bind_int64(statement, 5, Int64(entry.cacheCreationTokens))
        sqlite3_bind_int64(statement, 6, Int64(entry.cacheReadTokens))
        sqlite3_bind_double(statement, 7, entry.cost)
        _ = entry.sessionId.withCString { sqlite3_bind_text(statement, 8, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.projectPath.withCString { sqlite3_bind_text(statement, 9, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.projectName.withCString { sqlite3_bind_text(statement, 10, $0, -1, SQLITE_TRANSIENT) }
        
        if let requestId = entry.requestId {
            _ = requestId.withCString { sqlite3_bind_text(statement, 11, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 11)
        }
        
        if let messageId = entry.messageId {
            _ = messageId.withCString { sqlite3_bind_text(statement, 12, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 12)
        }
        
        _ = entry.messageType.withCString { sqlite3_bind_text(statement, 13, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.dateString.withCString { sqlite3_bind_text(statement, 14, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.sourceFile.withCString { sqlite3_bind_text(statement, 15, $0, -1, SQLITE_TRANSIENT) }
        
        // 绑定时间字段 (参数 16 和 17)
        _ = currentTime.withCString { sqlite3_bind_text(statement, 16, $0, -1, SQLITE_TRANSIENT) }
        _ = currentTime.withCString { sqlite3_bind_text(statement, 17, $0, -1, SQLITE_TRANSIENT) }
    }
    
    /// 查询使用记录
    func queryUsageEntries(
        dateRange: DateRange? = nil,
        projectPath: String? = nil,
        model: String? = nil,
        limit: Int? = nil,
        offset: Int = 0
    ) throws -> [UsageEntry] {
        return try dbQueue.sync {
            return try queryUsageEntriesInternal(
                dateRange: dateRange,
                projectPath: projectPath,
                model: model,
                limit: limit,
                offset: offset
            )
        }
    }
    
    /// 内部实现 - 查询使用记录
    private func queryUsageEntriesInternal(
        dateRange: DateRange? = nil,
        projectPath: String? = nil,
        model: String? = nil,
        limit: Int? = nil,
        offset: Int = 0
    ) throws -> [UsageEntry] {
        
        var whereConditions: [String] = []
        var parameters: [Any] = []
        
        // 构建查询条件
        if let dateRange = dateRange {
            switch dateRange {
            case .all:
                break // 不添加日期条件
            case .last7Days:
                whereConditions.append("timestamp >= datetime('now', '-7 days')")
            case .last30Days:
                whereConditions.append("timestamp >= datetime('now', '-30 days')")
            }
        }
        
        if let projectPath = projectPath {
            whereConditions.append("project_path LIKE ?")
            parameters.append("%\(projectPath)%")
        }
        
        if let model = model {
            whereConditions.append("model = ?")
            parameters.append(model)
        }
        
        // 构建完整SQL
        var sql = """
        SELECT id, timestamp, model, input_tokens, output_tokens,
               cache_creation_tokens, cache_read_tokens, cost,
               session_id, project_path, project_name,
               request_id, message_id, message_type, date_string, source_file
        FROM usage_entries
        """
        
        if !whereConditions.isEmpty {
            sql += " WHERE " + whereConditions.joined(separator: " AND ")
        }
        
        sql += " ORDER BY timestamp DESC"
        
        if let limit = limit {
            sql += " LIMIT \(limit) OFFSET \(offset)"
        }
        
        var statement: OpaquePointer?
        var entries: [UsageEntry] = []
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("准备查询语句失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 绑定参数
        for (index, parameter) in parameters.enumerated() {
            if let stringParam = parameter as? String {
                stringParam.withCString { cString in
                    sqlite3_bind_text(statement, Int32(index + 1), cString, -1, nil)
                }
            }
        }
        
        // 执行查询
        while sqlite3_step(statement) == SQLITE_ROW {
            if let entry = parseUsageEntryFromRow(statement) {
                entries.append(entry)
            }
        }
        
        return entries
    }
    
    /// 从SQL查询结果解析UsageEntry
    private func parseUsageEntryFromRow(_ statement: OpaquePointer?) -> UsageEntry? {
        guard let statement = statement else { return nil }
        
        // 安全地获取文本字段
        func getText(_ index: Int32) -> String {
            if let ptr = sqlite3_column_text(statement, index) {
                return String(cString: ptr)
            }
            return ""
        }
        
        func getOptionalText(_ index: Int32) -> String? {
            if let ptr = sqlite3_column_text(statement, index) {
                let text = String(cString: ptr)
                return text.isEmpty ? nil : text
            }
            return nil
        }
        
        let timestamp = getText(1)
        let model = getText(2)
        let inputTokens = Int(sqlite3_column_int64(statement, 3))
        let outputTokens = Int(sqlite3_column_int64(statement, 4))
        let cacheCreationTokens = Int(sqlite3_column_int64(statement, 5))
        let cacheReadTokens = Int(sqlite3_column_int64(statement, 6))
        let cost = sqlite3_column_double(statement, 7)
        let sessionId = getText(8)
        let projectPath = getText(9)
        let requestId = getOptionalText(11)
        let projectName = getText(10)  // 新增：读取project_name字段
        let messageId = getOptionalText(12)
        let messageType = getText(13)
        let dateString = getText(14)  // 新增：读取date_string字段
        let sourceFile = getText(15)  // 修改：source_file现在是必需字段

        return UsageEntry(
            timestamp: timestamp,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cost: cost,
            sessionId: sessionId,
            projectPath: projectPath,
            projectName: projectName,
            requestId: requestId,
            messageId: messageId,
            messageType: messageType,
            dateString: dateString,
            sourceFile: sourceFile
        )
    }
}

// MARK: - JSONL文件跟踪操作

extension UsageStatisticsDatabase {
    
    /// 记录文件处理状态
    func recordFileProcessing(_ fileURL: URL, fileSize: Int64, lastModified: Date) throws {
        try dbQueue.sync {
            try recordFileProcessingInternal(fileURL, fileSize: fileSize, lastModified: lastModified)
        }
    }
    
    private func recordFileProcessingInternal(_ fileURL: URL, fileSize: Int64, lastModified: Date) throws {
        let insertSQL = """
        INSERT OR REPLACE INTO jsonl_files 
        (file_path, file_name, file_size, last_modified, processing_status)
        VALUES (?, ?, ?, ?, 'pending')
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("准备文件记录语句失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        let formatter = ISO8601DateFormatter()
        let lastModifiedString = formatter.string(from: lastModified)
        
        // 使用 SQLITE_TRANSIENT 确保字符串被复制
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        fileURL.path.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        fileURL.lastPathComponent.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 3, fileSize)
        lastModifiedString.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("记录文件状态失败: \(errmsg)")
        }
    }
    
    /// 更新文件处理完成状态
    func updateFileProcessingCompleted(_ fileURL: URL, entryCount: Int) throws {
        try dbQueue.sync {
            try updateFileProcessingCompletedInternal(fileURL, entryCount: entryCount)
        }
    }
    
    private func updateFileProcessingCompletedInternal(_ fileURL: URL, entryCount: Int) throws {
        let updateSQL = """
        UPDATE jsonl_files 
        SET processing_status = 'completed', 
            entry_count = ?, 
            last_processed = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE file_path = ?
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("准备更新文件状态语句失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 使用 SQLITE_TRANSIENT 确保字符串被复制
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        sqlite3_bind_int64(statement, 1, Int64(entryCount))
        fileURL.path.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("更新文件状态失败: \(errmsg)")
        }
    }
    
    /// 检查文件是否需要重新处理
    func shouldProcessFile(_ fileURL: URL, currentModified: Date) throws -> Bool {
        return try dbQueue.sync {
            return try shouldProcessFileInternal(fileURL, currentModified: currentModified)
        }
    }
    
    private func shouldProcessFileInternal(_ fileURL: URL, currentModified: Date) throws -> Bool {
        let querySQL = """
        SELECT last_modified, processing_status 
        FROM jsonl_files 
        WHERE file_path = ?
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return true // 如果查询失败，默认需要处理
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 使用 SQLITE_TRANSIENT 确保字符串被复制
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        fileURL.path.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            guard let lastModifiedPtr = sqlite3_column_text(statement, 0),
                  let statusPtr = sqlite3_column_text(statement, 1) else {
                return true
            }
            
            let lastModifiedString = String(cString: lastModifiedPtr)
            let status = String(cString: statusPtr)
            
            let formatter = ISO8601DateFormatter()
            guard let lastModified = formatter.date(from: lastModifiedString) else {
                return true
            }
            
            // 如果文件已修改或处理失败，需要重新处理
            return currentModified > lastModified || status == "error" || status == "pending"
        }
        
        // 文件不在记录中，需要处理
        return true
    }
}

// MARK: - 统计查询操作

extension UsageStatisticsDatabase {
    
    /// 获取使用统计汇总数据（优化版本）
    func getUsageStatistics(dateRange: DateRange = .all, projectPath: String? = nil) throws -> UsageStatistics {
        return try dbQueue.sync {
            return try getUsageStatisticsOptimized(dateRange: dateRange, projectPath: projectPath)
        }
    }
    
    /// 获取会话统计数据（按项目分组）
    func getSessionStatistics(dateRange: DateRange = .all, sortOrder: SessionSortOrder = .costDescending) throws -> [ProjectUsage] {
        return try dbQueue.sync {
            return try getSessionStatisticsInternal(dateRange: dateRange, sortOrder: sortOrder)
        }
    }
    
    private func getUsageStatisticsOptimized(dateRange: DateRange = .all, projectPath: String? = nil) throws -> UsageStatistics {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 构建优化的查询条件
        var whereConditions: [String] = []
        var parameters: [Any] = []
        
        // 使用优化的时间范围查询，利用新索引
        switch dateRange {
        case .all:
            break // 不添加日期条件
        case .last7Days:
            // 使用新的时间索引，查询性能显著提升
            whereConditions.append("timestamp >= datetime('now', '-7 days')")
        case .last30Days:
            // 使用新的时间索引，查询性能显著提升
            whereConditions.append("timestamp >= datetime('now', '-30 days')")
        }
        
        if let projectPath = projectPath {
            whereConditions.append("project_path LIKE ?")
            parameters.append("%\(projectPath)%")
        }
        
        let whereClause = whereConditions.isEmpty ? "" : "WHERE " + whereConditions.joined(separator: " AND ")
        
        // 使用覆盖索引优化的统计查询
        let optimizedStatsSQL = """
        SELECT
            COUNT(*) as total_requests,
            COUNT(DISTINCT session_id) as total_sessions,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            SUM(input_tokens) as total_input_tokens,
            SUM(output_tokens) as total_output_tokens,
            SUM(cache_creation_tokens) as total_cache_creation_tokens,
            SUM(cache_read_tokens) as total_cache_read_tokens
        FROM usage_entries \(whereClause)
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, optimizedStatsSQL, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("准备优化统计查询失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 绑定参数
        for (index, parameter) in parameters.enumerated() {
            if let stringParam = parameter as? String {
                stringParam.withCString { cString in
                    sqlite3_bind_text(statement, Int32(index + 1), cString, -1, nil)
                }
            }
        }
        
        var totalRequests = 0
        var totalSessions = 0
        var totalCost = 0.0
        var totalTokens = 0
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCacheCreationTokens = 0
        var totalCacheReadTokens = 0
        
        if sqlite3_step(statement) == SQLITE_ROW {
            totalRequests = Int(sqlite3_column_int(statement, 0))
            totalSessions = Int(sqlite3_column_int(statement, 1))
            totalCost = sqlite3_column_double(statement, 2)
            totalTokens = Int(sqlite3_column_int64(statement, 3))
            totalInputTokens = Int(sqlite3_column_int64(statement, 4))
            totalOutputTokens = Int(sqlite3_column_int64(statement, 5))
            totalCacheCreationTokens = Int(sqlite3_column_int64(statement, 6))
            totalCacheReadTokens = Int(sqlite3_column_int64(statement, 7))
        }
        
        // 获取按模型统计（使用优化索引）
        let byModel = try getModelUsageOptimized(whereClause: whereClause, parameters: parameters)
        
        // 获取按日期统计（使用优化索引）
        let byDate = try getDailyUsageOptimized(whereClause: whereClause, parameters: parameters)
        
        // 获取按项目统计（使用优化索引）
        let byProject = try getProjectUsageOptimized(whereClause: whereClause, parameters: parameters)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let queryTime = (endTime - startTime) * 1000 // 转换为毫秒
        
        print("🚀 优化查询完成 - 耗时: \(String(format: "%.2f", queryTime))ms")
        print("   📊 总成本: $\(String(format: "%.2f", totalCost)), 总请求: \(totalRequests)")
        
        return UsageStatistics(
            totalCost: totalCost,
            totalTokens: totalTokens,
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalCacheCreationTokens: totalCacheCreationTokens,
            totalCacheReadTokens: totalCacheReadTokens,
            totalSessions: totalSessions,
            totalRequests: totalRequests,
            byModel: byModel,
            byDate: byDate,
            byProject: byProject
        )
    }
    
    /// 保留原有方法作为备用（兼容性）
    private func getUsageStatisticsInternal(dateRange: DateRange = .all, projectPath: String? = nil) throws -> UsageStatistics {
        // 使用优化版本
        return try getUsageStatisticsOptimized(dateRange: dateRange, projectPath: projectPath)
    }
    
    /// 优化的模型使用统计查询
    private func getModelUsageOptimized(whereClause: String, parameters: [Any]) throws -> [ModelUsage] {
        // 使用时间+模型复合索引优化查询
        let modelStatsSQL = """
        SELECT
            model,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            SUM(input_tokens) as input_tokens,
            SUM(output_tokens) as output_tokens,
            SUM(cache_creation_tokens) as cache_creation_tokens,
            SUM(cache_read_tokens) as cache_read_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count
        FROM usage_entries \(whereClause)
        GROUP BY model
        ORDER BY total_cost DESC
        """
        
        return try executeModelQuery(modelStatsSQL, parameters: parameters)
    }
    
    /// 优化的每日使用统计查询
    private func getDailyUsageOptimized(whereClause: String, parameters: [Any]) throws -> [DailyUsage] {
        // 使用日期+成本复合索引优化查询
        let dailyStatsSQL = """
        SELECT
            date_string,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            COUNT(DISTINCT session_id) as session_count,
            GROUP_CONCAT(DISTINCT model) as models_used
        FROM usage_entries \(whereClause)
        GROUP BY date_string
        ORDER BY date_string ASC
        """
        
        return try executeDailyQuery(dailyStatsSQL, parameters: parameters)
    }
    
    /// 优化的项目使用统计查询
    private func getProjectUsageOptimized(whereClause: String, parameters: [Any]) throws -> [ProjectUsage] {
        // 使用项目路径+时间复合索引优化查询
        let projectStatsSQL = """
        SELECT
            project_path,
            project_name,
            SUM(cost) as total_cost,
            SUM(input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens) as total_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count,
            MAX(timestamp) as last_used
        FROM usage_entries \(whereClause)
        GROUP BY project_path
        ORDER BY total_cost DESC
        """
        
        return try executeProjectQuery(projectStatsSQL, parameters: parameters)
    }
    
    /// 执行模型查询的通用方法
    private func executeModelQuery(_ sql: String, parameters: [Any]) throws -> [ModelUsage] {
        var statement: OpaquePointer?
        var models: [ModelUsage] = []
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 绑定参数
        for (index, parameter) in parameters.enumerated() {
            if let stringParam = parameter as? String {
                stringParam.withCString { cString in
                    sqlite3_bind_text(statement, Int32(index + 1), cString, -1, nil)
                }
            }
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let modelPtr = sqlite3_column_text(statement, 0) else { continue }
            
            let model = String(cString: modelPtr)
            let totalCost = sqlite3_column_double(statement, 1)
            let totalTokens = Int(sqlite3_column_int64(statement, 2))
            let inputTokens = Int(sqlite3_column_int64(statement, 3))
            let outputTokens = Int(sqlite3_column_int64(statement, 4))
            let cacheCreationTokens = Int(sqlite3_column_int64(statement, 5))
            let cacheReadTokens = Int(sqlite3_column_int64(statement, 6))
            let sessionCount = Int(sqlite3_column_int(statement, 7))
            let requestCount = Int(sqlite3_column_int(statement, 8))
            
            let modelUsage = ModelUsage(
                model: model,
                totalCost: totalCost,
                totalTokens: totalTokens,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: cacheCreationTokens,
                cacheReadTokens: cacheReadTokens,
                sessionCount: sessionCount,
                requestCount: requestCount
            )
            
            models.append(modelUsage)
        }
        
        return models
    }
    
    /// 执行每日查询的通用方法
    private func executeDailyQuery(_ sql: String, parameters: [Any]) throws -> [DailyUsage] {
        var statement: OpaquePointer?
        var dailyUsages: [DailyUsage] = []
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 绑定参数
        for (index, parameter) in parameters.enumerated() {
            if let stringParam = parameter as? String {
                stringParam.withCString { cString in
                    sqlite3_bind_text(statement, Int32(index + 1), cString, -1, nil)
                }
            }
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let datePtr = sqlite3_column_text(statement, 0) else { continue }
            
            let date = String(cString: datePtr)
            let totalCost = sqlite3_column_double(statement, 1)
            let totalTokens = Int(sqlite3_column_int64(statement, 2))
            let sessionCount = Int(sqlite3_column_int(statement, 3))
            
            var modelsUsed: [String] = []
            if let modelsPtr = sqlite3_column_text(statement, 4) {
                let modelsString = String(cString: modelsPtr)
                modelsUsed = modelsString.components(separatedBy: ",")
            }
            
            let dailyUsage = DailyUsage(
                date: date,
                totalCost: totalCost,
                totalTokens: totalTokens,
                sessionCount: sessionCount,
                modelsUsed: modelsUsed
            )
            
            dailyUsages.append(dailyUsage)
        }
        
        return dailyUsages
    }
    
    /// 执行项目查询的通用方法
    private func executeProjectQuery(_ sql: String, parameters: [Any]) throws -> [ProjectUsage] {
        var statement: OpaquePointer?
        var projectUsages: [ProjectUsage] = []
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 绑定参数
        for (index, parameter) in parameters.enumerated() {
            if let stringParam = parameter as? String {
                stringParam.withCString { cString in
                    sqlite3_bind_text(statement, Int32(index + 1), cString, -1, nil)
                }
            }
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let projectPathPtr = sqlite3_column_text(statement, 0),
                  let projectNamePtr = sqlite3_column_text(statement, 1) else { continue }
            
            let projectPath = String(cString: projectPathPtr)
            let projectName = String(cString: projectNamePtr)
            let totalCost = sqlite3_column_double(statement, 2)
            let totalTokens = Int(sqlite3_column_int64(statement, 3))
            let sessionCount = Int(sqlite3_column_int(statement, 4))
            let requestCount = Int(sqlite3_column_int(statement, 5))
            
            var lastUsed = ""
            if let lastUsedPtr = sqlite3_column_text(statement, 6) {
                lastUsed = String(cString: lastUsedPtr)
            }
            
            let projectUsage = ProjectUsage(
                projectPath: projectPath,
                projectName: projectName,
                totalCost: totalCost,
                totalTokens: totalTokens,
                sessionCount: sessionCount,
                requestCount: requestCount,
                lastUsed: lastUsed
            )
            
            projectUsages.append(projectUsage)
        }
        
        return projectUsages
    }
    
    /// 获取会话统计数据的内部实现
    private func getSessionStatisticsInternal(dateRange: DateRange = .all, sortOrder: SessionSortOrder = .costDescending) throws -> [ProjectUsage] {
        // 构建查询条件
        var whereConditions: [String] = []
        var parameters: [Any] = []
        
        switch dateRange {
        case .all:
            break // 不添加日期条件
        case .last7Days:
            whereConditions.append("timestamp >= datetime('now', '-7 days')")
        case .last30Days:
            whereConditions.append("timestamp >= datetime('now', '-30 days')")
        }
        
        // DateRange 只支持开始日期，没有结束日期
        // 如果需要结束日期，可以考虑传入当前时间作为结束
        
        let whereClause = whereConditions.isEmpty ? "" : "WHERE " + whereConditions.joined(separator: " AND ")
        
        // 确定排序条件
        let orderClause: String
        switch sortOrder {
        case .costDescending:
            orderClause = "ORDER BY total_cost DESC"
        case .costAscending:
            orderClause = "ORDER BY total_cost ASC"
        case .dateDescending:
            orderClause = "ORDER BY last_used DESC"
        case .dateAscending:
            orderClause = "ORDER BY last_used ASC"
        case .nameAscending:
            orderClause = "ORDER BY project_name ASC"
        case .nameDescending:
            orderClause = "ORDER BY project_name DESC"
        }
        
        // 查询项目统计数据
        let projectStatsSQL = """
        SELECT 
            project_path,
            project_name,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count,
            MAX(timestamp) as last_used
        FROM usage_entries \(whereClause)
        GROUP BY project_path, project_name
        \(orderClause)
        """
        
        var statement: OpaquePointer?
        var projectUsages: [ProjectUsage] = []
        
        guard sqlite3_prepare_v2(db, projectStatsSQL, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("准备会话统计查询失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 使用 SQLITE_TRANSIENT 绑定参数
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        for (index, parameter) in parameters.enumerated() {
            if let stringParam = parameter as? String {
                stringParam.withCString { cString in
                    sqlite3_bind_text(statement, Int32(index + 1), cString, -1, SQLITE_TRANSIENT)
                }
            }
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let projectPathPtr = sqlite3_column_text(statement, 0),
                  let projectNamePtr = sqlite3_column_text(statement, 1),
                  let lastUsedPtr = sqlite3_column_text(statement, 6) else { continue }
            
            let projectPath = String(cString: projectPathPtr)
            let projectName = String(cString: projectNamePtr)
            let totalCost = sqlite3_column_double(statement, 2)
            let totalTokens = Int(sqlite3_column_int64(statement, 3))
            let sessionCount = Int(sqlite3_column_int(statement, 4))
            let requestCount = Int(sqlite3_column_int(statement, 5))
            let lastUsed = String(cString: lastUsedPtr)
            
            let projectUsage = ProjectUsage(
                projectPath: projectPath,
                projectName: projectName,
                totalCost: totalCost,
                totalTokens: totalTokens,
                sessionCount: sessionCount,
                requestCount: requestCount,
                lastUsed: lastUsed
            )
            
            projectUsages.append(projectUsage)
        }
        
        return projectUsages
    }
    
    /// 获取按模型统计数据
    private func getModelUsageInternal(whereClause: String, parameters: [Any]) throws -> [ModelUsage] {
        let modelStatsSQL = """
        SELECT 
            model,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            SUM(input_tokens) as input_tokens,
            SUM(output_tokens) as output_tokens,
            SUM(cache_creation_tokens) as cache_creation_tokens,
            SUM(cache_read_tokens) as cache_read_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count
        FROM usage_entries \(whereClause)
        GROUP BY model
        ORDER BY total_cost DESC
        """
        
        var statement: OpaquePointer?
        var models: [ModelUsage] = []
        
        guard sqlite3_prepare_v2(db, modelStatsSQL, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 绑定参数
        for (index, parameter) in parameters.enumerated() {
            if let stringParam = parameter as? String {
                stringParam.withCString { cString in
                    sqlite3_bind_text(statement, Int32(index + 1), cString, -1, nil)
                }
            }
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let modelPtr = sqlite3_column_text(statement, 0) else { continue }
            
            let model = String(cString: modelPtr)
            let totalCost = sqlite3_column_double(statement, 1)
            let totalTokens = Int(sqlite3_column_int64(statement, 2))
            let inputTokens = Int(sqlite3_column_int64(statement, 3))
            let outputTokens = Int(sqlite3_column_int64(statement, 4))
            let cacheCreationTokens = Int(sqlite3_column_int64(statement, 5))
            let cacheReadTokens = Int(sqlite3_column_int64(statement, 6))
            let sessionCount = Int(sqlite3_column_int(statement, 7))
            let requestCount = Int(sqlite3_column_int(statement, 8))
            
            let modelUsage = ModelUsage(
                model: model,
                totalCost: totalCost,
                totalTokens: totalTokens,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: cacheCreationTokens,
                cacheReadTokens: cacheReadTokens,
                sessionCount: sessionCount,
                requestCount: requestCount
            )
            
            models.append(modelUsage)
        }
        
        return models
    }
    
    /// 获取按日期统计数据
    private func getDailyUsageInternal(whereClause: String, parameters: [Any]) throws -> [DailyUsage] {
        let dailyStatsSQL = """
        SELECT 
            date_string,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            COUNT(DISTINCT session_id) as session_count,
            GROUP_CONCAT(DISTINCT model) as models_used
        FROM usage_entries \(whereClause)
        GROUP BY date_string
        ORDER BY date_string ASC
        """
        
        var statement: OpaquePointer?
        var dailyUsages: [DailyUsage] = []
        
        guard sqlite3_prepare_v2(db, dailyStatsSQL, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 绑定参数
        for (index, parameter) in parameters.enumerated() {
            if let stringParam = parameter as? String {
                stringParam.withCString { cString in
                    sqlite3_bind_text(statement, Int32(index + 1), cString, -1, nil)
                }
            }
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let datePtr = sqlite3_column_text(statement, 0) else { continue }
            
            let date = String(cString: datePtr)
            let totalCost = sqlite3_column_double(statement, 1)
            let totalTokens = Int(sqlite3_column_int64(statement, 2))
            let sessionCount = Int(sqlite3_column_int(statement, 3))
            
            var modelsUsed: [String] = []
            if let modelsPtr = sqlite3_column_text(statement, 4) {
                let modelsString = String(cString: modelsPtr)
                modelsUsed = modelsString.components(separatedBy: ",")
            }
            
            let dailyUsage = DailyUsage(
                date: date,
                totalCost: totalCost,
                totalTokens: totalTokens,
                sessionCount: sessionCount,
                modelsUsed: modelsUsed
            )
            
            dailyUsages.append(dailyUsage)
        }
        
        return dailyUsages
    }
    
    /// 获取按项目统计数据
    private func getProjectUsageInternal(whereClause: String, parameters: [Any]) throws -> [ProjectUsage] {
        let projectStatsSQL = """
        SELECT 
            project_path,
            project_name,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count,
            MAX(timestamp) as last_used
        FROM usage_entries \(whereClause)
        GROUP BY project_path
        ORDER BY total_cost DESC
        """
        
        var statement: OpaquePointer?
        var projectUsages: [ProjectUsage] = []
        
        guard sqlite3_prepare_v2(db, projectStatsSQL, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 绑定参数
        for (index, parameter) in parameters.enumerated() {
            if let stringParam = parameter as? String {
                stringParam.withCString { cString in
                    sqlite3_bind_text(statement, Int32(index + 1), cString, -1, nil)
                }
            }
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let projectPathPtr = sqlite3_column_text(statement, 0),
                  let projectNamePtr = sqlite3_column_text(statement, 1) else { continue }
            
            let projectPath = String(cString: projectPathPtr)
            let projectName = String(cString: projectNamePtr)
            let totalCost = sqlite3_column_double(statement, 2)
            let totalTokens = Int(sqlite3_column_int64(statement, 3))
            let sessionCount = Int(sqlite3_column_int(statement, 4))
            let requestCount = Int(sqlite3_column_int(statement, 5))
            
            var lastUsed = ""
            if let lastUsedPtr = sqlite3_column_text(statement, 6) {
                lastUsed = String(cString: lastUsedPtr)
            }
            
            let projectUsage = ProjectUsage(
                projectPath: projectPath,
                projectName: projectName,
                totalCost: totalCost,
                totalTokens: totalTokens,
                sessionCount: sessionCount,
                requestCount: requestCount,
                lastUsed: lastUsed
            )
            
            projectUsages.append(projectUsage)
        }
        
        return projectUsages
    }
}

// MARK: - 数据迁移和维护操作

extension UsageStatisticsDatabase {
    
    /// 清空所有数据并重置ID序列
    /// 用于全量数据迁移前的数据库清理
    func clearAllDataAndResetSequences() throws {
        try dbQueue.sync {
            try clearAllDataAndResetSequencesInternal()
        }
    }
    
    private func clearAllDataAndResetSequencesInternal() throws {
        Logger.shared.info("🗑️ 开始清空所有数据并重置ID序列")
        
        // 先在事务外执行删除和重建操作
        do {
            // 强制重建数据库以确保表结构正确（不在事务中）
            try forceRebuildDatabaseWithoutVacuum()
            
            // 重新创建表
            try createTables()
            
            // 使用测试文件中的多重保险方法确保AUTO_INCREMENT从1开始
            try ensureAutoIncrementFromOne()
            
            // 最后执行VACUUM压缩数据库（不在事务中）
            try executeSQL("VACUUM")
            
            Logger.shared.info("✅ 数据清空和序列重置完成，ID序列已重置为从1开始")
            
        } catch {
            Logger.shared.error("❌ 数据清空失败: \(error)")
            throw error
        }
    }
    
    /// 简化的AUTO_INCREMENT序列重置方法
    /// 移除复杂的虚拟插入/删除操作，仅保留必要的序列清理
    private func ensureAutoIncrementFromOne() throws {
        // 直接清空序列表，让SQLite自动重新初始化
        try executeSQL("DELETE FROM sqlite_sequence")
        
        Logger.shared.info("🔄 已重置所有AUTO_INCREMENT序列")
    }
    
    /// 修复所有记录的日期字符串
    /// 使用 SQLite 的 datetime 函数进行精确日期解析
    func updateAllDateStrings() throws {
        try dbQueue.sync {
            try updateAllDateStringsInternal()
        }
    }
    
    private func updateAllDateStringsInternal() throws {
        print("🗓️ 修复所有日期字符串...")
        
        // 开始事务
        try executeSQL("BEGIN TRANSACTION")
        
        do {
            // 使用 SQLite 的 datetime 函数进行精确的日期解析
            // 这个方法可以正确处理 ISO8601 时间戳并转换为本地日期
            let updateSQL = """
            UPDATE usage_entries 
            SET date_string = date(datetime(timestamp, 'localtime'))
            WHERE timestamp IS NOT NULL AND timestamp != ''
            """
            
            try executeSQL(updateSQL)
            
            // 检查是否有无法解析的时间戳，使用备用方法
            let checkSQL = """
            UPDATE usage_entries 
            SET date_string = substr(timestamp, 1, 10)
            WHERE date_string IS NULL OR date_string = '' OR date_string = '1970-01-01'
            """
            
            try executeSQL(checkSQL)
            
            // 提交事务
            try executeSQL("COMMIT")
            
            print("✅ 日期字符串修复完成")
            
        } catch {
            // 回滚事务
            try? executeSQL("ROLLBACK")
            Logger.shared.error("❌ 日期字符串修复失败: \(error)")
            throw error
        }
    }
    
    /// 优化的去重处理 - 使用删除重复记录的高效方法
    /// 直接删除重复记录，避免创建大型临时表
    func deduplicateEntries() throws {
        try dbQueue.sync {
            try deduplicateEntriesOptimized()
        }
    }
    
    private func deduplicateEntriesOptimized() throws {
        print("🧹 开始优化去重处理...")
        
        // 开始事务
        try executeSQL("BEGIN TRANSACTION")
        
        do {
            // 统计去重前的数量
            let beforeCount = getCount(sql: "SELECT COUNT(*) FROM usage_entries")
            
            // 直接删除重复记录，保留最早的记录（基于 timestamp）
            let deleteSQL = """
            DELETE FROM usage_entries 
            WHERE id NOT IN (
                SELECT MIN(id) 
                FROM usage_entries 
                WHERE message_id IS NOT NULL AND request_id IS NOT NULL
                GROUP BY message_id, request_id
                
                UNION
                
                SELECT id 
                FROM usage_entries 
                WHERE message_id IS NULL OR request_id IS NULL
            )
            """
            
            try executeSQL(deleteSQL)
            
            // 统计去重后的数量
            let afterCount = getCount(sql: "SELECT COUNT(*) FROM usage_entries")
            let duplicateCount = beforeCount - afterCount
            
            print("📊 优化去重完成: 原始 \(beforeCount) 条，去重后 \(afterCount) 条")
            print("📊 删除重复记录: \(duplicateCount) 条")
            
            // 提交事务
            try executeSQL("COMMIT")
            
        } catch {
            // 回滚事务
            try? executeSQL("ROLLBACK")
            Logger.shared.error("❌ 优化去重处理失败: \(error)")
            throw error
        }
    }
    
    /// 获取记录数量的辅助方法（与测试文件完全一致）
    private func getCount(sql: String) -> Int {
        var statement: OpaquePointer?
        var count = 0

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        return count
    }
}

// MARK: - 统计汇总表维护

extension UsageStatisticsDatabase {
    
    /// 更新所有统计汇总表
    func updateStatisticsSummaries() throws {
        try dbQueue.sync {
            try updateStatisticsSummariesInternal()
        }
    }

    /// 生成所有统计汇总（与测试文件完全一致）
    func generateAllStatistics() throws {
        try dbQueue.sync {
            try generateAllStatisticsInternal()
        }
    }

    private func updateStatisticsSummariesInternal() throws {
        // 开始事务
        try executeSQL("BEGIN TRANSACTION")

        do {
            try updateDailyStatistics()
            try updateModelStatistics()
            try updateProjectStatistics()

            // 提交事务
            try executeSQL("COMMIT")
            print("统计汇总表更新完成")

        } catch {
            // 回滚事务
            try? executeSQL("ROLLBACK")
            throw error
        }
    }

    private func generateAllStatisticsInternal() throws {
        print("📊 开始生成所有统计汇总...")

        // 开始事务
        try executeSQL("BEGIN TRANSACTION")

        do {
            try generateDailyStatistics()
            try generateModelStatistics()
            try generateProjectStatistics()

            // 提交事务
            try executeSQL("COMMIT")
            print("✅ 所有统计汇总生成完成")

        } catch {
            // 回滚事务
            try? executeSQL("ROLLBACK")
            throw error
        }
    }
    
    /// 更新每日统计表（直接复制测试文件中的正确逻辑）
    private func updateDailyStatistics() throws {
        // 先删除所有现有统计数据，确保重新生成时ID从1开始
        try executeSQL("DELETE FROM daily_statistics")
        
        // 强制重置序列为0（下一个插入将从1开始）
        try executeSQL("DELETE FROM sqlite_sequence WHERE name='daily_statistics'")
        try executeSQL("INSERT INTO sqlite_sequence (name, seq) VALUES ('daily_statistics', 0)")
        
        let insertSQL = """
        INSERT INTO daily_statistics (
            date_string, total_cost, total_tokens, input_tokens, output_tokens,
            cache_creation_tokens, cache_read_tokens, session_count, request_count,
            models_used, created_at, updated_at
        )
        SELECT
            date_string,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            SUM(input_tokens) as input_tokens,
            SUM(output_tokens) as output_tokens,
            SUM(cache_creation_tokens) as cache_creation_tokens,
            SUM(cache_read_tokens) as cache_read_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count,
            GROUP_CONCAT(DISTINCT model) as models_used,
            datetime('now', 'localtime') as created_at,
            datetime('now', 'localtime') as updated_at
        FROM usage_entries
        GROUP BY date_string
        ORDER BY date_string
        """
        
        try executeSQL(insertSQL)
    }

    /// 生成每日统计表（与测试文件完全一致）
    private func generateDailyStatistics() throws {
        // 先删除所有现有统计数据，确保重新生成时ID从1开始
        try executeSQL("DELETE FROM daily_statistics")

        // 强制重置序列为0（下一个插入将从1开始）
        try executeSQL("DELETE FROM sqlite_sequence WHERE name='daily_statistics'")
        try executeSQL("INSERT INTO sqlite_sequence (name, seq) VALUES ('daily_statistics', 0)")

        let insertSQL = """
        INSERT INTO daily_statistics (
            date_string, total_cost, total_tokens, input_tokens, output_tokens,
            cache_creation_tokens, cache_read_tokens, session_count, request_count,
            models_used, created_at, updated_at
        )
        SELECT
            date_string,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            SUM(input_tokens) as input_tokens,
            SUM(output_tokens) as output_tokens,
            SUM(cache_creation_tokens) as cache_creation_tokens,
            SUM(cache_read_tokens) as cache_read_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count,
            GROUP_CONCAT(DISTINCT model) as models_used,
            datetime('now', 'localtime') as created_at,
            datetime('now', 'localtime') as updated_at
        FROM usage_entries
        GROUP BY date_string
        ORDER BY date_string
        """

        try executeSQL(insertSQL)

        // 打印详细的token统计信息
        let tokenStatsSQL = """
        SELECT
            SUM(input_tokens) as total_input,
            SUM(output_tokens) as total_output,
            SUM(cache_creation_tokens) as total_cache_creation,
            SUM(cache_read_tokens) as total_cache_read,
            SUM(input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens) as grand_total,
            COUNT(*) as record_count
        FROM usage_entries
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, tokenStatsSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let totalInput = sqlite3_column_int64(statement, 0)
                let totalOutput = sqlite3_column_int64(statement, 1)
                let totalCacheCreation = sqlite3_column_int64(statement, 2)
                let totalCacheRead = sqlite3_column_int64(statement, 3)
                let grandTotal = sqlite3_column_int64(statement, 4)
                let recordCount = sqlite3_column_int(statement, 5)

                print("   📊 Token统计详情:")
                print("      - 输入Token: \(totalInput)")
                print("      - 输出Token: \(totalOutput)")
                print("      - 缓存创建Token: \(totalCacheCreation)")
                print("      - 缓存读取Token: \(totalCacheRead)")
                print("      - 总Token数: \(grandTotal)")
                print("      - 记录数: \(recordCount)")
            }
        }
        sqlite3_finalize(statement)

        print("   ✅ 每日统计表重新生成完成（ID从1开始）")
    }

    /// 更新模型统计表（直接复制测试文件中的正确逻辑）
    private func updateModelStatistics() throws {
        // 先删除所有现有模型统计数据，确保重新生成时ID从1开始
        try executeSQL("DELETE FROM model_statistics")
        
        // 强制重置序列为0（下一个插入将从1开始）
        try executeSQL("DELETE FROM sqlite_sequence WHERE name='model_statistics'")
        try executeSQL("INSERT INTO sqlite_sequence (name, seq) VALUES ('model_statistics', 0)")
        
        // 生成全部时间范围的模型统计
        try generateModelStatisticsForRange("all", whereCondition: "")
        
        // 生成最近7天的模型统计
        let last7DaysCondition = "WHERE timestamp >= datetime('now', '-7 days')"
        try generateModelStatisticsForRange("7d", whereCondition: last7DaysCondition)
        
        // 生成最近30天的模型统计
        let last30DaysCondition = "WHERE timestamp >= datetime('now', '-30 days')"
        try generateModelStatisticsForRange("30d", whereCondition: last30DaysCondition)
    }

    /// 生成模型统计表（与测试文件完全一致）
    private func generateModelStatistics() throws {
        // 先删除所有现有模型统计数据，确保重新生成时ID从1开始
        try executeSQL("DELETE FROM model_statistics")

        // 强制重置序列为0（下一个插入将从1开始）
        try executeSQL("DELETE FROM sqlite_sequence WHERE name='model_statistics'")
        try executeSQL("INSERT INTO sqlite_sequence (name, seq) VALUES ('model_statistics', 0)")

        // 生成全部时间范围的模型统计
        try generateModelStatisticsForRange("all", whereCondition: "")

        // 生成最近7天的模型统计
        let last7DaysCondition = "WHERE timestamp >= datetime('now', '-7 days')"
        try generateModelStatisticsForRange("7d", whereCondition: last7DaysCondition)

        // 生成最近30天的模型统计
        let last30DaysCondition = "WHERE timestamp >= datetime('now', '-30 days')"
        try generateModelStatisticsForRange("30d", whereCondition: last30DaysCondition)

        print("   ✅ 模型统计表重新生成完成（ID从1开始）")
    }

    private func generateModelStatisticsForRange(_ range: String, whereCondition: String) throws {
        let insertSQL = """
        INSERT INTO model_statistics (
            model, date_range, total_cost, total_tokens, input_tokens, output_tokens,
            cache_creation_tokens, cache_read_tokens, session_count, request_count, 
            created_at, updated_at
        )
        SELECT
            model,
            '\(range)' as date_range,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            SUM(input_tokens) as input_tokens,
            SUM(output_tokens) as output_tokens,
            SUM(cache_creation_tokens) as cache_creation_tokens,
            SUM(cache_read_tokens) as cache_read_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count,
            datetime('now', 'localtime') as created_at,
            datetime('now', 'localtime') as updated_at
        FROM usage_entries \(whereCondition)
        GROUP BY model
        ORDER BY total_cost DESC
        """
        
        try executeSQL(insertSQL)
    }
    
    /// 更新项目统计表（直接复制测试文件中的正确逻辑）
    private func updateProjectStatistics() throws {
        // 先删除所有现有项目统计数据，确保重新生成时ID从1开始
        try executeSQL("DELETE FROM project_statistics")
        
        // 强制重置序列为0（下一个插入将从1开始）
        try executeSQL("DELETE FROM sqlite_sequence WHERE name='project_statistics'")
        try executeSQL("INSERT INTO sqlite_sequence (name, seq) VALUES ('project_statistics', 0)")
        
        // 生成全部时间范围的项目统计
        try generateProjectStatisticsForRange("all", whereCondition: "")
        
        // 生成最近7天的项目统计
        let last7DaysCondition = "WHERE timestamp >= datetime('now', '-7 days')"
        try generateProjectStatisticsForRange("7d", whereCondition: last7DaysCondition)
        
        // 生成最近30天的项目统计
        let last30DaysCondition = "WHERE timestamp >= datetime('now', '-30 days')"
        try generateProjectStatisticsForRange("30d", whereCondition: last30DaysCondition)
    }

    /// 生成项目统计表（与测试文件完全一致）
    private func generateProjectStatistics() throws {
        // 先删除所有现有项目统计数据，确保重新生成时ID从1开始
        try executeSQL("DELETE FROM project_statistics")

        // 强制重置序列为0（下一个插入将从1开始）
        try executeSQL("DELETE FROM sqlite_sequence WHERE name='project_statistics'")
        try executeSQL("INSERT INTO sqlite_sequence (name, seq) VALUES ('project_statistics', 0)")

        // 生成全部时间范围的项目统计
        try generateProjectStatisticsForRange("all", whereCondition: "")

        // 生成最近7天的项目统计
        let last7DaysCondition = "WHERE timestamp >= datetime('now', '-7 days')"
        try generateProjectStatisticsForRange("7d", whereCondition: last7DaysCondition)

        // 生成最近30天的项目统计
        let last30DaysCondition = "WHERE timestamp >= datetime('now', '-30 days')"
        try generateProjectStatisticsForRange("30d", whereCondition: last30DaysCondition)

        print("   ✅ 项目统计表重新生成完成（ID从1开始）")
    }

    private func generateProjectStatisticsForRange(_ range: String, whereCondition: String) throws {
        let insertSQL = """
        INSERT INTO project_statistics (
            project_path, project_name, date_range, total_cost, total_tokens,
            session_count, request_count, last_used, created_at, updated_at
        )
        SELECT
            project_path,
            project_name,
            '\(range)' as date_range,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count,
            MAX(timestamp) as last_used,
            datetime('now', 'localtime') as created_at,
            datetime('now', 'localtime') as updated_at
        FROM usage_entries \(whereCondition)
        GROUP BY project_path, project_name
        ORDER BY total_cost DESC
        """
        
        try executeSQL(insertSQL)
    }
    
    /// 增量更新统计（仅更新指定日期的数据）
    func updateStatisticsForDate(_ dateString: String) throws {
        try dbQueue.sync {
            try updateStatisticsForDateInternal(dateString)
        }
    }
    
    private func updateStatisticsForDateInternal(_ dateString: String) throws {
        // 更新每日统计
        let dailyUpdateSQL = """
        INSERT OR REPLACE INTO daily_statistics (
            date_string, total_cost, total_tokens, input_tokens, output_tokens,
            cache_creation_tokens, cache_read_tokens, session_count, request_count,
            models_used, created_at, updated_at
        )
        SELECT 
            date_string,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            SUM(input_tokens) as input_tokens,
            SUM(output_tokens) as output_tokens,
            SUM(cache_creation_tokens) as cache_creation_tokens,
            SUM(cache_read_tokens) as cache_read_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count,
            GROUP_CONCAT(DISTINCT model) as models_used,
            datetime('now', 'localtime') as created_at,
            datetime('now', 'localtime') as updated_at
        FROM usage_entries
        WHERE date_string = ?
        GROUP BY date_string
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, dailyUpdateSQL, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("准备每日统计更新语句失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 使用 SQLITE_TRANSIENT 确保字符串被复制
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        dateString.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("更新每日统计失败: \(errmsg)")
        }
        
        // 重新计算汇总统计（这里可以优化为增量计算）
        try updateModelStatistics()
        try updateProjectStatistics()
    }
    
    /// 清理过期的统计汇总数据
    func cleanupOldStatistics(keepDays: Int = 365) throws {
        try dbQueue.sync {
            try cleanupOldStatisticsInternal(keepDays: keepDays)
        }
    }
    
    private func cleanupOldStatisticsInternal(keepDays: Int) throws {
        let cutoffDate = "datetime('now', '-\(keepDays) days')"
        
        let cleanupQueries = [
            "DELETE FROM daily_statistics WHERE date_string < date(\(cutoffDate))",
            "DELETE FROM usage_entries WHERE timestamp < \(cutoffDate)"
        ]
        
        for query in cleanupQueries {
            try executeSQL(query)
        }
        
        print("清理了 \(keepDays) 天前的统计数据")
    }
    
    /// 获取数据库统计信息
    func getDatabaseStats() throws -> DatabaseStats {
        return try dbQueue.sync {
            return try getDatabaseStatsInternal()
        }
    }
    
    private func getDatabaseStatsInternal() throws -> DatabaseStats {
        let statsQueries = [
            "SELECT COUNT(*) FROM usage_entries",
            "SELECT COUNT(*) FROM jsonl_files",
            "SELECT COUNT(*) FROM daily_statistics",
            "SELECT COUNT(*) FROM model_statistics",
            "SELECT COUNT(*) FROM project_statistics"
        ]
        
        var counts: [Int] = []
        
        for query in statsQueries {
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_ROW {
                    counts.append(Int(sqlite3_column_int(statement, 0)))
                } else {
                    counts.append(0)
                }
            } else {
                counts.append(0)
            }
            
            sqlite3_finalize(statement)
        }
        
        return DatabaseStats(
            usageEntriesCount: counts.count > 0 ? counts[0] : 0,
            jsonlFilesCount: counts.count > 1 ? counts[1] : 0,
            dailyStatisticsCount: counts.count > 2 ? counts[2] : 0,
            modelStatisticsCount: counts.count > 3 ? counts[3] : 0,
            projectStatisticsCount: counts.count > 4 ? counts[4] : 0
        )
    }
}

// MARK: - 辅助数据结构

struct DatabaseStats {
    let usageEntriesCount: Int
    let jsonlFilesCount: Int
    let dailyStatisticsCount: Int
    let modelStatisticsCount: Int
    let projectStatisticsCount: Int
    
    var totalRecords: Int {
        return usageEntriesCount + jsonlFilesCount + dailyStatisticsCount + modelStatisticsCount + projectStatisticsCount
    }
}

// MARK: - 错误定义

enum UsageStatisticsDBError: Error, LocalizedError {
    case connectionFailed(String)
    case operationFailed(String)
    case dataNotFound
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "数据库连接失败: \(message)"
        case .operationFailed(let message):
            return "数据库操作失败: \(message)"
        case .dataNotFound:
            return "数据未找到"
        case .invalidData(let message):
            return "数据无效: \(message)"
        }
    }
}
