import Foundation
import SQLite3

/// 使用统计数据库管理器
/// 专门负责使用统计数据的存储和查询
class UsageStatisticsDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    private let dbQueue = DispatchQueue(label: "com.claude.usage-database", qos: .userInitiated)
    
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
        sqlite3_close(db)
    }
    
    /// 打开数据库连接
    private func openDatabase() throws {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            sqlite3_close(db)
            throw UsageStatisticsDBError.connectionFailed(errmsg)
        }
        
        // 启用外键约束
        sqlite3_exec(db, "PRAGMA foreign_keys = ON", nil, nil, nil)
        // 设置WAL模式以提高并发性能
        sqlite3_exec(db, "PRAGMA journal_mode = WAL", nil, nil, nil)
        
        print("使用统计数据库连接成功")
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
            input_tokens INTEGER DEFAULT 0,
            output_tokens INTEGER DEFAULT 0,
            cache_creation_tokens INTEGER DEFAULT 0,
            cache_read_tokens INTEGER DEFAULT 0,
            cost REAL DEFAULT 0.0,
            session_id TEXT,
            project_path TEXT,
            project_name TEXT,
            request_id TEXT,
            message_id TEXT,
            message_type TEXT,
            date_string TEXT,
            total_tokens INTEGER GENERATED ALWAYS AS 
                (input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens) STORED,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
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
            total_tokens INTEGER DEFAULT 0,
            input_tokens INTEGER DEFAULT 0,
            output_tokens INTEGER DEFAULT 0,
            cache_creation_tokens INTEGER DEFAULT 0,
            cache_read_tokens INTEGER DEFAULT 0,
            session_count INTEGER DEFAULT 0,
            request_count INTEGER DEFAULT 0,
            models_used TEXT,
            last_updated TEXT DEFAULT CURRENT_TIMESTAMP
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
            total_tokens INTEGER DEFAULT 0,
            input_tokens INTEGER DEFAULT 0,
            output_tokens INTEGER DEFAULT 0,
            cache_creation_tokens INTEGER DEFAULT 0,
            cache_read_tokens INTEGER DEFAULT 0,
            session_count INTEGER DEFAULT 0,
            request_count INTEGER DEFAULT 0,
            last_updated TEXT DEFAULT CURRENT_TIMESTAMP,
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
            total_tokens INTEGER DEFAULT 0,
            session_count INTEGER DEFAULT 0,
            request_count INTEGER DEFAULT 0,
            last_used TEXT,
            last_updated TEXT DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(project_path, date_range)
        );
        """
        
        try executeSQL(createTableSQL)
    }
    
    /// 创建索引
    private func createIndexes() throws {
        let indexes = [
            // usage_entries 表索引
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_timestamp ON usage_entries(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_date_string ON usage_entries(date_string)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_model ON usage_entries(model)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_project_path ON usage_entries(project_path)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_session_id ON usage_entries(session_id)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_request_message ON usage_entries(request_id, message_id)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_composite ON usage_entries(date_string, model, project_path)",
            
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
    
    /// 内部实现 - 批量插入使用记录
    private func insertUsageEntriesInternal(_ entries: [UsageEntry]) throws -> Int {
        guard !entries.isEmpty else { return 0 }
        
        let insertSQL = """
        INSERT OR IGNORE INTO usage_entries (
            timestamp, model, input_tokens, output_tokens, 
            cache_creation_tokens, cache_read_tokens, cost,
            session_id, project_path, project_name, 
            request_id, message_id, message_type, date_string
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        var insertedCount = 0
        
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("准备插入语句失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 开始事务
        try executeSQL("BEGIN TRANSACTION")
        
        do {
            for entry in entries {
                sqlite3_reset(statement)
                
                // 绑定参数
                try bindUsageEntryToStatement(statement, entry: entry)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    // 检查是否真的插入了新行
                    if sqlite3_changes(db) > 0 {
                        insertedCount += 1
                    }
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(db)!)
                    print("插入使用记录失败: \(errmsg)")
                }
            }
            
            // 提交事务
            try executeSQL("COMMIT")
            print("批量插入完成: \(insertedCount)/\(entries.count) 条记录")
            
        } catch {
            // 回滚事务
            try? executeSQL("ROLLBACK")
            throw error
        }
        
        return insertedCount
    }
    
    /// 绑定UsageEntry到SQL语句
    private func bindUsageEntryToStatement(_ statement: OpaquePointer?, entry: UsageEntry) throws {
        // 1. timestamp
        entry.timestamp.withCString { cString in
            sqlite3_bind_text(statement, 1, cString, -1, nil)
        }
        
        // 2. model
        entry.model.withCString { cString in
            sqlite3_bind_text(statement, 2, cString, -1, nil)
        }
        
        // 3-6. token counts (使用 Int64 防止溢出)
        sqlite3_bind_int64(statement, 3, Int64(entry.inputTokens))
        sqlite3_bind_int64(statement, 4, Int64(entry.outputTokens))
        sqlite3_bind_int64(statement, 5, Int64(entry.cacheCreationTokens))
        sqlite3_bind_int64(statement, 6, Int64(entry.cacheReadTokens))
        
        // 7. cost
        sqlite3_bind_double(statement, 7, entry.cost)
        
        // 8. session_id
        entry.sessionId.withCString { cString in
            sqlite3_bind_text(statement, 8, cString, -1, nil)
        }
        
        // 9. project_path
        entry.projectPath.withCString { cString in
            sqlite3_bind_text(statement, 9, cString, -1, nil)
        }
        
        // 10. project_name
        entry.projectName.withCString { cString in
            sqlite3_bind_text(statement, 10, cString, -1, nil)
        }
        
        // 11. request_id
        if let requestId = entry.requestId {
            requestId.withCString { cString in
                sqlite3_bind_text(statement, 11, cString, -1, nil)
            }
        } else {
            sqlite3_bind_null(statement, 11)
        }
        
        // 12. message_id
        if let messageId = entry.messageId {
            messageId.withCString { cString in
                sqlite3_bind_text(statement, 12, cString, -1, nil)
            }
        } else {
            sqlite3_bind_null(statement, 12)
        }
        
        // 13. message_type
        entry.messageType.withCString { cString in
            sqlite3_bind_text(statement, 13, cString, -1, nil)
        }
        
        // 14. date_string
        entry.dateString.withCString { cString in
            sqlite3_bind_text(statement, 14, cString, -1, nil)
        }
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
               request_id, message_id, message_type, date_string
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
        let messageId = getOptionalText(12)
        let messageType = getText(13)
        
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
            requestId: requestId,
            messageId: messageId,
            messageType: messageType
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
    
    /// 获取使用统计汇总数据
    func getUsageStatistics(dateRange: DateRange = .all, projectPath: String? = nil) throws -> UsageStatistics {
        return try dbQueue.sync {
            return try getUsageStatisticsInternal(dateRange: dateRange, projectPath: projectPath)
        }
    }
    
    /// 获取会话统计数据（按项目分组）
    func getSessionStatistics(dateRange: DateRange = .all, sortOrder: SessionSortOrder = .costDescending) throws -> [ProjectUsage] {
        return try dbQueue.sync {
            return try getSessionStatisticsInternal(dateRange: dateRange, sortOrder: sortOrder)
        }
    }
    
    private func getUsageStatisticsInternal(dateRange: DateRange = .all, projectPath: String? = nil) throws -> UsageStatistics {
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
        
        if let projectPath = projectPath {
            whereConditions.append("project_path LIKE ?")
            parameters.append("%\(projectPath)%")
        }
        
        let whereClause = whereConditions.isEmpty ? "" : "WHERE " + whereConditions.joined(separator: " AND ")
        
        // 计算总体统计
        let totalStatsSQL = """
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
        
        guard sqlite3_prepare_v2(db, totalStatsSQL, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw UsageStatisticsDBError.operationFailed("准备总体统计查询失败: \(errmsg)")
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
        
        // 获取按模型统计
        let byModel = try getModelUsageInternal(whereClause: whereClause, parameters: parameters)
        
        // 获取按日期统计
        let byDate = try getDailyUsageInternal(whereClause: whereClause, parameters: parameters)
        
        // 获取按项目统计
        let byProject = try getProjectUsageInternal(whereClause: whereClause, parameters: parameters)
        
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
            
            var modelsUsed: [String] = []
            if let modelsPtr = sqlite3_column_text(statement, 3) {
                let modelsString = String(cString: modelsPtr)
                modelsUsed = modelsString.components(separatedBy: ",")
            }
            
            let dailyUsage = DailyUsage(
                date: date,
                totalCost: totalCost,
                totalTokens: totalTokens,
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

// MARK: - 统计汇总表维护

extension UsageStatisticsDatabase {
    
    /// 更新所有统计汇总表
    func updateStatisticsSummaries() throws {
        try dbQueue.sync {
            try updateStatisticsSummariesInternal()
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
    
    /// 更新每日统计表
    private func updateDailyStatistics() throws {
        let updateSQL = """
        INSERT OR REPLACE INTO daily_statistics (
            date_string, total_cost, total_tokens, input_tokens, output_tokens,
            cache_creation_tokens, cache_read_tokens, session_count, request_count,
            models_used, last_updated
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
            CURRENT_TIMESTAMP as last_updated
        FROM usage_entries
        GROUP BY date_string
        """
        
        try executeSQL(updateSQL)
    }
    
    /// 更新模型统计表
    private func updateModelStatistics() throws {
        // 更新全部时间范围的统计
        try updateModelStatisticsForRange("all", whereCondition: "")
        
        // 更新最近7天的统计
        let last7DaysCondition = "WHERE timestamp >= datetime('now', '-7 days')"
        try updateModelStatisticsForRange("7d", whereCondition: last7DaysCondition)
        
        // 更新最近30天的统计
        let last30DaysCondition = "WHERE timestamp >= datetime('now', '-30 days')"
        try updateModelStatisticsForRange("30d", whereCondition: last30DaysCondition)
    }
    
    private func updateModelStatisticsForRange(_ range: String, whereCondition: String) throws {
        let updateSQL = """
        INSERT OR REPLACE INTO model_statistics (
            model, date_range, total_cost, total_tokens, input_tokens, output_tokens,
            cache_creation_tokens, cache_read_tokens, session_count, request_count, last_updated
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
            CURRENT_TIMESTAMP as last_updated
        FROM usage_entries \(whereCondition)
        GROUP BY model
        """
        
        try executeSQL(updateSQL)
    }
    
    /// 更新项目统计表
    private func updateProjectStatistics() throws {
        // 更新全部时间范围的统计
        try updateProjectStatisticsForRange("all", whereCondition: "")
        
        // 更新最近7天的统计
        let last7DaysCondition = "WHERE timestamp >= datetime('now', '-7 days')"
        try updateProjectStatisticsForRange("7d", whereCondition: last7DaysCondition)
        
        // 更新最近30天的统计
        let last30DaysCondition = "WHERE timestamp >= datetime('now', '-30 days')"
        try updateProjectStatisticsForRange("30d", whereCondition: last30DaysCondition)
    }
    
    private func updateProjectStatisticsForRange(_ range: String, whereCondition: String) throws {
        let updateSQL = """
        INSERT OR REPLACE INTO project_statistics (
            project_path, project_name, date_range, total_cost, total_tokens,
            session_count, request_count, last_used, last_updated
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
            CURRENT_TIMESTAMP as last_updated
        FROM usage_entries \(whereCondition)
        GROUP BY project_path, project_name
        """
        
        try executeSQL(updateSQL)
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
            models_used, last_updated
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
            CURRENT_TIMESTAMP as last_updated
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