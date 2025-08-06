import Foundation
import AppKit

/// 配置服务协议
///
/// 定义配置管理的核心接口，包括配置的加载、切换、创建和删除功能
protocol ConfigServiceProtocol {
    /// 异步加载所有可用配置
    /// - Returns: 配置数组，按名称排序
    /// - Throws: 配置加载过程中的错误
    func loadConfigs() async throws -> [ClaudeConfig]
    
    /// 切换到指定配置
    /// - Parameter config: 要切换到的配置
    /// - Throws: 配置切换过程中的错误
    func switchConfig(_ config: ClaudeConfig) async throws
    
    /// 创建新配置
    /// - Parameter config: 要创建的配置
    /// - Throws: 配置创建过程中的错误
    func createConfig(_ config: ClaudeConfig) async throws
    
    /// 删除指定配置
    /// - Parameter config: 要删除的配置
    /// - Throws: 配置删除过程中的错误
    func deleteConfig(_ config: ClaudeConfig) async throws
    
    /// 获取当前活动的配置
    /// - Returns: 当前配置，如果没有则返回 nil
    func getCurrentConfig() -> ClaudeConfig?
    
    /// 验证配置的有效性
    /// - Parameter config: 要验证的配置
    /// - Throws: 配置验证失败时的错误
    func validateConfig(_ config: ClaudeConfig) throws
}

/// 配置服务实现
///
/// 提供 Claude 配置管理的核心功能，包括配置文件的读写和配置验证
class ConfigService: ConfigServiceProtocol {
    private let fileManager: FileManager
    private let configDirectory: URL
    private let activeConfigFile: URL
    
    /// 获取当前配置目录路径
    var configDirectoryPath: String {
        return configDirectory.path
    }
    
    /// 默认初始化器，使用系统默认配置
    convenience init() {
        let fileManager = FileManager.default
        let configDirectory = Self.getClaudeConfigDirectory()
        
        self.init(
            fileManager: fileManager,
            configDirectory: configDirectory
        )
    }
    
    /// 使用指定配置目录的便利初始化器
    convenience init(configDirectory: URL) {
        self.init(
            fileManager: FileManager.default,
            configDirectory: configDirectory
        )
    }
    
    /// 请求访问 ~/.claude 目录的权限
    @MainActor
    static func requestClaudeDirectoryAccess() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.title = "授权访问 Claude 目录"
        openPanel.message = "应用需要访问 ~/.claude 目录来读取当前配置\n请选择您的 .claude 目录"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.showsHiddenFiles = true
        
        // 导航到用户家目录
        let homeDirectory = getRealHomeDirectory()
        openPanel.directoryURL = homeDirectory
        
