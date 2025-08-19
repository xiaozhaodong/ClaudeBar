# 自动同步系统设计方案

## 方案概述

本方案旨在为 ClaudeBar 应用实现自动的 JSONL 数据同步到 SQLite 数据库功能，并通过响应式编程实现数据变化时的 UI 自动更新。系统将支持全量同步（首次启动）和增量同步（定时执行）两种模式。

## 设计目标

1. **自动化数据同步**: 无需用户干预，自动将 Claude CLI 生成的 JSONL 数据同步到本地数据库
2. **实时 UI 更新**: 数据同步完成后，相关 UI 界面自动刷新显示最新数据
3. **高性能**: 增量同步仅处理新增数据，避免全量重复处理
4. **用户可控**: 提供手动同步功能和同步间隔设置
5. **状态透明**: 实时显示同步状态和进度信息

## 核心架构

### 1. 同步服务层

```swift
AutoSyncService (ObservableObject)
├── 定时器管理 (Timer)
├── 同步状态管理 (@Published)
├── 增量同步逻辑
└── 通知机制 (NotificationCenter)
```

### 2. 数据处理层

```swift
HybridUsageService
├── 全量同步方法 (performFullSync)
├── 增量同步方法 (performIncrementalSync)
└── 数据库操作 (UsageStatisticsDatabase)
```

### 3. UI 响应层

```swift
UsageStatisticsViewModel (ObservableObject)
├── 数据更新监听 (Combine)
├── 状态管理 (@Published)
└── 自动刷新逻辑
```

## 详细设计

### AutoSyncService 核心特性

#### 状态管理
- `@Published var lastSyncTime: Date?` - 上次同步时间
- `@Published var isSyncing: Bool` - 同步状态标识
- `@Published var syncStatus: String` - 同步状态描述
- `@Published var syncProgress: Double` - 同步进度 (0.0-1.0)

#### 定时器机制
- 默认间隔: 1小时 (3600秒)
- 可配置间隔: 通过用户偏好设置调整
- 自动启动: 应用启动时自动开始定时同步
- 生命周期管理: 应用退出时自动清理定时器

#### 同步策略
1. **首次启动检测**: 检查数据库是否为空，执行全量同步
2. **定时增量同步**: 每小时检查 JSONL 文件更新，同步新增数据
3. **手动同步**: 用户可随时触发立即同步
4. **错误重试**: 同步失败时自动重试机制

### 数据流程设计

#### 全量同步流程
```
应用首次启动
    ↓
检查数据库状态
    ↓
扫描所有 JSONL 文件
    ↓
解析并批量插入数据库
    ↓
更新同步时间戳
    ↓
发送完成通知
    ↓
UI 自动刷新
```

#### 增量同步流程
```
定时器触发 (每小时)
    ↓
获取上次同步时间
    ↓
扫描 JSONL 文件变更
    ↓
解析新增数据
    ↓
增量插入数据库
    ↓
更新同步时间戳
    ↓
发送更新通知
    ↓
UI 自动刷新
```

### UI 响应机制

#### 通知系统
```swift
extension Notification.Name {
    static let usageDataDidUpdate = Notification.Name("usageDataDidUpdate")
    static let syncStatusDidChange = Notification.Name("syncStatusDidChange")
    static let syncProgressDidUpdate = Notification.Name("syncProgressDidUpdate")
}
```

#### ViewModel 自动刷新
- 监听数据更新通知
- 自动重新获取统计数据
- 更新 `@Published` 属性触发 UI 重绘
- 错误处理和状态恢复

### 用户界面集成

#### 同步状态显示
- 同步进度条 (ProgressView)
- 状态文本描述 (正在同步/同步完成/同步失败)
- 上次同步时间显示
- 手动同步按钮

#### 设置界面扩展
- 同步间隔设置 (15分钟/30分钟/1小时/2小时/手动)
- 自动同步开关
- 同步历史记录
- 数据统计信息 (总条目数/最新条目时间)

## 技术实现细节

### 1. 定时器管理
```swift
class AutoSyncService: ObservableObject {
    private var timer: Timer?
    private let syncInterval: TimeInterval
    
    private func startAutoSync() {
        stopAutoSync() // 防止重复启动
        
        timer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performIncrementalSync()
            }
        }
    }
    
    private func stopAutoSync() {
        timer?.invalidate()
        timer = nil
    }
}
```

### 2. 线程安全处理
- 所有数据库操作在后台队列执行
- UI 更新在主线程执行 (`@MainActor`)
- 使用 `actor` 确保同步操作的串行执行

