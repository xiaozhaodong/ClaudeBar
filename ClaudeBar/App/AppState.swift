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
    
    internal var configService: ConfigServiceProtocol
    private let processService: ProcessService
    private var cancellables = Set<AnyCancellable>()
    private var loadConfigsTask: Task<Void, Never>?
    private var successMessageTask: Task<Void, Never>?
    
    // 配置缓存机制
    private var lastConfigLoadTime: Date?
    private let configCacheValidityDuration: TimeInterval = 5 * 60 // 5分钟缓存有效期
    
    init(configService: ConfigServiceProtocol? = nil) {
        self.configService = configService ?? ModernConfigService()
        self.processService = ProcessService()
        
        // 监听进程状态变化
        processService.$processStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.claudeProcessStatus, on: self)
            .store(in: &cancellables)
            
        // 启动时检查和执行迁移
        Task {
            await checkAndMigrate()
        }
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
            return
        }
        
        // 缓存过期或从未加载，执行加载
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
    
    deinit {
        loadConfigsTask?.cancel()
        successMessageTask?.cancel()
        cancellables.removeAll()
    }
    
}
