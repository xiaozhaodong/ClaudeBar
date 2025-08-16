#!/usr/bin/env swift

import Foundation
import SQLite3

// 基本的数据结构和协议定义（简化版本）
struct ClaudeConfig {
    let name: String
    let baseUrl: String
    let authToken: String
    let isActive: Bool
}

protocol ConfigServiceProtocol {
    func loadConfigs() async throws -> [ClaudeConfig]
    func getCurrentConfig() -> ClaudeConfig?
    func switchConfig(_ config: ClaudeConfig) async throws
    func createConfig(_ config: ClaudeConfig) async throws
    func updateConfig(oldConfig: ClaudeConfig, newConfig: ClaudeConfig) async throws
    func deleteConfig(_ config: ClaudeConfig) async throws
    func validateConfig(_ config: ClaudeConfig) throws
}

// Mock ConfigService
class MockConfigService: ConfigServiceProtocol {
    func loadConfigs() async throws -> [ClaudeConfig] { return [] }
    func getCurrentConfig() -> ClaudeConfig? { return nil }
    func switchConfig(_ config: ClaudeConfig) async throws {}
    func createConfig(_ config: ClaudeConfig) async throws {}
    func updateConfig(oldConfig: ClaudeConfig, newConfig: ClaudeConfig) async throws {}
    func deleteConfig(_ config: ClaudeConfig) async throws {}
    func validateConfig(_ config: ClaudeConfig) throws {}
}

// Mock Logger
class Logger {
    static let shared = Logger()
    func info(_ message: String) { print("ℹ️ \(message)") }
    func warning(_ message: String) { print("⚠️ \(message)") }
    func error(_ message: String) { print("❌ \(message)") }
    func debug(_ message: String) { print("🐛 \(message)") }
}

// 数据库错误类型
enum UsageStatisticsDBError: Error, LocalizedError {
    case connectionFailed(String)
    case operationFailed(String)
    case dataNotFound
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "数据库连接失败: \(message)"
        case .operationFailed(let message):
            return "数据库操作失败: \(message)"
        case .dataNotFound:
            return "数据未找到"
        case .invalidData(let message):
            return "数据无效: \(message)"
        }
    }
}

// 枚举和数据结构
enum DateRange {
    case all
    case last7Days
    case last30Days
    
    var startDate: Date? {
        switch self {
        case .all:
            return nil
        case .last7Days:
            return Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .last30Days:
            return Calendar.current.date(byAdding: .day, value: -30, to: Date())
        }
    }
}

struct UsageStatistics {
    let totalCost: Double
    let totalTokens: Int
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCacheCreationTokens: Int
    let totalCacheReadTokens: Int
    let totalSessions: Int
    let totalRequests: Int
    let byModel: [ModelUsage]
    let byDate: [DailyUsage]
    let byProject: [ProjectUsage]
}

struct ModelUsage {
    let model: String
    let totalCost: Double
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let sessionCount: Int
    let requestCount: Int
}

struct DailyUsage {
    let date: String
    let totalCost: Double
    let totalTokens: Int
    let modelsUsed: [String]
}

struct ProjectUsage {
    let projectPath: String
    let projectName: String
    let totalCost: Double
    let totalTokens: Int
    let sessionCount: Int
    let requestCount: Int
    let lastUsed: String
}

enum SessionSortOrder {
    case costDescending
    case costAscending
    case dateDescending
    case dateAscending
    case nameAscending
    case nameDescending
}

