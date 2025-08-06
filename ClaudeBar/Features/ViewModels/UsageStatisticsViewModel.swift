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
    
    private let usageService: UsageServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
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
    }
    
    /// 加载统计数据
    func loadStatistics() async {
        // 取消之前的加载任务
        loadTask?.cancel()
        
        loadTask = Task {
            do {
                let stats = try await usageService.getUsageStatistics(
                    dateRange: selectedDateRange,
                    projectPath: nil
                )
                
                guard !Task.isCancelled else { return }
                
                statistics = stats
                errorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                
                statistics = nil
                errorMessage = error.localizedDescription
                Logger.shared.error("加载使用统计失败: \(error)")
            }
        }
        
        await loadTask?.value
    }
    
    /// 刷新统计数据
    func refreshStatistics() async {
        // 清除缓存
        if let service = usageService as? UsageService {
            await service.clearCache()
        }
        
        await loadStatistics()
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
    
    deinit {
        loadTask?.cancel()
        cancellables.removeAll()
    }
}
