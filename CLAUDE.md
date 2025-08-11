# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

ClaudeBar 是一个 macOS 菜单栏应用，集成了 Claude CLI API 端点切换和使用统计功能。主要特性：
- **API 端点切换**: 管理多个 Claude CLI API 端点配置，支持图形化切换
- **使用统计**: 实时监控 Claude 使用情况，提供详细的 token 统计和成本分析
- **主窗口界面**: 提供完整的桌面界面，包含所有功能模块的导航
- **替代工具**: 替代原有的 `switch-claude.sh` 脚本功能，提供更好的用户体验

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
    ├── ConfigService.swift           # 配置文件管理
    ├── ConfigServiceCoordinator.swift # 配置服务协调器
    ├── ModernConfigService.swift     # 现代化配置服务
    ├── KeychainService.swift         # 钥匙串安全存储
    ├── ProcessService.swift          # Claude 进程管理
    ├── UsageService.swift            # 使用统计服务
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

1. **安全存储**: API Token 存储在 macOS Keychain 中，配置文件不包含敏感信息
2. **沙盒权限**: 通过用户手动选择目录来获取 `~/.claude` 的访问权限
3. **异步优先**: 所有 I/O 操作都使用异步模式，避免阻塞 UI
4. **错误处理**: 完整的错误类型定义和用户友好的错误消息
5. **状态管理**: 使用 ObservableObject 和 @Published 进行响应式状态管理
6. **实时监控**: 通过 ProcessService 和 UsageService 实现 Claude 进程和使用情况的实时监控
7. **窗口状态同步**: AppState 管理主窗口显示状态，AppDelegate 负责实际窗口操作

### 核心功能特性

#### 1. API 端点配置管理
- 支持多种配置格式（老式和新式 API 配置）
- 自动迁移 Token 到 Keychain
- 配置文件热重载

#### 2. 使用统计
- 实时解析 Claude CLI 生成的 JSONL 日志
- 按日期、模型、项目分组统计
- 精确的成本计算和 Token 统计
- 时间线图表可视化
- 支持多种统计维度（输入/输出/缓存 Token）

#### 3. 进程监控
- 实时监控 Claude 进程状态
- 检测 Claude CLI 的运行情况
- 提供进程状态指示器

### 配置文件格式

应用支持两种配置文件格式：

#### 传统格式（位于 `~/.claude/` 目录）
- 配置文件命名: `{配置名}-settings.json`
- 当前配置: `settings.json`  
- Token 存储: macOS Keychain（服务名: `claude-config-manager`）

#### 新式 API 配置格式
- 配置文件: `api-configs.json`
- 包含多个 API 端点配置
- 支持配置切换和管理

#### 使用数据文件
- 使用日志: `~/.claude/*.jsonl` 文件
- 实时解析 Claude CLI 生成的使用记录
- 支持历史数据统计和分析

### 权限和安全

- 应用使用 App Sandbox 沙盒技术
- 需要用户手动授权访问 `~/.claude` 目录
- API Token 通过 Security Framework 存储在 Keychain
- 配置文件中的 Token 会自动迁移到 Keychain

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
- 查看控制台日志了解应用状态
- 使用 Xcode 的 SwiftUI Preview 调试界面
- Keychain Access.app 可查看存储的 Token

### 常见开发任务

1. **添加新配置字段**: 修改 `ClaudeConfig` 结构体和相关的 Environment/Permissions 模型
2. **修改主界面**: 编辑 `MainPopoverView.swift` 或相关的页面组件
3. **调整使用统计**: 修改 `UsageService.swift`、`JSONLParser.swift` 或统计相关模型
4. **增加错误处理**: 在相应的错误枚举中添加新类型
5. **调整权限**: 修改 `ClaudeBar.entitlements` 文件
6. **更新图标**: 编辑 `Assets.xcassets/AppIcon.appiconset`
7. **优化性能**: 关注 `StreamingJSONLParser.swift` 和相关的异步处理逻辑
8. **窗口行为修改**: 在 `AppDelegate.swift` 中修改窗口管理逻辑，特别是 `showMainWindow()` 和 `hideMainWindow()` 方法

### 发布流程
1. 运行 `./verify.sh` 验证代码和项目结构
2. 运行 `./build.sh` 构建 Release 版本
3. 应用位于 `build/export/ClaudeBar.app`
4. 可选择创建 DMG 安装包（需要 create-dmg 工具）

### 关键调试点

#### 使用统计功能
- 日志解析: `JSONLParser.swift:parseJSONLFile`
- 统计计算: `UsageStatistics.swift:calculateStatistics`  
- 图表渲染: `TimelineChart.swift:body`
- 成本计算: `PricingModel.swift:calculateCost`

#### API 端点配置管理功能
- 配置加载: `ConfigService.swift:loadConfigurations`
- Token 管理: `KeychainService.swift:storeToken/retrieveToken`
- 配置切换: `MenuBarViewModel.swift:switchToConfiguration`

#### 进程监控功能
- 进程检测: `ProcessService.swift:checkClaudeProcess`
- 状态更新: `AppState.swift:claudeProcessStatus`

#### 窗口管理功能
- 窗口状态控制: `AppState.swift:showingMainWindow`
- 窗口显示逻辑: `AppDelegate.swift:showMainWindow/hideMainWindow`
- 关闭事件拦截: `AppDelegate.swift:windowShouldClose`
- 应用策略切换: `NSApp.setActivationPolicy(.regular/.accessory)`


- to memorize