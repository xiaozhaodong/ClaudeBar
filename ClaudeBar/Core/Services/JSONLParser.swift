import Foundation

/// JSONL 文件解析器
/// 负责解析 ~/.claude/projects 目录下的 JSONL 文件并提取使用统计数据
class JSONLParser {
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
    }
    
    /// 解析指定目录下的所有 JSONL 文件
    /// - Parameters:
    ///   - projectsDirectory: projects 目录路径
    ///   - startDate: 开始日期过滤（可选）
    ///   - endDate: 结束日期过滤（可选）
    /// - Returns: 解析出的使用记录数组
    /// - Throws: 解析过程中的错误
    func parseJSONLFiles(
        in projectsDirectory: URL,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [UsageEntry] {
        Logger.shared.info("开始解析 JSONL 文件，目录: \(projectsDirectory.path)")
        
        let jsonlFiles = try await findJSONLFiles(in: projectsDirectory)
        Logger.shared.info("找到 \(jsonlFiles.count) 个 JSONL 文件")
        
        var allEntries: [UsageEntry] = []
        var processedFiles = 0
        
        for fileURL in jsonlFiles {
            do {
                let entries = try await parseJSONLFile(
                    at: fileURL,
                    startDate: startDate,
                    endDate: endDate
                )
                allEntries.append(contentsOf: entries)
                processedFiles += 1
                
                if processedFiles % 10 == 0 {
                    Logger.shared.info("已处理 \(processedFiles)/\(jsonlFiles.count) 个文件")
                }
            } catch {
                Logger.shared.warning("解析文件失败: \(fileURL.path) - \(error.localizedDescription)")
                // 继续处理其他文件，不因单个文件失败而中断
            }
        }
        
        Logger.shared.info("解析完成，共获取 \(allEntries.count) 条使用记录")
        return allEntries
    }
    
    /// 查找指定目录下的所有 JSONL 文件
    private func findJSONLFiles(in directory: URL) async throws -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else {
            throw UsageStatisticsError.fileAccessDenied(directory.path)
        }
        
        var jsonlFiles: [URL] = []
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
        
        // 使用递归枚举器遍历所有子目录
        if let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                Logger.shared.warning("访问文件失败: \(url.path) - \(error.localizedDescription)")
                return true // 继续枚举
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
                    Logger.shared.warning("获取文件属性失败: \(fileURL.path) - \(error.localizedDescription)")
                }
            }
        }
        
        return jsonlFiles
    }
    
    /// 解析单个 JSONL 文件
    private func parseJSONLFile(
        at fileURL: URL,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [UsageEntry] {
        let data = try Data(contentsOf: fileURL)
        let content = String(data: data, encoding: .utf8) ?? ""
        
        // 从文件路径中提取项目路径
        let projectPath = extractProjectPath(from: fileURL)
        
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var entries: [UsageEntry] = []
        var validLines = 0
        var skippedLines = 0
        
        for (lineNumber, line) in lines.enumerated() {
            do {
                // 解析 JSON 行 - 支持更多格式变体
                let jsonData = line.data(using: .utf8) ?? Data()
                
                // 尝试多种解析策略，参考 ccusage 的容错机制
                var rawEntry: RawJSONLEntry?
                
                // 第一次尝试：标准解析
                do {
                    rawEntry = try decoder.decode(RawJSONLEntry.self, from: jsonData)
                } catch {
                    // 第二次尝试：宽松解析 - 忽略未知字段
                    let lenientDecoder = JSONDecoder()
                    lenientDecoder.dateDecodingStrategy = .iso8601
                    do {
                        rawEntry = try lenientDecoder.decode(RawJSONLEntry.self, from: jsonData)
                    } catch {
                        // 第三次尝试：解析为通用 JSON 对象后手动构建
                        if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            rawEntry = parseFromDictionary(jsonObject)
                        }
                    }
                }
                
                // 转换为标准使用记录
                if let entry = rawEntry?.toUsageEntry(projectPath: projectPath, sourceFile: fileURL.lastPathComponent) {
                    // 应用日期过滤
                    if entry.isInDateRange(startDate: startDate, endDate: endDate) {
                        entries.append(entry)
                        validLines += 1
                    } else {
                        skippedLines += 1
                    }
                } else {
                    skippedLines += 1
                }
            } catch {
                // 记录解析失败的行，但不中断整个文件的处理
                Logger.shared.debug("解析第 \(lineNumber + 1) 行失败: \(error.localizedDescription)")
                skippedLines += 1
            }
        }
        
        Logger.shared.debug("文件 \(fileURL.lastPathComponent): 有效记录 \(validLines)，跳过 \(skippedLines)")
        return entries
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
    
    /// 验证 JSONL 文件格式
    /// - Parameter fileURL: 文件 URL
    /// - Returns: 是否为有效的 JSONL 文件
    func validateJSONLFile(at fileURL: URL) async -> Bool {
        do {
            let data = try Data(contentsOf: fileURL)
            let content = String(data: data, encoding: .utf8) ?? ""
            
            let lines = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // 检查前几行是否为有效 JSON
            let samplesToCheck = min(5, lines.count)
            var validJsonCount = 0
            
            for i in 0..<samplesToCheck {
                let line = lines[i]
                if let jsonData = line.data(using: .utf8),
                   let _ = try? JSONSerialization.jsonObject(with: jsonData, options: []) {
                    validJsonCount += 1
                }
            }
            
            // 如果大部分样本行都是有效 JSON，则认为文件有效
            return Double(validJsonCount) / Double(samplesToCheck) >= 0.6
        } catch {
            Logger.shared.warning("验证 JSONL 文件失败: \(fileURL.path) - \(error.localizedDescription)")
            return false
        }
    }
    
    /// 获取文件的统计信息
    /// - Parameter fileURL: 文件 URL
    /// - Returns: 文件统计信息
    func getFileStats(for fileURL: URL) async -> JSONLFileStats? {
        do {
            let data = try Data(contentsOf: fileURL)
            let content = String(data: data, encoding: .utf8) ?? ""
            
            let lines = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let fileAttributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            let modificationDate = fileAttributes[.modificationDate] as? Date ?? Date()
            
            var validEntries = 0
            var assistantMessages = 0
            
            for line in lines.prefix(100) { // 只检查前100行以提高性能
                if let jsonData = line.data(using: .utf8),
                   let rawEntry = try? decoder.decode(RawJSONLEntry.self, from: jsonData) {
                    validEntries += 1
                    
                    let messageType = rawEntry.type ?? rawEntry.messageType ?? ""
                    if messageType == "assistant" {
                        assistantMessages += 1
                    }
                }
            }
            
            return JSONLFileStats(
                fileURL: fileURL,
                totalLines: lines.count,
                validEntries: validEntries,
                assistantMessages: assistantMessages,
                fileSize: fileSize,
                lastModified: modificationDate
            )
        } catch {
            Logger.shared.warning("获取文件统计失败: \(fileURL.path) - \(error.localizedDescription)")
            return nil
        }
    }
}

