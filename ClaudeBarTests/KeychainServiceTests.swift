import XCTest
@testable import ClaudeBar

/// KeychainService 单元测试类
///
/// 测试 KeychainService 的核心功能，包括：
/// - Token 存储和检索
/// - Token 更新和删除
/// - 错误处理和边界情况
/// - 配置列表管理
final class KeychainServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var keychainService: KeychainService!
    let testService = "com.claude.configmanager.test"
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        super.setUp()
        keychainService = KeychainService()
        
        // 清理测试环境
        _ = keychainService.clearAll()
    }
    
    override func tearDownWithError() throws {
        // 清理测试数据
        _ = keychainService.clearAll()
        keychainService = nil
        super.tearDown()
    }
    
    // MARK: - Store Token Tests
    
    /// 测试存储新 Token
    func testStoreNewToken() throws {
        let configName = "test-config"
        let token = "sk-test-token-12345"
        
        // 存储 Token
        try keychainService.store(token: token, for: configName)
        
        // 验证存储成功
        let retrievedToken = try keychainService.retrieve(for: configName)
        XCTAssertEqual(retrievedToken, token, "存储的 Token 应该能被正确检索")
    }
    
    /// 测试存储空 Token
    func testStoreEmptyToken() throws {
        let configName = "test-config"
        let emptyToken = ""
        
        // 存储空 Token
        try keychainService.store(token: emptyToken, for: configName)
        
        // 验证可以存储空字符串
        let retrievedToken = try keychainService.retrieve(for: configName)
        XCTAssertEqual(retrievedToken, emptyToken, "应该能存储空字符串")
    }
    
    /// 测试存储长 Token
    func testStoreLongToken() throws {
        let configName = "test-config"
        let longToken = String(repeating: "a", count: 1000) // 1000 字符长的 Token
        
        // 存储长 Token
        try keychainService.store(token: longToken, for: configName)
        
        // 验证存储成功
        let retrievedToken = try keychainService.retrieve(for: configName)
        XCTAssertEqual(retrievedToken, longToken, "应该能存储长 Token")
    }
    
    /// 测试存储特殊字符 Token
    func testStoreTokenWithSpecialCharacters() throws {
        let configName = "test-config"
        let specialToken = "sk-test@#$%^&*()_+-={}[]|\\:;\"'<>,.?/~`"
        
        // 存储包含特殊字符的 Token
        try keychainService.store(token: specialToken, for: configName)
        
        // 验证存储成功
        let retrievedToken = try keychainService.retrieve(for: configName)
        XCTAssertEqual(retrievedToken, specialToken, "应该能存储包含特殊字符的 Token")
    }
    
    // MARK: - Retrieve Token Tests
    
    /// 测试检索不存在的 Token
    func testRetrieveNonexistentToken() throws {
        let configName = "nonexistent-config"
        
        let retrievedToken = try keychainService.retrieve(for: configName)
        XCTAssertNil(retrievedToken, "不存在的配置应该返回 nil")
    }
    
    /// 测试检索已存在的 Token
    func testRetrieveExistingToken() throws {
        let configName = "existing-config"
        let token = "sk-existing-token"
        
        // 先存储 Token
        try keychainService.store(token: token, for: configName)
        
        // 检索 Token
        let retrievedToken = try keychainService.retrieve(for: configName)
        XCTAssertEqual(retrievedToken, token, "应该能检索已存储的 Token")
    }
    
    /// 测试检索多个不同配置的 Token
    func testRetrieveMultipleTokens() throws {
        let configs = [
            ("config1", "sk-token-1"),
            ("config2", "sk-token-2"),
            ("config3", "sk-token-3")
        ]
        
        // 存储多个 Token
        for (configName, token) in configs {
            try keychainService.store(token: token, for: configName)
        }
        
        // 验证每个 Token 都能正确检索
        for (configName, expectedToken) in configs {
            let retrievedToken = try keychainService.retrieve(for: configName)
            XCTAssertEqual(retrievedToken, expectedToken, "配置 \(configName) 的 Token 应该匹配")
        }
    }
    
    // MARK: - Update Token Tests
    
    /// 测试更新已存在的 Token
    func testUpdateExistingToken() throws {
        let configName = "update-config"
        let originalToken = "sk-original-token"
        let updatedToken = "sk-updated-token"
        
        // 存储原始 Token
        try keychainService.store(token: originalToken, for: configName)
        
        // 更新 Token
        try keychainService.update(token: updatedToken, for: configName)
        
        // 验证更新成功
        let retrievedToken = try keychainService.retrieve(for: configName)
        XCTAssertEqual(retrievedToken, updatedToken, "Token 应该被正确更新")
    }
    
    /// 测试更新不存在的 Token（应该创建新的）
    func testUpdateNonexistentToken() throws {
        let configName = "new-config"
        let token = "sk-new-token"
        
        // 更新不存在的 Token
        try keychainService.update(token: token, for: configName)
        
        // 验证创建成功
        let retrievedToken = try keychainService.retrieve(for: configName)
        XCTAssertEqual(retrievedToken, token, "不存在的 Token 更新应该创建新项目")
    }
    
    // MARK: - Delete Token Tests
    
    /// 测试删除已存在的 Token
    func testDeleteExistingToken() throws {
        let configName = "delete-config"
        let token = "sk-delete-token"
        
        // 存储 Token
        try keychainService.store(token: token, for: configName)
        
        // 删除 Token
        let deleteResult = keychainService.delete(for: configName)
        XCTAssertTrue(deleteResult, "删除操作应该成功")
        
        // 验证删除成功
        let retrievedToken = try keychainService.retrieve(for: configName)
        XCTAssertNil(retrievedToken, "删除后应该无法检索到 Token")
    }
    
    /// 测试删除不存在的 Token
    func testDeleteNonexistentToken() {
        let configName = "nonexistent-config"
        
        // 删除不存在的 Token
        let deleteResult = keychainService.delete(for: configName)
        XCTAssertTrue(deleteResult, "删除不存在的项目应该返回 true")
    }
    
    /// 测试多次删除同一个 Token
    func testDeleteTokenMultipleTimes() throws {
        let configName = "multi-delete-config"
        let token = "sk-multi-delete-token"
        
        // 存储 Token
        try keychainService.store(token: token, for: configName)
        
        // 第一次删除
        let firstDelete = keychainService.delete(for: configName)
        XCTAssertTrue(firstDelete, "第一次删除应该成功")
        
        // 第二次删除
        let secondDelete = keychainService.delete(for: configName)
        XCTAssertTrue(secondDelete, "第二次删除应该也返回成功")
    }
    
    // MARK: - List Stored Configs Tests
    
    /// 测试列出空的配置列表
    func testListEmptyConfigs() {
        let configs = keychainService.listStoredConfigs()
        XCTAssertTrue(configs.isEmpty, "空的 Keychain 应该返回空配置列表")
    }
    
    /// 测试列出单个配置
    func testListSingleConfig() throws {
        let configName = "single-config"
        let token = "sk-single-token"
        
        try keychainService.store(token: token, for: configName)
        
        let configs = keychainService.listStoredConfigs()
        XCTAssertEqual(configs.count, 1, "应该列出一个配置")
        XCTAssertEqual(configs.first, configName, "配置名称应该匹配")
    }
    
    /// 测试列出多个配置并验证排序
    func testListMultipleConfigsSorted() throws {
        let configNames = ["zebra", "alpha", "beta", "gamma"]
        
        // 存储多个配置（乱序）
        for configName in configNames.shuffled() {
            try keychainService.store(token: "sk-token", for: configName)
        }
        
        let configs = keychainService.listStoredConfigs()
        XCTAssertEqual(configs.count, configNames.count, "应该列出所有配置")
        XCTAssertEqual(configs, configNames.sorted(), "配置应该按字母顺序排序")
    }
    
    /// 测试列出配置后删除部分配置
    func testListConfigsAfterPartialDeletion() throws {
        let allConfigs = ["config1", "config2", "config3"]
        let remainingConfigs = ["config1", "config3"]
        
        // 存储所有配置
        for configName in allConfigs {
            try keychainService.store(token: "sk-token", for: configName)
        }
        
        // 删除部分配置
        _ = keychainService.delete(for: "config2")
        
        let configs = keychainService.listStoredConfigs()
        XCTAssertEqual(configs.count, remainingConfigs.count, "应该列出剩余配置")
        XCTAssertEqual(Set(configs), Set(remainingConfigs), "配置列表应该匹配")
    }
    
    // MARK: - Clear All Tests
    
    /// 测试清空所有配置
    func testClearAll() throws {
        // 存储多个配置
        let configNames = ["config1", "config2", "config3"]
        for configName in configNames {
            try keychainService.store(token: "sk-token", for: configName)
        }
        
        // 清空所有配置
        let clearResult = keychainService.clearAll()
        XCTAssertTrue(clearResult, "清空操作应该成功")
        
        // 验证清空成功
        let configs = keychainService.listStoredConfigs()
        XCTAssertTrue(configs.isEmpty, "清空后配置列表应该为空")
    }
    
    /// 测试清空空的 Keychain
    func testClearEmptyKeychain() {
        let clearResult = keychainService.clearAll()
        XCTAssertTrue(clearResult, "清空空的 Keychain 应该成功")
    }
    
    // MARK: - Configuration Name Edge Cases
    
    /// 测试特殊字符配置名称
    func testConfigNameWithSpecialCharacters() throws {
        let configNames = [
            "config-with-dashes",
            "config_with_underscores",
            "config.with.dots",
            "config@with@at",
            "config with spaces"
        ]
        
        for configName in configNames {
            let token = "sk-token-for-\(configName)"
            
            // 存储 Token
            try keychainService.store(token: token, for: configName)
            
            // 验证检索成功
            let retrievedToken = try keychainService.retrieve(for: configName)
            XCTAssertEqual(retrievedToken, token, "特殊字符配置名 '\(configName)' 应该正常工作")
        }
    }
    
    /// 测试长配置名称
    func testLongConfigName() throws {
        let longConfigName = String(repeating: "a", count: 100) // 100 字符长的配置名
        let token = "sk-long-config-token"
        
        try keychainService.store(token: token, for: longConfigName)
        
        let retrievedToken = try keychainService.retrieve(for: longConfigName)
        XCTAssertEqual(retrievedToken, token, "长配置名应该正常工作")
    }
    
    /// 测试空配置名称
    func testEmptyConfigName() throws {
        let emptyConfigName = ""
        let token = "sk-empty-config-token"
        
        try keychainService.store(token: token, for: emptyConfigName)
        
        let retrievedToken = try keychainService.retrieve(for: emptyConfigName)
        XCTAssertEqual(retrievedToken, token, "空配置名应该能正常存储")
    }
    
    // MARK: - Stress Tests
    
    /// 测试大量配置的性能
    func testPerformanceWithManyConfigs() throws {
        let configCount = 100
        
        // 性能测试：存储
        measure {
            for i in 0..<configCount {
                do {
                    try keychainService.store(token: "sk-token-\(i)", for: "config-\(i)")
                } catch {
                    XCTFail("存储配置 \(i) 失败: \(error)")
                }
            }
        }
        
        // 验证所有配置都存储成功
        let configs = keychainService.listStoredConfigs()
        XCTAssertEqual(configs.count, configCount, "应该存储所有配置")
    }
    
    /// 测试重复存储和删除操作
    func testRepeatedStoreAndDelete() throws {
        let configName = "repeated-config"
        let iterations = 50
        
        for i in 0..<iterations {
            let token = "sk-token-\(i)"
            
            // 存储
            try keychainService.store(token: token, for: configName)
            
            // 验证存储
            let retrievedToken = try keychainService.retrieve(for: configName)
            XCTAssertEqual(retrievedToken, token, "第 \(i) 次存储应该成功")
            
            // 删除
            let deleteResult = keychainService.delete(for: configName)
            XCTAssertTrue(deleteResult, "第 \(i) 次删除应该成功")
            
            // 验证删除
            let deletedToken = try keychainService.retrieve(for: configName)
            XCTAssertNil(deletedToken, "第 \(i) 次删除后应该无法检索到 Token")
        }
    }
}