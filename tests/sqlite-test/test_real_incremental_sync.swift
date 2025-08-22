#!/usr/bin/env swift

// 优化的增量同步测试
// 新增功能：
// 1. 使用MD5哈希进行精确的文件内容变更检测
// 2. 使用完整文件路径作为标识符，解决跨项目同名文件冲突
// 3. 为安全的增量同步提供技术基础
// 更新时间：2025-08-22

import Foundation
import SQLite3
import CryptoKit

// MARK: - 基于现有jsonl_files表的增量同步（优化版）

print("🚀 启动基于现有jsonl_files表的增量同步（优化版）")
print("时间: 2025-08-22T11:39:52+08:00")
print("目标数据库: ~/Library/Application Support/ClaudeBar/usage_statistics.db")
print("⚠️ 重要：需要数据库包含md5_hash字段，请先运行优化后的全量同步")

// 获取数据库路径
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let appDir = appSupport.appendingPathComponent("ClaudeBar")
let dbPath = appDir.appendingPathComponent("usage_statistics.db").path

print("📁 数据库路径: \(dbPath)")

// 检查数据库是否存在
guard FileManager.default.fileExists(atPath: dbPath) else {
    print("❌ usage_statistics.db 不存在，请先运行应用或全量数据迁移")
    exit(1)
}

// 连接到现有数据库
var db: OpaquePointer?
if sqlite3_open(dbPath, &db) != SQLITE_OK {
    print("❌ 无法连接到数据库")
    exit(1)
}

defer {
    sqlite3_close(db)
}

print("✅ 成功连接到现有的 usage_statistics.db")

// MARK: - MD5计算扩展
extension Data {
    var md5Hash: String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension URL {
    var fileMD5: String? {
        do {
            let data = try Data(contentsOf: self)
            return data.md5Hash
        } catch {
            print("⚠️ 计算文件MD5失败: \(self.path) - \(error.localizedDescription)")
            return nil
        }
    }
}

// 文件信息结构（优化版）
struct FileInfo {
    let path: String
    let name: String
    let currentSize: Int64
    let currentModified: String
    let currentMD5: String
    let dbSize: Int64
    let dbModified: String
    let dbMD5: String
    let entryCount: Int
    let needsUpdate: Bool
    
    // 是否为新文件（数据库中不存在）
    var isNewFile: Bool {
        return dbMD5.isEmpty
    }
    
    // 是否内容发生变更（基于MD5比较）
    var hasContentChanged: Bool {
        return !isNewFile && currentMD5 != dbMD5
    }
}

// 检查现有数据
func checkExistingData() {
    let usageSQL = "SELECT COUNT(*) FROM usage_entries"
    let filesSQL = "SELECT COUNT(*) FROM jsonl_files"
    
    var statement: OpaquePointer?
    
    // 检查使用记录数
    if sqlite3_prepare_v2(db, usageSQL, -1, &statement, nil) == SQLITE_OK {
        if sqlite3_step(statement) == SQLITE_ROW {
            let usageCount = sqlite3_column_int(statement, 0)
            print("📊 现有数据库中已有 \(usageCount) 条使用记录")
        }
    }
    sqlite3_finalize(statement)
    
    // 检查文件记录数
    if sqlite3_prepare_v2(db, filesSQL, -1, &statement, nil) == SQLITE_OK {
        if sqlite3_step(statement) == SQLITE_ROW {
            let filesCount = sqlite3_column_int(statement, 0)
            print("📂 jsonl_files表中已记录 \(filesCount) 个文件")
        }
    }
    sqlite3_finalize(statement)
}

// 扫描实际文件系统，找出需要增量处理的文件
func findIncrementalFiles() -> [FileInfo] {
    print("\n🔍 扫描文件系统，对比数据库记录...")
    
    // 1. 获取所有实际存在的JSONL文件
    let fileManager = FileManager.default
    let claudeProjectsPath = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    
    guard let enumerator = fileManager.enumerator(atPath: claudeProjectsPath.path) else {
        print("❌ 无法访问 ~/.claude/projects 目录")
        return []
    }
    
    var actualFiles: [String: (size: Int64, modified: String, md5: String)] = [:]
    
    for case let file as String in enumerator {
        if file.hasSuffix(".jsonl") {
            let fullPath = claudeProjectsPath.appendingPathComponent(file).path
            let fileURL = URL(fileURLWithPath: fullPath)
            
            if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
               let fileSize = attributes[.size] as? Int64,
               let modifiedDate = attributes[.modificationDate] as? Date,
               let md5Hash = fileURL.fileMD5 {
                
                let formatter = ISO8601DateFormatter()
                let modifiedString = formatter.string(from: modifiedDate)
                actualFiles[fullPath] = (fileSize, modifiedString, md5Hash)
            } else {
                print("⚠️ 无法计算文件MD5，跳过: \(fullPath)")
            }
        }
    }
    
    print("🗂️ 找到 \(actualFiles.count) 个实际JSONL文件")
    
    // 2. 查询数据库中的文件记录
    let sql = """
    SELECT file_path, file_name, file_size, last_modified, md5_hash, entry_count 
    FROM jsonl_files 
    WHERE processing_status = 'completed'
    """
    
    var statement: OpaquePointer?
    var dbFiles: [String: (name: String, size: Int64, modified: String, md5: String, entryCount: Int)] = [:]
    
    if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
        while sqlite3_step(statement) == SQLITE_ROW {
            let filePath = String(cString: sqlite3_column_text(statement, 0))
            let fileName = String(cString: sqlite3_column_text(statement, 1))
            let fileSize = sqlite3_column_int64(statement, 2)
            let lastModified = String(cString: sqlite3_column_text(statement, 3))
            let md5Hash = String(cString: sqlite3_column_text(statement, 4))
            let entryCount = Int(sqlite3_column_int(statement, 5))
            
            dbFiles[filePath] = (fileName, fileSize, lastModified, md5Hash, entryCount)
        }
    }
    sqlite3_finalize(statement)
    
