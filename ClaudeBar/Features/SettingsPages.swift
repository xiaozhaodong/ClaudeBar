import SwiftUI
import AppKit

// MARK: - 共享的设置组件

struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    
    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.Component.cardInner) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(.secondary)
                }
            }
            
            content
        }
        .padding(DesignTokens.Spacing.Page.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DesignTokens.Typography.pageTitle)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(DesignTokens.Typography.subtitle)
                .foregroundColor(.secondary)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let action: (() -> Void)?
    
    init(icon: String, title: String, value: String, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.Component.rowInner) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: DesignTokens.Size.Icon.medium)
            
            Text(title)
                .font(DesignTokens.Typography.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let action = action {
                Button(value) {
                    action()
                }
                .font(DesignTokens.Typography.body)
                .foregroundColor(.blue)
                .buttonStyle(PlainButtonStyle())
            } else {
                Text(value)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: DesignTokens.Size.Icon.large)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 用户偏好设置管理

class UserPreferences: ObservableObject {
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

// MARK: - GeneralSettingsPage 组件

struct GeneralSettingsPage: View {
    @StateObject private var preferences = UserPreferences()
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: "通用设置",
                subtitle: "配置应用的基本行为和偏好"
            )
            
            // 应用启动选项
            SettingsCard(
                title: "应用启动",
                subtitle: "配置应用的启动行为"
            ) {
                VStack(spacing: DesignTokens.Spacing.Component.settingRowSpacing) {
                    SettingToggleRow(
                        icon: "power",
                        title: "开机启动",
                        description: "系统启动时自动启动应用",
                        isOn: $preferences.launchAtLogin
                    )
                    
                    SettingToggleRow(
                        icon: "dock.rectangle",
                        title: "隐藏 Dock 图标",
                        description: "从 Dock 中隐藏应用图标，仅在菜单栏显示",
                        isOn: $preferences.hideDockIcon
                    )
                    
                    SettingToggleRow(
                        icon: "menubar.arrow.up.rectangle",
                        title: "显示在状态栏",
                        description: "在菜单栏显示应用图标",
                        isOn: $preferences.showInStatusBar
                    )
                }
            }
            
            // 通知设置
            SettingsCard(
                title: "通知设置",
                subtitle: "配置何时显示系统通知"
            ) {
                VStack(spacing: DesignTokens.Spacing.Component.settingRowSpacing) {
                    SettingToggleRow(
                        icon: "checkmark.circle.fill",
                        title: "成功通知",
                        description: "API 端点切换成功时显示通知",
                        isOn: $preferences.showSuccessNotifications
                    )
                    
                    SettingToggleRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "错误通知",
                        description: "出现错误时显示通知",
                        isOn: $preferences.showErrorNotifications
                    )
                }
            }
            
            // 自动刷新设置
            SettingsCard(
                title: "自动刷新",
                subtitle: "配置配置列表的自动更新"
            ) {
                VStack(spacing: DesignTokens.Spacing.Component.settingRowSpacing) {
                    SettingToggleRow(
                        icon: "arrow.clockwise",
                        title: "启用自动刷新",
                        description: "定期检查配置文件变化",
                        isOn: $preferences.enableAutoRefresh
                    )
                    
                    if preferences.enableAutoRefresh {
                        HStack(spacing: 16) {
                            Image(systemName: "timer")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("刷新间隔")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text("自动刷新的时间间隔")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Stepper("\(preferences.refreshInterval) 秒", 
                                   value: $preferences.refreshInterval, 
                                   in: 10...300, 
                                   step: 10)
                                .frame(width: 120)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // 界面设置
            SettingsCard(
                title: "界面设置",
                subtitle: "调整应用界面的显示方式"
            ) {
                VStack(spacing: DesignTokens.Spacing.Component.settingRowSpacing) {
                    SettingToggleRow(
                        icon: "rectangle.compress.vertical",
                        title: "紧凑模式",
                        description: "使用更紧凑的界面布局，节省空间",
                        isOn: $preferences.compactMode
                    )
                    
                    SettingToggleRow(
                        icon: "sparkles",
                        title: "动画效果",
                        description: "启用界面切换和交互动画",
                        isOn: $preferences.enableAnimations
                    )
                }
            }
            
            // 重置设置
            SettingsCard(
                title: "重置设置",
                subtitle: "将所有通用设置恢复为默认值"
            ) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("恢复默认设置")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("这将重置所有通用设置为初始值")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("重置") {
                        showingResetAlert = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("重置设置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                preferences.resetToDefaults()
            }
        } message: {
            Text("确定要将所有通用设置恢复为默认值吗？此操作无法撤销。")
        }
    }
}

// MARK: - ConfigSettingsPage 组件

struct ConfigSettingsPage: View {
    @EnvironmentObject private var appState: AppState
    @Binding var currentConfigPath: String
    @Binding var isChangingDirectory: Bool
    @State private var showingDirectoryPicker = false
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var isValidatingConfigs = false
    @State private var validationResults: [ConfigValidationResult] = []
    @State private var showingValidationResults = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: "API 配置管理",
                subtitle: "管理 Claude CLI 配置文件和目录"
            )
            
            // 当前配置目录
            SettingsCard(
                title: "配置目录",
                subtitle: "Claude CLI API 配置文件的存储位置"
            ) {
                VStack(spacing: 16) {
                    // 目录信息展示
                    HStack(spacing: DesignTokens.Spacing.Component.rowInner) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前配置目录")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(shortenPath(currentConfigPath))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        DirectoryStatusIndicator(path: currentConfigPath)
                        
                        // 打开目录按钮
                        Button(action: openCurrentDirectory) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("在 Finder 中打开")
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.selectedControlColor).opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    // 操作按钮
                    HStack(spacing: DesignTokens.Spacing.Component.rowInner) {
                        Button(action: selectConfigDirectory) {
                            HStack(spacing: 8) {
                                if isChangingDirectory {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "folder.badge.gearshape")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                
                                Text(isChangingDirectory ? "选择中..." : "选择目录")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .foregroundColor(isChangingDirectory ? .secondary : .white)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isChangingDirectory ? Color.gray.opacity(0.3) : Color.blue)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isChangingDirectory)
                        
                        Button(action: resetToDefaultDirectory) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .medium))
                                
                                Text("重置默认")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .foregroundColor(.blue)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isChangingDirectory)
                    }
                }
            }
            
            // 配置文件验证
            SettingsCard(
                title: "配置验证",
                subtitle: "检查和修复配置文件问题"
            ) {
                VStack(spacing: DesignTokens.Spacing.Component.settingRowSpacing) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("验证配置文件")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("检查配置文件格式和完整性")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: validateConfigs) {
                            HStack(spacing: 6) {
                                if isValidatingConfigs {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.shield")
                                        .font(.system(size: 12))
                                }
                                
                                Text(isValidatingConfigs ? "验证中..." : "验证配置")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isValidatingConfigs)
                    }
                    
                    if showingValidationResults && !validationResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(validationResults, id: \.configName) { result in
                                ConfigValidationRow(result: result)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            
            // 批量操作
            SettingsCard(
                title: "批量操作",
                subtitle: "导入、导出和备份配置文件"
            ) {
                VStack(spacing: DesignTokens.Spacing.Component.settingRowSpacing) {
                    HStack(spacing: DesignTokens.Spacing.Component.rowInner) {
                        Button(action: importConfigs) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 12))
                                Text("导入配置")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: exportConfigs) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12))
                                Text("导出配置")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: backupConfigs) {
                            HStack(spacing: 6) {
                                Image(systemName: "archivebox")
                                    .font(.system(size: 12))
                                Text("备份配置")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text("支持批量导入/导出 JSON 配置文件，或创建完整备份")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 私有方法
    
    private func shortenPath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + String(path.dropFirst(homeDir.count))
        }
        return path
    }
    
    private func openCurrentDirectory() {
        let url = URL(fileURLWithPath: currentConfigPath)
        NSWorkspace.shared.open(url)
    }
    
    private func selectConfigDirectory() {
        isChangingDirectory = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let openPanel = NSOpenPanel()
            openPanel.title = "选择 Claude CLI 配置目录"
            openPanel.message = "请选择包含 Claude CLI API 配置文件的目录"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.showsHiddenFiles = true
            
            let currentURL = URL(fileURLWithPath: currentConfigPath)
            openPanel.directoryURL = currentURL.deletingLastPathComponent()
            
            let response = openPanel.runModal()
            if response == .OK, let selectedURL = openPanel.url {
                updateConfigDirectory(to: selectedURL)
            }
            
            isChangingDirectory = false
        }
    }
    
    private func resetToDefaultDirectory() {
        isChangingDirectory = true
        
        let defaultURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        
        updateConfigDirectory(to: defaultURL)
        
        isChangingDirectory = false
    }
    
    private func updateConfigDirectory(to url: URL) {
        if let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmarkData, forKey: "claudeDirectoryBookmark")
            UserDefaults.standard.set(url.path, forKey: "configDirectoryPath")
        }
        
        currentConfigPath = url.path
        appState.updateConfigDirectory(url)
        
        Task {
            await appState.loadConfigs()
        }
    }
    
    private func validateConfigs() {
        isValidatingConfigs = true
        validationResults.removeAll()
        
        Task {
            // 模拟配置验证过程
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            
            await MainActor.run {
                // 这里应该调用实际的配置验证服务
                validationResults = [
                    ConfigValidationResult(configName: "default", isValid: true, issues: []),
                    ConfigValidationResult(configName: "work", isValid: false, issues: ["缺少必需的 API Token"]),
                    ConfigValidationResult(configName: "personal", isValid: true, issues: [])
                ]
                
                showingValidationResults = true
                isValidatingConfigs = false
            }
        }
    }
    
    private func importConfigs() {
        let openPanel = NSOpenPanel()
        openPanel.title = "导入配置文件"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = true
        
        if openPanel.runModal() == .OK {
            // 处理导入逻辑
            for url in openPanel.urls {
                print("导入配置文件: \(url.path)")
            }
        }
    }
    
    private func exportConfigs() {
        let savePanel = NSSavePanel()
        savePanel.title = "导出配置文件"
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "claude-configs-\(DateFormatter().string(from: Date()))"
        
        if savePanel.runModal() == .OK {
            // 处理导出逻辑
            if let url = savePanel.url {
                print("导出配置到: \(url.path)")
            }
        }
    }
    
    private func backupConfigs() {
        let savePanel = NSSavePanel()
        savePanel.title = "备份配置目录"
        savePanel.allowedContentTypes = [.zip]
        savePanel.nameFieldStringValue = "claude-backup-\(DateFormatter().string(from: Date()))"
        
        if savePanel.runModal() == .OK {
            // 处理备份逻辑
            if let url = savePanel.url {
                print("备份配置到: \(url.path)")
            }
        }
    }
}

// MARK: - 配置验证结果

struct ConfigValidationResult {
    let configName: String
    let isValid: Bool
    let issues: [String]
}

struct ConfigValidationRow: View {
    let result: ConfigValidationResult
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.Component.rowInner) {
            Image(systemName: result.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(result.isValid ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.configName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                if !result.isValid && !result.issues.isEmpty {
                    Text(result.issues.joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if result.isValid {
                Text("正常")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            } else {
                Button("修复") {
                    // 修复配置问题
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(.vertical, 4)
    }
}