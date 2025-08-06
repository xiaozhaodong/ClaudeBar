import SwiftUI
import AppKit

// MARK: - Settings Navigation Tab Definition

enum SettingsNavigationTab: String, CaseIterable, Identifiable {
    case general = "general"
    case config = "config"
    case appearance = "appearance"
    case advanced = "advanced"
    case about = "about"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general:
            return "通用设置"
        case .config:
            return "API 端点管理"
        case .appearance:
            return "外观主题"
        case .advanced:
            return "高级选项"
        case .about:
            return "关于应用"
        }
    }
    
    var icon: String {
        switch self {
        case .general:
            return "gearshape.fill"
        case .config:
            return "folder.fill"
        case .appearance:
            return "paintbrush.fill"
        case .advanced:
            return "wrench.fill"
        case .about:
            return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool
    @State private var selectedTab: SettingsNavigationTab = .general
    @State private var currentConfigPath: String = "未设置"
    @State private var isChangingDirectory = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航菜单
            SettingsSidebarView(
                selectedTab: $selectedTab,
                isPresented: $isPresented
            )
            .frame(width: 280)
            .background(Color(.controlBackgroundColor))
            
            // 分隔线
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(width: 1)
            
            // 右侧内容区域
            SettingsContentView(
                selectedTab: selectedTab,
                currentConfigPath: $currentConfigPath,
                isChangingDirectory: $isChangingDirectory
            )
            .frame(maxWidth: .infinity)
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 800, height: 600)
        .background(Color(.windowBackgroundColor))
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

// MARK: - Settings Sidebar View

struct SettingsSidebarView: View {
    @Binding var selectedTab: SettingsNavigationTab
    @Binding var isPresented: Bool
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // 设置头部
            SettingsHeaderSection(isPresented: $isPresented)
            
            // 导航菜单项
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(SettingsNavigationTab.allCases) { tab in
                        SettingsTabItem(
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
            SettingsBottomSection()
        }
    }
}

// MARK: - Settings Tab Item

struct SettingsTabItem: View {
    let tab: SettingsNavigationTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: DesignTokens.Size.Icon.large)
                
                Text(tab.title)
                    .font(isSelected ? DesignTokens.Typography.navigationLabelSelected : DesignTokens.Typography.navigationLabel)
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

// MARK: - Settings Header Section

struct SettingsHeaderSection: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 返回按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: DesignTokens.Typography.IconSize.small, weight: .semibold))
                        Text("返回")
                            .font(DesignTokens.Typography.caption)
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
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("设置")
                        .font(DesignTokens.Typography.subtitle)
                        .foregroundColor(.primary)
                    
                    Text("应用配置")
                        .font(DesignTokens.Typography.small)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.Page.cardPadding)
            .padding(.vertical, DesignTokens.Spacing.lg)
            
            // 分隔线
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 1)
        }
    }
}

// MARK: - Settings Bottom Section

struct SettingsBottomSection: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 1)
            
            HStack {
                Text("版本 1.0.0")
                    .font(DesignTokens.Typography.small)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("帮助") {
                    if let url = URL(string: "https://docs.anthropic.com/claude/docs") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(DesignTokens.Typography.small)
                .foregroundColor(.blue)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, DesignTokens.Spacing.Page.cardPadding)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
    }
}

// MARK: - Settings Content View

struct SettingsContentView: View {
    let selectedTab: SettingsNavigationTab
    @Binding var currentConfigPath: String
    @Binding var isChangingDirectory: Bool
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .config:
                    ConfigSettingsView(
                        currentConfigPath: $currentConfigPath,
                        isChangingDirectory: $isChangingDirectory
                    )
                case .appearance:
                    AppearanceSettingsView()
                case .advanced:
                    AdvancedSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }
            .padding(DesignTokens.Spacing.Page.padding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
    }
}

// MARK: - Individual Settings Pages

struct GeneralSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.Page.componentSpacing) {
            // 页面标题
            VStack(alignment: .leading, spacing: 8) {
                Text("通用设置")
                    .font(DesignTokens.Typography.pageTitle)
                    .foregroundColor(.primary)
                
                Text("配置应用的基本行为和偏好")
                    .font(DesignTokens.Typography.subtitle)
                    .foregroundColor(.secondary)
            }
            
