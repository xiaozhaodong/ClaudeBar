# Claude CLI API 切换器 - 安装和使用指南

## 概述

Claude CLI API 切换器是一个 macOS 菜单栏应用，用于管理多个 Claude CLI API 端点配置。它可以替代原有的 `switch-claude.sh` 脚本，提供图形化的 API 端点切换界面。

## 系统要求

- macOS 10.15 (Catalina) 或更高版本
- 已安装 Claude CLI
- Intel 或 Apple Silicon Mac

## 安装方式

### 方式一：直接安装
1. 下载 `ClaudeConfigManager.app`
2. 将应用拖拽到 `/Applications` 文件夹
3. 双击运行应用

### 方式二：从源码构建
1. 确保安装了 Xcode 12 或更高版本
2. 克隆或下载项目源码
3. 运行构建脚本：
   ```bash
   ./build.sh
   ```
4. 从 `build/export/` 目录获取构建好的应用

## 首次运行

1. 启动应用后，你会在菜单栏看到一个终端图标
2. 如果系统提示安全警告，请按以下步骤操作：
   - 打开 `系统偏好设置` > `安全性与隐私`
   - 在 `通用` 标签页中，点击 `仍要打开`
   - 或者在终端中运行：`sudo xattr -r -d com.apple.quarantine /Applications/ClaudeConfigManager.app`

## 使用方法

### 基本操作

1. **查看配置列表**
   - 点击菜单栏的终端图标
   - 查看所有可用的配置文件

2. **切换配置**
   - 在配置列表中点击要切换的配置
   - 当前配置会用蓝色圆点标识

3. **刷新配置**
   - 点击配置列表右上角的刷新按钮
   - 或点击底部的 "刷新配置" 按钮

4. **打开配置目录**
   - 点击 "打开配置目录" 按钮
   - 直接在 Finder 中打开 `~/.claude` 目录

### 配置文件格式

应用支持现有的配置文件格式，配置文件应放置在 `~/.claude` 目录中，文件名格式为 `{配置名}-settings.json`。

示例配置文件 (`example-settings.json`)：
```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "sk-ant-xxxxx",
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "32000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "permissions": {
    "allow": [],
    "deny": []
  },
  "cleanupPeriodDays": 365,
  "includeCoAuthoredBy": false
}
```

### 状态指示

菜单栏图标会根据当前状态显示不同的图标：

- **实心终端图标** (🟢): 配置正常，Claude 可用
- **空心终端图标** (🔵): 正在加载配置
- **三角警告图标** (🟡): 配置存在问题
- **问号图标** (🔴): 无可用配置

## 故障排除

### 常见问题

1. **应用无法启动**
   - 检查 macOS 版本是否符合要求
   - 尝试重新下载应用
   - 检查是否被系统安全策略阻止

2. **找不到配置文件**
   - 确认 `~/.claude` 目录存在
   - 检查配置文件命名格式是否正确 (`*-settings.json`)
   - 点击 "刷新配置" 重新扫描

3. **配置切换失败**
   - 检查配置文件格式是否正确
   - 确认有写入 `~/.claude/settings.json` 的权限
   - 查看应用显示的错误信息

4. **菜单栏图标消失**
   - 重启应用
   - 检查是否意外退出了应用
   - 在 Activity Monitor 中查看应用是否还在运行

### 重置应用

如果遇到严重问题，可以重置应用：

1. 退出应用
2. 删除用户偏好设置：
   ```bash
   defaults delete com.claude.configmanager
   ```
3. 重新启动应用

## 卸载

1. 退出应用（点击菜单中的 "退出"）
2. 从 Applications 文件夹删除 `ClaudeConfigManager.app`
3. （可选）清理偏好设置：
   ```bash
   defaults delete com.claude.configmanager
   ```

## 隐私和安全

- 应用只读取和修改 `~/.claude` 目录中的配置文件
- 不会收集或传输任何个人数据
- API Token 等敏感信息仅在本地处理
- 应用使用 Apple 官方的 App Sandbox 沙盒技术

## 技术支持

如果遇到问题或有功能建议，请：

1. 检查本文档的故障排除部分
2. 查看应用内的错误提示信息
3. 确认你的 Claude CLI 配置是否正常工作

## 更新日志

### v1.0.0
- 初始版本发布
- 支持配置文件管理和切换
- 菜单栏集成
- 兼容现有 switch-claude.sh 脚本功能