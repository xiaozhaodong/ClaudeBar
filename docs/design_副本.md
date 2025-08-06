# Claude 配置管理器 - macOS 菜单栏应用设计规范

## 技术架构选择

### 1. 开发技术栈

#### 1.1 核心技术选择: Swift + SwiftUI + AppKit
**选择理由:**
- **原生性能**: 最佳的系统集成和性能表现
- **维护成本**: 长期维护成本较低，Apple 官方支持
- **用户体验**: 完美融入 macOS 生态系统
- **资源占用**: 相比 Electron 等跨平台方案更轻量
- **系统特性**: 完整支持 macOS 特有功能（Keychain、通知等）

#### 1.2 架构模式: MVVM + Coordinator
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│      View       │────│   ViewModel     │────│      Model      │
│   (SwiftUI)     │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │       Coordinator        │
                    │   (Navigation Logic)     │
                    └─────────────────────────┘
```

### 2. 应用架构设计

#### 2.1 模块划分
```
ClaudeConfigManager/
├── App/
│   ├── ClaudeConfigManagerApp.swift        # 应用入口
│   ├── AppDelegate.swift                   # 系统级事件处理
│   └── AppCoordinator.swift               # 主协调器
├── Core/
│   ├── Models/                            # 数据模型
│   │   ├── ClaudeConfig.swift            # 配置模型
│   │   ├── AppSettings.swift             # 应用设置
│   │   └── ClaudeProcess.swift           # 进程状态模型
│   ├── Services/                          # 业务服务
│   │   ├── ConfigService.swift           # 配置管理服务
│   │   ├── ProcessService.swift          # 进程管理服务
│   │   ├── KeychainService.swift         # 密钥链服务
│   │   └── NotificationService.swift     # 通知服务
│   └── Extensions/                        # 扩展
├── Features/
│   ├── MenuBar/                          # 菜单栏功能
│   │   ├── MenuBarView.swift
│   │   ├── MenuBarViewModel.swift
│   │   └── StatusItemManager.swift
│   ├── ConfigManagement/                 # 配置管理
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Coordinator/
│   └── Settings/                         # 设置功能
├── Resources/                            # 资源文件
└── Supporting Files/                     # 支持文件
```

#### 2.2 核心组件设计

##### 状态管理器 (AppState)
```swift
class AppState: ObservableObject {
    @Published var currentConfig: ClaudeConfig?
    @Published var availableConfigs: [ClaudeConfig] = []
    @Published var claudeProcessStatus: ProcessStatus = .unknown
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
}
```

##### 配置服务 (ConfigService)
```swift
protocol ConfigServiceProtocol {
    func loadConfigs() async throws -> [ClaudeConfig]
    func switchConfig(_ config: ClaudeConfig) async throws
    func createConfig(_ config: ClaudeConfig) async throws
    func deleteConfig(_ config: ClaudeConfig) async throws
    func getCurrentConfig() -> ClaudeConfig?
}
```

##### 进程管理服务 (ProcessService)
```swift
protocol ProcessServiceProtocol {
    func getClaudeProcessStatus() -> ProcessStatus
    func startClaude() async throws
    func stopClaude() async throws
    func restartClaude() async throws
}
```

### 3. 用户界面设计

#### 3.1 菜单栏图标设计
```swift
class StatusItemManager: ObservableObject {
    private var statusItem: NSStatusItem?
    
    enum IconState {
        case active      // 绿色 - Claude 运行中
        case ready       // 蓝色 - 配置就绪，Claude 未运行
        case warning     // 橙色 - 配置问题或警告
        case error       // 红色 - 错误状态
        case disabled    // 灰色 - 应用禁用
    }
    
    func updateIcon(state: IconState) {
        // 动态更新菜单栏图标
    }
}
```

#### 3.2 主菜单结构
```swift
struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // 当前状态区域
            CurrentStatusSection()
            
            Divider()
            
            // 配置切换区域
            ConfigSwitchSection()
            
            Divider()
            
            // 配置管理区域
            ConfigManagementSection()
            
            Divider()
            
            // Claude 控制区域
            ClaudeControlSection()
            
            Divider()
            
            // 应用设置区域
            AppSettingsSection()
        }
        .frame(width: 300)
    }
}
```

#### 3.3 配置管理窗口设计
```swift
struct ConfigManagementWindow: View {
    @StateObject private var viewModel = ConfigManagementViewModel()
    
    var body: some View {
        HSplitView {
            // 左侧：配置列表
            ConfigListView(
                configs: viewModel.configs,
                selectedConfig: $viewModel.selectedConfig
            )
            .frame(minWidth: 200)
            
            // 右侧：配置详情和编辑
            ConfigDetailView(
                config: viewModel.selectedConfig
            )
            .frame(minWidth: 400)
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItemGroup {
                Button("添加配置", action: viewModel.addConfig)
                Button("删除配置", action: viewModel.deleteConfig)
                Button("导入配置", action: viewModel.importConfig)
                Button("导出配置", action: viewModel.exportConfig)
            }
        }
    }
}
```

### 4. 数据管理设计

#### 4.1 配置文件管理
```swift
class ConfigFileManager {
    private let configDirectory: URL
    private let activeConfigFile: URL
    
    // 文件操作
    func loadConfig(name: String) throws -> ClaudeConfig
    func saveConfig(_ config: ClaudeConfig) throws
    func deleteConfig(name: String) throws
    func listConfigNames() -> [String]
    
    // 配置切换
    func switchToConfig(name: String) throws
    func getCurrentConfigName() -> String?
    
