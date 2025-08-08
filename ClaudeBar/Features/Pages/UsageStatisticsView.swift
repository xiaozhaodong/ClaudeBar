import SwiftUI

/// 使用统计主界面
struct UsageStatisticsView: View {
    @StateObject private var viewModel: UsageStatisticsViewModel
    
    init(configService: ConfigServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: UsageStatisticsViewModel(configService: configService))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.Page.componentSpacing) {
            // 页面标题区域
            pageHeaderView
            
            // 日期选择器区域
            dateRangeSelector
                .padding(.horizontal, DesignTokens.Spacing.Page.padding)
            
            // 内容区域
            contentView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DesignTokens.Spacing.Page.padding)
        .onAppear {
            Task {
                await viewModel.onPageAppear()
            }
        }
        .onDisappear {
            viewModel.onPageDisappear()
        }
    }
    
    /// 页面标题区域
    private var pageHeaderView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("使用统计")
                        .font(DesignTokens.Typography.pageTitle)
                        .foregroundColor(.primary)
                    
                    Text("跟踪您的 Claude 使用情况和成本")
                        .font(DesignTokens.Typography.subtitle)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 刷新按钮
                Button(action: {
                    Task {
                        await viewModel.refreshStatistics()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: DesignTokens.Typography.IconSize.medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .disabled(viewModel.isLoading)
            }
            
            // 缓存状态指示器
            HStack {
                CacheStatusIndicator(
                    status: viewModel.cacheStatus,
                    metadata: viewModel.cacheMetadata,
                    onRefresh: {
                        await viewModel.refreshStatistics()
                    }
                )
                
                Spacer()
            }
            
            // 缓存过期提醒（仅在即将过期时显示）
            if let metadata = viewModel.cacheMetadata, metadata.isNearExpiry {
                CacheExpiryReminder(metadata: metadata) {
                    await viewModel.refreshStatistics()
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.Page.padding)
    }
    
    /// 日期范围选择器
    private var dateRangeSelector: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(DateRange.allCases, id: \.self) { range in
                    Button(range.displayName) {
                        Task {
                            await viewModel.switchToDateRange(range)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                            .fill(
                                viewModel.selectedDateRange == range ? 
                                    DesignTokens.Colors.accent : 
                                    DesignTokens.Colors.controlBackground
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                                    .stroke(
                                        viewModel.selectedDateRange == range ? 
                                            DesignTokens.Colors.accent : 
                                            DesignTokens.Colors.separator.opacity(0.3), 
                                        lineWidth: 1
                                    )
                            )
                    )
                    .foregroundColor(
                        viewModel.selectedDateRange == range ? 
                            .white : 
                            DesignTokens.Colors.primaryText
                    )
                    .font(DesignTokens.Typography.body)
                    .scaleEffect(viewModel.selectedDateRange == range ? 1.02 : 1.0)
                }
                
                Spacer()
            }
            
            // 分隔线
            Rectangle()
                .fill(DesignTokens.Colors.separator.opacity(0.3))
                .frame(height: 1)
        }
    }
    
    /// 内容区域
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else if let statistics = viewModel.statistics {
                statisticsView(statistics)
            } else {
                emptyView
            }
        }
    }
    
    /// 加载视图
    private var loadingView: some View {
        UsageStatisticsSkeletonView()
    }
    
    /// 错误视图
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("重试") {
                Task {
                    await viewModel.loadStatistics()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 空数据视图
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("暂无使用数据")
                .font(.headline)
            
            Text("请确认 ~/.claude/projects 目录存在且包含使用数据")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 统计数据视图
    private func statisticsView(_ statistics: UsageStatistics) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xl) {
                // 概览卡片
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack {
                        Text("使用概览")
                            .font(DesignTokens.Typography.sectionTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.Colors.primaryText)
                        
                        Spacer()
                        
                        // 数据更新时间
                        Text("数据更新于 \(getCurrentTimeString())")
                            .font(DesignTokens.Typography.small)
                            .foregroundColor(DesignTokens.Colors.secondaryText)
                    }
                    
                    overviewCards(statistics)
                }
                
                // 标签页内容
                tabContent(statistics)
            }
            .padding(.horizontal, DesignTokens.Spacing.Page.padding)
            .padding(.top, DesignTokens.Spacing.lg)
            .animation(DesignTokens.Animation.pageTransition, value: statistics.id)
        }
        .background(DesignTokens.Colors.windowBackground)
    }
    
    /// 获取当前时间字符串
    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
    
    /// 概览卡片
    private func overviewCards(_ statistics: UsageStatistics) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.lg), count: 2), 
            spacing: DesignTokens.Spacing.lg
        ) {
            StatCard(
                title: "总成本",
                value: statistics.formattedTotalCost,
                icon: "dollarsign.circle",
                color: .green
            )
            
            StatCard(
                title: "总会话数",
                value: statistics.formattedTotalSessions,
                icon: "bubble.left.and.bubble.right",
                color: .blue
            )
            
            StatCard(
                title: "总令牌数",
                value: statistics.formattedTotalTokens,
                icon: "doc.text",
                color: .orange
            )
            
            StatCard(
                title: "平均每请求成本",
                value: String(format: "$%.2f", statistics.averageCostPerRequest),
                icon: "chart.line.uptrend.xyaxis",
                color: .purple
            )
        }
    }
    
    /// 标签页内容
    private func tabContent(_ statistics: UsageStatistics) -> some View {
        VStack(spacing: 0) {
            // 标签页选择器
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(UsageTab.allCases, id: \.self) { tab in
                    Button(tab.displayName) {
                        withAnimation(DesignTokens.Animation.standard) {
                            viewModel.selectedTab = tab
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                            .fill(
                                viewModel.selectedTab == tab ? 
                                    DesignTokens.Colors.accent : 
                                    DesignTokens.Colors.controlBackground
                            )
                            .shadow(
                                color: viewModel.selectedTab == tab ? 
                                    DesignTokens.Colors.accent.opacity(0.3) : 
                                    Color.clear,
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    )
                    .foregroundColor(
                        viewModel.selectedTab == tab ? 
                            .white : 
                            DesignTokens.Colors.primaryText
                    )
                    .font(DesignTokens.Typography.body)
                    .fontWeight(viewModel.selectedTab == tab ? .semibold : .medium)
                    .scaleEffect(viewModel.selectedTab == tab ? 1.05 : 1.0)
                }
                
                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                    .fill(DesignTokens.Colors.controlBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                            .stroke(DesignTokens.Colors.separator.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // 标签页内容
            VStack {
                switch viewModel.selectedTab {
                case .overview:
                    OverviewTabView(statistics: statistics)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                case .models:
                    ModelsTabView(models: statistics.byModel)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                case .projects:
                    ProjectsTabView(projects: statistics.byProject)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                case .timeline:
                    TimelineTabView(dailyUsage: statistics.byDate)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                }
            }
            .padding(.top, DesignTokens.Spacing.lg)
        }
    }
}

/// 增强版统计卡片组件
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let gradient: LinearGradient
    @State private var isHovered = false
    
    init(title: String, value: String, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        
        // 根据颜色选择对应的渐变
        switch color {
        case .green:
            self.gradient = DesignTokens.Colors.StatCard.costGradient
        case .blue:
            self.gradient = DesignTokens.Colors.StatCard.sessionGradient
        case .orange:
            self.gradient = DesignTokens.Colors.StatCard.tokenGradient
        case .purple:
            self.gradient = DesignTokens.Colors.StatCard.averageGradient
        default:
            self.gradient = DesignTokens.Colors.StatCard.sessionGradient
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 顶部图标行
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                
                Spacer()
            }
            
            // 主要数值
            Text(value)
                .font(DesignTokens.Typography.sectionTitle)
                .fontWeight(.bold)
                .foregroundColor(DesignTokens.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // 标题
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.secondaryText)
                .lineLimit(1)
        }
        .statCardStyle(gradient: gradient, shadow: isHovered)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.cardHover) {
                isHovered = hovering
            }
        }
    }
}


