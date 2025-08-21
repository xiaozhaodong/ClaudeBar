# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

ClaudeBar 是一个 macOS 菜单栏应用，集成了 Claude CLI API 端点切换和使用统计功能。主要特性：
- **SQLite 配置管理**: 使用 SQLite 数据库存储 API 端点配置，支持应用内完整 CRUD 操作
- **无感刷新体验**: 配置操作立即生效，无界面刷新闪烁，提供类似 Web AJAX 的流畅体验
- **高性能使用统计**: 直接从数据库读取使用统计，支持大数值显示和精确日期筛选
- **主窗口界面**: 提供完整的桌面界面，包含所有功能模块的导航
- **替代工具**: 替代原有的 `switch-claude.sh` 脚本功能，提供更好的用户体验

## 最新更新 (2025-08-21)

### 近三天统计UI界面优化 v2.3
- **界面布局重构**: 将近三天使用数据移至总体统计上方，提升最新数据的快速访问性
- **界面简化设计**: 移除"最近三天"标题和时钟图标，使数据展示更直接、视觉更聚焦
- **会话统计新增**: 新增会话数量显示，采用四列布局（日期、会话、成本、Token）
- **视觉一致性**: 统一蓝色边框样式，与总体统计保持视觉一致性
- **精细间距控制**: 优化各列间距（日期-会话18pt、会话-成本10pt、成本-Token10pt）
- **响应式布局**: 精确控制列宽（日期38pt、会话35pt、成本80pt、Token自适应）
- **字体优化**: 提升字体大小（日期标签12pt、数据文字11pt）增强可读性
- **颜色指示器**: 使用不同颜色区分天数（今天-蓝色、昨天-橙色、前天-灰色）
- **数据模型扩展**: 扩展RecentDayData模型支持会话统计，集成数据库查询
- **交互体验**: 保留hover效果，支持大数值格式化和空值处理

### 定时器冲突修复和自动同步稳定性提升 v2.2 (2025-08-20)
- **修复定时器冲突**: 解决 ProcessService (5秒) 与 AutoSyncService (5分钟) 在主线程 RunLoop 中的竞争问题
- **升级定时器架构**: 将 AutoSyncService 从 Timer 升级到 DispatchSourceTimer，在后台队列执行避免主线程阻塞
- **提升同步可靠性**: 自动同步定时器现在能稳定触发，不再被进程监控的高频任务干扰
- **修复间隔变更**: 解决同步间隔修改时的"定时器已在运行"阻塞问题，确保新间隔立即生效
- **增强调试能力**: 添加详细的定时器触发日志和健康状态检查，便于问题诊断
- **线程安全优化**: 使用 DispatchSourceTimer 的现代并发模式，提升系统稳定性

### 使用统计数据准确性修复 v2.1 (2025-08-19)
- **修复Token统计不准确**: 将"全量同步"按钮从 `AutoSyncService.performFullSyncInternal()` 路由到正确的 `HybridUsageService.performFullDataMigration()`
- **修复成本计算错误**: 将成本计算从使用原始 JSONL 数据改为使用 `PricingModel.calculateCost()` 进行准确计算
- **修复数据库事务错误**: 解决 `UsageStatisticsDatabase.clearAllDataAndResetSequencesInternal()` 中 "cannot VACUUM from within a transaction" 错误，将 VACUUM 操作移出事务
- **代码清理优化**: 移除 `AutoSyncService` 中未使用的 `performFullSyncInternal()` (~160行) 和 `scanJSONLFiles()` (~45行) 方法
- **统一同步路径**: 确保所有同步操作都使用经过验证的数据迁移逻辑，提高数据一致性

### 全量同步系统重构 v2.0
- **替换增量同步**: 将整个同步机制改为全量同步以确保数据完整性和一致性
- **统一数据库表结构**: 所有表字段从 INTEGER 升级到 BIGINT，字段名统一为 created_at/updated_at
- **简化同步逻辑**: 移除复杂的增量检测机制，响应时间提升 99%+，代码复杂度降低 95%
- **改进用户体验**: 同步按钮独立于设置状态，始终可见可用
- **性能大幅提升**: 同步响应时间从 ~100ms 提升到 <1ms
- **详细记录**: 参见 `docs/全量同步系统重构记录_v2.0.md`