// 协议定义
protocol UsageServiceProtocol {
    func getUsageStatistics(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics
    func getUsageStatisticsSilently(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics
    func getSessionStatistics(dateRange: DateRange, sortOrder: SessionSortOrder) async throws -> [ProjectUsage]
    func validateDataAccess() async throws -> Bool
}

// Mock数据库服务
class MockUsageStatisticsDatabase {
    func getUsageStatistics(dateRange: DateRange = .all, projectPath: String? = nil) throws -> UsageStatistics {
        print("📊 MockDatabase: 执行 getUsageStatistics")
        print("   参数: dateRange=\(dateRange), projectPath=\(projectPath ?? "nil")")
        
        // 模拟有数据的情况
        let stats = UsageStatistics(
            totalCost: 6602.48,
            totalTokens: 500000,
            totalInputTokens: 300000,
            totalOutputTokens: 200000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 437,
            totalRequests: 36082,
            byModel: [],
            byDate: [],
            byProject: []
        )
        
        print("   数据库统计: 请求数=\(stats.totalRequests), 会话数=\(stats.totalSessions)")
        let hasData = stats.totalRequests > 0 || stats.totalSessions > 0
        print("   hasData 结果: \(hasData)")
        
        return stats
    }
    
    func getSessionStatistics(dateRange: DateRange = .all, sortOrder: SessionSortOrder = .costDescending) throws -> [ProjectUsage] {
        print("📊 MockDatabase: 执行 getSessionStatistics")
        return []
    }
}

// Mock fallback service
class MockUsageService: UsageServiceProtocol {
    func getUsageStatistics(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics {
        print("📁 MockUsageService: 降级到JSONL解析")
        return UsageStatistics(
            totalCost: 10.0,
            totalTokens: 1000,
            totalInputTokens: 600,
            totalOutputTokens: 400,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 1,
            totalRequests: 1,
            byModel: [],
            byDate: [],
            byProject: []
        )
    }
    
    func getUsageStatisticsSilently(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics {
        return try await getUsageStatistics(dateRange: dateRange, projectPath: projectPath)
    }
    
    func getSessionStatistics(dateRange: DateRange, sortOrder: SessionSortOrder) async throws -> [ProjectUsage] {
        return []
    }
    
    func validateDataAccess() async throws -> Bool {
        return true
    }
}

// 修改后的HybridUsageService（简化版本）
class TestHybridUsageService: UsageServiceProtocol {
    private let database: MockUsageStatisticsDatabase
    private let fallbackService: UsageServiceProtocol
    private let configService: ConfigServiceProtocol
    
    init(database: MockUsageStatisticsDatabase, configService: ConfigServiceProtocol) {
        self.database = database
        self.configService = configService
        self.fallbackService = MockUsageService()
    }
    
    /// 获取使用统计数据
    func getUsageStatistics(
        dateRange: DateRange,
        projectPath: String?
    ) async throws -> UsageStatistics {
        print("🔍 TestHybridUsageService: 开始获取使用统计数据")
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
    
    /// 检查数据库是否有数据（修改后的版本）
    private func checkDatabaseHasData() throws -> Bool {
        do {
            print("🔍 TestHybridUsageService: 检查数据库是否有数据...")
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
            throw error
        }
    }
    
    /// 判断是否为可恢复的错误
    private func isRecoverableError(_ error: Error) -> Bool {
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
    
    func getUsageStatisticsSilently(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics {
        return try await getUsageStatistics(dateRange: dateRange, projectPath: projectPath)
    }
    
    func getSessionStatistics(dateRange: DateRange, sortOrder: SessionSortOrder) async throws -> [ProjectUsage] {
        return []
    }
    
    func validateDataAccess() async throws -> Bool {
        return true
    }
}

// 测试函数
func testModifiedHybridService() async {
    print("🚀 开始测试修改后的 HybridUsageService")
    print("============================================================")
    
    let configService = MockConfigService()
    let database = MockUsageStatisticsDatabase()
    let hybridService = TestHybridUsageService(database: database, configService: configService)
    
    print("\n📊 测试1: 数据库有数据的情况")
    print("------------------------------")
    do {
        let stats = try await hybridService.getUsageStatistics(dateRange: .all, projectPath: nil)
        print("测试结果:")
        print("  总成本: $\(String(format: "%.2f", stats.totalCost))")
        print("  总请求: \(stats.totalRequests)")
        print("  总会话: \(stats.totalSessions)")
        
        if stats.totalCost > 1000 {
            print("✅ 成功: 数据来自数据库（高成本值）")
        } else {
            print("❌ 失败: 数据来自JSONL降级（低成本值）")
        }
    } catch {
        print("❌ 测试失败: \(error)")
    }
    
    print("\n🎯 测试完成!")
    print("如果看到'数据来自数据库'，说明修改有效")
    print("如果看到'数据来自JSONL降级'，说明还有问题")
}

// 运行测试
await testModifiedHybridService()