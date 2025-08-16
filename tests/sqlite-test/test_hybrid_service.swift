#!/usr/bin/env swift

import Foundation

// 模拟项目中的基本类型和服务
// 这里简化实现，重点测试 HybridUsageService 的逻辑

// MARK: - 基本数据类型

enum DateRange: String {
    case all = "all"
    case last7Days = "7d"
    case last30Days = "30d"
    
    var startDate: Date? {
        let calendar = Calendar.current
        let today = Date()
        
        switch self {
        case .all:
            return nil
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: today)
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: today)
        }
    }
}

enum SessionSortOrder {
    case costDescending
}

struct UsageStatistics {
    let totalCost: Double
    let totalTokens: Int
    let totalRequests: Int
    let totalSessions: Int
    
    static var empty: UsageStatistics {
        return UsageStatistics(totalCost: 0, totalTokens: 0, totalRequests: 0, totalSessions: 0)
    }
}

struct ProjectUsage {
    let projectPath: String
    let totalCost: Double
}

// MARK: - 服务协议

protocol UsageServiceProtocol {
    func getUsageStatistics(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics
    func getUsageStatisticsSilently(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics
    func getSessionStatistics(dateRange: DateRange, sortOrder: SessionSortOrder) async throws -> [ProjectUsage]
    func validateDataAccess() async throws -> Bool
}

// MARK: - 简化的数据库服务

class TestUsageStatisticsDatabase {
    func getUsageStatistics(dateRange: DateRange, projectPath: String?) throws -> UsageStatistics {
        print("📊 TestDatabase: 执行 getUsageStatistics")
        print("   参数: dateRange=\(dateRange), projectPath=\(projectPath ?? "nil")")
        
        // 模拟数据库查询
        return UsageStatistics(
            totalCost: 5382.08,
            totalTokens: 2500000,
            totalRequests: 32183,
            totalSessions: 395
        )
    }
    
    func getSessionStatistics(dateRange: DateRange, sortOrder: SessionSortOrder) throws -> [ProjectUsage] {
        print("📊 TestDatabase: 执行 getSessionStatistics")
        return [
            ProjectUsage(projectPath: "/test/project1", totalCost: 100.0),
            ProjectUsage(projectPath: "/test/project2", totalCost: 50.0)
        ]
    }
}

// MARK: - 简化的降级服务

class TestFallbackService: UsageServiceProtocol {
    func getUsageStatistics(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics {
        print("📁 TestFallbackService: 使用 JSONL 降级方案")
        // 模拟 JSONL 解析结果
        return UsageStatistics(
            totalCost: 100.0,  // 明显不同的数值，用于区分
            totalTokens: 50000,
            totalRequests: 1000,
            totalSessions: 10
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

// MARK: - HybridUsageService 测试版本

class TestHybridUsageService: UsageServiceProtocol {
    private let database: TestUsageStatisticsDatabase
    private let fallbackService: TestFallbackService
    
    init() {
        self.database = TestUsageStatisticsDatabase()
        self.fallbackService = TestFallbackService()
    }
    
    func getUsageStatistics(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics {
        print("🔍 HybridUsageService: 开始获取使用统计数据")
        print("   日期范围: \(dateRange)")
        print("   项目路径: \(projectPath ?? "全部")")
        
        // 先尝试从数据库读取
        do {
            let hasData = try checkDatabaseHasData()
            print("   数据库数据检查结果: \(hasData)")
            
            if hasData {
                print("✅ 正在从数据库获取数据...")
                let stats = try database.getUsageStatistics(dateRange: dateRange, projectPath: projectPath)
                print("✅ 数据库查询成功！总成本: $\(String(format: "%.2f", stats.totalCost)), 总请求: \(stats.totalRequests)")
                return stats
            } else {
                print("⚠️ 数据库为空，将降级到JSONL解析")
            }
        } catch {
            print("❌ 数据库查询异常: \(error)")
        }
        
        // 降级到JSONL文件解析
        print("📁 降级到JSONL文件解析...")
        return try await fallbackService.getUsageStatistics(dateRange: dateRange, projectPath: projectPath)
    }
    
    func getUsageStatisticsSilently(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics {
        return try await getUsageStatistics(dateRange: dateRange, projectPath: projectPath)
    }
    
    func getSessionStatistics(dateRange: DateRange, sortOrder: SessionSortOrder) async throws -> [ProjectUsage] {
        do {
            let hasData = try checkDatabaseHasData()
            if hasData {
                return try database.getSessionStatistics(dateRange: dateRange, sortOrder: sortOrder)
            }
        } catch {
            print("❌ 数据库会话查询异常: \(error)")
        }
        
        return try await fallbackService.getSessionStatistics(dateRange: dateRange, sortOrder: sortOrder)
    }
    
    func validateDataAccess() async throws -> Bool {
        return true
    }
    
    // MARK: - 数据检查逻辑
    
    private func checkDatabaseHasData() throws -> Bool {
        print("🔍 检查数据库是否有数据...")
        
        do {
            let stats = try database.getUsageStatistics(dateRange: .all, projectPath: nil)
            let hasData = stats.totalRequests > 0 || stats.totalSessions > 0
            print("   数据库统计: 请求数=\(stats.totalRequests), 会话数=\(stats.totalSessions)")
            print("   hasData 结果: \(hasData)")
            return hasData
        } catch {
            print("❌ 数据库数据检查失败: \(error)")
            return false
        }
    }
}

// MARK: - 测试主程序

func runTests() async {
    print("🚀 开始测试 HybridUsageService")
    print("=" * 60)
    
    let hybridService = TestHybridUsageService()
    
    // 测试1: 基本统计数据获取
    print("\n📊 测试1: 获取使用统计数据")
    print("-" * 30)
    
    do {
        let stats = try await hybridService.getUsageStatistics(dateRange: .all, projectPath: nil)
        print("测试结果:")
        print("  总成本: $\(String(format: "%.2f", stats.totalCost))")
        print("  总请求: \(stats.totalRequests)")
        print("  总会话: \(stats.totalSessions)")
        
        if stats.totalCost > 1000 {
            print("✅ 成功: 数据来自数据库（高成本值）")
        } else {
            print("⚠️ 警告: 数据可能来自JSONL降级（低成本值）")
        }
        
    } catch {
        print("❌ 测试1失败: \(error)")
    }
    
    // 测试2: 会话统计
    print("\n📊 测试2: 获取会话统计数据")
    print("-" * 30)
    
    do {
        let sessions = try await hybridService.getSessionStatistics(dateRange: .last7Days, sortOrder: .costDescending)
        print("测试结果: 找到 \(sessions.count) 个会话")
        for session in sessions {
            print("  项目: \(session.projectPath), 成本: $\(session.totalCost)")
        }
        
    } catch {
        print("❌ 测试2失败: \(error)")
    }
    
    print("\n🎯 测试完成!")
    print("如果看到'数据来自数据库'，说明HybridUsageService工作正常")
    print("如果看到'数据来自JSONL降级'，说明数据库访问有问题")
}

// 辅助函数
func *(left: String, right: Int) -> String {
    return String(repeating: left, count: right)
}

// 运行测试
await runTests()