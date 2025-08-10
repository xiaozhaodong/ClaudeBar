import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MenuBarViewModel()
    
    var body: some View {
        VStack(spacing: 6) { // 减小整体spacing，为各区域节省空间
            // 新设计的头部区域
            ModernHeaderSection()
            
            // 当前配置状态卡片
            if appState.currentConfig != nil {
                CurrentConfigCard()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6) // 减小底部padding
            }
            
            // 配置列表区域
            ModernConfigListSection()
            
            // 控制面板
            ModernControlPanel()
            
            // 底部信息区域
            BottomInfoSection()
        }
        .frame(width: 320)
        .fixedSize(horizontal: true, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            viewModel.setAppState(appState)
        }
    }
}

// MARK: - 现代化组件设计

struct ModernHeaderSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // 渐变背景头部
            HStack(spacing: 12) {
                // 应用图标 - 渐变设计
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
                    Text("Claude CLI API 切换器")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // 实时状态指示
                    HStack(spacing: 6) {
                        StatusIndicatorDot()
                        Text(statusText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 打开主界面按钮
                Button(action: {
                    appState.openMainWindow()
                }) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .opacity(0)
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // 悬停效果可以在这里添加
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8) // 减少垂直padding
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // 细线分隔
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
        }
    }
    
    private var statusText: String {
        if appState.isLoading {
            return "加载中..."
        } else if let currentConfig = appState.currentConfig {
            return currentConfig.isValid ? "运行正常" : "端点异常"
        } else {
            return "未配置端点"
        }
    }
}


struct CurrentConfigCard: View {
    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    
    var body: some View {
        if let currentConfig = appState.currentConfig {
            VStack(spacing: 0) {
                // 卡片内容
                VStack(alignment: .leading, spacing: 12) {
                    // 头部：配置名称和状态
                    HStack(alignment: .center, spacing: 12) {
                        // 状态指示器
                        ZStack {
                            Circle()
                                .fill(statusBackgroundColor)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: statusIcon)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(currentConfig.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                Text("当前 API 端点")
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            
                            Text(statusDescription)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(statusTextColor)
                        }
                        
                        Spacer()
                    }
                    
                    // 配置详情
                    VStack(spacing: 8) {
                        ConfigDetailRow(
                            icon: "link",
                            label: "API 端点",
                            value: currentConfig.baseURLDisplay,
                            valueColor: .secondary
                        )
                        
                        ConfigDetailRow(
                            icon: "key.fill",
                            label: "访问令牌",
                            value: currentConfig.tokenPreview,
                            valueColor: .secondary
                        )
                        
                        if !currentConfig.isValid {
                            ConfigDetailRow(
                                icon: "exclamationmark.triangle.fill",
                                label: "状态",
                                value: "端点需要修复",
                                valueColor: .orange
                            )
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderColor, lineWidth: 1)
                        )
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .shadow(
                    color: isHovered ? Color.black.opacity(0.1) : Color.clear,
                    radius: isHovered ? 8 : 0,
                    x: 0,
                    y: isHovered ? 4 : 0
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovered = hovering
                    }
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
        return currentConfig.isValid ? "端点正常运行" : "端点存在问题"
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
            await appState.forceRefreshConfigs()
        }
    }
    
    private func openConfigFile() {
        // 打开配置文件的逻辑
        let configDirectory = getRealClaudeConfigDirectory()
        NSWorkspace.shared.open(configDirectory)
    }
    
    private func getRealClaudeConfigDirectory() -> URL {
        let username = NSUserName()
        let realHomePath = "/Users/\(username)"
        
        if FileManager.default.fileExists(atPath: realHomePath) {
            return URL(fileURLWithPath: realHomePath).appendingPathComponent(".claude")
        }
        
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            return URL(fileURLWithPath: homeDir).appendingPathComponent(".claude")
        }
        
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude")
    }
}


struct ConfigDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 4)
    }
}

struct SearchBar: View {
    @Binding var searchText: String
    @State private var isSearchFocused = false
    
    var body: some View {
        HStack(spacing: 10) {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(searchText.isEmpty ? .secondary : .blue)
            
            // 搜索输入框
            TextField("搜索 API 端点...", text: $searchText)
                .font(.system(size: 13, weight: .medium))
                .textFieldStyle(PlainTextFieldStyle())
                .onTapGesture {
                    isSearchFocused = true
                }
            
            // 清除按钮
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSearchFocused ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
    }
}

struct ModernConfigListSection: View {
    @EnvironmentObject private var appState: AppState
    @State private var refreshTask: Task<Void, Never>?
    
