# ClaudeBar - macOS 菜单栏 Claude CLI 管理工具

## 概述

ClaudeBar 是一个功能强大的 macOS 菜单栏应用，专为 Claude CLI 用户设计。它不仅提供了图形化的 API 端点配置管理，还集成了使用统计、进程监控等高级功能。

### 主要特性

- **SQLite 配置管理**: 使用本地数据库存储配置，支持应用内完整的增删改查操作
- **无感刷新体验**: 配置操作立即生效，无界面刷新闪烁，响应时间 < 1ms
- **使用统计分析**: 实时监控 Claude CLI 使用情况，支持令牌统计和成本分析
- **主窗口界面**: 提供完整的桌面管理界面，包含所有功能模块
- **进程监控**: 实时监控 Claude CLI 进程状态，支持启动/停止/重启
- **数据安全**: API Token 等敏感信息存储在本地，不通过网络传输

## 系统要求

- **macOS**: 15.0 或更高版本
- **架构**: Intel x86_64 和 Apple Silicon arm64
- **依赖**: Claude CLI (需要预先安装)
- **Xcode**: 15.0+ (仅构建时需要)

## 安装方式

### 方式一：从 Release 下载

1. 从 [GitHub Releases](https://github.com/xiaozhaodong/ClaudeBar/releases) 下载最新版本
2. 将 `ClaudeBar.app` 拖拽到 `/Applications` 文件夹
3. 双击运行应用(暂未提供，自行编译先)

### 方式二：从源码构建

1. 确保安装了 Xcode 15.0 或更高版本
2. 克隆项目源码：
   ```bash
   git clone https://github.com/xiaozhaodong/ClaudeBar.git
   cd ClaudeBar
   ```
3. 运行构建脚本：
   ```bash
   ./build.sh
   ```
4. 从 `build/` 目录获取构建好的应用

## 首次运行

1. 启动应用后，你会在菜单栏看到一个终端图标
2. 首次运行会显示主窗口，介绍应用功能
3. 如果系统提示安全警告，请按以下步骤操作：
   - 打开 `系统偏好设置` > `隐私与安全性`
   - 在 `安全性` 部分，点击 `仍要打开`
   - 或者在终端中运行：`sudo xattr -r -d com.apple.quarantine /Applications/ClaudeBar.app`

## 使用方法

### 菜单栏操作

1. **查看配置列表**

   - 点击菜单栏的终端图标
   - 查看所有可用的 API 配置
2. **切换配置**

   - 在配置列表中点击要切换的配置
   - 当前激活配置会有特殊标识
3. **打开主窗口**

   - 点击菜单中的 "显示主窗口"
   - 或双击菜单栏图标

### 主窗口功能

1. **配置管理**

   - 创建、编辑、删除 API 配置
   - 支持完整的配置参数设置
   - 实时预览配置效果
2. **使用统计**

   - 查看 Claude CLI 使用统计
   - 令牌消耗和成本分析
   - 支持日期范围筛选
3. **进程监控**

   - 实时监控 Claude CLI 进程状态

### 配置管理

#### SQLite 数据库存储

- **现代化存储**: 所有配置存储在本地 SQLite 数据库中
- **存储位置**: `~/Library/Application Support/ClaudeBar/`
- **应用内管理**: 支持完整的创建、编辑、删除操作，无需手动编辑文件

#### 配置创建和编辑

在主窗口的配置管理页面中：

1. **创建新配置**

   - 点击 "新建配置" 按钮
   - 填写配置名称和 API 参数
   - 设置令牌限制和权限选项
2. **编辑现有配置**

   - 选择要编辑的配置
   - 点击 "编辑" 按钮修改参数
   - 更改立即生效，无需重启
3. **配置参数**

   - **API Token**: Anthropic API 密钥
   - **Base URL**: API 端点地址

### 状态指示

菜单栏图标会根据当前状态显示不同的图标：

- **终端图标**: 正常运行状态
- **加载动画**: 正在处理配置操作
- **警告图标**: 配置或进程存在问题
- **错误图标**: 严重错误或无可用配置

## 故障排除

### 常见问题

1. **应用无法启动**

   - 检查 macOS 版本是否为 15.0 或更高
   - 确认已安装 Claude CLI
   - 检查是否被系统安全策略阻止
2. **配置数据问题**

   - 检查数据库文件是否存在：`~/Library/Application Support/ClaudeBar/`
   - 如果数据库损坏，删除数据库文件让应用重新创建
   - 在主窗口中使用 "同步配置" 功能从旧配置文件导入
3. **配置切换失败**

   - 检查 API Token 是否有效
   - 确认网络连接正常
   - 查看主窗口中的错误信息详情
4. **使用统计不显示**

   - 确认 Claude CLI 已经有使用记录
   - 检查 `~/.claude/*.jsonl` 文件是否存在
   - 在主窗口中点击 "刷新统计" 重新加载
5. **菜单栏图标消失**

   - 重启应用
   - 检查 Activity Monitor 中应用是否还在运行
   - 尝试从 Applications 文件夹重新启动

### 重置应用

如果遇到严重问题，可以重置应用：

1. 退出应用
2. 删除应用数据：
   ```bash
   rm -rf ~/Library/Application\ Support/ClaudeBar/
   defaults delete com.claudebar.app
   ```
3. 重新启动应用，会自动重新导入配置

## 卸载

1. 退出应用（点击菜单中的 "退出"）
2. 从 Applications 文件夹删除 `ClaudeBar.app`
3. （可选）清理应用数据：
   ```bash
   rm -rf ~/Library/Application\ Support/ClaudeBar/
   defaults delete com.claudebar.app
   ```

## 隐私和安全

- **本地存储**: 所有数据存储在本地 SQLite 数据库，不上传到任何服务器
- **数据安全**: API Token 等敏感信息仅在本地处理和存储
- **沙盒保护**: 使用 Apple 官方的 App Sandbox 沙盒技术
- **权限最小化**: 仅访问必要的文件和目录
- **开源透明**: 完整源码开放，可审查所有功能实现

## 技术架构

### 核心技术栈

- **Swift 5.0** + **SwiftUI**: 原生 macOS 应用开发
- **SQLite**: 本地数据库存储
- **Combine**: 响应式编程框架
- **MVVM 架构**: 清晰的代码组织结构

### 主要组件

- **配置管理**: SQLite 数据库 + 文件系统同步
- **使用统计**: 实时解析 Claude CLI 日志文件
- **进程监控**: 系统进程检测和管理
- **界面系统**: 菜单栏 + 主窗口双界面

## 开源许可

本项目采用 **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** 许可证：

- ✅ **允许**: 个人使用、学习、修改、分享
- ❌ **禁止**: 商业使用、销售、订阅服务
- 📋 **要求**: 署名原作者

详细许可条款请查看 [LICENSE.md](LICENSE.md) 文件。

## 技术支持

如果遇到问题或有功能建议：

1. 查看本文档的故障排除部分
2. 检查应用内的错误提示和日志信息
3. 在 [GitHub Issues](https://github.com/xiaozhaodong/ClaudeBar/issues) 提交问题报告
4. 确认 Claude CLI 本身工作正常

## 更新日志

### v2.0.0 (当前版本)

- **SQLite 配置管理**: 完全重构配置存储系统
- **主窗口界面**: 新增完整的桌面管理界面
- **使用统计**: 集成 Claude CLI 使用统计和成本分析
- **进程监控**: 实时监控和管理 Claude CLI 进程
- **性能优化**: 响应时间提升到 < 1ms
- **数据安全**: 本地数据库存储，无网络传输

### v1.0.0

- 初始版本发布
- 基础配置文件管理和切换
- 菜单栏集成
- 兼容 switch-claude.sh 脚本功能

---

**项目地址**: https://github.com/xiaozhaodong/ClaudeBar
**作者**: xiaozhaodong
**许可证**: CC BY-NC 4.0
