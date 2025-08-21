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
    
    /// 静默获取使用统计数据（不显示加载状态）
    func getUsageStatisticsSilently(
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
actor UsageServiceActor {
    private var cachedData: [String: CachedUsageData] = [:]
    private let cacheExpiryInterval: TimeInterval
    
    init(cacheExpiryInterval: TimeInterval) {
        self.cacheExpiryInterval = cacheExpiryInterval
    }
    
    /// 获取缓存数据
    func getCachedData(for key: String) -> CachedUsageData? {
        guard var cached = cachedData[key] else {
            return nil
        }
        
        // 检查缓存状态
        let status = cached.getCacheStatus()
        
        if status == .expired {
            cachedData.removeValue(forKey: key)
            return nil
        }
        
        // 增加命中次数
        cached.incrementHitCount()
        cachedData[key] = cached
        
        return cached
    }
    
    /// 设置缓存数据
    func setCachedData(_ statistics: UsageStatistics, for key: String) {
        cachedData[key] = CachedUsageData(
            statistics: statistics,
            cacheExpiryInterval: cacheExpiryInterval
        )
        
        // 清理过期缓存
        cleanupExpiredCache()
    }
    
    /// 清理过期缓存
    private func cleanupExpiredCache() {
        cachedData = cachedData.filter { key, value in
            value.getCacheStatus() != .expired
        }
    }
    
    /// 清除所有缓存（线程安全）
    func clearAllCache() {
        cachedData.removeAll()
        Logger.shared.info("已清除所有缓存数据")
    }
    
    /// 获取缓存统计信息（线程安全）
    func getCacheStats() -> (count: Int, totalSize: Int, hitCount: Int) {
        let count = cachedData.count
        let totalSize = cachedData.values.reduce(0) { $0 + $1.dataSize }
        let hitCount = cachedData.values.reduce(0) { $0 + $1.hitCount }
        return (count: count, totalSize: totalSize, hitCount: hitCount)
    }
    
    /// 获取缓存元数据
    func getCacheMetadata(for key: String) -> CacheMetadata? {
        guard let cached = cachedData[key] else {
            return nil
        }
        return cached.getMetadata()
    }
    
    /// 获取所有缓存统计信息
    func getAllCacheMetadata() -> [String: CacheMetadata] {
        return cachedData.mapValues { $0.getMetadata() }
    }
}

/// 使用统计服务实现
class UsageService: UsageServiceProtocol, ObservableObject {
    // 解析器选择：优先使用新的流式解析器
    private let legacyParser: JSONLParser
    private let streamingParser: StreamingJSONLParser
    private let configService: ConfigServiceProtocol
    private let cacheActor: UsageServiceActor
    private let cacheExpiryInterval: TimeInterval = 1800 // 30分钟缓存
    
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
        streamingBatchSize: Int = 2000,  // 增加批处理大小从 1000 到 2000
        maxConcurrentFiles: Int = 8       // 增加并发文件数从 4 到 8
    ) {
        self.legacyParser = legacyParser
        self.configService = configService
        self.useStreamingParser = useStreamingParser
        self.streamingBatchSize = streamingBatchSize
        self.maxConcurrentFiles = maxConcurrentFiles
        self.cacheActor = UsageServiceActor(cacheExpiryInterval: cacheExpiryInterval)
        
        // 初始化流式解析器
        self.streamingParser = StreamingJSONLParser(
            batchSize: streamingBatchSize,
            maxConcurrentFiles: maxConcurrentFiles,
            streamBufferSize: 128 * 1024,  // 增加缓冲区大小从 64KB 到 128KB
            cacheExpiry: 3600 // 1小时缓存
        )
    }
    
    /// 获取使用统计数据
    func getUsageStatistics(
        dateRange: DateRange = .all,
        projectPath: String? = nil
    ) async throws -> UsageStatistics {
        return try await getUsageStatistics(dateRange: dateRange, projectPath: projectPath, showLoading: true)
    }

    /// 获取使用统计数据（内部方法，可控制是否显示加载状态）
    private func getUsageStatistics(
        dateRange: DateRange = .all,
        projectPath: String? = nil,
        showLoading: Bool = true
    ) async throws -> UsageStatistics {
        Logger.shared.info("开始获取使用统计数据，日期范围: \(dateRange.displayName), 显示加载状态: \(showLoading)")

        do {
            // 检查缓存
            let cacheKey = "\(dateRange.rawValue)_\(projectPath ?? "all")"
            Logger.shared.info("🔍 检查缓存，Key: \(cacheKey)")
            if let cachedData = await cacheActor.getCachedData(for: cacheKey) {
                Logger.shared.info("✅ 使用缓存的统计数据，状态: \(cachedData.getCacheStatus().displayName)")
                // 缓存命中时不设置加载状态，直接返回数据
                await MainActor.run {
                    lastUpdateTime = Date()
                }
                return cachedData.statistics
            } else {
                Logger.shared.info("❌ 缓存未命中或已过期，需要重新加载")
            }

            // 只有在需要重新加载且要求显示加载状态时才设置加载状态
            if showLoading {
                await MainActor.run {
                    isLoading = true
                    errorMessage = nil
                }
            }

            defer {
                if showLoading {
                    Task { @MainActor in
                        isLoading = false
                        lastUpdateTime = Date()
                    }
                } else {
                    Task { @MainActor in
                        lastUpdateTime = Date()
                    }
                }
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
            Logger.shared.info("💾 存储缓存数据，Key: \(cacheKey)")
            await cacheActor.setCachedData(statistics, for: cacheKey)
            
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

    /// 静默获取使用统计数据（不显示加载状态，用于缓存恢复）
    func getUsageStatisticsSilently(
        dateRange: DateRange = .all,
        projectPath: String? = nil
    ) async throws -> UsageStatistics {
        return try await getUsageStatistics(dateRange: dateRange, projectPath: projectPath, showLoading: false)
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
        
        // 检查数据量
        if entries.count < 100 {
            Logger.shared.error("❌ 关键问题：传入的entries数组只有\(entries.count)条，这远少于预期的数千条")
            Logger.shared.error("   这说明JSONL解析阶段出现了严重问题，大部分数据没有被成功解析")
        } else {
            Logger.shared.info("✅ entries数组大小正常：\(entries.count)条")
        }
        
        Logger.shared.debug("🧹 开始激进去重逻辑处理")
        
        // 激进去重逻辑：基于 messageId + requestId
        var uniqueEntries: [String: UsageEntry] = [:]
        var duplicateCount = 0
        var skippedNullCount = 0
        
        for entry in entries {
            // 完全模拟ccusage的createUniqueHash逻辑
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
                    continue // 跳过重复条目
                } else {
                    uniqueEntries[finalUniqueKey] = entry
                }
            } else {
                // 没有完整ID的条目直接添加，不去重
                let fallbackKey = "\(entry.timestamp):\(entry.model):\(entry.totalTokens):\(UUID().uuidString)"
                uniqueEntries[fallbackKey] = entry
                skippedNullCount += 1
            }
        }
        
        let finalEntries = Array(uniqueEntries.values)
        
        Logger.shared.debug("📊 去重统计: 原始 \(entries.count) 条，去重后 \(finalEntries.count) 条")
        Logger.shared.debug("📊 重复记录: \(duplicateCount) 条，跳过的null记录: \(skippedNullCount) 条")
        
        // 处理去重后的数据条目
        var effectiveRequestCount = 0  // 有效请求数（有成本的条目数）
        
        for entry in finalEntries {
            // 使用定价模型计算成本（与 ccusage 一致）- 只计算一次
            let calculatedCost = PricingModel.shared.calculateCost(
                model: entry.model,
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens,
                cacheCreationTokens: entry.cacheCreationTokens,
                cacheReadTokens: entry.cacheReadTokens
            )

            if calculatedCost > 0 {
                effectiveRequestCount += 1
            }

            // 更新总计
            totalCost += calculatedCost
            totalInputTokens += entry.inputTokens
            totalOutputTokens += entry.outputTokens
            totalCacheCreationTokens += entry.cacheCreationTokens
            totalCacheReadTokens += entry.cacheReadTokens
            
            // 按模型统计 - 传递预计算的成本
            updateModelStats(&modelStats, with: entry, calculatedCost: calculatedCost)
            
            // 按日期统计 - 传递预计算的成本
            updateDateStats(&dateStats, with: entry, calculatedCost: calculatedCost)
            
            // 按项目统计 - 传递预计算的成本
            updateProjectStats(&projectStats, with: entry, calculatedCost: calculatedCost)
        }
        
        let totalRequests = finalEntries.count
        let totalTokens = totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
        
        Logger.shared.info("📊 最终统计结果：")
        Logger.shared.info("- 总会话数: \(allSessionIds.count)")
        Logger.shared.info("- 总请求数: \(totalRequests)")
        Logger.shared.info("- 有成本的条目: \(effectiveRequestCount)")
        Logger.shared.info("- 总成本: $\(String(format: "%.6f", totalCost))")
        Logger.shared.info("- 总令牌: \(formatNumber(totalTokens))")
        
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
    private func updateModelStats(_ modelStats: inout [String: ModelUsageBuilder], with entry: UsageEntry, calculatedCost: Double) {
        // Phase 2: 在统计层面过滤无效模型
        guard !entry.model.isEmpty && entry.model != "unknown" && entry.model != "<synthetic>" else {
            Logger.shared.debug("⚠️  跳过统计 - 无效模型: '\(entry.model)', tokens=\(entry.totalTokens)")
            return
        }
        
        if modelStats[entry.model] == nil {
            modelStats[entry.model] = ModelUsageBuilder(model: entry.model)
        }
        modelStats[entry.model]?.add(entry, calculatedCost: calculatedCost)
    }
    
    /// 更新日期统计
    private func updateDateStats(_ dateStats: inout [String: DailyUsageBuilder], with entry: UsageEntry, calculatedCost: Double) {
        let dateKey = entry.dateString
        if dateStats[dateKey] == nil {
            dateStats[dateKey] = DailyUsageBuilder(date: dateKey)
        }
        dateStats[dateKey]?.add(entry, calculatedCost: calculatedCost)
    }
    
    /// 更新项目统计
    private func updateProjectStats(_ projectStats: inout [String: ProjectUsageBuilder], with entry: UsageEntry, calculatedCost: Double) {
        if projectStats[entry.projectPath] == nil {
            projectStats[entry.projectPath] = ProjectUsageBuilder(
                projectPath: entry.projectPath,
                projectName: entry.projectName
            )
        }
        projectStats[entry.projectPath]?.add(entry, calculatedCost: calculatedCost)
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
    
    
    /// 清除所有缓存
    func clearCache() async {
        await cacheActor.clearAllCache()
        
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
    
    /// 获取缓存元数据
    func getCacheMetadata(for dateRange: DateRange = .all, projectPath: String? = nil) async -> CacheMetadata? {
        let cacheKey = "\(dateRange.rawValue)_\(projectPath ?? "all")"
        return await cacheActor.getCacheMetadata(for: cacheKey)
    }
    
    /// 获取所有缓存统计信息
    func getAllCacheMetadata() async -> [String: CacheMetadata] {
        return await cacheActor.getAllCacheMetadata()
    }
    
    /// 获取解析器性能统计
    func getParserStats() async -> UsageServiceStats? {
        return parserStats
    }
    
    /// 格式化数字显示（与测试脚本保持一致）
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

/// 缓存的使用数据
struct CachedUsageData {
    let statistics: UsageStatistics
    let timestamp: Date
    let cacheTime: Date
    let expiryTime: Date
    let dataSize: Int
    private(set) var hitCount: Int
    
    init(statistics: UsageStatistics, cacheExpiryInterval: TimeInterval) {
        self.statistics = statistics
        self.timestamp = Date()
        self.cacheTime = Date()
        self.expiryTime = Date().addingTimeInterval(cacheExpiryInterval)
        self.dataSize = Self.calculateDataSize(statistics)
        self.hitCount = 0
    }
    
    /// 计算统计数据的近似大小
    private static func calculateDataSize(_ statistics: UsageStatistics) -> Int {
        var size = 0
        
        // 基础统计数据
        size += MemoryLayout<Double>.size * 4 // costs
        size += MemoryLayout<Int>.size * 8 // token counts and session/request counts
        
        // 模型数据
        size += statistics.byModel.count * 200 // 每个模型约200字节
        
        // 日期数据
        size += statistics.byDate.count * 100 // 每个日期约100字节
        
        // 项目数据
        size += statistics.byProject.count * 300 // 每个项目约300字节（包含路径）
        
        return size
    }
    
    /// 增加命中次数
    mutating func incrementHitCount() {
        hitCount += 1
    }
    
    /// 获取缓存状态
    func getCacheStatus() -> CacheStatus {
        let now = Date()
        let timeToExpiry = expiryTime.timeIntervalSince(now)
        
        if timeToExpiry <= 0 {
            return .expired
        } else if timeToExpiry <= 300 { // 5分钟内过期
            return .stale
        } else {
            return .fresh
        }
    }
    
    /// 获取缓存元数据
    func getMetadata() -> CacheMetadata {
        return CacheMetadata(
            status: getCacheStatus(),
            cacheTime: cacheTime,
            expiryTime: expiryTime,
            hitCount: hitCount,
            dataSize: dataSize
        )
    }
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
    
    func add(_ entry: UsageEntry, calculatedCost: Double) {
        // 使用预计算的成本，避免重复计算
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
        // 统一使用条目数，与总请求数计算保持一致
        let requestCount = entryCount
        
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
    
    func add(_ entry: UsageEntry, calculatedCost: Double) {
        // 使用预计算的成本，避免重复计算
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
            sessionCount: 0, // 传统UsageService不支持会话统计，使用0
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
    
    func add(_ entry: UsageEntry, calculatedCost: Double) {
        // 使用预计算的成本，避免重复计算
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
        // 统一使用条目数，与总请求数和模型统计保持一致
        let requestCount = entryCount
        
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
