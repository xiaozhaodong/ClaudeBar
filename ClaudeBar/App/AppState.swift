import SwiftUI
import Combine
import AppKit

@MainActor
class AppState: ObservableObject {
    @Published var currentConfig: ClaudeConfig?
    @Published var availableConfigs: [ClaudeConfig] = []
    @Published var isLoading: Bool = false
    @Published var isSwitchingConfig: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var claudeProcessStatus: ProcessService.ProcessStatus = .unknown
    @Published var showingSettings: Bool = false
    @Published var showingMainWindow: Bool = false
    @Published var migrationStatus: String?
    
    // 使用统计相关状态
    @Published var usageStatistics: UsageStatistics?
    @Published var isLoadingUsage: Bool = false
    @Published var usageErrorMessage: String?
    
    // 自动同步服务
    @Published var autoSyncService: AutoSyncService
    
    internal var configService: ConfigServiceProtocol
    private let processService: ProcessService
    private let usageService: UsageServiceProtocol
    private let usageStatisticsDB: UsageStatisticsDatabase  // 使用统计数据库
    internal let userPreferences: UserPreferences
    private var cancellables = Set<AnyCancellable>()
    private var loadConfigsTask: Task<Void, Never>?
    private var successMessageTask: Task<Void, Never>?
    private var loadUsageTask: Task<Void, Never>?
    
    // 配置缓存机制
    private var lastConfigLoadTime: Date?
    private let configCacheValidityDuration: TimeInterval = 60 // 增加到60秒缓存有效期
    
    init(configService: ConfigServiceProtocol? = nil) {
        self.configService = configService ?? SQLiteConfigService()
        self.processService = ProcessService()
        
        // 初始化使用统计数据库（这会自动创建表结构）
        self.usageStatisticsDB = UsageStatisticsDatabase()
        print("使用统计数据库已初始化")
        
        // 使用混合服务：优先数据库，降级到JSONL
        let hybridUsageService = HybridUsageService(database: self.usageStatisticsDB, configService: self.configService)
        self.usageService = hybridUsageService
        
        // 初始化用户偏好设置
        self.userPreferences = UserPreferences()
        
        // 初始化自动同步服务
        self.autoSyncService = AutoSyncService(
            usageService: hybridUsageService,
            userPreferences: userPreferences
        )
        
        // 监听进程状态变化
        processService.$processStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.claudeProcessStatus, on: self)
            .store(in: &cancellables)
            
        // 配置自动同步服务的初始状态
        configureAutoSyncService()
            
        // 启动时检查和执行迁移
        Task {
            await checkAndMigrate()
        }
        