/// JSONL 文件统计信息
struct JSONLFileStats {
    let fileURL: URL
    let totalLines: Int
    let validEntries: Int
    let assistantMessages: Int
    let fileSize: Int64
    let lastModified: Date
    
    /// 文件名
    var fileName: String {
        return fileURL.lastPathComponent
    }
    
    /// 格式化的文件大小
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    /// 格式化的最后修改时间
    var formattedLastModified: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: lastModified)
    }
    
    /// 有效性百分比
    var validityPercentage: Double {
        guard totalLines > 0 else { return 0 }
        return Double(validEntries) / Double(totalLines) * 100
    }
}

// MARK: - 解析器扩展
extension JSONLParser {
    /// 从字典手动构建 RawJSONLEntry，支持更多数据格式变体
    private func parseFromDictionary(_ dict: [String: Any]) -> RawJSONLEntry? {
        // 提取基本字段，支持多种命名变体
        let type = extractString(from: dict, keys: ["type", "message_type", "messageType"])
        let messageType = extractString(from: dict, keys: ["message_type", "messageType", "type"])
        let model = extractString(from: dict, keys: ["model", "model_name", "modelName"])
        let timestamp = extractString(from: dict, keys: ["timestamp", "created_at", "createdAt", "date", "time"])
        let sessionId = extractString(from: dict, keys: ["sessionId", "session_id", "session"])  // 优先Claude Code格式
        // 分别提取两种 requestId 格式
        let requestId = extractString(from: dict, keys: ["requestId"])  // 无下划线版本
        let requestIdUnderscore = extractString(from: dict, keys: ["request_id"])  // 下划线版本
        let messageId = extractString(from: dict, keys: ["message_id", "messageId"])
        let uuid = extractString(from: dict, keys: ["uuid", "id"])
        
        // 尝试从message.id字段提取messageId（与测试脚本第294-301行一致）
        var finalMessageId = messageId
        if finalMessageId == nil || finalMessageId!.isEmpty {
            if let messageDict = dict["message"] as? [String: Any],
               let msgId = messageDict["id"] as? String {
                finalMessageId = msgId
            }
        }
        
        // 提取成本信息
        let cost = extractDouble(from: dict, keys: ["cost", "cost_usd", "costUSD", "price"])
        let costUSD = extractDouble(from: dict, keys: ["cost_usd", "costUSD", "cost"])
        
        // 解析使用数据 - 支持嵌套和平铺两种格式
        var usage: RawJSONLEntry.UsageData?
        
        // 尝试多种方式解析使用数据，参考 ccusage 的全面解析策略
        // 优先级1：从 usage 字段解析
        if let usageDict = dict["usage"] as? [String: Any] {
            usage = parseUsageData(from: usageDict)
        }
        // 优先级2：从 message.usage 字段解析
        else if let messageDict = dict["message"] as? [String: Any],
                let usageDict = messageDict["usage"] as? [String: Any] {
            usage = parseUsageData(from: usageDict)
        }
        // 优先级3：从顶级字段直接解析（有些格式可能直接包含 token 字段）
        else {
            usage = parseUsageData(from: dict)
        }
        
        // 如果还是没有使用数据，但有成本信息，仍然保留这条记录
        // ccusage 可能会处理只有成本没有 token 详情的记录
        
        // 解析消息数据 - 添加对message.id的支持（测试脚本需要）
        var message: RawJSONLEntry.MessageData?
        if let messageDict = dict["message"] as? [String: Any] {
            let messageUsage = parseUsageData(from: messageDict)
            let messageModel = extractString(from: messageDict, keys: ["model"])
            let messageId = extractString(from: messageDict, keys: ["id"])  // 提取message.id
            message = RawJSONLEntry.MessageData(usage: messageUsage, model: messageModel, id: messageId)
        }
        
        return RawJSONLEntry(
            type: type,
            messageType: messageType,
            model: model,
            usage: usage,
            message: message,
            cost: cost,
            costUSD: costUSD,
            timestamp: timestamp,
            sessionId: sessionId,
            requestId: requestId,
            requestIdUnderscore: requestIdUnderscore,  // 添加下划线版本的 requestId
            messageId: finalMessageId,  // 使用处理后的messageId
            id: extractString(from: dict, keys: ["id"]),
            uuid: uuid,
            date: extractString(from: dict, keys: ["date"])
        )
    }
    
