import Foundation

/// Claude 配置模型
struct ClaudeConfig: Codable, Identifiable, Hashable {
    var id = UUID()
    let name: String
    let env: Environment
    let permissions: Permissions?
    let cleanupPeriodDays: Int?
    let includeCoAuthoredBy: Bool?
    
    /// 环境变量配置
    struct Environment: Codable, Hashable {
        let anthropicAuthToken: String?
        let anthropicBaseURL: String?
        let claudeCodeMaxOutputTokens: String?
        let claudeCodeDisableNonessentialTraffic: String?
        
        private enum CodingKeys: String, CodingKey {
            case anthropicAuthToken = "ANTHROPIC_AUTH_TOKEN"
            case anthropicBaseURL = "ANTHROPIC_BASE_URL"
            case claudeCodeMaxOutputTokens = "CLAUDE_CODE_MAX_OUTPUT_TOKENS"
            case claudeCodeDisableNonessentialTraffic = "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"
        }
    }
    
    /// 权限配置
    struct Permissions: Codable, Hashable {
        let allow: [String]
        let deny: [String]
    }
    
    /// 从配置名称创建配置对象
    init(name: String, configData: ConfigData) {
        self.name = name
        self.env = configData.env
        self.permissions = configData.permissions
        self.cleanupPeriodDays = configData.cleanupPeriodDays
        self.includeCoAuthoredBy = configData.includeCoAuthoredBy
    }
    
    /// 直接初始化
    init(name: String, env: Environment, permissions: Permissions? = nil, 
         cleanupPeriodDays: Int? = nil, includeCoAuthoredBy: Bool? = nil) {
        self.name = name
        self.env = env
        self.permissions = permissions
        self.cleanupPeriodDays = cleanupPeriodDays
        self.includeCoAuthoredBy = includeCoAuthoredBy
    }
    
    /// 获取显示用的 Token 预览（只显示前几位）
    var tokenPreview: String {
        guard let token = env.anthropicAuthToken, !token.isEmpty else {
            return "未设置"
        }
        let visibleLength = min(8, token.count)
        return String(token.prefix(visibleLength)) + "..."
    }
    
    /// 获取 Base URL 显示文本
    var baseURLDisplay: String {
        return env.anthropicBaseURL ?? "默认"
    }
    
    /// 检查配置是否有效
    var isValid: Bool {
        return env.anthropicAuthToken != nil && !env.anthropicAuthToken!.isEmpty
    }
}

/// 配置文件的数据结构（用于 JSON 序列化）
struct ConfigData: Codable {
    let env: ClaudeConfig.Environment
    let permissions: ClaudeConfig.Permissions?
    let cleanupPeriodDays: Int?
    let includeCoAuthoredBy: Bool?
}

/// 配置管理错误类型
///
/// 定义配置管理过程中可能出现的各种错误类型，
/// 并提供用户友好的错误消息和恢复建议
enum ConfigManagerError: LocalizedError {
    case configNotFound(String)
    case configInvalid(String)
    case fileOperationFailed(String)
    case claudeNotInstalled
    case claudeStartFailed
    case keychainError(OSStatus)
    case networkError(Error)
    case parseError(String)
    case permissionDenied(String)
    case diskSpaceInsufficient
    case configDirectoryInaccessible(String)
    case tokenMigrationFailed(String)
    
    /// 用户友好的错误描述
    var errorDescription: String? {
        switch self {
        case .configNotFound(let name):
            return "找不到配置 '\(name)'"
        case .configInvalid(let reason):
            return "配置格式无效：\(reason)"
        case .fileOperationFailed(let reason):
            return "文件操作失败：\(reason)"
        case .claudeNotInstalled:
            return "Claude CLI 未安装或无法找到"
        case .claudeStartFailed:
            return "启动 Claude 进程失败"
        case .keychainError(let status):
            return self.keychainErrorMessage(for: status)
        case .networkError(let error):
            return "网络连接错误：\(error.localizedDescription)"
        case .parseError(let reason):
            return "配置文件解析错误：\(reason)"
        case .permissionDenied(let path):
            return "访问权限被拒绝：\(path)"
        case .diskSpaceInsufficient:
            return "磁盘空间不足，无法保存配置文件"
        case .configDirectoryInaccessible(let path):
            return "无法访问配置目录：\(path)"
        case .tokenMigrationFailed(let reason):
            return "Token 迁移到安全存储失败：\(reason)"
        }
    }
    