    private var filteredConfigs: [ClaudeConfig] {
        return appState.availableConfigs
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 列表头部
            HStack {
                Text("可用 API 端点")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                if !filteredConfigs.isEmpty {
                    Text("(\(filteredConfigs.count))")
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
            .padding(.horizontal, 16)
            
            // 配置列表内容
            if appState.isLoading {
                LoadingStateView()
            } else if filteredConfigs.isEmpty {
                EmptyStateView()
            } else {
                ConfigGridView(configs: filteredConfigs)
            }
        }
        .onDisappear {
            refreshTask?.cancel()
        }
    }
    
    private func refreshConfigs() {
        guard !appState.isLoading else { return }
        
        refreshTask?.cancel()
        refreshTask = Task {
            await appState.forceRefreshConfigs()
        }
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonConfigCard()
            }
        }
        .padding(.horizontal, 16)
    }
}

struct SkeletonConfigCard: View {
    @State private var animationOffset: CGFloat = -1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 骨架圆点
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 16, height: 16)
                
                // 骨架文本
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 14)
                    .frame(maxWidth: 120)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 16, height: 16)
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 12)
                .frame(maxWidth: 200)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    // 闪烁动画
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: animationOffset * 300)
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

struct EmptyStateView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            // 空状态图标
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "doc.text")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                Text("未找到配置文件")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("请选择包含配置文件的目录")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("选择配置目录") {
                // 调用 AppState 的公共方法
                appState.requestConfigDirectoryAccess()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("授权 ~/.claude 目录") {
                // 直接调用权限请求
                appState.requestClaudeDirectoryAccess()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }
    
    private func getRealClaudeConfigDirectory() -> URL {
        let username = NSUserName()
        let realHomePath = "/Users/\(username)"
        
        if FileManager.default.fileExists(atPath: realHomePath) {
            return URL(fileURLWithPath: realHomePath).appendingPathComponent(".claude")
        }
        
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            return URL(fileURLWithPath: homeDir).appendingPathComponent(".claude")
        }
        
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude")
    }
}

struct ConfigGridView: View {
    let configs: [ClaudeConfig]
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(configs) { config in
                ModernConfigRow(config: config)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct ModernConfigRow: View {
    let config: ClaudeConfig
    @EnvironmentObject private var appState: AppState
    @State private var switchTask: Task<Void, Never>?
    @State private var isHovered = false
    
    private var isCurrentConfig: Bool {
        appState.currentConfig?.name == config.name
    }
    
    private var isDisabled: Bool {
        appState.isLoading || isCurrentConfig
    }
    
    var body: some View {
        Button(action: { switchToConfig() }) {
            HStack(spacing: 12) {
                // 状态指示器
                ZStack {
                    Circle()
                        .stroke(statusBorderColor, lineWidth: 2)
                        .frame(width: 16, height: 16)
                    
                    if isCurrentConfig {
                        Circle()
                            .fill(statusFillColor)
                            .frame(width: 8, height: 8)
                    }
                }
                
                // 配置信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(config.name)
                            .font(.system(size: 14, weight: isCurrentConfig ? .semibold : .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        
                        if isCurrentConfig {
                            Text("当前")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        
                        Spacer(minLength: 4)
                        
                        // 配置状态图标
                        Image(systemName: config.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(config.isValid ? .green : .orange)
                    }
                    
                    Text(config.baseURLDisplay)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundFillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered && !isDisabled ? 1.02 : 1.0)
            .shadow(
                color: isHovered && !isDisabled ? Color.black.opacity(0.08) : Color.clear,
                radius: isHovered && !isDisabled ? 4 : 0,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled && !isCurrentConfig ? 0.6 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onDisappear {
            switchTask?.cancel()
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
        
        switchTask?.cancel()
        switchTask = Task {
            await appState.switchConfig(config)
        }
    }
}

struct ModernControlPanel: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                // 使用统计状态区域
                ModernUsageStatisticsSection()
                
                // Claude 进程状态区域
                ModernProcessStatusSection()
                
                // 错误信息显示
                if let errorMessage = appState.errorMessage {
                    ErrorMessageView(message: errorMessage)
                }
                
                // 成功信息显示
                if let successMessage = appState.successMessage {
                    SuccessMessageView(message: successMessage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }
}

struct ModernProcessStatusSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            // 进程状态标题
            HStack {
                Text("Claude 进程")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: refreshStatus) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 进程状态卡片或进程列表
            if appState.claudeProcessStatus.processCount > 0 {
                // 显示进程列表
                ProcessListView(processes: appState.claudeProcessStatus.processes)
            } else {
                // 显示空状态
                EmptyProcessView()
            }
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
    
    private var processStatusTitle: String {
        return appState.claudeProcessStatus.displayText
    }
    
    private var processStatusDescription: String {
        switch appState.claudeProcessStatus {
        case .running(let processes):
            if processes.isEmpty {
                return "没有检测到 Claude 进程"
            } else {
                return "检测到 \(processes.count) 个 Claude 进程"
            }
        case .stopped:
            return "没有 Claude 进程在运行"
        case .error(let message):
            return message
        case .unknown:
            return "正在检查状态..."
        }
    }
    
    private func refreshStatus() {
        appState.refreshProcessStatus()
    }
}

struct ErrorMessageView: View {
    let message: String
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.9)),
                removal: .opacity.combined(with: .scale(scale: 0.9))
            ))
        }
    }
}

// MARK: - 使用统计状态区域（与进程状态区域风格统一）
struct ModernUsageStatisticsSection: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            // 使用统计标题和刷新按钮（与Claude进程标题保持一致的风格）
            HStack {
                Text("使用统计")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: refreshUsageStats) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 使用统计卡片内容（纯内容，无标题栏）
            if appState.isLoadingUsage {
                LoadingUsageStatsView()
            } else if let statistics = appState.usageStatistics {
                UsageStatsDisplayCard(statistics: statistics)
            } else {
                EmptyUsageStatsView()
            }
        }
    }
    
    private func refreshUsageStats() {
        Task {
            await appState.refreshUsageStatistics()
        }
    }
}

