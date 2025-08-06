# Claude 配置管理器 - 系统设计文档（改进版）

## 1. 架构设计

### 1.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (SwiftUI)                      │
├─────────────────────────────────────────────────────────────┤
│                  ViewModel Layer                           │
├─────────────────────────────────────────────────────────────┤
│                 Service Layer                              │
├─────────────────────────────────────────────────────────────┤
│              Data/Model Layer                              │
├─────────────────────────────────────────────────────────────┤
│               System Layer                                 │
└─────────────────────────────────────────────────────────────┘
```

#### 1.1.1 分层职责
- **UI Layer**：用户界面和交互处理
- **ViewModel Layer**：业务逻辑和状态管理
- **Service Layer**：核心业务服务
- **Data/Model Layer**：数据模型和持久化
- **System Layer**：系统集成和底层操作

### 1.2 组件架构

```
ClaudeConfigManager/
├── App/                          # 应用层
│   ├── ClaudeConfigManagerApp.swift
│   ├── AppDelegate.swift
│   └── AppState.swift
├── Core/                         # 核心层
│   ├── Models/                   # 数据模型
│   │   ├── ClaudeConfig.swift
│   │   ├── ConfigValidator.swift (新增)
│   │   └── ErrorModels.swift (新增)
│   ├── Services/                 # 业务服务
│   │   ├── ConfigService.swift
│   │   ├── KeychainService.swift
│   │   ├── ProcessService.swift
│   │   ├── Logger.swift
│   │   ├── ValidationService.swift (新增)
│   │   └── NotificationService.swift (新增)
│   └── Utils/                    # 工具类
│       ├── FileManager+Extensions.swift (新增)
│       ├── String+Validation.swift (新增)
│       └── JSONSchemaValidator.swift (新增)
├── Features/                     # 功能模块
│   ├── MenuBar/
│   │   ├── StatusItemManager.swift
│   │   ├── MenuBarView.swift
│   │   └── MenuBarViewModel.swift
│   ├── ConfigEditor/            # 新增配置编辑器
│   │   ├── ConfigEditorView.swift
│   │   ├── ConfigEditorViewModel.swift
│   │   └── ConfigFormValidator.swift
│   └── ContentView.swift
├── Tests/                       # 测试模块 (新增)
│   ├── UnitTests/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── ViewModels/
│   ├── IntegrationTests/
│   └── UITests/
└── Resources/                   # 资源文件
    ├── Schemas/                 # JSON Schema 文件 (新增)
    │   └── config-schema.json
    └── Localizable.strings      # 多语言支持 (新增)
```

## 2. 核心服务设计

### 2.1 ConfigService 增强设计

#### 2.1.1 服务接口
```swift
protocol ConfigServiceProtocol {
    // 基础功能
    func loadConfigs() async throws -> [ClaudeConfig]
    func switchConfig(_ config: ClaudeConfig) async throws
    func createConfig(_ config: ClaudeConfig) async throws
    func deleteConfig(_ config: ClaudeConfig) async throws
    func getCurrentConfig() -> ClaudeConfig?
    
    // 新增功能
    func validateConfig(_ config: ClaudeConfig) async throws -> ValidationResult
    func backupConfig(_ config: ClaudeConfig) async throws -> URL
    func restoreConfig(from backupURL: URL) async throws -> ClaudeConfig
    func watchConfigChanges() -> AsyncStream<ConfigChangeEvent>
}
```

#### 2.1.2 验证机制
```swift
struct ValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    let suggestions: [ValidationSuggestion]
}

enum ValidationError {
    case missingRequiredField(String)
    case invalidTokenFormat
    case invalidURL(String)
    case invalidPermissionFormat
    case fileSystemError(Error)
}
```

#### 2.1.3 错误处理增强
```swift
enum ConfigServiceError: LocalizedError {
    case validationFailed(ValidationResult)
    case networkTimeout
    case concurrentModification
    case backupFailed(Error)
    case restoreFailed(Error)
    
