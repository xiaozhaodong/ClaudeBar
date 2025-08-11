import Foundation

/// SQLite 配置服务
/// 使用 SQLite 数据库存储 API 配置，保持现有接口兼容
class SQLiteConfigService: ConfigServiceProtocol {
    private let databaseManager: DatabaseManager
    private let fileManager: FileManager
    private let claudeDirectory: URL
    private let settingsFile: URL
    
    init(fileManager: FileManager = FileManager.default) {
        self.databaseManager = DatabaseManager()
        
        self.fileManager = fileManager
        
        // 使用标准的 ~/.claude 目录
        let homeDir = fileManager.homeDirectoryForCurrentUser
        self.claudeDirectory = homeDir.appendingPathComponent(".claude")
        self.settingsFile = claudeDirectory.appendingPathComponent("settings.json")
        
        // 确保目录存在
        ensureDirectoryExists()
    }
    
    /// 确保 Claude 目录存在
    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: claudeDirectory.path) {
            try? fileManager.createDirectory(at: claudeDirectory, 
                                           withIntermediateDirectories: true, 
                                           attributes: nil)
        }
    }
    
    // MARK: - ConfigServiceProtocol 实现
    
    /// 异步加载所有配置
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
    private func loadConfigsSync() throws -> [ClaudeConfig] {
        do {
            let records = try databaseManager.getAllConfigs()
            
            var configs: [ClaudeConfig] = []
            for record in records {
                let config = convertToClaudeConfig(from: record)
                configs.append(config)
            }
            
            return configs.sorted { $0.name < $1.name }
        } catch {
            throw ConfigManagerError.fileOperationFailed("加载配置失败: \(error.localizedDescription)")
        }
    }
    
    /// 切换配置
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
    private func switchConfigSync(_ config: ClaudeConfig) throws {
        // 1. 在数据库中设置活动配置
        if let record = try databaseManager.getConfig(byName: config.name) {
            try databaseManager.setActiveConfig(byId: record.id)
        } else {
            throw ConfigManagerError.configNotFound(config.name)
        }
        
        // 2. 更新 settings.json 文件
        try updateSettingsFile(config)
        
        print("配置切换成功: \(config.name)")
    }
    
    /// 创建新配置
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
    private func createConfigSync(_ config: ClaudeConfig) throws {
        // 检查配置是否已存在
        if try databaseManager.configExists(name: config.name) {
            throw ConfigManagerError.fileOperationFailed("配置 '\(config.name)' 已存在")
        }
        
        // 在数据库中创建新配置
        let record = APIConfigRecord(
            name: config.name,
            baseURL: config.env.anthropicBaseURL ?? "https://api.anthropic.com",
            authToken: config.env.anthropicAuthToken ?? "",
            isActive: false
        )
        
        try databaseManager.createConfig(record)
        print("配置创建成功: \(config.name)")
    }
    
    /// 删除配置
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
    private func deleteConfigSync(_ config: ClaudeConfig) throws {
        print("尝试删除配置: \(config.name)")
        
        guard let record = try databaseManager.getConfig(byName: config.name) else {
            print("未找到配置: \(config.name)")
            throw ConfigManagerError.configNotFound(config.name)
        }
        
        print("找到配置记录: ID=\(record.id), Name=\(record.name)")
        
        try databaseManager.deleteConfig(byId: record.id)
        print("配置删除成功: \(config.name)")
    }
    
    /// 更新配置
    func updateConfig(_ oldConfig: ClaudeConfig, _ newConfig: ClaudeConfig) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.updateConfigSync(oldConfig, newConfig)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 同步更新配置
    private func updateConfigSync(_ oldConfig: ClaudeConfig, _ newConfig: ClaudeConfig) throws {
        guard let record = try databaseManager.getConfig(byName: oldConfig.name) else {
            throw ConfigManagerError.configNotFound(oldConfig.name)
        }
        
        // 创建更新后的记录
        let updatedRecord = APIConfigRecord(
            id: record.id,
            name: newConfig.name,
            baseURL: newConfig.env.anthropicBaseURL ?? "https://api.anthropic.com",
            authToken: newConfig.env.anthropicAuthToken ?? "",
            isActive: record.isActive, // 保持原有的活动状态
            createdAt: record.createdAt,
            updatedAt: Date()
        )
        
        try databaseManager.updateConfig(updatedRecord)
        
        // 如果是当前活动配置，更新 settings.json
        if record.isActive {
            try updateSettingsFile(newConfig)
        }
        
        print("配置更新成功: \(oldConfig.name) -> \(newConfig.name)")
    }
    
    /// 获取当前配置
    func getCurrentConfig() -> ClaudeConfig? {
        do {
            if let record = try databaseManager.getActiveConfig() {
                return convertToClaudeConfig(from: record)
            }
            return nil
        } catch {
            print("获取当前配置失败: \(error)")
            return nil
        }
    }
    
    /// 验证配置
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
    
    // MARK: - 辅助方法
    
    /// 将数据库记录转换为 ClaudeConfig
    private func convertToClaudeConfig(from record: APIConfigRecord) -> ClaudeConfig {
        let env = ClaudeConfig.Environment(
            anthropicAuthToken: record.authToken,
            anthropicBaseURL: record.baseURL,
            claudeCodeMaxOutputTokens: "32000",
            claudeCodeDisableNonessentialTraffic: "1"
        )
        
        let permissions = ClaudeConfig.Permissions(allow: [], deny: [])
        
        return ClaudeConfig(
            name: record.name,
            env: env,
            permissions: permissions,
            cleanupPeriodDays: 365,
            includeCoAuthoredBy: false
        )
    }
    
    /// 更新 settings.json 文件（复用现有逻辑）
    private func updateSettingsFile(_ config: ClaudeConfig) throws {
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: settingsFile.path) else {
            // 如果文件不存在，创建新的配置文件
            try createNewSettingsFile(config)
            return
        }
        
        // 读取现有文件内容
        let originalContent = try String(contentsOf: settingsFile, encoding: .utf8)
        
        // 使用字符串替换方式更新各个字段，保持原始格式
        var updatedContent = originalContent
        
        // 更新 ANTHROPIC_AUTH_TOKEN
        if let token = config.env.anthropicAuthToken {
            updatedContent = try updateJSONField(
                in: updatedContent,
                field: "ANTHROPIC_AUTH_TOKEN",
                value: token
            )
        }
        
        // 更新 ANTHROPIC_BASE_URL
        if let baseURL = config.env.anthropicBaseURL {
            updatedContent = try updateJSONField(
                in: updatedContent,
                field: "ANTHROPIC_BASE_URL",
                value: baseURL
            )
        }
        
        // 更新 CLAUDE_CODE_MAX_OUTPUT_TOKENS
        if let maxTokens = config.env.claudeCodeMaxOutputTokens {
            updatedContent = try updateJSONField(
                in: updatedContent,
                field: "CLAUDE_CODE_MAX_OUTPUT_TOKENS",
                value: maxTokens
            )
        }
        
        // 更新 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
        if let disableTraffic = config.env.claudeCodeDisableNonessentialTraffic {
            updatedContent = try updateJSONField(
                in: updatedContent,
                field: "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
                value: disableTraffic
            )
        }
        
        // 原子性写回文件
        try updatedContent.write(to: settingsFile, atomically: true, encoding: .utf8)
    }
    
    /// 使用正则表达式精确替换JSON字段值，保持原始格式（复用现有逻辑）
    private func updateJSONField(in content: String, field: String, value: String) throws -> String {
        // 转义JSON值中的特殊字符
        let escapedValue = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        // 构建正则表达式：匹配字段名和其值，但保持原始格式
        let pattern = "(\"\(field)\"\\s*:\\s*\")([^\"]*)(\")"
        let replacement = "$1\(escapedValue)$3"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            throw ConfigManagerError.parseError("无法创建正则表达式用于字段 \(field)")
        }
        
        let range = NSRange(location: 0, length: content.utf16.count)
        let updatedContent = regex.stringByReplacingMatches(
            in: content,
            options: [],
            range: range,
            withTemplate: replacement
        )
        
        return updatedContent
    }
    
    /// 创建新的 settings.json 文件（当文件不存在时使用）
    private func createNewSettingsFile(_ config: ClaudeConfig) throws {
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
        
        let jsonData = try JSONSerialization.data(withJSONObject: settingsData, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try jsonData.write(to: settingsFile)
        
        print("创建新的 settings.json 文件")
    }
}

