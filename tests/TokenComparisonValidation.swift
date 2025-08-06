import Foundation

/// Token 统计对比验证工具
/// 用于验证 ClaudeBar 与 ccusage 的统计结果是否一致
class TokenComparisonValidation {
    
    /// 验证结果结构
    struct ValidationResult {
        let totalTokensMatch: Bool
        let costMatch: Bool
        let sessionCountMatch: Bool
        let requestCountMatch: Bool
        let cacheTokensMatch: Bool
        let differences: [String]
        
        var isValid: Bool {
            return totalTokensMatch && costMatch && sessionCountMatch && requestCountMatch && cacheTokensMatch
        }
        
        var summary: String {
            if isValid {
                return "✅ 所有统计指标都与 ccusage 一致"
            } else {
                return "❌ 发现差异：\n" + differences.joined(separator: "\n")
            }
        }
    }
    
    /// 对比两个统计结果
    /// - Parameters:
    ///   - claudeBarStats: ClaudeBar 的统计结果
    ///   - ccusageStats: ccusage 的统计结果
    ///   - tolerance: 允许的误差范围（百分比）
    /// - Returns: 验证结果
    static func compare(
        claudeBarStats: UsageStatistics,
        ccusageStats: CCUsageStats,
        tolerance: Double = 0.01 // 1% 误差容忍度
    ) -> ValidationResult {
        var differences: [String] = []
        
        // 1. 检查总 token 数
        let totalTokensMatch = abs(Double(claudeBarStats.totalTokens - ccusageStats.totalTokens)) / Double(ccusageStats.totalTokens) <= tolerance
        if !totalTokensMatch {
            differences.append("总 Token 数不匹配：ClaudeBar: \(claudeBarStats.totalTokens), ccusage: \(ccusageStats.totalTokens)")
        }
        
        // 2. 检查总成本
        let costMatch = abs(claudeBarStats.totalCost - ccusageStats.totalCost) / ccusageStats.totalCost <= tolerance
        if !costMatch {
            differences.append("总成本不匹配：ClaudeBar: $\(claudeBarStats.totalCost), ccusage: $\(ccusageStats.totalCost)")
        }
        
        // 3. 检查会话数
        let sessionCountMatch = abs(Double(claudeBarStats.totalSessions - ccusageStats.totalSessions)) / Double(ccusageStats.totalSessions) <= tolerance
        if !sessionCountMatch {
            differences.append("会话数不匹配：ClaudeBar: \(claudeBarStats.totalSessions), ccusage: \(ccusageStats.totalSessions)")
        }
        
        // 4. 检查请求数
        let requestCountMatch = abs(Double(claudeBarStats.totalRequests - ccusageStats.totalRequests)) / Double(ccusageStats.totalRequests) <= tolerance
        if !requestCountMatch {
            differences.append("请求数不匹配：ClaudeBar: \(claudeBarStats.totalRequests), ccusage: \(ccusageStats.totalRequests)")
        }
        
        // 5. 检查缓存 token 统计
        let cacheTokensMatch = checkCacheTokensMatch(claudeBarStats: claudeBarStats, ccusageStats: ccusageStats, tolerance: tolerance, differences: &differences)
        
        return ValidationResult(
            totalTokensMatch: totalTokensMatch,
            costMatch: costMatch,
            sessionCountMatch: sessionCountMatch,
            requestCountMatch: requestCountMatch,
            cacheTokensMatch: cacheTokensMatch,
            differences: differences
        )
    }
    
    /// 检查缓存 token 是否匹配
    private static func checkCacheTokensMatch(
        claudeBarStats: UsageStatistics,
        ccusageStats: CCUsageStats,
        tolerance: Double,
        differences: inout [String]
    ) -> Bool {
        var allMatch = true
        
        // 检查缓存创建 token
        if ccusageStats.totalCacheCreationTokens > 0 {
            let cacheCreationMatch = abs(Double(claudeBarStats.totalCacheCreationTokens - ccusageStats.totalCacheCreationTokens)) / Double(ccusageStats.totalCacheCreationTokens) <= tolerance
            if !cacheCreationMatch {
                differences.append("缓存创建 Token 不匹配：ClaudeBar: \(claudeBarStats.totalCacheCreationTokens), ccusage: \(ccusageStats.totalCacheCreationTokens)")
                allMatch = false
            }
        }
        
        // 检查缓存读取 token
        if ccusageStats.totalCacheReadTokens > 0 {
            let cacheReadMatch = abs(Double(claudeBarStats.totalCacheReadTokens - ccusageStats.totalCacheReadTokens)) / Double(ccusageStats.totalCacheReadTokens) <= tolerance
            if !cacheReadMatch {
                differences.append("缓存读取 Token 不匹配：ClaudeBar: \(claudeBarStats.totalCacheReadTokens), ccusage: \(ccusageStats.totalCacheReadTokens)")
                allMatch = false
            }
        }
        
        return allMatch
    }
    