    var errorDescription: String? { ... }
    var recoverySuggestion: String? { ... }
    var helpAnchor: String? { ... }
}
```

### 2.2 测试架构设计

#### 2.2.1 测试分层
```
Tests/
├── UnitTests/                   # 单元测试
│   ├── Models/
│   │   ├── ClaudeConfigTests.swift
│   │   └── ConfigValidatorTests.swift
│   ├── Services/
│   │   ├── ConfigServiceTests.swift
│   │   ├── KeychainServiceTests.swift
│   │   └── ProcessServiceTests.swift
│   └── ViewModels/
│       └── MenuBarViewModelTests.swift
├── IntegrationTests/            # 集成测试
│   ├── ConfigManagementFlowTests.swift
│   ├── KeychainIntegrationTests.swift
│   └── ProcessIntegrationTests.swift
├── UITests/                     # UI 测试
│   ├── MenuBarUITests.swift
│   └── ConfigEditorUITests.swift
├── PerformanceTests/            # 性能测试
│   └── ConfigSwitchingPerformanceTests.swift
└── TestUtilities/               # 测试工具
    ├── MockServices.swift
    ├── TestDataBuilder.swift
    └── TestEnvironment.swift
```

#### 2.2.2 Mock 服务设计
```swift
class MockConfigService: ConfigServiceProtocol {
    var mockConfigs: [ClaudeConfig] = []
    var shouldFailLoadConfigs = false
    var loadConfigsDelay: TimeInterval = 0
    
    // 实现所有协议方法的 Mock 版本
}

class TestDataBuilder {
    static func createValidConfig(name: String = "test") -> ClaudeConfig
    static func createInvalidConfig() -> ClaudeConfig
    static func createConfigWithMissingToken() -> ClaudeConfig
}
```

### 2.3 错误处理架构

#### 2.3.1 错误处理流程
```
Error Occurrence
       ↓
   Error Classification
       ↓
   Error Recovery Attempt
       ↓
   User Notification
       ↓
   Error Logging
       ↓
   Analytics Reporting
```

#### 2.3.2 用户友好错误处理
```swift
protocol ErrorPresentable {
    var userFriendlyTitle: String { get }
    var userFriendlyMessage: String { get }
    var recoveryOptions: [ErrorRecoveryOption] { get }
    var helpURL: URL? { get }
}

struct ErrorRecoveryOption {
    let title: String
    let action: () async throws -> Void
    let isDestructive: Bool
}
```

#### 2.3.3 错误上下文收集
```swift
struct ErrorContext {
    let timestamp: Date
    let operation: String
    let userID: String?
    let systemInfo: SystemInfo
    let configState: ConfigState
    let stackTrace: String
}
```

## 3. 数据流设计

### 3.1 配置管理数据流

```
User Action → ViewModel → Service → Validation → Storage → Notification
     ↑                                                        ↓
User Feedback ← UI Update ← State Update ← Success/Error ←─────┘
```

#### 3.1.1 状态管理
```swift
@MainActor
class AppState: ObservableObject {
    @Published var configs: [ClaudeConfig] = []
    @Published var currentConfig: ClaudeConfig?
    @Published var isLoading = false
    @Published var error: ErrorInfo?
    @Published var claudeProcessState: ProcessState = .unknown
    
    // 新增状态
    @Published var lastSyncTime: Date?
    @Published var validationErrors: [ValidationError] = []
    @Published var performanceMetrics: PerformanceMetrics?
}
```

#### 3.1.2 响应式更新
```swift
class ConfigWatcher {
    func startWatching() -> AsyncStream<ConfigChangeEvent> {
        AsyncStream { continuation in
            // 文件系统监控实现
        }
    }
}

