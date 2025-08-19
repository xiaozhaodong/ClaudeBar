import Foundation

/// 使用统计数据迁移服务
/// 负责将现有的JSONL文件数据导入到SQLite数据库中
class UsageDataMigrationService {
    private let usageDatabase: UsageStatisticsDatabase
    private let jsonlParser: JSONLParser
    private let streamingParser: StreamingJSONLParser
    private let useStreamingParser: Bool
    
    init(usageDatabase: UsageStatisticsDatabase, useStreamingParser: Bool = true) {
        self.usageDatabase = usageDatabase
        self.jsonlParser = JSONLParser()
        self.streamingParser = StreamingJSONLParser(
            batchSize: 2000,
            maxConcurrentFiles: 8,
            streamBufferSize: 128 * 1024
        )
        self.useStreamingParser = useStreamingParser
    }
    
    /// 执行完整的数据迁移
    /// - Returns: 迁移结果统计
    func performFullMigration() async throws -> MigrationResult {
        let startTime = Date()
        print("🚀 开始使用统计数据迁移...")
        
        // 1. 获取Claude项目目录
        let claudeDirectory = try getClaudeDirectory()
        let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
        
        guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
            throw MigrationError.projectsDirectoryNotFound(projectsDirectory.path)
        }
        
        print("📁 Claude项目目录: \(projectsDirectory.path)")
        
        // 2. 扫描所有JSONL文件
        let jsonlFiles = try await scanJSONLFiles(in: projectsDirectory)
        print("📄 找到 \(jsonlFiles.count) 个JSONL文件")
        
        if jsonlFiles.isEmpty {
            return MigrationResult(
                totalFiles: 0,
                processedFiles: 0,
                totalEntries: 0,
                insertedEntries: 0,
                skippedFiles: 0,
                errorFiles: 0,
                duration: Date().timeIntervalSince(startTime)
            )
        }
        
        // 3. 批量处理文件并导入数据
        let result = try await processFilesAndImportData(files: jsonlFiles)
        
        // 4. 生成统计汇总数据
        try await generateStatisticsSummaries()
        
        let endTime = Date()
        let finalResult = MigrationResult(
            totalFiles: jsonlFiles.count,
            processedFiles: result.processedFiles,
            totalEntries: result.totalEntries,
            insertedEntries: result.insertedEntries,
            skippedFiles: result.skippedFiles,
            errorFiles: result.errorFiles,
            duration: endTime.timeIntervalSince(startTime)
        )
        
        print("✅ 数据迁移完成")
        print("📊 迁移统计: \(finalResult.summary)")
        
