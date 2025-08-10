import Foundation

/// 高性能流式 JSONL 文件解析器
/// 优化了内存使用、并发处理和缓存机制以提高大型 JSONL 文件的解析性能
class StreamingJSONLParser {
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let dateFormatter: DateFormatter
    private let isoDateFormatter: ISO8601DateFormatter
    private let cache: JSONLParserCache
    
    // 性能调优参数
    private let batchSize: Int
    private let maxConcurrentFiles: Int
    private let streamBufferSize: Int
    
    init(
        fileManager: FileManager = .default,
        batchSize: Int = 1000,
        maxConcurrentFiles: Int = 4,
        streamBufferSize: Int = 64 * 1024, // 64KB
        cacheExpiry: TimeInterval = 3600 // 1小时
    ) {
        self.fileManager = fileManager
        self.batchSize = batchSize
        self.maxConcurrentFiles = maxConcurrentFiles
        self.streamBufferSize = streamBufferSize
        
        // 初始化 JSON 解码器
        self.decoder = JSONDecoder()
        
        // 缓存 DateFormatter 以提高性能
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        self.isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        self.cache = JSONLParserCache(expiryInterval: cacheExpiry)
    }
    
    /// 解析指定目录下的所有 JSONL 文件 - 高性能版本
    func parseJSONLFiles(
        in projectsDirectory: URL,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [UsageEntry] {
        let startTime = CFAbsoluteTimeGetCurrent()
        Logger.shared.info("开始高性能 JSONL 解析，目录: \(projectsDirectory.path)")
        
        let jsonlFiles = try await findJSONLFiles(in: projectsDirectory)
        Logger.shared.info("找到 \(jsonlFiles.count) 个 JSONL 文件")
        
        // 使用并发处理文件
        let allEntries = try await parseFilesWithConcurrency(
            files: jsonlFiles,
            startDate: startDate,
            endDate: endDate
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        Logger.shared.info("解析完成：\(allEntries.count) 条记录，耗时 \(String(format: "%.2f", totalTime))s，速度: \(String(format: "%.0f", Double(allEntries.count) / totalTime)) 条/秒")
        
        return allEntries
    }
    
    /// 使用并发处理多个文件
    private func parseFilesWithConcurrency(
        files: [URL],
        startDate: Date?,
        endDate: Date?
    ) async throws -> [UsageEntry] {
        return try await withThrowingTaskGroup(of: [UsageEntry].self) { group in
            var allEntries: [UsageEntry] = []
            var fileIndex = 0
            var activeTasks = 0
            
            // 提交初始任务批次
            while fileIndex < files.count && activeTasks < maxConcurrentFiles {
                let fileURL = files[fileIndex]
                group.addTask {
                    return try await self.parseJSONLFileWithStreaming(
                        at: fileURL,
                        startDate: startDate,
                        endDate: endDate
                    )
                }
                fileIndex += 1
                activeTasks += 1
            }
            
            // 处理结果并提交新任务
            while activeTasks > 0 {
                let entries = try await group.next()!
                allEntries.append(contentsOf: entries)
                activeTasks -= 1
                
                // 如果还有文件要处理，提交新任务
                if fileIndex < files.count {
                    let fileURL = files[fileIndex]
                    group.addTask {
                        return try await self.parseJSONLFileWithStreaming(
                            at: fileURL,
                            startDate: startDate,
                            endDate: endDate
                        )
                    }
                    fileIndex += 1
                    activeTasks += 1
                }
            }
            
            return allEntries
        }
    }
    
    /// 使用流式处理解析单个 JSONL 文件
    private func parseJSONLFileWithStreaming(
        at fileURL: URL,
        startDate: Date?,
        endDate: Date?
    ) async throws -> [UsageEntry] {
        // 检查缓存
        if let cachedEntries = await cache.getCachedEntries(for: fileURL, startDate: startDate, endDate: endDate) {
            Logger.shared.debug("使用缓存数据: \(fileURL.lastPathComponent)")
            return cachedEntries
        }
        
        // 从文件路径中提取项目路径
        let projectPath = extractProjectPath(from: fileURL)
        
        var entries: [UsageEntry] = []
        var validLines = 0
        var skippedLines = 0
        var totalLines = 0
        
        // 打开文件进行流式读取
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            throw UsageStatisticsError.fileAccessDenied(fileURL.path)
        }
        
        defer {
            try? fileHandle.close()
        }
        
        var buffer = Data()
        var batch: [UsageEntry] = []
        batch.reserveCapacity(batchSize)
        
        // 流式读取文件内容
        while true {
            let chunk = fileHandle.readData(ofLength: streamBufferSize)
            if chunk.isEmpty {
                break
            }
            
            buffer.append(chunk)
            
            // 处理缓冲区中的完整行
            try await processBufferLines(
                buffer: &buffer,
                batch: &batch,
                entries: &entries,
                projectPath: projectPath,
                startDate: startDate,
                endDate: endDate,
                validLines: &validLines,
                skippedLines: &skippedLines,
                totalLines: &totalLines
            )
        }
        
        // 处理剩余的缓冲区内容
        if !buffer.isEmpty {
            try await processRemainingBuffer(
                buffer: buffer,
                batch: &batch,
                entries: &entries,
                projectPath: projectPath,
                startDate: startDate,
                endDate: endDate,
                validLines: &validLines,
                skippedLines: &skippedLines,
                totalLines: &totalLines
            )
        }
        
        // 处理最后一批数据
        if !batch.isEmpty {
            entries.append(contentsOf: batch)
        }
        
        Logger.shared.debug("文件 \(fileURL.lastPathComponent): \(totalLines) 行，有效 \(validLines)，跳过 \(skippedLines)")
        
        // 缓存结果
        await cache.setCachedEntries(entries, for: fileURL, startDate: startDate, endDate: endDate)
        
        return entries
    }
    
    /// 处理缓冲区中的完整行
    private func processBufferLines(
        buffer: inout Data,
        batch: inout [UsageEntry],
        entries: inout [UsageEntry],
        projectPath: String,
        startDate: Date?,
        endDate: Date?,
        validLines: inout Int,
        skippedLines: inout Int,
        totalLines: inout Int
    ) async throws {
        guard let string = String(data: buffer, encoding: .utf8) else {
            return
        }
        
        let lines = string.components(separatedBy: .newlines)
        
        // 保留最后一行（可能不完整）到缓冲区
        if lines.count > 1 {
            let incompleteLineData = lines.last?.data(using: .utf8) ?? Data()
            buffer = incompleteLineData
            
            // 处理完整的行
            let completeLines = lines.dropLast()
            try await processLines(
                lines: Array(completeLines),
                batch: &batch,
                entries: &entries,
                projectPath: projectPath,
                startDate: startDate,
                endDate: endDate,
                validLines: &validLines,
                skippedLines: &skippedLines,
                totalLines: &totalLines
            )
        }
    }
    
    /// 处理剩余的缓冲区内容
    private func processRemainingBuffer(
        buffer: Data,
        batch: inout [UsageEntry],
        entries: inout [UsageEntry],
        projectPath: String,
        startDate: Date?,
        endDate: Date?,
        validLines: inout Int,
        skippedLines: inout Int,
        totalLines: inout Int
    ) async throws {
        guard let string = String(data: buffer, encoding: .utf8),
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let lines = [string.trimmingCharacters(in: .whitespacesAndNewlines)]
        try await processLines(
            lines: lines,
            batch: &batch,
            entries: &entries,
            projectPath: projectPath,
            startDate: startDate,
            endDate: endDate,
            validLines: &validLines,
            skippedLines: &skippedLines,
            totalLines: &totalLines
        )
    }
    
    /// 批量处理行数据
    private func processLines(
        lines: [String],
        batch: inout [UsageEntry],
        entries: inout [UsageEntry],
        projectPath: String,
        startDate: Date?,
        endDate: Date?,
        validLines: inout Int,
        skippedLines: inout Int,
        totalLines: inout Int
    ) async throws {
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            totalLines += 1
            
            do {
                // 解析 JSON 行
                let jsonData = trimmedLine.data(using: .utf8) ?? Data()
                let rawEntry = try decoder.decode(RawJSONLEntry.self, from: jsonData)
                
                // 转换为标准使用记录
                if let entry = rawEntry.toUsageEntry(projectPath: projectPath) {
                    // 应用日期过滤 - 使用优化的日期检查
                    if isEntryInDateRange(entry, startDate: startDate, endDate: endDate) {
                        batch.append(entry)
                        validLines += 1
                        
                        // 当批次达到限制时，添加到主数组并清空批次
                        if batch.count >= batchSize {
                            entries.append(contentsOf: batch)
                            batch.removeAll(keepingCapacity: true)
                        }
                    } else {
                        skippedLines += 1
                    }
                } else {
                    skippedLines += 1
                }
            } catch {
                skippedLines += 1
                // 不记录每个解析错误，以减少日志开销
            }
        }
    }
    