enum ConfigChangeEvent {
    case configAdded(ClaudeConfig)
    case configModified(ClaudeConfig)
    case configDeleted(String)
    case activeConfigChanged(ClaudeConfig)
}
```

### 3.2 安全数据流

#### 3.2.1 Token 处理流程
```
Token Input → Validation → Keychain Storage → Memory Clear
                                    ↓
                            Configuration Usage
                                    ↓
                              Secure Cleanup
```

#### 3.2.2 权限验证流程
```swift
protocol SecurityValidator {
    func validateFileAccess(path: String) throws
    func validateKeychainAccess() throws
    func validateNetworkAccess(url: URL) throws
    func sanitizeUserInput(_ input: String) -> String
}
```

## 4. 性能设计

### 4.1 性能优化策略

#### 4.1.1 配置加载优化
```swift
class OptimizedConfigService {
    private var configCache: [String: ClaudeConfig] = [:]
    private var lastModificationTimes: [String: Date] = [:]
    
    func loadConfigsWithCaching() async throws -> [ClaudeConfig] {
        // 增量加载和缓存策略
    }
}
```

#### 4.1.2 UI 响应性优化
```swift
class PerformantMenuBarViewModel: ObservableObject {
    @Published var configs: [ClaudeConfig] = []
    
    func loadConfigsInBackground() {
        Task {
            let configs = try await configService.loadConfigs()
            await MainActor.run {
                self.configs = configs
            }
        }
    }
}
```

### 4.2 内存管理

#### 4.2.1 内存优化策略
- **延迟加载**：仅在需要时加载配置数据
- **弱引用**：避免循环引用
- **资源释放**：及时释放不需要的资源
- **缓存策略**：合理的缓存大小和清理策略

#### 4.2.2 性能监控
```swift
class PerformanceMonitor {
    func trackOperation<T>(_ operation: String, execute: () async throws -> T) async throws -> T {
        let startTime = Date()
        defer {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.performance("Operation \(operation) took \(duration)s")
        }
        return try await execute()
    }
}
```

## 5. 安全设计

### 5.1 数据保护

#### 5.1.1 敏感数据处理
```swift
protocol SecureDataHandler {
    func storeSecurely(_ data: Data, withKey key: String) throws
    func retrieveSecurely(withKey key: String) throws -> Data?
    func deleteSecurely(withKey key: String) throws
    func listSecureKeys() throws -> [String]
}
```

#### 5.1.2 内存安全
```swift
class SecureString {
    private var data: Data
    
    init(_ string: String) {
        self.data = string.data(using: .utf8) ?? Data()
    }
    
    deinit {
        // 清零内存
        data.withUnsafeMutableBytes { bytes in
            bytes.bindMemory(to: UInt8.self).initialize(repeating: 0)
        }
    }
}
```

### 5.2 权限管理

#### 5.2.1 最小权限原则
```xml
<!-- ClaudeConfigManager.entitlements -->
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
```

#### 5.2.2 权限验证
```swift
class PermissionValidator {
    func validateFileSystemAccess() throws
    func validateKeychainAccess() throws
    func validateNetworkAccess() throws
}
```

## 6. 可测试性设计

### 6.1 依赖注入

#### 6.1.1 服务容器
```swift
protocol ServiceContainer {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func resolve<T>(_ type: T.Type) -> T
}

class DIContainer: ServiceContainer {
    private var services: [String: Any] = [:]
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        services[key] = factory
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        let factory = services[key] as! () -> T
        return factory()
    }
}
```

#### 6.1.2 测试配置
```swift
class TestServiceContainer {
    static func createTestContainer() -> ServiceContainer {
        let container = DIContainer()
        container.register(ConfigServiceProtocol.self) { MockConfigService() }
        container.register(KeychainServiceProtocol.self) { MockKeychainService() }
        return container
    }
}
```

### 6.2 测试工具

#### 6.2.1 测试基类
```swift
class BaseTestCase: XCTestCase {
    var container: ServiceContainer!
    var testEnvironment: TestEnvironment!
    
    override func setUp() {
        super.setUp()
        container = TestServiceContainer.createTestContainer()
        testEnvironment = TestEnvironment()
    }
    