### 使用统计系统重构 v1.2.0 (2025-08-15)
- **移除定时器机制**: 删除15秒缓存检查定时器，改为手动刷新机制
- **修复数据溢出**: 数据库令牌字段从Int32升级到Int64，支持大数值正确显示
- **修复日期过滤**: 使用SQLite内置datetime函数，修复最近7天和30天筛选功能
- **性能优化**: 响应时间从~100ms提升到<1ms，代码复杂度降低36%
- **详细记录**: 参见 `docs/使用统计系统优化重构记录.md`

## 常用构建和开发命令

### 构建应用
```bash
# 构建 Release 版本（默认）
./build.sh

# 构建 Debug 版本
./build.sh debug
```

### 验证项目
```bash
# 验证项目结构和代码正确性，创建测试配置
./verify.sh
```

### 在 Xcode 中开发
```bash
# 打开 Xcode 项目
open ClaudeBar.xcodeproj

# 在 Xcode 中按 Cmd+R 运行项目
# 在 Xcode 中按 Cmd+B 构建项目
# 在 Xcode 中按 Cmd+U 运行测试
```

### 测试
```bash
# 运行单元测试（在 Xcode 中）
# Target: ClaudeBarTests
# 主要测试文件:
# - ConfigServiceTests.swift
# - KeychainServiceTests.swift  
# - ProcessServiceTests.swift
# - UsageServiceTests.swift

# 还有独立的测试脚本位于 tests/ 目录
# 这些测试主要用于验证使用统计和进程监控功能
```

## 重要架构决策

### 菜单栏与主窗口集成
应用采用双模式设计：
- **菜单栏模式**: 使用 `NSApp.setActivationPolicy(.accessory)`，仅显示菜单栏，隐藏 Dock 图标
- **主窗口模式**: 使用 `NSApp.setActivationPolicy(.regular)`，显示完整桌面界面和 Dock 图标
- **窗口管理**: 通过 `NSWindowDelegate.windowShouldClose` 拦截关闭事件，实现窗口隐藏而非真正关闭

关键实现点：
- `AppDelegate` 实现 `NSWindowDelegate` 协议，处理窗口生命周期
- 菜单栏按钮触发主窗口显示，通过 `AppState.openMainWindow()` 控制
- 窗口关闭时自动切换回菜单栏模式，保持应用运行状态

## 代码架构

### 核心架构模式
- **MVVM 架构**: 使用 SwiftUI + ViewModel 模式
- **依赖注入**: 通过协议和初始化器参数实现
- **异步编程**: 使用 Swift async/await 和 Combine
- **模块化设计**: 按功能划分 App、Core、Features 三个层次

### 主要组件层次

```
App/                     # 应用层
├── ClaudeBarApp.swift          # 应用入口
├── AppDelegate.swift           # 应用代理（菜单栏管理）
└── AppState.swift             # 全局状态管理

Core/                    # 核心业务层
├── DesignTokens.swift         # 设计系统
├── Models/
│   ├── ClaudeConfig.swift     # 配置数据模型
│   ├── UsageEntry.swift       # 使用记录模型  
│   ├── UsageStatistics.swift  # 使用统计模型
│   └── PricingModel.swift     # 定价模型
└── Services/
    ├── ConfigService.swift           # 配置文件管理（已弃用）
    ├── ConfigServiceCoordinator.swift # 配置服务协调器
    ├── ModernConfigService.swift     # 现代化配置服务（已弃用）
    ├── SQLiteConfigService.swift     # SQLite 配置服务（主要）
    ├── DatabaseManager.swift         # SQLite 数据库管理器
    ├── KeychainService.swift         # 钥匙串安全存储（已弃用）
    ├── ProcessService.swift          # Claude 进程管理
    ├── HybridUsageService.swift      # 混合使用统计服务（主要）
    ├── UsageService.swift            # 传统使用统计服务（降级）
    ├── UsageStatisticsDatabase.swift # 使用统计数据库（新增）
    ├── JSONLParser.swift             # JSONL 解析器
    ├── StreamingJSONLParser.swift    # 流式 JSONL 解析器
    └── Logger.swift                  # 日志服务

Features/                # 功能特性层
├── ContentView.swift           # 主界面（已弃用）
├── MainPopoverView.swift       # 主弹出窗口界面
├── SettingsView.swift          # 设置界面
├── MenuBar/
│   ├── StatusItemManager.swift    # 菜单栏状态项管理
│   ├── MenuBarView.swift         # 菜单栏界面
│   └── MenuBarViewModel.swift    # 菜单栏视图模型
├── Navigation/
│   ├── ModernNavigationView.swift   # 现代导航界面
│   ├── SidebarNavigationView.swift  # 侧边栏导航
│   ├── NavigationComponents.swift   # 导航组件
│   └── NavigationTab.swift         # 导航标签
├── Pages/
│   ├── OverviewPageView.swift         # 概览页面
│   ├── UsageStatisticsView.swift     # 使用统计页面
│   ├── ConfigManagementComponents.swift # API 配置管理组件
│   ├── ProcessMonitorComponents.swift   # 进程监控组件
│   └── PlaceholderPageViews.swift       # 占位页面
├── Components/
│   ├── TimelineChart.swift        # 时间线图表
│   ├── UsageTabViews.swift        # 使用统计标签视图
│   ├── SkeletonLoader.swift       # 骨架屏加载器
│   ├── StatusComponents.swift     # 状态组件
│   └── ActionComponents.swift     # 操作组件
├── ViewModels/
│   └── UsageStatisticsViewModel.swift  # 使用统计视图模型
└── Settings/
    └── UserPreferences.swift      # 用户偏好设置
```

