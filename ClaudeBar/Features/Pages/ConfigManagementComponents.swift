//
//  ConfigManagementComponents.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI

// MARK: - API 配置管理页面组件

struct ConfigManagementHeader: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API 端点管理")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("管理您的 Claude API 端点配置")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 刷新按钮
                if appState.isLoading {
                    ProgressView()
                        .frame(width: 20, height: 20)
                        .scaleEffect(0.8)
                        .controlSize(.small)
                } else {
                    Button(action: refreshConfigs) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                            Text("刷新")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 1)
        }
    }
    
    private func refreshConfigs() {
        guard !appState.isLoading else { return }
        Task {
            await appState.forceRefreshConfigs()
        }
    }
}

struct CurrentConfigDetailCard: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        if let currentConfig = appState.currentConfig {
            VStack(alignment: .leading, spacing: 20) {
                // 卡片标题
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                    
                    Text("当前使用的 API 端点")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 状态指示器
                    StatusIndicatorDot()
                }
                
                // 配置详情网格
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], alignment: .leading, spacing: 16) {
                    ConfigDetailItem(
                        icon: "text.badge.checkmark",
                        label: "端点名称",
                        value: currentConfig.name,
                        valueColor: .primary
                    )
                    
                    ConfigDetailItem(
                        icon: "link",
                        label: "API 端点",
                        value: currentConfig.baseURLDisplay,
                        valueColor: .secondary
                    )
                    
                    ConfigDetailItem(
                        icon: "key.fill",
                        label: "认证状态",
                        value: currentConfig.env.anthropicAuthToken != nil ? "已配置" : "未配置",
                        valueColor: currentConfig.env.anthropicAuthToken != nil ? .green : .orange
                    )
                    
                    ConfigDetailItem(
                        icon: "checkmark.shield.fill",
                        label: "端点状态",
                        value: currentConfig.isValid ? "正常" : "异常",
                        valueColor: currentConfig.isValid ? .green : .red
                    )
                }
                
                // 操作按钮
                HStack(spacing: 12) {
                    Button(action: openConfigFile) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 12))
                            Text("查看文件")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: openConfigDirectory) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                            Text("打开目录")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.3), lineWidth: 2)
                    )
            )
        }
    }
    
    private func openConfigFile() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let settingsFile = homeDirectory.appendingPathComponent(".claude/settings.json")
        
        // 确保文件存在
        if FileManager.default.fileExists(atPath: settingsFile.path) {
            NSWorkspace.shared.open(settingsFile)
        } else {
            // 如果 settings.json 不存在，打开 api_configs.json
            let apiConfigFile = homeDirectory.appendingPathComponent(".claude/api_configs.json")
            NSWorkspace.shared.open(apiConfigFile)
        }
    }
    
    private func openConfigDirectory() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let claudeDirectory = homeDirectory.appendingPathComponent(".claude")
        NSWorkspace.shared.open(claudeDirectory)
    }
}

struct ConfigDetailItem: View {
    let icon: String
    let label: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 16)
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(valueColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
        )
    }
}

