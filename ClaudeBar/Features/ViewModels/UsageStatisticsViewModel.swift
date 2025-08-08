import SwiftUI
import Combine

/// 使用统计标签页
enum UsageTab: String, CaseIterable {
    case overview = "overview"
    case models = "models"
    case projects = "projects"
    case timeline = "timeline"
    
    var displayName: String {
        switch self {
        case .overview:
            return "概览"
        case .models:
            return "按模型"
        case .projects:
            return "按项目"
        case .timeline:
            return "时间线"
        }
    }
}

/// 使用统计视图模型
@MainActor
class UsageStatisticsViewModel: ObservableObject {
    @Published var statistics: UsageStatistics?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedDateRange: DateRange = .all
    @Published var selectedTab: UsageTab = .overview
    @Published var cacheStatus: CacheStatus = .empty
    @Published var cacheMetadata: CacheMetadata?
    
    private let usageService: UsageServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var cacheCheckTimer: Timer?
    
    // 缓存策略相关状态
    private var statisticsCache: [DateRange: UsageStatistics] = [:]
    
    init(configService: ConfigServiceProtocol) {
        self.usageService = UsageService(configService: configService)
        
        // 监听服务状态变化
        if let service = usageService as? UsageService {
            service.$isLoading
                .receive(on: DispatchQueue.main)
                .assign(to: \.isLoading, on: self)
                .store(in: &cancellables)
            
            service.$errorMessage
                .receive(on: DispatchQueue.main)
                .assign(to: \.errorMessage, on: self)
                .store(in: &cancellables)
        }
        
        // 启动缓存状态检查定时器
        startCacheStatusTimer()
    }
    
    /// 加载统计数据（简化缓存逻辑）
    func loadStatistics() async {
        // 取消之前的加载任务
        loadTask?.cancel()
        
        loadTask = Task {
            // 设置加载状态
            cacheStatus = .loading
            
            do {
                let stats = try await usageService.getUsageStatistics(
                    dateRange: selectedDateRange,
                    projectPath: nil
                )
                
                guard !Task.isCancelled else { return }
                
                statistics = stats
                errorMessage = nil
                
                // 更新本地缓存
                statisticsCache[selectedDateRange] = stats
                Logger.shared.info("数据加载成功，更新本地缓存: \(selectedDateRange)")
                
                // 更新缓存状态
                await updateCacheStatusAsync()
                Logger.shared.info("缓存状态更新完成: \(cacheStatus.displayName)")
                
            } catch {
                guard !Task.isCancelled else { return }
                
                Logger.shared.error("加载使用统计失败: \(error)")
                
                // 如果有陈旧的缓存数据，优雅降级使用缓存
                if let metadata = cacheMetadata,
                   metadata.status == .stale && statistics != nil {
                    Logger.shared.info("加载失败，降级使用陈旧缓存数据")
                    errorMessage = "无法获取最新数据，显示缓存数据"
                    cacheStatus = .stale
                } else {
                    // 完全失败，清理状态
                    statistics = nil
                    errorMessage = error.localizedDescription
                    cacheStatus = .error
                }
            }
        }
        
        await loadTask?.value
    }

    /// 从缓存静默加载统计数据（不显示加载状态）
    private func loadStatisticsFromCache() async {
        do {
            // 使用静默方法，不会触发加载状态
            let stats: UsageStatistics
            if let service = usageService as? UsageService {
                stats = try await service.getUsageStatisticsSilently(
                    dateRange: selectedDateRange,
                    projectPath: nil
                )
            } else {
                stats = try await usageService.getUsageStatistics(
                    dateRange: selectedDateRange,
                    projectPath: nil
                )
            }

            statistics = stats
            errorMessage = nil

            // 更新本地缓存
            statisticsCache[selectedDateRange] = stats
            Logger.shared.info("从Service层缓存恢复数据成功: \(selectedDateRange)")

            // 更新缓存状态
            await updateCacheStatusAsync()

        } catch {
            Logger.shared.error("从缓存恢复数据失败: \(error)")
            // 如果缓存恢复失败，回退到正常加载
            await loadStatistics()
        }
    }

    /// 刷新统计数据（强制清除缓存）
    func refreshStatistics() async {
        Logger.shared.info("用户手动刷新数据，强制清除缓存: \(selectedDateRange)")
        
        // 强制清除服务层缓存
        if let service = usageService as? UsageService {
            await service.clearCache()
        }
        
        // 清除当前时间段的本地缓存
        statisticsCache.removeValue(forKey: selectedDateRange)
        
        // 重置缓存状态和元数据
        cacheStatus = .empty
        cacheMetadata = nil
        statistics = nil
        
        // 重新加载数据
        await loadStatistics()
        
        Logger.shared.info("手动刷新完成")
    }
    
    /// 获取会话统计数据
    func getSessionStatistics(sortOrder: SessionSortOrder = .costDescending) async -> [ProjectUsage] {
        do {
            return try await usageService.getSessionStatistics(
                dateRange: selectedDateRange,
                sortOrder: sortOrder
            )
        } catch {
            Logger.shared.error("获取会话统计失败: \(error)")
            return []
        }
    }
    
    /// 验证数据访问权限
    func validateDataAccess() async -> Bool {
        do {
            return try await usageService.validateDataAccess()
        } catch {
            Logger.shared.error("验证数据访问权限失败: \(error)")
            return false
        }
    }
    
    /// 格式化日期范围显示
    var dateRangeDisplayText: String {
        switch selectedDateRange {
        case .all:
            return "所有时间"
        case .last7Days:
            return "最近 7 天"
        case .last30Days:
            return "最近 30 天"
        }
    }
    
