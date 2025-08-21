import SwiftUI

// MARK: - Performance Optimization Structures

/// 记忆化值容器，避免重复计算
final class MemoizedValue<T> {
    private var cachedValue: T?
    private var cachedInputHash: Int?
    
    func getValue<Input: Hashable>(for input: Input, compute: (Input) -> T) -> T {
        let inputHash = input.hashValue
        if let cached = cachedValue, cachedInputHash == inputHash {
            return cached
        }
        
        let newValue = compute(input)
        cachedValue = newValue
        cachedInputHash = inputHash
        return newValue
    }
    
    func clear() {
        cachedValue = nil
        cachedInputHash = nil
    }
}

/// 图表度量数据
struct ChartMetrics: Hashable {
    let barWidth: CGFloat
    let totalWidth: CGFloat
    let itemCount: Int
    
    static func == (lhs: ChartMetrics, rhs: ChartMetrics) -> Bool {
        return lhs.barWidth == rhs.barWidth && 
               lhs.totalWidth == rhs.totalWidth && 
               lhs.itemCount == rhs.itemCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(barWidth)
        hasher.combine(totalWidth)
        hasher.combine(itemCount)
    }
}

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
    @State private var hoverDebounceTask: Task<Void, Never>?
    @State private var isHoverTransitioning = false
    
    // MARK: - Performance Optimization
    private let maxCostMemo = MemoizedValue<Double>()
    private let chartMetricsMemo = MemoizedValue<ChartMetrics>()
    
    // MARK: - Hover State Management
    private let hoverEnterDelay: UInt64 = 80_000_000    // 80ms - 快速显示
    private let hoverExitDelay: UInt64 = 150_000_000    // 150ms - 防止意外隐藏
    
    var body: some View {
        GeometryReader { geometry in
            let maxCost = getMaxCost()
            let metrics = getChartMetrics(geometry: geometry)
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
                            barWidth: metrics.barWidth,
                            maxHeight: chartHeight,
                            maxCost: maxCost
                        )
                    }
                }
                .padding(.leading, 60)
                .padding(.bottom, 40)
                
                // 浮动工具提示层（独立层级，不影响图表布局）
                if let hoveredIndex = hoveredIndex,
                   hoveredIndex < dailyUsage.count {
                    enhancedFloatingTooltip(
                        for: dailyUsage[hoveredIndex], 
                        at: hoveredIndex, 
                        geometry: geometry, 
                        barWidth: metrics.barWidth
                    )
                        .allowsHitTesting(false) // 防止工具提示阻止鼠标事件
                }
                
                // Y轴标签
                yAxisLabels(geometry: geometry, chartHeight: chartHeight, maxCost: maxCost)
                
                // X轴标签
                xAxisLabels(geometry: geometry, barWidth: metrics.barWidth)
            }
        }
        .onAppear {
            withAnimation(DesignTokens.Animation.chart.delay(0.3)) {
                showAnimation = true
            }
        }
        .onDisappear {
            hoverDebounceTask?.cancel()
            hoverDebounceTask = nil
            isHoverTransitioning = false
        }
    }
    
    // MARK: - Performance Optimization Methods
    
    /// 获取缓存的最大成本值（简化版本，避免Hashable约束）
    private func getMaxCost() -> Double {
        // 简单缓存：只要数组长度相同就认为没变化（针对此场景优化）
        let cacheKey = dailyUsage.count
        return maxCostMemo.getValue(for: cacheKey) { _ in
            dailyUsage.map { $0.totalCost }.max() ?? 1
        }
    }
    
    /// 获取缓存的图表度量数据
    private func getChartMetrics(geometry: GeometryProxy) -> ChartMetrics {
        let cacheKey = Int(geometry.size.width * 1000) + dailyUsage.count
        return chartMetricsMemo.getValue(for: cacheKey) { _ in
            let chartWidth = geometry.size.width - 60
            let barWidth = max(8, chartWidth / CGFloat(dailyUsage.count) - 3)
            return ChartMetrics(
                barWidth: barWidth,
                totalWidth: chartWidth,
                itemCount: dailyUsage.count
            )
        }
    }
    
    /// 增强版柱状图条 - 优化交互体验和视觉反馈
    private func chartBar(day: DailyUsage, index: Int, barWidth: CGFloat, maxHeight: CGFloat, maxCost: Double) -> some View {
        let isHovered = hoveredIndex == index
        let barHeight = showAnimation ? 
            max(4, CGFloat(day.totalCost / maxCost) * maxHeight) : 
            4
        
        return ZStack {
            // 主柱状图
            Rectangle()
                .fill(barGradient(for: day, isHovered: isHovered))
                .frame(
                    width: barWidth,
                    height: barHeight
                )
                .cornerRadius(barWidth / 4)
                .overlay(
                    // 动态顶部高亮
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.6 : 0.4), 
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(2, barHeight * 0.3))
                        .cornerRadius(barWidth / 4),
                    alignment: .top
                )
                .shadow(
                    color: barColor(for: day).opacity(isHovered ? 0.5 : 0.25),
                    radius: isHovered ? 6 : 3,
                    x: 0,
                    y: isHovered ? 4 : 2
                )
            
            // 悬停时的边框高亮
            if isHovered {
                Rectangle()
                    .fill(Color.clear)
                    .frame(
                        width: barWidth + 2,
                        height: barHeight + 2
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: barWidth / 4)
                            .stroke(
                                barColor(for: day).opacity(0.8),
                                lineWidth: 1.5
                            )
                    )
                    .transition(.scale)
            }
        }
        .scaleEffect(x: isHovered ? 1.02 : 1.0, y: isHovered ? 1.05 : 1.0)
        .animation(DesignTokens.Animation.fast, value: isHovered)
        .onHover { isHovering in
            handleHover(isHovering: isHovering, index: index)
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
    
    /// 增强版防抖悬停处理 - 消除闪动和竞态条件
    private func handleHover(isHovering: Bool, index: Int) {
        print("INFO: handleHover - isHovering: \(isHovering), index: \(index), current: \(hoveredIndex?.description ?? "nil")")
        
        // 取消之前的防抖任务
        hoverDebounceTask?.cancel()
        hoverDebounceTask = nil
        
        if isHovering {
            // 悬停进入：快速响应，带防抖
            hoverDebounceTask = Task {
                // 短暂延迟确保稳定悬停
                try? await Task.sleep(nanoseconds: hoverEnterDelay)
                
                if !Task.isCancelled {
                    await MainActor.run {
                        guard !isHoverTransitioning else { return }
                        
                        isHoverTransitioning = true
                        withAnimation(DesignTokens.Animation.fast) {
                            hoveredIndex = index
                        }
                        
                        // 短暂延迟后重置过渡状态
                        Task {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            await MainActor.run {
                                isHoverTransitioning = false
                            }
                        }
                    }
                }
            }
        } else {
            // 悬停退出：延迟隐藏，防止快速切换造成的闪烁
            hoverDebounceTask = Task {
                try? await Task.sleep(nanoseconds: hoverExitDelay)
                
                if !Task.isCancelled {
                    await MainActor.run {
                        // 双重检查：确保没有新的悬停事件
                        guard !isHoverTransitioning else { return }
                        
                        isHoverTransitioning = true
                        withAnimation(DesignTokens.Animation.fast) {
                            hoveredIndex = nil
                        }
                        
                        // 重置过渡状态
                        Task {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            await MainActor.run {
                                isHoverTransitioning = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// 增强版浮动工具提示（独立层级，智能定位）
    private func enhancedFloatingTooltip(for day: DailyUsage, at index: Int, geometry: GeometryProxy, barWidth: CGFloat) -> some View {
        let chartWidth = geometry.size.width - 60
        let totalSpacing = CGFloat(dailyUsage.count - 1) * 3
        let availableWidth = chartWidth - totalSpacing
        let actualBarWidth = availableWidth / CGFloat(dailyUsage.count)
        
        let xOffset = 60 + (actualBarWidth + 3) * CGFloat(index) + actualBarWidth / 2
        
        return enhancedTooltip(for: day)
            .position(x: min(max(xOffset, 140), geometry.size.width - 140), y: 80)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
            .zIndex(999) // 确保工具提示在最顶层
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
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                .stroke(DesignTokens.Colors.separator.opacity(0.3), lineWidth: 0.5)
        )
        .fixedSize() // 防止工具提示尺寸变化
        .compositingGroup() // 优化渲染性能
        .drawingGroup() // 减少图层渲染复杂度
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
    
    /// 增强版柱状图渐变色 - 支持悬停状态
    private func barGradient(for day: DailyUsage, isHovered: Bool = false) -> LinearGradient {
        let baseColor = barColor(for: day)
        let intensity = isHovered ? 1.0 : 0.85
        
        return LinearGradient(
            colors: [
                baseColor.opacity(intensity),
                baseColor.opacity(intensity - 0.25)
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
        DailyUsage(date: "2024-01-01", totalCost: 0.05, totalTokens: 1000, sessionCount: 3, modelsUsed: ["claude-4-sonnet"]),
        DailyUsage(date: "2024-01-02", totalCost: 0.12, totalTokens: 2400, sessionCount: 5, modelsUsed: ["claude-4-sonnet", "claude-3-haiku"]),
        DailyUsage(date: "2024-01-03", totalCost: 0.08, totalTokens: 1600, sessionCount: 2, modelsUsed: ["claude-4-sonnet"]),
        DailyUsage(date: "2024-01-04", totalCost: 0.15, totalTokens: 3000, sessionCount: 7, modelsUsed: ["claude-4-opus"]),
        DailyUsage(date: "2024-01-05", totalCost: 0.03, totalTokens: 600, sessionCount: 1, modelsUsed: ["claude-3-haiku"])
    ]
    
    TimelineTabView(dailyUsage: sampleData)
        .frame(width: 500, height: 350)
        .padding()
}