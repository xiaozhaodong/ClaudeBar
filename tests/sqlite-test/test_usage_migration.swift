#!/usr/bin/env swift

import Foundation
import SQLite3

// MARK: - String扩展支持正则表达式
extension String {
    func matches(_ regex: String) -> Bool {
        return range(of: regex, options: .regularExpression) != nil
    }
}

// MARK: - 真实的数据模型（与项目保持一致）

struct TestUsageEntry {
    let timestamp: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Double
    let sessionId: String
    let projectPath: String
    let projectName: String
    let requestId: String?
    let messageId: String?
    let messageType: String
    let dateString: String
    let sourceFile: String
    
    var totalTokens: Int {
        return inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
}

// MARK: - JSONL原始数据模型（用于解析）

struct RawJSONLEntry: Codable {
    let type: String?
    let messageType: String?
    let model: String?
    let usage: UsageData?
    let message: MessageData?
    let cost: Double?
    let costUSD: Double?
    let timestamp: String?
    let sessionId: String?
    let requestId: String?
    let requestIdUnderscore: String?
    let messageId: String?
    let id: String?
    let uuid: String?
    let date: String?
    
    private enum CodingKeys: String, CodingKey {
        case type
        case messageType = "message_type"
        case model
        case usage
        case message
        case cost
        case costUSD
        case timestamp
        case sessionId = "sessionId"
        case requestId
        case requestIdUnderscore = "request_id"
        case messageId = "message_id"
        case id
        case uuid
        case date
    }
    
    struct UsageData: Codable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?
        let cacheCreationTokens: Int?
        let cacheReadTokens: Int?
        
        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case cacheCreationTokens = "cache_creation_tokens"
            case cacheReadTokens = "cache_read_tokens"
        }
        
        var effectiveCacheCreationTokens: Int {
            return cacheCreationInputTokens ?? cacheCreationTokens ?? 0
        }
        