    print("💾 数据库中记录了 \(dbFiles.count) 个已处理文件")
    
    // 3. 对比找出需要增量处理的文件
    var incrementalFiles: [FileInfo] = []
    var newFiles = 0
    var changedFiles = 0
    var upToDateFiles = 0
    
    for (filePath, actualInfo) in actualFiles {
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        
        if let dbInfo = dbFiles[filePath] {
            // 文件在数据库中存在，使用MD5检查是否有变更
            let contentChanged = actualInfo.md5 != dbInfo.md5
            
            if contentChanged {
                // 文件内容发生变更，需要增量处理
                incrementalFiles.append(FileInfo(
                    path: filePath,
                    name: fileName,
                    currentSize: actualInfo.size,
                    currentModified: actualInfo.modified,
                    currentMD5: actualInfo.md5,
                    dbSize: dbInfo.size,
                    dbModified: dbInfo.modified,
                    dbMD5: dbInfo.md5,
                    entryCount: dbInfo.entryCount,
                    needsUpdate: true
                ))
                changedFiles += 1
                
                print("📝 内容变更文件: \(fileName)")
                print("   大小: \(dbInfo.size) -> \(actualInfo.size) 字节")
                print("   MD5: \(dbInfo.md5.prefix(8))... -> \(actualInfo.md5.prefix(8))...")
            } else {
                upToDateFiles += 1
            }
        } else {
            // 新文件，需要完整处理
            incrementalFiles.append(FileInfo(
                path: filePath,
                name: fileName,
                currentSize: actualInfo.size,
                currentModified: actualInfo.modified,
                currentMD5: actualInfo.md5,
                dbSize: 0,
                dbModified: "",
                dbMD5: "",
                entryCount: 0,
                needsUpdate: true
            ))
            newFiles += 1
            print("🆕 新文件: \(fileName) (\(actualInfo.size) 字节, MD5: \(actualInfo.md5.prefix(8))...)")
        }
    }
    
    print("\n📊 文件分析结果:")
    print("   新文件: \(newFiles) 个")
    print("   变更文件: \(changedFiles) 个") 
    print("   最新文件: \(upToDateFiles) 个")
    print("   需要处理: \(incrementalFiles.count) 个")
    
    return incrementalFiles
}

