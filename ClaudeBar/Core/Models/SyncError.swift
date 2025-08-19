import Foundation

/// 自动同步系统错误类型
/// 为自动同步系统提供详细的错误分类和用户友好的错误描述
enum SyncError: LocalizedError {
    // MARK: - 文件操作错误
    case fileReadFailed(String, Error?)
    case fileWriteFailed(String, Error?)
    case fileNotFound(String)
    case directoryAccessDenied(String)
    case insufficientDiskSpace
    case fileCorrupted(String)
    
    // MARK: - 数据解析错误
    case jsonlParsingFailed(String, Error?)
    case dataFormatInvalid(String)
    case timestampParsingFailed(String)
    case encodingError(String)
    case schemaVersionMismatch(expected: String, actual: String)
    
    // MARK: - 数据库操作错误
    case databaseConnectionFailed(Error?)
    case databaseQueryFailed(String, Error?)
    case databaseUpdateFailed(String, Error?)
    case databaseTransactionFailed(Error?)
    case databaseCorrupted(String)
    case databaseLocked
    case databaseSchemaMismatch
    
    // MARK: - 网络连接错误
    case networkUnavailable
    case connectionTimeout
    case authenticationFailed
    case serverError(Int, String?)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case apiEndpointChanged
    
    // MARK: - 同步过程错误
    case syncInProgress
    case syncCancelled
    case syncDataConflict(String)
    case lastSyncTimeInvalid
    case incrementalSyncFailed(String)
    case fullSyncRequired
    case dataIntegrityCheckFailed(String)
    
    // MARK: - 配置错误
    case syncConfigInvalid(String)
    case syncIntervalInvalid
    case configServiceUnavailable
    case permissionDenied(String)
    
