import Foundation

/// 混合使用统计服务
/// 优先从数据库读取数据，如果失败则降级到JSONL文件解析
class HybridUsageService: UsageServiceProtocol {
    private let database: UsageStatisticsDatabase
    private let fallbackService: UsageService
    private let configService: ConfigServiceProtocol
    
    init(database: UsageStatisticsDatabase, configService: ConfigServiceProtocol) {
        self.database = database
        self.configService = configService
        self.fallbackService = UsageService(configService: configService)
    }
    
    /// 获取使用统计数据
    func getUsageStatistics(
        dateRange: DateRange,
        projectPath: String?
    ) async throws -> UsageStatistics {
        print("🔍 HybridUsageService: 开始获取使用统计数据")
        print("   日期范围: \(dateRange)")
        print("   项目路径: \(projectPath ?? "全部")")
        
        // 先尝试从数据库读取
        do {
            let hasData = try checkDatabaseHasData()
            print("   数据库数据检查结果: \(hasData)")
            
            if hasData {
                Logger.shared.info("📊 从数据库获取使用统计数据")
                print("✅ 正在从数据库获取数据...")
                let stats = try database.getUsageStatistics(dateRange: dateRange, projectPath: projectPath)
                print("✅ 数据库查询成功！总成本: $\(String(format: "%.2f", stats.totalCost)), 总请求: \(stats.totalRequests)")
                return stats
            } else {
                Logger.shared.info("⚠️ 数据库为空，降级到JSONL解析")
                print("⚠️ 数据库为空，将降级到JSONL解析")
            }
        } catch {
            // 只有在特定的数据库错误时才降级
            // 如果是连接错误或严重异常，应该重新抛出
            if isRecoverableError(error) {
                Logger.shared.warning("⚠️ 数据库暂时不可用，降级到JSONL解析: \(error)")
                print("⚠️ 数据库暂时不可用，降级到JSONL解析: \(error)")
            } else {
                Logger.shared.error("❌ 数据库严重错误，重新抛出异常: \(error)")
                print("❌ 数据库严重错误: \(error)")
                throw error
            }
        }
        
        // 降级到JSONL文件解析
        Logger.shared.info("📁 使用JSONL文件解析作为降级方案")
        print("📁 降级到JSONL文件解析...")
        return try await fallbackService.getUsageStatistics(dateRange: dateRange, projectPath: projectPath)
    }
    
    /// 判断是否为可恢复的错误
    private func isRecoverableError(_ error: Error) -> Bool {
        // 这里可以根据具体的错误类型来判断
        // 例如：文件锁定、临时连接失败等可以降级
        // 但是数据损坏、磁盘满等应该抛出异常
        if let dbError = error as? UsageStatisticsDBError {
            switch dbError {
            case .connectionFailed, .operationFailed:
                return true  // 这些错误可以降级到JSONL
            case .dataNotFound, .invalidData:
                return false // 这些错误应该抛出
            }
        }
        return true // 默认认为可以降级
    }
    
    /// 静默获取使用统计数据（不显示加载状态）
    func getUsageStatisticsSilently(
        dateRange: DateRange = .all,
        projectPath: String? = nil
    ) async throws -> UsageStatistics {
        return try await getUsageStatistics(dateRange: dateRange, projectPath: projectPath)
    }
    
    /// 获取会话统计数据
    func getSessionStatistics(
        dateRange: DateRange,
        sortOrder: SessionSortOrder
    ) async throws -> [ProjectUsage] {
        // 先尝试从数据库读取
        do {
            let hasData = try checkDatabaseHasData()
            if hasData {
                Logger.shared.info("📊 从数据库获取会话统计数据")
                let sessions = try database.getSessionStatistics(dateRange: dateRange, sortOrder: sortOrder)
                return sessions
            } else {
                Logger.shared.info("⚠️ 数据库为空，降级到JSONL解析")
            }
        } catch {
            Logger.shared.error("❌ 数据库会话查询失败，降级到JSONL解析: \(error)")
        }
        
        // 降级到JSONL文件解析
        Logger.shared.info("📁 使用JSONL文件解析作为降级方案")
        return try await fallbackService.getSessionStatistics(dateRange: dateRange, sortOrder: sortOrder)
    }
    
    /// 验证数据访问权限
    func validateDataAccess() async throws -> Bool {
        // 先尝试数据库访问
        do {
            let _ = try database.getUsageStatistics(dateRange: .last7Days, projectPath: nil)
            Logger.shared.info("✅ 数据库访问验证成功")
            return true
        } catch {
            Logger.shared.info("⚠️ 数据库访问失败，验证JSONL文件访问")
        }
        
        // 降级到JSONL文件访问验证
        return try await fallbackService.validateDataAccess()
    }
    
    // MARK: - 私有辅助方法
    
    /// 检查数据库是否有数据
    private func checkDatabaseHasData() throws -> Bool {
        do {
            print("🔍 HybridUsageService: 检查数据库是否有数据...")
            let stats = try database.getUsageStatistics(dateRange: .all, projectPath: nil)
            let hasData = stats.totalRequests > 0 || stats.totalSessions > 0
            print("📊 数据库统计: 请求数=\(stats.totalRequests), 会话数=\(stats.totalSessions)")
            print("✅ checkDatabaseHasData 结果: \(hasData)")
            Logger.shared.debug("数据库数据检查: 请求数=\(stats.totalRequests), 会话数=\(stats.totalSessions)")
            return hasData
        } catch {
            print("❌ 数据库查询异常: \(error)")
            Logger.shared.error("数据库数据检查失败: \(error)")
            // 重要：数据库查询失败时，应该抛出异常而不是返回false
            // 只有当确认数据库为空时才返回false
            throw error
        }
    }
    
    /// 获取数据源状态
    func getDataSourceStatus() async -> DataSourceStatus {
        do {
            let hasData = try checkDatabaseHasData()
            if hasData {
                return .database
            } else {
                return .jsonlFallback
            }
        } catch {
            return .jsonlFallback
        }
    }
}

/// 数据源状态
enum DataSourceStatus {
    case database      // 使用数据库
    case jsonlFallback // 降级到JSONL文件
    
    var displayName: String {
        switch self {
        case .database:
            return "数据库"
        case .jsonlFallback:
            return "JSONL文件"
        }
    }
}