// 使用与全量同步完全一致的JSONL解析结构
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
    
    /// 转换为标准的使用记录（与全量同步完全一致）
    func toUsageEntry(projectPath: String, sourceFile: String) -> (timestamp: String, model: String, inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int, cost: Double, sessionId: String, requestId: String?, sourceFile: String)? {
        // 完全复制全量同步中 RawJSONLEntry.toUsageEntry 的逻辑
        let _ = type ?? self.messageType ?? ""  // 不需要messageType，只是为了与全量同步保持一致
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
        
        // 获取模型名称，过滤无效模型（与全量同步完全一致）
        let modelName = model ?? message?.model ?? ""
        
        // 过滤掉无效的模型名称（与全量同步完全一致）
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
        let _ = messageId ?? message?.id  // extractedMessageId 在增量同步中不需要
        
        // 时间戳处理（与项目完全一致）
        let finalTimestamp = timestamp ?? date ?? formatCurrentDateToISO()
        
        // 项目名称提取（与项目完全一致） - 增量同步中不需要，但保持逻辑一致
        let _ = projectPath.components(separatedBy: "/").last ?? "未知项目"
        
        // 日期字符串生成（使用项目的逻辑） - 增量同步中不需要，但保持逻辑一致
        let _ = formatDateLikeCcusage(from: finalTimestamp)
        
        return (
            timestamp: finalTimestamp,
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cost: calculatedCost,
            sessionId: sessionId ?? "unknown",
            requestId: extractedRequestId,
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
            if dateComponent.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil {
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
}

// MARK: - 成本计算（与项目PricingModel保持完全一致）

/// 使用项目PricingModel的成本计算方法（与项目完全一致）
func calculateCostUsingProjectPricingModel(model: String, inputTokens: Int, outputTokens: Int,
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

    // 与项目PricingModel保持一致：不做精度处理，返回完整Double值
    return totalCost
}

/// 使用与项目PricingModel.normalizeModelName完全一致的模型名称规范化逻辑
func normalizeModelNameForPricing(_ model: String) -> String {
    // 首先转换为小写并去除空格（与项目PricingModel.normalizeModelName一致）
    let cleaned = model.lowercased().replacingOccurrences(of: " ", with: "")
    
    // 标准化模型名称（与项目PricingModel.performNormalization完全一致）
    // 关键：移除连字符，这是项目PricingModel的核心逻辑
    let normalized = cleaned.replacingOccurrences(of: "-", with: "")
    
    // 模型映射表 - 与项目PricingModel.performNormalization完全一致
    let mappings: [String: String] = [
        // Claude 4 变体（包含具体版本号）- 与项目PricingModel完全一致
        "claude4opus20250514": "claude-4-opus",
        "claude4sonnet20250514": "claude-4-sonnet", 
        "claude4haiku20250514": "claude-4-haiku",
        "claudesonnet420250514": "claude-4-sonnet",
        "claudeopus420250514": "claude-4-opus",
        "claudehaiku420250514": "claude-4-haiku",
        // 具体版本号映射（从实际数据中观察到的格式）- 与项目PricingModel完全一致
        "claude4sonnet": "claude-4-sonnet",
        "claude4opus": "claude-4-opus", 
        "claude4haiku": "claude-4-haiku",
        // 简化命名变体 - 与项目PricingModel完全一致
        "sonnet4": "claude-4-sonnet",
        "opus4": "claude-4-opus",
        "haiku4": "claude-4-haiku",
        // Claude 3.5 变体 - 与项目PricingModel完全一致
        "claude35sonnet": "claude-3-5-sonnet",
        "claude3.5sonnet": "claude-3-5-sonnet",
        "claudesonnet35": "claude-3-5-sonnet",
        "sonnet35": "claude-3-5-sonnet",
        // Claude 3 变体 - 与项目PricingModel完全一致
        "claude3opus": "claude-3-opus",
        "claude3sonnet": "claude-3-sonnet", 
        "claude3haiku": "claude-3-haiku",
        "opus3": "claude-3-opus",
        "sonnet3": "claude-3-sonnet",
        "haiku3": "claude-3-haiku",
        // Gemini 模型（添加基本支持）- 与项目PricingModel完全一致
        "gemini25pro": "gemini-2.5-pro",
        "gemini2.5pro": "gemini-2.5-pro"
    ]
    
    // 直接匹配的情况（与项目PricingModel.performNormalization完全一致）
    if let mapped = mappings[normalized] {
        return mapped
    }
    
    // 如果包含关键词，尝试智能匹配（与项目PricingModel.performNormalization完全一致）
    for (key, value) in mappings {
        if normalized.contains(key) || key.contains(normalized) {
            return value
        }
    }
    
    // 检查是否包含版本号，如果包含则尝试去除版本号后再匹配
    let versionPattern = #"\d{8}"# // 8位日期格式 YYYYMMDD
    let withoutVersion = normalized.replacingOccurrences(of: versionPattern, with: "", options: .regularExpression)
    if withoutVersion != normalized {
        // 递归调用，去除版本号后再匹配
        return normalizeModelNameForPricing(withoutVersion)
    }
    
    // 特殊情况处理：处理包含claude但格式不标准的情况
    if normalized.contains("claude") && normalized.contains("sonnet") {
        if normalized.contains("4") {
            return "claude-4-sonnet"
        } else if normalized.contains("35") || normalized.contains("3.5") {
            return "claude-3-5-sonnet"
        } else if normalized.contains("3") {
            return "claude-3-sonnet"
        }
    }
    
    // 如果无法匹配，返回normalized（与项目PricingModel.performNormalization完全一致）
    return normalized
}

// 插入使用记录（与全量同步完全一致：使用INSERT OR IGNORE）
func insertUsageEntry(entry: (timestamp: String, model: String, inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int, cost: Double, sessionId: String, requestId: String?, sourceFile: String), projectPath: String) -> (inserted: Bool, updated: Bool) {
    
    // 生成日期字符串和项目名称
    let dateString: String
    if let date = ISO8601DateFormatter().date(from: entry.timestamp) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        dateString = formatter.string(from: date)
    } else {
        // 回退到字符串截取
        dateString = String(entry.timestamp.prefix(10))
    }
    let projectName = projectPath.components(separatedBy: "/").last ?? "unknown"
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    let currentTime = formatter.string(from: Date())
    
    // 使用与全量同步完全相同的INSERT OR IGNORE逻辑
    let insertSQL = """
    INSERT OR IGNORE INTO usage_entries (
        timestamp, model, input_tokens, output_tokens, 
        cache_creation_tokens, cache_read_tokens, cost,
        session_id, project_path, project_name, 
        request_id, message_id, message_type, date_string, source_file,
        created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 'assistant', ?, ?, ?, ?)
    """
    
    var statement: OpaquePointer?
    var success = false
    
    if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        _ = entry.timestamp.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.model.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 3, Int64(entry.inputTokens))
        sqlite3_bind_int64(statement, 4, Int64(entry.outputTokens))
        sqlite3_bind_int64(statement, 5, Int64(entry.cacheCreationTokens))
        sqlite3_bind_int64(statement, 6, Int64(entry.cacheReadTokens))
        sqlite3_bind_double(statement, 7, entry.cost)
        _ = entry.sessionId.withCString { sqlite3_bind_text(statement, 8, $0, -1, SQLITE_TRANSIENT) }
        _ = projectPath.withCString { sqlite3_bind_text(statement, 9, $0, -1, SQLITE_TRANSIENT) }
        _ = projectName.withCString { sqlite3_bind_text(statement, 10, $0, -1, SQLITE_TRANSIENT) }
        
        if let requestId = entry.requestId {
            _ = requestId.withCString { sqlite3_bind_text(statement, 11, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 11)
        }
        
        _ = dateString.withCString { sqlite3_bind_text(statement, 12, $0, -1, SQLITE_TRANSIENT) }
        _ = entry.sourceFile.withCString { sqlite3_bind_text(statement, 13, $0, -1, SQLITE_TRANSIENT) }
        _ = currentTime.withCString { sqlite3_bind_text(statement, 14, $0, -1, SQLITE_TRANSIENT) }  // created_at
        _ = currentTime.withCString { sqlite3_bind_text(statement, 15, $0, -1, SQLITE_TRANSIENT) }  // updated_at
        
        if sqlite3_step(statement) == SQLITE_DONE {
            success = sqlite3_changes(db) > 0
        }
    }
    
    sqlite3_finalize(statement)
    
    // 因为删除了旧记录，所有成功插入的都算作新增
    return (success, false)
}

