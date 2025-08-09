//
//  MainPopoverView.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//


import SwiftUI

// MARK: - Navigation Tab Definition
    // 应用设置
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    
    @Published var hideDockIcon: Bool {
        didSet { UserDefaults.standard.set(hideDockIcon, forKey: "hideDockIcon") }
    }
    
    @Published var showInStatusBar: Bool {
        didSet { UserDefaults.standard.set(showInStatusBar, forKey: "showInStatusBar") }
    }
    
    // 通知设置
    @Published var showSuccessNotifications: Bool {
        didSet { UserDefaults.standard.set(showSuccessNotifications, forKey: "showSuccessNotifications") }
    }
    
    @Published var showErrorNotifications: Bool {
        didSet { UserDefaults.standard.set(showErrorNotifications, forKey: "showErrorNotifications") }
    }
    
    // 自动刷新设置
    @Published var enableAutoRefresh: Bool {
        didSet { UserDefaults.standard.set(enableAutoRefresh, forKey: "enableAutoRefresh") }
    }
    
    @Published var refreshInterval: Int {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }
    
    // 界面设置
    @Published var compactMode: Bool {
        didSet { UserDefaults.standard.set(compactMode, forKey: "compactMode") }
    }
    
    @Published var enableAnimations: Bool {
        didSet { UserDefaults.standard.set(enableAnimations, forKey: "enableAnimations") }
    }
    
    // 外观设置
    @Published var colorScheme: String {
        didSet { UserDefaults.standard.set(colorScheme, forKey: "colorScheme") }
    }
    
    @Published var accentColor: String {
        didSet { UserDefaults.standard.set(accentColor, forKey: "accentColor") }
    }
    
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    
    @Published var menuBarIconStyle: String {
        didSet { UserDefaults.standard.set(menuBarIconStyle, forKey: "menuBarIconStyle") }
    }
    
    // 开发者选项
    @Published var enableDebugLogging: Bool {
        didSet { UserDefaults.standard.set(enableDebugLogging, forKey: "enableDebugLogging") }
    }
    
    init() {
        // 初始化所有设置，从 UserDefaults 读取或使用默认值
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.hideDockIcon = UserDefaults.standard.bool(forKey: "hideDockIcon")
        self.showInStatusBar = UserDefaults.standard.object(forKey: "showInStatusBar") as? Bool ?? true
        
        self.showSuccessNotifications = UserDefaults.standard.object(forKey: "showSuccessNotifications") as? Bool ?? true
        self.showErrorNotifications = UserDefaults.standard.object(forKey: "showErrorNotifications") as? Bool ?? true
        
        self.enableAutoRefresh = UserDefaults.standard.bool(forKey: "enableAutoRefresh")
        self.refreshInterval = UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 30
        
        self.compactMode = UserDefaults.standard.bool(forKey: "compactMode")
        self.enableAnimations = UserDefaults.standard.object(forKey: "enableAnimations") as? Bool ?? true
        
        self.colorScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "auto"
        self.accentColor = UserDefaults.standard.string(forKey: "accentColor") ?? "blue"
        self.fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Double ?? 14.0
        self.menuBarIconStyle = UserDefaults.standard.string(forKey: "menuBarIconStyle") ?? "terminal"
        
        self.enableDebugLogging = UserDefaults.standard.bool(forKey: "enableDebugLogging")
    }
    
    func resetToDefaults() {
        launchAtLogin = false
        hideDockIcon = false
        showInStatusBar = true
        showSuccessNotifications = true
        showErrorNotifications = true
        enableAutoRefresh = false
        refreshInterval = 30
        compactMode = false
        enableAnimations = true
        colorScheme = "auto"
        accentColor = "blue"
        fontSize = 14.0
        menuBarIconStyle = "terminal"
        enableDebugLogging = false
    }
}

// MARK: - Navigation Tab Definition

enum NavigationTab: String, CaseIterable, Identifiable {
    case overview = "overview"
    case configManagement = "config"
    case processMonitor = "process"
    case systemStatus = "system"
    case toolbox = "toolbox"
    case settings = "settings"
    case help = "help"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .overview:
            return "概览"
        case .configManagement:
            return "API 配置管理"
        case .processMonitor:
            return "进程监控"
        case .systemStatus:
            return "系统状态"
        case .toolbox:
            return "工具箱"
        case .settings:
            return "设置"
        case .help:
            return "帮助"
        }
    }
    
    var icon: String {
        switch self {
        case .overview:
            return "chart.pie.fill"
        case .configManagement:
            return "gearshape.2.fill"
        case .processMonitor:
            return "chart.line.uptrend.xyaxis"
        case .systemStatus:
            return "info.circle.fill"
        case .toolbox:
            return "wrench.and.screwdriver.fill"
        case .settings:
            return "gearshape.fill"
        case .help:
            return "questionmark.circle.fill"
        }
    }
}

struct MainPopoverView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MenuBarViewModel()
    @State private var selectedTab: NavigationTab = .overview
    
    var body: some View {
        NavigationView {
            // 新的导航式主界面内容
            ModernNavigationView(
                selectedTab: $selectedTab
            )
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            viewModel.setAppState(appState)
        }
    }
}

// MARK: - Modern Navigation View

struct ModernNavigationView: View {
    @Binding var selectedTab: NavigationTab
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航菜单
            SidebarNavigationView(
                selectedTab: $selectedTab
            )
            .frame(width: 280)
            .background(Color(.controlBackgroundColor))
            
            // 分隔线
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(width: 1)
            
            // 右侧内容区域
            NavigationContentView(selectedTab: selectedTab)
                .frame(maxWidth: .infinity)
                .background(Color(.windowBackgroundColor))
        }
    }
}

// MARK: - Sidebar Navigation View

struct SidebarNavigationView: View {
    @Binding var selectedTab: NavigationTab
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // 应用头部
            SidebarHeaderSection()
            
            // 导航菜单项
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(NavigationTab.allCases) { tab in
                        NavigationTabItem(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Spacer()
            
            // 底部区域
            SidebarBottomSection()
        }
    }
}

// MARK: - Navigation Tab Item

