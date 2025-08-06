import Foundation

/// 使用统计数据模型
struct UsageStatistics: Codable, Identifiable {
    let id = UUID()
    let totalCost: Double
    let totalTokens: Int
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCacheCreationTokens: Int
    let totalCacheReadTokens: Int
    let totalSessions: Int
    let totalRequests: Int
    let byModel: [ModelUsage]
    let byDate: [DailyUsage]
    let byProject: [ProjectUsage]
    
    private enum CodingKeys: String, CodingKey {
        case totalCost = "total_cost"
        case totalTokens = "total_tokens"
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case totalCacheCreationTokens = "total_cache_creation_tokens"
        case totalCacheReadTokens = "total_cache_read_tokens"
        case totalSessions = "total_sessions"
        case totalRequests = "total_requests"
        case byModel = "by_model"
        case byDate = "by_date"
        case byProject = "by_project"
    }
    
    /// 创建空的统计数据
    static var empty: UsageStatistics {
        return UsageStatistics(
            totalCost: 0,
            totalTokens: 0,
            totalInputTokens: 0,
            totalOutputTokens: 0,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 0,
            totalRequests: 0,
            byModel: [],
            byDate: [],
            byProject: []
        )
    }
    
    /// 平均每次请求成本（Phase 3: 改进版）
    var averageCostPerRequest: Double {
        guard totalRequests > 0 else { 
            print("⚠️ 计算平均每请求成本时总请求数为 0")
            return 0 
        }
        
        // Phase 3: 如果总成本为 0，可能是数据问题
        guard totalCost > 0 else {
            print("⚠️ 总成本为 $0，平均成本计算可能不准确 - 总请求数: \(totalRequests)")
            return 0
        }
        
        let average = totalCost / Double(totalRequests)
        
        // Phase 3: 合理性检查：平均成本应该在合理范围内
        if average > 10.0 {  // 超过 $10 每请求可能有问题
            print("⚠️ 平均每请求成本异常高: $\(String(format: "%.6f", average)) - 总成本: $\(String(format: "%.6f", totalCost)), 总请求: \(totalRequests)")
        } else if average < 0.000001 {  // 低于 $0.000001 可能有问题
            print("⚠️ 平均每请求成本异常低: $\(String(format: "%.6f", average)) - 总成本: $\(String(format: "%.6f", totalCost)), 总请求: \(totalRequests)")
        } else {
            print("✅ 平均每请求成本在合理范围内: $\(String(format: "%.6f", average))")
        }
        
        return average
    }
    
    /// 平均每个会话成本
    var averageCostPerSession: Double {
        guard totalSessions > 0 else { return 0 }
        return totalCost / Double(totalSessions)
    }
    
    /// 格式化的成本显示
    var formattedTotalCost: String {
        return String(format: "$%.2f", totalCost)
    }
    
    /// 格式化的令牌数显示
    var formattedTotalTokens: String {
        return formatTokenCount(totalTokens)
    }
    
    /// 格式化的会话数显示
    var formattedTotalSessions: String {
        return NumberFormatter.localizedString(from: NSNumber(value: totalSessions), number: .decimal)
    }
    
    /// 格式化令牌数量
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
        }
    }
}

/// 按模型统计的使用数据
struct ModelUsage: Codable, Identifiable {
    let id = UUID()
    let model: String
    let totalCost: Double
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let sessionCount: Int
    let requestCount: Int?
    
    private enum CodingKeys: String, CodingKey {
        case model
        case totalCost = "total_cost"
        case totalTokens = "total_tokens"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case sessionCount = "session_count"
        case requestCount = "request_count"
    }
    
    /// 友好的模型名称显示
    var displayName: String {
        let modelMap: [String: String] = [
            "claude-4-opus": "Opus 4",
            "claude-4-sonnet": "Sonnet 4",
            "claude-3.5-sonnet": "Sonnet 3.5",
            "claude-3-opus": "Opus 3",
            "claude-3-haiku": "Haiku 3"
        ]
        return modelMap[model] ?? model
    }
    
    /// 模型的颜色
    var color: String {
        if model.contains("opus") {
            return "purple"
        } else if model.contains("sonnet") {
            return "blue"
        } else if model.contains("haiku") {
            return "green"
        } else {
            return "gray"
        }
    }
    
    /// 格式化的成本显示
    var formattedCost: String {
        return String(format: "$%.2f", totalCost)
    }
    
    /// 格式化的令牌数显示
    var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.2fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        } else {
            return NumberFormatter.localizedString(from: NSNumber(value: totalTokens), number: .decimal)
        }
    }
}

/// 按日期统计的使用数据
struct DailyUsage: Codable, Identifiable {
    let id = UUID()
    let date: String
    let totalCost: Double
    let totalTokens: Int
    let modelsUsed: [String]
    