    /// 恢复建议
    var recoverySuggestion: String? {
        switch self {
        case .configNotFound(let name):
            return """
            建议操作：
            1. 检查配置文件 '\(name)-settings.json' 是否存在于 ~/.claude 目录中
            2. 确认配置名称拼写是否正确
            3. 可以在应用中创建新的配置
            """
        case .configInvalid(let reason):
            if reason.contains("API Token") {
                return """
                建议操作：
                1. 检查 Token 是否完整且未被截断
                2. 确认 Token 来源是否可靠
                3. 联系相关服务提供商获取有效的 API Token
                """
            } else if reason.contains("配置名称") {
                return """
                建议操作：
                1. 配置名称只能包含字母、数字、连字符和下划线
                2. 避免使用空格和特殊字符
                3. 建议使用描述性的名称，如 'work' 或 'personal'
                """
            } else {
                return """
                建议操作：
                1. 检查配置文件格式是否正确
                2. 参考示例配置文件进行修正
                3. 删除并重新创建配置
                """
            }
        case .claudeNotInstalled:
            return """
            建议操作：
            1. 安装 Claude CLI：访问 https://claude.ai 下载最新版本
            2. 确保 Claude CLI 已添加到系统 PATH 环境变量中
            3. 在终端中运行 'claude --version' 验证安装
            4. 重启应用以重新检测 Claude CLI
            """
        case .claudeStartFailed:
            return """
            建议操作：
            1. 检查 Claude CLI 是否正确安装
            2. 确认当前配置是否有效
            3. 重新启动应用并重试
            4. 查看系统日志获取详细错误信息
            """
        case .fileOperationFailed(let reason):
            if reason.contains("权限") {
                return """
                建议操作：
                1. 检查 ~/.claude 目录的读写权限
                2. 尝试手动创建配置目录：mkdir -p ~/.claude
                3. 确保当前用户有权限写入该目录
                """
            } else if reason.contains("空间") {
                return """
                建议操作：
                1. 清理磁盘空间，删除不必要的文件
                2. 移动大文件到外部存储
                3. 清空垃圾箱释放空间
                """
            } else {
                return """
                建议操作：
                1. 检查文件是否被其他程序占用
                2. 重启应用并重试
                3. 检查磁盘空间和文件权限
                """
            }
        case .keychainError:
            return """
            建议操作：
            1. 检查钥匙串访问权限设置
            2. 解锁系统钥匙串
            3. 重新启动钥匙串代理：killall SecurityAgent
            4. 如果问题持续，可能需要重新创建配置
            """
        case .networkError:
            return """
            建议操作：
            1. 检查网络连接是否正常
            2. 确认防火墙设置允许应用访问网络
            3. 如果使用代理，请检查代理设置
            4. 稍后重试或联系网络管理员
            """
        case .parseError:
            return """
            建议操作：
            1. 使用 JSON 验证工具检查配置文件格式
            2. 比较与工作正常的配置文件差异
            3. 删除有问题的配置文件并重新创建
            4. 确保文件编码为 UTF-8
            """
        case .permissionDenied:
            return """
            建议操作：
            1. 检查文件和目录的访问权限
            2. 在系统偏好设置中授予应用必要权限
            3. 尝试以管理员权限运行（不推荐）
            4. 联系系统管理员获取帮助
            """
        case .diskSpaceInsufficient:
            return """
            建议操作：
            1. 删除不需要的文件释放空间
            2. 清空垃圾箱和下载文件夹
            3. 移动大文件到外部存储
            4. 使用磁盘工具检查和修复磁盘
            """
        case .configDirectoryInaccessible:
            return """
            建议操作：
            1. 手动创建配置目录：mkdir -p ~/.claude
            2. 检查目录权限：ls -la ~/.claude
            3. 修复权限：chmod 755 ~/.claude
            4. 重启应用重新尝试
            """
        case .tokenMigrationFailed:
            return """
            建议操作：
            1. 手动记录配置文件中的 Token
            2. 删除并重新创建配置
            3. 检查钥匙串权限设置
            4. 如果问题持续，可以继续使用但 Token 可能不安全
            """
        }
    }
    