/// 概览标签页视图
struct UsageOverviewTabView: View {
    let statistics: UsageStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 令牌详情
            tokenDetailsSection
            
            // 最常用模型
            topModelsSection
            
            // 热门项目
            topProjectsSection
        }
    }
    
    /// 令牌详情部分
    private var tokenDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("令牌详情")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                TokenDetailCard(
                    title: "输入令牌",
                    value: formatTokenCount(statistics.totalInputTokens),
                    color: DesignTokens.Colors.Token.input
                )
                
                TokenDetailCard(
                    title: "输出令牌",
                    value: formatTokenCount(statistics.totalOutputTokens),
                    color: DesignTokens.Colors.Token.output
                )
                
                TokenDetailCard(
                    title: "缓存写入",
                    value: formatTokenCount(statistics.totalCacheCreationTokens),
                    color: DesignTokens.Colors.Token.cacheWrite
                )
                
                TokenDetailCard(
                    title: "缓存读取",
                    value: formatTokenCount(statistics.totalCacheReadTokens),
                    color: DesignTokens.Colors.Token.cacheRead
                )
            }
        }
    }
    
    /// 最常用模型部分
    private var topModelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最常用模型")
                .font(.headline)
                .fontWeight(.semibold)
            
            if statistics.byModel.isEmpty {
                Text("暂无模型使用数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(statistics.byModel.prefix(3))) { model in
                        ModelSummaryRow(model: model)
                    }
                }
            }
        }
    }
    
    /// 热门项目部分
    private var topProjectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门项目")
                .font(.headline)
                .fontWeight(.semibold)
            
            if statistics.byProject.isEmpty {
                Text("暂无项目使用数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(statistics.byProject.prefix(3))) { project in
                        ProjectSummaryRow(project: project)
                    }
                }
            }
        }
    }
    
    /// 格式化令牌数量
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
        }
    }
}

/// 模型摘要行组件
struct ModelSummaryRow: View {
    let model: ModelUsage
    
    var body: some View {
        HStack {
            // 模型名称和令牌信息
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(model.formattedTokens) 令牌")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 成本和会话信息
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.formattedCost)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(model.sessionCount) 会话")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// 项目摘要行组件
struct ProjectSummaryRow: View {
    let project: ProjectUsage
    
    var body: some View {
        HStack {
            // 项目名称和路径
            VStack(alignment: .leading, spacing: 2) {
                Text(project.projectName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(project.formattedPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 成本和会话信息
            VStack(alignment: .trailing, spacing: 2) {
                Text(project.formattedCost)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(project.sessionCount) 会话")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    UsageStatisticsView(configService: ConfigService())
        .frame(width: 800, height: 600)
}
