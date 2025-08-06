//
//  ConfigManagementComponents.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI

// MARK: - 配置管理页面组件

struct ConfigManagementHeader: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("配置管理")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("管理您的 Claude CLI 配置文件")
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
            await appState.loadConfigs()
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
                    
                    Text("当前使用的配置")
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
                        label: "配置名称",
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
                        label: "配置状态",
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
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            let configFileURL = configDirectory.appendingPathComponent("settings.json")
            NSWorkspace.shared.open(configFileURL)
        }
    }
    
    private func openConfigDirectory() {
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            NSWorkspace.shared.open(configDirectory)
        }
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
                Text("所有配置")
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
                        Text("新建配置")
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
        // 打开配置目录，让用户手动创建配置
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            NSWorkspace.shared.open(configDirectory)
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
        appState.isLoading || isCurrentConfig
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
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 12))
                            Text("切换")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isDisabled)
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
                    
                    Button(action: duplicateConfig) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.green.opacity(0.1))
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
        guard !appState.isLoading else { return }
        guard !isCurrentConfig else { return }
        
        Task {
            await appState.switchConfig(config)
        }
    }
    
    private func editConfig() {
        // 打开配置文件进行编辑
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            let configFileURL = configDirectory.appendingPathComponent("\(config.name)-settings.json")
            NSWorkspace.shared.open(configFileURL)
        }
    }
    
    private func duplicateConfig() {
        // 复制配置文件（简单实现，打开目录让用户手动操作）
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            NSWorkspace.shared.open(configDirectory)
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
                Text("没有找到配置文件")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("请在 ~/.claude 目录中创建配置文件")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("打开配置目录") {
                if let configService = appState.configService as? ConfigService {
                    let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
                    NSWorkspace.shared.open(configDirectory)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// SkeletonConfigRow 已在 StatusComponents.swift 中定义