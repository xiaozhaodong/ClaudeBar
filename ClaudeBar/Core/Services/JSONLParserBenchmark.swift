import Foundation

/// JSONL 解析器性能基准测试
class JSONLParserBenchmark {
    
    /// 比较两个解析器的性能
    static func comparePerformance(
        projectsDirectory: URL,
        dateRange: DateRange = .all
    ) async throws -> BenchmarkResult {
        let originalParser = JSONLParser()
        let streamingParser = StreamingJSONLParser(
            batchSize: 1000,
            maxConcurrentFiles: 4,
            streamBufferSize: 64 * 1024,
            cacheExpiry: 3600
        )
        
        Logger.shared.info("🚀 开始 JSONL 解析器性能基准测试")
        Logger.shared.info("测试目录: \(projectsDirectory.path)")
        
        // 清除流式解析器缓存以确保公平测试
        await streamingParser.clearCache()
        
        // 测试原始解析器
        Logger.shared.info("📊 测试原始 JSONLParser...")
        let originalStartTime = CFAbsoluteTimeGetCurrent()
        let originalStartMemory = getCurrentMemoryUsage()
        
        let originalEntries = try await originalParser.parseJSONLFiles(
            in: projectsDirectory,
            startDate: dateRange.startDate,
            endDate: Date()
        )
        
        let originalEndTime = CFAbsoluteTimeGetCurrent()
        let originalEndMemory = getCurrentMemoryUsage()
        let originalTime = originalEndTime - originalStartTime
        let originalMemoryDelta = max(0, originalEndMemory - originalStartMemory)
        
        Logger.shared.info("原始解析器: \(originalEntries.count) 条记录，耗时 \(String(format: "%.3f", originalTime))s")
        
        // 等待内存释放
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        
        // 测试流式解析器
        Logger.shared.info("⚡ 测试流式 StreamingJSONLParser...")
        let streamingStartTime = CFAbsoluteTimeGetCurrent()
        let streamingStartMemory = getCurrentMemoryUsage()
        
        let streamingEntries = try await streamingParser.parseJSONLFiles(
            in: projectsDirectory,
            startDate: dateRange.startDate,
            endDate: Date()
        )
        
        let streamingEndTime = CFAbsoluteTimeGetCurrent()
        let streamingEndMemory = getCurrentMemoryUsage()
        let streamingTime = streamingEndTime - streamingStartTime
        let streamingMemoryDelta = max(0, streamingEndMemory - streamingStartMemory)
        
        Logger.shared.info("流式解析器: \(streamingEntries.count) 条记录，耗时 \(String(format: "%.3f", streamingTime))s")
        
        // 获取缓存统计
        let cacheStats = await streamingParser.getCacheStats()
        
        // 计算性能提升
        let timeImprovement = originalTime > 0 ? (originalTime - streamingTime) / originalTime * 100 : 0
        let memoryImprovement = originalMemoryDelta > 0 ? Double(originalMemoryDelta - streamingMemoryDelta) / Double(originalMemoryDelta) * 100 : 0
        
        let result = BenchmarkResult(
            originalTime: originalTime,
            streamingTime: streamingTime,
            originalMemoryUsage: originalMemoryDelta,
            streamingMemoryUsage: streamingMemoryDelta,
            originalEntryCount: originalEntries.count,
            streamingEntryCount: streamingEntries.count,
            cacheStats: cacheStats,
            timeImprovement: timeImprovement,
            memoryImprovement: memoryImprovement
        )
        
        // 输出详细结果
        logBenchmarkResults(result)
        
        return result
    }
    
    /// 输出基准测试结果
    private static func logBenchmarkResults(_ result: BenchmarkResult) {
        Logger.shared.info("📈 性能基准测试结果:")
        Logger.shared.info("════════════════════════════════════════")
        Logger.shared.info("⏱️  解析时间:")
        Logger.shared.info("   原始解析器: \(String(format: "%.3f", result.originalTime))s")
        Logger.shared.info("   流式解析器: \(String(format: "%.3f", result.streamingTime))s")
        Logger.shared.info("   时间提升: \(String(format: "%.1f", result.timeImprovement))%")
        
        Logger.shared.info("💾 内存使用:")
        Logger.shared.info("   原始解析器: \(formatBytes(result.originalMemoryUsage))")
        Logger.shared.info("   流式解析器: \(formatBytes(result.streamingMemoryUsage))")
        Logger.shared.info("   内存节省: \(String(format: "%.1f", result.memoryImprovement))%")
        
        Logger.shared.info("📊 数据处理:")
        Logger.shared.info("   原始条目数: \(result.originalEntryCount)")
        Logger.shared.info("   流式条目数: \(result.streamingEntryCount)")
        Logger.shared.info("   数据完整性: \(result.dataIntegrityCheck ? "✅ 通过" : "❌ 失败")")
        
        Logger.shared.info("🗄️  缓存统计:")
        Logger.shared.info("   缓存命中率: \(result.cacheStats.formattedHitRate)")
        Logger.shared.info("   缓存大小: \(result.cacheStats.cacheSize) 个文件")
        Logger.shared.info("   缓存条目: \(result.cacheStats.totalCachedEntries)")
        
        let throughputImprovement = result.streamingTime > 0 ? 
            (Double(result.streamingEntryCount) / result.streamingTime) / (Double(result.originalEntryCount) / result.originalTime) - 1 : 0
        Logger.shared.info("🚀 吞吐量提升: \(String(format: "%.1f", throughputImprovement * 100))%")
        Logger.shared.info("════════════════════════════════════════")
    }
    
    /// 获取当前内存使用量
    private static func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) { pointer in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), pointer, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    /// 格式化字节数
    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

/// 基准测试结果
struct BenchmarkResult {
    let originalTime: TimeInterval
    let streamingTime: TimeInterval
    let originalMemoryUsage: Int64
    let streamingMemoryUsage: Int64
    let originalEntryCount: Int
    let streamingEntryCount: Int
    let cacheStats: JSONLParserCacheStats
    let timeImprovement: Double
    let memoryImprovement: Double
    
    /// 数据完整性检查
    var dataIntegrityCheck: Bool {
        return abs(originalEntryCount - streamingEntryCount) <= max(1, originalEntryCount / 1000) // 允许 0.1% 的误差
    }
    
    /// 是否有显著性能提升
    var hasSignificantImprovement: Bool {
        return timeImprovement > 10 || memoryImprovement > 15 // 时间提升 > 10% 或内存节省 > 15%
    }
    
    /// 总体性能等级
    var performanceGrade: String {
        if timeImprovement > 50 && memoryImprovement > 30 {
            return "🏆 优秀"
        } else if timeImprovement > 25 && memoryImprovement > 15 {
            return "🥈 良好"
        } else if timeImprovement > 10 || memoryImprovement > 10 {
            return "🥉 一般"
        } else {
            return "⚠️ 需要优化"
        }
    }
}