    /// 用户友好的错误描述
    var errorDescription: String? {
        switch self {
        // 文件操作错误
        case .fileReadFailed(let path, _):
            return "无法读取文件：\(path)"
        case .fileWriteFailed(let path, _):
            return "无法写入文件：\(path)"
        case .fileNotFound(let path):
            return "找不到文件：\(path)"
        case .directoryAccessDenied(let path):
            return "无权限访问目录：\(path)"
        case .insufficientDiskSpace:
            return "磁盘空间不足，无法完成同步操作"
        case .fileCorrupted(let path):
            return "文件已损坏：\(path)"
            
        // 数据解析错误
        case .jsonlParsingFailed(let fileName, _):
            return "解析 JSONL 文件失败：\(fileName)"
        case .dataFormatInvalid(let reason):
            return "数据格式无效：\(reason)"
        case .timestampParsingFailed(let timestamp):
            return "时间戳解析失败：\(timestamp)"
        case .encodingError(let reason):
            return "数据编码错误：\(reason)"
        case .schemaVersionMismatch(let expected, let actual):
            return "数据结构版本不匹配，期望：\(expected)，实际：\(actual)"
            
        // 数据库操作错误
        case .databaseConnectionFailed(_):
            return "无法连接到数据库"
        case .databaseQueryFailed(let query, _):
            return "数据库查询失败：\(query)"
        case .databaseUpdateFailed(let operation, _):
            return "数据库更新失败：\(operation)"
        case .databaseTransactionFailed(_):
            return "数据库事务执行失败"
        case .databaseCorrupted(let reason):
            return "数据库已损坏：\(reason)"
        case .databaseLocked:
            return "数据库被锁定，请稍后重试"
        case .databaseSchemaMismatch:
            return "数据库结构版本不匹配"
            
        // 网络连接错误
        case .networkUnavailable:
            return "网络连接不可用"
        case .connectionTimeout:
            return "连接超时"
        case .authenticationFailed:
            return "身份验证失败"
        case .serverError(let code, let message):
            return "服务器错误（\(code)）：\(message ?? "未知错误")"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "请求频率超限，请在 \(Int(retryAfter)) 秒后重试"
            } else {
                return "请求频率超限，请稍后重试"
            }
        case .apiEndpointChanged:
            return "API 端点已变更，请更新配置"
            
        // 同步过程错误
        case .syncInProgress:
            return "同步正在进行中，请等待完成"
        case .syncCancelled:
            return "同步操作已取消"
        case .syncDataConflict(let details):
            return "同步数据冲突：\(details)"
        case .lastSyncTimeInvalid:
            return "上次同步时间无效，将执行完整同步"
        case .incrementalSyncFailed(let reason):
            return "增量同步失败：\(reason)"
        case .fullSyncRequired:
            return "需要执行完整同步"
        case .dataIntegrityCheckFailed(let reason):
            return "数据完整性检查失败：\(reason)"
            
        // 配置错误
        case .syncConfigInvalid(let reason):
            return "同步配置无效：\(reason)"
        case .syncIntervalInvalid:
            return "同步间隔设置无效"
        case .configServiceUnavailable:
            return "配置服务不可用"
        case .permissionDenied(let resource):
            return "访问权限被拒绝：\(resource)"
        }
    }
    
    /// 恢复建议
    var recoverySuggestion: String? {
        switch self {
        // 文件操作错误
        case .fileReadFailed(let path, _):
            return """
            建议操作：
            1. 检查文件是否存在：\(path)
            2. 确认应用有读取该文件的权限
            3. 检查文件是否被其他程序占用
            4. 重启应用并重试
            """
        case .fileWriteFailed(let path, _):
            return """
            建议操作：
            1. 检查磁盘空间是否充足
            2. 确认应用有写入权限：\(path)
            3. 检查目标目录是否存在
            4. 关闭可能占用文件的其他程序
            """
        case .fileNotFound:
            return """
            建议操作：
            1. 检查 Claude CLI 是否正确安装
            2. 确认 ~/.claude 目录存在
            3. 使用 Claude CLI 生成一些使用数据
            4. 重新启动应用
            """
        case .directoryAccessDenied:
            return """
            建议操作：
            1. 在系统偏好设置中为应用授权完全磁盘访问
            2. 检查 ~/.claude 目录权限
            3. 重启应用以获取新权限
            """
        case .insufficientDiskSpace:
            return """
            建议操作：
            1. 清理磁盘空间，删除不必要文件
            2. 清空垃圾箱释放空间
            3. 移动大文件到外部存储
            4. 释放至少 1GB 空间后重试
            """
        case .fileCorrupted:
            return """
            建议操作：
            1. 备份原始数据文件
            2. 删除损坏的文件
            3. 执行完整重新同步
            4. 如问题持续，联系技术支持
            """
            
        // 数据解析错误
        case .jsonlParsingFailed:
            return """
            建议操作：
            1. 检查 JSONL 文件格式是否正确
            2. 确认文件编码为 UTF-8
            3. 查看是否有部分写入的数据
            4. 备份文件后尝试手动修复
            """
        case .dataFormatInvalid:
            return """
            建议操作：
            1. 更新到最新版本的 Claude CLI
            2. 检查数据格式是否与预期一致
            3. 执行完整重新同步
            4. 如问题持续，报告数据格式问题
            """
        case .timestampParsingFailed:
            return """
            建议操作：
            1. 检查系统时间设置是否正确
            2. 确认时区设置正确
            3. 更新 Claude CLI 到最新版本
            4. 重新生成使用数据
            """
        case .schemaVersionMismatch:
            return """
            建议操作：
            1. 更新应用到最新版本
            2. 更新 Claude CLI 到最新版本
            3. 执行数据库迁移
            4. 如必要，执行完整重新同步
            """
            
        // 数据库操作错误
        case .databaseConnectionFailed:
            return """
            建议操作：
            1. 检查数据库文件权限
            2. 确认磁盘空间充足
            3. 重启应用重新初始化数据库
            4. 如问题持续，重新创建数据库
            """
        case .databaseQueryFailed, .databaseUpdateFailed:
            return """
            建议操作：
            1. 检查数据库完整性
            2. 重启应用重试操作
            3. 如问题持续，备份数据后重建数据库
            4. 联系技术支持获取帮助
            """
        case .databaseLocked:
            return """
            建议操作：
            1. 等待几秒钟后重试
            2. 关闭其他可能访问数据库的应用实例
            3. 重启应用解除锁定
            4. 检查是否有僵尸进程占用数据库
            """
        case .databaseCorrupted:
            return """
            建议操作：
            1. 立即停止使用损坏的数据库
            2. 从最近的备份恢复数据库
            3. 如无备份，执行完整重新同步
            4. 考虑启用自动备份功能
            """
            
        // 网络连接错误
        case .networkUnavailable:
            return """
            建议操作：
            1. 检查网络连接是否正常
            2. 确认防火墙没有阻止应用
            3. 稍后重试网络相关操作
            4. 使用本地数据继续工作
            """
        case .connectionTimeout:
            return """
            建议操作：
            1. 检查网络稳定性
            2. 增加连接超时时间
            3. 稍后重试
            4. 考虑使用离线模式
            """
        case .authenticationFailed:
            return """
            建议操作：
            1. 检查 API Token 是否正确
            2. 确认 Token 没有过期
            3. 重新设置认证信息
            4. 联系服务提供商确认账户状态
            """
        case .rateLimitExceeded:
            return """
            建议操作：
            1. 等待限制解除后重试
            2. 调整同步频率设置
            3. 考虑升级账户获得更高限制
            4. 使用增量同步减少请求量
            """
            
        // 同步过程错误
        case .syncInProgress:
            return """
            建议操作：
            1. 等待当前同步完成
            2. 如同步时间过长，可以取消后重试
            3. 检查同步进度和状态
            4. 避免同时启动多个同步操作
            """
        case .syncDataConflict:
            return """
            建议操作：
            1. 选择保留哪个版本的数据
            2. 手动合并冲突的数据
            3. 执行完整重新同步
            4. 配置冲突解决策略
            """
        case .incrementalSyncFailed:
            return """
            建议操作：
            1. 检查上次同步时间是否正确
            2. 验证增量数据的完整性
            3. 执行完整同步作为备选方案
            4. 重新初始化同步基准点
            """
            
        // 配置错误
        case .syncConfigInvalid:
            return """
            建议操作：
            1. 检查同步配置文件格式
            2. 重置为默认配置
            3. 参考配置文档进行修正
            4. 确保所有必需参数都已设置
            """
        case .permissionDenied:
            return """
            建议操作：
            1. 在系统偏好设置中授予必要权限
            2. 重启应用以获取新权限
            3. 检查文件和目录的访问权限
            4. 联系系统管理员获取帮助
            """
        default:
            return """
            建议操作：
            1. 重新启动应用并重试
            2. 检查相关权限和网络连接
            3. 查看详细错误日志
            4. 如问题持续，联系技术支持
            """
        }
    }
    
    /// 错误的严重程度
    var severity: ErrorSeverity {
        switch self {
        case .fileNotFound, .lastSyncTimeInvalid, .fullSyncRequired:
            return .warning
        case .syncInProgress, .syncCancelled, .rateLimitExceeded:
            return .warning
        case .fileReadFailed, .fileWriteFailed, .jsonlParsingFailed:
            return .error
        case .databaseQueryFailed, .databaseUpdateFailed, .networkUnavailable:
            return .error
        case .syncDataConflict, .incrementalSyncFailed:
            return .error
        case .databaseCorrupted, .fileCorrupted, .databaseConnectionFailed:
            return .critical
        case .insufficientDiskSpace, .permissionDenied:
            return .critical
        case .schemaVersionMismatch, .databaseSchemaMismatch:
            return .critical
        default:
            return .error
        }
    }
    
    /// 是否可以自动恢复
    var isRecoverable: Bool {
        switch self {
        case .fileNotFound, .lastSyncTimeInvalid, .fullSyncRequired:
            return true
        case .syncInProgress, .syncCancelled:
            return true
        case .rateLimitExceeded, .connectionTimeout, .networkUnavailable:
            return true
        case .databaseLocked, .incrementalSyncFailed:
            return true
        case .databaseCorrupted, .fileCorrupted, .insufficientDiskSpace:
            return false
        case .permissionDenied, .schemaVersionMismatch:
            return false
        case .databaseConnectionFailed, .configServiceUnavailable:
            return false
        default:
            return true
        }
    }
    
    /// 用户操作建议
    var userAction: UserAction {
        switch self {
        case .fileNotFound:
            return .checkPermissions
        case .permissionDenied, .directoryAccessDenied:
            return .checkPermissions
        case .insufficientDiskSpace:
            return .freeSpace
        case .networkUnavailable, .connectionTimeout:
            return .checkNetwork
        case .syncConfigInvalid, .dataFormatInvalid:
            return .fixConfigFormat
        case .databaseCorrupted, .fileCorrupted:
            return .contactSupport
        case .syncInProgress, .syncCancelled:
            return .retryOperation
        case .fullSyncRequired, .incrementalSyncFailed:
            return .retryOperation
        case .databaseConnectionFailed, .configServiceUnavailable:
            return .restartApp
        default:
            return .retryOperation
        }
    }
    
    /// 底层错误（如果有）
    var underlyingError: Error? {
        switch self {
        case .fileReadFailed(_, let error), .fileWriteFailed(_, let error):
            return error
        case .jsonlParsingFailed(_, let error):
            return error
        case .databaseConnectionFailed(let error), .databaseQueryFailed(_, let error):
            return error
        case .databaseUpdateFailed(_, let error), .databaseTransactionFailed(let error):
            return error
        default:
            return nil
        }
    }
    
    /// 错误代码（用于日志和调试）
    var errorCode: String {
        switch self {
        case .fileReadFailed: return "FILE_READ_FAILED"
        case .fileWriteFailed: return "FILE_WRITE_FAILED"
        case .fileNotFound: return "FILE_NOT_FOUND"
        case .directoryAccessDenied: return "DIRECTORY_ACCESS_DENIED"
        case .insufficientDiskSpace: return "INSUFFICIENT_DISK_SPACE"
        case .fileCorrupted: return "FILE_CORRUPTED"
        case .jsonlParsingFailed: return "JSONL_PARSING_FAILED"
        case .dataFormatInvalid: return "DATA_FORMAT_INVALID"
        case .timestampParsingFailed: return "TIMESTAMP_PARSING_FAILED"
        case .encodingError: return "ENCODING_ERROR"
        case .schemaVersionMismatch: return "SCHEMA_VERSION_MISMATCH"
        case .databaseConnectionFailed: return "DATABASE_CONNECTION_FAILED"
        case .databaseQueryFailed: return "DATABASE_QUERY_FAILED"
        case .databaseUpdateFailed: return "DATABASE_UPDATE_FAILED"
        case .databaseTransactionFailed: return "DATABASE_TRANSACTION_FAILED"
        case .databaseCorrupted: return "DATABASE_CORRUPTED"
        case .databaseLocked: return "DATABASE_LOCKED"
        case .databaseSchemaMismatch: return "DATABASE_SCHEMA_MISMATCH"
        case .networkUnavailable: return "NETWORK_UNAVAILABLE"
        case .connectionTimeout: return "CONNECTION_TIMEOUT"
        case .authenticationFailed: return "AUTHENTICATION_FAILED"
        case .serverError: return "SERVER_ERROR"
        case .rateLimitExceeded: return "RATE_LIMIT_EXCEEDED"
        case .apiEndpointChanged: return "API_ENDPOINT_CHANGED"
        case .syncInProgress: return "SYNC_IN_PROGRESS"
        case .syncCancelled: return "SYNC_CANCELLED"
        case .syncDataConflict: return "SYNC_DATA_CONFLICT"
        case .lastSyncTimeInvalid: return "LAST_SYNC_TIME_INVALID"
        case .incrementalSyncFailed: return "INCREMENTAL_SYNC_FAILED"
        case .fullSyncRequired: return "FULL_SYNC_REQUIRED"
        case .dataIntegrityCheckFailed: return "DATA_INTEGRITY_CHECK_FAILED"
        case .syncConfigInvalid: return "SYNC_CONFIG_INVALID"
        case .syncIntervalInvalid: return "SYNC_INTERVAL_INVALID"
        case .configServiceUnavailable: return "CONFIG_SERVICE_UNAVAILABLE"
        case .permissionDenied: return "PERMISSION_DENIED"
        }
    }
}