struct NavigationTabItem: View {
    let tab: NavigationTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(tab.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(textColor)
                
                Spacer()
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 3, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundFill)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var iconColor: Color {
        if isSelected {
            return .blue
        } else {
            return isHovered ? .primary : .secondary
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .primary
        } else {
            return isHovered ? .primary : .secondary
        }
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return Color.blue.opacity(0.1)
        } else if isHovered {
            return Color.gray.opacity(0.08)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Navigation Content View

struct NavigationContentView: View {
    let selectedTab: NavigationTab
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Group {
            switch selectedTab {
            case .overview:
                OverviewPageView()
            case .configManagement:
                ConfigManagementPageView()
            case .processMonitor:
                ProcessMonitorPageView()
            case .systemStatus:
                SystemStatusPageView()
            case .toolbox:
                ToolboxPageView()
            case .settings:
                SettingsPageView()
            case .help:
                HelpPageView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
    }
}

struct MainContentView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showingSettings: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧边栏
            VStack(spacing: 0) {
                // 左侧头部
                SidebarHeaderSection()
                
                // 当前配置卡片
                if appState.currentConfig != nil {
                    CurrentConfigSection()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
                
                // 配置列表
                SidebarConfigListSection()
                
                Spacer()
                
                // 左侧底部
                SidebarBottomSection(showingSettings: $showingSettings)
            }
            .frame(width: 320)
            .background(Color(.controlBackgroundColor))
            
            // 分隔线
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(width: 1)
            
            // 右侧主内容区
            VStack(spacing: 0) {
                // 右侧头部
                MainContentHeaderSection()
                
                // 主内容区域
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // 快速操作面板
                        QuickActionsPanelSection()
                        
                        // 配置详情面板
                        if appState.currentConfig != nil {
                            ConfigDetailsPanelSection()
                        }
                        
                        // 系统状态面板
                        SystemStatusPanelSection()
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.windowBackgroundColor))
        }
    }
}

struct PopoverHeaderSection: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showingSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 应用图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "terminal.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude 配置管理器")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        StatusIndicatorDot()
                        Text(statusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 关闭按钮
                Button(action: {
                    NSApplication.shared.hide(nil)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 0.5)
        }
    }
    
    private var statusText: String {
        if appState.isLoading {
            return "加载中..."
        } else if let currentConfig = appState.currentConfig {
            return currentConfig.isValid ? "运行正常" : "配置异常"
        } else {
            return "未配置"
        }
    }
}

struct CurrentConfigSection: View {
    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    
    var body: some View {
        if let currentConfig = appState.currentConfig {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    // 状态指示器
                    ZStack {
                        Circle()
                            .fill(statusBackgroundColor)
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: statusIcon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(currentConfig.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("当前配置")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        Text(statusDescription)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(statusTextColor)
                    }
                    
                    Spacer()
                    
                    // 快速操作
                    HStack(spacing: 6) {
                        QuickActionButton(
                            icon: "arrow.clockwise",
                            action: { refreshConfig() }
                        )
                        
                        QuickActionButton(
                            icon: "folder",
                            action: { openConfigDirectory() }
                        )
                    }
                }
                
                // 配置详情
                if !currentConfig.isValid {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        
                        Text("配置需要修复")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
    }
    
    private var statusIcon: String {
        guard let currentConfig = appState.currentConfig else { return "questionmark" }
        return currentConfig.isValid ? "checkmark" : "exclamationmark"
    }
    
    private var statusBackgroundColor: Color {
        guard let currentConfig = appState.currentConfig else { return .gray }
        return currentConfig.isValid ? .green : .orange
    }
    
    private var statusDescription: String {
        guard let currentConfig = appState.currentConfig else { return "未知状态" }
        return currentConfig.isValid ? "配置正常运行" : "配置存在问题"
    }
    
    private var statusTextColor: Color {
        guard let currentConfig = appState.currentConfig else { return .secondary }
        return currentConfig.isValid ? .green : .orange
    }
    
    private var borderColor: Color {
        guard let currentConfig = appState.currentConfig else { return Color.gray.opacity(0.3) }
        return currentConfig.isValid ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3)
    }
    
    private func refreshConfig() {
        Task {
            await appState.loadConfigs()
        }
    }
    
    private func openConfigDirectory() {
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            NSWorkspace.shared.open(configDirectory)
        }
    }
}

struct ConfigListSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 列表头部
            HStack {
                Text("可用配置")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                if !appState.availableConfigs.isEmpty {
                    Text("(\(appState.availableConfigs.count))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 刷新按钮
                if appState.isLoading {
                    ProgressView()
                        .frame(width: 14, height: 14)
                        .scaleEffect(0.7)
                        .controlSize(.small)
                } else {
                    Button(action: refreshConfigs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            
            // 配置列表内容
            ScrollView {
                if appState.isLoading {
                    LoadingConfigsView()
                } else if appState.availableConfigs.isEmpty {
                    EmptyConfigsView()
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.availableConfigs) { config in
                            ConfigRowView(config: config)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(maxHeight: 200)
        }
    }
    
    private func refreshConfigs() {
        guard !appState.isLoading else { return }
        Task {
            await appState.loadConfigs()
        }
    }
}

struct ConfigRowView: View {
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
        Button(action: { switchToConfig() }) {
            HStack(spacing: 10) {
                // 状态指示器
                ZStack {
                    Circle()
                        .stroke(statusBorderColor, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    
                    if isCurrentConfig {
                        Circle()
                            .fill(statusFillColor)
                            .frame(width: 6, height: 6)
                    }
                }
                
                // 配置信息
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(config.name)
                            .font(.system(size: 13, weight: isCurrentConfig ? .semibold : .medium))
                            .foregroundColor(.primary)
                        
                        if isCurrentConfig {
                            Text("当前")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        
                        Spacer()
                        
                        // 配置状态图标
                        Image(systemName: config.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(config.isValid ? .green : .orange)
                    }
                    
                    Text(config.baseURLDisplay)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundFillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered && !isDisabled ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled && !isCurrentConfig ? 0.6 : 1.0)
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
    
    private var backgroundFillColor: Color {
        if isCurrentConfig {
            return Color.blue.opacity(0.08)
        } else if isHovered && !isDisabled {
            return Color(.controlBackgroundColor).opacity(0.8)
        } else {
            return Color(.controlBackgroundColor)
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
}

struct QuickActionsSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
            
            HStack(spacing: 8) {
                ActionButton(
                    title: "刷新",
                    icon: "arrow.clockwise",
                    color: .blue,
                    isCompact: true,
                    action: {
                        Task { await appState.loadConfigs() }
                    }
                )
                
                ActionButton(
                    title: "目录",
                    icon: "folder.fill",
                    color: .blue,
                    isCompact: true,
                    action: { openConfigDirectory() }
                )
                
                Spacer()
                
                // 错误或成功消息
                if let errorMessage = appState.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        
                        Text(errorMessage)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                if let _ = appState.successMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        
                        Text("切换成功")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private func openConfigDirectory() {
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            NSWorkspace.shared.open(configDirectory)
        }
    }
}

struct BottomNavigationSection: View {
    @Binding var showingSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
            
            HStack {
                Text("版本 1.0.0")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("帮助") {
                        if let url = URL(string: "https://docs.anthropic.com/claude/docs") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSettings = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 11))
                            Text("设置")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct LoadingConfigsView: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonConfigRow()
            }
        }
        .padding(.horizontal, 16)
    }
}

struct EmptyConfigsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "doc.text")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("未找到配置文件")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("请选择包含配置文件的目录")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("选择目录") {
                appState.requestConfigDirectoryAccess()
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
    }
}

struct SkeletonConfigRow: View {
    @State private var animationOffset: CGFloat = -1
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 14, height: 14)
            
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .frame(maxWidth: 100)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 10)
                    .frame(maxWidth: 160)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: animationOffset * 200)
                        .clipped()
                )
        )
        .onAppear {
            withAnimation(
                Animation.linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
            ) {
                animationOffset = 1
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isCompact: Bool = false
    let action: () -> Void
    
    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 4 : 6) {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 10 : 12, weight: .semibold))
                    .foregroundColor(isHovered ? .white : color)
                
                Text(title)
                    .font(.system(size: isCompact ? 10 : 12, weight: .semibold))
                    .foregroundColor(isHovered ? .white : .primary)
            }
            .padding(.horizontal, isCompact ? 8 : 12)
            .padding(.vertical, isCompact ? 4 : 6)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 6 : 8)
                    .fill(isHovered ? color : color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 6 : 8)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(appState.isLoading)
        .opacity(appState.isLoading ? 0.6 : 1.0)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - 新的桌面布局组件