// MARK: - 数据迁移扩展

extension SQLiteConfigService {
    
    /// 从现有配置文件迁移到 SQLite
    func migrateFromExistingConfigs() async throws -> (success: Bool, migratedCount: Int) {
        var migratedCount = 0
        
        // 1. 尝试从 api_configs.json 迁移（现代格式）
        let apiConfigsFile = claudeDirectory.appendingPathComponent("api_configs.json")
        if fileManager.fileExists(atPath: apiConfigsFile.path) {
            migratedCount += try migrateFromApiConfigs(apiConfigsFile)
        }
        
        // 2. 尝试从传统格式迁移 (*-settings.json)
        let configDir = claudeDirectory.appendingPathComponent("config")
        if fileManager.fileExists(atPath: configDir.path) {
            migratedCount += try migrateFromLegacyConfigs(configDir)
        }
        
        print("迁移完成，共迁移 \(migratedCount) 个配置")
        return (success: true, migratedCount: migratedCount)
    }
    
    /// 从 api_configs.json 迁移
    private func migrateFromApiConfigs(_ file: URL) throws -> Int {
        let data = try Data(contentsOf: file)
        let apiConfigsData = try JSONDecoder().decode(ApiConfigsData.self, from: data)
        
        var migratedCount = 0
        for (name, apiConfig) in apiConfigsData.apiConfigs {
            // 检查是否已存在
            if try !databaseManager.configExists(name: name) {
                let record = APIConfigRecord(
                    name: name,
                    baseURL: apiConfig.anthropicBaseURL,
                    authToken: apiConfig.anthropicAuthToken,
                    isActive: apiConfigsData.current == name
                )
                
                try databaseManager.createConfig(record)
                migratedCount += 1
                print("迁移配置: \(name)")
            }
        }
        
        return migratedCount
    }
    
    /// 从传统格式迁移 (*-settings.json)
    private func migrateFromLegacyConfigs(_ configDir: URL) throws -> Int {
        let files = try fileManager.contentsOfDirectory(at: configDir, 
                                                      includingPropertiesForKeys: nil, 
                                                      options: [.skipsHiddenFiles])
        
        var migratedCount = 0
        for fileURL in files {
            let fileName = fileURL.lastPathComponent
            if fileName.hasSuffix("-settings.json") && fileName != "settings.json" {
                let configName = String(fileName.dropLast("-settings.json".count))
                
                // 检查是否已存在
                if try !databaseManager.configExists(name: configName) {
                    let data = try Data(contentsOf: fileURL)
                    let configData = try JSONDecoder().decode(ConfigData.self, from: data)
                    
                    let record = APIConfigRecord(
                        name: configName,
                        baseURL: configData.env.anthropicBaseURL ?? "https://api.anthropic.com",
                        authToken: configData.env.anthropicAuthToken ?? "",
                        isActive: false
                    )
                    
                    try databaseManager.createConfig(record)
                    migratedCount += 1
                    print("迁移配置: \(configName)")
                }
            }
        }
        
        return migratedCount
    }
}
