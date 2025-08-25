import Foundation

/// 自动同步系统通知名称扩展
/// 定义同步系统相关的通知标识符，提供类型安全的通知机制
extension Notification.Name {
    
    // MARK: - 使用数据更新通知
    
    /// 使用数据已更新通知
    /// 当新的使用统计数据可用时发送
    /// userInfo: ["statistics": UsageStatistics, "dateRange": DateRange]
    static let usageDataDidUpdate = Notification.Name("ClaudeBar.usageDataDidUpdate")
    
    /// 使用数据同步开始通知
    /// 当开始同步使用数据时发送
    /// userInfo: ["syncType": String] // "incremental" 或 "full"
    static let usageDataSyncDidStart = Notification.Name("ClaudeBar.usageDataSyncDidStart")
    
    /// 使用数据同步完成通知
    /// 当使用数据同步完成时发送（无论成功或失败）
    /// userInfo: ["success": Bool, "error": SyncError?, "itemsCount": Int?]
    static let usageDataSyncDidComplete = Notification.Name("ClaudeBar.usageDataSyncDidComplete")
    
    // MARK: - 同步状态变更通知
    
    /// 同步状态发生变更通知
    /// 当同步系统状态改变时发送
    /// userInfo: ["status": SyncStatus, "previousStatus": SyncStatus?]
    static let syncStatusDidChange = Notification.Name("ClaudeBar.syncStatusDidChange")
    
    /// 同步配置变更通知
    /// 当同步相关配置改变时发送
    /// userInfo: ["configKey": String, "newValue": Any, "oldValue": Any?]
    static let syncConfigDidChange = Notification.Name("ClaudeBar.syncConfigDidChange")
    
    /// 同步错误发生通知
    /// 当同步过程中发生错误时发送
    /// userInfo: ["error": SyncError, "context": String?, "canRetry": Bool]
    static let syncErrorDidOccur = Notification.Name("ClaudeBar.syncErrorDidOccur")
    
    // MARK: - 同步进度更新通知
    
    /// 同步进度更新通知
    /// 当同步进度发生变化时发送
    /// userInfo: ["progress": Double, "totalItems": Int?, "processedItems": Int?, "currentItem": String?]
    static let syncProgressDidUpdate = Notification.Name("ClaudeBar.syncProgressDidUpdate")
    
    /// 文件处理进度通知
    /// 当处理单个文件时发送进度更新
    /// userInfo: ["fileName": String, "progress": Double, "totalBytes": Int64?, "processedBytes": Int64?]
    static let fileProcessingProgressDidUpdate = Notification.Name("ClaudeBar.fileProcessingProgressDidUpdate")
    
    /// 数据库同步进度通知
    /// 当同步数据到数据库时发送进度更新
    /// userInfo: ["tableName": String?, "totalRecords": Int?, "processedRecords": Int?, "operation": String]
    static let databaseSyncProgressDidUpdate = Notification.Name("ClaudeBar.databaseSyncProgressDidUpdate")
    
    // MARK: - 数据变更通知
    
    /// 数据源变更通知
    /// 当检测到新的数据源或数据源状态变更时发送
    /// userInfo: ["dataSource": DataSourceStatus, "filePath": String?]
    static let dataSourceDidChange = Notification.Name("ClaudeBar.dataSourceDidChange")
    
    // MARK: - API配置变更通知
    
    /// API配置变更通知
    /// 当API配置发生变更时发送（创建、更新、删除、切换）
    /// userInfo: ["operation": String, "configName": String, "config": ClaudeConfig?]
    static let configDidChange = Notification.Name("ClaudeBar.configDidChange")
    
    /// 数据完整性检查完成通知
    /// 当数据完整性检查完成时发送
    /// userInfo: ["success": Bool, "issuesFound": Int, "details": [String]?]
    static let dataIntegrityCheckDidComplete = Notification.Name("ClaudeBar.dataIntegrityCheckDidComplete")
    
    /// 缓存状态变更通知
    /// 当缓存状态发生变化时发送
    /// userInfo: ["cacheStatus": CacheStatus, "cacheKey": String?, "metadata": CacheMetadata?]
    static let cacheStatusDidChange = Notification.Name("ClaudeBar.cacheStatusDidChange")
    
    // MARK: - 系统级通知
    
    /// 同步服务启动通知
    /// 当自动同步服务启动时发送
    /// userInfo: ["syncInterval": TimeInterval, "autoSyncEnabled": Bool]
    static let syncServiceDidStart = Notification.Name("ClaudeBar.syncServiceDidStart")
    