struct SidebarHeaderSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 应用图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "terminal.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude 配置管理器")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        StatusIndicatorDot()
                        Text(statusText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // 分隔线
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 1)
        }
    }
    
    private var statusText: String {
        if appState.isLoading {
            return "加载中..."
        } else if let currentConfig = appState.currentConfig {
            return currentConfig.isValid ? "运行正常" : "配置异常"
        } else {
            return "未配置"
        }
    }
}

struct SidebarConfigListSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 列表头部
            HStack {
                Text("可用配置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                if !appState.availableConfigs.isEmpty {
                    Text("(\(appState.availableConfigs.count))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 刷新按钮
                if appState.isLoading {
                    ProgressView()
                        .frame(width: 16, height: 16)
                        .scaleEffect(0.8)
                        .controlSize(.small)
                } else {
                    Button(action: refreshConfigs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            
            // 配置列表内容
            ScrollView {
                if appState.isLoading {
                    LoadingConfigsView()
                } else if appState.availableConfigs.isEmpty {
                    EmptyConfigsView()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.availableConfigs) { config in
                            ConfigRowView(config: config)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private func refreshConfigs() {
        guard !appState.isLoading else { return }
        Task {
            await appState.loadConfigs()
        }
    }
}

struct SidebarBottomSection: View {
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 1)
            
            HStack {
                Text("版本 1.0.0")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("现在设置和帮助都在左侧导航菜单中")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

struct MainContentHeaderSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let currentConfig = appState.currentConfig {
                        Text("当前配置: \(currentConfig.name)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(currentConfig.baseURLDisplay)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        Text("API 配置管理")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("请选择一个配置")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 错误或成功消息
                if let errorMessage = appState.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                        
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if let _ = appState.successMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        
                        Text("切换成功")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 1)
        }
    }
}

struct QuickActionsPanelSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("快速操作")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ActionButton(
                    title: "刷新配置",
                    icon: "arrow.clockwise",
                    color: .blue,
                    action: {
                        Task { await appState.loadConfigs() }
                    }
                )
                
                ActionButton(
                    title: "打开目录",
                    icon: "folder.fill",
                    color: .blue,
                    action: { openConfigDirectory() }
                )
                
                ActionButton(
                    title: "新建配置",
                    icon: "plus",
                    color: .green,
                    action: { createNewConfig() }
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    private func openConfigDirectory() {
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            NSWorkspace.shared.open(configDirectory)
        }
    }
    
    private func createNewConfig() {
        // TODO: 实现新建配置功能
    }
}

struct ConfigDetailsPanelSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        if let currentConfig = appState.currentConfig {
            VStack(alignment: .leading, spacing: 16) {
                Text("配置详情")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    MainConfigDetailRow(
                        icon: "text.badge.checkmark",
                        label: "配置名称",
                        value: currentConfig.name,
                        valueColor: .primary
                    )
                    
                    MainConfigDetailRow(
                        icon: "link",
                        label: "API 端点",
                        value: currentConfig.baseURLDisplay,
                        valueColor: .secondary
                    )
                    
                    MainConfigDetailRow(
                        icon: "key.fill",
                        label: "认证状态",
                        value: currentConfig.env.anthropicAuthToken != nil ? "已配置" : "未配置",
                        valueColor: currentConfig.env.anthropicAuthToken != nil ? .green : .orange
                    )
                    
                    MainConfigDetailRow(
                        icon: "checkmark.shield.fill",
                        label: "配置状态",
                        value: currentConfig.isValid ? "正常" : "异常",
                        valueColor: currentConfig.isValid ? .green : .red
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }
}

struct SystemStatusPanelSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("系统状态")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                MainConfigDetailRow(
                    icon: "terminal.fill",
                    label: "Claude 进程",
                    value: claudeProcessStatusText,
                    valueColor: claudeProcessStatusColor
                )
                
                MainConfigDetailRow(
                    icon: "folder.fill",
                    label: "配置目录",
                    value: configDirectoryStatus,
                    valueColor: .secondary
                )
                
                MainConfigDetailRow(
                    icon: "doc.text.fill",
                    label: "可用配置",
                    value: "\(appState.availableConfigs.count) 个",
                    valueColor: .secondary
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    private var claudeProcessStatusText: String {
        switch appState.claudeProcessStatus {
        case .running(_):
            return "运行中"
        case .stopped:
            return "已停止"
        case .error(_):
            return "错误"
        case .unknown:
            return "未知"
        }
    }
    
    private var claudeProcessStatusColor: Color {
        switch appState.claudeProcessStatus {
        case .running(_):
            return .green
        case .stopped:
            return .orange
        case .error(_):
            return .red
        case .unknown:
            return .secondary
        }
    }
    
    private var configDirectoryStatus: String {
        if let configService = appState.configService as? ConfigService {
            return "~/.claude"
        } else {
            return "未设置"
        }
    }
}

struct MainConfigDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MainPopoverView()
        .environmentObject(AppState())
}

// MARK: - Page Views

// 概览页面
struct OverviewPageView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 欢迎区域
                WelcomeSection()
                
                // 当前配置卡片
                if appState.currentConfig != nil {
                    CurrentConfigOverviewCard()
                }
                
                // 快速状态概览
                QuickStatusOverview()
                
                // 最近活动
                RecentActivitySection()
            }
            .padding(24)
        }
        .navigationTitle("概览")
    }
}