struct ConfigurationsList: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 列表头部
            HStack {
                Text("所有 API 端点")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                if !appState.availableConfigs.isEmpty {
                    Text("(\(appState.availableConfigs.count))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: createNewConfig) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("新建端点")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 配置列表内容
            if appState.isLoading {
                ConfigListLoadingView()
            } else if appState.availableConfigs.isEmpty {
                ConfigListEmptyView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.availableConfigs) { config in
                        ConfigManagementRowView(config: config)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    private func createNewConfig() {
        // 显示新建配置对话框
        showNewConfigDialog()
    }
    
    private func showNewConfigDialog() {
        let alert = NSAlert()
        alert.messageText = "新建 API 端点配置"
        alert.informativeText = "请输入新配置的详细信息"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        
        // 使用简单的容器视图，精确控制布局，给按钮留出足够空间
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 180))
        
        // 配置名称标签和输入框
        let nameLabel = NSTextField(labelWithString: "端点名称:")
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.frame = NSRect(x: 0, y: 150, width: 100, height: 17)
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = NSColor.clear
        
        let nameField = NSTextField(frame: NSRect(x: 0, y: 125, width: 350, height: 22))
        nameField.placeholderString = "例如：work, personal, claude-3-5"
        
        // Base URL 标签和输入框
        let urlLabel = NSTextField(labelWithString: "API Base URL:")
        urlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        urlLabel.frame = NSRect(x: 0, y: 95, width: 100, height: 17)
        urlLabel.isEditable = false
        urlLabel.isBordered = false
        urlLabel.backgroundColor = NSColor.clear
        
        let baseUrlField = NSTextField(frame: NSRect(x: 0, y: 70, width: 350, height: 22))
        baseUrlField.placeholderString = "https://api.anthropic.com"
        baseUrlField.stringValue = "https://api.anthropic.com"
        
        // Auth Token 标签和输入框
        let tokenLabel = NSTextField(labelWithString: "Auth Token:")
        tokenLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        tokenLabel.frame = NSRect(x: 0, y: 40, width: 100, height: 17)
        tokenLabel.isEditable = false
        tokenLabel.isBordered = false
        tokenLabel.backgroundColor = NSColor.clear
        
        let tokenField = NSSecureTextField(frame: NSRect(x: 0, y: 15, width: 350, height: 22))
        tokenField.placeholderString = "sk-ant-api03-xxxxxxxxxxxxxxx"
        
        // 添加到容器视图
        containerView.addSubview(nameLabel)
        containerView.addSubview(nameField)
        containerView.addSubview(urlLabel)
        containerView.addSubview(baseUrlField)
        containerView.addSubview(tokenLabel)
        containerView.addSubview(tokenField)
        
        alert.accessoryView = containerView
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let configName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseUrl = baseUrlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 验证输入
            guard !configName.isEmpty else {
                appState.showErrorMessage("端点名称不能为空")
                return
            }
            
            guard !token.isEmpty else {
                appState.showErrorMessage("Auth Token 不能为空")
                return
            }
            
            // 创建新配置
            let env = ClaudeConfig.Environment(
                anthropicAuthToken: token,
                anthropicBaseURL: baseUrl.isEmpty ? "https://api.anthropic.com" : baseUrl,
                claudeCodeMaxOutputTokens: "32000",
                claudeCodeDisableNonessentialTraffic: "1"
            )
            
            let newConfig = ClaudeConfig(
                name: configName,
                env: env,
                permissions: ClaudeConfig.Permissions(allow: [], deny: []),
                cleanupPeriodDays: 365,
                includeCoAuthoredBy: false
            )
            
            Task {
                do {
                    try await appState.configService.createConfig(newConfig)
                    appState.showSuccessMessage("成功创建 API 端点「\(configName)」")
                    await appState.forceRefreshConfigs()
                } catch {
                    appState.showErrorMessage("创建端点失败：\(error.localizedDescription)")
                }
            }
        }
    }
}

struct ConfigManagementRowView: View {
    let config: ClaudeConfig
    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    
    private var isCurrentConfig: Bool {
        appState.currentConfig?.name == config.name
    }
    
    private var isDisabled: Bool {
        isCurrentConfig
    }
    
