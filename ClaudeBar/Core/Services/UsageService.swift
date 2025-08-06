import Foundation
import Combine

/// 使用统计服务协议
protocol UsageServiceProtocol {
    /// 获取使用统计数据
    /// - Parameters:
    ///   - dateRange: 日期范围
    ///   - projectPath: 特定项目路径（可选）
    /// - Returns: 使用统计数据
    func getUsageStatistics(
        dateRange: DateRange,
        projectPath: String?
    ) async throws -> UsageStatistics
    
    /// 获取会话统计数据
    /// - Parameters:
    ///   - dateRange: 日期范围
    ///   - sortOrder: 排序方式
    /// - Returns: 项目使用统计数组
    func getSessionStatistics(
        dateRange: DateRange,
        sortOrder: SessionSortOrder
    ) async throws -> [ProjectUsage]
    
    /// 验证数据访问权限
    func validateDataAccess() async throws -> Bool
}

/// 会话排序方式
enum SessionSortOrder {
    case costDescending
    case costAscending
    case dateDescending
    case dateAscending
    case nameAscending
    case nameDescending
}

/// 使用统计服务实现
class UsageService: UsageServiceProtocol, ObservableObject {
    // 解析器选择：优先使用新的流式解析器
    private let legacyParser: JSONLParser
    private let streamingParser: StreamingJSONLParser
    private let configService: ConfigServiceProtocol
    private var cachedData: [String: CachedUsageData] = [:]
    private let cacheExpiryInterval: TimeInterval = 300 // 5分钟缓存
    
    // 性能设置
    private let useStreamingParser: Bool
    private let streamingBatchSize: Int
    private let maxConcurrentFiles: Int
    
    @Published var isLoading: Bool = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?
    @Published var parserStats: UsageServiceStats?
    
    init(
        legacyParser: JSONLParser = JSONLParser(),
        configService: ConfigServiceProtocol,
        useStreamingParser: Bool = true,
        streamingBatchSize: Int = 1000,
        maxConcurrentFiles: Int = 4
    ) {
        self.legacyParser = legacyParser
        self.configService = configService
        self.useStreamingParser = useStreamingParser
        self.streamingBatchSize = streamingBatchSize
        self.maxConcurrentFiles = maxConcurrentFiles
        
        // 初始化流式解析器
        self.streamingParser = StreamingJSONLParser(
            batchSize: streamingBatchSize,
            maxConcurrentFiles: maxConcurrentFiles,
            streamBufferSize: 64 * 1024,
            cacheExpiry: 3600 // 1小时缓存
        )
    }
    
    /// 获取使用统计数据
    func getUsageStatistics(
        dateRange: DateRange = .all,
        projectPath: String? = nil
    ) async throws -> UsageStatistics {
        Logger.shared.info("开始获取使用统计数据，日期范围: \(dateRange.displayName)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
                lastUpdateTime = Date()
            }
        }
        
        do {
            // 检查缓存
            let cacheKey = "\(dateRange.rawValue)_\(projectPath ?? "all")"
            if let cachedData = getCachedData(for: cacheKey) {
                Logger.shared.info("使用缓存的统计数据")
                return cachedData.statistics
            }
            
            // 获取 Claude 项目目录
            let claudeDirectory = try getClaudeDirectory()
            let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
            
            Logger.shared.info("获取的 Claude 目录: \(claudeDirectory.path)")
            Logger.shared.info("预期的 projects 目录: \(projectsDirectory.path)")
            
            // 检查目录是否存在
            guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
                Logger.shared.error("projects 目录不存在: \(projectsDirectory.path)")
                throw UsageStatisticsError.dataNotFound
            }
            
            // 添加详细的目录权限检查
            let isReadable = FileManager.default.isReadableFile(atPath: projectsDirectory.path)
            Logger.shared.info("projects 目录可读性: \(isReadable)")
            