        // 预加载使用统计数据（不阻塞启动）
        Task {
            await loadUsageStatisticsInBackground()
        }
    }
    
    /// 配置自动同步服务
    /// 设置自动同步服务的初始状态和依赖关系
    private func configureAutoSyncService() {
        // 延迟启动自动同步，避免初始化时的主线程阻塞
        if userPreferences.autoSyncEnabled {
            // 使用 1 秒延迟，让应用完全启动后再开始同步
            Task {
                do {
                    // 延迟启动以避免初始化时的阻塞
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒
                    try await autoSyncService.startAutoSync()
                    print("✅ 自动同步服务已启动")
                } catch {
                    print("⚠️ 自动同步服务启动失败: \(error)")
                }
            }
        }
        
        // 监听自动同步设置变化，已经在AutoSyncService内部处理
        // 这里不需要额外的监听逻辑
    }
    
    /// 检查并请求 ~/.claude 目录访问权限（已简化）
    /// 遵循 YAGNI 原则：移除不必要的复杂权限检查
    @MainActor
    private func checkAndRequestClaudeDirectoryAccess() {
        // 新的配置服务不需要复杂的权限管理
        // 此方法保留以保持向后兼容
        print("使用现代化配置服务，无需复杂权限检查")
    }
    
    /// 检查和执行配置迁移
    /// 遵循 SOLID 原则：单一职责，专门处理迁移逻辑
    @MainActor
    private func checkAndMigrate() async {
        // 简化：直接加载配置，不进行复杂迁移
        await loadConfigs()
        print("使用标准配置服务")
    }
    
    func loadConfigs() async {
        // 防止重复加载
        guard !isLoading else { return }
        
        // 取消之前的加载任务
        loadConfigsTask?.cancel()
        
        loadConfigsTask = Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let configs = try await configService.loadConfigs()
                
                // 检查任务是否被取消
                guard !Task.isCancelled else { return }
                
                availableConfigs = configs
                currentConfig = configService.getCurrentConfig()
                
                // 更新缓存时间戳
                lastConfigLoadTime = Date()
                
                // 清除错误信息
                errorMessage = nil
            } catch {
                // 检查任务是否被取消
                guard !Task.isCancelled else { return }
                
                errorMessage = "加载配置失败: \(error.localizedDescription)"
                print("配置加载错误: \(error)")
            }
            
            isLoading = false
        }
        
        await loadConfigsTask?.value
    }
    
    /// 智能加载配置：只有在缓存过期或从未加载时才重新加载
    func loadConfigsIfNeeded() async {
        // 如果正在加载中，直接返回
        guard !isLoading else { return }
        
        // 检查是否需要重新加载配置
        let now = Date()
        if let lastLoadTime = lastConfigLoadTime,
           now.timeIntervalSince(lastLoadTime) < configCacheValidityDuration,
           !availableConfigs.isEmpty {
            // 缓存仍然有效且有配置数据，无需重新加载
            print("配置缓存有效，跳过重新加载 (上次加载时间: \(lastLoadTime))")
            return
        }
        
        // 缓存过期或从未加载，执行加载
        print("配置缓存过期或未初始化，执行加载")
        await loadConfigs()
    }
    
    /// 强制刷新配置（用于用户主动刷新）
    func forceRefreshConfigs() async {
        lastConfigLoadTime = nil // 清除缓存时间戳
        await loadConfigs()
    }
    
    /// 请求 ~/.claude 目录访问权限
    @MainActor 
    func requestClaudeDirectoryAccess() {
        let openPanel = NSOpenPanel()
        openPanel.title = "授权访问 Claude 目录"
        openPanel.message = "应用需要访问 ~/.claude 目录来读取当前配置\n请选择您的 .claude 目录"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.showsHiddenFiles = true
        
        // 导航到用户家目录
        openPanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        
        let response = openPanel.runModal()
        if response == .OK, let selectedURL = openPanel.url {
            // 保存书签以便后续访问
            if let bookmarkData = try? selectedURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(bookmarkData, forKey: "claudeDirectoryBookmark")
                print("已保存 Claude 目录书签: \(selectedURL.path)")
            }
            
            // 重新加载配置
            Task {
                await loadConfigs()
            }
        } else {
            errorMessage = "需要授权访问 ~/.claude 目录以读取当前配置"
        }
    }
    @MainActor 
    func requestConfigDirectoryAccess() {
        // 现代化服务不需要手动选择目录
        print("现代化服务已简化权限管理")
        Task {
            await loadConfigs()
        }
    }
    
    /// 内部使用的配置目录访问权限请求
    @MainActor
    private func internalRequestConfigDirectoryAccess() {
        requestConfigDirectoryAccess()
    }
    
    func switchConfig(_ config: ClaudeConfig) async {
        // 防止重复操作
        guard !isSwitchingConfig else { return }
        guard currentConfig?.name != config.name else { return }
        
        isSwitchingConfig = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await configService.switchConfig(config)
            currentConfig = config
            
            // 配置已切换成功，设置成功消息
            showSuccessMessage("API 端点切换成功。如果 Claude 正在运行，请手动重启以使新端点生效。")
        } catch {
            errorMessage = "切换 API 端点失败: \(error.localizedDescription)"
            print("API 端点切换错误: \(error)")
        }
        
        isSwitchingConfig = false
    }
    
    /// 显示成功消息，20秒后自动关闭
    func showSuccessMessage(_ message: String) {
        successMessage = message
        
        // 取消之前的自动关闭任务
        successMessageTask?.cancel()
        
        // 20秒后自动关闭成功消息
        successMessageTask = Task {
            try? await Task.sleep(nanoseconds: 20_000_000_000) // 20秒
            if !Task.isCancelled {
                successMessage = nil
            }
        }
    }
    
    /// 手动关闭成功消息
    func dismissSuccessMessage() {
        successMessage = nil
        successMessageTask?.cancel()
    }
    
    func refreshProcessStatus() {
        processService.refreshStatus()
    }
    
    /// 更新配置目录（已简化）
    /// 遵循 YAGNI 原则：移除不必要的目录切换功能
    @MainActor
    func updateConfigDirectory(_ url: URL) {
        // 现代化服务使用固定目录，不需要动态更新
        print("现代化服务使用标准 ~/.claude 目录")
        
        // 重新加载配置
        Task {
            await loadConfigs()
        }
    }
    
    /// 显示错误消息
    func showErrorMessage(_ message: String) {
        self.errorMessage = message
    }
    
    /// 打开主窗口
    @MainActor
    func openMainWindow() {
        guard !showingMainWindow else { return } // 防止重复操作
        showingMainWindow = true
    }
    
    /// 关闭主窗口
    @MainActor
    func closeMainWindow() {
        guard showingMainWindow else { return } // 防止重复操作
        showingMainWindow = false
    }
    
    /// 切换主窗口显示状态
    @MainActor
    func toggleMainWindow() {
        showingMainWindow.toggle()
    }
    
    // MARK: - 本地状态操作方法（无感刷新）
    
    /// 本地添加配置（无需重新加载数据库）
    @MainActor
    func addConfigLocally(_ config: ClaudeConfig) {
        // 检查配置是否已存在
        guard !availableConfigs.contains(where: { $0.name == config.name }) else {
            print("配置 \(config.name) 已存在，跳过添加")
            return
        }
        
        // 添加到本地配置数组
        availableConfigs.append(config)
        
        // 重新排序保持一致性
        availableConfigs.sort { $0.name < $1.name }
        
        print("本地添加配置成功: \(config.name)")
    }
    
    /// 本地删除配置（无需重新加载数据库）
    @MainActor
    func removeConfigLocally(_ config: ClaudeConfig) {
        // 从本地配置数组中移除
        availableConfigs.removeAll { $0.name == config.name }
        
        // 如果删除的是当前配置，清除当前配置状态
        if currentConfig?.name == config.name {
            currentConfig = nil
        }
        
        print("本地删除配置成功: \(config.name)")
    }
    
    /// 本地更新配置（无需重新加载数据库）
    @MainActor
    func updateConfigLocally(oldConfig: ClaudeConfig, newConfig: ClaudeConfig) {
        // 查找并更新配置
        if let index = availableConfigs.firstIndex(where: { $0.name == oldConfig.name }) {
            availableConfigs[index] = newConfig
            
            // 如果更新的是当前配置，同步更新当前配置状态
            if currentConfig?.name == oldConfig.name {
                currentConfig = newConfig
            }
            
            // 如果名称发生变化，重新排序
            if oldConfig.name != newConfig.name {
                availableConfigs.sort { $0.name < $1.name }
            }
            
            print("本地更新配置成功: \(oldConfig.name) -> \(newConfig.name)")
        } else {
            print("警告：未找到要更新的配置 \(oldConfig.name)")
        }
    }
    
    deinit {
        loadConfigsTask?.cancel()
        successMessageTask?.cancel()
        loadUsageTask?.cancel()
        cancellables.removeAll()
        
        // 停止自动同步服务
        Task {
            await autoSyncService.stopAutoSync()
        }
    }
    
    // MARK: - 使用统计相关方法
    
    /// 后台加载使用统计数据（简化）
    private func loadUsageStatisticsInBackground() async {
        do {
            let stats = try await usageService.getUsageStatistics(dateRange: .all, projectPath: nil)
            usageStatistics = stats
            usageErrorMessage = nil
            Logger.shared.info("AppState: 后台加载使用统计成功")
        } catch {
            usageErrorMessage = "加载使用统计失败: \(error.localizedDescription)"
            Logger.shared.error("AppState: 后台加载使用统计失败: \(error)")
        }
    }
    
    /// 刷新使用统计数据（直接调用数据库）
    func refreshUsageStatistics() async {
        guard !isLoadingUsage else { return }
        
        loadUsageTask?.cancel()
        loadUsageTask = Task {
            isLoadingUsage = true
            usageErrorMessage = nil
            
            do {
                // 直接调用数据库服务
                let stats = try await usageService.getUsageStatistics(dateRange: .all, projectPath: nil)
                
                guard !Task.isCancelled else { return }
                
                usageStatistics = stats
                usageErrorMessage = nil
                Logger.shared.info("AppState: 使用统计刷新成功")
                
            } catch {
                guard !Task.isCancelled else { return }
                
                usageErrorMessage = "刷新使用统计失败: \(error.localizedDescription)"
                Logger.shared.error("AppState: 使用统计刷新错误: \(error)")
            }
            
            isLoadingUsage = false
        }
        
        await loadUsageTask?.value
    }
    
    /// 打开主窗口并跳转到使用统计页面
    @MainActor
    func openUsageStatistics() {
        guard !showingMainWindow else { 
            // 如果窗口已打开，仅通知切换到使用统计页面
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToUsageStatistics"), object: nil)
            return 
        }
        showingMainWindow = true
        
        // 延迟发送导航通知，确保窗口已显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToUsageStatistics"), object: nil)
        }
    }
    
    // MARK: - 自动同步服务访问方法
    
    /// 手动触发完整同步
    /// 通过AppState提供统一的同步接口
    func performFullSync() async {
        do {
            let result = try await autoSyncService.performFullSync()
            Logger.shared.info("AppState: 完整同步完成，处理了 \(result.processedItems) 项")
            
            // 同步完成后刷新使用统计
            await refreshUsageStatistics()
        } catch {
            Logger.shared.error("AppState: 完整同步失败: \(error)")
            showErrorMessage("完整同步失败: \(error.localizedDescription)")
        }
    }
    
    /// 手动触发增量同步
    /// 通过AppState提供统一的同步接口
    func performIncrementalSync() async {
        do {
            let result = try await autoSyncService.performIncrementalSync()
            Logger.shared.info("AppState: 增量同步完成，处理了 \(result.processedItems) 项")
            
            // 同步完成后刷新使用统计
            await refreshUsageStatistics()
        } catch {
            Logger.shared.error("AppState: 增量同步失败: \(error)")
            showErrorMessage("增量同步失败: \(error.localizedDescription)")
        }
    }
    
    /// 取消当前同步操作
    func cancelSync() async {
        await autoSyncService.cancelSync()
        Logger.shared.info("AppState: 同步操作已取消")
    }
}