    /// 生成详细的对比报告
    static func generateDetailedReport(
        claudeBarStats: UsageStatistics,
        ccusageStats: CCUsageStats
    ) -> String {
        var report = """
        # Token 统计对比报告
        
        ## 总体统计
        | 指标 | ClaudeBar | ccusage | 差异 | 差异率 |
        |------|-----------|---------|------|--------|
        """
        
        // 总 Token 数
        let tokenDiff = claudeBarStats.totalTokens - ccusageStats.totalTokens
        let tokenDiffPercent = ccusageStats.totalTokens > 0 ? Double(tokenDiff) / Double(ccusageStats.totalTokens) * 100 : 0
        report += "\n| 总 Token 数 | \(claudeBarStats.totalTokens) | \(ccusageStats.totalTokens) | \(tokenDiff) | \(String(format: "%.2f%%", tokenDiffPercent)) |"
        
        // 总成本
        let costDiff = claudeBarStats.totalCost - ccusageStats.totalCost
        let costDiffPercent = ccusageStats.totalCost > 0 ? costDiff / ccusageStats.totalCost * 100 : 0
        report += "\n| 总成本 | $\(String(format: "%.6f", claudeBarStats.totalCost)) | $\(String(format: "%.6f", ccusageStats.totalCost)) | $\(String(format: "%.6f", costDiff)) | \(String(format: "%.2f%%", costDiffPercent)) |"
        
        // 会话数
        let sessionDiff = claudeBarStats.totalSessions - ccusageStats.totalSessions
        let sessionDiffPercent = ccusageStats.totalSessions > 0 ? Double(sessionDiff) / Double(ccusageStats.totalSessions) * 100 : 0
        report += "\n| 会话数 | \(claudeBarStats.totalSessions) | \(ccusageStats.totalSessions) | \(sessionDiff) | \(String(format: "%.2f%%", sessionDiffPercent)) |"
        
        // 请求数
        let requestDiff = claudeBarStats.totalRequests - ccusageStats.totalRequests
        let requestDiffPercent = ccusageStats.totalRequests > 0 ? Double(requestDiff) / Double(ccusageStats.totalRequests) * 100 : 0
        report += "\n| 请求数 | \(claudeBarStats.totalRequests) | \(ccusageStats.totalRequests) | \(requestDiff) | \(String(format: "%.2f%%", requestDiffPercent)) |"
        
        report += """
        
        ## Token 类型分解
        | Token 类型 | ClaudeBar | ccusage | 差异 |
        |------------|-----------|---------|------|
        """
        
        report += "\n| Input Tokens | \(claudeBarStats.totalInputTokens) | \(ccusageStats.totalInputTokens) | \(claudeBarStats.totalInputTokens - ccusageStats.totalInputTokens) |"
        report += "\n| Output Tokens | \(claudeBarStats.totalOutputTokens) | \(ccusageStats.totalOutputTokens) | \(claudeBarStats.totalOutputTokens - ccusageStats.totalOutputTokens) |"
        report += "\n| Cache Creation | \(claudeBarStats.totalCacheCreationTokens) | \(ccusageStats.totalCacheCreationTokens) | \(claudeBarStats.totalCacheCreationTokens - ccusageStats.totalCacheCreationTokens) |"
        report += "\n| Cache Read | \(claudeBarStats.totalCacheReadTokens) | \(ccusageStats.totalCacheReadTokens) | \(claudeBarStats.totalCacheReadTokens - ccusageStats.totalCacheReadTokens) |"
        
        return report
    }
}

/// ccusage 统计结果的模拟结构（用于测试对比）
struct CCUsageStats {
    let totalTokens: Int
    let totalCost: Double
    let totalSessions: Int
    let totalRequests: Int
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCacheCreationTokens: Int
    let totalCacheReadTokens: Int
}

// MARK: - 使用示例和测试方法
extension TokenComparisonValidation {
    
    /// 运行验证测试的示例方法
    static func runValidationTest() {
        print("🧪 开始 Token 统计验证测试...")
        
        // 模拟的 ccusage 数据（实际使用时应该从 ccusage 输出中获取）
        let mockCCUsageStats = CCUsageStats(
            totalTokens: 150000,
            totalCost: 2.5,
            totalSessions: 25,
            totalRequests: 45,
            totalInputTokens: 100000,
            totalOutputTokens: 40000,
            totalCacheCreationTokens: 8000,
            totalCacheReadTokens: 2000
        )
        
        // 模拟的 ClaudeBar 数据
        let mockClaudeBarStats = UsageStatistics(
            totalCost: 2.52,
            totalTokens: 151000,
            totalInputTokens: 100500,
            totalOutputTokens: 40200,
            totalCacheCreationTokens: 8100,
            totalCacheReadTokens: 2200,
            totalSessions: 26,
            totalRequests: 46,
            byModel: [],
            byDate: [],
            byProject: []
        )
        
        // 执行对比验证
        let result = compare(
            claudeBarStats: mockClaudeBarStats,
            ccusageStats: mockCCUsageStats,
            tolerance: 0.05 // 5% 误差容忍度
        )
        
        print(result.summary)
        
        // 生成详细报告
        let detailedReport = generateDetailedReport(
            claudeBarStats: mockClaudeBarStats,
            ccusageStats: mockCCUsageStats
        )
        
        print("\n" + detailedReport)
    }
}