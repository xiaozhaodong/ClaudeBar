import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var currentConfig: ClaudeConfig?
    @Published var availableConfigs: [ClaudeConfig] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var claudeProcessStatus: ProcessService.ProcessStatus = .unknown
    @Published var showingSettings: Bool = false
    
    internal var configService: ConfigServiceProtocol
    private let processService: ProcessService
    private var cancellables = Set<AnyCancellable>()
    private var loadConfigsTask: Task<Void, Never>?
    private var successMessageTask: Task<Void, Never>?
    
    init(configService: ConfigServiceProtocol = ConfigService()) {
        self.configService = configService
        self.processService = ProcessService()
        
        // 监听进程状态变化
        processService.$processStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.claudeProcessStatus, on: self)
            .store(in: &cancellables)
            
        // 启动时检查权限（同步调用）
        checkAndRequestClaudeDirectoryAccess()
    }
    
    /// 检查并请求 ~/.claude 目录访问权限
    @MainActor
    private func checkAndRequestClaudeDirectoryAccess() {
        // 使用真实的家目录路径
        let username = NSUserName()
        let realHomePath = "/Users/\(username)"
        let claudeDir = URL(fileURLWithPath: realHomePath).appendingPathComponent(".claude")
        let settingsFile = claudeDir.appendingPathComponent("settings.json")
        
        print("检查配置文件: \(settingsFile.path)")
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: settingsFile.path) else {
            print("配置文件不存在: \(settingsFile.path)")
            return
        }
        
        // 尝试读取文件以检查权限
        do {
            _ = try Data(contentsOf: settingsFile)
            print("已有 ~/.claude 目录访问权限")
        } catch {
            print("无法读取 ~/.claude/settings.json，弹出权限对话框: \(error)")
            // 延迟执行权限请求，确保 UI 已完全加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.requestClaudeDirectoryAccess()
            }
        }
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
                
                // 清除错误信息
                errorMessage = nil
            } catch {
                // 检查任务是否被取消
                guard !Task.isCancelled else { return }
                
                // 特殊处理权限错误
                if let configError = error as? ConfigManagerError,
                   case .permissionDenied(_) = configError {
                    // 请求用户授权访问配置目录
                    internalRequestConfigDirectoryAccess()
                } else {
                    errorMessage = "加载配置失败: \(error.localizedDescription)"
                    print("配置加载错误: \(error)")
                }
            }
            
            isLoading = false
        }
        
        await loadConfigsTask?.value
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
        if let authorizedURL = ConfigService.requestConfigDirectoryAccess() {
            print("用户已授权访问配置目录: \(authorizedURL.path)")
            
            // 重新创建 ConfigService 使用新的目录
            configService = ConfigService(configDirectory: authorizedURL)
            
            // 重新加载配置
            Task {
                await loadConfigs()
            }
        } else {
            errorMessage = "需要选择 Claude 配置目录以继续使用应用"
        }
    }
    
    /// 内部使用的配置目录访问权限请求
    @MainActor
    private func internalRequestConfigDirectoryAccess() {
        requestConfigDirectoryAccess()
    }
    
    func switchConfig(_ config: ClaudeConfig) async {
        // 防止重复操作
        guard !isLoading else { return }
        guard currentConfig?.name != config.name else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await configService.switchConfig(config)
            currentConfig = config
            
            // 配置已切换成功，设置成功消息
            showSuccessMessage("配置已切换成功。如果 Claude 正在运行，请手动重启以使新配置生效。")
        } catch {
            errorMessage = "切换配置失败: \(error.localizedDescription)"
            print("配置切换错误: \(error)")
        }
        
        isLoading = false
    }
    
    /// 显示成功消息，20秒后自动关闭
    private func showSuccessMessage(_ message: String) {
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
    
    /// 更新配置目录
    @MainActor
    func updateConfigDirectory(_ url: URL) {
        configService = ConfigService(configDirectory: url)
        
        // 清除当前状态
        currentConfig = nil
        availableConfigs = []
        errorMessage = nil
        successMessage = nil
    }
    
    deinit {
        loadConfigsTask?.cancel()
        successMessageTask?.cancel()
        cancellables.removeAll()
    }
}