import Foundation

/// 现代化配置服务 - 兼容 switch-claude.sh 格式
/// 遵循 KISS 原则：简化架构，移除复杂的权限管理系统
/// 遵循 SOLID 原则：单一职责，专注于 API 配置管理
class ModernConfigService: ConfigServiceProtocol {
    
    private let fileManager: FileManager
    private let claudeDirectory: URL
    private let apiConfigsFile: URL
    private let settingsFile: URL
    
    /// 初始化服务
    /// 遵循 DI 原则：依赖注入提高可测试性
    init(fileManager: FileManager = FileManager.default) {
        self.fileManager = fileManager
        
        // 简化目录结构：直接使用 ~/.claude
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.claudeDirectory = homeDir.appendingPathComponent(".claude")
        self.apiConfigsFile = claudeDirectory.appendingPathComponent("api_configs.json")
        self.settingsFile = claudeDirectory.appendingPathComponent("settings.json")
        
        // 确保目录存在
        ensureDirectoryExists()
    }
    
    /// 确保 Claude 目录存在
    /// 遵循 KISS 原则：简化目录创建逻辑
    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: claudeDirectory.path) {
            try? fileManager.createDirectory(at: claudeDirectory, 
                                           withIntermediateDirectories: true, 
                                           attributes: nil)
        }
    }
    
    /// 异步加载所有配置
    /// 遵循 SRP 原则：专门负责加载配置数据
    func loadConfigs() async throws -> [ClaudeConfig] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let configs = try self.loadConfigsSync()
                    continuation.resume(returning: configs)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 同步加载配置数据
    /// 遵循 KISS 原则：直接从 api_configs.json 读取
    private func loadConfigsSync() throws -> [ClaudeConfig] {
        // 如果文件不存在，初始化空配置文件
        if !fileManager.fileExists(atPath: apiConfigsFile.path) {
            try initializeApiConfigsFile()
            return []
        }
        
        let data = try Data(contentsOf: apiConfigsFile)
        let apiConfigsData = try JSONDecoder().decode(ApiConfigsData.self, from: data)
        
        // 转换为 ClaudeConfig 数组
        var configs: [ClaudeConfig] = []
        for (name, apiConfig) in apiConfigsData.apiConfigs {
            let config = ClaudeConfig(name: name, apiConfig: apiConfig)
            configs.append(config)
        }
        
        return configs.sorted { $0.name < $1.name }
    }
    
    /// 初始化 API 配置文件
    /// 遵循 DRY 原则：统一初始化逻辑
    private func initializeApiConfigsFile() throws {
        let emptyConfig = ApiConfigsData(current: "", apiConfigs: [:])
        let data = try JSONEncoder().encode(emptyConfig)
        try data.write(to: apiConfigsFile)
    }
    
    /// 切换配置
    /// 遵循 SOLID 原则：开闭原则，易于扩展新的切换逻辑
    func switchConfig(_ config: ClaudeConfig) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.validateConfig(config)
                    try self.switchConfigSync(config)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 同步切换配置逻辑
    /// 遵循 KISS 原则：简化切换过程，直接更新两个文件
    private func switchConfigSync(_ config: ClaudeConfig) throws {
        // 1. 更新 api_configs.json 中的 current 字段
        try updateCurrentConfig(config.name)
        
        // 2. 更新 settings.json
        try updateSettingsFile(config)
    }
    
    /// 更新当前配置记录
    /// 遵循 SRP 原则：专门负责更新 current 字段
    private func updateCurrentConfig(_ configName: String) throws {
        var apiConfigsData: ApiConfigsData
        
        if fileManager.fileExists(atPath: apiConfigsFile.path) {
            let data = try Data(contentsOf: apiConfigsFile)
            apiConfigsData = try JSONDecoder().decode(ApiConfigsData.self, from: data)
        } else {
            apiConfigsData = ApiConfigsData(current: "", apiConfigs: [:])
        }
        
        apiConfigsData.current = configName
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(apiConfigsData)
        try data.write(to: apiConfigsFile)
    }
    
    /// 更新 settings.json 文件
    /// 遵循 DRY 原则：消除重复的配置更新逻辑
    private func updateSettingsFile(_ config: ClaudeConfig) throws {
        // 创建基础 settings.json 结构
        let settingsData: [String: Any] = [
            "env": [
                "ANTHROPIC_AUTH_TOKEN": config.env.anthropicAuthToken ?? "",
                "ANTHROPIC_BASE_URL": config.env.anthropicBaseURL ?? "https://api.anthropic.com",
                "CLAUDE_CODE_MAX_OUTPUT_TOKENS": config.env.claudeCodeMaxOutputTokens ?? "32000",
                "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": config.env.claudeCodeDisableNonessentialTraffic ?? "1"
            ],
            "permissions": [
                "allow": config.permissions?.allow ?? [],
                "deny": config.permissions?.deny ?? []
            ],
            "cleanupPeriodDays": config.cleanupPeriodDays ?? 365,
            "includeCoAuthoredBy": config.includeCoAuthoredBy ?? false
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: settingsData, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: settingsFile)
    }
    
    /// 创建新配置
    /// 遵循 SOLID 原则：里氏替换原则，保持接口一致性
    func createConfig(_ config: ClaudeConfig) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.validateConfig(config)
                    try self.createConfigSync(config)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 同步创建配置
    /// 遵循 SRP 原则：专门负责配置创建逻辑
    private func createConfigSync(_ config: ClaudeConfig) throws {
        var apiConfigsData: ApiConfigsData
        
        if fileManager.fileExists(atPath: apiConfigsFile.path) {
            let data = try Data(contentsOf: apiConfigsFile)
            apiConfigsData = try JSONDecoder().decode(ApiConfigsData.self, from: data)
        } else {
            apiConfigsData = ApiConfigsData(current: "", apiConfigs: [:])
        }
        
        // 检查配置是否已存在
        if apiConfigsData.apiConfigs[config.name] != nil {
            throw ConfigManagerError.fileOperationFailed("配置 '\(config.name)' 已存在")
        }
        
        // 添加新配置
        let apiConfig = config.toApiEndpointConfig()
        apiConfigsData.apiConfigs[config.name] = apiConfig
        
        // 如果是第一个配置，设为当前配置
        if apiConfigsData.current.isEmpty {
            apiConfigsData.current = config.name
        }
        
        // 保存更新后的配置
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(apiConfigsData)
        try data.write(to: apiConfigsFile)
    }
    
    /// 删除配置
    /// 遵循 SOLID 原则：接口隔离原则，提供完整的CRUD操作
    func deleteConfig(_ config: ClaudeConfig) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.deleteConfigSync(config)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 同步删除配置
    /// 遵循 SRP 原则：专门负责配置删除逻辑
    private func deleteConfigSync(_ config: ClaudeConfig) throws {
        guard fileManager.fileExists(atPath: apiConfigsFile.path) else {
            throw ConfigManagerError.configNotFound(config.name)
        }
        
        let data = try Data(contentsOf: apiConfigsFile)
        var apiConfigsData = try JSONDecoder().decode(ApiConfigsData.self, from: data)
        
        // 检查配置是否存在
        guard apiConfigsData.apiConfigs[config.name] != nil else {
            throw ConfigManagerError.configNotFound(config.name)
        }
        
        // 删除配置
        apiConfigsData.apiConfigs.removeValue(forKey: config.name)
        
        // 如果删除的是当前配置，清空当前配置
        if apiConfigsData.current == config.name {
            apiConfigsData.current = apiConfigsData.apiConfigs.keys.first ?? ""
        }
        
        // 保存更新后的配置
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let updatedData = try encoder.encode(apiConfigsData)
        try updatedData.write(to: apiConfigsFile)
    }
    
    /// 获取当前配置
    /// 遵循 KISS 原则：简化当前配置获取逻辑
    func getCurrentConfig() -> ClaudeConfig? {
        guard fileManager.fileExists(atPath: apiConfigsFile.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: apiConfigsFile)
            let apiConfigsData = try JSONDecoder().decode(ApiConfigsData.self, from: data)
            
            guard !apiConfigsData.current.isEmpty,
                  let apiConfig = apiConfigsData.apiConfigs[apiConfigsData.current] else {
                return nil
            }
            
            return ClaudeConfig(name: apiConfigsData.current, apiConfig: apiConfig)
        } catch {
            print("获取当前配置失败: \(error)")
            return nil
        }
    }
    
    /// 验证配置
    /// 遵循 SRP 原则：专门负责配置验证逻辑
    func validateConfig(_ config: ClaudeConfig) throws {
        // 验证配置名称
        guard !config.name.isEmpty else {
            throw ConfigManagerError.configInvalid("配置名称不能为空")
        }
        
        // 验证配置名称格式（不能包含特殊字符）
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard config.name.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            throw ConfigManagerError.configInvalid("配置名称只能包含字母、数字、连字符和下划线")
        }
        
        // 验证 API Token
        guard let token = config.env.anthropicAuthToken, !token.isEmpty else {
            throw ConfigManagerError.configInvalid("API Token 不能为空")
        }
        
        // 验证 Base URL 格式（如果提供）
        if let baseURL = config.env.anthropicBaseURL, !baseURL.isEmpty {
            guard URL(string: baseURL) != nil else {
                throw ConfigManagerError.configInvalid("Base URL 格式无效")
            }
        }
    }
}