        return finalResult
    }
    
    /// 增量迁移（只处理新的或修改过的文件）
    func performIncrementalMigration() async throws -> MigrationResult {
        let startTime = Date()
        print("🔄 开始增量数据迁移...")
        
        let claudeDirectory = try getClaudeDirectory()
        let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
        
        guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
            throw MigrationError.projectsDirectoryNotFound(projectsDirectory.path)
        }
        
        // 扫描所有文件
        let allFiles = try await scanJSONLFiles(in: projectsDirectory)
        
        // 过滤出需要处理的文件
        var filesToProcess: [URL] = []
        for fileURL in allFiles {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            
            if try usageDatabase.shouldProcessFile(fileURL, currentModified: modificationDate) {
                filesToProcess.append(fileURL)
            }
        }
        
        print("📄 需要处理 \(filesToProcess.count)/\(allFiles.count) 个文件")
        
        if filesToProcess.isEmpty {
            return MigrationResult(
                totalFiles: allFiles.count,
                processedFiles: 0,
                totalEntries: 0,
                insertedEntries: 0,
                skippedFiles: allFiles.count - filesToProcess.count,
                errorFiles: 0,
                duration: Date().timeIntervalSince(startTime)
            )
        }
        
        // 处理需要更新的文件
        let result = try await processFilesAndImportData(files: filesToProcess)
        
        // 更新统计汇总
        try await generateStatisticsSummaries()
        
        let endTime = Date()
        let finalResult = MigrationResult(
            totalFiles: allFiles.count,
            processedFiles: result.processedFiles,
            totalEntries: result.totalEntries,
            insertedEntries: result.insertedEntries,
            skippedFiles: allFiles.count - filesToProcess.count,
            errorFiles: result.errorFiles,
            duration: endTime.timeIntervalSince(startTime)
        )
        
        print("✅ 增量迁移完成")
        print("📊 迁移统计: \(finalResult.summary)")
        
        return finalResult
    }
    
    /// 扫描JSONL文件
    private func scanJSONLFiles(in directory: URL) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    var jsonlFiles: [URL] = []
                    let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                    
                    if let enumerator = FileManager.default.enumerator(
                        at: directory,
                        includingPropertiesForKeys: Array(resourceKeys),
                        options: [.skipsHiddenFiles],
                        errorHandler: { url, error in
                            print("⚠️ 访问文件失败: \(url.path) - \(error.localizedDescription)")
                            return true
                        }
                    ) {
                        for case let fileURL as URL in enumerator {
                            do {
                                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                                
                                if let isDirectory = resourceValues.isDirectory, !isDirectory,
                                   let name = resourceValues.name, name.hasSuffix(".jsonl") {
                                    jsonlFiles.append(fileURL)
                                }
                            } catch {
                                print("⚠️ 获取文件属性失败: \(fileURL.path) - \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    // 按文件大小排序，小文件优先处理（更快看到进度）
                    jsonlFiles.sort { url1, url2 in
                        let size1 = (try? url1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                        let size2 = (try? url2.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                        return size1 < size2
                    }
                    
                    continuation.resume(returning: jsonlFiles)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 处理文件并导入数据
    private func processFilesAndImportData(files: [URL]) async throws -> ProcessingResult {
        var processedFiles = 0
        var totalEntries = 0
        var insertedEntries = 0
        var errorFiles = 0
        
        print("⏳ 开始处理 \(files.count) 个文件...")
        
        for (index, fileURL) in files.enumerated() {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let modificationDate = attributes[.modificationDate] as? Date ?? Date()
                
                print("📝 处理文件 (\(index + 1)/\(files.count)): \(fileURL.lastPathComponent)")
                
                // 记录文件处理开始
                try usageDatabase.recordFileProcessing(fileURL, fileSize: fileSize, lastModified: modificationDate)
                
                // 解析文件
                let entries = try await parseJSONLFile(fileURL)
                totalEntries += entries.count
                
                if !entries.isEmpty {
                    // 批量插入数据
                    let inserted = try usageDatabase.insertUsageEntries(entries)
                    insertedEntries += inserted
                    
                    print("✅ 文件 \(fileURL.lastPathComponent): 解析 \(entries.count) 条，插入 \(inserted) 条")
                } else {
                    print("⚠️ 文件 \(fileURL.lastPathComponent): 无有效数据")
                }
                
                // 更新文件处理完成状态
                try usageDatabase.updateFileProcessingCompleted(fileURL, entryCount: entries.count)
                
                processedFiles += 1
                
                // 每处理10个文件输出一次进度
                if (index + 1) % 10 == 0 || index == files.count - 1 {
                    let progress = Double(index + 1) / Double(files.count) * 100
                    print("📈 进度: \(String(format: "%.1f", progress))% (\(index + 1)/\(files.count))")
                }
                
            } catch {
                errorFiles += 1
                print("❌ 处理文件失败: \(fileURL.lastPathComponent) - \(error.localizedDescription)")
            }
        }
        
        return ProcessingResult(
            processedFiles: processedFiles,
            totalEntries: totalEntries,
            insertedEntries: insertedEntries,
            skippedFiles: 0,
            errorFiles: errorFiles
        )
    }
    
    /// 解析单个JSONL文件
    private func parseJSONLFile(_ fileURL: URL) async throws -> [UsageEntry] {
        if useStreamingParser {
            return try await streamingParser.parseJSONLFiles(in: fileURL.deletingLastPathComponent())
                .filter { extractProjectPath(from: fileURL) == $0.projectPath }
        } else {
            return try await jsonlParser.parseJSONLFiles(in: fileURL.deletingLastPathComponent())
                .filter { extractProjectPath(from: fileURL) == $0.projectPath }
        }
    }
    
    /// 从文件路径提取项目路径
    private func extractProjectPath(from fileURL: URL) -> String {
        let pathComponents = fileURL.pathComponents
        
        if let projectsIndex = pathComponents.firstIndex(of: "projects"),
           projectsIndex + 1 < pathComponents.count {
            let projectComponents = Array(pathComponents[(projectsIndex + 1)...])
            let directoryComponents = projectComponents.dropLast()
            
            if !directoryComponents.isEmpty {
                return "/" + directoryComponents.joined(separator: "/")
            }
        }
        
        return fileURL.deletingLastPathComponent().path
    }
    
    /// 生成统计汇总数据
    private func generateStatisticsSummaries() async throws {
        print("📊 生成统计汇总数据...")
        try usageDatabase.updateStatisticsSummaries()
        print("✅ 统计汇总数据生成完成")
    }
    
    /// 测试数据库插入功能
    func testDatabaseInsertion() async throws -> TestResult {
        print("🧪 开始测试数据库插入功能...")
        
        // 创建测试数据
        let testEntries = createTestUsageEntries()
        print("📝 创建了 \(testEntries.count) 条测试数据")
        
        // 插入测试数据
        let insertedCount = try usageDatabase.insertUsageEntries(testEntries)
        print("✅ 成功插入 \(insertedCount) 条测试数据")
        
        // 查询验证数据
        let queriedEntries = try usageDatabase.queryUsageEntries(limit: 10)
        print("🔍 查询到 \(queriedEntries.count) 条记录")
        
        // 生成统计汇总
        try usageDatabase.updateStatisticsSummaries()
        print("📊 统计汇总更新完成")
        
        // 获取统计数据
        let statistics = try usageDatabase.getUsageStatistics()
        
        let result = TestResult(
            insertedCount: insertedCount,
            queriedCount: queriedEntries.count,
            totalCost: statistics.totalCost,
            totalTokens: statistics.totalTokens,
            totalSessions: statistics.totalSessions,
            modelCount: statistics.byModel.count,
            projectCount: statistics.byProject.count
        )
        
        print("✅ 测试完成: \(result.summary)")
        return result
    }
    
    /// 创建测试数据
    private func createTestUsageEntries() -> [UsageEntry] {
        let testData = [
            (
                model: "claude-4-sonnet",
                inputTokens: 1000,
                outputTokens: 500,
                cacheCreationTokens: 200,
                cacheReadTokens: 100,
                sessionId: "test-session-1",
                projectPath: "/test/project1"
            ),
            (
                model: "claude-3.5-sonnet",
                inputTokens: 800,
                outputTokens: 300,
                cacheCreationTokens: 0,
                cacheReadTokens: 50,
                sessionId: "test-session-1",
                projectPath: "/test/project1"
            ),
            (
                model: "claude-4-opus",
                inputTokens: 1200,
                outputTokens: 800,
                cacheCreationTokens: 300,
                cacheReadTokens: 150,
                sessionId: "test-session-2",
                projectPath: "/test/project2"
            ),
            (
                model: "claude-4-sonnet",
                inputTokens: 600,
                outputTokens: 400,
                cacheCreationTokens: 100,
                cacheReadTokens: 80,
                sessionId: "test-session-2",
                projectPath: "/test/project2"
            ),
            (
                model: "claude-3-haiku",
                inputTokens: 400,
                outputTokens: 200,
                cacheCreationTokens: 0,
                cacheReadTokens: 20,
                sessionId: "test-session-3",
                projectPath: "/test/project3"
            )
        ]
        
        let formatter = ISO8601DateFormatter()
        let baseDate = Date()
        
        return testData.enumerated().map { index, data in
            let timestamp = formatter.string(from: baseDate.addingTimeInterval(TimeInterval(index * -3600))) // 每小时间隔
            let cost = PricingModel.shared.calculateCost(
                model: data.model,
                inputTokens: data.inputTokens,
                outputTokens: data.outputTokens,
                cacheCreationTokens: data.cacheCreationTokens,
                cacheReadTokens: data.cacheReadTokens
            )
            
            return UsageEntry(
                timestamp: timestamp,
                model: data.model,
                inputTokens: data.inputTokens,
                outputTokens: data.outputTokens,
                cacheCreationTokens: data.cacheCreationTokens,
                cacheReadTokens: data.cacheReadTokens,
                cost: cost,
                sessionId: data.sessionId,
                projectPath: data.projectPath,
                requestId: "test-request-\(index + 1)",
                messageId: "test-message-\(index + 1)",
                messageType: "assistant",
                sourceFile: "migration_test_data"
            )
        }
    }
    
    /// 获取Claude目录
    private func getClaudeDirectory() throws -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let claudeDirectory = homeDirectory.appendingPathComponent(".claude")
        
        guard FileManager.default.fileExists(atPath: claudeDirectory.path) else {
            throw MigrationError.claudeDirectoryNotFound(claudeDirectory.path)
        }
        
        return claudeDirectory
    }
}

// MARK: - 数据结构

/// 测试结果
struct TestResult {
    let insertedCount: Int
    let queriedCount: Int
    let totalCost: Double
    let totalTokens: Int
    let totalSessions: Int
    let modelCount: Int
    let projectCount: Int
    
    var summary: String {
        return """
        插入: \(insertedCount) 条, 查询: \(queriedCount) 条
        总成本: $\(String(format: "%.6f", totalCost)), 总Token: \(totalTokens)
        会话数: \(totalSessions), 模型数: \(modelCount), 项目数: \(projectCount)
        """
    }
    
    var isSuccessful: Bool {
        return insertedCount > 0 && queriedCount > 0 && totalTokens > 0
    }
}

/// 迁移结果
struct MigrationResult {
    let totalFiles: Int
    let processedFiles: Int
    let totalEntries: Int
    let insertedEntries: Int
    let skippedFiles: Int
    let errorFiles: Int
    let duration: TimeInterval
    
    var summary: String {
        return """
        总文件: \(totalFiles), 处理: \(processedFiles), 跳过: \(skippedFiles), 错误: \(errorFiles)
        总记录: \(totalEntries), 插入: \(insertedEntries)
        耗时: \(String(format: "%.2f", duration))秒
        """
    }
    
    var isSuccessful: Bool {
        return errorFiles == 0 && processedFiles > 0
    }
}

/// 处理结果（内部使用）
private struct ProcessingResult {
    let processedFiles: Int
    let totalEntries: Int
    let insertedEntries: Int
    let skippedFiles: Int
    let errorFiles: Int
}

/// 迁移错误类型
enum MigrationError: Error, LocalizedError {
    case claudeDirectoryNotFound(String)
    case projectsDirectoryNotFound(String)
    case parsingFailed(String)
    case databaseError(String)
    
    var errorDescription: String? {
        switch self {
        case .claudeDirectoryNotFound(let path):
            return "Claude目录不存在: \(path)"
        case .projectsDirectoryNotFound(let path):
            return "Projects目录不存在: \(path)"
        case .parsingFailed(let reason):
            return "解析失败: \(reason)"
        case .databaseError(let reason):
            return "数据库错误: \(reason)"
        }
    }
}