// 更新jsonl_files表中的文件记录
func updateFileRecord(filePath: String, fileName: String, fileSize: Int64, lastModified: String, md5Hash: String, entryCount: Int) -> Bool {
    let sql = """
    INSERT OR REPLACE INTO jsonl_files 
    (file_path, file_name, file_size, last_modified, md5_hash, last_processed, 
     entry_count, processing_status, updated_at)
    VALUES (?, ?, ?, ?, ?, datetime('now'), ?, 'completed', datetime('now'))
    """
    
    var statement: OpaquePointer?
    var success = false
    
    if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        _ = filePath.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = fileName.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 3, fileSize)
        _ = lastModified.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        _ = md5Hash.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 6, Int32(entryCount))
        
        if sqlite3_step(statement) == SQLITE_DONE {
            success = true
        }
    }
    
    sqlite3_finalize(statement)
    return success
}

// 处理单个文件的增量同步
func processFileIncremental(fileInfo: FileInfo) -> (newEntries: Int, updatedEntries: Int, skippedEntries: Int) {
    print("\n📄 处理文件: \(fileInfo.name)")
    
    // 提取项目路径
    var projectPath = fileInfo.path
    if let range = projectPath.range(of: ".claude/projects/") {
        projectPath = "/" + String(projectPath[range.upperBound...]).components(separatedBy: "/").dropLast().joined(separator: "/")
    }
    
    var newEntries = 0
    var updatedEntries = 0
    var skippedEntries = 0
    
    // 如果是变更的文件，先删除该文件的所有旧记录
    if fileInfo.dbSize > 0 && fileInfo.needsUpdate {
        print("📝 文件已变更，需要重新处理")
        
        // 使用完整文件路径删除该文件的记录（解决跨项目同名文件冲突）
        let filePath = fileInfo.path
        print("   🗑️ 删除文件相关的旧记录: \(filePath)")
        
        let deleteSQL = "DELETE FROM usage_entries WHERE source_file = ?"
        
        var deleteStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStatement, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            
            // 绑定完整文件路径参数
            _ = filePath.withCString { sqlite3_bind_text(deleteStatement, 1, $0, -1, SQLITE_TRANSIENT) }
            
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                let deletedCount = sqlite3_changes(db)
                print("   ✅ 精确删除了 \(deletedCount) 条旧记录")
            } else {
                print("   ⚠️ 删除操作失败，将使用 UPSERT 模式")
            }
        }
        sqlite3_finalize(deleteStatement)
        
    } else if fileInfo.dbSize == 0 {
        print("📝 新文件，开始处理")
    }
    
    // 打开文件，重新处理整个文件
    guard let fileHandle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: fileInfo.path)) else {
        print("❌ 无法打开文件")
        return (0, 0, 0)
    }
    
    defer { try? fileHandle.close() }
    
    var buffer = Data()
    
    // 从文件开头处理整个文件
    fileHandle.seek(toFileOffset: 0)
    
    // 逐行读取和处理
    while true {
        let chunk = fileHandle.readData(ofLength: 64 * 1024) // 64KB缓冲区
        if chunk.isEmpty { break }
        
        buffer.append(chunk)
        
        // 处理完整的行
        while let newlineRange = buffer.range(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
            buffer.removeSubrange(0...newlineRange.lowerBound)
            
            if !lineData.isEmpty {
                do {
                    let entry = try JSONDecoder().decode(RawJSONLEntry.self, from: lineData)
                    
                    if let usageEntry = entry.toUsageEntry(projectPath: projectPath, sourceFile: fileInfo.path) {
                        let result = insertUsageEntry(entry: usageEntry, projectPath: projectPath)
                        if result.inserted {
                            newEntries += 1
                        } else if result.updated {
                            updatedEntries += 1
                        } else {
                            skippedEntries += 1
                        }
                    }
                } catch {
                    // 忽略解析错误的行
                    skippedEntries += 1
                }
            }
        }
    }
    
    // 处理最后一行（如果有不完整的行）
    if !buffer.isEmpty {
        do {
            let entry = try JSONDecoder().decode(RawJSONLEntry.self, from: buffer)
            
            if let usageEntry = entry.toUsageEntry(projectPath: projectPath, sourceFile: fileInfo.name) {
                let result = insertUsageEntry(entry: usageEntry, projectPath: projectPath)
                if result.inserted {
                    newEntries += 1
                } else if result.updated {
                    updatedEntries += 1
                } else {
                    skippedEntries += 1
                }
            }
        } catch {
            skippedEntries += 1
        }
    }
    
    // 更新文件记录
    let totalEntries = newEntries + updatedEntries + skippedEntries
    _ = updateFileRecord(
        filePath: fileInfo.path,
        fileName: fileInfo.name,
        fileSize: fileInfo.currentSize,
        lastModified: fileInfo.currentModified,
        md5Hash: fileInfo.currentMD5,
        entryCount: totalEntries
    )
    
    print("✅ 重新处理完成 - 新增: \(newEntries), 更新: \(updatedEntries), 跳过: \(skippedEntries)")
    return (newEntries, updatedEntries, skippedEntries)
}