    // 备份和恢复
    func backupConfigs() throws -> URL
    func restoreConfigs(from backupURL: URL) throws
}
```

#### 4.2 安全存储 (Keychain)
```swift
class KeychainService {
    private let service = "com.claude.configmanager"
    
    func store(token: String, for configName: String) throws
    func retrieve(for configName: String) throws -> String?
    func delete(for configName: String) throws
    func updateToken(_ token: String, for configName: String) throws
}
```

#### 4.3 应用设置存储
```swift
@propertyWrapper
struct AppSetting<T> {
    private let key: String
    private let defaultValue: T
    
    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

class AppSettings: ObservableObject {
    @AppSetting(key: "launchAtLogin", defaultValue: false)
    var launchAtLogin: Bool
    
    @AppSetting(key: "showNotifications", defaultValue: true)
    var showNotifications: Bool
    
    @AppSetting(key: "autoRestartClaude", defaultValue: true)
    var autoRestartClaude: Bool
}
```

### 5. 系统集成设计

#### 5.1 启动管理
```swift
class LaunchManager {
    private let launcherBundleId = "com.claude.configmanager.launcher"
    
    func enableLaunchAtLogin() {
        // 使用 SMLoginItemSetEnabled 或 ServiceManagement 框架
    }
    
    func disableLaunchAtLogin() {
        // 禁用开机启动
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        // 检查启动状态
    }
}
```

#### 5.2 通知管理
```swift
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    func requestNotificationPermission() async -> Bool
    func showConfigSwitchNotification(to configName: String)
    func showErrorNotification(message: String)
    func showSuccessNotification(message: String)
}
```

#### 5.3 进程监控
```swift
class ProcessMonitor {
    private var processObserver: NSObjectProtocol?
    
    func startMonitoring() {
        // 使用 NSWorkspace 监控进程变化
    }
    
    func stopMonitoring() {
        // 停止监控
    }
    
    func findClaudeProcess() -> NSRunningApplication?
    func terminateClaudeProcess() -> Bool
}
```

### 6. 错误处理设计

#### 6.1 错误类型定义
```swift
enum ConfigManagerError: LocalizedError {
    case configNotFound(String)
    case configInvalid(String)
    case fileOperationFailed(String)
    case claudeNotInstalled
    case claudeStartFailed
    case keychainError(OSStatus)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .configNotFound(let name):
            return "配置 '\(name)' 未找到"
        case .configInvalid(let reason):
            return "配置无效: \(reason)"
        // ... 其他错误消息
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .configNotFound:
            return "请检查配置文件是否存在，或创建新配置"
        case .claudeNotInstalled:
            return "请先安装 Claude CLI"
        // ... 其他恢复建议
        }
    }
}
```

#### 6.2 错误处理策略
```swift
class ErrorHandler {
    static func handle(_ error: Error, context: String) {
        // 日志记录
        Logger.shared.error("Error in \(context): \(error)")
        
        // 用户通知
        if let configError = error as? ConfigManagerError {
            NotificationManager.shared.showErrorNotification(
                message: configError.localizedDescription
            )
        }
        
        // 错误恢复
        attemptRecovery(for: error)
    }
    
    private static func attemptRecovery(for error: Error) {
        // 实现自动恢复逻辑
    }
}
```

### 7. 性能优化设计

#### 7.1 异步操作
```swift
// 使用 async/await 处理所有 I/O 操作
class ConfigService {
    func loadConfigs() async throws -> [ClaudeConfig] {
        // 异步加载配置文件
    }
    
    func switchConfig(_ config: ClaudeConfig) async throws {
        // 异步切换配置
    }
}
```

#### 7.2 缓存策略
```swift
class ConfigCache {
    private var cache: [String: ClaudeConfig] = [:]
    private let cacheQueue = DispatchQueue(label: "config.cache", attributes: .concurrent)
    
    func get(name: String) -> ClaudeConfig? {
        return cacheQueue.sync { cache[name] }
    }
    
    func set(_ config: ClaudeConfig, for name: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache[name] = config
        }
    }
}
```

#### 7.3 内存管理
```swift
// 使用 weak 引用避免循环引用
class MenuBarViewModel: ObservableObject {
    weak var coordinator: AppCoordinator?
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.removeAll()
    }
}
```

### 8. 测试设计

#### 8.1 单元测试架构
```swift
// 使用依赖注入便于测试
protocol ConfigServiceProtocol {
    func loadConfigs() async throws -> [ClaudeConfig]
}

class MockConfigService: ConfigServiceProtocol {
    var mockConfigs: [ClaudeConfig] = []
    
    func loadConfigs() async throws -> [ClaudeConfig] {
        return mockConfigs
    }
}
```

#### 8.2 UI 测试支持
```swift
// 添加 accessibility identifier 支持 UI 测试
extension View {
    func testIdentifier(_ identifier: String) -> some View {
        self.accessibilityIdentifier(identifier)
    }
}
```

### 9. 国际化设计

#### 9.1 本地化支持
```swift
// 使用 SwiftUI 本地化
Text("config.switch.title")
    .localizedStringKey("配置切换")

// 支持的语言
// - 简体中文 (zh-Hans)
// - 英文 (en)
```

### 10. 构建和分发设计

#### 10.1 构建配置
```swift
// Build Settings
// - Deployment Target: macOS 10.15
// - Architectures: x86_64, arm64
// - Code Signing: Developer ID Application
// - Notarization: Enabled
```

#### 10.2 分发策略
```bash
# 支持多种分发方式:
# 1. 直接下载 .app 文件
# 2. Homebrew Cask
# 3. 未来可能支持 Mac App Store
```

这个设计规范提供了完整的技术架构和实现指导，确保应用能够高效、安全、可维护地实现所有需求功能。