//
//  SettingsView.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI
import Foundation
import AppKit

// MARK: - Main Settings View

struct SettingsView: View {
    @EnvironmentObject private var userPreferences: UserPreferences
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: SettingsTab = .general
    @State private var isResetDialogPresented = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航栏
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedTab == tab ? .white : .secondary)
                                .frame(width: 20)
                            
                            Text(tab.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedTab == tab ? .white : .primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // 重置按钮
                Button("重置设置") {
                    isResetDialogPresented = true
                }
                .foregroundColor(.red)
                .font(.system(size: 13))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .frame(width: 200)
            .padding(.vertical, 20)
            .background(Color(.controlBackgroundColor))
            
            // 右侧内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 标题
                    HStack {
                        Image(systemName: selectedTab.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.accentColor)
                        
                        Text(selectedTab.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    // 内容区域
                    selectedTab.contentView
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 600)
        .alert("重置设置", isPresented: $isResetDialogPresented) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                userPreferences.resetToDefaults()
            }
        } message: {
            Text("此操作将重置所有设置到默认值，此操作不可撤销。")
        }
    }
}

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable {
    case general = "general"
    case autoSync = "autoSync"
    case notifications = "notifications"
    case appearance = "appearance"
    case advanced = "advanced"
    case about = "about"
    
    var title: String {
        switch self {
        case .general: return "通用"
        case .appearance: return "外观"
        case .notifications: return "通知"
        case .autoSync: return "自动同步"
        case .advanced: return "高级"
        case .about: return "关于"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .appearance: return "paintbrush"
        case .notifications: return "bell"
        case .autoSync: return "arrow.triangle.2.circlepath"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
    
    @ViewBuilder
    var contentView: some View {
        switch self {
        case .general:
            GeneralSettingsSection()
        case .appearance:
            AppearanceSettingsSection()
        case .notifications:
            NotificationSettingsSection()
        case .autoSync:
            AutoSyncSettingsSection()
        case .advanced:
            AdvancedSettingsSection()
        case .about:
            AboutSettingsSection()
        }
    }
}

// MARK: - General Settings Section

struct GeneralSettingsSection: View {
    @EnvironmentObject private var userPreferences: UserPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("应用行为")
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ModernSettingRow(
                    icon: "power",
                    title: "开机自启动",
                    description: "系统启动时自动启动应用",
                    control: AnyView(
                        Toggle("", isOn: $userPreferences.launchAtLogin)
                            .controlSize(.small)
                    )
                )
                
                ModernSettingRow(
                    icon: "dock.rectangle",
                    title: "隐藏 Dock 图标",
                    description: "仅在菜单栏显示应用图标",
                    control: AnyView(
                        Toggle("", isOn: $userPreferences.hideDockIcon)
                            .controlSize(.small)
                    )
                )
                
                ModernSettingRow(
                    icon: "menubar.rectangle",
                    title: "显示在状态栏",
                    description: "在系统状态栏显示应用图标",
                    control: AnyView(
                        Toggle("", isOn: $userPreferences.showInStatusBar)
                            .controlSize(.small)
                    )
                )
            }
        }
        .padding(DesignTokens.Spacing.Page.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

// MARK: - Appearance Settings Section

struct AppearanceSettingsSection: View {
    @EnvironmentObject private var userPreferences: UserPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 外观主题
            VStack(alignment: .leading, spacing: 16) {
                Text("外观主题")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    ModernSettingRow(
                        icon: "circle.lefthalf.filled",
                        title: "主题",
                        description: "选择应用外观主题",
                        control: AnyView(
                            Picker("", selection: $userPreferences.colorScheme) {
                                Text("跟随系统").tag("auto")
                                Text("浅色").tag("light")
                                Text("深色").tag("dark")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                        )
                    )
                    
                    ModernSettingRow(
                        icon: "paintpalette",
                        title: "主色调",
                        description: "应用的主色调",
                        control: AnyView(
                            Picker("", selection: $userPreferences.accentColor) {
                                Text("蓝色").tag("blue")
                                Text("绿色").tag("green")
                                Text("橙色").tag("orange")
                                Text("紫色").tag("purple")
                                Text("红色").tag("red")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 100)
                        )
                    )
                }
            }
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            // 字体设置
            VStack(alignment: .leading, spacing: 16) {
                Text("字体设置")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    ModernSettingRow(
                        icon: "textformat.size",
                        title: "字体大小",
                        description: "调整界面字体大小",
                        control: AnyView(
                            VStack(spacing: 4) {
                                Slider(
                                    value: $userPreferences.fontSize,
                                    in: 12...18,
                                    step: 1
                                )
                                .frame(width: 150)
                                
                                Text("\(Int(userPreferences.fontSize))pt")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        )
                    )
                }
            }
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            // 界面设置
            VStack(alignment: .leading, spacing: 16) {
                Text("界面设置")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    ModernSettingRow(
                        icon: "rectangle.compress.vertical",
                        title: "紧凑模式",
                        description: "使用更紧凑的界面布局",
                        control: AnyView(
                            Toggle("", isOn: $userPreferences.compactMode)
                                .controlSize(.small)
                        )
                    )
                    
                    ModernSettingRow(
                        icon: "sparkles",
                        title: "启用动画",
                        description: "界面切换和状态变化动画",
                        control: AnyView(
                            Toggle("", isOn: $userPreferences.enableAnimations)
                                .controlSize(.small)
                        )
                    )
                    
                    ModernSettingRow(
                        icon: "terminal",
                        title: "菜单栏图标样式",
                        description: "菜单栏显示的图标样式",
                        control: AnyView(
                            Picker("", selection: $userPreferences.menuBarIconStyle) {
                                Text("终端").tag("terminal")
                                Text("齿轮").tag("gear")
                                Text("圆形").tag("circle")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 100)
                        )
                    )
                }
            }
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }
}