// MARK: - 使用统计显示卡片（纯内容，无标题栏）
struct UsageStatsDisplayCard: View {
    let statistics: UsageStatistics
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 8) {
            // 总体统计
            UsageStatsContent(statistics: statistics)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            
            // 最近三天统计
            RecentDaysUsageView(statistics: statistics)
        }
        .onTapGesture {
            // 点击统计卡片打开主窗口的使用统计页面
            appState.openUsageStatistics()
        }
    }
}

// MARK: - 使用统计内容组件
struct UsageStatsContent: View {
    let statistics: UsageStatistics
    
    var body: some View {
        HStack(spacing: 16) {
            // 总成本
            StatisticColumn(
                title: "总成本",
                value: statistics.formattedTotalCost,
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 32)
            
            // 总会话
            StatisticColumn(
                title: "总会话",
                value: statistics.formattedTotalSessions,
                icon: "message.circle.fill",
                color: .blue
            )
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 32)
            
            // 总令牌
            StatisticColumn(
                title: "总令牌",
                value: statistics.formattedTotalTokens,
                icon: "cpu.fill",
                color: .purple
            )
        }
    }
}

struct StatisticColumn: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            
            // 数值
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // 标题
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 最近三天使用数据组件
struct RecentDaysUsageView: View {
    let statistics: UsageStatistics
    
    var body: some View {
        VStack(spacing: 6) {
            // 标题行
            HStack {
                Text("最近三天")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            // 每日数据
            VStack(spacing: 4) {
                ForEach(getRecentDaysData(), id: \.dayLabel) { dayData in
                    RecentDayRow(dayData: dayData)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
    
    // 获取最近三天的数据
    private func getRecentDaysData() -> [RecentDayData] {
        var result: [RecentDayData] = []
        
        // 现在 UsageEntry.dateString 已经使用正确的本地时区转换
        // statistics.byDate 中的日期已经是按本地日期分组的
        // 所以直接按照本地日期查找即可
        let calendar = Calendar.current
        let now = Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en-CA")
        dateFormatter.timeZone = TimeZone.current  // 使用系统时区，与 ccusage 一致
        
        // 获取最近三天的日期（今天、昨天、前天）
        for dayOffset in 0...2 {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dateString = dateFormatter.string(from: targetDate)
            
            let dayLabel: String
            switch dayOffset {
            case 0:
                dayLabel = "今天"
            case 1:
                dayLabel = "昨天"
            case 2:
                dayLabel = "前天"
            default:
                dayLabel = "其他"
            }
            
            // 查找对应日期的数据
            let dayUsage = statistics.byDate.first { $0.date == dateString }
            
            result.append(RecentDayData(
                dayLabel: dayLabel,
                date: dateString,
                cost: dayUsage?.totalCost ?? 0,
                tokens: dayUsage?.totalTokens ?? 0
            ))
        }
        
        return result
    }
}

// 最近一天的数据模型
struct RecentDayData {
    let dayLabel: String
    let date: String
    let cost: Double
    let tokens: Int
    
    var formattedCost: String {
        if cost == 0 {
            return "-"
        }
        return String(format: "$%.2f", cost)
    }
    
    var formattedTokens: String {
        if tokens == 0 {
            return "-"
        } else if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        } else {
            return "\(tokens)"
        }
    }
}

// 最近一天的数据行
struct RecentDayRow: View {
    let dayData: RecentDayData
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 日期标签
            HStack(spacing: 6) {
                Circle()
                    .fill(dayLabelColor)
                    .frame(width: 6, height: 6)
                
                Text(dayData.dayLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(minWidth: 32, alignment: .leading)
            }
            
            Spacer()
            
            // 成本
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                
                Text(dayData.formattedCost)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(dayData.cost > 0 ? .primary : .secondary)
                    .frame(minWidth: 45, alignment: .trailing)
            }
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 12)
            
            // 令牌数
            HStack(spacing: 4) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                
                Text(dayData.formattedTokens)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(dayData.tokens > 0 ? .primary : .secondary)
                    .frame(minWidth: 45, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var dayLabelColor: Color {
        // 根据日期标签显示不同的颜色
        switch dayData.dayLabel {
        case "今天":
            return .blue
        case "昨天":
            return .orange
        case "前天":
            return .gray
        default:
            return .gray
        }
    }
}

// MARK: - 占位状态组件
struct LoadingUsageStatsView: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 6) {
                    // 骨架图标
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 16, height: 16)
                    
                    // 骨架数值
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 14)
                        .frame(maxWidth: 48)
                    
                    // 骨架标题
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 10)
                        .frame(maxWidth: 32)
                }
                .frame(maxWidth: .infinity)
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