    /// 同步服务停止通知
    /// 当自动同步服务停止时发送
    /// userInfo: ["reason": String?] // "userRequest", "error", "shutdown"
    static let syncServiceDidStop = Notification.Name("ClaudeBar.syncServiceDidStop")
    
    /// 定时同步触发通知
    /// 当定时器触发自动同步时发送
    /// userInfo: ["scheduledTime": Date, "actualTime": Date, "delay": TimeInterval?]
    static let scheduledSyncDidTrigger = Notification.Name("ClaudeBar.scheduledSyncDidTrigger")
}

// MARK: - 通知 UserInfo 键常量

/// 通知 UserInfo 字典的键名常量
/// 提供类型安全的通知数据访问
public struct SyncNotificationKeys {
    
    // MARK: - 数据相关键
    static let statistics = "statistics"
    static let dateRange = "dateRange"
    static let dataSource = "dataSource"
    static let filePath = "filePath"
    static let fileName = "fileName"
    static let tableName = "tableName"
    
    // MARK: - 状态相关键
    static let status = "status"
    static let previousStatus = "previousStatus"
    static let success = "success"
    static let error = "error"
    static let cacheStatus = "cacheStatus"
    static let cacheKey = "cacheKey"
    static let metadata = "metadata"
    
    // MARK: - 进度相关键
    static let progress = "progress"
    static let totalItems = "totalItems"
    static let processedItems = "processedItems"
    static let currentItem = "currentItem"
    static let totalBytes = "totalBytes"
    static let processedBytes = "processedBytes"
    static let totalRecords = "totalRecords"
    static let processedRecords = "processedRecords"
    static let operation = "operation"
    
    // MARK: - 配置相关键
    static let configKey = "configKey"
    static let newValue = "newValue"
    static let oldValue = "oldValue"
    static let syncInterval = "syncInterval"
    static let autoSyncEnabled = "autoSyncEnabled"
    
    // MARK: - 同步相关键
    static let syncType = "syncType"
    static let itemsCount = "itemsCount"
    static let context = "context"
    static let canRetry = "canRetry"
    static let reason = "reason"
    
    // MARK: - 时间相关键
    static let scheduledTime = "scheduledTime"
    static let actualTime = "actualTime"
    static let delay = "delay"
    
    // MARK: - 检查相关键
    static let issuesFound = "issuesFound"
    static let details = "details"
    
    // MARK: - 配置变更相关键
    static let configName = "configName"
    static let config = "config"
}

// MARK: - 同步状态枚举

/// 同步系统状态
public enum SyncStatus: String, CaseIterable {
    case idle = "idle"                      // 空闲状态
    case preparing = "preparing"            // 准备同步
    case scanning = "scanning"              // 扫描文件
    case parsing = "parsing"                // 解析数据
    case validating = "validating"          // 验证数据
    case syncing = "syncing"                // 同步中
    case completed = "completed"            // 完成
    case failed = "failed"                  // 失败
    case cancelled = "cancelled"            // 已取消
    case paused = "paused"                  // 暂停
    
    /// 状态显示名称
    public var displayName: String {
        switch self {
        case .idle:
            return "空闲"
        case .preparing:
            return "准备同步"
        case .scanning:
            return "扫描文件"
        case .parsing:
            return "解析数据"
        case .validating:
            return "验证数据"
        case .syncing:
            return "同步中"
        case .completed:
            return "同步完成"
        case .failed:
            return "同步失败"
        case .cancelled:
            return "已取消"
        case .paused:
            return "已暂停"
        }
    }
    
    /// 状态图标
    public var iconName: String {
        switch self {
        case .idle:
            return "circle"
        case .preparing:
            return "gear"
        case .scanning:
            return "magnifyingglass"
        case .parsing:
            return "doc.text"
        case .validating:
            return "checkmark.shield"
        case .syncing:
            return "arrow.clockwise"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "stop.circle"
        case .paused:
            return "pause.circle"
        }
    }
    
