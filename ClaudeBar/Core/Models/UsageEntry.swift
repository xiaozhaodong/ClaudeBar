import Foundation

/// 单条使用记录模型（与测试文件完全一致）
struct UsageEntry: Codable {
    let timestamp: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Double
    let sessionId: String
    let projectPath: String
    let projectName: String  // 与测试文件一致：作为存储字段而不是计算属性
    let requestId: String?
    let messageId: String?
    let messageType: String
    let dateString: String   // 与测试文件一致：作为存储字段而不是计算属性
    let sourceFile: String   // 与测试文件一致：必需字段而不是可选字段

    private enum CodingKeys: String, CodingKey {
        case timestamp
        case model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cost
        case sessionId = "session_id"
        case projectPath = "project_path"
        case projectName = "project_name"  // 新增：项目名称字段的编码键
        case requestId = "request_id"
        case messageId = "message_id"
        case messageType = "message_type"
        case dateString = "date_string"    // 新增：日期字符串字段的编码键
        case sourceFile = "source_file"
    }
    
    /// 总令牌数
    var totalTokens: Int {
        return inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
    
    /// 检查是否在指定日期范围内
    func isInDateRange(startDate: Date?, endDate: Date?) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let entryDate = formatter.date(from: timestamp) else {
            // 尝试另一种格式
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            guard let entryDate = formatter.date(from: timestamp) else {
                return false
            }
            return isDateInRange(entryDate, startDate: startDate, endDate: endDate)
        }
        
        return isDateInRange(entryDate, startDate: startDate, endDate: endDate)
    }
    
    private func isDateInRange(_ date: Date, startDate: Date?, endDate: Date?) -> Bool {
        if let startDate = startDate, date < startDate {
            return false
        }
        if let endDate = endDate, date > endDate {
            return false
        }
        return true
    }
}

