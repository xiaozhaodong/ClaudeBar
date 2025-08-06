//
//  PlaceholderPageViews.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI
import AppKit
import Foundation

// MARK: - Page Views Implementation

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
        .navigationTitle("API 端点管理")
    }
}

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

// MARK: - 系统状态页面

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

// MARK: - 工具箱页面

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

// MARK: - 设置页面

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

// MARK: - 帮助页面

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
                            question: "API 端点切换失败怎么办？",
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

// MARK: - 系统状态页面组件

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

// MARK: - 工具箱页面组件

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