// MARK: - 迁移功能

extension ModernConfigService {
    
    /// 从旧配置格式迁移到新格式
    /// 遵循 SOLID 原则：开闭原则，通过扩展添加新功能
    func migrateFromLegacyConfig() async throws -> MigrationResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.performMigration()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 执行迁移操作
    /// 遵循 KISS 原则：直接的迁移逻辑，无复杂的权限处理
    private func performMigration() throws -> MigrationResult {
        let legacyConfigDir = claudeDirectory.appendingPathComponent("config")
        
        // 检查是否存在旧配置
        guard fileManager.fileExists(atPath: legacyConfigDir.path) else {
            return MigrationResult(success: true, migratedConfigs: 0, errors: [], currentConfig: nil)
        }
        
        // 创建备份
        let backupResult = try createBackup()
        var errors: [ConfigManagerError] = backupResult.errors
        
        var apiConfigsData = ApiConfigsData(current: "", apiConfigs: [:])
        var migratedCount = 0
        var currentConfigName: String?
        
        // 迁移每个配置文件
        let configFiles = try fileManager.contentsOfDirectory(at: legacyConfigDir, 
                                                             includingPropertiesForKeys: nil, 
                                                             options: [.skipsHiddenFiles])
        
        for fileURL in configFiles {
            let fileName = fileURL.lastPathComponent
            if fileName.hasSuffix("-settings.json") && fileName != "settings.json" {
                do {
                    let configName = String(fileName.dropLast("-settings.json".count))
                    let legacyData = try Data(contentsOf: fileURL)
                    let configData = try JSONDecoder().decode(ConfigData.self, from: legacyData)
                    
                    // 转换为新格式
                    let apiConfig = ApiEndpointConfig(
                        anthropicAuthToken: configData.env.anthropicAuthToken ?? "",
                        anthropicBaseURL: configData.env.anthropicBaseURL ?? "https://api.anthropic.com"
                    )
                    
                    apiConfigsData.apiConfigs[configName] = apiConfig
                    migratedCount += 1
                    
                    print("已迁移配置: \(configName)")
                } catch {
                    errors.append(ConfigManagerError.migrationFailed("迁移配置 \(fileName) 失败: \(error)"))
                }
            }
        }
        
        // 尝试确定当前配置
        if fileManager.fileExists(atPath: settingsFile.path) {
            do {
                let currentData = try Data(contentsOf: settingsFile)
                let currentConfigData = try JSONDecoder().decode(ConfigData.self, from: currentData)
                
                // 找到匹配的配置
                for (name, apiConfig) in apiConfigsData.apiConfigs {
                    if apiConfig.anthropicAuthToken == currentConfigData.env.anthropicAuthToken &&
                       apiConfig.anthropicBaseURL == currentConfigData.env.anthropicBaseURL {
                        currentConfigName = name
                        apiConfigsData.current = name
                        break
                    }
                }
            } catch {
                errors.append(ConfigManagerError.migrationFailed("无法确定当前配置: \(error)"))
            }
        }
        
        // 如果没有找到当前配置但有可用配置，设置第一个为当前配置
        if apiConfigsData.current.isEmpty && !apiConfigsData.apiConfigs.isEmpty {
            apiConfigsData.current = apiConfigsData.apiConfigs.keys.first!
            currentConfigName = apiConfigsData.current
        }
        
        // 保存新的配置文件
        if migratedCount > 0 {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(apiConfigsData)
            try data.write(to: apiConfigsFile)
            
            print("迁移完成，已保存到: \(apiConfigsFile.path)")
        }
        
        return MigrationResult(
            success: errors.isEmpty,
            migratedConfigs: migratedCount,
            errors: errors,
            currentConfig: currentConfigName
        )
    }
    
    /// 创建备份
    /// 遵循 SRP 原则：专门负责备份逻辑
    private func createBackup() throws -> (success: Bool, errors: [ConfigManagerError]) {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupDir = claudeDirectory.appendingPathComponent("backup-\(timestamp)")
        
        var errors: [ConfigManagerError] = []
        
        do {
            try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true, attributes: nil)
            
            // 备份 config 目录
            let configDir = claudeDirectory.appendingPathComponent("config")
            if fileManager.fileExists(atPath: configDir.path) {
                let backupConfigDir = backupDir.appendingPathComponent("config")
                try fileManager.copyItem(at: configDir, to: backupConfigDir)
            }
            
            // 备份 settings.json
            if fileManager.fileExists(atPath: settingsFile.path) {
                let backupSettingsFile = backupDir.appendingPathComponent("settings.json")
                try fileManager.copyItem(at: settingsFile, to: backupSettingsFile)
            }
            
            print("备份已创建: \(backupDir.path)")
            return (true, errors)
        } catch {
            errors.append(ConfigManagerError.backupCreationFailed("创建备份失败: \(error)"))
            return (false, errors)
        }
    }
}