    private enum CodingKeys: String, CodingKey {
        case date
        case totalCost = "total_cost"
        case totalTokens = "total_tokens"
        case modelsUsed = "models_used"
    }
    
    /// 日期的显示格式
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: date) {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
        return date
    }
    
    /// 完整日期显示
    var fullFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: date) {
            formatter.dateFormat = "yyyy年MM月dd日"
            return formatter.string(from: date)
        }
        return date
    }
    
    /// 格式化的成本显示
    var formattedCost: String {
        return String(format: "$%.2f", totalCost)
    }
    
    /// 格式化的令牌数显示
    var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.2fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        } else {
            return NumberFormatter.localizedString(from: NSNumber(value: totalTokens), number: .decimal)
        }
    }
}

/// 按项目统计的使用数据
struct ProjectUsage: Codable, Identifiable {
    let id = UUID()
    let projectPath: String
    let projectName: String
    let totalCost: Double
    let totalTokens: Int
    let sessionCount: Int
    let requestCount: Int?
    let lastUsed: String
    
    private enum CodingKeys: String, CodingKey {
        case projectPath = "project_path"
        case projectName = "project_name"
        case totalCost = "total_cost"
        case totalTokens = "total_tokens"
        case sessionCount = "session_count"
        case requestCount = "request_count"
        case lastUsed = "last_used"
    }
    
    /// 格式化的项目路径（简化显示）
    var formattedPath: String {
        if projectPath.isEmpty {
            return ""
        }
        
        // 家目录模式匹配
        let homePatterns = [
            "/Users/[^/]+",
            "/home/[^/]+",
            "C:\\\\Users\\\\[^\\\\]+",
            "/root"
        ]
        
        var formattedPath = projectPath
        
        // 将家目录替换为 ~
        for pattern in homePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: projectPath.count)
                formattedPath = regex.stringByReplacingMatches(
                    in: projectPath, 
                    options: [], 
                    range: range, 
                    withTemplate: "~"
                )
                if formattedPath != projectPath {
                    break
                }
            }
        }
        
        // 分割路径
        let parts = formattedPath.components(separatedBy: "/")
        
        // 如果路径足够短，直接返回
        if parts.count <= 4 {
            return formattedPath
        }
        
        // 对于长路径，显示首部、省略号和末尾2-3部分
        let firstPart = parts[0]
        let lastParts = Array(parts.suffix(3))
        
        return "\(firstPart)/.../" + lastParts.joined(separator: "/")
    }
    
    /// 格式化的成本显示
    var formattedCost: String {
        return String(format: "$%.2f", totalCost)
    }
    
    /// 格式化的令牌数显示
    var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.2fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        } else {
            return NumberFormatter.localizedString(from: NSNumber(value: totalTokens), number: .decimal)
        }
    }
    
    /// 最后使用时间的格式化显示
    var formattedLastUsed: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = formatter.date(from: lastUsed) {
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: date)
        }
        
        // 尝试另一种格式
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        if let date = formatter.date(from: lastUsed) {
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: date)
        }
        
        return lastUsed
    }
    
    /// 平均每个会话成本
    var averageCostPerSession: Double {
        guard sessionCount > 0 else { return 0 }
        return totalCost / Double(sessionCount)
    }
}

/// 日期范围过滤选项
enum DateRange: String, CaseIterable {
    case all = "all"
    case last7Days = "7d"
    case last30Days = "30d"
    
    var displayName: String {
        switch self {
        case .all:
            return "所有时间"
        case .last7Days:
            return "最近7天"
        case .last30Days:
            return "最近30天"
        }
    }
    
    /// 获取开始日期（相对于今天）
    var startDate: Date? {
        let calendar = Calendar.current
        let today = Date()
        
        switch self {
        case .all:
            return nil
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: today)
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: today)
        }
    }
}

/// 使用统计错误类型
enum UsageStatisticsError: LocalizedError {
    case dataNotFound
    case parsingFailed(String)
    case fileAccessDenied(String)
    case invalidDateRange
    case calculationError(String)
    
    var errorDescription: String? {
        switch self {
        case .dataNotFound:
            return "未找到使用数据"
        case .parsingFailed(let reason):
            return "数据解析失败：\(reason)"
        case .fileAccessDenied(let path):
            return "无法访问文件：\(path)"
        case .invalidDateRange:
            return "无效的日期范围"
        case .calculationError(let reason):
            return "统计计算错误：\(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .dataNotFound:
            return "请确认 ~/.claude/projects 目录存在且包含使用数据文件"
        case .parsingFailed:
            return "数据文件可能已损坏，请检查文件格式"
        case .fileAccessDenied:
            return "请检查文件权限或重新授权访问 Claude 目录"
        case .invalidDateRange:
            return "请选择有效的日期范围"
        case .calculationError:
            return "请重试统计计算或联系技术支持"
        }
    }
}