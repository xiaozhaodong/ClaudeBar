import Foundation

/// 缓存状态枚举
enum CacheStatus: String, CaseIterable {
    case empty = "empty"
    case loading = "loading"
    case fresh = "fresh"
    case stale = "stale"
    case expired = "expired"
    case error = "error"
    
    /// 状态显示名称
    var displayName: String {
        switch self {
        case .empty:
            return "无缓存"
        case .loading:
            return "加载中"
        case .fresh:
            return "数据最新"
        case .stale:
            return "数据陈旧"
        case .expired:
            return "缓存过期"
        case .error:
            return "缓存错误"
        }
    }
    
    /// 状态图标
    var iconName: String {
        switch self {
        case .empty:
            return "circle"
        case .loading:
            return "arrow.clockwise"
        case .fresh:
            return "checkmark.circle.fill"
        case .stale:
            return "clock"
        case .expired:
            return "exclamationmark.circle"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    /// 状态颜色
    var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .empty:
            return (0.6, 0.6, 0.6) // 灰色
        case .loading:
            return (0.0, 0.5, 1.0) // 蓝色
        case .fresh:
            return (0.2, 0.8, 0.2) // 绿色
        case .stale:
            return (1.0, 0.8, 0.0) // 黄色
        case .expired:
            return (1.0, 0.6, 0.0) // 橙色
        case .error:
            return (1.0, 0.2, 0.2) // 红色
        }
    }
    
    /// 是否需要刷新
    var needsRefresh: Bool {
        switch self {
        case .empty, .expired, .error:
            return true
        case .stale:
            return true
        case .loading, .fresh:
            return false
        }
    }
    
    /// 是否可以显示数据
    var canShowData: Bool {
        switch self {
        case .fresh, .stale:
            return true
        case .empty, .loading, .expired, .error:
            return false
        }
    }
    
    /// 获取状态提示文案
    func getMessage(lastUpdateTime: Date? = nil, expiryTime: Date? = nil) -> String {
        switch self {
        case .empty:
            return "尚未加载数据"
        case .loading:
            return "正在加载数据..."
        case .fresh:
            if let lastUpdate = lastUpdateTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return "数据已更新至 \(formatter.string(from: lastUpdate))"
            }
            return "数据是最新的"
        case .stale:
            if let expiry = expiryTime {
                let timeRemaining = expiry.timeIntervalSinceNow
                if timeRemaining > 0 {
                    let minutes = Int(timeRemaining / 60)
                    return "数据将在 \(minutes) 分钟后过期"
                }
            }
            return "数据需要刷新"
        case .expired:
            return "缓存已过期，请刷新数据"
        case .error:
            return "缓存数据异常"
        }
    }
}

/// 缓存统计信息
struct CacheMetadata {
    let status: CacheStatus
    let cacheTime: Date
    let expiryTime: Date
    let hitCount: Int
    let dataSize: Int
    
    /// 缓存剩余时间（秒）
    var timeToExpiry: TimeInterval {
        return expiryTime.timeIntervalSinceNow
    }
    
    /// 缓存使用时长（秒）
    var cacheAge: TimeInterval {
        return Date().timeIntervalSince(cacheTime)
    }
    
    /// 调试描述
    var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return "状态:\(status.displayName) 缓存时间:\(formatter.string(from: cacheTime)) 过期时间:\(formatter.string(from: expiryTime)) 命中:\(hitCount)次 大小:\(dataSize)字节"
    }
    
    /// 是否接近过期（5分钟内）
    var isNearExpiry: Bool {
        return timeToExpiry <= 300 && timeToExpiry > 0
    }
    
    /// 格式化的缓存时间
    var formattedCacheTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: cacheTime)
    }
    
    /// 格式化的过期时间
    var formattedExpiryTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: expiryTime)
    }
    
    /// 格式化的数据大小
    var formattedDataSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(dataSize))
    }
}