    override func tearDown() {
        testEnvironment.cleanup()
        super.tearDown()
    }
}
```

#### 6.2.2 异步测试支持
```swift
extension XCTestCase {
    func awaitAsyncThrows<T>(
        _ operation: @escaping () async throws -> T,
        timeout: TimeInterval = 10
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            guard let result = try await group.next() else {
                throw TestError.asyncOperationFailed
            }
            return result
        }
    }
}
```

## 7. 监控和日志设计

### 7.1 结构化日志

#### 7.1.1 日志模型
```swift
struct LogEntry {
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let metadata: [String: Any]
    let file: String
    let function: String
    let line: Int
}

enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}
```

#### 7.1.2 日志服务增强
```swift
class EnhancedLogger {
    func log(
        level: LogLevel,
        message: String,
        category: String = "General",
        metadata: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
        writeLog(entry)
    }
}
```

### 7.2 性能监控

#### 7.2.1 指标收集
```swift
struct PerformanceMetrics {
    let configLoadTime: TimeInterval
    let configSwitchTime: TimeInterval
    let memoryUsage: UInt64
    let cpuUsage: Double
    let diskUsage: UInt64
}

class MetricsCollector {
    func collectMetrics() -> PerformanceMetrics {
        // 收集系统性能指标
    }
    
    func reportMetrics(_ metrics: PerformanceMetrics) {
        // 报告指标到监控系统
    }
}
```

## 8. 部署和维护设计

### 8.1 构建流程

#### 8.1.1 自动化构建
```bash
#!/bin/bash
# enhanced-build.sh

set -e

echo "🚀 开始增强构建流程..."

# 1. 代码质量检查
echo "📊 运行代码质量检查..."
swiftlint --strict
swiftformat --lint .

# 2. 运行测试套件
echo "🧪 运行测试套件..."
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager

# 3. 生成测试报告
echo "📋 生成测试报告..."
xcrun xccov view --report --json DerivedData/*/Logs/Test/*.xcresult > test-coverage.json

# 4. 性能基准测试
echo "⚡ 运行性能测试..."
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -testPlan PerformanceTestPlan

# 5. 构建发布版本
echo "🔨 构建发布版本..."
xcodebuild build -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -configuration Release

echo "✅ 构建完成！"
```

#### 8.1.2 质量门控
```swift
struct QualityGate {
    let minimumTestCoverage: Double = 80.0
    let maximumCyclomaticComplexity: Int = 10
    let maximumCodeDuplication: Double = 5.0
    
    func validate(metrics: QualityMetrics) throws {
        guard metrics.testCoverage >= minimumTestCoverage else {
            throw QualityGateError.insufficientTestCoverage(metrics.testCoverage)
        }
        // 其他验证...
    }
}
```

### 8.2 监控和维护

#### 8.2.1 健康检查
```swift
class HealthChecker {
    func performHealthCheck() -> HealthStatus {
        var issues: [HealthIssue] = []
        
        // 检查配置文件完整性
        if !checkConfigIntegrity() {
            issues.append(.configCorruption)
        }
        
        // 检查 Keychain 访问
        if !checkKeychainAccess() {
            issues.append(.keychainAccess)
        }
        
        // 检查磁盘空间
        if !checkDiskSpace() {
            issues.append(.lowDiskSpace)
        }
        
        return HealthStatus(issues: issues)
    }
}
```

---

## 总结

此改进版设计文档包含了：

1. **测试架构**：完整的测试分层和 Mock 设计
2. **错误处理机制**：用户友好的错误处理和恢复
3. **性能优化**：缓存、异步处理和性能监控
4. **安全增强**：数据保护和权限管理
5. **可测试性**：依赖注入和测试工具
6. **监控日志**：结构化日志和性能指标
7. **质量保证**：自动化构建和质量门控

这些设计改进将确保系统能够达到 95% 以上的质量标准。