            // 通用设置内容
            VStack(spacing: 16) {
                ModernAppSettingsSection()
                
                NotificationSettingsSection()
                
                AutoRefreshSettingsSection()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ConfigSettingsView: View {
    @Binding var currentConfigPath: String
    @Binding var isChangingDirectory: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.Page.componentSpacing) {
            // 页面标题
            VStack(alignment: .leading, spacing: 8) {
                Text("配置管理")
                    .font(DesignTokens.Typography.pageTitle)
                    .foregroundColor(.primary)
                
                Text("管理 Claude CLI 配置文件和目录")
                    .font(DesignTokens.Typography.subtitle)
                    .foregroundColor(.secondary)
            }
            
            // 配置管理内容
            ModernConfigDirectorySection(
                currentPath: $currentConfigPath,
                isChangingDirectory: $isChangingDirectory
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppearanceSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.Page.componentSpacing) {
            // 页面标题
            VStack(alignment: .leading, spacing: 8) {
                Text("外观主题")
                    .font(DesignTokens.Typography.pageTitle)
                    .foregroundColor(.primary)
                
                Text("自定义应用界面的外观和主题")
                    .font(DesignTokens.Typography.subtitle)
                    .foregroundColor(.secondary)
            }
            
            // 外观设置内容
            ThemeSettingsSection()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AdvancedSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.Page.componentSpacing) {
            // 页面标题
            VStack(alignment: .leading, spacing: 8) {
                Text("高级选项")
                    .font(DesignTokens.Typography.pageTitle)
                    .foregroundColor(.primary)
                
                Text("高级功能和开发者选项")
                    .font(DesignTokens.Typography.subtitle)
                    .foregroundColor(.secondary)
            }
            
            // 高级设置内容
            DeveloperSettingsSection()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.Page.componentSpacing) {
            // 页面标题
            VStack(alignment: .leading, spacing: 8) {
                Text("关于应用")
                    .font(DesignTokens.Typography.pageTitle)
                    .foregroundColor(.primary)
                
                Text("应用信息、版本和帮助资源")
                    .font(DesignTokens.Typography.subtitle)
                    .foregroundColor(.secondary)
            }
            
            // 关于内容
            ModernAboutSection()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CompactConfigDirectorySection: View {
    @EnvironmentObject private var appState: AppState
    @Binding var currentPath: String
    @Binding var isChangingDirectory: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 区域标题
            HStack {
                Text("配置目录")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                DirectoryStatusIndicator(path: currentPath)
            }
            
            // 当前配置目录显示
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    
                    Text(shortenPath(currentPath))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    // 打开目录按钮
                    Button(action: openCurrentDirectory) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("在 Finder 中打开")
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // 操作按钮区域
            VStack(spacing: 8) {
                // 选择配置目录按钮
                Button(action: selectConfigDirectory) {
                    HStack(spacing: 6) {
                        if isChangingDirectory {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.system(size: 12, weight: .medium))
                        }
                        
                        Text(isChangingDirectory ? "选择中..." : "选择目录")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .foregroundColor(isChangingDirectory ? .secondary : .white)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isChangingDirectory ? Color.gray.opacity(0.3) : Color.blue)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isChangingDirectory)
                
                // 重置为默认目录按钮
                Button(action: resetToDefaultDirectory) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                        
                        Text("重置默认")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .foregroundColor(.blue)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isChangingDirectory)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func shortenPath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + String(path.dropFirst(homeDir.count))
        }
        return path
    }
    
    private func openCurrentDirectory() {
        let url = URL(fileURLWithPath: currentPath)
        NSWorkspace.shared.open(url)
    }
    
    private func selectConfigDirectory() {
        isChangingDirectory = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let openPanel = NSOpenPanel()
            openPanel.title = "选择 Claude 配置目录"
            openPanel.message = "请选择包含 Claude 配置文件的目录"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.showsHiddenFiles = true
            
            let currentURL = URL(fileURLWithPath: currentPath)
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
        
        currentPath = url.path
        appState.updateConfigDirectory(url)
        
        Task {
            await appState.loadConfigs()
        }
    }
}

struct CompactAppSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("应用设置")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                CompactSettingRow(
                    icon: "bell.fill",
                    title: "显示通知",
                    control: AnyView(
                        Toggle("", isOn: .constant(true))
                            .controlSize(.small)
                    )
                )
                