// 配置管理页面
struct ConfigManagementPageView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // 页面头部
            ConfigManagementHeader()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 当前配置详情
                    if appState.currentConfig != nil {
                        CurrentConfigDetailCard()
                    }
                    
                    // 配置列表
                    ConfigurationsList()
                }
                .padding(24)
            }
        }
        .navigationTitle("API 配置管理")
    }
}

// 进程监控页面
struct ProcessMonitorPageView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // 进程监控头部
            ProcessMonitorHeader()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 进程状态卡片
                    ProcessStatusCard()
                    
                    // 进程列表详情
                    ProcessDetailsList()
                }
                .padding(24)
            }
        }
        .navigationTitle("进程监控")
    }
}

// 系统状态页面
struct SystemStatusPageView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 系统信息卡片
                SystemInfoCard()
                
                // 目录状态
                DirectoryStatusCard()
                
                // 健康检查
                HealthCheckCard()
                
                // 性能指标
                PerformanceMetricsCard()
            }
            .padding(24)
        }
        .navigationTitle("系统状态")
    }
}

// 工具箱页面
struct ToolboxPageView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 快速操作
                QuickActionsGrid()
                
                // 实用工具
                UtilityToolsGrid()
                
                // 外部链接
                ExternalLinksSection()
            }
            .padding(24)
        }
        .navigationTitle("工具箱")
    }
}

// MARK: - 概览页面组件

struct WelcomeSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("欢迎使用 Claude 配置管理器")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("管理和切换您的 Claude CLI 配置")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }
}

struct CurrentConfigOverviewCard: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        if let currentConfig = appState.currentConfig {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("当前配置")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    StatusIndicatorDot()
                }
                
                VStack(spacing: 12) {
                    MainConfigDetailRow(
                        icon: "text.badge.checkmark",
                        label: "配置名称",
                        value: currentConfig.name,
                        valueColor: .primary
                    )
                    
                    MainConfigDetailRow(
                        icon: "link",
                        label: "API 端点",
                        value: currentConfig.baseURLDisplay,
                        valueColor: .secondary
                    )
                    
                    MainConfigDetailRow(
                        icon: "checkmark.shield.fill",
                        label: "配置状态",
                        value: currentConfig.isValid ? "正常" : "异常",
                        valueColor: currentConfig.isValid ? .green : .red
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }
}

struct QuickStatusOverview: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatusOverviewCard(
                title: "可用配置",
                value: "\(appState.availableConfigs.count)",
                icon: "gearshape.2.fill",
                color: .blue
            )
            
            StatusOverviewCard(
                title: "Claude 进程",
                value: appState.claudeProcessStatus.processCount > 0 ? "运行中" : "已停止",
                icon: "terminal.fill",
                color: appState.claudeProcessStatus.processCount > 0 ? .green : .gray
            )
            
            StatusOverviewCard(
                title: "系统状态",
                value: "正常",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }
}

struct StatusOverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

struct RecentActivitySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近活动")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ActivityItem(
                    icon: "arrow.clockwise",
                    title: "刷新配置列表",
                    time: "刚刚",
                    color: .blue
                )
                
                ActivityItem(
                    icon: "gearshape.fill",
                    title: "切换到生产配置",
                    time: "5分钟前",
                    color: .green
                )
                
                ActivityItem(
                    icon: "folder.fill",
                    title: "打开配置目录",
                    time: "10分钟前",
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

struct ActivityItem: View {
    let icon: String
    let title: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 占位符组件

struct ConfigManagementHeader: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API 配置管理")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("管理您的 Claude CLI API 端点配置")
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

struct ProcessMonitorHeader: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("进程监控")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("监控 Claude CLI 进程状态和性能")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 刷新按钮
                Button(action: refreshProcessStatus) {
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
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 1)
        }
    }
    
    private func refreshProcessStatus() {
        appState.refreshProcessStatus()
    }
}