        let response = openPanel.runModal()
        if response == .OK, let url = openPanel.url {
            // 保存书签以便后续访问
            if let bookmarkData = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(bookmarkData, forKey: "claudeDirectoryBookmark")
                print("已保存 Claude 目录书签: \(url.path)")
            }
            return url
        }
        
        return nil
    }
    
    /// 恢复对 ~/.claude 目录的访问权限
    private static func restoreClaudeDirectoryAccess() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "claudeDirectoryBookmark") else {
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("Claude 目录书签已过期")
                return nil
            }
            
            guard url.startAccessingSecurityScopedResource() else {
                print("无法访问安全范围资源: \(url.path)")
                return nil
            }
            
            print("成功恢复 Claude 目录访问权限: \(url.path)")
            return url
        } catch {
            print("恢复 Claude 目录书签失败: \(error)")
            return nil
        }
    }
    @MainActor
    static func requestConfigDirectoryAccess() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择 Claude 配置目录"
        openPanel.message = "请选择包含 Claude 配置文件的目录\n提示：按 Cmd+Shift+. 可显示隐藏文件夹"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.showsHiddenFiles = true  // 显示隐藏文件和文件夹
        
        // 尝试导航到用户家目录
        let homeDirectory = getRealHomeDirectory()
        openPanel.directoryURL = homeDirectory
        
        let response = openPanel.runModal()
        if response == .OK, let url = openPanel.url {
            // 保存书签以便后续访问
            if let bookmarkData = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(bookmarkData, forKey: "claudeConfigDirectoryBookmark")
                print("已保存配置目录书签: \(url.path)")
            }
            return url
        }
        
        return nil
    }
    
    /// 检查并确保有配置目录访问权限
    @MainActor
    static func ensureConfigDirectoryAccess() -> Bool {
        // 首先尝试恢复已保存的权限
        if let _ = restoreConfigDirectoryAccess() {
            return true
        }
        
        // 如果没有权限，请求用户授权
        if let _ = requestConfigDirectoryAccess() {
            return true
        }
        
        return false
    }
    
    /// 从书签恢复配置目录访问权限
    static func restoreConfigDirectoryAccess() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "claudeConfigDirectoryBookmark") else {
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                print("配置目录书签已过期，需要重新选择")
                return nil
            }
            
            // 开始访问安全作用域资源
            if url.startAccessingSecurityScopedResource() {
                print("成功恢复配置目录访问权限: \(url.path)")
                return url
            } else {
                print("无法访问安全作用域资源")
                return nil
            }
        } catch {
            print("恢复配置目录书签失败: \(error)")
            return nil
        }
    }
    
    /// 获取真实的用户家目录（绕过沙盒限制）
    private static func getRealHomeDirectory() -> URL {
        // 方法1: 直接从用户名构建路径
        let username = NSUserName()
        let realHomePath = "/Users/\(username)"
        
        print("用户名: \(username)")
        print("构建的真实家目录: \(realHomePath)")
        
        // 验证路径是否存在
        if FileManager.default.fileExists(atPath: realHomePath) {
            print("使用真实家目录: \(realHomePath)")
            return URL(fileURLWithPath: realHomePath)
        }
        
        // 方法2: 尝试使用环境变量 HOME
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            print("使用环境变量 HOME: \(homeDir)")
            return URL(fileURLWithPath: homeDir)
        }
        
        // 方法3: 使用 NSHomeDirectory() 作为最后备选
        let homeDir = NSHomeDirectory()
        print("使用 NSHomeDirectory: \(homeDir)")
        
        // 如果是沙盒路径，尝试解析出真实路径
        if homeDir.contains("/Containers/") {
            // 沙盒路径格式: /Users/username/Library/Containers/bundleId/Data
            // 我们需要提取出 /Users/username 部分
            let components = homeDir.components(separatedBy: "/")
            if let userIndex = components.firstIndex(of: "Users"),
               userIndex + 1 < components.count {
                let extractedUsername = components[userIndex + 1]
                let realHome = "/Users/\(extractedUsername)"
                print("从沙盒路径解析出真实家目录: \(realHome)")
                return URL(fileURLWithPath: realHome)
            }
        }
        
        return URL(fileURLWithPath: homeDir)
    }
    
    /// 获取 Claude 配置目录
    private static func getClaudeConfigDirectory() -> URL {
        // 首先尝试从书签恢复访问权限
        if let authorizedURL = restoreConfigDirectoryAccess() {
            print("使用已授权的配置目录: \(authorizedURL.path)")
            return authorizedURL
        }
        
        // 如果没有保存的权限，尝试直接访问 ~/.claude/config
        let homeDirectory = getRealHomeDirectory()
        let configDirectory = homeDirectory.appendingPathComponent(".claude").appendingPathComponent("config")
        
        // 检查是否能直接访问（可能在非沙盒环境或有权限时）
        if FileManager.default.fileExists(atPath: configDirectory.path) {
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: configDirectory.path)
                print("直接访问配置目录成功: \(configDirectory.path)")
                return configDirectory
            } catch {
                print("无法直接访问配置目录: \(error)")
            }
        }
        
        print("等待用户选择配置目录，临时路径: \(configDirectory.path)")
        return configDirectory
    }
    
    /// 依赖注入初始化器，用于测试和自定义配置
    /// - Parameters:
    ///   - fileManager: 文件管理器实例
    ///   - configDirectory: 配置目录路径
    init(fileManager: FileManager = FileManager.default,
         configDirectory: URL) {
        self.fileManager = fileManager
        self.configDirectory = configDirectory
        
        // 当前配置文件应与配置目录在同一权限范围内
        // 如果配置目录在用户选择的路径下，则使用该路径的父目录作为 Claude 目录
        if configDirectory.lastPathComponent == "config" {
            // 配置目录是 ~/.claude/config，所以 activeConfigFile 应该在 ~/.claude/settings.json
            self.activeConfigFile = configDirectory.deletingLastPathComponent().appendingPathComponent("settings.json")
        } else {
            // 配置目录直接是 ~/.claude，所以 activeConfigFile 在 ~/.claude/settings.json
            self.activeConfigFile = configDirectory.appendingPathComponent("settings.json")
        }
        
        print("配置目录: \(configDirectory.path)")
        print("当前配置文件: \(activeConfigFile.path)")
    }
    
    /// 异步加载所有配置文件
    ///
    /// 扫描配置目录中的所有 *-settings.json 文件，解析配置内容
    ///
    /// - Returns: 按名称排序的配置数组
    /// - Throws: `ConfigManagerError` 当配置目录不可访问时
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
    
    private func loadConfigsSync() throws -> [ClaudeConfig] {
        print("开始加载配置文件")
        
        // 检查配置目录是否存在以及是否有访问权限
        if !fileManager.fileExists(atPath: configDirectory.path) {
            print("配置目录不存在: \(configDirectory.path)")
            // 如果配置目录不存在，且没有保存的书签，请求用户选择目录
            if UserDefaults.standard.data(forKey: "claudeConfigDirectoryBookmark") == nil {
                throw ConfigManagerError.permissionDenied("需要选择配置目录")
            }
            return []
        }
        
        // 尝试访问目录以检查权限
        do {
            _ = try fileManager.contentsOfDirectory(at: configDirectory, 
                                                 includingPropertiesForKeys: nil, 
                                                 options: [.skipsHiddenFiles])
        } catch {
            // 如果访问失败，可能是权限问题
            if (error as NSError).code == 257 { // Permission denied
                print("配置目录访问权限不足，需要用户授权")
                throw ConfigManagerError.permissionDenied(configDirectory.path)
            } else {
                throw error
            }
        }
        
        var configs: [ClaudeConfig] = []
        let contents = try fileManager.contentsOfDirectory(at: configDirectory, 
                                                         includingPropertiesForKeys: nil, 
                                                         options: [.skipsHiddenFiles])
        
        print("找到 \(contents.count) 个文件")
        
        for fileURL in contents {
            let fileName = fileURL.lastPathComponent
            // 查找所有 *-settings.json 文件
            if fileName.hasSuffix("-settings.json") && fileName != "settings.json" {
                let configName = String(fileName.dropLast("-settings.json".count))
                
                print("正在解析配置文件: \(fileName)")
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    let configData = try JSONDecoder().decode(ConfigData.self, from: data)
                    
                    let config = ClaudeConfig(name: configName, configData: configData)
                    configs.append(config)
                    print("成功加载配置: \(configName)")
                } catch {
                    print("解析配置文件 \(fileName) 失败: \(error)")
                }
            }
        }
        
        print("成功加载 \(configs.count) 个配置")
        return configs.sorted { $0.name < $1.name }
    }
    
    /// 异步切换到指定配置
    ///
    /// 将指定配置设置为当前活动配置，写入到 settings.json 文件
    ///
    /// - Parameter config: 要切换到的配置
    /// - Throws: `ConfigManagerError.configNotFound` 当配置文件不存在时
    ///           `ConfigManagerError.fileOperationFailed` 当文件写入失败时
    func switchConfig(_ config: ClaudeConfig) async throws {
        // 简化为直接的异步操作，不使用复杂的超时机制
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // 验证配置
                    try self.validateConfig(config)
                    try self.switchConfigSync(config)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 检查并报告权限状态
    private func checkPermissionStatus() {
        print("=== 权限状态检查 ===")
        
        // 检查配置目录权限
        if let bookmarkData = UserDefaults.standard.data(forKey: "claudeConfigDirectoryBookmark") {
            print("✓ 配置目录权限书签存在")
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                print("  - 配置目录路径: \(url.path)")
                print("  - 书签状态: \(isStale ? "已过期" : "有效")")
            } catch {
                print("  - 书签解析失败: \(error)")
            }
        } else {
            print("✗ 配置目录权限书签不存在")
        }
        
        // 检查 Claude 目录权限
        if let bookmarkData = UserDefaults.standard.data(forKey: "claudeDirectoryBookmark") {
            print("✓ Claude 目录权限书签存在")
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                print("  - Claude 目录路径: \(url.path)")
                print("  - 书签状态: \(isStale ? "已过期" : "有效")")
            } catch {
                print("  - 书签解析失败: \(error)")
            }
        } else {
            print("✗ Claude 目录权限书签不存在")
        }
        
        // 检查文件系统访问
        print("✓ 配置目录: \(configDirectory.path)")
        print("  - 存在: \(fileManager.fileExists(atPath: configDirectory.path) ? "是" : "否")")
        print("✓ 当前配置文件: \(activeConfigFile.path)")
        print("  - 存在: \(fileManager.fileExists(atPath: activeConfigFile.path) ? "是" : "否")")
        
        print("=== 权限状态检查完成 ===")
    }

    /// 安全作用域资源管理器
    private class SecurityScopedResourceManager {
        private var securityScopedURL: URL?
        
        func acquireAccess(for targetFile: URL) -> Bool {
            print("尝试获取安全作用域资源访问权限")
            print("目标文件: \(targetFile.path)")
            
            // 首先尝试从配置目录的权限推断 targetFile 的权限
            if let bookmarkData = UserDefaults.standard.data(forKey: "claudeConfigDirectoryBookmark") {
                if let url = tryAccessWithBookmark(bookmarkData, for: targetFile, description: "配置目录") {
                    securityScopedURL = url
                    print("✓ 成功获取配置目录权限")
                    return true
                }
            }
            
            // 如果配置目录权限不适用，尝试 Claude 目录权限
            if let bookmarkData = UserDefaults.standard.data(forKey: "claudeDirectoryBookmark") {
                if let url = tryAccessWithBookmark(bookmarkData, for: targetFile, description: "Claude 目录") {
                    securityScopedURL = url
                    print("✓ 成功获取 Claude 目录权限")
                    return true
                }
            }
            
            print("✗ 无法获取安全作用域资源访问权限")
            return false
        }
        
        private func tryAccessWithBookmark(_ bookmarkData: Data, for targetFile: URL, description: String) -> URL? {
            do {
                var isStale = false
                let authorizedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    print("✗ \(description)权限书签已过期")
                    return nil
                }
                
                if authorizedURL.startAccessingSecurityScopedResource() {
                    // 确定 targetFile 是否在授权范围内
                    let authorizedPath = authorizedURL.path
                    let targetPath = targetFile.path
                    
                    print("  - 授权路径: \(authorizedPath)")
                    print("  - 目标路径: \(targetPath)")
                    
                    if targetPath.hasPrefix(authorizedPath) || 
                       authorizedPath.hasPrefix(targetFile.deletingLastPathComponent().path) ||
                       targetFile.deletingLastPathComponent().path.hasPrefix(authorizedPath) {
                        print("✓ 使用\(description)权限访问目标文件")
                        return authorizedURL
                    } else {
                        print("✗ 目标文件不在\(description)权限范围内")
                        authorizedURL.stopAccessingSecurityScopedResource()
                    }
                } else {
                    print("✗ 无法启动\(description)安全作用域资源访问")
                }
            } catch {
                print("✗ 恢复\(description)权限失败: \(error)")
            }
            return nil
        }
        
        deinit {
            releaseAccess()
        }
        
        func releaseAccess() {
            if let url = securityScopedURL {
                url.stopAccessingSecurityScopedResource()
                securityScopedURL = nil
                print("✓ 已释放安全作用域资源访问权限")
            }
        }
    }

    private func switchConfigSync(_ config: ClaudeConfig) throws {
        let sourceFile = configDirectory.appendingPathComponent("\(config.name)-settings.json")
        
        // 权限状态检查（调试信息）
        checkPermissionStatus()
        
        guard fileManager.fileExists(atPath: sourceFile.path) else {
            throw ConfigManagerError.configNotFound(config.name)
        }
        
        print("=== 开始切换配置 ===")
        print("配置名称: \(config.name)")
        print("源文件: \(sourceFile.path)")
        print("目标文件: \(activeConfigFile.path)")
        
        // 确保目标目录存在
        let activeConfigDir = activeConfigFile.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: activeConfigDir.path) {
            do {
                try fileManager.createDirectory(at: activeConfigDir, withIntermediateDirectories: true, attributes: nil)
                print("✓ 创建目标目录: \(activeConfigDir.path)")
            } catch {
                print("✗ 创建目标目录失败: \(error)")
                throw ConfigManagerError.fileOperationFailed("无法创建配置目录: \(error.localizedDescription)")
            }
        }
        
        // 使用资源管理器确保权限正确管理
        let resourceManager = SecurityScopedResourceManager()
        let hasAccess = resourceManager.acquireAccess(for: activeConfigFile)
        
        print("权限获取结果: \(hasAccess ? "成功" : "失败")")
        
        // 确保资源管理器在操作完成后释放权限
        defer {
            resourceManager.releaseAccess()
        }
        
        do {
            // 直接读取源配置文件的原始内容
            let sourceData = try Data(contentsOf: sourceFile)
            
            print("准备写入数据大小: \(sourceData.count) 字节")
            
            // 直接将原始内容写入到 settings.json，保持原有格式
            try sourceData.write(to: activeConfigFile)
            print("✓ 成功切换到配置: \(config.name)")
            print("=== 配置切换完成 ===")
            
        } catch {
            print("✗ 写入配置文件失败: \(error)")
            let nsError = error as NSError
            print("错误代码: \(nsError.code)")
            print("错误域: \(nsError.domain)")
            print("错误描述: \(nsError.localizedDescription)")
            
            if nsError.code == 513 || nsError.code == 257 || nsError.code == 1 {
                // 权限错误
                if hasAccess {
                    throw ConfigManagerError.fileOperationFailed("写入配置文件失败，可能需要手动选择访问权限: \(error.localizedDescription)")
                } else {
                    throw ConfigManagerError.permissionDenied("写入当前配置文件时权限不足，请重新授权访问目录: \(activeConfigFile.path)")
                }
            } else {
                throw ConfigManagerError.fileOperationFailed("写入配置文件失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 异步创建新配置
    ///
    /// 创建新的配置文件，包含所有配置信息
    ///
    /// - Parameter config: 要创建的配置
    /// - Throws: `ConfigManagerError.fileOperationFailed` 当配置已存在或创建失败时
    func createConfig(_ config: ClaudeConfig) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // 验证配置
                    try self.validateConfig(config)
                    try self.createConfigSync(config)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func createConfigSync(_ config: ClaudeConfig) throws {
        let configFile = configDirectory.appendingPathComponent("\(config.name)-settings.json")
        
        if fileManager.fileExists(atPath: configFile.path) {
            throw ConfigManagerError.fileOperationFailed("配置 '\(config.name)' 已存在")
        }
        
        // 创建包含 Token 的配置文件
        let configData = ConfigData(
            env: config.env,
            permissions: config.permissions,
            cleanupPeriodDays: config.cleanupPeriodDays,
            includeCoAuthoredBy: config.includeCoAuthoredBy
        )
        
        let data = try JSONEncoder().encode(configData)
        try data.write(to: configFile)
    }
    
    /// 异步删除指定配置
    ///
    /// 删除配置文件
    ///
    /// - Parameter config: 要删除的配置
    /// - Throws: `ConfigManagerError.configNotFound` 当配置文件不存在时
    ///           `ConfigManagerError.fileOperationFailed` 当文件删除失败时
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
    
    private func deleteConfigSync(_ config: ClaudeConfig) throws {
        let configFile = configDirectory.appendingPathComponent("\(config.name)-settings.json")
        
        guard fileManager.fileExists(atPath: configFile.path) else {
            throw ConfigManagerError.configNotFound(config.name)
        }
        
        // 删除配置文件
        try fileManager.removeItem(at: configFile)
    }
    
    /// 获取当前活动配置
    ///
    /// 读取 settings.json 文件，并尝试匹配到对应的配置
    ///
    /// - Returns: 当前配置，如果 settings.json 不存在或无法匹配则返回 nil
    func getCurrentConfig() -> ClaudeConfig? {
        print("尝试读取当前配置文件: \(activeConfigFile.path)")
        
        // 检查当前配置文件的目录是否存在，如果不存在则创建
        let activeConfigDir = activeConfigFile.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: activeConfigDir.path) {
            do {
                try fileManager.createDirectory(at: activeConfigDir, withIntermediateDirectories: true, attributes: nil)
                print("创建当前配置目录: \(activeConfigDir.path)")
            } catch {
                print("无法创建当前配置目录: \(error)")
                return nil
            }
        }
        
        guard fileManager.fileExists(atPath: activeConfigFile.path) else {
            print("当前配置文件不存在: \(activeConfigFile.path)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: activeConfigFile)
            let configData = try JSONDecoder().decode(ConfigData.self, from: data)
            
            print("成功读取当前配置文件")
            
            // 尝试匹配现有配置
            let allConfigs = try loadConfigsSync()
            for config in allConfigs {
                if isConfigMatching(config, with: configData) {
                    print("找到匹配的配置: \(config.name)")
                    return config
                }
            }
            
            // 如果没有匹配的，创建一个临时配置
            print("没有找到匹配的配置，创建临时配置")
            return ClaudeConfig(name: "当前", configData: configData)
        } catch {
            print("读取当前配置失败: \(error)")
            return nil
        }
    }
    
    /// 验证配置的有效性
    ///
    /// 检查配置是否满足基本要求，包括必要字段的存在和格式验证
    ///
    /// - Parameter config: 要验证的配置
    /// - Throws: `ConfigManagerError.configInvalid` 当配置无效时
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
        
        // 注意：不再检查 Token 格式，允许任何非空 Token
        
        // 验证 Base URL 格式（如果提供）
        if let baseURL = config.env.anthropicBaseURL, !baseURL.isEmpty {
            guard URL(string: baseURL) != nil else {
                throw ConfigManagerError.configInvalid("Base URL 格式无效")
            }
        }
        
        // 验证数值参数
        if let maxTokens = config.env.claudeCodeMaxOutputTokens {
            guard Int(maxTokens) != nil, Int(maxTokens)! > 0 else {
                throw ConfigManagerError.configInvalid("最大输出 Token 数必须是正整数")
            }
        }
        
        if let cleanupDays = config.cleanupPeriodDays {
            guard cleanupDays > 0 else {
                throw ConfigManagerError.configInvalid("清理周期天数必须是正整数")
            }
        }
    }
    
    /// 检查配置是否匹配
    ///
    /// 通过比较关键字段来判断两个配置是否相同
    ///
    /// - Parameters:
    ///   - config: 要比较的配置
    ///   - configData: 要比较的配置数据
    /// - Returns: 如果配置匹配则返回 true
    private func isConfigMatching(_ config: ClaudeConfig, with configData: ConfigData) -> Bool {
        return config.env.anthropicAuthToken == configData.env.anthropicAuthToken &&
               config.env.anthropicBaseURL == configData.env.anthropicBaseURL
    }
}