                CompactSettingRow(
                    icon: "clock.fill",
                    title: "自动刷新",
                    control: AnyView(
                        Toggle("", isOn: .constant(false))
                            .controlSize(.small)
                    )
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct CompactSettingRow: View {
    let icon: String
    let title: String
    let control: AnyView
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            control
        }
        .padding(.vertical, 2)
    }
}

struct CompactAboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关于")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude 配置管理器")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("版本 1.0.0")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 12) {
                    Button("GitHub") {
                        if let url = URL(string: "https://github.com/anthropics/claude-cli") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("帮助") {
                        if let url = URL(string: "https://docs.anthropic.com/claude/docs") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Modern Settings Components

struct ModernConfigDirectorySection: View {
    @EnvironmentObject private var appState: AppState
    @Binding var currentPath: String
    @Binding var isChangingDirectory: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 区域标题
            HStack {
                Text("配置目录")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                DirectoryStatusIndicator(path: currentPath)
            }
            
            // 当前配置目录显示
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前配置目录")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(shortenPath(currentPath))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    
                    Spacer()
                    
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // 操作按钮区域
                HStack(spacing: 12) {
                    // 选择配置目录按钮
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
                        .frame(height: 40)
                        .foregroundColor(isChangingDirectory ? .secondary : .white)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isChangingDirectory ? Color.gray.opacity(0.3) : Color.blue)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isChangingDirectory)
                    
                    // 重置为默认目录按钮
                    Button(action: resetToDefaultDirectory) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                            
                            Text("重置默认")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundColor(.blue)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isChangingDirectory)
                }
            }
        }
        .padding(DesignTokens.Spacing.Page.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    // 复用原有的私有方法
    private func shortenPath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + String(path.dropFirst(homeDir.count))
        }
        return path
    }
    
    private func openCurrentDirectory() {
        let url = URL(fileURLWithPath: currentPath)
        NSWorkspace.shared.open(url)
    }
    
    private func selectConfigDirectory() {
        isChangingDirectory = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let openPanel = NSOpenPanel()
            openPanel.title = "选择 Claude 配置目录"
            openPanel.message = "请选择包含 Claude 配置文件的目录"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.showsHiddenFiles = true
            
            let currentURL = URL(fileURLWithPath: currentPath)
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
        
        currentPath = url.path
        appState.updateConfigDirectory(url)
        
        Task {
            await appState.loadConfigs()
        }
    }
}