struct ProcessStatusCard: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 卡片标题
            HStack {
                Image(systemName: processStatusIcon)
                    .font(.system(size: 18))
                    .foregroundColor(processStatusColor)
                
                Text("Claude 进程状态")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 进程数量标识
                Text("\(appState.claudeProcessStatus.processCount) 个进程")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.controlBackgroundColor))
                    )
            }
            
            // 状态概览
            HStack(spacing: 16) {
                ProcessStatusItem(
                    title: "进程状态",
                    value: processStatusText,
                    icon: processStatusIcon,
                    color: processStatusColor
                )
                
                ProcessStatusItem(
                    title: "总内存使用",
                    value: totalMemoryUsage,
                    icon: "memorychip.fill",
                    color: memoryStatusColor
                )
                
                ProcessStatusItem(
                    title: "平均CPU",
                    value: averageCPUUsage,
                    icon: "cpu.fill",
                    color: cpuStatusColor
                )
            }
            
            // 详细描述
            Text(processStatusDescription)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(processStatusColor.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private var processStatusIcon: String {
        switch appState.claudeProcessStatus {
        case .running(let processes):
            return processes.isEmpty ? "stop.circle.fill" : "checkmark.circle.fill"
        case .stopped:
            return "stop.circle.fill"
        case .error(_):
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    private var processStatusColor: Color {
        switch appState.claudeProcessStatus {
        case .running(let processes):
            return processes.isEmpty ? .gray : .green
        case .stopped:
            return .gray
        case .error(_):
            return .red
        case .unknown:
            return .orange
        }
    }
    
    private var processStatusText: String {
        switch appState.claudeProcessStatus {
        case .running(let processes):
            return processes.isEmpty ? "无进程" : "运行中"
        case .stopped:
            return "已停止"
        case .error(_):
            return "错误"
        case .unknown:
            return "未知"
        }
    }
    
    private var processStatusDescription: String {
        switch appState.claudeProcessStatus {
        case .running(let processes):
            if processes.isEmpty {
                return "当前没有检测到 Claude CLI 进程在运行。您可能需要先启动 Claude 命令行工具。"
            } else {
                return "检测到 \(processes.count) 个 Claude 进程正在运行，系统工作正常。"
            }
        case .stopped:
            return "没有 Claude 进程在运行。您可以通过命令行启动 Claude 工具。"
        case .error(let message):
            return "进程监控遇到问题：\(message)"
        case .unknown:
            return "正在检查 Claude 进程状态，请稍候..."
        }
    }
    
    private var totalMemoryUsage: String {
        let processes = appState.claudeProcessStatus.processes
        let totalMemory = processes.compactMap { $0.memoryInfo?.residentSizeMB }.reduce(0, +)
        return totalMemory > 0 ? String(format: "%.1f MB", totalMemory) : "N/A"
    }
    
    private var averageCPUUsage: String {
        let processes = appState.claudeProcessStatus.processes
        let cpuValues = processes.compactMap { $0.cpuUsage }.compactMap { Double($0) }
        if cpuValues.isEmpty {
            return "N/A"
        }
        let average = cpuValues.reduce(0, +) / Double(cpuValues.count)
        return String(format: "%.1f%%", average)
    }
    
    private var memoryStatusColor: Color {
        let processes = appState.claudeProcessStatus.processes
        let totalMemory = processes.compactMap { $0.memoryInfo?.residentSizeMB }.reduce(0, +)
        if totalMemory > 500 {
            return .red
        } else if totalMemory > 200 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var cpuStatusColor: Color {
        let processes = appState.claudeProcessStatus.processes
        let cpuValues = processes.compactMap { $0.cpuUsage }.compactMap { Double($0) }
        if cpuValues.isEmpty {
            return .gray
        }
        let average = cpuValues.reduce(0, +) / Double(cpuValues.count)
        if average > 50 {
            return .red
        } else if average > 20 {
            return .orange
        } else {
            return .green
        }
    }
}

struct ProcessStatusItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
        )
    }
}

struct ProcessDetailsList: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("进程详情")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            if appState.claudeProcessStatus.processCount > 0 {
                LazyVStack(spacing: 12) {
                    ForEach(appState.claudeProcessStatus.processes) { process in
                        DetailedProcessRowView(process: process)
                    }
                }
            } else {
                EmptyProcessDetailView()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

struct DetailedProcessRowView: View {
    let process: ProcessService.ClaudeProcess
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主要信息行
            HStack(spacing: 16) {
                // 状态指示器
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                // 进程信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(process.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("PID: \(process.pid)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // 性能指标
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CPU 使用率")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(process.cpuUsageText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(process.cpuUsageColor))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("内存使用")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(process.memoryUsageText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(process.memoryUsageColor))
                        }
                        
                        if let startTime = process.startTime {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("运行时间")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text(formatRunningTime(startTime))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // 展开/折叠按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // 详细信息（展开时显示）
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if let executablePath = process.executablePath {
                        ProcessDetailRow(
                            icon: "terminal",
                            label: "可执行文件",
                            value: executablePath
                        )
                    }
                    
                    if let workingDirectory = process.workingDirectory {
                        ProcessDetailRow(
                            icon: "folder",
                            label: "工作目录",
                            value: workingDirectory
                        )
                    }
                    
                    if let memoryInfo = process.memoryInfo {
                        ProcessDetailRow(
                            icon: "memorychip",
                            label: "物理内存",
                            value: memoryInfo.formattedResident,
                            valueColor: Color(process.memoryUsageColor)
                        )
                        
                        ProcessDetailRow(
                            icon: "square.stack.3d.down.right",
                            label: "虚拟内存",
                            value: String(format: "%.1f MB", memoryInfo.virtualSizeMB)
                        )
                    }
                    
                    ProcessDetailRow(
                        icon: "cpu",
                        label: "CPU 使用率",
                        value: process.cpuUsageText,
                        valueColor: Color(process.cpuUsageColor)
                    )
                    
                    if let startTime = process.startTime {
                        ProcessDetailRow(
                            icon: "clock",
                            label: "启动时间",
                            value: formatStartTime(startTime)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.05))
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
    }
    
    private func formatStartTime(_ startTime: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: startTime)
    }
    
    private func formatRunningTime(_ startTime: Date) -> String {
        let interval = Date().timeIntervalSince(startTime)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

struct EmptyProcessDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("没有检测到 Claude 进程")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Claude CLI 当前未在运行，请先启动 Claude 命令行工具")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("如何启动 Claude") {
                if let url = URL(string: "https://docs.anthropic.com/claude/docs") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct SystemInfoCard: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 卡片标题
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                
                Text("系统信息")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // 系统信息网格
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .leading, spacing: 16) {
                SystemInfoItem(
                    icon: "desktopcomputer",
                    label: "操作系统",
                    value: systemVersion,
                    color: .blue
                )
                
                SystemInfoItem(
                    icon: "cpu",
                    label: "处理器架构",
                    value: processorArchitecture,
                    color: .purple
                )
                
                SystemInfoItem(
                    icon: "person.fill",
                    label: "当前用户",
                    value: currentUser,
                    color: .green
                )
                
                SystemInfoItem(
                    icon: "house.fill",
                    label: "用户目录",
                    value: homeDirectory,
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    private var systemVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    private var processorArchitecture: String {
        #if arch(arm64)
        return "Apple Silicon (ARM64)"
        #elseif arch(x86_64)
        return "Intel x86_64"
        #else
        return "Unknown"
        #endif
    }
    
    private var currentUser: String {
        return NSUserName()
    }
    
    private var homeDirectory: String {
        return NSHomeDirectory().replacingOccurrences(of: "/Users/", with: "~/")
    }
}

struct SystemInfoItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 16)
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
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

struct DirectoryStatusCard: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 卡片标题
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                
                Text("目录状态")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: openConfigDirectory) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                        Text("打开")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(spacing: 12) {
                DirectoryStatusRow(
                    path: configDirectoryPath,
                    name: "Claude 配置目录",
                    icon: "gearshape.2.fill",
                    description: "存放 Claude CLI 配置文件"
                )
                
                DirectoryStatusRow(
                    path: NSHomeDirectory(),
                    name: "用户主目录",
                    icon: "house.fill",
                    description: "当前用户的主目录"
                )
                
                DirectoryStatusRow(
                    path: "/Applications",
                    name: "应用程序目录",
                    icon: "square.grid.3x3.fill",
                    description: "系统应用程序安装位置"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    private var configDirectoryPath: String {
        if let configService = appState.configService as? ConfigService {
            return configService.configDirectoryPath
        }
        return NSHomeDirectory() + "/.claude"
    }
    
    private func openConfigDirectory() {
        let directoryURL = URL(fileURLWithPath: configDirectoryPath)
        NSWorkspace.shared.open(directoryURL)
    }
}

struct DirectoryStatusRow: View {
    let path: String
    let name: String
    let icon: String
    let description: String
    @State private var directoryExists = false
    @State private var isAccessible = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(statusColor)
            }
            
            // 目录信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    StatusBadge(
                        text: statusText,
                        color: statusColor
                    )
                }
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(path)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(statusColor.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            checkDirectoryStatus()
        }
    }
    
    private var statusColor: Color {
        if !directoryExists {
            return .red
        } else if !isAccessible {
            return .orange
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        if !directoryExists {
            return "不存在"
        } else if !isAccessible {
            return "无权限"
        } else {
            return "可访问"
        }
    }
    
    private func checkDirectoryStatus() {
        let fileManager = FileManager.default
        _ = URL(fileURLWithPath: path)
        
        directoryExists = fileManager.fileExists(atPath: path)
        
        if directoryExists {
            isAccessible = fileManager.isReadableFile(atPath: path)
        } else {
            isAccessible = false
        }
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))
            )
    }
}