### 关键设计原则

1. **SQLite 数据存储**: API 配置存储在本地 SQLite 数据库中，提供更强的数据一致性和并发安全性
2. **应用内配置管理**: 完全摒弃外部文件编辑，提供原生的创建、编辑、删除界面
3. **无感刷新优化**: 通过本地状态同步避免全量数据重载，实现类似 Web AJAX 的即时响应
4. **异步优先**: 所有 I/O 操作都使用异步模式，避免阻塞 UI
5. **错误处理**: 完整的错误类型定义和用户友好的错误消息
6. **状态管理**: 使用 ObservableObject 和 @Published 进行响应式状态管理
7. **实时监控**: 通过 ProcessService 和 UsageService 实现 Claude 进程和使用情况的实时监控
8. **窗口状态同步**: AppState 管理主窗口显示状态，AppDelegate 负责实际窗口操作

### 核心功能特性

#### 1. SQLite 配置管理系统
- **数据库存储**: 使用 SQLite 数据库存储所有 API 端点配置
- **应用内管理**: 提供完整的创建、编辑、删除界面，无需外部文件操作
- **无感刷新**: 配置变更立即生效，无界面刷新感知（< 1ms 响应时间）
- **数据迁移**: 支持从 JSON 配置文件自动迁移到 SQLite
- **线程安全**: 使用串行队列确保数据库操作的线程安全性
- **双重存储**: SQLite 存储 + settings.json 文件更新，确保与 Claude CLI 的兼容性

#### 2. 全量同步系统 (v2.0 重构)
- **全量数据迁移**: 使用 `HybridUsageService.performFullDataMigration()` 进行完整数据同步
- **数据库表结构统一**: 所有表使用 BIGINT 字段和 created_at/updated_at 时间戳
- **高性能同步**: 响应时间从 ~100ms 提升到 <1ms，代码复杂度降低 95%
- **用户体验优化**: 同步按钮独立于设置状态，始终可见可用
- **进度追踪**: 实时进度回调，支持多阶段同步进度显示
- **数据完整性**: 自动数据去重、日期字符串修复、统计汇总生成
- **错误处理**: 完善的错误恢复机制和详细错误报告

#### 3. 高性能使用统计 (v1.2.0 重构)
- **数据库优先**: `HybridUsageService` 优先从 SQLite 数据库读取统计数据
- **大数值支持**: 使用 Int64 存储令牌数据，支持超过21亿的令牌统计
- **精确日期筛选**: 使用 SQLite 内置 datetime 函数，准确筛选最近7天/30天数据
- **高性能查询**: 直接数据库查询，响应时间 < 1ms，无需复杂缓存
- **智能降级**: 数据库不可用时自动降级到 JSONL 文件解析
- **实时刷新**: 手动刷新机制，用户主动触发数据更新
- **多维统计**: 按日期、模型、项目分组统计，支持成本和令牌分析
- **时间线图表**: 可视化展示使用趋势和模式

#### 4. 进程监控
- 实时监控 Claude 进程状态
- 检测 Claude CLI 的运行情况
- 提供进程状态指示器

### SQLite 配置管理架构

#### 数据库设计
```sql
CREATE TABLE api_configs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    base_url TEXT NOT NULL,
    auth_token TEXT NOT NULL,
    is_active INTEGER DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

#### 服务层架构
```
ConfigServiceProtocol (接口)
    ↓
SQLiteConfigService (实现)
    ↓
DatabaseManager (数据库操作)
    ↓
