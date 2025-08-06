import XCTest
@testable import ClaudeBar

/// ConfigService 单元测试类
///
/// 测试 ConfigService 的核心功能，包括：
/// - 配置文件加载和解析
/// - 配置切换和创建
/// - Keychain 集成
/// - 错误处理
final class ConfigServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var configService: ConfigService!
    var mockKeychainService: MockKeychainService!
    var tempDirectory: URL!
    var originalConfigDirectory: URL?
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        super.setUp()
        
        // 创建临时测试目录
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConfigServiceTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // 创建 mock 对象
        mockKeychainService = MockKeychainService()
        
        // 创建测试用的 ConfigService
        configService = ConfigService(
            fileManager: FileManager.default,
            configDirectory: tempDirectory,
            keychainService: mockKeychainService
        )
    }
    
    override func tearDownWithError() throws {
        // 清理临时目录
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        configService = nil
        mockKeychainService = nil
        tempDirectory = nil
        
        super.tearDown()
    }
    
    // MARK: - Configuration Loading Tests
    
    /// 测试加载空目录
    func testLoadConfigsFromEmptyDirectory() async throws {
        let configs = try await configService.loadConfigs()
        XCTAssertTrue(configs.isEmpty, "空目录应该返回空配置列表")
    }
    
    /// 测试加载单个有效配置
    func testLoadSingleValidConfig() async throws {
        // 创建测试配置文件
        let configName = "test"
        let configData = createTestConfigData()
        try createTestConfigFile(name: configName, data: configData)
        
        let configs = try await configService.loadConfigs()
        
        XCTAssertEqual(configs.count, 1, "应该加载一个配置")
        XCTAssertEqual(configs.first?.name, configName, "配置名称应该匹配")
        XCTAssertEqual(configs.first?.env.anthropicBaseURL, configData.env.anthropicBaseURL)
    }
    
    /// 测试加载多个配置并验证排序
    func testLoadMultipleConfigsSorted() async throws {
        let configNames = ["zebra", "alpha", "beta"]
        
        for name in configNames {
            let configData = createTestConfigData()
            try createTestConfigFile(name: name, data: configData)
        }
        
        let configs = try await configService.loadConfigs()
        
        XCTAssertEqual(configs.count, 3, "应该加载三个配置")
        XCTAssertEqual(configs.map { $0.name }, ["alpha", "beta", "zebra"], "配置应该按名称排序")
    }
    
    /// 测试忽略无效的配置文件
    func testIgnoreInvalidConfigFiles() async throws {
        // 创建有效配置
        try createTestConfigFile(name: "valid", data: createTestConfigData())
        
        // 创建无效的JSON文件
        let invalidFile = tempDirectory.appendingPathComponent("invalid-settings.json")
        try "invalid json content".write(to: invalidFile, atomically: true, encoding: .utf8)
        
        // 创建非配置文件
        let otherFile = tempDirectory.appendingPathComponent("other.json")
        try "{}".write(to: otherFile, atomically: true, encoding: .utf8)
        
        let configs = try await configService.loadConfigs()
        
        XCTAssertEqual(configs.count, 1, "应该只加载有效的配置文件")
        XCTAssertEqual(configs.first?.name, "valid")
    }
    
    // MARK: - Keychain Integration Tests
    
    /// 测试从 Keychain 加载 Token
    func testLoadTokenFromKeychain() async throws {
        let configName = "test"
        let token = "sk-test-token-from-keychain"
        
        // 在 Keychain 中设置 Token
        mockKeychainService.mockTokens[configName] = token
        
        // 创建不包含 Token 的配置文件
        var configData = createTestConfigData()
        configData = ConfigData(
            env: ClaudeConfig.Environment(
                anthropicAuthToken: nil,
                anthropicBaseURL: configData.env.anthropicBaseURL,
                claudeCodeMaxOutputTokens: configData.env.claudeCodeMaxOutputTokens,
                claudeCodeDisableNonessentialTraffic: configData.env.claudeCodeDisableNonessentialTraffic
            ),
            permissions: configData.permissions,
            cleanupPeriodDays: configData.cleanupPeriodDays,
            includeCoAuthoredBy: configData.includeCoAuthoredBy
        )
        try createTestConfigFile(name: configName, data: configData)
        
        let configs = try await configService.loadConfigs()
        
        XCTAssertEqual(configs.count, 1)
        XCTAssertEqual(configs.first?.env.anthropicAuthToken, token, "应该从 Keychain 加载 Token")
    }
    
    /// 测试 Token 从文件迁移到 Keychain
    func testMigrateTokenFromFileToKeychain() async throws {
        let configName = "test"
        let token = "sk-test-token-in-file"
        
        // 创建包含 Token 的配置文件
        var configData = createTestConfigData()
        configData = ConfigData(
            env: ClaudeConfig.Environment(
                anthropicAuthToken: token,
                anthropicBaseURL: configData.env.anthropicBaseURL,
                claudeCodeMaxOutputTokens: configData.env.claudeCodeMaxOutputTokens,
                claudeCodeDisableNonessentialTraffic: configData.env.claudeCodeDisableNonessentialTraffic
            ),
            permissions: configData.permissions,
            cleanupPeriodDays: configData.cleanupPeriodDays,
            includeCoAuthoredBy: configData.includeCoAuthoredBy
        )
        try createTestConfigFile(name: configName, data: configData)
        
        let configs = try await configService.loadConfigs()
        
        XCTAssertEqual(configs.count, 1)
        XCTAssertEqual(configs.first?.env.anthropicAuthToken, token, "配置中应该包含 Token")
        XCTAssertEqual(mockKeychainService.mockTokens[configName], token, "Token 应该被存储到 Keychain")
        
        // 验证文件中的 Token 被移除
        let updatedFileData = try Data(contentsOf: tempDirectory.appendingPathComponent("\(configName)-settings.json"))
        let updatedConfigData = try JSONDecoder().decode(ConfigData.self, from: updatedFileData)
        XCTAssertNil(updatedConfigData.env.anthropicAuthToken, "文件中的 Token 应该被移除")
    }
    
    // MARK: - Config Switching Tests
    
    /// 测试成功切换配置
    func testSwitchConfigSuccess() async throws {
        let configName = "test"
        let configData = createTestConfigData()
        try createTestConfigFile(name: configName, data: configData)
        
        let configs = try await configService.loadConfigs()
        guard let config = configs.first else {
            XCTFail("应该加载到配置")
            return
        }
        
        try await configService.switchConfig(config)
        
        // 验证 settings.json 文件被创建
        let settingsFile = tempDirectory.appendingPathComponent("settings.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsFile.path), "应该创建 settings.json 文件")
        
        // 验证内容正确
        let settingsData = try Data(contentsOf: settingsFile)
        let savedConfig = try JSONDecoder().decode(ConfigData.self, from: settingsData)
        XCTAssertEqual(savedConfig.env.anthropicBaseURL, configData.env.anthropicBaseURL)
    }
    
    /// 测试切换不存在的配置
    func testSwitchNonexistentConfig() async {
        let nonexistentConfig = ClaudeConfig(
            name: "nonexistent",
            env: ClaudeConfig.Environment(
                anthropicAuthToken: "token",
                anthropicBaseURL: "url",
                claudeCodeMaxOutputTokens: nil,
                claudeCodeDisableNonessentialTraffic: nil
            )
        )
        
        do {
            try await configService.switchConfig(nonexistentConfig)
            XCTFail("应该抛出配置未找到错误")
        } catch ConfigManagerError.configNotFound(let name) {
            XCTAssertEqual(name, "nonexistent")
        } catch {
            XCTFail("应该抛出 ConfigManagerError.configNotFound 错误，而不是 \(error)")
        }
    }
    
    // MARK: - Config Creation Tests
    
    /// 测试创建新配置
    func testCreateNewConfig() async throws {
        let configName = "newconfig"
        let token = "sk-new-token"
        let config = ClaudeConfig(
            name: configName,
            env: ClaudeConfig.Environment(
                anthropicAuthToken: token,
                anthropicBaseURL: "https://api.anthropic.com",
                claudeCodeMaxOutputTokens: "32000",
                claudeCodeDisableNonessentialTraffic: "1"
            ),
            permissions: ClaudeConfig.Permissions(allow: [], deny: []),
            cleanupPeriodDays: 365,
            includeCoAuthoredBy: false
        )
        
        try await configService.createConfig(config)
        
        // 验证配置文件被创建
        let configFile = tempDirectory.appendingPathComponent("\(configName)-settings.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configFile.path), "应该创建配置文件")
        
        // 验证 Token 存储到 Keychain
        XCTAssertEqual(mockKeychainService.mockTokens[configName], token, "Token 应该存储到 Keychain")
        
        // 验证配置文件不包含 Token
        let fileData = try Data(contentsOf: configFile)
        let savedConfigData = try JSONDecoder().decode(ConfigData.self, from: fileData)
        XCTAssertNil(savedConfigData.env.anthropicAuthToken, "配置文件不应该包含 Token")
    }
    
    /// 测试创建重复配置
    func testCreateDuplicateConfig() async throws {
        let configName = "duplicate"
        let configData = createTestConfigData()
        try createTestConfigFile(name: configName, data: configData)
        
        let duplicateConfig = ClaudeConfig(
            name: configName,
            env: ClaudeConfig.Environment(
                anthropicAuthToken: "token",
                anthropicBaseURL: "url",
                claudeCodeMaxOutputTokens: nil,
                claudeCodeDisableNonessentialTraffic: nil
            )
        )
        
        do {
            try await configService.createConfig(duplicateConfig)
            XCTFail("应该抛出文件操作失败错误")
        } catch ConfigManagerError.fileOperationFailed(let message) {
            XCTAssertTrue(message.contains("已存在"), "错误消息应该包含'已存在'")
        } catch {
            XCTFail("应该抛出 ConfigManagerError.fileOperationFailed 错误，而不是 \(error)")
        }
    }
    
    // MARK: - Config Deletion Tests
    
    /// 测试删除配置
    func testDeleteConfig() async throws {
        let configName = "todelete"
        let token = "sk-delete-token"
        let configData = createTestConfigData()
        try createTestConfigFile(name: configName, data: configData)
        
        // 在 Keychain 中设置 Token
        mockKeychainService.mockTokens[configName] = token
        
        let configs = try await configService.loadConfigs()
        guard let config = configs.first else {
            XCTFail("应该加载到配置")
            return
        }
        
        try await configService.deleteConfig(config)
        
        // 验证配置文件被删除
        let configFile = tempDirectory.appendingPathComponent("\(configName)-settings.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: configFile.path), "配置文件应该被删除")
        
        // 验证 Keychain 中的 Token 被删除
        XCTAssertTrue(mockKeychainService.deletedConfigs.contains(configName), "Keychain 中的 Token 应该被删除")
    }
    
    /// 测试删除不存在的配置
    func testDeleteNonexistentConfig() async {
        let nonexistentConfig = ClaudeConfig(
            name: "nonexistent",
            env: ClaudeConfig.Environment(
                anthropicAuthToken: "token",
                anthropicBaseURL: "url",
                claudeCodeMaxOutputTokens: nil,
                claudeCodeDisableNonessentialTraffic: nil
            )
        )
        
        do {
            try await configService.deleteConfig(nonexistentConfig)
            XCTFail("应该抛出配置未找到错误")
        } catch ConfigManagerError.configNotFound(let name) {
            XCTAssertEqual(name, "nonexistent")
        } catch {
            XCTFail("应该抛出 ConfigManagerError.configNotFound 错误，而不是 \(error)")
        }
    }
    
    // MARK: - Current Config Tests
    
    /// 测试获取当前配置（不存在 settings.json）
    func testGetCurrentConfigWhenNoSettingsFile() {
        let currentConfig = configService.getCurrentConfig()
        XCTAssertNil(currentConfig, "没有 settings.json 时应该返回 nil")
    }
    
    /// 测试获取当前配置（存在匹配的配置）
    func testGetCurrentConfigWithMatchingConfig() async throws {
        let configName = "current"
        let configData = createTestConfigData()
        try createTestConfigFile(name: configName, data: configData)
        
        // 创建 settings.json
        let settingsFile = tempDirectory.appendingPathComponent("settings.json")
        let settingsData = try JSONEncoder().encode(configData)
        try settingsData.write(to: settingsFile)
        
        let currentConfig = configService.getCurrentConfig()
        XCTAssertNotNil(currentConfig, "应该返回当前配置")
        XCTAssertEqual(currentConfig?.name, configName, "应该匹配正确的配置")
    }
    
    
    // MARK: - Config Validation Tests
    
    /// 测试验证有效配置
    func testValidateValidConfig() throws {
        let validConfig = ClaudeConfig(
            name: "valid-config",
            env: ClaudeConfig.Environment(
                anthropicAuthToken: "sk-valid-token-12345",
                anthropicBaseURL: "https://api.anthropic.com",
                claudeCodeMaxOutputTokens: "32000",
                claudeCodeDisableNonessentialTraffic: "1"
            ),
            permissions: ClaudeConfig.Permissions(allow: [], deny: []),
            cleanupPeriodDays: 365,
            includeCoAuthoredBy: false
        )
        
        // 验证应该成功
        XCTAssertNoThrow(try configService.validateConfig(validConfig), "有效配置应该通过验证")
    }
    
    /// 测试验证空配置名称
    func testValidateEmptyConfigName() {
        let invalidConfig = ClaudeConfig(
            name: "",
            env: ClaudeConfig.Environment(
                anthropicAuthToken: "sk-valid-token",
                anthropicBaseURL: "https://api.anthropic.com",
                claudeCodeMaxOutputTokens: nil,
                claudeCodeDisableNonessentialTraffic: nil
            )
        )
        
        XCTAssertThrowsError(try configService.validateConfig(invalidConfig)) { error in
            guard case ConfigManagerError.configInvalid(let message) = error else {
                XCTFail("应该抛出 configInvalid 错误")
                return
            }
            XCTAssertTrue(message.contains("配置名称不能为空"), "错误消息应该指出配置名称为空")
        }
    }
    
    /// 测试验证配置名称格式
    func testValidateConfigNameFormat() {
        let invalidNames = ["config@name", "config name", "config/name", "config\\name"]
        
        for invalidName in invalidNames {
            let invalidConfig = ClaudeConfig(
                name: invalidName,
                env: ClaudeConfig.Environment(
                    anthropicAuthToken: "sk-valid-token",
                    anthropicBaseURL: "https://api.anthropic.com",
                    claudeCodeMaxOutputTokens: nil,
                    claudeCodeDisableNonessentialTraffic: nil
                )
            )
            
            XCTAssertThrowsError(try configService.validateConfig(invalidConfig)) { error in
                guard case ConfigManagerError.configInvalid(let message) = error else {
                    XCTFail("应该抛出 configInvalid 错误")
                    return
                }
                XCTAssertTrue(message.contains("配置名称只能包含"), "错误消息应该指出配置名称格式问题")
            }
        }
    }
    
    /// 测试验证空 Token
    func testValidateEmptyToken() {
        let invalidConfig = ClaudeConfig(
            name: "valid-name",
            env: ClaudeConfig.Environment(
                anthropicAuthToken: "",
                anthropicBaseURL: "https://api.anthropic.com",
                claudeCodeMaxOutputTokens: nil,
                claudeCodeDisableNonessentialTraffic: nil
            )
        )
        
        XCTAssertThrowsError(try configService.validateConfig(invalidConfig)) { error in
            guard case ConfigManagerError.configInvalid(let message) = error else {
                XCTFail("应该抛出 configInvalid 错误")
                return
            }
            XCTAssertTrue(message.contains("API Token 不能为空"), "错误消息应该指出 Token 为空")
        }
    }
    
    /// 测试验证 nil Token
    func testValidateNilToken() {
        let invalidConfig = ClaudeConfig(
            name: "valid-name",
            env: ClaudeConfig.Environment(
                anthropicAuthToken: nil,
                anthropicBaseURL: "https://api.anthropic.com",
                claudeCodeMaxOutputTokens: nil,
                claudeCodeDisableNonessentialTraffic: nil
            )
        )
        
        XCTAssertThrowsError(try configService.validateConfig(invalidConfig)) { error in
            guard case ConfigManagerError.configInvalid(let message) = error else {
                XCTFail("应该抛出 configInvalid 错误")
                return
            }
            XCTAssertTrue(message.contains("API Token 不能为空"), "错误消息应该指出 Token 为空")
        }
    }
    
    /// 测试验证 Token 格式
    func testValidateTokenFormat() {
        let invalidTokens = ["invalid-token", "ak-wrong-prefix", "token-without-prefix"]
        
        for invalidToken in invalidTokens {
            let invalidConfig = ClaudeConfig(
                name: "valid-name",
                env: ClaudeConfig.Environment(
                    anthropicAuthToken: invalidToken,
                    anthropicBaseURL: "https://api.anthropic.com",
                    claudeCodeMaxOutputTokens: nil,
                    claudeCodeDisableNonessentialTraffic: nil
                )
            )
            
            XCTAssertThrowsError(try configService.validateConfig(invalidConfig)) { error in
                guard case ConfigManagerError.configInvalid(let message) = error else {
                    XCTFail("应该抛出 configInvalid 错误")
                    return
                }
                XCTAssertTrue(message.contains("API Token 格式无效"), "错误消息应该指出 Token 格式问题")
            }
        }
    }
    
    /// 测试验证无效 Base URL
    func testValidateInvalidBaseURL() {
        let invalidConfig = ClaudeConfig(
            name: "valid-name",
            env: ClaudeConfig.Environment(
                anthropicAuthToken: "sk-valid-token",
                anthropicBaseURL: "invalid-url",
                claudeCodeMaxOutputTokens: nil,
                claudeCodeDisableNonessentialTraffic: nil
            )
        )
        
        XCTAssertThrowsError(try configService.validateConfig(invalidConfig)) { error in
            guard case ConfigManagerError.configInvalid(let message) = error else {
                XCTFail("应该抛出 configInvalid 错误")
                return
            }
            XCTAssertTrue(message.contains("Base URL 格式无效"), "错误消息应该指出 URL 格式问题")
        }
    }
    
    /// 测试验证无效的最大 Token 数
    func testValidateInvalidMaxTokens() {
        let invalidMaxTokens = ["abc", "-100", "0"]
        
        for invalidToken in invalidMaxTokens {
            let invalidConfig = ClaudeConfig(
                name: "valid-name",
                env: ClaudeConfig.Environment(
                    anthropicAuthToken: "sk-valid-token",
                    anthropicBaseURL: "https://api.anthropic.com",
                    claudeCodeMaxOutputTokens: invalidToken,
                    claudeCodeDisableNonessentialTraffic: nil
                )
            )
            
            XCTAssertThrowsError(try configService.validateConfig(invalidConfig)) { error in
                guard case ConfigManagerError.configInvalid(let message) = error else {
                    XCTFail("应该抛出 configInvalid 错误")
                    return
                }
                XCTAssertTrue(message.contains("最大输出 Token 数必须是正整数"), "错误消息应该指出 Token 数格式问题")
            }
        }
    }
    
    /// 测试验证无效的清理周期
    func testValidateInvalidCleanupPeriod() {
        let invalidConfig = ClaudeConfig(
            name: "valid-name",
            env: ClaudeConfig.Environment(
                anthropicAuthToken: "sk-valid-token",
                anthropicBaseURL: "https://api.anthropic.com",
                claudeCodeMaxOutputTokens: nil,
                claudeCodeDisableNonessentialTraffic: nil
            ),
            permissions: nil,
            cleanupPeriodDays: -1,
            includeCoAuthoredBy: nil
        )
        
        XCTAssertThrowsError(try configService.validateConfig(invalidConfig)) { error in
            guard case ConfigManagerError.configInvalid(let message) = error else {
                XCTFail("应该抛出 configInvalid 错误")
                return
            }
            XCTAssertTrue(message.contains("清理周期天数必须是正整数"), "错误消息应该指出清理周期格式问题")
        }
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    /// 测试配置目录不存在时的行为
    func testLoadConfigsFromNonexistentDirectory() async throws {
        // 创建一个不存在的目录路径
        let nonexistentDirectory = tempDirectory.appendingPathComponent("nonexistent")
        let nonexistentConfigService = ConfigService(
            configDirectory: nonexistentDirectory,
            keychainService: mockKeychainService
        )
        
        let configs = try await nonexistentConfigService.loadConfigs()
        XCTAssertTrue(configs.isEmpty, "不存在的目录应该返回空配置列表")
    }
    
    /// 测试处理损坏的 JSON 文件
    func testLoadConfigsWithCorruptedJSON() async throws {
        // 创建损坏的 JSON 文件
        let corruptedFile = tempDirectory.appendingPathComponent("corrupted-settings.json")
        try "{ invalid json content".write(to: corruptedFile, atomically: true, encoding: .utf8)
        
        // 创建有效的配置文件
        try createTestConfigFile(name: "valid", data: createTestConfigData())
        
        let configs = try await configService.loadConfigs()
        
        // 应该只加载有效的配置，忽略损坏的文件
        XCTAssertEqual(configs.count, 1, "应该忽略损坏的文件，只加载有效配置")
        XCTAssertEqual(configs.first?.name, "valid")
    }
    
    /// 测试处理空 JSON 文件
    func testLoadConfigsWithEmptyJSON() async throws {
        // 创建空 JSON 文件
        let emptyFile = tempDirectory.appendingPathComponent("empty-settings.json")
        try "".write(to: emptyFile, atomically: true, encoding: .utf8)
        
        let configs = try await configService.loadConfigs()
        XCTAssertTrue(configs.isEmpty, "空文件应该被忽略")
    }
    
    /// 测试处理权限不足的文件
    func testHandleFilePermissionErrors() async throws {
        // 创建配置文件
        try createTestConfigFile(name: "permission", data: createTestConfigData())
        
        // 改变文件权限为不可读（仅在支持的文件系统上）
        let configFile = tempDirectory.appendingPathComponent("permission-settings.json")
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: configFile.path)
            
            let configs = try await configService.loadConfigs()
            
            // 恢复权限以便清理
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: configFile.path)
            
            // 权限不足的文件应该被跳过
            XCTAssertTrue(configs.isEmpty, "权限不足的文件应该被跳过")
        } catch {
            // 如果无法设置权限（比如在某些文件系统上），跳过这个测试
            throw XCTSkip("无法设置文件权限进行测试")
        }
    }
    
    /// 测试并发配置加载
    func testConcurrentConfigLoading() async throws {
        // 创建多个测试配置
        for i in 1...5 {
            try createTestConfigFile(name: "concurrent\(i)", data: createTestConfigData())
        }
        
        // 并发加载配置
        async let configs1 = configService.loadConfigs()
        async let configs2 = configService.loadConfigs()
        async let configs3 = configService.loadConfigs()
        
        let results = try await [configs1, configs2, configs3]
        
        // 所有结果应该一致
        XCTAssertEqual(results[0].count, results[1].count, "并发加载结果应该一致")
        XCTAssertEqual(results[1].count, results[2].count, "并发加载结果应该一致")
        XCTAssertEqual(results[0].count, 5, "应该加载所有配置")
    }
    
    /// 测试超大配置文件处理
    func testHandleLargeConfigFile() async throws {
        // 创建一个大的权限列表
        let largePermissions = ClaudeConfig.Permissions(
            allow: Array(0..<1000).map { "path/\($0)" },
            deny: Array(1000..<2000).map { "path/\($0)" }
        )
        
        let largeConfigData = ConfigData(
            env: ClaudeConfig.Environment(
                anthropicAuthToken: "sk-large-config-token",
                anthropicBaseURL: "https://api.anthropic.com",
                claudeCodeMaxOutputTokens: "100000",
                claudeCodeDisableNonessentialTraffic: "1"
            ),
            permissions: largePermissions,
            cleanupPeriodDays: 365,
            includeCoAuthoredBy: false
        )
        
        try createTestConfigFile(name: "large", data: largeConfigData)
        
        let configs = try await configService.loadConfigs()
        
        XCTAssertEqual(configs.count, 1, "应该能处理大配置文件")
        XCTAssertEqual(configs.first?.permissions?.allow.count, 1000, "权限列表应该完整")
    }
    
    /// 测试配置文件名边界情况
    func testConfigFileNameEdgeCases() async throws {
        let edgeCaseNames = [
            "a", // 单字符
            String(repeating: "a", count: 100), // 长名称
            "config-with-many-dashes",
            "config_with_underscores",
            "123numeric",
            "MixedCase"
        ]
        
        for name in edgeCaseNames {
            try createTestConfigFile(name: name, data: createTestConfigData())
        }
        
        let configs = try await configService.loadConfigs()
        
        XCTAssertEqual(configs.count, edgeCaseNames.count, "应该处理所有边界情况的配置名")
        
        let loadedNames = configs.map { $0.name }.sorted()
        let expectedNames = edgeCaseNames.sorted()
        XCTAssertEqual(loadedNames, expectedNames, "配置名应该正确解析")
    }
    
    // MARK: - Performance Tests
    
    /// 测试加载大量配置的性能
    func testLoadManyConfigsPerformance() throws {
        let configCount = 50
        
        // 创建大量配置文件
        for i in 1...configCount {
            let configData = createTestConfigData()
            try createTestConfigFile(name: "perf\(i)", data: configData)
        }
        
        // 性能测试
        measure {
            let expectation = XCTestExpectation(description: "配置加载完成")
            
            Task {
                do {
                    let configs = try await configService.loadConfigs()
                    XCTAssertEqual(configs.count, configCount, "应该加载所有配置")
                    expectation.fulfill()
                } catch {
                    XCTFail("加载配置失败: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    private func createTestConfigData() -> ConfigData {
        return ConfigData(
            env: ClaudeConfig.Environment(
                anthropicAuthToken: "sk-test-token",
                anthropicBaseURL: "https://api.anthropic.com",
                claudeCodeMaxOutputTokens: "32000",
                claudeCodeDisableNonessentialTraffic: "1"
            ),
            permissions: ClaudeConfig.Permissions(allow: [], deny: []),
            cleanupPeriodDays: 365,
            includeCoAuthoredBy: false
        )
    }
    
    private func createTestConfigFile(name: String, data: ConfigData) throws {
        let configFile = tempDirectory.appendingPathComponent("\(name)-settings.json")
        let jsonData = try JSONEncoder().encode(data)
        try jsonData.write(to: configFile)
    }
}

// MARK: - Mock Classes

/// Mock KeychainService for testing
class MockKeychainService: KeychainService {
    var mockTokens: [String: String] = [:]
    var deletedConfigs: Set<String> = []
    var shouldThrowError = false
    var errorToThrow: Error?
    
    override func store(token: String, for configName: String) throws {
        if shouldThrowError {
            throw errorToThrow ?? KeychainError.unexpectedError(-1)
        }
        mockTokens[configName] = token
    }
    
    override func retrieve(for configName: String) throws -> String? {
        if shouldThrowError {
            throw errorToThrow ?? KeychainError.unexpectedError(-1)
        }
        return mockTokens[configName]
    }
    
    override func update(token: String, for configName: String) throws {
        if shouldThrowError {
            throw errorToThrow ?? KeychainError.unexpectedError(-1)
        }
        mockTokens[configName] = token
    }
    
    override func delete(for configName: String) -> Bool {
        deletedConfigs.insert(configName)
        mockTokens.removeValue(forKey: configName)
        return true
    }
    
    override func listStoredConfigs() -> [String] {
        return Array(mockTokens.keys).sorted()
    }
    
    override func clearAll() -> Bool {
        mockTokens.removeAll()
        deletedConfigs.removeAll()
        return true
    }
}