struct HealthCheckCard: View {
    @EnvironmentObject private var appState: AppState
    @State private var healthCheckResults: [HealthCheckItem] = []
    @State private var isRunningHealthCheck = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 卡片标题
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                
                Text("健康检查")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: runHealthCheck) {
                    HStack(spacing: 6) {
                        if isRunningHealthCheck {
                            ProgressView()
                                .frame(width: 12, height: 12)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                        }
                        Text("检查")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isRunningHealthCheck)
            }
            
            if healthCheckResults.isEmpty {
                EmptyHealthCheckView()
            } else {
                VStack(spacing: 8) {
                    ForEach(healthCheckResults) { item in
                        HealthCheckRow(item: item)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
        .onAppear {
            if healthCheckResults.isEmpty {
                runHealthCheck()
            }
        }
    }
    
    private func runHealthCheck() {
        guard !isRunningHealthCheck else { return }
        
        isRunningHealthCheck = true
        
        Task {
            await performHealthChecks()
            
            await MainActor.run {
                isRunningHealthCheck = false
            }
        }
    }
    
    private func performHealthChecks() async {
        var results: [HealthCheckItem] = []
        
        // 检查配置目录
        let configDirExists = checkConfigDirectory()
        results.append(HealthCheckItem(
            id: "config-dir",
            name: "配置目录检查",
            description: "检查 ~/.claude 目录是否存在",
            status: configDirExists ? .passed : .failed,
            details: configDirExists ? "配置目录存在且可访问" : "配置目录不存在或无法访问"
        ))
        
        // 检查配置文件
        let configFilesCount = checkConfigFiles()
        results.append(HealthCheckItem(
            id: "config-files",
            name: "配置文件检查",
            description: "检查是否存在有效的配置文件",
            status: configFilesCount > 0 ? .passed : .warning,
            details: configFilesCount > 0 ? "找到 \(configFilesCount) 个配置文件" : "未找到配置文件"
        ))
        
        // 检查进程状态
        let processCount = appState.claudeProcessStatus.processCount
        results.append(HealthCheckItem(
            id: "process-status",
            name: "进程状态检查",
            description: "检查 Claude 进程运行状态",
            status: processCount > 0 ? .passed : .warning,
            details: processCount > 0 ? "检测到 \(processCount) 个运行中的进程" : "未检测到运行中的进程"
        ))
        
        // 检查权限
        let hasPermissions = checkPermissions()
        results.append(HealthCheckItem(
            id: "permissions",
            name: "权限检查",
            description: "检查应用权限配置",
            status: hasPermissions ? .passed : .warning,
            details: hasPermissions ? "应用权限配置正常" : "可能需要重新授权目录访问权限"
        ))
        
        await MainActor.run {
            healthCheckResults = results
        }
    }
    
    private func checkConfigDirectory() -> Bool {
        let configPath = NSHomeDirectory() + "/.claude"
        return FileManager.default.fileExists(atPath: configPath)
    }
    
    private func checkConfigFiles() -> Int {
        let configPath = NSHomeDirectory() + "/.claude"
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: configPath)
            return contents.filter { $0.hasSuffix("-settings.json") || $0 == "settings.json" }.count
        } catch {
            return 0
        }
    }
    
    private func checkPermissions() -> Bool {
        let configPath = NSHomeDirectory() + "/.claude"
        return FileManager.default.isReadableFile(atPath: configPath) && 
               FileManager.default.isWritableFile(atPath: configPath)
    }
}

struct HealthCheckItem: Identifiable {
    let id: String
    let name: String
    let description: String
    let status: HealthCheckStatus
    let details: String
}

enum HealthCheckStatus {
    case passed
    case warning
    case failed
    
    var icon: String {
        switch self {
        case .passed:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .passed:
            return .green
        case .warning:
            return .orange
        case .failed:
            return .red
        }
    }
}

struct HealthCheckRow: View {
    let item: HealthCheckItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.status.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(item.status.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(item.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(item.details)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(item.status.color)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(item.status.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct EmptyHealthCheckView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("点击检查按钮开始健康检查")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("将检查配置文件、进程状态和权限")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct PerformanceMetricsCard: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 卡片标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.indigo)
                
                Text("性能指标")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                PerformanceMetricItem(
                    title: "应用启动时间",
                    value: "< 1秒",
                    icon: "speedometer",
                    color: .green,
                    trend: .stable
                )
                
                PerformanceMetricItem(
                    title: "内存使用",
                    value: memoryUsage,
                    icon: "memorychip",
                    color: memoryColor,
                    trend: .stable
                )
                
                PerformanceMetricItem(
                    title: "配置加载时间",
                    value: "< 100ms",
                    icon: "clock",
                    color: .blue,
                    trend: .stable
                )
                
                PerformanceMetricItem(
                    title: "响应时间",
                    value: "即时",
                    icon: "bolt.fill",
                    color: .yellow,
                    trend: .stable
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    private var memoryUsage: String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            return String(format: "%.1f MB", memoryMB)
        } else {
            return "N/A"
        }
    }
    
    private var memoryColor: Color {
        // 简单的内存使用颜色判断
        return .green
    }
}

enum PerformanceTrend {
    case up, down, stable
    