    /// 错误的严重程度
    var severity: ErrorSeverity {
        switch self {
        case .configNotFound, .configInvalid:
            return .warning
        case .claudeNotInstalled:
            return .critical
        case .fileOperationFailed, .permissionDenied, .diskSpaceInsufficient:
            return .error
        case .keychainError, .tokenMigrationFailed:
            return .warning
        case .networkError, .parseError:
            return .error
        case .claudeStartFailed, .configDirectoryInaccessible:
            return .critical
        }
    }
    
    /// 是否可以自动恢复
    var isRecoverable: Bool {
        switch self {
        case .configNotFound, .configInvalid:
            return true
        case .claudeNotInstalled:
            return false
        case .fileOperationFailed, .permissionDenied:
            return true
        case .keychainError, .tokenMigrationFailed:
            return true
        case .networkError:
            return true
        case .parseError:
            return true
        case .claudeStartFailed, .diskSpaceInsufficient, .configDirectoryInaccessible:
            return false
        }
    }
    
    /// 用户操作建议
    var userAction: UserAction {
        switch self {
        case .configNotFound:
            return .createNew
        case .configInvalid:
            return .editConfig
        case .claudeNotInstalled:
            return .installClaude
        case .fileOperationFailed, .permissionDenied:
            return .checkPermissions
        case .keychainError, .tokenMigrationFailed:
            return .retryOperation
        case .networkError:
            return .checkNetwork
        case .parseError:
            return .fixConfigFormat
        case .claudeStartFailed:
            return .restartApp
        case .diskSpaceInsufficient:
            return .freeSpace
        case .configDirectoryInaccessible:
            return .contactSupport
        }
    }
    
    /// 根据钥匙串错误代码生成友好消息
    private func keychainErrorMessage(for status: OSStatus) -> String {
        switch status {
        case errSecItemNotFound:
            return "钥匙串中未找到存储的 Token"
        case errSecDuplicateItem:
            return "钥匙串中已存在相同的项目"
        case errSecAuthFailed:
            return "钥匙串认证失败，请检查系统钥匙串状态"
        case errSecUserCanceled:
            return "用户取消了钥匙串操作"
        case errSecInteractionNotAllowed:
            return "当前不允许与钥匙串交互，请解锁钥匙串"
        case errSecNotAvailable:
            return "钥匙串服务不可用"
        case errSecParam:
            return "钥匙串操作参数无效"
        case errSecAllocate:
            return "钥匙串内存分配失败"
        default:
            return "钥匙串操作失败（错误代码：\(status)）"
        }
    }
}

/// 错误严重程度
enum ErrorSeverity {
    case warning    // 警告：不影响基本功能
    case error      // 错误：影响部分功能
    case critical   // 严重：影响核心功能
    
    var displayName: String {
        switch self {
        case .warning: return "警告"
        case .error: return "错误"
        case .critical: return "严重错误"
        }
    }
    
    var iconName: String {
        switch self {
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

/// 用户操作建议
enum UserAction {
    case createNew       // 创建新配置
    case editConfig      // 编辑配置
    case installClaude   // 安装 Claude CLI
    case checkPermissions // 检查权限
    case retryOperation  // 重试操作
    case checkNetwork    // 检查网络
    case fixConfigFormat // 修复配置格式
    case restartApp      // 重启应用
    case freeSpace       // 释放磁盘空间
    case contactSupport  // 联系技术支持
    
    var displayName: String {
        switch self {
        case .createNew: return "创建新配置"
        case .editConfig: return "编辑配置"
        case .installClaude: return "安装 Claude CLI"
        case .checkPermissions: return "检查权限"
        case .retryOperation: return "重试操作"
        case .checkNetwork: return "检查网络"
        case .fixConfigFormat: return "修复格式"
        case .restartApp: return "重启应用"
        case .freeSpace: return "释放空间"
        case .contactSupport: return "联系支持"
        }
    }
}