    private var isSwitchingThisConfig: Bool {
        appState.isSwitchingConfig && !isCurrentConfig
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 状态指示器
            VStack {
                ZStack {
                    Circle()
                        .stroke(statusBorderColor, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isCurrentConfig {
                        Circle()
                            .fill(statusFillColor)
                            .frame(width: 10, height: 10)
                    }
                }
                
                Spacer()
            }
            
            // 配置信息
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(config.name)
                        .font(.system(size: 16, weight: isCurrentConfig ? .semibold : .medium))
                        .foregroundColor(.primary)
                    
                    if isCurrentConfig {
                        Text("当前")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    // 配置状态图标
                    Image(systemName: config.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(config.isValid ? .green : .orange)
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API 端点")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(config.baseURLDisplay)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("认证状态")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(config.env.anthropicAuthToken != nil ? "已配置" : "未配置")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(config.env.anthropicAuthToken != nil ? .green : .orange)
                    }
                }
            }
            
            // 操作按钮
            VStack(spacing: 8) {
                if !isCurrentConfig {
                    Button(action: switchToConfig) {
                        HStack(spacing: 4) {
                            if isSwitchingThisConfig {
                                ProgressView()
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(0.7)
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 12))
                            }
                            Text("切换")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSwitchingThisConfig ? Color.blue.opacity(0.7) : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isDisabled || isSwitchingThisConfig)
                }
                
                HStack(spacing: 8) {
                    Button(action: editConfig) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: deleteConfig) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(backgroundFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .scaleEffect(isHovered && !isDisabled ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var statusBorderColor: Color {
        if isCurrentConfig {
            return .blue
        } else {
            return config.isValid ? .green : .orange
        }
    }
    
    private var statusFillColor: Color {
        return .blue
    }
    
    private var backgroundFill: Color {
        if isCurrentConfig {
            return Color.blue.opacity(0.05)
        } else if isHovered && !isDisabled {
            return Color(.controlBackgroundColor).opacity(0.8)
        } else {
            return Color(.windowBackgroundColor)
        }
    }
    
    private var borderColor: Color {
        if isCurrentConfig {
            return Color.blue.opacity(0.3)
        } else if isHovered && !isDisabled {
            return Color.blue.opacity(0.2)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
    
    private func switchToConfig() {
        guard !appState.isSwitchingConfig else { return }
        guard !isCurrentConfig else { return }
        
        Task {
            await appState.switchConfig(config)
        }
    }
    
    private func editConfig() {
        // 显示编辑配置对话框
        showEditConfigDialog()
    }
    
    private func showEditConfigDialog() {
        let alert = NSAlert()
        alert.messageText = "编辑 API 端点配置"
        alert.informativeText = "修改「\(config.name)」的配置信息"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        
        // 创建编辑表单容器
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 180))
        
        // 配置名称标签和输入框
        let nameLabel = NSTextField(labelWithString: "端点名称:")
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.frame = NSRect(x: 0, y: 150, width: 100, height: 17)
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = NSColor.clear
        
        let nameField = NSTextField(frame: NSRect(x: 0, y: 125, width: 350, height: 22))
        nameField.stringValue = config.name
        nameField.placeholderString = "例如：work, personal, claude-3-5"
        
        // Base URL 标签和输入框
        let urlLabel = NSTextField(labelWithString: "API Base URL:")
        urlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        urlLabel.frame = NSRect(x: 0, y: 95, width: 100, height: 17)
        urlLabel.isEditable = false
        urlLabel.isBordered = false
        urlLabel.backgroundColor = NSColor.clear
        
        let baseUrlField = NSTextField(frame: NSRect(x: 0, y: 70, width: 350, height: 22))
        baseUrlField.stringValue = config.env.anthropicBaseURL ?? "https://api.anthropic.com"
        baseUrlField.placeholderString = "https://api.anthropic.com"
        
        // Auth Token 标签和输入框
        let tokenLabel = NSTextField(labelWithString: "Auth Token:")
        tokenLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        tokenLabel.frame = NSRect(x: 0, y: 40, width: 100, height: 17)
        tokenLabel.isEditable = false
        tokenLabel.isBordered = false
        tokenLabel.backgroundColor = NSColor.clear
        
        let tokenField = NSSecureTextField(frame: NSRect(x: 0, y: 15, width: 350, height: 22))
        tokenField.stringValue = config.env.anthropicAuthToken ?? ""
        tokenField.placeholderString = "sk-ant-api03-xxxxxxxxxxxxxxx"
        
        // 添加到容器视图
        containerView.addSubview(nameLabel)
        containerView.addSubview(nameField)
        containerView.addSubview(urlLabel)
        containerView.addSubview(baseUrlField)
        containerView.addSubview(tokenLabel)
        containerView.addSubview(tokenField)
        
        alert.accessoryView = containerView
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let configName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseUrl = baseUrlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 验证输入
            guard !configName.isEmpty else {
                appState.showErrorMessage("端点名称不能为空")
                return
            }
            
            guard !token.isEmpty else {
                appState.showErrorMessage("Auth Token 不能为空")
                return
            }
            
            // 创建更新后的配置
            let env = ClaudeConfig.Environment(
                anthropicAuthToken: token,
                anthropicBaseURL: baseUrl.isEmpty ? "https://api.anthropic.com" : baseUrl,
                claudeCodeMaxOutputTokens: "32000",
                claudeCodeDisableNonessentialTraffic: "1"
            )
            
            let updatedConfig = ClaudeConfig(
                name: configName,
                env: env,
                permissions: ClaudeConfig.Permissions(allow: [], deny: []),
                cleanupPeriodDays: 365,
                includeCoAuthoredBy: false
            )
            
            Task {
                do {
                    // 使用更新方法而不是删除再创建
                    let sqliteService = appState.configService as! SQLiteConfigService
                    try await sqliteService.updateConfig(config, updatedConfig)
                    appState.showSuccessMessage("成功更新 API 端点「\(configName)」")
                    await appState.forceRefreshConfigs()
                } catch {
                    appState.showErrorMessage("更新端点失败：\(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteConfig() {
        // 删除配置确认对话框
        let alert = NSAlert()
        alert.messageText = "删除 API 端点"
        alert.informativeText = "确定要删除 API 端点「\(config.name)」吗？此操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Task {
                do {
                    try await appState.configService.deleteConfig(config)
                    appState.showSuccessMessage("已删除 API 端点「\(config.name)」")
                    await appState.forceRefreshConfigs()
                } catch {
                    appState.showErrorMessage("删除端点失败：\(error.localizedDescription)")
                }
            }
        }
    }
}

struct ConfigListLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonConfigRow()
            }
        }
    }
}

struct ConfigListEmptyView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("没有找到 API 端点")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("请通过应用程序创建 API 端点配置")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("打开目录") {
                let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
                let claudeDirectory = homeDirectory.appendingPathComponent(".claude")
                NSWorkspace.shared.open(claudeDirectory)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// SkeletonConfigRow 已在 StatusComponents.swift 中定义