    /// 状态颜色
    public var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .idle:
            return (0.6, 0.6, 0.6)     // 灰色
        case .preparing, .scanning, .parsing, .validating:
            return (0.0, 0.5, 1.0)     // 蓝色
        case .syncing:
            return (1.0, 0.8, 0.0)     // 黄色
        case .completed:
            return (0.2, 0.8, 0.2)     // 绿色
        case .failed:
            return (1.0, 0.2, 0.2)     // 红色
        case .cancelled:
            return (1.0, 0.6, 0.0)     // 橙色
        case .paused:
            return (0.6, 0.6, 0.6)     // 灰色
        }
    }
    
    /// 是否为活跃状态
    public var isActive: Bool {
        switch self {
        case .preparing, .scanning, .parsing, .validating, .syncing:
            return true
        case .idle, .completed, .failed, .cancelled, .paused:
            return false
        }
    }
    
    /// 是否可以取消
    public var canCancel: Bool {
        return isActive
    }
    
    /// 是否可以重试
    public var canRetry: Bool {
        switch self {
        case .failed, .cancelled:
            return true
        case .idle, .preparing, .scanning, .parsing, .validating, .syncing, .completed, .paused:
            return false
        }
    }
    
    /// 是否可以暂停
    public var canPause: Bool {
        switch self {
        case .scanning, .parsing, .syncing:
            return true
        case .idle, .preparing, .validating, .completed, .failed, .cancelled, .paused:
            return false
        }
    }
    
    /// 是否可以恢复
    public var canResume: Bool {
        return self == .paused
    }
}

// MARK: - 通知发送辅助方法

extension NotificationCenter {
    
    /// 发送使用数据更新通知
    /// - Parameters:
    ///   - statistics: 使用统计数据
    ///   - dateRange: 日期范围
    public func postUsageDataDidUpdate(statistics: Any, dateRange: Any) {
        post(name: .usageDataDidUpdate, object: nil, userInfo: [
            SyncNotificationKeys.statistics: statistics,
            SyncNotificationKeys.dateRange: dateRange
        ])
    }
    
    /// 发送同步状态变更通知
    /// - Parameters:
    ///   - status: 当前同步状态
    ///   - previousStatus: 之前的同步状态
    public func postSyncStatusDidChange(status: SyncStatus, previousStatus: SyncStatus? = nil) {
        var userInfo: [String: Any] = [SyncNotificationKeys.status: status]
        if let previousStatus = previousStatus {
            userInfo[SyncNotificationKeys.previousStatus] = previousStatus
        }
        post(name: .syncStatusDidChange, object: nil, userInfo: userInfo)
    }
    
    /// 发送同步进度更新通知
    /// - Parameters:
    ///   - progress: 进度百分比 (0.0 - 1.0)
    ///   - totalItems: 总项目数
    ///   - processedItems: 已处理项目数
    ///   - currentItem: 当前处理项目
    public func postSyncProgressDidUpdate(
        progress: Double,
        totalItems: Int? = nil,
        processedItems: Int? = nil,
        currentItem: String? = nil
    ) {
        var userInfo: [String: Any] = [SyncNotificationKeys.progress: progress]
        if let totalItems = totalItems {
            userInfo[SyncNotificationKeys.totalItems] = totalItems
        }
        if let processedItems = processedItems {
            userInfo[SyncNotificationKeys.processedItems] = processedItems
        }
        if let currentItem = currentItem {
            userInfo[SyncNotificationKeys.currentItem] = currentItem
        }
        post(name: .syncProgressDidUpdate, object: nil, userInfo: userInfo)
    }
    
    /// 发送同步错误通知
    /// - Parameters:
    ///   - error: 同步错误
    ///   - context: 错误上下文
    ///   - canRetry: 是否可以重试
    public func postSyncErrorDidOccur(error: Any, context: String? = nil, canRetry: Bool = true) {
        var userInfo: [String: Any] = [
            SyncNotificationKeys.error: error,
            SyncNotificationKeys.canRetry: canRetry
        ]
        if let context = context {
            userInfo[SyncNotificationKeys.context] = context
        }
        post(name: .syncErrorDidOccur, object: nil, userInfo: userInfo)
    }
    
    /// 发送数据源变更通知
    /// - Parameters:
    ///   - dataSource: 数据源状态
    ///   - filePath: 文件路径
    public func postDataSourceDidChange(dataSource: Any, filePath: String? = nil) {
        var userInfo: [String: Any] = [SyncNotificationKeys.dataSource: dataSource]
        if let filePath = filePath {
            userInfo[SyncNotificationKeys.filePath] = filePath
        }
        post(name: .dataSourceDidChange, object: nil, userInfo: userInfo)
    }
    
    /// 发送配置变更通知
    /// - Parameters:
    ///   - operation: 操作类型（create、update、delete、switch）
    ///   - configName: 配置名称
    ///   - config: 配置对象（可选）
    public func postConfigDidChange(operation: String, configName: String, config: Any? = nil) {
        var userInfo: [String: Any] = [
            SyncNotificationKeys.operation: operation,
            SyncNotificationKeys.configName: configName
        ]
        if let config = config {
            userInfo[SyncNotificationKeys.config] = config
        }
        post(name: .configDidChange, object: nil, userInfo: userInfo)
    }
}