struct ModernAppSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("应用行为")
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ModernSettingRow(
                    icon: "bell.fill",
                    title: "显示通知",
                    description: "API 端点切换成功时显示通知",
                    control: AnyView(
                        Toggle("", isOn: .constant(true))
                            .controlSize(.small)
                    )
                )
                
                ModernSettingRow(
                    icon: "clock.fill",
                    title: "自动刷新",
                    description: "定时自动刷新配置列表",
                    control: AnyView(
                        Toggle("", isOn: .constant(false))
                            .controlSize(.small)
                    )
                )
                
                ModernSettingRow(
                    icon: "menubar.arrow.up.rectangle",
                    title: "启动时显示",
                    description: "应用启动时自动显示主界面",
                    control: AnyView(
                        Toggle("", isOn: .constant(false))
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

struct NotificationSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("通知设置")
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ModernSettingRow(
                    icon: "checkmark.circle.fill",
                    title: "成功通知",
                    description: "API 端点切换成功时显示通知",
                    control: AnyView(
                        Toggle("", isOn: .constant(true))
                            .controlSize(.small)
                    )
                )
                
                ModernSettingRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "错误通知",
                    description: "出现错误时显示通知",
                    control: AnyView(
                        Toggle("", isOn: .constant(true))
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

struct AutoRefreshSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("自动刷新")
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ModernSettingRow(
                    icon: "arrow.clockwise",
                    title: "启用自动刷新",
                    description: "定期检查配置文件变化",
                    control: AnyView(
                        Toggle("", isOn: .constant(false))
                            .controlSize(.small)
                    )
                )
                
                ModernSettingRow(
                    icon: "timer",
                    title: "刷新间隔",
                    description: "自动刷新的时间间隔（秒）",
                    control: AnyView(
                        Stepper("30秒", value: .constant(30), in: 10...300, step: 10)
                            .labelsHidden()
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

struct ThemeSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("界面主题")
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ModernSettingRow(
                    icon: "sun.max.fill",
                    title: "外观模式",
                    description: "选择应用的外观主题",
                    control: AnyView(
                        Picker("", selection: .constant("auto")) {
                            Text("自动").tag("auto")
                            Text("浅色").tag("light")
                            Text("深色").tag("dark")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 180)
                    )
                )
                
                ModernSettingRow(
                    icon: "paintbrush.fill",
                    title: "强调色",
                    description: "选择界面的强调色",
                    control: AnyView(
                        HStack(spacing: 8) {
                            ForEach(["blue", "green", "orange", "red", "purple"], id: \.self) { color in
                                Circle()
                                    .fill(Color(color))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: color == "blue" ? 2 : 0)
                                    )
                            }
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
    }
}

struct DeveloperSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("开发者选项")
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ModernSettingRow(
                    icon: "terminal.fill",
                    title: "调试日志",
                    description: "启用详细的调试日志记录",
                    control: AnyView(
                        Toggle("", isOn: .constant(false))
                            .controlSize(.small)
                    )
                )
                
                ModernSettingRow(
                    icon: "doc.text.fill",
                    title: "导出日志",
                    description: "导出应用日志文件",
                    control: AnyView(
                        Button("导出") {
                            // 导出日志逻辑
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    )
                )
                
                ModernSettingRow(
                    icon: "trash.fill",
                    title: "重置所有设置",
                    description: "将所有设置恢复为默认值",
                    control: AnyView(
                        Button("重置") {
                            // 重置设置逻辑
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
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

struct ModernAboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 应用信息
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "terminal.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 28, weight: .medium))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude 配置管理器")
                        .font(DesignTokens.Typography.pageTitle)
                        .foregroundColor(.primary)
                    
                    Text("版本 1.0.0 (Build 1)")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(.secondary)
                    
                    Text("© 2024 Claude Config Manager")
                        .font(DesignTokens.Typography.small)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            // 链接和帮助
            VStack(alignment: .leading, spacing: 16) {
                Text("帮助和支持")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    ModernLinkRow(
                        icon: "book.fill",
                        title: "使用文档",
                        url: "https://docs.anthropic.com/claude/docs"
                    )
                    
                    ModernLinkRow(
                        icon: "chevron.left.forwardslash.chevron.right",
                        title: "GitHub 仓库",
                        url: "https://github.com/anthropics/claude-cli"
                    )
                    
                    ModernLinkRow(
                        icon: "questionmark.circle.fill",
                        title: "技术支持",
                        url: "https://support.anthropic.com"
                    )
                    
                    ModernLinkRow(
                        icon: "shield.fill",
                        title: "隐私政策",
                        url: "https://www.anthropic.com/privacy"
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

struct ModernSettingRow: View {
    let icon: String
    let title: String
    let description: String
    let control: AnyView
    
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
            
            control
        }
        .padding(.vertical, 4)
    }
}

struct ModernLinkRow: View {
    let icon: String
    let title: String
    let url: String
    @State private var isHovered = false
    
    var body: some View {
        Button(action: openURL) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: DesignTokens.Size.Icon.medium)
                
                Text(title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: DesignTokens.Typography.IconSize.small, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.blue.opacity(0.05) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered ? Color.blue.opacity(0.2) : Color.clear, lineWidth: 1)
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

#Preview {
    SettingsView(isPresented: .constant(true))
        .environmentObject(AppState())
}