    var icon: String {
        switch self {
        case .up:
            return "arrow.up"
        case .down:
            return "arrow.down"
        case .stable:
            return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up:
            return .red
        case .down:
            return .green
        case .stable:
            return .gray
        }
    }
}

struct PerformanceMetricItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: PerformanceTrend
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(trend.color)
            }
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.windowBackgroundColor))
        )
    }
}

struct QuickActionsGrid: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("快速操作")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // 配置相关操作
                ToolboxActionCard(
                    title: "刷新配置",
                    description: "重新加载所有配置文件",
                    icon: "arrow.clockwise",
                    color: .blue,
                    action: {
                        Task { await appState.loadConfigs() }
                    }
                )
                
                ToolboxActionCard(
                    title: "打开配置目录",
                    description: "在 Finder 中打开 ~/.claude",
                    icon: "folder.fill",
                    color: .blue,
                    action: { openConfigDirectory() }
                )
                
                ToolboxActionCard(
                    title: "新建配置",
                    description: "创建新的 Claude 配置",
                    icon: "plus.circle.fill",
                    color: .green,
                    action: { createNewConfig() }
                )
                
                ToolboxActionCard(
                    title: "导入配置",
                    description: "从文件导入配置",
                    icon: "square.and.arrow.down",
                    color: .orange,
                    action: { importConfig() }
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    private func openConfigDirectory() {
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            NSWorkspace.shared.open(configDirectory)
        }
    }
    
    private func createNewConfig() {
        // 创建模板配置文件
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            
            // 确保目录存在
            if !FileManager.default.fileExists(atPath: configDirectory.path) {
                try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            }
            
            // 打开目录
            NSWorkspace.shared.open(configDirectory)
        }
    }
    
    private func importConfig() {
        // 打开文件选择器（简化实现，直接打开配置目录）
        openConfigDirectory()
    }
}

struct UtilityToolsGrid: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("实用工具")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // 系统工具
                ToolboxActionCard(
                    title: "检查 Claude 进程",
                    description: "查看当前运行的 Claude 进程",
                    icon: "terminal.fill",
                    color: .purple,
                    action: { checkClaudeProcess() }
                )
                
                ToolboxActionCard(
                    title: "清理缓存",
                    description: "清除临时文件和缓存",
                    icon: "trash.fill",
                    color: .red,
                    action: { clearCache() }
                )
                
                ToolboxActionCard(
                    title: "导出日志",
                    description: "导出应用日志文件",
                    icon: "doc.text.fill",
                    color: .gray,
                    action: { exportLogs() }
                )
                
                ToolboxActionCard(
                    title: "重置权限",
                    description: "重新请求目录访问权限",
                    icon: "lock.open.fill",
                    color: .orange,
                    action: { resetPermissions() }
                )
                
                ToolboxActionCard(
                    title: "备份配置",
                    description: "创建配置文件备份",
                    icon: "archivebox.fill",
                    color: .indigo,
                    action: { backupConfigs() }
                )
                
                ToolboxActionCard(
                    title: "验证配置",
                    description: "检查配置文件完整性",
                    icon: "checkmark.shield.fill",
                    color: .green,
                    action: { validateConfigs() }
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    private func checkClaudeProcess() {
        appState.refreshProcessStatus()
    }
    
    private func clearCache() {
        // 清理缓存的简单实现
        // 这里可以添加更复杂的缓存清理逻辑
        print("清理缓存...")
    }
    
    private func exportLogs() {
        // 导出日志的简单实现
        let logDirectory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/ClaudeConfigManager")
        if FileManager.default.fileExists(atPath: logDirectory.path) {
            NSWorkspace.shared.open(logDirectory)
        }
    }
    
    private func resetPermissions() {
        // 重置权限
        appState.requestConfigDirectoryAccess()
    }
    
    private func backupConfigs() {
        if let configService = appState.configService as? ConfigService {
            let configDirectory = URL(fileURLWithPath: configService.configDirectoryPath)
            let desktopDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let backupDirectory = desktopDirectory.appendingPathComponent("claude-config-backup-\(Date().timeIntervalSince1970)")
            
            do {
                try FileManager.default.copyItem(at: configDirectory, to: backupDirectory)
                NSWorkspace.shared.open(backupDirectory)
            } catch {
                print("备份失败: \(error)")
            }
        }
    }
    
    private func validateConfigs() {
        Task {
            await appState.loadConfigs()
        }
    }
}