### 3. 错误处理策略
```swift
enum SyncError: Error, LocalizedError {
    case databaseError(String)
    case fileAccessError(String)
    case parsingError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseError(let msg): return "数据库错误: \(msg)"
        case .fileAccessError(let msg): return "文件访问错误: \(msg)"
        case .parsingError(let msg): return "数据解析错误: \(msg)"
        case .networkError(let msg): return "网络错误: \(msg)"
        }
    }
}
```

### 4. 性能优化
- **批量插入**: 使用事务批量插入数据，提高性能
- **增量处理**: 仅处理文件修改时间晚于上次同步的文件
- **内存管理**: 大文件分块读取，避免内存溢出
- **索引优化**: 数据库添加时间索引，加速查询

## 配置管理

### 用户偏好设置
```swift
extension UserPreferences {
    @AppStorage("autoSyncEnabled") var autoSyncEnabled: Bool = true
    @AppStorage("syncInterval") var syncInterval: Int = 3600 // 秒
    @AppStorage("lastFullSyncDate") var lastFullSyncDate: Date?
    @AppStorage("showSyncNotifications") var showSyncNotifications: Bool = true
}
```

### 同步间隔选项
- 15分钟 (900秒)
- 30分钟 (1800秒)  
- 1小时 (3600秒) - 默认
- 2小时 (7200秒)
- 4小时 (14400秒)
- 手动同步 (禁用定时器)

## 监控与调试

### 日志记录
```swift
extension Logger {
    static let autoSync = Logger(subsystem: "com.claudebar.autosync", category: "sync")
}

// 使用示例
Logger.autoSync.info("开始增量同步，上次同步时间: \(lastSyncTime)")
Logger.autoSync.error("同步失败: \(error.localizedDescription)")
```

### 性能指标
- 同步耗时统计
- 处理条目数量
- 数据库大小变化
- 内存使用情况

### 调试功能
- 同步日志查看器
- 手动触发全量同步
- 数据库状态检查
- JSONL 文件状态显示

## 测试策略

### 单元测试
- AutoSyncService 基本功能测试
- 定时器启停测试
- 错误处理测试
- 通知机制测试

### 集成测试
- 全量同步端到端测试
- 增量同步端到端测试
- UI 自动更新测试
- 多并发同步测试

### 性能测试
- 大数据量同步性能
- 内存使用测试
- 定时器精度测试
- UI 响应性能测试

## 部署注意事项

### 数据迁移
- 现有数据自动迁移到新的同步系统
- 兼容性检查和数据校验
- 回滚机制设计

### 向后兼容
- 保持现有 HybridUsageService API 不变
- 新功能作为可选特性添加
- 渐进式启用策略

### 资源管理
- 定时器资源清理
- 数据库连接池管理
- 内存缓存策略优化

## 预期收益

1. **用户体验提升**: 数据自动同步，无需手动刷新
2. **数据一致性**: 确保 UI 显示的数据始终是最新的
3. **性能优化**: 增量同步减少资源消耗
4. **可维护性**: 清晰的架构设计便于后续扩展
5. **可靠性**: 完善的错误处理和重试机制

## 实施计划

### 第一阶段：核心功能实现 (预计3-4天)
1. 创建 AutoSyncService 基础框架
2. 实现定时器和基本同步逻辑  
3. 集成到现有架构中

### 第二阶段：UI 集成 (预计2-3天)
1. 更新 UsageStatisticsViewModel
2. 添加同步状态显示界面
3. 实现通知机制

### 第三阶段：功能完善 (预计2-3天)
1. 添加用户设置界面
2. 实现错误处理和重试
3. 性能优化

### 第四阶段：测试与优化 (预计2-3天)
1. 单元测试和集成测试
2. 性能测试和调优
3. 文档完善

## 详细实施 TodoList

为确保项目的有序推进，以下是基于设计方案的详细任务清单，每个任务都可以独立执行，互不干扰：

### 第一阶段：核心框架搭建 (1-5)
1. **创建 AutoSyncService 基础框架和协议定义**
   - 定义 AutoSyncServiceProtocol 协议
   - 创建 AutoSyncService 类实现 ObservableObject
   - 设置基本的依赖注入结构

2. **实现 SyncError 错误类型枚举和本地化描述**
   - 创建 SyncError 枚举类型
   - 实现 LocalizedError 协议
   - 添加中文错误描述

