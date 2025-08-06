import SwiftUI

/// 时间线标签页视图
struct TimelineTabView: View {
    let dailyUsage: [DailyUsage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使用时间线")
                .font(.headline)
                .fontWeight(.semibold)
            
            if dailyUsage.isEmpty {
                emptyStateView
            } else {
                chartView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("暂无时间线数据")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var chartView: some View {
        VStack(spacing: 16) {
            // 图表
            UsageChart(dailyUsage: dailyUsage)
                .frame(height: 200)
            
            // 图例和统计
            chartLegend
        }
    }
    
    private var chartLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("统计概览")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总天数")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(dailyUsage.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("平均日成本")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(averageDailyCost))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("最高日成本")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(maxDailyCost))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var averageDailyCost: Double {
        guard !dailyUsage.isEmpty else { return 0 }
        let totalCost = dailyUsage.reduce(0) { $0 + $1.totalCost }
        return totalCost / Double(dailyUsage.count)
    }
    
    private var maxDailyCost: Double {
        return dailyUsage.map { $0.totalCost }.max() ?? 0
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return String(format: "$%.2f", amount)
    }
}

/// 增强版使用图表组件
struct UsageChart: View {
    let dailyUsage: [DailyUsage]
    @State private var hoveredIndex: Int?
    @State private var showAnimation = false
    
