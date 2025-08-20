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
    
    // MARK: - 批量数据插入功能
    
    /// 批量插入使用记录数据
    /// 高性能实现，支持大数据集、进度回调和错误恢复
    /// - Parameters:
    ///   - entries: 要插入的使用记录数组
    ///   - batchSize: 批次大小（默认1000条一批）
    ///   - progressCallback: 进度回调（0.0-1.0）
    /// - Returns: 实际插入的记录数量
    /// - Throws: 插入过程中的错误
    func batchInsertUsageEntries(
        _ entries: [UsageEntry],
        batchSize: Int = 1000,
        progressCallback: ((Double) -> Void)? = nil
    ) async throws -> Int {
        guard !entries.isEmpty else { return 0 }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        Logger.shared.info("🚀 开始批量插入 \(entries.count) 条使用记录，批次大小: \(batchSize)")
        
        var totalInserted = 0
        let totalBatches = (entries.count + batchSize - 1) / batchSize
        
        // 分批处理以优化内存使用和事务粒度
        for batchIndex in 0..<totalBatches {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, entries.count)
            let batch = Array(entries[startIndex..<endIndex])
            
            do {
                let batchInserted = try database.insertUsageEntries(batch)
                totalInserted += batchInserted
                
                // 更新进度
                let progress = Double(batchIndex + 1) / Double(totalBatches)
                progressCallback?(progress)
                
                Logger.shared.debug("批次 \(batchIndex + 1)/\(totalBatches) 完成: \(batchInserted)/\(batch.count) 条记录插入成功")
                
                // 定期让出CPU时间，避免阻塞UI
                if batchIndex % 10 == 0 {
                    await Task.yield()
                }
                
            } catch {
                Logger.shared.error("批次 \(batchIndex + 1) 插入失败: \(error)")
                // 根据错误类型决定是否继续
                if isCriticalError(error) {
                    throw BatchInsertError.criticalError(error, processedBatches: batchIndex, totalInserted: totalInserted)
                } else {
                    Logger.shared.warning("跳过失败批次，继续处理后续数据")
                    continue
                }
            }
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let throughput = Double(totalInserted) / duration
        
        Logger.shared.info("✅ 批量插入完成: \(totalInserted)/\(entries.count) 条记录成功插入")
        Logger.shared.info("⚡ 性能指标: 耗时 \(String(format: "%.2f", duration))s, 吞吐量 \(String(format: "%.0f", throughput)) 记录/秒")
        
        // 插入完成后不立即更新统计，在全量迁移最后统一更新
        // try await updateStatisticsSummariesIfNeeded(insertedCount: totalInserted)
        
        return totalInserted
    }
    
    /// 高性能批量插入（优化版本）
    /// 使用预编译语句和优化的内存管理
    /// - Parameters:
    ///   - entries: 要插入的使用记录数组  
    ///   - progressCallback: 进度回调
    /// - Returns: 插入结果统计
    func optimizedBatchInsert(
        _ entries: [UsageEntry],
        progressCallback: ((BatchInsertProgress) -> Void)? = nil
    ) async throws -> BatchInsertResult {
        guard !entries.isEmpty else {
            return BatchInsertResult(totalProcessed: 0, successCount: 0, errorCount: 0, duration: 0)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        Logger.shared.info("🔥 开始高性能批量插入 \(entries.count) 条记录")
        
        var successCount = 0
        var errorCount = 0
        
        // 按日期分组以优化统计更新
        let groupedEntries = Dictionary(grouping: entries) { $0.dateString }
        let sortedDates = groupedEntries.keys.sorted()
        
        for (dateIndex, dateString) in sortedDates.enumerated() {
            guard let dateEntries = groupedEntries[dateString] else { continue }
            
            do {
                let inserted = try database.insertUsageEntries(dateEntries)
                successCount += inserted
                errorCount += (dateEntries.count - inserted)
                
                // 不在这里更新统计，避免重复
                // try database.updateStatisticsForDate(dateString)
                
                // 更新进度
                let progress = BatchInsertProgress(
                    currentBatch: dateIndex + 1,
                    totalBatches: sortedDates.count,
                    processedRecords: successCount + errorCount,
                    totalRecords: entries.count,
                    currentOperation: "处理日期: \(dateString)"
                )
                progressCallback?(progress)
                
                Logger.shared.debug("日期 \(dateString): \(inserted)/\(dateEntries.count) 条记录插入成功")
                
            } catch {
                Logger.shared.error("处理日期 \(dateString) 失败: \(error)")
                errorCount += dateEntries.count
                
                if isCriticalError(error) {
                    throw error
                }
            }
            
            // 定期让出CPU
            if dateIndex % 5 == 0 {
                await Task.yield()
            }
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let result = BatchInsertResult(
            totalProcessed: entries.count,
            successCount: successCount,
            errorCount: errorCount,
            duration: duration
        )
        
        Logger.shared.info("✅ 高性能批量插入完成: \(result.successCount)/\(result.totalProcessed) 成功")
        Logger.shared.info("⚡ 平均吞吐量: \(String(format: "%.0f", result.throughput)) 记录/秒")
        
        return result
    }
    
    /// 流式批量插入（内存优化版本）
    /// 适用于超大数据集，逐步处理减少内存占用
    /// - Parameters:
    ///   - entriesProvider: 异步数据提供者
    ///   - batchSize: 处理批次大小
    ///   - progressCallback: 进度回调
    /// - Returns: 插入结果
    func streamingBatchInsert(
        entriesProvider: @escaping () async throws -> [UsageEntry]?,
        batchSize: Int = 500,
        progressCallback: ((BatchInsertProgress) -> Void)? = nil
    ) async throws -> BatchInsertResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        Logger.shared.info("🌊 开始流式批量插入，批次大小: \(batchSize)")
        
        var totalProcessed = 0
        var successCount = 0
        var errorCount = 0
        var batchNumber = 0
        
        while let batch = try await entriesProvider() {
            guard !batch.isEmpty else { break }
            
            batchNumber += 1
            
            do {
                let inserted = try database.insertUsageEntries(batch)
                successCount += inserted
                errorCount += (batch.count - inserted)
                totalProcessed += batch.count
                
                // 更新进度（估算）
                let progress = BatchInsertProgress(
                    currentBatch: batchNumber,
                    totalBatches: -1, // 未知总数
                    processedRecords: totalProcessed,
                    totalRecords: -1, // 未知总数
                    currentOperation: "处理批次 \(batchNumber), 已处理 \(totalProcessed) 条"
                )
                progressCallback?(progress)
                
                Logger.shared.debug("流式批次 \(batchNumber): \(inserted)/\(batch.count) 条记录插入成功")
                
                // 定期让出CPU和更新统计
                if batchNumber % 10 == 0 {
                    await Task.yield()
                    try? database.updateStatisticsSummaries()
                }
                
            } catch {
                Logger.shared.error("流式批次 \(batchNumber) 失败: \(error)")
                errorCount += batch.count
                totalProcessed += batch.count
                
                if isCriticalError(error) {
                    throw error
                }
            }
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let result = BatchInsertResult(
            totalProcessed: totalProcessed,
            successCount: successCount,
            errorCount: errorCount,
            duration: duration
        )
        
        Logger.shared.info("✅ 流式插入完成: \(result.successCount)/\(result.totalProcessed) 成功")
        return result
    }
    
    // MARK: - 私有辅助方法
    
    /// 判断是否为严重错误（需要中断处理）
    private func isCriticalError(_ error: Error) -> Bool {
        if let dbError = error as? UsageStatisticsDBError {
            switch dbError {
            case .connectionFailed:
                return true // 连接失败应该中断
            case .operationFailed(let message):
                // 磁盘空间不足等严重问题
                return message.contains("disk") || message.contains("space") || message.contains("SQLITE_FULL")
            case .dataNotFound, .invalidData:
                return false // 数据问题可以继续
            }
        }
        return false
    }
    
    /// 根据插入量判断是否需要更新统计汇总
    private func updateStatisticsSummariesIfNeeded(insertedCount: Int) async throws {
        // 插入量超过1000条时才更新汇总统计，避免频繁操作
        if insertedCount >= 1000 {
            Logger.shared.info("📊 插入量较大，更新统计汇总")
            try database.updateStatisticsSummaries()
        }
    }
    
    // MARK: - 完整数据迁移功能
    
    /// 执行完整的数据迁移过程（直接复制测试文件中的正确步骤）
    /// 扫描 JSONL 文件 → 清空数据库 → 解析数据 → 批量插入 → 修复日期 → 去重 → 生成统计
    /// - Parameters:
    ///   - progressCallback: 进度回调 (0.0-1.0)
    /// - Returns: 迁移结果统计
    func performFullDataMigration(
        progressCallback: ((Double, String) -> Void)? = nil
    ) async throws -> FullMigrationResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        Logger.shared.info("🚀 开始执行完整数据迁移（使用测试文件中的正确逻辑）")
        
        progressCallback?(0.0, "准备数据迁移...")
        
        // 步骤 1: 获取 Claude 目录和扫描 JSONL 文件
        let claudeDirectory = getClaudeDirectory()
        let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
        
        guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
            throw MigrationError.claudeDirectoryNotFound("Claude projects 目录不存在: \(projectsDirectory.path)")
        }
        
        progressCallback?(0.1, "扫描 JSONL 文件...")
        let jsonlFiles = try scanJSONLFiles(in: projectsDirectory)
        Logger.shared.info("📄 找到 \(jsonlFiles.count) 个 JSONL 文件")
        
        guard !jsonlFiles.isEmpty else {
            throw MigrationError.noDataFound("未找到任何 JSONL 文件")
        }
        
        // 步骤 2: 清空数据库并重置序列（与测试文件完全一致）
        progressCallback?(0.2, "清空数据库...")
        try database.clearAllDataAndResetSequences()
        Logger.shared.info("✅ 数据库清空完成")
        
        // 步骤 3: 解析并批量插入数据（与测试文件完全一致）
        progressCallback?(0.3, "开始解析和插入数据...")
        let insertResult = try await parseAndInsertJSONLFiles(
            jsonlFiles,
            startProgress: 0.3,
            endProgress: 0.7,
            progressCallback: progressCallback
        )
        
        Logger.shared.info("✅ 数据插入完成: \(insertResult.totalInserted)/\(insertResult.totalEntries) 条记录")
        
        // 步骤 4: 去重处理（日期字符串已在插入时处理，无需单独修复）
        progressCallback?(0.8, "去重处理...")
        try database.deduplicateEntries()
        Logger.shared.info("✅ 去重处理完成")
        
        // 步骤 5: 生成统计汇总
        progressCallback?(0.9, "生成统计汇总...")
        try database.generateAllStatistics()
        Logger.shared.info("✅ 统计汇总生成完成")
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        progressCallback?(1.0, "迁移完成")
        
        let result = FullMigrationResult(
            filesProcessed: insertResult.filesProcessed,
            totalEntries: insertResult.totalEntries,
            insertedEntries: insertResult.totalInserted,
            duration: duration,
            filesWithData: insertResult.filesWithData,
            emptyFiles: insertResult.emptyFiles
        )
        
        Logger.shared.info("🎉 完整数据迁移完成: \(result.description)")
        return result
    }
    
    // MARK: - 迁移过程的私有辅助方法
    
    /// 获取 Claude 目录
    private func getClaudeDirectory() -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(".claude")
    }
    
    /// 扫描指定目录中的所有 JSONL 文件
    private func scanJSONLFiles(in directory: URL) throws -> [URL] {
        var jsonlFiles: [URL] = []
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
        
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                Logger.shared.warning("⚠️ 访问文件失败: \(url.path) - \(error.localizedDescription)")
                return true // 继续枚举
            }
        ) else {
            throw MigrationError.fileSystemError("无法访问目录: \(directory.path)")
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                
                if let isDirectory = resourceValues.isDirectory, !isDirectory,
                   let name = resourceValues.name, name.hasSuffix(".jsonl") {
                    jsonlFiles.append(fileURL)
                }
            } catch {
                Logger.shared.warning("⚠️ 获取文件属性失败: \(fileURL.path) - \(error.localizedDescription)")
            }
        }
        
        // 按文件大小排序，小文件优先（优化处理顺序）
        jsonlFiles.sort { url1, url2 in
            let size1 = (try? url1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let size2 = (try? url2.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return size1 < size2
        }
        
        return jsonlFiles
    }
    
    /// 并行解析并插入 JSONL 文件数据
    /// 使用并发处理提升文件解析性能，同时保持数据库插入的线程安全
    private func parseAndInsertJSONLFiles(
        _ jsonlFiles: [URL],
        startProgress: Double,
        endProgress: Double,
        progressCallback: ((Double, String) -> Void)?
    ) async throws -> InsertionResult {
        let progressRange = endProgress - startProgress
        var totalEntries = 0
        var totalInserted = 0
        var filesWithData = 0
        var emptyFiles = 0
        
        // 分批处理文件以控制并发度
        let batchSize = min(4, max(1, jsonlFiles.count / 10)) // 控制并发数量
        let batches = jsonlFiles.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            // 并行解析当前批次的文件
            let parseResults = await withTaskGroup(of: FileParseResult.self) { group in
                for fileURL in batch {
                    group.addTask {
                        await self.parseFileAsync(fileURL)
                    }
                }
                
                var results: [FileParseResult] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            // 串行插入解析结果以保证数据库安全
            for (fileIndex, result) in parseResults.enumerated() {
                let overallIndex = batchIndex * batchSize + fileIndex
                let fileProgress = startProgress + (Double(overallIndex) / Double(jsonlFiles.count)) * progressRange
                progressCallback?(fileProgress, "插入文件: \(result.fileName)")
                
                do {
                    if case .success(let entries, let fileSize, let modificationDate) = result.parseResult {
                        // 记录文件处理状态
                        try database.recordFileProcessing(result.fileURL, fileSize: fileSize, lastModified: modificationDate)
                        
                        totalEntries += entries.count
                        
                        if !entries.isEmpty {
                            let inserted = try database.insertUsageEntries(entries)
                            totalInserted += inserted
                            filesWithData += 1
                            Logger.shared.debug("文件 \(result.fileName): 解析 \(entries.count) 条，插入 \(inserted) 条")
                        } else {
                            emptyFiles += 1
                            Logger.shared.debug("文件 \(result.fileName): 无有效数据")
                        }
                        
                        // 更新文件处理完成状态
                        try database.updateFileProcessingCompleted(result.fileURL, entryCount: entries.count)
                        
                    } else if case .empty = result.parseResult {
                        emptyFiles += 1
                        Logger.shared.debug("跳过空文件: \(result.fileName)")
                        
                    } else if case .error(let error) = result.parseResult {
                        Logger.shared.error("❌ 处理文件失败: \(result.fileName) - \(error)")
                        emptyFiles += 1
                    }
                    
                } catch {
                    Logger.shared.error("❌ 插入文件数据失败: \(result.fileName) - \(error)")
                    emptyFiles += 1
                }
            }
            
            // 批次间让出 CPU 时间
            await Task.yield()
        }
        
        return InsertionResult(
            filesProcessed: jsonlFiles.count,
            totalEntries: totalEntries,
            totalInserted: totalInserted,
            filesWithData: filesWithData,
            emptyFiles: emptyFiles
        )
    }
    
    /// 异步解析单个文件
    private func parseFileAsync(_ fileURL: URL) async -> FileParseResult {
        do {
            let fileName = fileURL.lastPathComponent
            
            // 检查文件大小
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize == 0 {
                return FileParseResult(
                    fileURL: fileURL,
                    fileName: fileName,
                    parseResult: .empty
                )
            }
            
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            
            // 解析 JSONL 文件
            let entries = try await parseJSONLFile(fileURL)
            
            return FileParseResult(
                fileURL: fileURL,
                fileName: fileName,
                parseResult: .success(entries, fileSize, modificationDate)
            )
            
        } catch {
            return FileParseResult(
                fileURL: fileURL,
                fileName: fileURL.lastPathComponent,
                parseResult: .error(error)
            )
        }
    }
    
    /// 解析单个 JSONL 文件（直接复制测试文件中的正确逻辑）
    private func parseJSONLFile(_ fileURL: URL) async throws -> [UsageEntry] {
        let data = try Data(contentsOf: fileURL)
        let content = String(data: data, encoding: .utf8) ?? ""
        
        // 从文件路径提取项目路径（与测试文件完全一致）
        let projectPath = extractProjectPath(from: fileURL)
        
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var entries: [UsageEntry] = []
        let decoder = JSONDecoder()
        var validLines = 0
        var skippedLines = 0
        
        for line in lines {
            do {
                let jsonData = line.data(using: .utf8) ?? Data()
                
                // 解析原始JSONL数据（使用系统现有的 RawJSONLEntry）
                let rawEntry = try decoder.decode(RawJSONLEntry.self, from: jsonData)
                
                // 转换为标准使用记录（与测试文件完全一致）
                if let entry = rawEntry.toUsageEntry(projectPath: projectPath, sourceFile: fileURL.lastPathComponent) {
                    entries.append(entry)
                    validLines += 1
                } else {
                    skippedLines += 1
                }
                
            } catch {
                skippedLines += 1
                // 与测试文件一致：静默跳过解析错误，减少日志开销
            }
        }
        
        Logger.shared.debug("文件 \(fileURL.lastPathComponent): 有效行 \(validLines), 跳过行 \(skippedLines)")
        return entries
    }
    
    /// 从文件路径提取项目路径（与测试文件完全一致）
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

// MARK: - 批量插入相关数据结构

/// 批量插入进度信息
struct BatchInsertProgress {
    let currentBatch: Int
    let totalBatches: Int
    let processedRecords: Int
    let totalRecords: Int
    let currentOperation: String
    
    /// 进度百分比 (0.0-1.0)
    var progressPercentage: Double {
        guard totalRecords > 0 else { return 0.0 }
        return Double(processedRecords) / Double(totalRecords)
    }
    
    /// 批次进度百分比 (0.0-1.0)
    var batchProgressPercentage: Double {
        guard totalBatches > 0 else { return 0.0 }
        return Double(currentBatch) / Double(totalBatches)
    }
    
    /// 进度描述
    var description: String {
        if totalBatches > 0 {
            return "批次 \(currentBatch)/\(totalBatches) - \(currentOperation)"
        } else {
            return "\(currentOperation) - 已处理 \(processedRecords) 条记录"
        }
    }
}

/// 批量插入结果
struct BatchInsertResult {
    let totalProcessed: Int
    let successCount: Int
    let errorCount: Int
    let duration: TimeInterval
    
    /// 成功率 (0.0-1.0)
    var successRate: Double {
        guard totalProcessed > 0 else { return 0.0 }
        return Double(successCount) / Double(totalProcessed)
    }
    
    /// 吞吐量 (记录/秒)
    var throughput: Double {
        guard duration > 0 else { return 0.0 }
        return Double(successCount) / duration
    }
    
    /// 结果描述
    var description: String {
        return "总计: \(totalProcessed), 成功: \(successCount), 失败: \(errorCount), 耗时: \(String(format: "%.2f", duration))s"
    }
    
    /// 性能描述
    var performanceDescription: String {
        return "成功率: \(String(format: "%.1f", successRate * 100))%, 吞吐量: \(String(format: "%.0f", throughput)) 记录/秒"
    }
}

/// 批量插入错误
enum BatchInsertError: Error, LocalizedError {
    case criticalError(Error, processedBatches: Int, totalInserted: Int)
    case invalidInput(String)
    case resourceExhausted(String)
    case operationCancelled
    
    var errorDescription: String? {
        switch self {
        case .criticalError(let underlyingError, let processedBatches, let totalInserted):
            return "严重错误导致批量插入中断: \(underlyingError.localizedDescription)。已处理 \(processedBatches) 个批次，插入 \(totalInserted) 条记录。"
        case .invalidInput(let message):
            return "输入数据无效: \(message)"
        case .resourceExhausted(let message):
            return "资源耗尽: \(message)"
        case .operationCancelled:
            return "操作已取消"
        }
    }
}

// MARK: - 完整数据迁移相关数据结构

/// 完整数据迁移结果
struct FullMigrationResult {
    let filesProcessed: Int
    let totalEntries: Int
    let insertedEntries: Int
    let duration: TimeInterval
    let filesWithData: Int
    let emptyFiles: Int
    
    /// 成功率 (0.0-1.0)
    var successRate: Double {
        guard totalEntries > 0 else { return 0.0 }
        return Double(insertedEntries) / Double(totalEntries)
    }
    
    /// 处理效率 (有效文件比例)
    var processingEfficiency: Double {
        guard filesProcessed > 0 else { return 0.0 }
        return Double(filesWithData) / Double(filesProcessed)
    }
    
    /// 吞吐量 (记录/秒)
    var throughput: Double {
        guard duration > 0 else { return 0.0 }
        return Double(insertedEntries) / duration
    }
    
    /// 结果描述
    var description: String {
        return """
        迁移完成: 处理文件 \(filesProcessed) 个，总记录 \(totalEntries) 条，成功插入 \(insertedEntries) 条
        耗时: \(String(format: "%.2f", duration))s，成功率: \(String(format: "%.1f", successRate * 100))%
        有效文件: \(filesWithData) 个，空文件: \(emptyFiles) 个
        """
    }
    
    /// 性能报告
    var performanceReport: String {
        return """
        性能指标:
        - 处理效率: \(String(format: "%.1f", processingEfficiency * 100))%
        - 数据吞吐量: \(String(format: "%.0f", throughput)) 记录/秒
        - 平均文件处理时间: \(String(format: "%.3f", duration / Double(filesProcessed)))s/文件
        """
    }
}

/// 插入结果数据结构
struct InsertionResult {
    let filesProcessed: Int
    let totalEntries: Int
    let totalInserted: Int
    let filesWithData: Int
    let emptyFiles: Int
}

/// 迁移错误类型
enum MigrationError: Error, LocalizedError {
    case claudeDirectoryNotFound(String)
    case noDataFound(String)
    case fileSystemError(String)
    case parsingError(String)
    case databaseError(String)
    
    var errorDescription: String? {
        switch self {
        case .claudeDirectoryNotFound(let message):
            return "Claude 目录未找到: \(message)"
        case .noDataFound(let message):
            return "未找到数据: \(message)"
        case .fileSystemError(let message):
            return "文件系统错误: \(message)"
        case .parsingError(let message):
            return "数据解析错误: \(message)"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        }
    }
}

// MARK: - 并行文件处理相关数据结构

/// 文件解析结果
struct FileParseResult {
    let fileURL: URL
    let fileName: String
    let parseResult: ParseResult
}

/// 解析结果枚举
enum ParseResult {
    case success([UsageEntry], Int64, Date)  // entries, fileSize, modificationDate
    case empty
    case error(Error)
}

/// Array扩展：分块处理
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}