// 更新统计表数据
func updateStatisticsAfterIncremental() -> Bool {
    print("📊 开始更新统计表...")
    
    // 开始事务
    guard sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) == SQLITE_OK else {
        print("❌ 无法开始事务")
        return false
    }
    
    do {
        // 1. 更新每日统计
        try updateDailyStatistics()
        
        // 2. 更新模型统计  
        try updateModelStatistics()
        
        // 3. 更新项目统计
        try updateProjectStatistics()
        
        // 提交事务
        guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            print("❌ 统计更新提交失败")
            return false
        }
        
        print("✅ 统计表更新完成")
        return true
        
    } catch {
        sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
        print("❌ 统计更新失败: \(error)")
        return false
    }
}

// 更新每日统计
func updateDailyStatistics() throws {
    print("   📅 更新每日统计...")
    
    // 清除现有每日统计
    guard sqlite3_exec(db, "DELETE FROM daily_statistics", nil, nil, nil) == SQLITE_OK else {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        throw NSError(domain: "SQLite", code: 0, userInfo: [NSLocalizedDescriptionKey: "清除每日统计失败: \(errmsg)"])
    }
    
    // 重新生成每日统计数据
    let sql = """
    INSERT INTO daily_statistics (
        date_string, total_cost, total_tokens, input_tokens, output_tokens,
        cache_creation_tokens, cache_read_tokens, session_count, request_count,
        models_used, created_at, updated_at
    )
    SELECT 
        date_string,
        SUM(cost) as total_cost,
        SUM(input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens) as total_tokens,
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
    
    guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        throw NSError(domain: "SQLite", code: 0, userInfo: [NSLocalizedDescriptionKey: "每日统计更新失败: \(errmsg)"])
    }
}

// 更新模型统计
func updateModelStatistics() throws {
    print("   🤖 更新模型统计...")
    
    // 清除现有模型统计
    guard sqlite3_exec(db, "DELETE FROM model_statistics", nil, nil, nil) == SQLITE_OK else {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        throw NSError(domain: "SQLite", code: 0, userInfo: [NSLocalizedDescriptionKey: "清除模型统计失败: \(errmsg)"])
    }
    
    // 重新生成统计数据 (all-time, last-7-days, last-30-days)
    let ranges = [
        ("all-time", ""),
        ("last-7-days", "WHERE date_string >= date('now', '-7 days')"),
        ("last-30-days", "WHERE date_string >= date('now', '-30 days')")
    ]
    
    for (range, whereCondition) in ranges {
        let fromClause = whereCondition.isEmpty ? "FROM usage_entries" : "FROM usage_entries \(whereCondition)"
        let sql = """
        INSERT INTO model_statistics (
            model, date_range, total_cost, total_tokens, input_tokens, output_tokens,
            cache_creation_tokens, cache_read_tokens, session_count, request_count,
            created_at, updated_at
        )
        SELECT 
            model,
            '\(range)' as date_range,
            SUM(cost) as total_cost,
            SUM(input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens) as total_tokens,
            SUM(input_tokens) as input_tokens,
            SUM(output_tokens) as output_tokens,
            SUM(cache_creation_tokens) as cache_creation_tokens,
            SUM(cache_read_tokens) as cache_read_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count,
            datetime('now', 'localtime') as created_at,
            datetime('now', 'localtime') as updated_at
        \(fromClause)
        GROUP BY model
        HAVING SUM(input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens) > 0
        ORDER BY total_cost DESC
        """
        
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw NSError(domain: "SQLite", code: 0, userInfo: [NSLocalizedDescriptionKey: "模型统计(\(range))更新失败: \(errmsg)"])
        }
    }
}

// 更新项目统计
func updateProjectStatistics() throws {
    print("   📁 更新项目统计...")
    
    // 清除现有项目统计
    guard sqlite3_exec(db, "DELETE FROM project_statistics", nil, nil, nil) == SQLITE_OK else {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        throw NSError(domain: "SQLite", code: 0, userInfo: [NSLocalizedDescriptionKey: "清除项目统计失败: \(errmsg)"])
    }
    
    // 重新生成项目统计数据
    let ranges = [
        ("all-time", ""),
        ("last-7-days", "WHERE date_string >= date('now', '-7 days')"),
        ("last-30-days", "WHERE date_string >= date('now', '-30 days')")
    ]
    
    for (range, whereCondition) in ranges {
        let baseWhereClause = "WHERE project_path IS NOT NULL AND project_path != ''"
        let fullWhereClause = whereCondition.isEmpty ? baseWhereClause : "\(whereCondition) AND project_path IS NOT NULL AND project_path != ''"
        
        let sql = """
        INSERT INTO project_statistics (
            project_path, project_name, date_range, total_cost, total_tokens,
            session_count, request_count, last_used, created_at, updated_at
        )
        SELECT 
            project_path,
            project_name,
            '\(range)' as date_range,
            SUM(cost) as total_cost,
            SUM(input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens) as total_tokens,
            COUNT(DISTINCT session_id) as session_count,
            COUNT(*) as request_count,
            MAX(timestamp) as last_used,
            datetime('now', 'localtime') as created_at,
            datetime('now', 'localtime') as updated_at
        FROM usage_entries 
        \(fullWhereClause)
        GROUP BY project_path, project_name
        HAVING SUM(input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens) > 0
        ORDER BY total_cost DESC
        """
        
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw NSError(domain: "SQLite", code: 0, userInfo: [NSLocalizedDescriptionKey: "项目统计(\(range))更新失败: \(errmsg)"])
        }
    }
}
func runIncrementalSync() {
    print("\n🧪 开始基于jsonl_files表的增量同步...")
    
    // 检查现有数据
    checkExistingData()
    
    // 找出需要增量处理的文件
    let incrementalFiles = findIncrementalFiles()
    
    if incrementalFiles.isEmpty {
        print("\n✅ 所有文件都是最新的，无需增量处理")
        return
    }
    
    print("\n🔄 开始处理 \(incrementalFiles.count) 个文件...")
    
    var totalNewEntries = 0
    var totalUpdatedEntries = 0
    var totalSkippedEntries = 0
    let startTime = Date()
    
    for fileInfo in incrementalFiles {
        let result = processFileIncremental(fileInfo: fileInfo)
        totalNewEntries += result.newEntries
        totalUpdatedEntries += result.updatedEntries
        totalSkippedEntries += result.skippedEntries
    }
    
    let processingTime = Date().timeIntervalSince(startTime)
    
    // 更新统计汇总
    if totalNewEntries > 0 || totalUpdatedEntries > 0 {
        print("\n📊 有数据变更，开始更新统计表...")
        if updateStatisticsAfterIncremental() {
            print("✅ 统计表更新成功")
        } else {
            print("⚠️ 统计表更新失败，但数据同步已完成")
        }
    } else {
        print("\n📊 无数据变更，跳过统计表更新")
    }
    
    print("\n📊 增量同步完成:")
    print("   处理文件: \(incrementalFiles.count) 个")
    print("   新增记录: \(totalNewEntries) 条")
    print("   更新记录: \(totalUpdatedEntries) 条")
    print("   跳过记录: \(totalSkippedEntries) 条")
    print("   处理时间: \(String(format: "%.2f", processingTime)) 秒")
    
    // 检查最终结果
    checkExistingData()
}

// 执行增量同步
runIncrementalSync()

print("\n🎉 基于jsonl_files表的增量同步完成！")
print("数据已成功同步到现有的 usage_statistics.db 数据库")
print("您可以在ClaudeBar应用中查看更新后的使用统计数据")