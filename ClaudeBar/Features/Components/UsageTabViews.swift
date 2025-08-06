import SwiftUI

/// 增强版概览标签页视图
struct OverviewTabView: View {
    let statistics: UsageStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("令牌详情")
                .font(DesignTokens.Typography.sectionTitle)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Colors.primaryText)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignTokens.Spacing.md) {
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
        .cardStyle()
    }
    
    /// 最常用模型部分
    private var topModelsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("最常用模型")
                    .font(DesignTokens.Typography.sectionTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                
                Spacer()
                
                if !statistics.byModel.isEmpty {
                    Text("Top \(min(3, statistics.byModel.count))")
                        .font(DesignTokens.Typography.small)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignTokens.Colors.accentLight)
                        )
                }
            }
            
            if statistics.byModel.isEmpty {
                EmptyStateUsageView(
                    icon: "cpu",
                    title: "暂无模型使用数据",
                    description: "开始使用 Claude 后，这里将显示您最常用的模型"
                )
                .frame(minHeight: 100)
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(Array(statistics.byModel.prefix(3))) { model in
                        EnhancedModelSummaryRow(model: model)
                    }
                }
            }
        }
        .cardStyle()
    }
    
    /// 热门项目部分
    private var topProjectsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("热门项目")
                    .font(DesignTokens.Typography.sectionTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                
                Spacer()
                
                if !statistics.byProject.isEmpty {
                    Text("Top \(min(3, statistics.byProject.count))")
                        .font(DesignTokens.Typography.small)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignTokens.Colors.accentLight)
                        )
                }
            }
            
            if statistics.byProject.isEmpty {
                EmptyStateUsageView(
                    icon: "folder",
                    title: "暂无项目使用数据",
                    description: "在项目中使用 Claude 后，这里将显示您最活跃的项目"
                )
                .frame(minHeight: 100)
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(Array(statistics.byProject.prefix(3))) { project in
                        EnhancedProjectSummaryRow(project: project)
                    }
                }
            }
        }
        .cardStyle()
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

/// 增强版令牌详情卡片
struct TokenDetailCard: View {
    let title: String
    let value: String
    let color: Color
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // 顶部标题行
            HStack {
                Text(title)
                    .font(DesignTokens.Typography.small)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                
                Spacer()
                
                // 小圆点指示器
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            
            // 数值显示
            Text(value)
                .font(DesignTokens.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.08),
                            color.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                        .fill(DesignTokens.Colors.controlBackground)
                        .opacity(0.7)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

/// 增强版模型摘要行
struct EnhancedModelSummaryRow: View {
    let model: ModelUsage
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 模型信息
            HStack(spacing: DesignTokens.Spacing.sm) {
                Circle()
                    .fill(modelColor)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(DesignTokens.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Colors.primaryText)
                    
                    Text("\(model.formattedTokens) 令牌")
                        .font(DesignTokens.Typography.small)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            // 统计信息
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.formattedCost)
                    .font(DesignTokens.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                
                Text("\(model.sessionCount) 会话")
                    .font(DesignTokens.Typography.small)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                .fill(DesignTokens.Colors.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                        .stroke(DesignTokens.Colors.separator.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.cardHover) {
                isHovered = hovering
            }
        }
    }
    
    private var modelColor: Color {
        switch model.color {
        case "purple":
            return DesignTokens.Colors.Model.opus
        case "blue":
            return DesignTokens.Colors.Model.sonnet
        case "green":
            return DesignTokens.Colors.Model.haiku
        default:
            return DesignTokens.Colors.Model.defaultColor
        }
    }
}

/// 增强版项目摘要行
struct EnhancedProjectSummaryRow: View {
    let project: ProjectUsage
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 项目信息
            VStack(alignment: .leading, spacing: 2) {
                Text(project.projectName)
                    .font(DesignTokens.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                    .lineLimit(1)
                
                Text(project.formattedPath)
                    .font(DesignTokens.Typography.small)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 统计信息
            VStack(alignment: .trailing, spacing: 2) {
                Text(project.formattedCost)
                    .font(DesignTokens.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                
                Text("\(project.sessionCount) 会话")
                    .font(DesignTokens.Typography.small)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                .fill(DesignTokens.Colors.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                        .stroke(DesignTokens.Colors.separator.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.cardHover) {
                isHovered = hovering
            }
        }
    }
}

/// 通用空状态视图
struct EmptyStateUsageView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.Typography.IconSize.extraLarge))
                .foregroundColor(DesignTokens.Colors.secondaryText)
            
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.subtitle)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                
                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.lg)
    }
}

