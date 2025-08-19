import SwiftUI
import Combine
import Foundation

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
    @Published var isAutoRefreshing: Bool = false
    
    private let usageService: UsageServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
    
    // 防抖机制
    private var refreshDebounceTask: Task<Void, Never>?
    private let refreshDebounceInterval: TimeInterval = 1.0 // 1秒防抖
    
    
    init(configService: ConfigServiceProtocol) {
        // 使用 HybridUsageService 替代 UsageService
        let usageDatabase = UsageStatisticsDatabase()
        self.usageService = HybridUsageService(database: usageDatabase, configService: configService)
        
        // 设置通知监听器
        setupNotificationListeners()
    }
    
    /// 加载统计数据（简化逻辑）
    func loadStatistics() async {
        // 取消之前的加载任务
        loadTask?.cancel()
        
        loadTask = Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let stats = try await usageService.getUsageStatistics(
                    dateRange: selectedDateRange,
                    projectPath: nil
                )
                
                guard !Task.isCancelled else { return }
                
                statistics = stats
                errorMessage = nil
                
                Logger.shared.info("数据加载成功: \(selectedDateRange)")
                
            } catch {
                guard !Task.isCancelled else { return }
                
                Logger.shared.error("加载使用统计失败: \(error)")
                statistics = nil
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
        
        await loadTask?.value
    }


    /// 刷新统计数据（直接调用数据库）
    func refreshStatistics() async {
        Logger.shared.info("用户手动刷新数据，直接从数据库获取: \(selectedDateRange)")
        
        // 取消防抖任务，避免冲突
        refreshDebounceTask?.cancel()
        
        // 取消之前的加载任务
        loadTask?.cancel()
        
        loadTask = Task {
            isLoading = true
            errorMessage = nil
            
            do {
                // 直接调用数据库服务，不依赖缓存
                let stats = try await usageService.getUsageStatistics(
                    dateRange: selectedDateRange,
                    projectPath: nil
                )
                
                guard !Task.isCancelled else { return }
                
                statistics = stats
                errorMessage = nil
                
                Logger.shared.info("手动刷新成功: 总成本 $\(String(format: "%.2f", stats.totalCost)), 总请求 \(stats.totalRequests)")
                
            } catch {
                guard !Task.isCancelled else { return }
                
                Logger.shared.error("手动刷新失败: \(error)")
                errorMessage = "刷新失败: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
        
        await loadTask?.value
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
    
    /// 检查是否可以手动刷新
    var canManualRefresh: Bool {
        return !isLoading && !isAutoRefreshing
    }
    
    

    
    deinit {
        loadTask?.cancel()
        refreshDebounceTask?.cancel()
        cancellables.removeAll()
        
        // 移除通知监听器（同步操作）
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }
    
    // MARK: - 通知监听管理
    
    /// 设置通知监听器
    private func setupNotificationListeners() {
        Logger.shared.info("设置使用统计通知监听器")
        
        // 监听使用数据更新通知
        let usageDataObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("ClaudeBar.usageDataDidUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                await self?.handleUsageDataUpdated(notification)
            }
        }
        notificationObservers.append(usageDataObserver)
        
        // 监听同步完成通知
        let syncCompleteObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("ClaudeBar.usageDataSyncDidComplete"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                await self?.handleSyncCompleted(notification)
            }
        }
        notificationObservers.append(syncCompleteObserver)
        
        Logger.shared.info("通知监听器设置完成，共 \(notificationObservers.count) 个监听器")
    }
    
    /// 移除通知监听器
    private func removeNotificationListeners() {
        Logger.shared.info("移除使用统计通知监听器")
        
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        
        Logger.shared.info("通知监听器移除完成")
    }
    
    // MARK: - 通知处理方法
    
    /// 处理使用数据更新通知
    private func handleUsageDataUpdated(_ notification: Notification) async {
        guard let userInfo = notification.userInfo else { return }
        
        Logger.shared.info("收到使用数据更新通知")
        
        // 检查是否有统计数据
        if let statistics = userInfo["statistics"] as? UsageStatistics {
            Logger.shared.info("通知包含统计数据，直接更新")
            self.statistics = statistics
            self.errorMessage = nil
        } else {
            Logger.shared.info("通知不包含统计数据，触发自动刷新")
            await performDebouncedRefresh()
        }
    }
    
    /// 处理同步完成通知
    private func handleSyncCompleted(_ notification: Notification) async {
        guard let userInfo = notification.userInfo else { return }
        
        let success = userInfo["success"] as? Bool ?? false
        
        if success {
            Logger.shared.info("同步完成，自动刷新数据")
            await performDebouncedRefresh()
        } else {
            Logger.shared.warning("同步失败，不执行自动刷新")
            if let error = userInfo["error"] {
                Logger.shared.error("同步错误: \(error)")
            }
        }
        
        self.isAutoRefreshing = false
    }
    
    /// 执行防抖刷新
    private func performDebouncedRefresh() async {
        // 取消之前的防抖任务
        refreshDebounceTask?.cancel()
        
        refreshDebounceTask = Task {
            // 等待防抖时间
            try? await Task.sleep(nanoseconds: UInt64(refreshDebounceInterval * 1_000_000_000))
            
            // 检查任务是否被取消
            guard !Task.isCancelled else { return }
            
            Logger.shared.info("执行防抖自动刷新")
            await self.autoRefreshStatistics()
        }
        
        await refreshDebounceTask?.value
    }
    
    /// 自动刷新统计数据（静默刷新，不显示加载状态）
    private func autoRefreshStatistics() async {
        // 避免在手动刷新时进行自动刷新
        guard !isLoading else {
            Logger.shared.debug("正在手动刷新，跳过自动刷新")
            return
        }
        
        // 取消之前的加载任务
        loadTask?.cancel()
        
        loadTask = Task {
            Logger.shared.info("开始自动刷新数据: \(selectedDateRange)")
            
            do {
                let stats = try await usageService.getUsageStatistics(
                    dateRange: selectedDateRange,
                    projectPath: nil
                )
                
                guard !Task.isCancelled else { return }
                
                statistics = stats
                errorMessage = nil
                
                Logger.shared.info("自动刷新成功: 总成本 $\(String(format: "%.2f", stats.totalCost)), 总请求 \(stats.totalRequests)")
                
            } catch {
                guard !Task.isCancelled else { return }
                
                Logger.shared.error("自动刷新失败: \(error)")
                // 自动刷新失败时不更新错误消息，保持现有数据显示
            }
        }
        
        await loadTask?.value
    }
    
    
    /// 页面出现时加载数据
    func onPageAppear() async {
        Logger.shared.info("页面出现，加载数据: \(selectedDateRange)")
        await loadStatistics()
    }
    
    /// 页面消失时的处理
    func onPageDisappear() {
        // 取消加载任务以节省资源
        loadTask?.cancel()
    }
    
    /// 切换时间段
    func switchToDateRange(_ newRange: DateRange) async {
        guard newRange != selectedDateRange else { return }
        
        Logger.shared.info("切换时间段: \(selectedDateRange) -> \(newRange)")
        
        // 使用动画切换时间段
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDateRange = newRange
        }
        
        // 加载新时间段的数据
        await loadStatistics()
    }
    
    
}