    /// 优化的日期范围检查
    private func isEntryInDateRange(_ entry: UsageEntry, startDate: Date?, endDate: Date?) -> Bool {
        guard startDate != nil || endDate != nil else { return true }
        
        // 尝试使用缓存的日期格式化器
        var entryDate: Date?
        
        // 先尝试主要格式
        entryDate = dateFormatter.date(from: entry.timestamp)
        
        // 如果失败，尝试 ISO8601 格式
        if entryDate == nil {
            entryDate = isoDateFormatter.date(from: entry.timestamp)
        }
        
        // 如果还是失败，尝试其他常见格式
        if entryDate == nil {
            let altFormatter = DateFormatter()
            altFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            altFormatter.locale = Locale(identifier: "en_US_POSIX")
            altFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            entryDate = altFormatter.date(from: entry.timestamp)
        }
        
        guard let date = entryDate else { return false }
        
        if let startDate = startDate, date < startDate {
            return false
        }
        if let endDate = endDate, date > endDate {
            return false
        }
        return true
    }
    
    /// 查找指定目录下的所有 JSONL 文件
    private func findJSONLFiles(in directory: URL) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                guard FileManager.default.fileExists(atPath: directory.path) else {
                    continuation.resume(throwing: UsageStatisticsError.fileAccessDenied(directory.path))
                    return
                }
                