// MARK: - Notification Settings Section

struct NotificationSettingsSection: View {
    @EnvironmentObject private var userPreferences: UserPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 通知设置
            VStack(alignment: .leading, spacing: 16) {
                Text("通知设置")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    ModernSettingRow(
                        icon: "checkmark.circle",
                        title: "成功通知",
                        description: "操作成功时显示通知",
                        control: AnyView(
                            Toggle("", isOn: $userPreferences.showSuccessNotifications)
                                .controlSize(.small)
                        )
                    )
                    
                    ModernSettingRow(
                        icon: "exclamationmark.triangle",
                        title: "错误通知",
                        description: "操作失败时显示通知",
                        control: AnyView(
                            Toggle("", isOn: $userPreferences.showErrorNotifications)
                                .controlSize(.small)
                        )
                    )
                }
            }
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }
}

// MARK: - Auto Sync Settings Section

struct AutoSyncSettingsSection: View {
    @EnvironmentObject private var userPreferences: UserPreferences
    @EnvironmentObject private var appState: AppState
    @State private var showingManualSyncAlert = false
    @State private var isPerformingManualSync = false
    
    /*
    var autoSyncService: AutoSyncService {
        // 通过AppState获取AutoSyncService实例
        return appState.autoSyncService
    }
    */
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("自动同步")
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // 自动同步开关
                ModernSettingRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "启用自动同步",
                    description: "定期自动同步使用统计数据",
                    control: AnyView(
                        Toggle("", isOn: $userPreferences.autoSyncEnabled)
                            .controlSize(.small)
                    )
                )
                
                // 同步间隔选择器（仅在自动同步启用时显示）
                if userPreferences.autoSyncEnabled {
                    ModernSettingRow(
                        icon: "clock.arrow.circlepath",
                        title: "同步间隔",
                        description: "自动同步的时间间隔",
                        control: AnyView(
                            Picker("", selection: Binding(
                                get: { userPreferences.currentSyncInterval },
                                set: { userPreferences.setSyncInterval($0) }
                            )) {
                                ForEach(SyncInterval.allCases, id: \.self) { interval in
                                    Text(interval.displayName).tag(interval)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 100)
                        )
                    )
                }
                
                // 同步通知开关
                ModernSettingRow(
                    icon: "bell.badge",
                    title: "同步通知",
                    description: "同步完成时显示通知",
                    control: AnyView(
                        Toggle("", isOn: $userPreferences.showSyncNotifications)
                            .controlSize(.small)
                    )
                )
                
                // 最后同步时间显示
                if let lastSyncDate = userPreferences.lastFullSyncDate {
                    ModernSettingRow(
                        icon: "clock.fill",
                        title: "最后同步时间",
                        description: formatLastSyncTime(lastSyncDate),
                        control: AnyView(
                            Text(formatSyncTime(lastSyncDate))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        )
                    )
                } else {
                    ModernSettingRow(
                        icon: "clock.fill",
                        title: "最后同步时间",
                        description: "尚未执行过同步",
                        control: AnyView(
                            Text("从未同步")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        )
                    )
                }
                
                // 手动同步按钮
                HStack(spacing: 16) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: DesignTokens.Size.Icon.large)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("手动同步")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(.primary)
                        
                        Text("立即执行完整数据同步")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(isPerformingManualSync ? "同步中..." : "立即同步") {
                        performManualSync()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isPerformingManualSync)
                }
                .padding(.vertical, 4)
                
                // 同步状态显示区域 - 待完善
                // SyncStatusDisplayView(service: autoSyncService)
            }
        }
        .padding(DesignTokens.Spacing.Page.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
        .alert("手动同步", isPresented: $showingManualSyncAlert) {
            Button("确定") { }
        } message: {
            Text("同步已开始，您可以在同步状态区域查看进度。")
        }
    }
    
    // MARK: - Private Methods
    
    private func formatLastSyncTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatSyncTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func performManualSync() {
        guard !isPerformingManualSync else { return }
        
        isPerformingManualSync = true
        
        Task {
            do {
                // 调用AppState的同步方法，这会处理AutoSyncService调用
                await appState.performFullSync()
                
                await MainActor.run {
                    isPerformingManualSync = false
                    showingManualSyncAlert = true
                }
            } catch {
                await MainActor.run {
                    isPerformingManualSync = false
                    // 错误已经在AppState中处理，这里不需要额外操作
                }
            }
        }
    }
}