struct ErrorUsageStatsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("点击重试")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture {
            Task {
                await appState.refreshUsageStatistics()
            }
        }
    }
}

struct EmptyUsageStatsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
            
            Text("暂无数据")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("点击刷新")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture {
            Task {
                await appState.refreshUsageStatistics()
            }
        }
    }
}

// MARK: - 辅助函数

extension MenuBarView {
    private func getRealClaudeConfigDirectory() -> URL {
        let username = NSUserName()
        let realHomePath = "/Users/\(username)"
        
        if FileManager.default.fileExists(atPath: realHomePath) {
            return URL(fileURLWithPath: realHomePath).appendingPathComponent(".claude")
        }
        
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            return URL(fileURLWithPath: homeDir).appendingPathComponent(".claude")
        }
        
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude")
    }
}


struct BottomInfoSection: View {
    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                // 版本信息
                HStack {
                    Text("版本 1.0.0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 快捷键提示
                    HStack(spacing: 4) {
                        Text("⌘Q")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        
                        Text("退出")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 退出按钮
                Button("退出 Claude CLI API 切换器") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12) // 恢复底部padding，确保退出按钮不被截断
        }
    }
}

// MARK: - 进程显示组件

struct ProcessListView: View {
    let processes: [ProcessService.ClaudeProcess]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(processes) { process in
                ProcessRowView(process: process)
            }
        }
    }
}

struct ProcessRowView: View {
    let process: ProcessService.ClaudeProcess
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主要信息行
            HStack(spacing: 12) {
                // 状态指示器
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(process.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("PID: \(process.pid)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // CPU 和内存使用率显示
                    HStack(spacing: 12) {
                        // CPU 使用率
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("CPU: \(process.cpuUsageText)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(process.cpuUsageColor))
                        }
                        
                        // 内存使用
                        HStack(spacing: 4) {
                            Image(systemName: "memorychip")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("内存: \(process.memoryUsageText)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(process.memoryUsageColor))
                        }
                        
                        Spacer()
                    }
                    
                    if let executablePath = process.executablePath {
                        Text(URL(fileURLWithPath: executablePath).lastPathComponent)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                // 展开/折叠按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // 详细信息（展开时显示）
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if let executablePath = process.executablePath {
                        ProcessDetailRow(
                            icon: "terminal",
                            label: "可执行文件",
                            value: executablePath
                        )
                    }
                    
                    // CPU 使用率详情
                    ProcessDetailRow(
                        icon: "cpu",
                        label: "CPU 使用率",
                        value: process.cpuUsageText,
                        valueColor: Color(process.cpuUsageColor)
                    )
                    
                    // 内存使用详情
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
                    } else {
                        ProcessDetailRow(
                            icon: "memorychip",
                            label: "内存使用",
                            value: "N/A"
                        )
                    }
                    
                    if let startTime = process.startTime {
                        ProcessDetailRow(
                            icon: "clock",
                            label: "启动时间",
                            value: formatStartTime(startTime)
                        )
                    }
                    
                    if let workingDirectory = process.workingDirectory {
                        ProcessDetailRow(
                            icon: "folder",
                            label: "工作目录",
                            value: workingDirectory
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
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
}


struct EmptyProcessView: View {
    var body: some View {
        HStack(spacing: 12) {
            // 状态指示器
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("没有检测到 Claude 进程")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Claude CLI 当前未在运行")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct SuccessMessageView: View {
    let message: String
    @EnvironmentObject private var appState: AppState
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible = false
                        appState.dismissSuccessMessage()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.9)),
                removal: .opacity.combined(with: .scale(scale: 0.9))
            ))
        }
    }
}