        var effectiveCacheReadTokens: Int {
            return cacheReadInputTokens ?? cacheReadTokens ?? 0
        }
    }
    
    struct MessageData: Codable {
        let usage: UsageData?
        let model: String?
        let id: String?
    }
    
    /// 转换为标准的使用记录（完全与项目一致）
    func toUsageEntry(projectPath: String, sourceFile: String) -> TestUsageEntry? {
        // 完全复制项目中 RawJSONLEntry.toUsageEntry 的逻辑
        let messageType = type ?? self.messageType ?? ""
        let usageData = usage ?? message?.usage
        
        // 计算总量用于过滤判断
        let totalTokens = (usageData?.inputTokens ?? 0) + 
                         (usageData?.outputTokens ?? 0) + 
                         (usageData?.effectiveCacheCreationTokens ?? 0) + 
                         (usageData?.effectiveCacheReadTokens ?? 0)
        let totalCost = cost ?? costUSD ?? 0
        
        // 修复会话统计问题：不能仅基于tokens和cost来过滤条目
        let hasValidSessionId = (sessionId != nil && !sessionId!.isEmpty && sessionId != "unknown")
        
        // 如果有有效的sessionId，即使没有usage数据也应该保留（用于会话统计）
        // 如果没有sessionId且没有usage数据，才过滤掉
        if !hasValidSessionId && totalTokens == 0 && totalCost == 0 {
            return nil
        }
        
        // 获取模型名称，过滤无效模型（与项目StreamingJSONLParser完全一致）
        let modelName = model ?? message?.model ?? ""
        
        // 过滤掉无效的模型名称（与项目UsageEntry.toUsageEntry完全一致）
        if modelName.isEmpty || modelName == "unknown" || modelName == "<synthetic>" {
            return nil
        }
        
        // 提取token数据
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        let cacheCreationTokens = usageData?.effectiveCacheCreationTokens ?? 0
        let cacheReadTokens = usageData?.effectiveCacheReadTokens ?? 0
        
        // 成本计算：统一使用PricingModel重新计算
        let calculatedCost = calculateCostUsingProjectPricingModel(
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens
        )
        
        // ID提取逻辑（与项目完全一致）
        let extractedRequestId = requestId ?? requestIdUnderscore ?? messageId
        let extractedMessageId = messageId ?? message?.id
        
        // 时间戳处理（与项目完全一致）
        let finalTimestamp = timestamp ?? date ?? formatCurrentDateToISO()
        
        // 项目名称提取（与项目完全一致）
        let projectComponents = projectPath.components(separatedBy: "/")
        let projectName = projectComponents.last ?? "未知项目"
        
        // 日期字符串生成（使用项目的逻辑）
        let dateString = formatDateLikeCcusage(from: finalTimestamp)
        
        return TestUsageEntry(
            timestamp: finalTimestamp,
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cost: calculatedCost,
            sessionId: sessionId ?? "unknown",
            projectPath: projectPath,
            projectName: projectName,
            requestId: extractedRequestId,
            messageId: extractedMessageId,
            messageType: messageType,
            dateString: dateString,
            sourceFile: sourceFile
        )
    }
    
    private func formatCurrentDateToISO() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
    
    /// 精确的日期格式化方法，支持多种时间戳格式
    private func formatDateLikeCcusage(from timestamp: String) -> String {
        // 首先尝试 ISO8601 格式解析
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = iso8601Formatter.date(from: timestamp) {
            return formatDateToString(date)
        }
        
        // 尝试其他常见格式
        let formatters = [
            // ISO8601 无毫秒
            { () -> DateFormatter in
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            // RFC3339 格式
            { () -> DateFormatter in
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            // 简单的日期时间格式
            { () -> DateFormatter in
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss"
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone.current
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: timestamp) {
                return formatDateToString(date)
            }
        }
        
        // 如果所有格式都失败，尝试使用 SQLite datetime 函数的安全方式
        // 检查时间戳是否至少包含日期格式
        if timestamp.count >= 10 && timestamp.contains("-") {
            let dateComponent = String(timestamp.prefix(10))
            // 验证日期格式 YYYY-MM-DD
            if dateComponent.matches("^\\d{4}-\\d{2}-\\d{2}$") {
                return dateComponent
            }
        }
        
        // 最后的回退：返回当前日期（避免错误数据）
        return formatDateToString(Date())
    }
    
    /// 将Date对象格式化为 YYYY-MM-DD 字符串
    private func formatDateToString(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        return dateFormatter.string(from: date)
    }
    
    /// 使用项目PricingModel的成本计算方法（与项目完全一致）
    private func calculateCostUsingProjectPricingModel(model: String, inputTokens: Int, outputTokens: Int,
                                                      cacheCreationTokens: Int, cacheReadTokens: Int) -> Double {
        // 使用与项目PricingModel.swift完全一致的定价表和逻辑
        let pricing: [String: (input: Double, output: Double, cacheWrite: Double, cacheRead: Double)] = [
            // Claude 4 系列（新一代模型）
            "claude-4-opus": (15.0, 75.0, 18.75, 1.5),
            "claude-4-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-4-haiku": (1.0, 5.0, 1.25, 0.1),
            // 别名映射 - 简化版本
            "sonnet-4": (3.0, 15.0, 3.75, 0.3),
            "opus-4": (15.0, 75.0, 18.75, 1.5),
            "haiku-4": (1.0, 5.0, 1.25, 0.1),
            // Claude 3.5 系列
            "claude-3-5-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-3.5-sonnet": (3.0, 15.0, 3.75, 0.3),
            // Claude 3 系列
            "claude-3-opus": (15.0, 75.0, 18.75, 1.5),
            "claude-3-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-3-haiku": (0.25, 1.25, 0.3, 0.03),
            // Gemini 模型（基于 Google AI 官方定价）
            "gemini-2.5-pro": (1.25, 10.0, 0.31, 0.25)
        ]

        // 使用与项目PricingModel.normalizeModelName完全一致的模型名称规范化
        let normalizedModel = normalizeModelNameForPricing(model)
        let modelPricing = pricing[normalizedModel]

        guard let pricingInfo = modelPricing else {
            // 对于未知模型，返回0成本（与项目PricingModel.calculateCost一致）
            return 0.0
        }

        // 使用与项目PricingModel.calculateCost完全一致的计算逻辑
        let inputCost = Double(inputTokens) / 1_000_000 * pricingInfo.input
        let outputCost = Double(outputTokens) / 1_000_000 * pricingInfo.output
        let cacheWriteCost = Double(cacheCreationTokens) / 1_000_000 * pricingInfo.cacheWrite
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * pricingInfo.cacheRead

        let totalCost = inputCost + outputCost + cacheWriteCost + cacheReadCost
        return totalCost
    }
    
    /// 使用与项目PricingModel.normalizeModelName完全一致的模型名称规范化逻辑
    private func normalizeModelNameForPricing(_ model: String) -> String {
        // 直接返回原始模型名，如果在定价表中有精确匹配
        let basePricing = [
            "claude-4-opus", "claude-4-sonnet", "claude-4-haiku",
            "sonnet-4", "opus-4", "haiku-4",
            "claude-3-5-sonnet", "claude-3.5-sonnet",
            "claude-3-opus", "claude-3-sonnet", "claude-3-haiku",
            "gemini-2.5-pro"
        ]

        if basePricing.contains(model) {
            return model
        }

        // 标准化模型名称（与项目PricingModel.performNormalization完全一致）
        // 关键：移除连字符，这是项目PricingModel的核心逻辑
        let normalized = model.lowercased().replacingOccurrences(of: "-", with: "")

        // 模型映射表 - 与项目PricingModel.performNormalization完全一致
        let mappings: [String: String] = [
            // Claude 4 变体（包含具体版本号）- 与项目PricingModel完全一致
            "claude4opus": "claude-4-opus",
            "claude4sonnet": "claude-4-sonnet",
            "claude4haiku": "claude-4-haiku",
            "claudeopus4": "claude-4-opus",
            "claudesonnet4": "claude-4-sonnet",
            "claudehaiku4": "claude-4-haiku",
            // 具体版本号映射（从实际数据中观察到的格式）- 与项目PricingModel完全一致
            "claudesonnet420250514": "claude-4-sonnet",
            "claudeopus420250514": "claude-4-opus",
            "claudehaiku420250514": "claude-4-haiku",
            // 简化命名变体 - 与项目PricingModel完全一致
            "opus4": "claude-4-opus",
            "sonnet4": "claude-4-sonnet",
            "haiku4": "claude-4-haiku",
            // Claude 3.5 变体 - 与项目PricingModel完全一致
            "claude3.5sonnet": "claude-3-5-sonnet",
            "claude35sonnet": "claude-3-5-sonnet",
            "claude3sonnet35": "claude-3-5-sonnet",
            "claudesonnet35": "claude-3-5-sonnet",
            // Claude 3 变体 - 与项目PricingModel完全一致
            "claude3opus": "claude-3-opus",
            "claude3sonnet": "claude-3-sonnet",
            "claude3haiku": "claude-3-haiku",
            "claudeopus3": "claude-3-opus",
            "claudesonnet3": "claude-3-sonnet",
            "claudehaiku3": "claude-3-haiku",
            // Gemini 模型（添加基本支持）- 与项目PricingModel完全一致
            "gemini2.5pro": "gemini-2.5-pro",
            "gemini25pro": "gemini-2.5-pro"
        ]

        if let mapped = mappings[normalized] {
            return mapped
        }

        // 直接匹配的情况（与项目PricingModel.performNormalization完全一致）
        if basePricing.contains(model) {
            return model
        }

        // 如果包含关键词，尝试智能匹配（与项目PricingModel.performNormalization完全一致）
        if model.contains("opus") {
            if model.contains("4") {
                return "claude-4-opus"
            } else if model.contains("3") {
                return "claude-3-opus"
            }
        } else if model.contains("sonnet") {
            if model.contains("4") {
                return "claude-4-sonnet"
            } else if model.contains("3.5") || model.contains("35") {
                return "claude-3-5-sonnet"
            } else if model.contains("3") {
                return "claude-3-sonnet"
            }
        } else if model.contains("haiku") {
            if model.contains("4") {
                return "claude-4-haiku"
            } else if model.contains("3") {
                return "claude-3-haiku"
            }
        }

        // 如果无法匹配，返回normalized（与项目PricingModel.performNormalization完全一致）
        return normalized
    }
}

// MARK: - 数据库管理器（完整版本）

class TestUsageDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    
    init() {
        // 使用项目指定的数据库路径
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                 in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ClaudeBar")
        
        // 确保应用支持目录存在
        try? FileManager.default.createDirectory(at: appDir, 
                                               withIntermediateDirectories: true)
        
        dbPath = appDir.appendingPathComponent("usage_statistics.db").path
        
        do {
            try openDatabase()
            try dropAllTables()  // 删除所有表并重置序列
            try createTables()   // 重新创建表并确保ID从1开始
            print("✅ 测试数据库初始化成功，ID序列已重置: \(dbPath)")
        } catch {
            print("❌ 数据库初始化失败: \(error)")
            exit(1)
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func openDatabase() throws {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            sqlite3_close(db)
            throw TestError.databaseError("连接失败: \(errmsg)")
        }
        
        // 启用外键约束，但暂时不使用WAL模式避免I/O问题
        sqlite3_exec(db, "PRAGMA foreign_keys = ON", nil, nil, nil)
        // sqlite3_exec(db, "PRAGMA journal_mode = WAL", nil, nil, nil)
    }
    
    private func dropAllTables() throws {
        // 强制清除sqlite_sequence表中的所有序列记录（在删除表之前）
        try? executeSQL("DELETE FROM sqlite_sequence")
        
        // 删除表结构
        let dropTables = [
            "DROP TABLE IF EXISTS usage_entries",
            "DROP TABLE IF EXISTS jsonl_files", 
            "DROP TABLE IF EXISTS daily_statistics",
            "DROP TABLE IF EXISTS model_statistics",
            "DROP TABLE IF EXISTS project_statistics"
        ]
        
        // 执行删除表
        for dropSQL in dropTables {
            try executeSQL(dropSQL)
        }
        
        // 再次强制清除sqlite_sequence（确保彻底清理）
        try? executeSQL("DELETE FROM sqlite_sequence")
        
        // 执行VACUUM来重建数据库文件，彻底清除残留数据
        try? executeSQL("VACUUM")
        
        print("🗑️ 已删除所有现有表、重置序列并压缩数据库")
    }
    
    private func ensureAutoIncrementFromOne() throws {
        // 彻底重置AUTO_INCREMENT序列的多重保险方法
        let tableNames = ["usage_entries", "jsonl_files", "daily_statistics", "model_statistics", "project_statistics"]
        
        // 方法1：强制删除所有sequence记录
        try? executeSQL("DELETE FROM sqlite_sequence")
        
        // 方法2：为每个表明确设置序列值为0（下一个ID将是1）
        for tableName in tableNames {
            try? executeSQL("DELETE FROM sqlite_sequence WHERE name='\(tableName)'")
            try? executeSQL("INSERT OR REPLACE INTO sqlite_sequence (name, seq) VALUES ('\(tableName)', 0)")
        }
        
        // 方法3：通过一个虚拟插入和删除来强制重置（最可靠的方法）
        for tableName in tableNames {
            // 插入一条虚拟记录来触发AUTO_INCREMENT
            switch tableName {
            case "usage_entries":
                try? executeSQL("INSERT INTO usage_entries (timestamp, model) VALUES ('test', 'test')")
                try? executeSQL("DELETE FROM usage_entries WHERE model='test'")
            case "jsonl_files":
                try? executeSQL("INSERT INTO jsonl_files (file_path, file_name, file_size, last_modified) VALUES ('test', 'test', 0, 'test')")
                try? executeSQL("DELETE FROM jsonl_files WHERE file_path='test'")
            case "daily_statistics":
                try? executeSQL("INSERT INTO daily_statistics (date_string) VALUES ('test')")
                try? executeSQL("DELETE FROM daily_statistics WHERE date_string='test'")
            case "model_statistics":
                try? executeSQL("INSERT INTO model_statistics (model, date_range) VALUES ('test', 'test')")
                try? executeSQL("DELETE FROM model_statistics WHERE model='test'")
            case "project_statistics":
                try? executeSQL("INSERT INTO project_statistics (project_path, project_name, date_range) VALUES ('test', 'test', 'test')")
                try? executeSQL("DELETE FROM project_statistics WHERE project_path='test'")
            default:
                break
            }
            
            // 再次确保序列重置为0
            try? executeSQL("UPDATE sqlite_sequence SET seq = 0 WHERE name='\(tableName)'")
        }
        
        print("🔄 已通过多重方法强制重置所有AUTO_INCREMENT序列从1开始")
    }
    
    private func createTables() throws {
        let createUsageEntriesTable = """
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
        
        let createJSONLFilesTable = """
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
        
        let createDailyStatsTable = """
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
        
        let createModelStatsTable = """
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
        
        let createProjectStatsTable = """
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
        
        let createIndexes = [
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_timestamp ON usage_entries(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_date_string ON usage_entries(date_string)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_model ON usage_entries(model)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_project_path ON usage_entries(project_path)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_session_id ON usage_entries(session_id)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_source_file ON usage_entries(source_file)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_request_message ON usage_entries(request_id, message_id)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_composite ON usage_entries(date_string, model, project_path)",
            "CREATE INDEX IF NOT EXISTS idx_usage_entries_source_composite ON usage_entries(source_file, timestamp)",
            
            "CREATE INDEX IF NOT EXISTS idx_jsonl_files_path ON jsonl_files(file_path)",
            "CREATE INDEX IF NOT EXISTS idx_jsonl_files_modified ON jsonl_files(last_modified)",
            "CREATE INDEX IF NOT EXISTS idx_jsonl_files_status ON jsonl_files(processing_status)",
            
            "CREATE INDEX IF NOT EXISTS idx_daily_stats_date ON daily_statistics(date_string)",
            "CREATE INDEX IF NOT EXISTS idx_model_stats_composite ON model_statistics(model, date_range)",
            "CREATE INDEX IF NOT EXISTS idx_project_stats_composite ON project_statistics(project_path, date_range)"
        ]
        
        // 创建所有表
        try executeSQL(createUsageEntriesTable)
        try executeSQL(createJSONLFilesTable)
        try executeSQL(createDailyStatsTable)
        try executeSQL(createModelStatsTable)
        try executeSQL(createProjectStatsTable)
        
        // 强制确保AUTO_INCREMENT从1开始
        try ensureAutoIncrementFromOne()
        
        // 创建所有索引
        for indexSQL in createIndexes {
            try executeSQL(indexSQL)
        }
        
        print("✅ 数据库表和索引创建完成（5个表），ID序列已重置为从1开始")
    }
    
    private func executeSQL(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw TestError.databaseError("SQL执行失败: \(errmsg)")
        }
    }
    
    func insertUsageEntries(_ entries: [TestUsageEntry]) throws -> Int {
        let insertSQL = """
        INSERT OR IGNORE INTO usage_entries (
            timestamp, model, input_tokens, output_tokens, 
            cache_creation_tokens, cache_read_tokens, cost,
            session_id, project_path, project_name, 
            request_id, message_id, message_type, date_string, source_file,
            created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        var insertedCount = 0
        
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw TestError.databaseError("准备插入语句失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 开始事务
        try executeSQL("BEGIN TRANSACTION")
        
        do {
            for entry in entries {
                sqlite3_reset(statement)
                
                // 绑定参数
                try bindUsageEntry(statement, entry: entry)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    if sqlite3_changes(db) > 0 {
                        insertedCount += 1
                    }
                }
            }
            
            try executeSQL("COMMIT")
            
        } catch {
            try? executeSQL("ROLLBACK")
            throw error
        }
        
        return insertedCount
    }
    
    private func bindUsageEntry(_ statement: OpaquePointer?, entry: TestUsageEntry) throws {
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
    
    func queryUsageEntries(limit: Int = 10) throws -> [TestUsageEntry] {
        let sql = """
        SELECT timestamp, model, input_tokens, output_tokens,
               cache_creation_tokens, cache_read_tokens, cost,
               session_id, project_path, project_name,
               request_id, message_id, message_type, date_string, source_file
        FROM usage_entries
        ORDER BY timestamp DESC
        LIMIT \(limit)
        """
        
        var statement: OpaquePointer?
        var entries: [TestUsageEntry] = []
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw TestError.databaseError("准备查询语句失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let entry = parseUsageEntryFromRow(statement) {
                entries.append(entry)
            }
        }
        
        return entries
    }
    
    private func parseUsageEntryFromRow(_ statement: OpaquePointer?) -> TestUsageEntry? {
        guard let statement = statement else { return nil }
        
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
        
        return TestUsageEntry(
            timestamp: getText(0),
            model: getText(1),
            inputTokens: Int(sqlite3_column_int64(statement, 2)),
            outputTokens: Int(sqlite3_column_int64(statement, 3)),
            cacheCreationTokens: Int(sqlite3_column_int64(statement, 4)),
            cacheReadTokens: Int(sqlite3_column_int64(statement, 5)),
            cost: sqlite3_column_double(statement, 6),
            sessionId: getText(7),
            projectPath: getText(8),
            projectName: getText(9),
            requestId: getOptionalText(10),
            messageId: getOptionalText(11),
            messageType: getText(12),
            dateString: getText(13),
            sourceFile: getText(14)
        )
    }
    
    func updateDailyStatistics() throws {
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
    
    func getStatisticsSummary() throws -> StatisticsSummary {
        let sql = """
        SELECT 
            COUNT(*) as total_requests,
            COUNT(DISTINCT session_id) as total_sessions,
            SUM(cost) as total_cost,
            SUM(total_tokens) as total_tokens,
            COUNT(DISTINCT model) as model_count,
            COUNT(DISTINCT project_path) as project_count
        FROM usage_entries
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw TestError.databaseError("准备统计查询失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return StatisticsSummary(
                totalRequests: Int(sqlite3_column_int(statement, 0)),
                totalSessions: Int(sqlite3_column_int(statement, 1)),
                totalCost: sqlite3_column_double(statement, 2),
                totalTokens: Int(sqlite3_column_int64(statement, 3)),
                modelCount: Int(sqlite3_column_int(statement, 4)),
                projectCount: Int(sqlite3_column_int(statement, 5))
            )
        }
        
        return StatisticsSummary(totalRequests: 0, totalSessions: 0, totalCost: 0, totalTokens: 0, modelCount: 0, projectCount: 0)
    }
    
    // MARK: - JSONL文件跟踪操作
    
    func recordFileProcessing(_ fileURL: URL, fileSize: Int64, lastModified: Date) throws {
        let insertSQL = """
        INSERT OR REPLACE INTO jsonl_files 
        (file_path, file_name, file_size, last_modified, processing_status, 
         created_at, updated_at)
        VALUES (?, ?, ?, ?, 'processing', datetime('now', 'localtime'), datetime('now', 'localtime'))
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw TestError.databaseError("准备文件记录语句失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        let formatter = ISO8601DateFormatter()
        let lastModifiedString = formatter.string(from: lastModified)
        
        // 使用 SQLITE_TRANSIENT 确保字符串安全
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        _ = fileURL.path.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = fileURL.lastPathComponent.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 3, fileSize)
        _ = lastModifiedString.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw TestError.databaseError("记录文件状态失败: \(errmsg)")
        }
    }
    
    func updateFileProcessingCompleted(_ fileURL: URL, entryCount: Int) throws {
        let updateSQL = """
        UPDATE jsonl_files 
        SET processing_status = 'completed', 
            entry_count = ?, 
            last_processed = datetime('now', 'localtime'),
            updated_at = datetime('now', 'localtime')
        WHERE file_path = ?
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw TestError.databaseError("准备更新文件状态语句失败: \(errmsg)")
        }
        
        defer { sqlite3_finalize(statement) }
        
        // 使用 SQLITE_TRANSIENT 确保字符串安全
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        sqlite3_bind_int(statement, 1, Int32(entryCount))
        _ = fileURL.path.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw TestError.databaseError("更新文件状态失败: \(errmsg)")
        }
    }
    
    // MARK: - 统计汇总生成
    
    func generateAllStatistics() throws {
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
        print("   ✅ 每日统计表重新生成完成（ID从1开始）")
    }
    
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
    
    // MARK: - 日期字符串修复方法
    
    func updateAllDateStrings() throws {
        print("🗓️ 修复所有日期字符串...")
        
        // 使用 SQLite 的 datetime 函数进行精确的日期解析
        // 这个方法可以正确处理 ISO8601 时间戳并转换为本地日期
        let updateSQL = """
        UPDATE usage_entries 
        SET date_string = date(datetime(timestamp, 'localtime'))
        WHERE timestamp IS NOT NULL AND timestamp != ''
        """
        
        if sqlite3_exec(db, updateSQL, nil, nil, nil) == SQLITE_OK {
            // 检查是否有无法解析的时间戳，使用备用方法
            let checkSQL = """
            UPDATE usage_entries 
            SET date_string = substr(timestamp, 1, 10)
            WHERE date_string IS NULL OR date_string = '' OR date_string = '1970-01-01'
            """
            
            if sqlite3_exec(db, checkSQL, nil, nil, nil) == SQLITE_OK {
                print("✅ 日期字符串修复完成")
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                throw TestError.databaseError("日期字符串备用修复失败: \(errmsg)")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw TestError.databaseError("日期字符串修复失败: \(errmsg)")
        }
    }
    
    // MARK: - 去重处理（与项目UsageService保持一致）
    
    func deduplicateEntries() throws {
        print("🧹 开始激进去重逻辑处理...")
        
        // 开始事务
        try executeSQL("BEGIN TRANSACTION")
        
        do {
            // 创建临时表存储去重后的数据
            let createTempTableSQL = """
            CREATE TEMP TABLE temp_unique_entries AS
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY 
                           CASE 
                               WHEN message_id IS NOT NULL AND request_id IS NOT NULL 
                               THEN message_id || ':' || request_id
                               ELSE CAST(id AS TEXT) 
                           END
                       ORDER BY timestamp
                   ) as rn
            FROM usage_entries
            WHERE message_id IS NOT NULL AND request_id IS NOT NULL
            
            UNION ALL
            
            SELECT *, 1 as rn
            FROM usage_entries 
            WHERE message_id IS NULL OR request_id IS NULL
            """
            
            try executeSQL(createTempTableSQL)
            
            // 统计去重前后的数量
            let beforeCount = getCount(sql: "SELECT COUNT(*) FROM usage_entries")
            let afterCount = getCount(sql: "SELECT COUNT(*) FROM temp_unique_entries WHERE rn = 1")
            let duplicateCount = beforeCount - afterCount
            
            // 删除原表数据
            try executeSQL("DELETE FROM usage_entries")
            
            // 插入去重后的数据 (排除生成列 total_tokens)
            let insertSQL = """
            INSERT INTO usage_entries (
                id, timestamp, model, input_tokens, output_tokens, 
                cache_creation_tokens, cache_read_tokens, cost,
                session_id, project_path, project_name, 
                request_id, message_id, message_type, date_string, source_file,
                created_at, updated_at
            )
            SELECT id, timestamp, model, input_tokens, output_tokens, 
                   cache_creation_tokens, cache_read_tokens, cost,
                   session_id, project_path, project_name, 
                   request_id, message_id, message_type, date_string, source_file,
                   created_at, updated_at
            FROM temp_unique_entries 
            WHERE rn = 1
            """
            
            try executeSQL(insertSQL)
            
            // 删除临时表
            try executeSQL("DROP TABLE temp_unique_entries")
            
            // 提交事务
            try executeSQL("COMMIT")
            
            print("📊 去重统计: 原始 \(beforeCount) 条，去重后 \(afterCount) 条")
            print("📊 重复记录: \(duplicateCount) 条")
            print("✅ 去重处理完成")
            
        } catch {
            try? executeSQL("ROLLBACK")
            throw error
        }
    }
    
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

// MARK: - 数据结构

struct StatisticsSummary {
    let totalRequests: Int
    let totalSessions: Int
    let totalCost: Double
    let totalTokens: Int
    let modelCount: Int
    let projectCount: Int
    
    var summary: String {
        return """
        总请求: \(totalRequests), 总会话: \(totalSessions)
        总成本: $\(String(format: "%.6f", totalCost)), 总Token: \(totalTokens)
        模型数: \(modelCount), 项目数: \(projectCount)
        """
    }
}

enum TestError: Error {
    case databaseError(String)
    case testFailed(String)
}

// MARK: - 测试主程序（完整版本）

class UsageDatabaseTest {
    private let database: TestUsageDatabase
    private let decoder = JSONDecoder()
    
    init() {
        self.database = TestUsageDatabase()
    }
    
    func runAllTests() throws {
        print("🧪 开始使用统计数据库测试...")
        print("=====================================")
        
        try testRealDataMigration()
        try testDataQuery()
        try testStatisticsGeneration()
        
        print("=====================================")
        print("✅ 所有测试通过！")
    }
    
    private func testRealDataMigration() throws {
        print("\n📁 测试1: 读取真实JSONL文件并迁移数据")
        
        // 获取Claude项目目录
        let claudeDirectory = getClaudeDirectory()
        let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
        
        guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
            print("⚠️ Claude projects目录不存在: \(projectsDirectory.path)")
            print("📝 使用测试数据替代...")
            try insertTestData()
            return
        }
        
        print("📂 扫描目录: \(projectsDirectory.path)")
        
        // 扫描所有JSONL文件
        let jsonlFiles = try scanJSONLFiles(in: projectsDirectory)
        print("📄 找到 \(jsonlFiles.count) 个JSONL文件")
        
        if jsonlFiles.isEmpty {
            print("⚠️ 未找到JSONL文件，使用测试数据替代...")
            try insertTestData()
            return
        }
        
        // 解析并插入真实数据
        var totalEntries = 0
        var totalInserted = 0
        var filesWithData = 0
        var filesEmpty = 0
        
        print("🔍 开始处理JSONL文件，共 \(jsonlFiles.count) 个")
        
        for (index, fileURL) in jsonlFiles.enumerated() {
            do {
                let fileName = fileURL.lastPathComponent
                print("📝 处理文件 (\(index + 1)/\(jsonlFiles.count)): \(fileName)")
                
                // 检查文件大小
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                if fileSize == 0 {
                    print("   ⚠️ 文件为空，跳过")
                    filesEmpty += 1
                    continue
                }
                
                print("   📦 文件大小: \(fileSize) bytes")
                
                let modificationDate = attributes[.modificationDate] as? Date ?? Date()
                
                try database.recordFileProcessing(fileURL, fileSize: fileSize, lastModified: modificationDate)
                
                let entries = try parseJSONLFile(fileURL)
                totalEntries += entries.count
                
                if !entries.isEmpty {
                    let inserted = try database.insertUsageEntries(entries)
                    totalInserted += inserted
                    filesWithData += 1
                    print("   ✅ 解析 \(entries.count) 条，插入 \(inserted) 条")
                } else {
                    filesEmpty += 1
                    print("   ⚠️ 无有效数据")
                }
                
                // 更新文件处理完成状态
                try database.updateFileProcessingCompleted(fileURL, entryCount: entries.count)
                
                // 每处理10个文件显示进度
                if (index + 1) % 10 == 0 || index == jsonlFiles.count - 1 {
                    let progress = Double(index + 1) / Double(jsonlFiles.count) * 100
                    print("   📈 进度: \(String(format: "%.1f", progress))% - 有效文件: \(filesWithData), 空文件: \(filesEmpty)")
                }
                
            } catch {
                print("   ❌ 处理失败: \(error.localizedDescription)")
                filesEmpty += 1
            }
        }
        
        print("📊 迁移完成: 总记录 \(totalEntries)，插入 \(totalInserted)")
        print("📁 文件统计: 有效文件 \(filesWithData) 个，空文件 \(filesEmpty) 个")
        print("📈 数据效率: \(String(format: "%.1f", Double(filesWithData) / Double(jsonlFiles.count) * 100))%")
        
        // 修复数据库中的关键问题
        print("🔧 修复数据库中的日期字符串和成本问题...")
        try database.updateAllDateStrings()
        
        // 添加去重逻辑（与项目UsageService保持一致）
        try database.deduplicateEntries()
        
        // 生成所有统计汇总
        try database.generateAllStatistics()
        
        print("✅ 真实数据迁移测试通过")
    }
    
    private func insertTestData() throws {
        let testEntries = createFallbackTestData()
        let insertedCount = try database.insertUsageEntries(testEntries)
        print("📝 插入测试数据: \(insertedCount) 条")
        
        // 修复测试数据的日期字符串
        try database.updateAllDateStrings()
        
        // 生成统计汇总
        try database.generateAllStatistics()
    }
    
    private func getClaudeDirectory() -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(".claude")
    }
    
    private func scanJSONLFiles(in directory: URL) throws -> [URL] {
        var jsonlFiles: [URL] = []
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
        
        if let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                print("⚠️ 访问文件失败: \(url.path) - \(error.localizedDescription)")
                return true
            }
        ) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                    
                    if let isDirectory = resourceValues.isDirectory, !isDirectory,
                       let name = resourceValues.name, name.hasSuffix(".jsonl") {
                        jsonlFiles.append(fileURL)
                    }
                } catch {
                    print("⚠️ 获取文件属性失败: \(fileURL.path) - \(error.localizedDescription)")
                }
            }
        }
        
        // 按文件大小排序，小文件优先
        jsonlFiles.sort { url1, url2 in
            let size1 = (try? url1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let size2 = (try? url2.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return size1 < size2
        }
        
        return jsonlFiles
    }
    
    private func parseJSONLFile(_ fileURL: URL) throws -> [TestUsageEntry] {
        let data = try Data(contentsOf: fileURL)
        let content = String(data: data, encoding: .utf8) ?? ""
        
        // 从文件路径提取项目路径（与StreamingJSONLParser完全一致）
        let projectPath = extractProjectPath(from: fileURL)
        
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var entries: [TestUsageEntry] = []
        var validLines = 0
        var skippedLines = 0
        
        for (_, line) in lines.enumerated() {
            do {
                let jsonData = line.data(using: .utf8) ?? Data()
                
                // 使用与StreamingJSONLParser完全相同的解析逻辑
                let rawEntry = try decoder.decode(RawJSONLEntry.self, from: jsonData)
                
                // 转换为标准使用记录（使用与项目完全一致的逻辑）
                if let entry = rawEntry.toUsageEntry(projectPath: projectPath, sourceFile: fileURL.lastPathComponent) {
                    entries.append(entry)
                    validLines += 1
                } else {
                    skippedLines += 1
                }
                
            } catch {
                skippedLines += 1
                // 与StreamingJSONLParser一致：不记录每个解析错误，以减少日志开销
            }
        }
        
        return entries
    }
    
    private func extractProjectPath(from fileURL: URL) -> String {
        // 与StreamingJSONLParser完全一致的项目路径提取逻辑
        let pathComponents = fileURL.pathComponents
        
        // 查找 "projects" 目录的位置
        if let projectsIndex = pathComponents.firstIndex(of: "projects"),
           projectsIndex + 1 < pathComponents.count {
            
            // 项目路径是从 projects 目录的下一级开始
            let projectComponents = Array(pathComponents[(projectsIndex + 1)...])
            
            // 移除最后的文件名，只保留目录路径
            let directoryComponents = projectComponents.dropLast()
            
            if !directoryComponents.isEmpty {
                return "/" + directoryComponents.joined(separator: "/")
            }
        }
        
        // 如果无法确定项目路径，返回文件所在目录
        return fileURL.deletingLastPathComponent().path
    }
    
    private func createFallbackTestData() -> [TestUsageEntry] {
        let formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let testData = [
            ("claude-4-sonnet", 1000, 500, 200, 100, "session-1", "/test/project1"),
            ("claude-3.5-sonnet", 800, 300, 0, 50, "session-1", "/test/project1"),
            ("claude-4-opus", 1200, 800, 300, 150, "session-2", "/test/project2"),
            ("claude-4-sonnet", 600, 400, 100, 80, "session-2", "/test/project2"),
            ("claude-3-haiku", 400, 200, 0, 20, "session-3", "/test/project3"),
            ("claude-4-sonnet", 900, 600, 150, 75, "session-4", "/test/project1"),
            ("claude-4-opus", 1500, 1000, 400, 200, "session-5", "/test/project3")
        ]
        
        return testData.enumerated().map { index, data in
            let timestamp = Date().addingTimeInterval(TimeInterval(index * -3600))
            let cost = calculateTestCostUsingProjectPricing(model: data.0,
                                                          inputTokens: data.1,
                                                          outputTokens: data.2,
                                                          cacheCreationTokens: data.3,
                                                          cacheReadTokens: data.4)
            
            return TestUsageEntry(
                timestamp: formatter.string(from: timestamp),
                model: data.0,
                inputTokens: data.1,
                outputTokens: data.2,
                cacheCreationTokens: data.3,
                cacheReadTokens: data.4,
                cost: cost,
                sessionId: data.5,
                projectPath: data.6,
                projectName: String(data.6.split(separator: "/").last ?? "unknown"),
                requestId: "req-\(index + 1)",
                messageId: "msg-\(index + 1)",
                messageType: "assistant",
                dateString: dateFormatter.string(from: timestamp),
                sourceFile: "test-session-\(data.5).jsonl"
            )
        }
    }

    /// 使用项目PricingModel逻辑计算测试数据成本
    private func calculateTestCostUsingProjectPricing(model: String, inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int) -> Double {
        // 使用与项目PricingModel.swift完全一致的定价表和逻辑
        let pricing: [String: (input: Double, output: Double, cacheWrite: Double, cacheRead: Double)] = [
            "claude-4-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-4-opus": (15.0, 75.0, 18.75, 1.5),
            "claude-3.5-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-3-haiku": (0.25, 1.25, 0.3, 0.03),
            "gemini-2.5-pro": (1.25, 10.0, 0.00, 0.00)
        ]

        guard let modelPricing = pricing[model] else { return 0.0 }

        let inputCost = Double(inputTokens) / 1_000_000 * modelPricing.input
        let outputCost = Double(outputTokens) / 1_000_000 * modelPricing.output
        let cacheWriteCost = Double(cacheCreationTokens) / 1_000_000 * modelPricing.cacheWrite
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * modelPricing.cacheRead

        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }


    private func testDataQuery() throws {
        print("\n🔍 测试2: 数据查询功能")
        
        let queriedEntries = try database.queryUsageEntries(limit: 10)
        print("查询到 \(queriedEntries.count) 条记录")
        
        guard !queriedEntries.isEmpty else {
            throw TestError.testFailed("查询结果为空")
        }
        
        // 验证查询的数据内容
        let firstEntry = queriedEntries[0]
        print("第一条记录: 模型=\(firstEntry.model), Token=\(firstEntry.totalTokens), 成本=$\(String(format: "%.6f", firstEntry.cost))")
        
        print("✅ 数据查询测试通过")
    }
    
    private func testStatisticsGeneration() throws {
        print("\n📊 测试3: 统计数据生成")
        
        try database.updateDailyStatistics()
        print("每日统计更新完成")
        
        let stats = try database.getStatisticsSummary()
        print("统计摘要:")
        print(stats.summary)
        
        guard stats.totalRequests > 0 && stats.totalTokens > 0 else {
            throw TestError.testFailed("统计数据异常: 请求数或Token数为0")
        }
        
        print("✅ 统计数据生成测试通过")
    }
    
    private func createTestData() -> [TestUsageEntry] {
        let formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let testData = [
            ("claude-4-sonnet", 1000, 500, 200, 100, "session-1", "/test/project1"),
            ("claude-3.5-sonnet", 800, 300, 0, 50, "session-1", "/test/project1"),
            ("claude-4-opus", 1200, 800, 300, 150, "session-2", "/test/project2"),
            ("claude-4-sonnet", 600, 400, 100, 80, "session-2", "/test/project2"),
            ("claude-3-haiku", 400, 200, 0, 20, "session-3", "/test/project3"),
            ("claude-4-sonnet", 900, 600, 150, 75, "session-4", "/test/project1"),
            ("claude-4-opus", 1500, 1000, 400, 200, "session-5", "/test/project3")
        ]
        
        return testData.enumerated().map { index, data in
            let timestamp = Date().addingTimeInterval(TimeInterval(index * -3600))
            let cost = calculateSimpleCost(model: data.0, 
                                         inputTokens: data.1, 
                                         outputTokens: data.2, 
                                         cacheCreationTokens: data.3, 
                                         cacheReadTokens: data.4)
            
            return TestUsageEntry(
                timestamp: formatter.string(from: timestamp),
                model: data.0,
                inputTokens: data.1,
                outputTokens: data.2,
                cacheCreationTokens: data.3,
                cacheReadTokens: data.4,
                cost: cost,
                sessionId: data.5,
                projectPath: data.6,
                projectName: String(data.6.split(separator: "/").last ?? "unknown"),
                requestId: "req-\(index + 1)",
                messageId: "msg-\(index + 1)",
                messageType: "assistant",
                dateString: dateFormatter.string(from: timestamp),
                sourceFile: "test-session-\(data.5).jsonl"
            )
        }
    }
    
    private func calculateSimpleCost(model: String, inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int) -> Double {
        // 简化的成本计算
        let pricing: [String: (input: Double, output: Double, cacheWrite: Double, cacheRead: Double)] = [
            "claude-4-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-4-opus": (15.0, 75.0, 18.75, 1.5),
            "claude-3.5-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-3-haiku": (0.25, 1.25, 0.3, 0.03),
            "gemini-2.5-pro": (1.25, 10.0, 0.31, 0.25)
        ]
        
        guard let modelPricing = pricing[model] else { return 0.0 }
        
        let inputCost = Double(inputTokens) / 1_000_000 * modelPricing.input
        let outputCost = Double(outputTokens) / 1_000_000 * modelPricing.output
        let cacheWriteCost = Double(cacheCreationTokens) / 1_000_000 * modelPricing.cacheWrite
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * modelPricing.cacheRead
        
        let totalCost = inputCost + outputCost + cacheWriteCost + cacheReadCost
        // 与项目PricingModel保持一致：不做精度处理，返回完整Double值
        return totalCost
    }
}

// MARK: - 主程序入口

func main() {
    print("🚀 启动使用统计数据库测试程序")
    
    do {
        let test = UsageDatabaseTest()
        try test.runAllTests()
        
        print("\n🎉 测试程序执行完成")
        print("数据库文件位置: ~/Library/Application Support/ClaudeBar/usage_statistics.db")
        print("您可以使用SQLite工具查看数据库内容")
        
    } catch {
        print("❌ 测试失败: \(error)")
        exit(1)
    }
}

// 运行主程序
main()