/// JSONL 原始数据模型（用于解析）
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
    let requestId: String?  // 无下划线版本
    let requestIdUnderscore: String?  // 下划线版本
    let messageId: String?
    // 增加更多字段支持，参考测试脚本的成功经验
    let id: String?  // 通用 ID 字段
    let uuid: String?  // UUID字段（ccusage可能使用）
    let date: String?  // 日期字段
    
    private enum CodingKeys: String, CodingKey {
        case type
        case messageType = "message_type"
        case model
        case usage
        case message
        case cost
        case costUSD
        case timestamp
        case sessionId = "sessionId"  // 修复：Claude Code 使用驼峰命名，不是下划线
        case requestId  // 支持无下划线的 requestId 字段
        case requestIdUnderscore = "request_id"  // 支持下划线的 request_id 字段
        case messageId = "message_id"
        case id
        case uuid  // 添加uuid字段编码键
        case date
    }
    
    /// 嵌套的使用数据
    struct UsageData: Codable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?
        // 兼容旧格式的字段
        let cacheCreationTokens: Int?
        let cacheReadTokens: Int?
        
        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            // 兼容旧格式
            case cacheCreationTokens = "cache_creation_tokens"
            case cacheReadTokens = "cache_read_tokens"
        }
        
        /// 获取缓存创建令牌数（优先使用精确字段）
        var effectiveCacheCreationTokens: Int {
            return cacheCreationInputTokens ?? cacheCreationTokens ?? 0
        }
        
        /// 获取缓存读取令牌数（优先使用精确字段）
        var effectiveCacheReadTokens: Int {
            return cacheReadInputTokens ?? cacheReadTokens ?? 0
        }
    }
    
    /// 嵌套的消息数据
    struct MessageData: Codable {
        let usage: UsageData?
        let model: String?
        let id: String?  // 添加id字段以支持message.id提取（测试脚本第139行）
    }
    
    /// 转换为标准的使用记录（与测试文件完全一致）
    func toUsageEntry(projectPath: String, sourceFile: String) -> UsageEntry? {
        // 获取消息类型 - 采用与ccusage更接近的策略
        let messageType = type ?? self.messageType ?? ""
        let usageData = usage ?? message?.usage
        
        // 完全模拟测试脚本中验证成功的过滤逻辑（第84-118行）
        let _ = usageData != nil  // hasUsageData - 未使用但保留与测试脚本一致
        let _ = (cost ?? costUSD ?? 0) > 0  // hasCostData - 未使用但保留与测试脚本一致
        
        // 更精确的数据验证，与测试脚本一致（未使用但保留用于未来调试）
        let _ = usageData?.inputTokens != nil || 
               usageData?.outputTokens != nil || 
               usageData?.effectiveCacheCreationTokens != nil ||
               usageData?.effectiveCacheReadTokens != nil
        
        // 计算总量用于过滤判断
        let totalTokens = (usageData?.inputTokens ?? 0) + 
                         (usageData?.outputTokens ?? 0) + 
                         (usageData?.effectiveCacheCreationTokens ?? 0) + 
                         (usageData?.effectiveCacheReadTokens ?? 0)
        let totalCost = cost ?? costUSD ?? 0
        
        // 修复会话统计问题：不能仅基于tokens和cost来过滤条目
        // 对于会话统计，所有有sessionId的条目都应该被保留
        // 只过滤掉真正无效的条目（没有sessionId且没有使用数据）
        let hasValidSessionId = (sessionId != nil && !sessionId!.isEmpty && sessionId != "unknown")
        
        // 如果有有效的sessionId，即使没有usage数据也应该保留（用于会话统计）
        // 如果没有sessionId且没有usage数据，才过滤掉
        if !hasValidSessionId && totalTokens == 0 && totalCost == 0 {
            return nil
        }
        
        // 获取模型名称，过滤无效模型（测试脚本第124-129行）
        let modelName = model ?? message?.model ?? ""
        
        // 过滤掉无效的模型名称
        if modelName.isEmpty || modelName == "unknown" || modelName == "<synthetic>" {
            // 记录被过滤的条目用于调试 (使用print代替Logger避免循环依赖)
            print("⚠️  过滤条目 - 无效模型: model='\(modelName)', sessionId=\(sessionId ?? "nil"), tokens=\(totalTokens), cost=\(totalCost)")
            return nil
        }
        
        // 提取token数据（测试脚本第131-134行）
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        let cacheCreationTokens = usageData?.effectiveCacheCreationTokens ?? 0
        let cacheReadTokens = usageData?.effectiveCacheReadTokens ?? 0
        
        // 成本计算：与测试脚本保持一致，使用PricingModel重新计算成本
        let calculatedCost = PricingModel.shared.calculateCost(
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens
        )
        
        // 完全模拟ccusage的ID提取逻辑（测试脚本第137-140行）
        // 优先使用 requestId（无下划线），然后是 request_id（下划线），最后是 messageId
        let extractedRequestId = requestId ?? requestIdUnderscore ?? messageId
        let extractedMessageId = messageId ?? message?.id
        
        // 时间戳处理（与测试文件完全一致）
        let finalTimestamp = timestamp ?? date ?? formatCurrentDateToISO()

        // 项目名称提取（与测试文件完全一致）
        let projectComponents = projectPath.components(separatedBy: "/")
        let projectName = projectComponents.last ?? "未知项目"

        // 日期字符串生成（使用项目的逻辑）
        let dateString = formatDateLikeCcusage(from: finalTimestamp)

        return UsageEntry(
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

    /// 格式化当前日期为ISO字符串（与测试文件完全一致）
    private func formatCurrentDateToISO() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    /// 精确的日期格式化方法，支持多种时间戳格式（与测试文件完全一致）
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

    /// 将Date对象格式化为 YYYY-MM-DD 字符串（与测试文件完全一致）
    private func formatDateToString(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        return dateFormatter.string(from: date)
    }
}

/// 全局日期字符串缓存（性能优化）
private class DateStringCache {
    static let shared = DateStringCache()
    private var cache: [String: String] = [:]
    private let queue = DispatchQueue(label: "DateStringCache", attributes: .concurrent)
    
    private init() {}
    
    func getDateString(for timestamp: String) -> String {
        return queue.sync {
            if let cached = cache[timestamp] {
                return cached
            }
            
            let computed = Date.formatDateLikeCcusage(timestamp)
            
            // 写操作需要barrier
            queue.async(flags: .barrier) {
                self.cache[timestamp] = computed
                
                // 防止缓存无限增长，保留最近1000个条目
                if self.cache.count > 1000 {
                    let sortedKeys = Array(self.cache.keys.sorted())
                    let keysToRemove = Array(sortedKeys.prefix(self.cache.count - 800))
                    for key in keysToRemove {
                        self.cache.removeValue(forKey: key)
                    }
                }
            }
            
            return computed
        }
    }
}

/// 全局日期格式化器（性能优化）
private struct DateFormatters {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    static let localDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en-CA")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

/// 扩展 Date 以支持 ISO 字符串转换
extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
    
    /// ccusage 风格的日期格式化方法（高性能版本）
    /// 参考测试脚本第470-485行的formatDateLikeCcusage函数
    static func formatDateLikeCcusage(_ timestamp: String) -> String {
        guard let date = DateFormatters.iso8601.date(from: timestamp) else {
            // 如果解析失败，回退到简单的字符串截取
            return String(timestamp.prefix(10))
        }
        
        return DateFormatters.localDate.string(from: date)
    }
}