3. **扩展 UserPreferences 添加自动同步相关设置**
   - 添加 @AppStorage 属性：autoSyncEnabled、syncInterval、lastFullSyncDate、showSyncNotifications
   - 定义同步间隔选项常量

4. **创建通知系统 - 定义 Notification.Name 扩展**
   - 添加 usageDataDidUpdate 通知
   - 添加 syncStatusDidChange 通知
   - 添加 syncProgressDidUpdate 通知

5. **实现 AutoSyncService 状态管理属性 (@Published)**
   - lastSyncTime: Date? 属性
   - isSyncing: Bool 属性
   - syncStatus: String 属性
   - syncProgress: Double 属性

### 第二阶段：定时器和同步逻辑 (6-10)
6. **实现定时器管理 - startAutoSync 和 stopAutoSync 方法**
   - Timer 实例管理
   - 定时器启动和停止逻辑
   - 防止重复启动的保护机制

7. **实现全量同步逻辑 - performFullSync 方法**
   - 扫描所有 JSONL 文件
   - 批量解析和数据插入
   - 进度更新和错误处理

8. **实现增量同步逻辑 - performIncrementalSync 方法**
   - 基于时间戳的文件变更检测
   - 增量数据解析和插入
   - 优化性能的批量处理

9. **扩展 HybridUsageService 支持批量数据插入**
   - 添加 batchInsertUsageEntries 方法
   - 实现事务批量插入优化
   - 与现有 API 保持兼容

10. **扩展 UsageStatisticsDatabase 添加时间索引优化**
    - 在时间字段上创建数据库索引
    - 优化日期范围查询性能
    - 数据库迁移脚本

### 第三阶段：UI 集成和响应 (11-15)
11. **更新 UsageStatisticsViewModel 支持通知监听**
    - 添加 NotificationCenter 监听器
    - 实现自动数据刷新逻辑
    - 处理同步状态变化

12. **创建同步状态显示组件 (进度条、状态文本)**
    - SyncStatusView 组件
    - ProgressView 集成
    - 状态文本和图标显示

13. **在使用统计页面集成同步状态显示**
    - 将 SyncStatusView 添加到 UsageStatisticsView
    - 实现状态绑定和更新
    - 优化界面布局

14. **创建设置页面的自动同步配置界面**
    - 自动同步开关
    - 同步间隔选择器
    - 同步历史记录显示

15. **实现手动同步按钮和触发逻辑**
    - 手动同步按钮组件
    - 触发同步的 Action 处理
    - 防止重复同步的逻辑

### 第四阶段：系统集成 (16-20)
16. **集成 AutoSyncService 到 AppState 全局状态**
    - 在 AppState 中添加 AutoSyncService 实例
    - 配置依赖注入
    - 确保单例模式

17. **实现同步错误处理和重试机制**
    - 指数退避重试策略
    - 错误恢复逻辑
    - 用户友好的错误提示

18. **添加 Logger 扩展用于自动同步日志记录**
    - Logger.autoSync 子系统
    - 关键操作日志记录
    - 调试信息和性能指标

19. **实现首次启动检测和自动全量同步**
    - 检查数据库是否为空
    - 首次启动时自动触发全量同步
    - 启动完成状态管理

20. **实现应用生命周期管理 (启动/退出时的定时器处理)**
    - AppDelegate 生命周期集成
    - 应用启动时启动同步服务
    - 应用退出时清理资源

### 第五阶段：测试和优化 (21-25)
21. **创建 AutoSyncService 单元测试**
    - 基本功能测试用例
    - 定时器启停测试
    - 错误处理测试

22. **创建全量和增量同步集成测试**
    - 端到端同步测试
    - 数据正确性验证
    - 并发同步测试

23. **创建 UI 自动更新响应测试**
    - 通知机制测试
    - ViewModel 自动刷新测试
    - 界面状态同步测试

24. **性能测试和内存使用优化**
    - 大数据量同步性能测试
    - 内存泄漏检测
    - 响应时间优化

25. **更新项目文档和使用说明**
    - 更新 CLAUDE.md 文档
    - 添加新功能使用说明
    - 更新构建和调试指南

### 任务执行说明
- 每个任务都设计为可独立执行，不存在强依赖关系
- 建议按阶段顺序执行，但同阶段内的任务可并行处理
- 每完成一个任务，建议运行相关测试确保代码质量
- 实施过程中如发现设计问题，可及时调整方案

---

**文档创建时间**: 2025-08-16 17:34:01 CST
**文档更新时间**: 2025-08-17 03:06:57 CST
**版本**: v1.1
**负责人**: ClaudeBar 开发团队