    var body: some View {
        GeometryReader { geometry in
            let maxCost = dailyUsage.map { $0.totalCost }.max() ?? 1
            let barWidth = max(8, (geometry.size.width - 60) / CGFloat(dailyUsage.count) - 3)
            let chartHeight = geometry.size.height - 80
            
            ZStack(alignment: .bottom) {
                // 背景网格
                backgroundGrid(geometry: geometry, chartHeight: chartHeight, maxCost: maxCost)
                
                // 主图表内容
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(dailyUsage.enumerated()), id: \.offset) { index, day in
                        chartBar(
                            day: day,
                            index: index,
                            barWidth: barWidth,
                            maxHeight: chartHeight,
                            maxCost: maxCost
                        )
                    }
                }
                .padding(.leading, 60)
                .padding(.bottom, 40)
                
                // Y轴标签
                yAxisLabels(geometry: geometry, chartHeight: chartHeight, maxCost: maxCost)
                
                // X轴标签
                xAxisLabels(geometry: geometry, barWidth: barWidth)
            }
        }
        .onAppear {
            withAnimation(DesignTokens.Animation.chart.delay(0.3)) {
                showAnimation = true
            }
        }
    }
    
    /// 单个柱状图条
    private func chartBar(day: DailyUsage, index: Int, barWidth: CGFloat, maxHeight: CGFloat, maxCost: Double) -> some View {
        VStack(spacing: 4) {
            // 工具提示
            if hoveredIndex == index {
                enhancedTooltip(for: day)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .zIndex(10)
            }
            
            // 柱状图条
            Rectangle()
                .fill(barGradient(for: day))
                .frame(
                    width: barWidth,
                    height: showAnimation ? 
                        max(4, CGFloat(day.totalCost / maxCost) * maxHeight) : 
                        4
                )
                .cornerRadius(barWidth / 4)
                .overlay(
                    // 顶部高亮
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(2, CGFloat(day.totalCost / maxCost) * maxHeight * 0.3))
                        .cornerRadius(barWidth / 4),
                    alignment: .top
                )
                .shadow(
                    color: barColor(for: day).opacity(0.3),
                    radius: hoveredIndex == index ? 4 : 2,
                    x: 0,
                    y: 2
                )
                .scaleEffect(x: 1.0, y: hoveredIndex == index ? 1.05 : 1.0)
                .animation(DesignTokens.Animation.fast, value: hoveredIndex)
                .onHover { isHovering in
                    withAnimation(DesignTokens.Animation.fast) {
                        hoveredIndex = isHovering ? index : nil
                    }
                }
        }
    }
    
    /// 背景网格
    private func backgroundGrid(geometry: GeometryProxy, chartHeight: CGFloat, maxCost: Double) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(DesignTokens.Colors.Chart.grid)
                    .frame(height: 1)
                    .opacity(0.3)
                
                if index < 4 {
                    Spacer()
                }
            }
        }
        .frame(height: chartHeight)
        .padding(.leading, 60)
        .padding(.bottom, 40)
    }
    
    /// Y轴标签
    private func yAxisLabels(geometry: GeometryProxy, chartHeight: CGFloat, maxCost: Double) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                let value = maxCost * Double(4 - index) / 4
                
                Text(formatCurrency(value))
                    .font(DesignTokens.Typography.small)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                    .frame(width: 50, alignment: .trailing)
                
                if index < 4 {
                    Spacer()
                }
            }
        }
        .frame(height: chartHeight)
        .position(x: 30, y: geometry.size.height / 2 - 20)
    }
    
    /// X轴标签
    private func xAxisLabels(geometry: GeometryProxy, barWidth: CGFloat) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(dailyUsage.enumerated()), id: \.offset) { index, day in
                Text(day.formattedDate)
                    .font(DesignTokens.Typography.small)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                    .rotationEffect(.degrees(-45))
                    .frame(width: barWidth)
                    .fixedSize()
                    .opacity(shouldShowXAxisLabel(index: index) ? 1.0 : 0.3)
            }
        }
        .padding(.leading, 60)
        .position(x: geometry.size.width / 2, y: geometry.size.height - 20)
    }
    
    /// 是否显示X轴标签（避免过于密集）
    private func shouldShowXAxisLabel(index: Int) -> Bool {
        if dailyUsage.count <= 7 {
            return true
        } else if dailyUsage.count <= 14 {
            return index % 2 == 0
        } else {
            return index % 3 == 0
        }
    }
    
    /// 增强版工具提示
    private func enhancedTooltip(for day: DailyUsage) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // 日期标题
            Text(day.fullFormattedDate)
                .font(DesignTokens.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Colors.primaryText)
            
            Divider()
                .frame(height: 1)
            
            // 统计信息
            VStack(alignment: .leading, spacing: 4) {
                tooltipRow(icon: "dollarsign.circle", label: "成本", value: day.formattedCost, color: .green)
                tooltipRow(icon: "doc.text", label: "令牌", value: day.formattedTokens, color: .orange)
                tooltipRow(icon: "cpu", label: "模型", value: "\(day.modelsUsed.count)个", color: .blue)
            }
            
            // 使用的模型列表
            if !day.modelsUsed.isEmpty {
                Divider()
                    .frame(height: 1)
                
                Text("使用模型:")
                    .font(DesignTokens.Typography.small)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 2) {
                    ForEach(day.modelsUsed.prefix(4), id: \.self) { model in
                        Text(modelDisplayName(model))
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(modelColor(model).opacity(0.2))
                            )
                            .foregroundColor(modelColor(model))
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                .fill(DesignTokens.Colors.controlBackground)
                .shadow(
                    color: DesignTokens.Shadow.heavy.color,
                    radius: DesignTokens.Shadow.heavy.radius,
                    x: DesignTokens.Shadow.heavy.x,
                    y: DesignTokens.Shadow.heavy.y
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                .stroke(DesignTokens.Colors.separator.opacity(0.5), lineWidth: 1)
        )
    }
    
    /// 工具提示行
    private func tooltipRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
                .frame(width: 14)
            
            Text(label)
                .font(DesignTokens.Typography.small)
                .foregroundColor(DesignTokens.Colors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(DesignTokens.Typography.small)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Colors.primaryText)
        }
    }
    
    /// 柱状图渐变色
    private func barGradient(for day: DailyUsage) -> LinearGradient {
        let baseColor = barColor(for: day)
        return LinearGradient(
            colors: [
                baseColor,
                baseColor.opacity(0.7)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func barColor(for day: DailyUsage) -> Color {
        let maxCost = dailyUsage.map { $0.totalCost }.max() ?? 1
        let intensity = day.totalCost / maxCost
        
        if intensity > 0.7 {
            return DesignTokens.Colors.Chart.high
        } else if intensity > 0.4 {
            return DesignTokens.Colors.Chart.medium
        } else {
            return DesignTokens.Colors.Chart.low
        }
    }
    
    /// 模型显示名称
    private func modelDisplayName(_ model: String) -> String {
        let modelMap: [String: String] = [
            "claude-4-opus": "Opus 4",
            "claude-4-sonnet": "Sonnet 4", 
            "claude-3.5-sonnet": "Sonnet 3.5",
            "claude-3-opus": "Opus 3",
            "claude-3-haiku": "Haiku 3"
        ]
        return modelMap[model] ?? model.components(separatedBy: "-").last?.capitalized ?? model
    }
    
    /// 模型颜色
    private func modelColor(_ model: String) -> Color {
        if model.contains("opus") {
            return DesignTokens.Colors.Model.opus
        } else if model.contains("sonnet") {
            return DesignTokens.Colors.Model.sonnet
        } else if model.contains("haiku") {
            return DesignTokens.Colors.Model.haiku
        } else {
            return DesignTokens.Colors.Model.defaultColor
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount < 0.001 {
            return "$0.00"
        } else if amount < 1.0 {
            return String(format: "$%.3f", amount)
        } else {
            return String(format: "$%.2f", amount)
        }
    }
}

#Preview {
    let sampleData = [
        DailyUsage(date: "2024-01-01", totalCost: 0.05, totalTokens: 1000, modelsUsed: ["claude-4-sonnet"]),
        DailyUsage(date: "2024-01-02", totalCost: 0.12, totalTokens: 2400, modelsUsed: ["claude-4-sonnet", "claude-3-haiku"]),
        DailyUsage(date: "2024-01-03", totalCost: 0.08, totalTokens: 1600, modelsUsed: ["claude-4-sonnet"]),
        DailyUsage(date: "2024-01-04", totalCost: 0.15, totalTokens: 3000, modelsUsed: ["claude-4-opus"]),
        DailyUsage(date: "2024-01-05", totalCost: 0.03, totalTokens: 600, modelsUsed: ["claude-3-haiku"])
    ]
    
    TimelineTabView(dailyUsage: sampleData)
        .frame(width: 500, height: 350)
        .padding()
}