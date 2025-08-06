import Foundation

/// 单条使用记录模型
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
    let requestId: String?
    let messageId: String?  // 添加 messageId 字段以支持 ccusage 风格的去重
    let messageType: String
    
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
        case requestId = "request_id"
        case messageId = "message_id"  // 添加 messageId 的编码键
        case messageType = "message_type"
    }
    
    /// 总令牌数
    var totalTokens: Int {
        return inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
    
    /// 日期字符串（YYYY-MM-DD 格式）
    var dateString: String {
        return String(timestamp.prefix(10))
    }
    
    /// 项目名称（从路径中提取）
    var projectName: String {
        if projectPath.isEmpty {
            return "未知项目"
        }
        
        let components = projectPath.components(separatedBy: "/")
        return components.last ?? projectPath
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
    
    /// 转换为标准的使用记录
    /// 完全基于 ccusage 测试脚本验证成功的逻辑实现
    func toUsageEntry(projectPath: String) -> UsageEntry? {
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
        
        // 获取模型名称，过滤合成消息（测试脚本第124-129行）
        let modelName = model ?? message?.model ?? "unknown"
        if modelName == "<synthetic>" {
            // 与测试脚本一致的调试输出
            // print("⚠️  过滤条目 - 合成消息: model=\(modelName)")
            return nil
        }
        
        // 提取token数据（测试脚本第131-134行）
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        let cacheCreationTokens = usageData?.effectiveCacheCreationTokens ?? 0
        let cacheReadTokens = usageData?.effectiveCacheReadTokens ?? 0
        
        // 计算成本
        let calculatedCost = cost ?? costUSD ?? PricingModel.shared.calculateCost(
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
        
        // ccusage风格的时间戳处理（测试脚本第140行）
        let finalTimestamp = timestamp ?? date ?? Date().toISOString()
        
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
            requestId: extractedRequestId,
            messageId: extractedMessageId,
            messageType: messageType
        )
    }
}

/// 扩展 Date 以支持 ISO 字符串转换
extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
    
    /// ccusage 风格的日期格式化方法
    /// 参考测试脚本第470-485行的formatDateLikeCcusage函数
    static func formatDateLikeCcusage(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: timestamp) else {
            // 如果解析失败，回退到简单的字符串截取
            return String(timestamp.prefix(10))
        }

        // 使用en-CA locale确保YYYY-MM-DD格式（与ccusage一致）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en-CA")
        dateFormatter.timeZone = TimeZone.current // 使用系统时区

        return dateFormatter.string(from: date)
    }
}