            // 列出目录内容
            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(atPath: projectsDirectory.path)
                Logger.shared.info("projects 目录包含 \(directoryContents.count) 个项目：")
                for item in directoryContents.prefix(10) {
                    Logger.shared.info("- \(item)")
                }
                if directoryContents.count > 10 {
                    Logger.shared.info("... 还有 \(directoryContents.count - 10) 个项目")
                }
            } catch {
                Logger.shared.error("无法列出 projects 目录内容: \(error)")
            }
            
            // 解析 JSONL 文件 - 使用高性能解析器或传统解析器
            let parseStartTime = CFAbsoluteTimeGetCurrent()
            let entries: [UsageEntry]
            
            if useStreamingParser {
                Logger.shared.info("使用高性能流式解析器")
                entries = try await streamingParser.parseJSONLFiles(
                    in: projectsDirectory,
                    startDate: dateRange.startDate,
                    endDate: Date()
                )
                
                // 获取解析器统计信息
                let cacheStats = await streamingParser.getCacheStats()
                await MainActor.run {
                    parserStats = UsageServiceStats(
                        parserType: "StreamingJSONLParser",
                        parseTime: CFAbsoluteTimeGetCurrent() - parseStartTime,
                        cacheHitRate: cacheStats.hitRate,
                        cacheSize: cacheStats.cacheSize,
                        entriesProcessed: entries.count
                    )
                }
            } else {
                Logger.shared.info("使用传统解析器")
                entries = try await legacyParser.parseJSONLFiles(
                    in: projectsDirectory,
                    startDate: dateRange.startDate,
                    endDate: Date()
                )
                
                await MainActor.run {
                    parserStats = UsageServiceStats(
                        parserType: "JSONLParser",
                        parseTime: CFAbsoluteTimeGetCurrent() - parseStartTime,
                        cacheHitRate: 0,
                        cacheSize: 0,
                        entriesProcessed: entries.count
                    )
                }
            }
            
            Logger.shared.info("解析完成，获得原始条目数: \(entries.count)")
            
            // 应用项目路径过滤
            let filteredEntries = projectPath != nil ? 
                entries.filter { $0.projectPath.contains(projectPath!) } : entries
            
            Logger.shared.info("过滤后条目数: \(filteredEntries.count)")
            
            // 计算统计数据
            let statistics = calculateStatistics(from: filteredEntries)
            
            // 缓存结果
            setCachedData(statistics, for: cacheKey)
            
            Logger.shared.info("✅ 统计数据获取完成：总成本 $\(String(format: "%.2f", statistics.totalCost)), 总会话数 \(statistics.totalSessions), 总令牌数 \(formatNumber(statistics.totalTokens)), 总条目数 \(filteredEntries.count)")
            return statistics
            
        } catch {
            Logger.shared.error("获取使用统计失败: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    /// 获取会话统计数据
    func getSessionStatistics(
        dateRange: DateRange = .all,
        sortOrder: SessionSortOrder = .costDescending
    ) async throws -> [ProjectUsage] {
        let statistics = try await getUsageStatistics(dateRange: dateRange)
        let sessions = statistics.byProject
        
        // 应用排序
        return sortSessions(sessions, by: sortOrder)
    }
    
    /// 计算统计数据
    private func calculateStatistics(from entries: [UsageEntry]) -> UsageStatistics {
        guard !entries.isEmpty else {
            return UsageStatistics.empty
        }
        
        var totalCost: Double = 0
        var totalInputTokens: Int = 0
        var totalOutputTokens: Int = 0
        var totalCacheCreationTokens: Int = 0
        var totalCacheReadTokens: Int = 0
        
        var modelStats: [String: ModelUsageBuilder] = [:]
        var dateStats: [String: DailyUsageBuilder] = [:]
        var projectStats: [String: ProjectUsageBuilder] = [:]
        
        // 会话数：基于所有原始数据的唯一 session_id 计算（不受去重影响）
        var allSessionIds = Set<String>()
        for entry in entries {
            allSessionIds.insert(entry.sessionId)
        }
        
        // 处理数据条目 - 不进行去重以匹配 ccusage 统计结果
        var validEntries: [UsageEntry] = []
        
        Logger.shared.debug("🔍 开始处理 \(entries.count) 条原始数据条目，发现 \(allSessionIds.count) 个唯一会话")
        
        // 紧急调试：如果entries太少，这就是问题所在
        if entries.count < 100 {
            Logger.shared.error("❌ 关键问题：传入的entries数组只有\(entries.count)条，这远少于预期的数千条")
            Logger.shared.error("   这说明JSONL解析阶段出现了严重问题，大部分数据没有被成功解析")
            
            // 显示前几个条目的详细信息
            for (index, entry) in entries.prefix(5).enumerated() {
                Logger.shared.debug("   条目\(index + 1): sessionId=\(entry.sessionId), model=\(entry.model), tokens=\(entry.totalTokens)")
            }
        } else {
            Logger.shared.info("✅ entries数组大小正常：\(entries.count)条")
        }
        
        // 添加诊断信息
        var messageTypeDistribution: [String: Int] = [:]
        var modelDistribution: [String: Int] = [:]
        var entriesWithUsage = 0
        var entriesWithCost = 0
        
        for entry in entries {
            messageTypeDistribution[entry.messageType] = (messageTypeDistribution[entry.messageType] ?? 0) + 1
            modelDistribution[entry.model] = (modelDistribution[entry.model] ?? 0) + 1
            if entry.inputTokens > 0 || entry.outputTokens > 0 || entry.cacheCreationTokens > 0 || entry.cacheReadTokens > 0 {
                entriesWithUsage += 1
            }
            if entry.cost > 0 {
                entriesWithCost += 1
            }
        }
        
        Logger.shared.debug("消息类型分布: \(messageTypeDistribution)")
        Logger.shared.debug("模型分布: \(modelDistribution)")
        Logger.shared.debug("有使用数据的条目: \(entriesWithUsage), 有成本数据的条目: \(entriesWithCost)")
        
        // 完全基于测试脚本验证成功的ccusage去重策略实现
        // 参考测试脚本第616-730行的成功经验
        Logger.shared.debug("🧹 实施完全ccusage风格的去重逻辑")
        
        // 策略1: 测试无去重的情况（测试脚本第619-625行）
        Logger.shared.debug("🧪 测试策略1: 不进行去重，统计原始数据")
        var noDedupeTotal = 0
        for entry in entries {
            noDedupeTotal += entry.totalTokens
        }
        Logger.shared.debug("📊 无去重情况下的总tokens: \(formatNumber(noDedupeTotal))")
        
        // 策略2: ccusage风格的温和去重逻辑（测试脚本第627-661行）
        Logger.shared.debug("🧪 测试策略2a: 只对完全相同的条目进行去重")
        var gentleUniqueEntries: [String: UsageEntry] = [:]
        var gentleDuplicateCount = 0
        var gentleDuplicateTokens = 0
        
        for entry in entries {
            let totalEntryTokens = entry.inputTokens + entry.outputTokens + entry.cacheCreationTokens + entry.cacheReadTokens
            
            // 更严格的去重键：要求多个字段完全匹配才认为是重复（测试脚本第640行）
            let strictKey = "\(entry.timestamp):\(entry.model):\(totalEntryTokens):\(entry.sessionId)"
            
            if gentleUniqueEntries[strictKey] != nil {
                // 只有在时间戳、模型、token数量、会话ID都相同时才认为是重复
                gentleDuplicateCount += 1
                gentleDuplicateTokens += totalEntryTokens
                if gentleDuplicateCount <= 5 {
                    Logger.shared.debug("🔍 发现严格重复记录: \(strictKey.prefix(80))... (\(totalEntryTokens) tokens)")
                }
            } else {
                gentleUniqueEntries[strictKey] = entry
            }
        }
        
        Logger.shared.debug("📊 温和去重统计: 原始 \(entries.count) 条，去重后 \(gentleUniqueEntries.count) 条")
        Logger.shared.debug("📊 温和去重移除: \(gentleDuplicateCount) 条，tokens: \(formatNumber(gentleDuplicateTokens))")
        
        var gentleTotal = 0
        for entry in gentleUniqueEntries.values {
            gentleTotal += entry.totalTokens
        }
        Logger.shared.debug("📊 温和去重后总tokens: \(formatNumber(gentleTotal))")
        
        // 策略3: 激进去重逻辑对比（测试脚本第663-730行）
        Logger.shared.debug("🧹 对比：激进去重逻辑")
        
        var uniqueEntries: [String: UsageEntry] = [:]
        var duplicateCount = 0
        var duplicateTokens = 0
        var skippedNullCount = 0
        
        for entry in entries {
            let totalEntryTokens = entry.inputTokens + entry.outputTokens + entry.cacheCreationTokens + entry.cacheReadTokens

            // 完全模拟ccusage的createUniqueHash逻辑（测试脚本第674-681行）
            var uniqueKey: String?

            // 只有当同时有messageId和requestId时才创建去重键
            if let messageId = entry.messageId, !messageId.isEmpty,
               let requestId = entry.requestId, !requestId.isEmpty {
                uniqueKey = "\(messageId):\(requestId)"
            }

            // 如果没有完整的ID组合，不进行去重（ccusage的行为）
            if let finalUniqueKey = uniqueKey {
                if uniqueEntries[finalUniqueKey] != nil {
                    duplicateCount += 1
                    duplicateTokens += totalEntryTokens
                    continue // 跳过重复条目
                } else {
                    uniqueEntries[finalUniqueKey] = entry
                }
            } else {
                // 没有完整ID的条目直接添加，不去重
                let fallbackKey = "\(entry.timestamp):\(entry.model):\(totalEntryTokens):\(UUID().uuidString)"
                uniqueEntries[fallbackKey] = entry
                skippedNullCount += 1
            }
        }
        
        // 决定使用哪种去重策略（测试脚本第700-730行）
        let ccusageTarget = 1208150693  // 最新的ccusage统计结果 (2025-08-05 再次更新)
        let noDedupeDistance = abs(noDedupeTotal - ccusageTarget)
        let gentleDistance = abs(gentleTotal - ccusageTarget)
        let aggressiveTotal = uniqueEntries.values.reduce(0) { $0 + $1.totalTokens }
        let aggressiveDistance = abs(aggressiveTotal - ccusageTarget)
        
        Logger.shared.debug("🎯 去重策略比较:")
        Logger.shared.debug("无去重: \(formatNumber(noDedupeTotal)) (距离ccusage: \(formatNumber(noDedupeDistance)))")
        Logger.shared.debug("温和去重: \(formatNumber(gentleTotal)) (距离ccusage: \(formatNumber(gentleDistance)))")
        Logger.shared.debug("激进去重: \(formatNumber(aggressiveTotal)) (距离ccusage: \(formatNumber(aggressiveDistance)))")
        
        // 强制使用激进去重策略（与测试脚本保持一致）
        Logger.shared.debug("✅ 选择激进去重策略（与测试脚本一致）")
        let finalEntries = Array(uniqueEntries.values)
        let selectedStrategy = "aggressive"
        
        Logger.shared.debug("📊 最终选择策略: \(selectedStrategy)，条目数: \(finalEntries.count)")
        Logger.shared.debug("📊 去重统计: 原始 \(entries.count) 条，去重后 \(finalEntries.count) 条")
        Logger.shared.debug("📊 重复记录: \(duplicateCount) 条，重复tokens: \(formatNumber(duplicateTokens))")
        Logger.shared.debug("📊 跳过的null记录: \(skippedNullCount) 条 (messageId或requestId为空)")
        
        // 处理最终选定的数据条目
        for entry in finalEntries {
            validEntries.append(entry)

            // 使用定价模型计算成本（与 ccusage 一致）
            let calculatedCost = PricingModel.shared.calculateCost(
                model: entry.model,
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens,
                cacheCreationTokens: entry.cacheCreationTokens,
                cacheReadTokens: entry.cacheReadTokens
            )

            // 更新总计
            totalCost += calculatedCost  // 使用计算的成本而不是 entry.cost
            totalInputTokens += entry.inputTokens
            totalOutputTokens += entry.outputTokens
            totalCacheCreationTokens += entry.cacheCreationTokens
            totalCacheReadTokens += entry.cacheReadTokens
            
            // 按模型统计
            updateModelStats(&modelStats, with: entry)
            
            // 按日期统计
            updateDateStats(&dateStats, with: entry)
            
            // 按项目统计
            updateProjectStats(&projectStats, with: entry)
        }
        
        // 请求数是去重后的有效条目数
        let totalRequests = validEntries.count
        // 根据 ccusage 标准，总 token 包括所有类型：input + output + cache_creation + cache_read
        let totalTokens = totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
        
        Logger.shared.debug("🎯 最终统计结果：")
        Logger.shared.debug("- 总会话数: \(allSessionIds.count)（基于原始数据唯一session_id）")
        Logger.shared.debug("- 总请求数: \(totalRequests)（智能去重后的有效条目）")
        Logger.shared.debug("- 总成本: $\(String(format: "%.2f", totalCost))")
        Logger.shared.debug("- 总令牌: \(formatNumber(totalTokens))")
        Logger.shared.debug("- Input: \(formatNumber(totalInputTokens)), Output: \(formatNumber(totalOutputTokens)), Cache: \(formatNumber(totalCacheCreationTokens))+\(formatNumber(totalCacheReadTokens))")
        
        // 与ccusage基准对比（使用测试脚本验证的精确目标值）
        let difference = totalTokens - ccusageTarget
        let percentDiff = abs(Double(difference) / Double(ccusageTarget)) * 100
        Logger.shared.info("📊 与ccusage对比: 差异 \(formatNumber(difference)) tokens (\(String(format: "%.2f", percentDiff))%)")
        
        if percentDiff < 1.0 {
            Logger.shared.info("✅ 差异小于1%，达到目标精度！")
        } else if percentDiff < 5.0 {
            Logger.shared.info("🟡 差异小于5%，较好的精度")
        } else if percentDiff < 10.0 {
            Logger.shared.info("🟠 差异小于10%，需要进一步优化")
        } else {
            Logger.shared.warning("🔴 差异较大(\(String(format: "%.2f", percentDiff))%)，需要重新审查过滤策略")
        }
        
        // 数据一致性检查
        if allSessionIds.count > totalRequests {
            Logger.shared.info("⚠️ 会话数(\(allSessionIds.count)) > 请求数(\(totalRequests))，这可能是因为某些会话中的所有请求都被去重过滤掉了")
        }
        
        // 记录去重效果
        let dedupeRatio = Double(entries.count - validEntries.count) / Double(entries.count) * 100
        Logger.shared.debug("📊 去重效果: 原始条目 \(entries.count)，有效条目 \(validEntries.count)，去重率 \(String(format: "%.2f", dedupeRatio))%")
        
        return UsageStatistics(
            totalCost: totalCost,
            totalTokens: totalTokens,
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalCacheCreationTokens: totalCacheCreationTokens,
            totalCacheReadTokens: totalCacheReadTokens,
            totalSessions: allSessionIds.count,  // 使用原始数据的唯一会话数
            totalRequests: totalRequests,
            byModel: modelStats.values.map { $0.build() }.sorted { $0.totalCost > $1.totalCost },
            byDate: dateStats.values.map { $0.build() }.sorted { $0.date < $1.date },
            byProject: projectStats.values.map { $0.build() }.sorted { $0.totalCost > $1.totalCost }
        )
    }
    
    /// 更新模型统计
    private func updateModelStats(_ modelStats: inout [String: ModelUsageBuilder], with entry: UsageEntry) {
        if modelStats[entry.model] == nil {
            modelStats[entry.model] = ModelUsageBuilder(model: entry.model)
        }
        modelStats[entry.model]?.add(entry)
    }
    
    /// 更新日期统计
    private func updateDateStats(_ dateStats: inout [String: DailyUsageBuilder], with entry: UsageEntry) {
        let dateKey = entry.dateString
        if dateStats[dateKey] == nil {
            dateStats[dateKey] = DailyUsageBuilder(date: dateKey)
        }
        dateStats[dateKey]?.add(entry)
    }
    
    /// 更新项目统计
    private func updateProjectStats(_ projectStats: inout [String: ProjectUsageBuilder], with entry: UsageEntry) {
        if projectStats[entry.projectPath] == nil {
            projectStats[entry.projectPath] = ProjectUsageBuilder(
                projectPath: entry.projectPath,
                projectName: entry.projectName
            )
        }
        projectStats[entry.projectPath]?.add(entry)
    }
    
    /// 排序会话数据
    private func sortSessions(_ sessions: [ProjectUsage], by sortOrder: SessionSortOrder) -> [ProjectUsage] {
        switch sortOrder {
        case .costDescending:
            return sessions.sorted { $0.totalCost > $1.totalCost }
        case .costAscending:
            return sessions.sorted { $0.totalCost < $1.totalCost }
        case .dateDescending:
            return sessions.sorted { $0.lastUsed > $1.lastUsed }
        case .dateAscending:
            return sessions.sorted { $0.lastUsed < $1.lastUsed }
        case .nameAscending:
            return sessions.sorted { $0.projectName < $1.projectName }
        case .nameDescending:
            return sessions.sorted { $0.projectName > $1.projectName }
        }
    }
    
    /// 获取 Claude 配置目录
    private func getClaudeDirectory() throws -> URL {
        // 尝试从 ConfigService 获取配置目录
        if let configDirectory = try? getConfigServiceDirectory() {
            return configDirectory
        }
        
        // 回退到默认目录
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(".claude")
    }
    
    /// 从 ConfigService 获取配置目录
    private func getConfigServiceDirectory() throws -> URL? {
        if let configService = configService as? ConfigService {
            let configPath = configService.configDirectoryPath
            let configURL = URL(fileURLWithPath: configPath)
            
            // ConfigService 返回的是 ~/.claude/config 目录
            // 我们需要父目录 ~/.claude 来访问 projects 子目录
            if configURL.lastPathComponent == "config" {
                return configURL.deletingLastPathComponent()
            }
            
            return configURL
        }
        return nil
    }
    
    /// 获取缓存数据
    private func getCachedData(for key: String) -> CachedUsageData? {
        guard let cached = cachedData[key],
              Date().timeIntervalSince(cached.timestamp) < cacheExpiryInterval else {
            cachedData.removeValue(forKey: key)
            return nil
        }
        return cached
    }
    
    /// 设置缓存数据
    private func setCachedData(_ statistics: UsageStatistics, for key: String) {
        cachedData[key] = CachedUsageData(
            statistics: statistics,
            timestamp: Date()
        )
        
        // 清理过期缓存
        cleanupExpiredCache()
    }
    
    /// 清理过期缓存
    private func cleanupExpiredCache() {
        let now = Date()
        cachedData = cachedData.filter { key, value in
            now.timeIntervalSince(value.timestamp) < cacheExpiryInterval
        }
    }
    
    /// 清除所有缓存
    func clearCache() async {
        cachedData.removeAll()
        
        // 如果使用流式解析器，也清除其缓存
        if useStreamingParser {
            await streamingParser.clearCache()
        }
        
        Logger.shared.info("使用统计缓存已清除")
    }
    
    /// 运行性能基准测试
    func runPerformanceBenchmark() async throws -> BenchmarkResult? {
        let claudeDirectory = try getClaudeDirectory()
        let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
        
        guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
            Logger.shared.warning("projects 目录不存在，无法运行基准测试")
            return nil
        }
        
        Logger.shared.info("🚀 开始运行 JSONL 解析器性能基准测试...")
        
        // 运行基准测试
        let result = try await JSONLParserBenchmark.comparePerformance(
            projectsDirectory: projectsDirectory,
            dateRange: .all
        )
        
        Logger.shared.info("📈 基准测试完成，总体性能评级: \(result.performanceGrade)")
        
        return result
    }
    
    /// 验证数据访问权限
    func validateDataAccess() async throws -> Bool {
        do {
            let claudeDirectory = try getClaudeDirectory()
            let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
            
            return FileManager.default.fileExists(atPath: projectsDirectory.path) &&
                   FileManager.default.isReadableFile(atPath: projectsDirectory.path)
        } catch {
            throw UsageStatisticsError.fileAccessDenied("无法访问 Claude 数据目录")
        }
    }
    
    /// 清除解析器缓存
    func clearParserCache() async {
        if useStreamingParser {
            await streamingParser.clearCache()
            Logger.shared.info("已清除流式解析器缓存")
        }
       await clearCache()
    }
    
    /// 获取解析器性能统计
    func getParserStats() async -> UsageServiceStats? {
        return parserStats
    }
    
    /// 切换解析器类型（用于测试和调试）
    func switchParserType() {
        // 注意：这个方法不能在运行时动态切换，只能通过重新初始化实现
        Logger.shared.info("解析器切换需要重新初始化 UsageService")
//        await clearCache()
    }
    
    /// 格式化数字显示（与测试脚本保持一致）
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

/// 缓存的使用数据
private struct CachedUsageData {
    let statistics: UsageStatistics
    let timestamp: Date
}

/// 模型使用统计构建器
private class ModelUsageBuilder {
    let model: String
    private var totalCost: Double = 0
    private var inputTokens: Int = 0
    private var outputTokens: Int = 0
    private var cacheCreationTokens: Int = 0
    private var cacheReadTokens: Int = 0
    private var sessionIds = Set<String>()
    private var requestIds = Set<String>()
    private var entryCount: Int = 0
    
    init(model: String) {
        self.model = model
    }
    
    func add(_ entry: UsageEntry) {
        // 使用定价模型计算成本（与 ccusage 一致）
        let calculatedCost = PricingModel.shared.calculateCost(
            model: entry.model,
            inputTokens: entry.inputTokens,
            outputTokens: entry.outputTokens,
            cacheCreationTokens: entry.cacheCreationTokens,
            cacheReadTokens: entry.cacheReadTokens
        )
        totalCost += calculatedCost
        inputTokens += entry.inputTokens
        outputTokens += entry.outputTokens
        cacheCreationTokens += entry.cacheCreationTokens
        cacheReadTokens += entry.cacheReadTokens
        sessionIds.insert(entry.sessionId)
        entryCount += 1
        
        // 跟踪唯一请求ID
        if let requestId = entry.requestId {
            requestIds.insert(requestId)
        }
    }
    
    func build() -> ModelUsage {
        // 请求数优先使用唯一请求ID数量，否则使用条目数量
        let requestCount = requestIds.count > 0 ? requestIds.count : entryCount
        
        return ModelUsage(
            model: model,
            totalCost: totalCost,
            totalTokens: inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            sessionCount: sessionIds.count,
            requestCount: requestCount
        )
    }
}

/// 日期使用统计构建器
private class DailyUsageBuilder {
    let date: String
    private var totalCost: Double = 0
    private var totalTokens: Int = 0
    private var modelsUsed = Set<String>()
    
    init(date: String) {
        self.date = date
    }
    
    func add(_ entry: UsageEntry) {
        // 使用定价模型计算成本（与 ccusage 一致）
        let calculatedCost = PricingModel.shared.calculateCost(
            model: entry.model,
            inputTokens: entry.inputTokens,
            outputTokens: entry.outputTokens,
            cacheCreationTokens: entry.cacheCreationTokens,
            cacheReadTokens: entry.cacheReadTokens
        )
        totalCost += calculatedCost
        // 确保与 ccusage 计算方式一致
        totalTokens += entry.totalTokens
        modelsUsed.insert(entry.model)
    }
    
    func build() -> DailyUsage {
        return DailyUsage(
            date: date,
            totalCost: totalCost,
            totalTokens: totalTokens,
            modelsUsed: Array(modelsUsed)
        )
    }
}

/// 项目使用统计构建器
private class ProjectUsageBuilder {
    let projectPath: String
    let projectName: String
    private var totalCost: Double = 0
    private var totalTokens: Int = 0
    private var sessionIds = Set<String>()
    private var requestIds = Set<String>()
    private var entryCount: Int = 0
    private var lastUsed: String = ""
    
    init(projectPath: String, projectName: String) {
        self.projectPath = projectPath
        self.projectName = projectName
    }
    
    func add(_ entry: UsageEntry) {
        // 使用定价模型计算成本（与 ccusage 一致）
        let calculatedCost = PricingModel.shared.calculateCost(
            model: entry.model,
            inputTokens: entry.inputTokens,
            outputTokens: entry.outputTokens,
            cacheCreationTokens: entry.cacheCreationTokens,
            cacheReadTokens: entry.cacheReadTokens
        )
        totalCost += calculatedCost
        // 确保与 ccusage 计算方式一致：使用 entry.totalTokens
        totalTokens += entry.totalTokens
        sessionIds.insert(entry.sessionId)
        entryCount += 1
        
        // 跟踪唯一请求ID
        if let requestId = entry.requestId {
            requestIds.insert(requestId)
        }
        
        // 更新最后使用时间
        if entry.timestamp > lastUsed {
            lastUsed = entry.timestamp
        }
    }
    
    func build() -> ProjectUsage {
        // 请求数优先使用唯一请求ID数量，否则使用条目数量
        let requestCount = requestIds.count > 0 ? requestIds.count : entryCount
        
        return ProjectUsage(
            projectPath: projectPath,
            projectName: projectName,
            totalCost: totalCost,
            totalTokens: totalTokens,
            sessionCount: sessionIds.count,
            requestCount: requestCount,
            lastUsed: lastUsed
        )
    }
}

/// 使用服务统计信息
struct UsageServiceStats {
    let parserType: String
    let parseTime: TimeInterval
    let cacheHitRate: Double
    let cacheSize: Int
    let entriesProcessed: Int
    
    var formattedParseTime: String {
        return String(format: "%.3f", parseTime)
    }
    
    var formattedCacheHitRate: String {
        return String(format: "%.1f%%", cacheHitRate * 100)
    }
    
    var throughput: Double {
        return parseTime > 0 ? Double(entriesProcessed) / parseTime : 0
    }
    
    var formattedThroughput: String {
        return String(format: "%.0f", throughput)
    }
}