    /// 解析使用数据 - 更宽松的策略，参考 ccusage
    private func parseUsageData(from dict: [String: Any]) -> RawJSONLEntry.UsageData? {
        let inputTokens = extractInt(from: dict, keys: ["input_tokens", "inputTokens", "input", "in_tokens"])
        let outputTokens = extractInt(from: dict, keys: ["output_tokens", "outputTokens", "output", "out_tokens"])
        // 扩展缓存 token 字段支持，参考 ccusage 可能使用的所有变体
        let cacheCreationInputTokens = extractInt(from: dict, keys: [
            "cache_creation_input_tokens", "cacheCreationInputTokens",
            "cache_creation_tokens", "cacheCreationTokens",
            "cache_write_tokens", "cacheWriteTokens",
            "cache_write_input_tokens", "cacheWriteInputTokens"
        ])
        let cacheReadInputTokens = extractInt(from: dict, keys: [
            "cache_read_input_tokens", "cacheReadInputTokens", 
            "cache_read_tokens", "cacheReadTokens"
        ])
        let cacheCreationTokens = extractInt(from: dict, keys: [
            "cache_creation_tokens", "cacheCreationTokens",
            "cache_write_tokens", "cacheWriteTokens",
            "cache_write_input_tokens", "cacheWriteInputTokens"
        ])
        let cacheReadTokens = extractInt(from: dict, keys: [
            "cache_read_tokens", "cacheReadTokens"
        ])
        
        // 更宽松的条件：只要有任何一个字段有值就创建对象
        // ccusage 可能处理部分字段缺失的情况
        let hasAnyTokenData = inputTokens != nil || outputTokens != nil || 
                             cacheCreationInputTokens != nil || cacheReadInputTokens != nil ||
                             cacheCreationTokens != nil || cacheReadTokens != nil
        
        if !hasAnyTokenData {
            return nil
        }
        
        return RawJSONLEntry.UsageData(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationInputTokens: cacheCreationInputTokens,
            cacheReadInputTokens: cacheReadInputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens
        )
    }
    
    /// 从字典中提取字符串值，支持多个可能的键名
    private func extractString(from dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }
    
    /// 从字典中提取整数值，支持多个可能的键名  
    private func extractInt(from dict: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dict[key] as? Int {
                return value
            } else if let value = dict[key] as? Double {
                return Int(value)
            } else if let value = dict[key] as? String, let intValue = Int(value) {
                return intValue
            }
        }
        return nil
    }
    
    /// 从字典中提取浮点数值，支持多个可能的键名
    private func extractDouble(from dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dict[key] as? Double {
                return value
            } else if let value = dict[key] as? Int {
                return Double(value)
            } else if let value = dict[key] as? String, let doubleValue = Double(value) {
                return doubleValue
            }
        }
        return nil
    }
}