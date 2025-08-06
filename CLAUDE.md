# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Claude 配置管理器是一个 macOS 菜单栏应用，用于管理多个 Claude CLI 配置。它提供图形化界面来切换不同的 Claude 配置文件，替代原有的 `switch-claude.sh` 脚本功能。

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
# 验证项目结构和代码正确性
./verify.sh
```

### 在 Xcode 中开发
```bash
# 打开 Xcode 项目
open ClaudeConfigManager.xcodeproj

# 在 Xcode 中按 Cmd+R 运行项目
# 在 Xcode 中按 Cmd+B 构建项目
# 在 Xcode 中按 Cmd+U 运行测试
```

### 测试
```bash
# 运行单元测试（在 Xcode 中）
# Target: ClaudeConfigManagerTests
# 主要测试文件:
# - ConfigServiceTests.swift
# - KeychainServiceTests.swift  
# - ProcessServiceTests.swift
```

## 代码架构

### 核心架构模式
- **MVVM 架构**: 使用 SwiftUI + ViewModel 模式
- **依赖注入**: 通过协议和初始化器参数实现
- **异步编程**: 使用 Swift async/await 和 Combine
- **模块化设计**: 按功能划分 Core、Features、App 三个层次

### 主要组件层次

```
App/                     # 应用层
├── ClaudeConfigManagerApp.swift  # 应用入口
├── AppDelegate.swift            # 应用代理
└── AppState.swift              # 全局状态管理

Core/                    # 核心业务层
├── Models/
│   └── ClaudeConfig.swift      # 配置数据模型和错误类型
└── Services/
    ├── ConfigService.swift     # 配置文件管理服务
    ├── KeychainService.swift   # 钥匙串安全存储
    ├── ProcessService.swift    # Claude 进程管理
    └── Logger.swift           # 日志服务

Features/                # 功能特性层
├── ContentView.swift           # 主界面
└── MenuBar/
    ├── StatusItemManager.swift    # 菜单栏状态项管理
    ├── MenuBarView.swift         # 菜单栏界面
    └── MenuBarViewModel.swift    # 菜单栏视图模型
```

### 关键设计原则

1. **安全存储**: API Token 存储在 macOS Keychain 中，配置文件不包含敏感信息
2. **沙盒权限**: 通过用户手动选择目录来获取 `~/.claude` 的访问权限
3. **异步优先**: 所有 I/O 操作都使用异步模式，避免阻塞 UI
4. **错误处理**: 完整的错误类型定义和用户友好的错误消息
5. **状态管理**: 使用 ObservableObject 和 @Published 进行响应式状态管理

### 配置文件格式

应用管理位于 `~/.claude/` 目录中的配置文件：
- 配置文件命名: `{配置名}-settings.json`
- 当前配置: `settings.json`
- Token 存储: macOS Keychain（服务名: `claude-config-manager`）

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

1. **添加新配置字段**: 修改 `ClaudeConfig.Environment` 结构体
2. **修改 UI**: 编辑 `MenuBarView.swift` 或 `ContentView.swift`
3. **增加错误处理**: 在 `ConfigManagerError` 枚举中添加新类型
4. **调整权限**: 修改 `ClaudeConfigManager.entitlements` 文件
5. **更新图标**: 编辑 `Assets.xcassets/AppIcon.appiconset`

### 发布流程
1. 运行 `./verify.sh` 验证代码
2. 运行 `./build.sh` 构建 Release 版本
3. 应用位于 `build/export/ClaudeConfigManager.app`
4. 可选择创建 DMG 安装包（需要 create-dmg 工具）