// MARK: - Sync Status Display View - 待完善

/*
struct SyncStatusDisplayView: View {
    @ObservedObject var service: AutoSyncService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("同步状态")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                SyncStatusIndicator(status: service.syncStatus)
            }
            
            if service.isSyncing {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("进度：\(Int(service.syncProgress * 100))%")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(service.syncStatus.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: service.syncProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(x: 1, y: 0.5)
                }
            }
            
            if let lastSync = service.lastSyncTime {
                Text("最后同步：\(formatRelativeTime(lastSync))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            if let error = service.lastSyncError {
                Text("错误：\(error.errorDescription ?? "未知错误")")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.quaternarySystemFill))
        )
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Sync Status Indicator

struct SyncStatusIndicator: View {
    let status: SyncStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(red: status.color.red, green: status.color.green, blue: status.color.blue))
                .frame(width: 8, height: 8)
            
            Text(status.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
*/

// MARK: - Advanced Settings Section

struct AdvancedSettingsSection: View {
    @EnvironmentObject private var userPreferences: UserPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 开发者选项
            VStack(alignment: .leading, spacing: 16) {
                Text("开发者选项")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    ModernSettingRow(
                        icon: "ladybug",
                        title: "调试日志",
                        description: "启用详细调试日志（重启后生效）",
                        control: AnyView(
                            Toggle("", isOn: $userPreferences.enableDebugLogging)
                                .controlSize(.small)
                        )
                    )
                }
            }
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            // 数据管理
            VStack(alignment: .leading, spacing: 16) {
                Text("数据管理")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: DesignTokens.Size.Icon.large)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("打开配置目录")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(.primary)
                            
                            Text("在 Finder 中显示应用配置文件夹")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("打开") {
                            openConfigDirectory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                    
                    HStack(spacing: 16) {
                        Image(systemName: "trash")
                            .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: DesignTokens.Size.Icon.large)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("清除缓存")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(.primary)
                            
                            Text("清除所有缓存数据")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("清除") {
                            clearCaches()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }
    
    private func openConfigDirectory() {
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude")
        NSWorkspace.shared.open(url)
    }
    
    private func clearCaches() {
        // TODO: 实现缓存清理逻辑
        print("清除缓存")
    }
}

// MARK: - About Settings Section

struct AboutSettingsSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 应用信息
            VStack(alignment: .leading, spacing: 16) {
                Text("应用信息")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ClaudeBar")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("版本 1.0.0")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            
                            Text("Claude CLI 配置管理工具")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    HStack(spacing: 12) {
                        Link(destination: URL(string: "https://github.com/yourusername/claudebar")!) {
                            Label("GitHub", systemImage: "link")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Link(destination: URL(string: "https://github.com/yourusername/claudebar/issues")!) {
                            Label("反馈问题", systemImage: "exclamationmark.bubble")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            // 致谢
            VStack(alignment: .leading, spacing: 16) {
                Text("致谢")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    AcknowledgmentRow(
                        name: "Claude CLI",
                        description: "Anthropic 官方命令行工具",
                        url: "https://github.com/anthropics/claude-cli"
                    )
                    
                    AcknowledgmentRow(
                        name: "SwiftUI",
                        description: "Apple 现代化用户界面框架",
                        url: "https://developer.apple.com/swiftui/"
                    )
                }
            }
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }
}

// MARK: - Modern Setting Row

struct ModernSettingRow: View {
    let icon: String
    let title: String
    let description: String
    let control: AnyView
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: DesignTokens.Size.Icon.large)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            control
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Acknowledgment Row

struct AcknowledgmentRow: View {
    let name: String
    let description: String
    let url: String
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("访问") {
                openURL()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.vertical, 4)
    }
    
    private func openURL() {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(UserPreferences())
        .environmentObject(AppState())
}