                var jsonlFiles: [URL] = []
                let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .fileSizeKey])
                
                // 使用递归枚举器遍历所有子目录 - 优化：逐个处理而不是一次性加载
                if let enumerator = FileManager.default.enumerator(
                    at: directory,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: [.skipsHiddenFiles],
                    errorHandler: { url, error in
                        Logger.shared.warning("访问文件失败: \(url.path) - \(error.localizedDescription)")
                        return true // 继续枚举
                    }
                ) {
                    // 逐个处理文件，避免一次性加载所有对象到内存
                    for case let fileURL as URL in enumerator {
                        autoreleasepool {
                            do {
                                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                                
                                if let isDirectory = resourceValues.isDirectory, !isDirectory,
                                   let name = resourceValues.name, name.hasSuffix(".jsonl") {
                                    jsonlFiles.append(fileURL)
                                }
                            } catch {
                                Logger.shared.warning("获取文件属性失败: \(fileURL.path) - \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                // 按文件大小排序，大文件优先处理（更好的并发平衡）
                jsonlFiles.sort { url1, url2 in
                    let size1 = (try? url1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    let size2 = (try? url2.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    return size1 > size2
                }
                
                continuation.resume(returning: jsonlFiles)
            }
        }
    }
    
    /// 从文件路径中提取项目路径
    private func extractProjectPath(from fileURL: URL) -> String {
        let pathComponents = fileURL.pathComponents
        
        // 查找 "projects" 目录的位置
        if let projectsIndex = pathComponents.firstIndex(of: "projects"),
           projectsIndex + 1 < pathComponents.count {
            
            // 项目路径是从 projects 目录的下一级开始
            let projectComponents = Array(pathComponents[(projectsIndex + 1)...])
            
            // 移除最后的文件名，只保留目录路径
            let directoryComponents = projectComponents.dropLast()
            
            if !directoryComponents.isEmpty {
                return "/" + directoryComponents.joined(separator: "/")
            }
        }
        
        // 如果无法确定项目路径，返回文件所在目录
        return fileURL.deletingLastPathComponent().path
    }
    
    /// 清除缓存
    func clearCache() async {
        await cache.clearCache()
    }
    
    /// 获取缓存统计信息
    func getCacheStats() async -> JSONLParserCacheStats {
        return await cache.getStats()
    }
}

/// JSONL 解析器缓存
actor JSONLParserCache {
    private var cache: [String: CachedResult] = [:]
    private let expiryInterval: TimeInterval
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var totalSize: Int = 0
    
    init(expiryInterval: TimeInterval) {
        self.expiryInterval = expiryInterval
    }
    
    func getCachedEntries(for fileURL: URL, startDate: Date?, endDate: Date?) -> [UsageEntry]? {
        let key = cacheKey(for: fileURL, startDate: startDate, endDate: endDate)
        
        // 检查文件修改时间
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modificationDate = fileAttributes[.modificationDate] as? Date else {
            return nil
        }
        
        if let cached = cache[key],
           cached.fileModificationDate >= modificationDate,
           Date().timeIntervalSince(cached.timestamp) < expiryInterval {
            hitCount += 1
            return cached.entries
        }
        
        // 清理过期的缓存项
        cache.removeValue(forKey: key)
        missCount += 1
        return nil
    }
    
    func setCachedEntries(_ entries: [UsageEntry], for fileURL: URL, startDate: Date?, endDate: Date?) {
        let key = cacheKey(for: fileURL, startDate: startDate, endDate: endDate)
        
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modificationDate = fileAttributes[.modificationDate] as? Date else {
            return
        }
        
        let result = CachedResult(
            entries: entries,
            timestamp: Date(),
            fileModificationDate: modificationDate
        )
        
        cache[key] = result
        totalSize += entries.count
        
        // 定期清理过期缓存
        if cache.count % 10 == 0 {
            cleanupExpiredCache()
        }
    }
    
    func clearCache() {
        cache.removeAll()
        hitCount = 0
        missCount = 0
        totalSize = 0
    }
    
    func getStats() -> JSONLParserCacheStats {
        let hitRate = hitCount + missCount > 0 ? Double(hitCount) / Double(hitCount + missCount) : 0
        return JSONLParserCacheStats(
            hitCount: hitCount,
            missCount: missCount,
            hitRate: hitRate,
            cacheSize: cache.count,
            totalCachedEntries: totalSize
        )
    }
    
    private func cacheKey(for fileURL: URL, startDate: Date?, endDate: Date?) -> String {
        let startStr = startDate?.timeIntervalSince1970.description ?? "nil"
        let endStr = endDate?.timeIntervalSince1970.description ?? "nil"
        return "\(fileURL.path)_\(startStr)_\(endStr)"
    }
    
    private func cleanupExpiredCache() {
        let now = Date()
        cache = cache.filter { _, value in
            now.timeIntervalSince(value.timestamp) < expiryInterval
        }
    }
    
    private struct CachedResult {
        let entries: [UsageEntry]
        let timestamp: Date
        let fileModificationDate: Date
    }
}

/// 缓存统计信息
struct JSONLParserCacheStats {
    let hitCount: Int
    let missCount: Int
    let hitRate: Double
    let cacheSize: Int
    let totalCachedEntries: Int
    
    var formattedHitRate: String {
        return String(format: "%.1f%%", hitRate * 100)
    }
}