    /// 获取统计摘要文本
    var statisticsSummary: String? {
        guard let stats = statistics else { return nil }
        
        return """
        总成本: \(stats.formattedTotalCost) | \
        会话数: \(stats.formattedTotalSessions) | \
        令牌数: \(stats.formattedTotalTokens)
        """
    }
    
    /// 获取最常用的模型
    var topModels: [ModelUsage] {
        guard let stats = statistics else { return [] }
        return Array(stats.byModel.prefix(3))
    }
    
    /// 获取热门项目
    var topProjects: [ProjectUsage] {
        guard let stats = statistics else { return [] }
        return Array(stats.byProject.prefix(3))
    }
    
    /// 获取最近的使用数据
    var recentDailyUsage: [DailyUsage] {
        guard let stats = statistics else { return [] }
        return Array(stats.byDate.suffix(7).reversed())
    }
    
    /// 检查是否有数据
    var hasData: Bool {
        guard let stats = statistics else { return false }
        return stats.totalSessions > 0
    }
    
    /// 检查是否显示图表
    var shouldShowChart: Bool {
        guard let stats = statistics else { return false }
        return stats.byDate.count > 1
    }
    
    /// 更新缓存状态（异步版本 - 优化准确性）
    private func updateCacheStatusAsync() async {
        if let service = usageService as? UsageService {
            let metadata = await service.getCacheMetadata(
                for: selectedDateRange,
                projectPath: nil
            )
            self.cacheMetadata = metadata
            self.cacheStatus = metadata?.status ?? .empty
            Logger.shared.info("🔍 异步缓存状态更新: \(self.cacheStatus.displayName)")
            if let meta = metadata {
                Logger.shared.info("   - 缓存时间: \(meta.formattedCacheTime)")
                Logger.shared.info("   - 过期时间: \(meta.formattedExpiryTime)")
                Logger.shared.info("   - 剩余时间: \(Int(max(0, meta.timeToExpiry / 60))) 分钟")
                Logger.shared.info("   - 命中次数: \(meta.hitCount)")
            }
        }
    }
    

    
    /// 启动缓存状态检查定时器（优化检查频率）
    private func startCacheStatusTimer() {
        // 使用更短的间隔以便及时更新缓存状态
        cacheCheckTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateCacheStatusAsync()
            }
        }
    }
    
    /// 停止缓存状态检查定时器
    private func stopCacheStatusTimer() {
        cacheCheckTimer?.invalidate()
        cacheCheckTimer = nil
    }
    
    /// 检查缓存有效性
    func checkCacheStatus() {
        Task {
            await updateCacheStatusAsync()
        }
    }
    
    /// 是否需要刷新数据
    var needsRefresh: Bool {
        return cacheStatus.needsRefresh
    }
    
    /// 获取缓存状态消息
    var cacheStatusMessage: String {
        guard let metadata = cacheMetadata else {
            return cacheStatus.getMessage()
        }
        
        return cacheStatus.getMessage(
            lastUpdateTime: metadata.cacheTime,
            expiryTime: metadata.expiryTime
        )
    }
    
    deinit {
        loadTask?.cancel()
        cacheCheckTimer?.invalidate()
        cancellables.removeAll()
    }
    
    /// 页面出现时检查缓存
    func onPageAppear() async {
        Logger.shared.info("页面出现，检查当前时间段缓存: \(selectedDateRange)")

        // 先更新缓存状态
        await updateCacheStatusAsync()

        // 检查是否有有效的Service层缓存
        if let metadata = cacheMetadata, metadata.status.canShowData {
            Logger.shared.info("发现有效缓存，状态: \(metadata.status.displayName)")

            // 尝试从本地缓存快速恢复显示
            if let cachedStats = statisticsCache[selectedDateRange] {
                Logger.shared.info("使用本地缓存快速显示数据")
                statistics = cachedStats
            } else {
                // 如果本地缓存不存在但Service层有缓存，直接从Service层获取（不显示加载状态）
                Logger.shared.info("本地缓存缺失，从Service层静默恢复数据")
                await loadStatisticsFromCache()
            }
        } else {
            Logger.shared.info("缓存无效或不存在，需要重新加载数据")
            await loadStatistics()
        }
    }
    
    /// 页面消失时的处理
    func onPageDisappear() {
        // 取消加载任务以节省资源
        loadTask?.cancel()
    }
    
    
    /// 智能切换时间段（统一缓存检查策略）
    func switchToDateRange(_ newRange: DateRange) async {
        guard newRange != selectedDateRange else { return }
        
        Logger.shared.info("切换时间段: \(selectedDateRange) -> \(newRange)")
        
        // 保存当前数据到本地缓存
        if let currentStats = statistics {
            statisticsCache[selectedDateRange] = currentStats
            Logger.shared.info("保存当前数据到本地缓存: \(selectedDateRange)")
        }
        
        // 使用动画切换时间段
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDateRange = newRange
        }
        
        // 统一使用与 onPageAppear 相同的缓存检查逻辑
        await updateCacheStatusAsync()
        
        // 检查是否有有效的Service层缓存
        if let metadata = cacheMetadata, metadata.status.canShowData {
            Logger.shared.info("目标时间段有有效缓存，状态: \(metadata.status.displayName)")

            // 尝试从本地缓存快速显示
            if let cachedStats = statisticsCache[newRange] {
                Logger.shared.info("使用本地缓存快速显示")
                statistics = cachedStats
            } else {
                // 本地缓存缺失，从Service层静默恢复
                Logger.shared.info("本地缓存缺失，从Service层静默恢复数据")
                await loadStatisticsFromCache()
            }
        } else {
            Logger.shared.info("目标时间段缓存无效，需要重新加载")
            await loadStatistics()
        }
    }
}