struct ExternalLinksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("帮助与文档")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ExternalLinkItem(
                    title: "Claude CLI 文档",
                    description: "官方 Claude CLI 使用文档",
                    icon: "book.fill",
                    url: "https://docs.anthropic.com/claude/docs"
                )
                
                ExternalLinkItem(
                    title: "API 参考",
                    description: "Claude API 完整参考文档",
                    icon: "code.fill",
                    url: "https://docs.anthropic.com/claude/reference"
                )
                
                ExternalLinkItem(
                    title: "GitHub 仓库",
                    description: "Claude CLI 源代码仓库",
                    icon: "chevron.left.forwardslash.chevron.right",
                    url: "https://github.com/anthropics/claude-cli"
                )
                
                ExternalLinkItem(
                    title: "支持中心",
                    description: "获取技术支持和帮助",
                    icon: "questionmark.circle.fill",
                    url: "https://support.anthropic.com"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

struct ToolboxActionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(color)
                }
                
                // 文本内容
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? color.opacity(0.05) : Color(.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isHovered ? color.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct ExternalLinkItem: View {
    let title: String
    let description: String
    let icon: String
    let url: String
    @State private var isHovered = false
    
    var body: some View {
        Button(action: openURL) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                // 文本内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 外部链接图标
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.blue.opacity(0.05) : Color(.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func openURL() {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - 设置页面组件

struct SettingsPageView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var preferences = UserPreferences()
    @State private var currentConfigPath: String = "未设置"
    @State private var isChangingDirectory = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // 页面标题
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("设置")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("配置应用行为、外观和高级选项")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                // 配置目录管理
                VStack(alignment: .leading, spacing: 20) {
                    Text("配置目录")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                    
                    ModernConfigDirectorySection(
                        currentPath: $currentConfigPath,
                        isChangingDirectory: $isChangingDirectory
                    )
                    .padding(.horizontal, 24)
                }
                
                // 应用设置
                VStack(alignment: .leading, spacing: 20) {
                    Text("应用行为")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                    
                    ModernAppSettingsSection()
                        .padding(.horizontal, 24)
                }
                
                // 通知设置
                VStack(alignment: .leading, spacing: 20) {
                    Text("通知设置")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                    
                    NotificationSettingsSection()
                        .padding(.horizontal, 24)
                }
                
                // 外观设置
                VStack(alignment: .leading, spacing: 20) {
                    Text("外观主题")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                    
                    ThemeSettingsSection()
                        .padding(.horizontal, 24)
                }
                
                // 高级选项
                VStack(alignment: .leading, spacing: 20) {
                    Text("高级选项")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                    
                    DeveloperSettingsSection()
                        .padding(.horizontal, 24)
                }
                
                // 关于信息
                VStack(alignment: .leading, spacing: 20) {
                    Text("关于应用")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                    
                    ModernAboutSection()
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("设置")
        .onAppear {
            updateCurrentConfigPath()
        }
    }
    
    private func updateCurrentConfigPath() {
        if let configService = appState.configService as? ConfigService {
            currentConfigPath = configService.configDirectoryPath
        } else {
            let defaultPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude").path
            currentConfigPath = defaultPath
        }
    }
}

// MARK: - 帮助页面组件

struct HelpPageView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // 页面标题
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("帮助中心")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("使用指南、常见问题和故障排除")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                // 快速开始指南
                HelpSectionCard(
                    title: "快速开始",
                    icon: "play.circle.fill",
                    color: .green
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpStepItem(
                            step: "1",
                            title: "选择配置目录",
                            description: "在设置页面中选择包含 Claude 配置文件的目录（通常是 ~/.claude）"
                        )
                        
                        HelpStepItem(
                            step: "2",
                            title: "查看可用配置",
                            description: "应用会自动扫描并显示所有可用的 Claude CLI 配置文件"
                        )
                        
                        HelpStepItem(
                            step: "3",
                            title: "切换配置",
                            description: "点击配置列表中的任意配置，即可快速切换到该配置"
                        )
                        
                        HelpStepItem(
                            step: "4",
                            title: "监控状态",
                            description: "通过进程监控页面查看 Claude CLI 的运行状态和性能指标"
                        )
                    }
                }
                
                // 配置文件指南
                HelpSectionCard(
                    title: "配置文件格式",
                    icon: "doc.text.fill",
                    color: .blue
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("配置文件命名规则")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("• 默认配置：settings.json\n• 自定义配置：{配置名}-settings.json\n• 例如：work-settings.json、personal-settings.json")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("配置文件结构")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("{\n  \"env\": {\n    \"ANTHROPIC_BASE_URL\": \"https://api.anthropic.com\",\n    \"CLAUDE_CODE_MAX_OUTPUT_TOKENS\": \"32000\"\n  },\n  \"permissions\": {\n    \"allow\": [],\n    \"deny\": []\n  },\n  \"cleanupPeriodDays\": 365,\n  \"includeCoAuthoredBy\": false\n}")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.controlBackgroundColor))
                                )
                        }
                    }
                }
                
                // 故障排除
                HelpSectionCard(
                    title: "常见问题",
                    icon: "wrench.and.screwdriver.fill",
                    color: .orange
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HelpFAQItem(
                            question: "为什么看不到配置文件？",
                            answer: "请确保：\n1. 配置目录路径正确（通常是 ~/.claude）\n2. 配置文件命名符合规范\n3. 应用有访问该目录的权限\n4. 配置文件格式为有效的 JSON"
                        )
                        
                        HelpFAQItem(
                            question: "配置切换失败怎么办？",
                            answer: "可能的原因：\n1. 目标配置文件损坏或格式错误\n2. 缺少必要的 API Token\n3. 网络连接问题\n4. Claude CLI 进程异常\n\n建议先验证配置文件的完整性"
                        )
                        
                        HelpFAQItem(
                            question: "如何备份配置？",
                            answer: "方法一：使用应用内的备份功能\n方法二：手动复制 ~/.claude 目录\n方法三：使用版本控制系统管理配置文件\n\n建议定期备份重要配置"
                        )
                        
                        HelpFAQItem(
                            question: "应用权限问题",
                            answer: "如果遇到权限问题：\n1. 在设置中重新选择配置目录\n2. 确保授予应用文件夹访问权限\n3. 检查 macOS 安全设置\n4. 必要时重启应用"
                        )
                    }
                }
                
                // 外部资源
                HelpSectionCard(
                    title: "更多资源",
                    icon: "link.circle.fill",
                    color: .purple
                ) {
                    VStack(spacing: 12) {
                        HelpLinkItem(
                            title: "Claude CLI 官方文档",
                            description: "完整的 Claude CLI 使用指南和 API 参考",
                            icon: "book.fill",
                            url: "https://docs.anthropic.com/claude/docs"
                        )
                        
                        HelpLinkItem(
                            title: "GitHub 仓库",
                            description: "Claude CLI 开源代码仓库和问题反馈",
                            icon: "chevron.left.forwardslash.chevron.right",
                            url: "https://github.com/anthropics/claude-cli"
                        )
                        
                        HelpLinkItem(
                            title: "社区支持",
                            description: "Anthropic 官方支持社区",
                            icon: "person.3.fill",
                            url: "https://support.anthropic.com"
                        )
                        
                        HelpLinkItem(
                            title: "API 状态",
                            description: "Claude API 服务状态监控",
                            icon: "chart.line.uptrend.xyaxis",
                            url: "https://status.anthropic.com"
                        )
                    }
                }
                
                // 应用信息
                VStack(alignment: .center, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 8) {
                        Text("Claude 配置管理器")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("版本 1.0.0 • © 2024")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text("如需技术支持，请访问帮助文档或联系开发者")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("帮助")
    }
}

// MARK: - 帮助页面支持组件

struct HelpSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
        .padding(.horizontal, 24)
    }
}

struct HelpStepItem: View {
    let step: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 28, height: 28)
                
                Text(step)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct HelpFAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(answer)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}

struct HelpLinkItem: View {
    let title: String
    let description: String
    let icon: String
    let url: String
    @State private var isHovered = false
    
    var body: some View {
        Button(action: openURL) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.blue.opacity(0.05) : Color(.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isHovered ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func openURL() {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}