/// 增强版按模型统计标签页视图
struct ModelsTabView: View {
    let models: [ModelUsage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 标题部分
            HStack {
                Text("模型使用统计")
                    .font(DesignTokens.Typography.sectionTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                
                Spacer()
                
                if !models.isEmpty {
                    Text("\(models.count) 个模型")
                        .font(DesignTokens.Typography.small)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignTokens.Colors.accentLight)
                        )
                }
            }
            
            if models.isEmpty {
                EmptyStateUsageView(
                    icon: "cpu",
                    title: "暂无模型使用数据",
                    description: "开始使用 Claude 后，这里将显示所有模型的详细使用统计"
                )
                .frame(minHeight: 200)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(models) { model in
                            EnhancedModelDetailRow(model: model)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                }
            }
        }
        .cardStyle()
    }
}

/// 增强版模型详情行
struct EnhancedModelDetailRow: View {
    let model: ModelUsage
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 模型头部信息
            HStack {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Circle()
                        .fill(modelColor)
                        .frame(width: 12, height: 12)
                    
                    Text(model.displayName)
                        .font(DesignTokens.Typography.subtitle)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Colors.primaryText)
                }
                
                Spacer()
                
                Text(model.formattedCost)
                    .font(DesignTokens.Typography.subtitle)
                    .fontWeight(.bold)
                    .foregroundColor(modelColor)
            }
            
            // 统计网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignTokens.Spacing.md) {
                MetricItem(
                    title: "令牌数",
                    value: model.formattedTokens,
                    icon: "doc.text",
                    color: .orange
                )
                
                MetricItem(
                    title: "会话数",
                    value: "\(model.sessionCount)",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                )
                
                MetricItem(
                    title: "请求数",
                    value: "\(model.requestCount ?? 0)",
                    icon: "arrow.up.arrow.down",
                    color: .purple
                )
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                .fill(
                    LinearGradient(
                        colors: [
                            modelColor.opacity(0.05),
                            modelColor.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                        .fill(DesignTokens.Colors.controlBackground)
                        .opacity(0.8)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                .stroke(modelColor.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.cardHover) {
                isHovered = hovering
            }
        }
    }
    
    private var modelColor: Color {
        switch model.color {
        case "purple":
            return DesignTokens.Colors.Model.opus
        case "blue":
            return DesignTokens.Colors.Model.sonnet
        case "green":
            return DesignTokens.Colors.Model.haiku
        default:
            return DesignTokens.Colors.Model.defaultColor
        }
    }
}

/// 度量项组件
struct MetricItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: DesignTokens.Typography.IconSize.small))
            
            Text(value)
                .font(DesignTokens.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Colors.primaryText)
            
            Text(title)
                .font(DesignTokens.Typography.small)
                .foregroundColor(DesignTokens.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 增强版按项目统计标签页视图
struct ProjectsTabView: View {
    let projects: [ProjectUsage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 标题部分
            HStack {
                Text("项目使用统计")
                    .font(DesignTokens.Typography.sectionTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                
                Spacer()
                
                if !projects.isEmpty {
                    Text("\(projects.count) 个项目")
                        .font(DesignTokens.Typography.small)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignTokens.Colors.accentLight)
                        )
                }
            }
            
            if projects.isEmpty {
                EmptyStateUsageView(
                    icon: "folder",
                    title: "暂无项目使用数据",
                    description: "在项目中使用 Claude 后，这里将显示所有项目的详细使用统计"
                )
                .frame(minHeight: 200)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(projects) { project in
                            EnhancedProjectDetailRow(project: project)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                }
            }
        }
        .cardStyle()
    }
}

/// 增强版项目详情行
struct EnhancedProjectDetailRow: View {
    let project: ProjectUsage
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 项目头部信息
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.projectName)
                        .font(DesignTokens.Typography.subtitle)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Colors.primaryText)
                        .lineLimit(2)
                    
                    Text(project.formattedPath)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer(minLength: DesignTokens.Spacing.md)
                
                Text(project.formattedCost)
                    .font(DesignTokens.Typography.subtitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Colors.primary)
            }
            
            // 统计网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignTokens.Spacing.md) {
                MetricItem(
                    title: "会话数",
                    value: "\(project.sessionCount)",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                )
                
                MetricItem(
                    title: "令牌数",
                    value: project.formattedTokens,
                    icon: "doc.text",
                    color: .orange
                )
                
                MetricItem(
                    title: "最后使用",
                    value: project.formattedLastUsed,
                    icon: "clock",
                    color: .gray
                )
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                .fill(DesignTokens.Colors.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                .stroke(DesignTokens.Colors.separator.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.cardHover) {
                isHovered = hovering
            }
        }
    }
}