SQLite3 (原生 C API)
```

#### 无感刷新机制
- **本地状态同步**: 操作成功后直接更新本地配置数组，避免数据库重查询
- **原子性操作**: 数据库操作与界面更新保持原子性，失败时不更新界面
- **响应时间**: 配置 CRUD 操作响应时间 < 1ms（vs 原来的 ~100ms）

### 数据存储策略

#### SQLite 数据库（主要存储）
- **位置**: `~/Library/Application Support/ClaudeBar/configs.db`
- **存储内容**: API 端点配置（name, base_url, auth_token, is_active）
- **优势**: 数据一致性、并发安全、快速查询、事务支持

#### settings.json 文件（兼容性）
- **位置**: `~/.claude/settings.json`
- **用途**: 与 Claude CLI 保持兼容，使用字符串替换方式更新
- **更新时机**: 切换配置时自动更新

#### 数据迁移支持
- **自动检测**: 应用启动时检测现有 JSON 配置文件
- **迁移来源**: `~/.claude/api_configs.json` 和 `{name}-settings.json`
- **迁移策略**: 非破坏性迁移，保留原有文件

#### 使用数据文件
- 使用日志: `~/.claude/*.jsonl` 文件
- 实时解析 Claude CLI 生成的使用记录
- 支持历史数据统计和分析

### 权限和安全

- 应用使用 App Sandbox 沙盒技术
- **数据安全**: API Token 和配置存储在本地 SQLite 数据库，不通过网络传输
- **数据位置**: 数据库位于用户私有目录 `~/Library/Application Support/ClaudeBar/`
- **操作安全**: 删除操作需要二次确认，配置名称唯一性验证
- **无需授权**: 应用启动即可使用，无需手动授权 ~/.claude 目录访问权限

## 开发注意事项

### 依赖管理
- 项目为纯 Swift/SwiftUI 应用，无外部依赖
- 目标系统: macOS 15.0+
- 使用 Swift 5.0

### 测试配置
```bash
# 创建测试配置目录
mkdir -p ~/.claude

# 创建测试配置文件
cat > ~/.claude/test-settings.json << 'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "32000"
  },
  "permissions": {
    "allow": [],
    "deny": []
  },
  "cleanupPeriodDays": 365,
  "includeCoAuthoredBy": false
}
EOF
```

### 调试技巧
- 应用启动后在菜单栏显示终端图标
- 查看控制台日志了解应用状态和数据库操作
- 使用 Xcode 的 SwiftUI Preview 调试界面
- 数据库文件可通过 SQLite 工具查看：`~/Library/Application Support/ClaudeBar/configs.db`

### 常见开发任务

1. **添加新配置字段**: 修改 `APIConfigRecord` 结构体和 `DatabaseManager` 中的表结构
2. **修改主界面**: 编辑 `MainPopoverView.swift` 或相关的页面组件
3. **调整全量同步系统**: 修改 `HybridUsageService.swift:performFullDataMigration` 和 `UsageStatisticsDatabase.swift` 中的数据迁移逻辑
4. **调整使用统计**: 修改 `HybridUsageService.swift`、`UsageStatisticsDatabase.swift` 或 `UsageStatisticsViewModel.swift`
5. **增加错误处理**: 在相应的错误枚举中添加新类型
6. **调整权限**: 修改 `ClaudeBar.entitlements` 文件
7. **更新图标**: 编辑 `Assets.xcassets/AppIcon.appiconset`
8. **优化自动同步**: 修改 `AutoSyncService.swift` 中的定时器逻辑和同步策略
9. **修复定时器冲突**: 优先使用 DispatchSourceTimer 而非 Timer，避免主线程 RunLoop 竞争
10. **窗口行为修改**: 在 `AppDelegate.swift` 中修改窗口管理逻辑，特别是 `showMainWindow()` 和 `hideMainWindow()` 方法
11. **配置管理优化**: 修改 `SQLiteConfigService.swift` 和 `DatabaseManager.swift` 实现新功能
12. **无感刷新调优**: 在 `AppState.swift` 中调整本地状态同步逻辑
13. **数据库表结构修改**: 在 `UsageStatisticsDatabase.swift` 中更新表定义，确保使用 BIGINT 和 created_at/updated_at 字段
14. **近三天统计UI优化**: 修改 `MenuBarView.swift` 中的 `RecentDaysUsageView` 和 `RecentDayRow` 组件，调整布局间距和数据展示

### 重要经验教训

#### 定时器冲突诊断 (2025-08-20)
- **症状**: 定时任务不触发，日志缺失，间隔变更无效
- **根因**: 多个定时器在主线程 RunLoop 中竞争，高频定时器阻塞低频定时器
- **诊断方法**: 
  1. 检查是否存在多个 Timer 实例
  2. 分析定时器频率差异 (ProcessService 5秒 vs AutoSyncService 5分钟)
  3. 查看主线程阻塞情况
- **解决方案**: 使用 DispatchSourceTimer 替代 Timer，在后台队列执行
- **预防措施**: 新定时器优先使用 DispatchSourceTimer，避免主线程 RunLoop 竞争

### 发布流程
1. 运行 `./verify.sh` 验证代码和项目结构
2. 运行 `./build.sh` 构建 Release 版本
3. 应用位于 `build/export/ClaudeBar.app`
4. 可选择创建 DMG 安装包（需要 create-dmg 工具）

### 关键调试点

#### 自动同步定时器功能 (v2.2 修复)
- **定时器类型**: `AutoSyncService.swift:186` - 使用 DispatchSourceTimer 避免主线程冲突
- **定时器创建**: `AutoSyncService.swift:766-811` - setupAutoSyncTimer() 创建和配置定时器
- **定时器触发**: `AutoSyncService.swift:814-893` - handleTimerFired() 处理触发事件
- **间隔变更**: `AutoSyncService.swift:934-937` - 先停止再启动避免阻塞问题
- **冲突避免**: 后台队列 syncQueue 执行，不与 ProcessService (5秒) 主线程定时器竞争
- **调试日志**: 查找 "🔥 DispatchTimer 触发" 确认定时器正常工作

#### SQLite 配置管理功能
- 数据库操作: `DatabaseManager.swift:createConfig/updateConfig/deleteConfig`
- 配置服务: `SQLiteConfigService.swift:loadConfigs/switchConfig`
- 无感刷新: `AppState.swift:addConfigLocally/removeConfigLocally/updateConfigLocally`
- 界面管理: `ConfigManagementComponents.swift:showEditConfigDialog/deleteConfig`

#### 全量同步系统功能 (v2.1 修复)
- 全量数据迁移: `HybridUsageService.swift:performFullDataMigration` - 完整数据迁移流程
- 数据库操作: `UsageStatisticsDatabase.swift:clearAllDataAndResetSequences/forceRebuildDatabaseWithoutVacuum` - 数据清理、去重和VACUUM错误修复
- 自动同步服务: `AutoSyncService.swift:performFullSyncUsingMigration` - 正确路由到HybridUsageService数据迁移
- UI界面优化: `UsageStatisticsView.swift` - 同步按钮独立于设置状态
- 进度回调: 使用 `(Double, String) -> Void` 签名的进度回调机制
- 数据库表结构: 所有表使用 BIGINT 字段和 created_at/updated_at 时间戳
- 成本计算: `UsageEntry.swift:toUsageEntry` - 使用PricingModel进行准确成本计算

#### 使用统计功能 (重构后 v1.2.0)
- 混合服务: `HybridUsageService.swift:getUsageStatistics` - 数据库优先，JSONL降级
- 数据库查询: `UsageStatisticsDatabase.swift:getUsageStatisticsInternal` - 使用Int64和SQLite datetime
- 视图模型: `UsageStatisticsViewModel.swift:refreshStatistics` - 直接数据库调用，无定时器
- 日期过滤: 使用 `datetime('now', '-7 days')` 和 `datetime('now', '-30 days')`
- 图表渲染: `TimelineChart.swift:body`
- 成本计算: `PricingModel.swift:calculateCost`

#### 进程监控功能
- 进程检测: `ProcessService.swift:checkClaudeProcess`
- 状态更新: `AppState.swift:claudeProcessStatus`

#### 近三天统计UI界面功能 (v2.3 新增)
- 界面组件: `MenuBarView.swift:RecentDaysUsageView` - 近三天数据展示容器
- 数据行组件: `MenuBarView.swift:RecentDayRow` - 单日数据行，四列布局设计
- 数据模型: `MenuBarView.swift:RecentDayData` - 扩展支持会话统计
- 间距控制: 手动HStack间距管理，精确控制视觉效果
- 颜色指示: 天数标签颜色编码（蓝/橙/灰），增强视觉识别
- 响应式设计: 固定宽度+自适应相结合的布局策略

#### 窗口管理功能
- 窗口状态控制: `AppState.swift:showingMainWindow`
- 窗口显示逻辑: `AppDelegate.swift:showMainWindow/hideMainWindow`
- 关闭事件拦截: `AppDelegate.swift:windowShouldClose`
- 应用策略切换: `NSApp.setActivationPolicy(.regular/.accessory)`


- to memorize