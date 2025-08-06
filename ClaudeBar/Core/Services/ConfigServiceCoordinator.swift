import Foundation
import AppKit

/// 配置服务协调器 - 管理新旧格式的过渡
/// 遵循 Strategy 模式：根据情况选择合适的配置服务实现
/// 遵循 SOLID 原则：依赖倒置，依赖抽象而非具体实现
@MainActor
class ConfigServiceCoordinator: ConfigServiceProtocol {
    
    private var activeService: ConfigServiceProtocol
    private let legacyService: ConfigService
    private let modernService: ModernConfigService
    private let fileManager: FileManager
    
    /// 初始化协调器
    /// 遵循 SOLID 原则：依赖注入提高可测试性
    init(fileManager: FileManager = FileManager.default) {
        self.fileManager = fileManager
        self.modernService = ModernConfigService(fileManager: fileManager)
        
        // 初始化传统服务（如需要）
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let claudeDir = homeDir.appendingPathComponent(".claude")
        self.legacyService = ConfigService(configDirectory: claudeDir)
        
        // 默认使用现代服务
        self.activeService = modernService
    }
    
    /// 检查并执行迁移
    /// 遵循 YAGNI 原则：只在需要时执行迁移
    func checkAndMigrate() async throws -> MigrationResult? {
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let claudeDir = homeDir.appendingPathComponent(".claude")
        let legacyConfigDir = claudeDir.appendingPathComponent("config")
        let modernConfigFile = claudeDir.appendingPathComponent("api_configs.json")
        
        // 如果新配置文件已存在，无需迁移
        if fileManager.fileExists(atPath: modernConfigFile.path) {
            print("检测到现代配置文件，使用新格式")
            activeService = modernService
            return nil
        }
        
        // 如果存在旧配置目录，执行迁移
        if fileManager.fileExists(atPath: legacyConfigDir.path) {
            print("检测到旧配置格式，开始自动迁移...")
            
            // 显示迁移提示
            let shouldMigrate = await showMigrationDialog()
            if shouldMigrate {
                let result = try await modernService.migrateFromLegacyConfig()
                if result.success {
                    activeService = modernService
                    print("迁移成功，已切换到新格式")
                } else {
                    print("迁移失败，继续使用旧格式")
                    activeService = legacyService
                }
                return result
            } else {
                print("用户选择不迁移，继续使用旧格式")
                activeService = legacyService
                return nil
            }
        }
        
        // 没有任何配置，使用现代服务
        print("未找到任何配置，使用新格式")
        activeService = modernService
        return nil
    }
    
    /// 显示迁移确认对话框
    /// 遵循 KISS 原则：简单的用户确认界面
    private func showMigrationDialog() async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "API 端点格式升级"
            alert.informativeText = """
            检测到旧的配置格式。为了与 switch-claude.sh 完全兼容，建议升级到新的 API 端点格式。
            
            升级内容：
            • 将配置迁移到 api_configs.json 格式
            • 自动备份现有配置
            • 保持所有功能正常工作
            
            是否现在升级？
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "立即升级")
            alert.addButton(withTitle: "稍后升级")
            
            let response = alert.runModal()
            continuation.resume(returning: response == .alertFirstButtonReturn)
        }
    }
    
    /// 强制切换到现代服务（用于测试）
    func switchToModernService() {
        activeService = modernService
    }
    
    /// 强制切换到传统服务（用于回滚）
    func switchToLegacyService() {
        activeService = legacyService
    }
    
    // MARK: - ConfigServiceProtocol 实现
    
    func loadConfigs() async throws -> [ClaudeConfig] {
        return try await activeService.loadConfigs()
    }
    
    func switchConfig(_ config: ClaudeConfig) async throws {
        try await activeService.switchConfig(config)
    }
    
    func createConfig(_ config: ClaudeConfig) async throws {
        try await activeService.createConfig(config)
    }
    
    func deleteConfig(_ config: ClaudeConfig) async throws {
        try await activeService.deleteConfig(config)
    }
    
    func getCurrentConfig() -> ClaudeConfig? {
        return activeService.getCurrentConfig()
    }
    
    func validateConfig(_ config: ClaudeConfig) throws {
        try activeService.validateConfig(config)
    }
}

/// 配置服务工厂 - 简化服务创建
/// 遵循 Factory 模式：统一服务实例创建
class ConfigServiceFactory {
    
    @MainActor
    static func createService() -> ConfigServiceCoordinator {
        return ConfigServiceCoordinator()
    }
    
    /// 创建现代配置服务（跳过迁移检查）
    static func createModernService() -> ModernConfigService {
        return ModernConfigService()
    }
    
    /// 创建传统配置服务（兼容性测试用）
    static func createLegacyService() -> ConfigService {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let claudeDir = homeDir.appendingPathComponent(".claude")
        return ConfigService(configDirectory: claudeDir)
    }
}