#!/usr/bin/env swift

import Foundation

// MARK: - 数据模型（与项目保持一致）

struct SingleFileUsageEntry {
    let timestamp: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Double
    let sessionId: String
    let requestId: String?
    let messageId: String?
    let messageType: String
    
    var totalTokens: Int {
        return inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
}

// MARK: - JSONL原始数据模型（用于解析）

struct RawJSONLEntry: Codable {
    let type: String?
    let messageType: String?
    let model: String?
    let usage: UsageData?
    let message: MessageData?
    let cost: Double?
    let costUSD: Double?
    let timestamp: String?
    let sessionId: String?
    let requestId: String?
    let requestIdUnderscore: String?
    let messageId: String?
    let id: String?
    let uuid: String?
    let date: String?
    
    private enum CodingKeys: String, CodingKey {
        case type
        case messageType = "message_type"
        case model
        case usage
        case message
        case cost
        case costUSD
        case timestamp
        case sessionId = "sessionId"
        case requestId
        case requestIdUnderscore = "request_id"
        case messageId = "message_id"
        case id
        case uuid
        case date
    }
    
    struct UsageData: Codable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?
        let cacheCreationTokens: Int?
        let cacheReadTokens: Int?
        
        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case cacheCreationTokens = "cache_creation_tokens"
            case cacheReadTokens = "cache_read_tokens"
        }
        
        var effectiveCacheCreationTokens: Int {
            return cacheCreationInputTokens ?? cacheCreationTokens ?? 0
        }
        
        var effectiveCacheReadTokens: Int {
            return cacheReadInputTokens ?? cacheReadTokens ?? 0
        }
    }
    
    struct MessageData: Codable {
        let usage: UsageData?
        let model: String?
        let id: String?
    }
    
    /// 转换为标准的使用记录
    func toUsageEntry() -> SingleFileUsageEntry? {
        let messageType = type ?? self.messageType ?? ""
        let usageData = usage ?? message?.usage
        
        // 计算总量用于过滤判断
        let totalTokens = (usageData?.inputTokens ?? 0) + 
                         (usageData?.outputTokens ?? 0) + 
                         (usageData?.effectiveCacheCreationTokens ?? 0) + 
                         (usageData?.effectiveCacheReadTokens ?? 0)
        let totalCost = cost ?? costUSD ?? 0
        
        // 只处理有usage数据或cost数据的记录
        if totalTokens == 0 && totalCost == 0 {
            return nil
        }
        
        // 获取模型名称
        let modelName = model ?? message?.model ?? ""
        
        // 过滤掉无效的模型名称
        if modelName.isEmpty || modelName == "unknown" || modelName == "<synthetic>" {
            return nil
        }
        
        // 提取token数据
        let inputTokens = usageData?.inputTokens ?? 0
        let outputTokens = usageData?.outputTokens ?? 0
        let cacheCreationTokens = usageData?.effectiveCacheCreationTokens ?? 0
        let cacheReadTokens = usageData?.effectiveCacheReadTokens ?? 0
        
        // 成本计算：使用项目的PricingModel逻辑
        let calculatedCost = calculateCostUsingProjectPricingModel(
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens
        )
        
        // ID提取逻辑
        let extractedRequestId = requestId ?? requestIdUnderscore ?? messageId
        let extractedMessageId = messageId ?? message?.id
        
        // 时间戳处理
        let finalTimestamp = timestamp ?? date ?? formatCurrentDateToISO()
        
        return SingleFileUsageEntry(
            timestamp: finalTimestamp,
            model: modelName,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cost: calculatedCost,
            sessionId: sessionId ?? "unknown",
            requestId: extractedRequestId,
            messageId: extractedMessageId,
            messageType: messageType
        )
    }
    
    private func formatCurrentDateToISO() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
    
    /// 使用项目PricingModel的成本计算方法
    private func calculateCostUsingProjectPricingModel(model: String, inputTokens: Int, outputTokens: Int,
                                                      cacheCreationTokens: Int, cacheReadTokens: Int) -> Double {
        // 使用与项目PricingModel.swift完全一致的定价表
        let pricing: [String: (input: Double, output: Double, cacheWrite: Double, cacheRead: Double)] = [
            // Claude 4 系列
            "claude-4-opus": (15.0, 75.0, 18.75, 1.5),
            "claude-4-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-4-haiku": (1.0, 5.0, 1.25, 0.1),
            // 别名映射
            "sonnet-4": (3.0, 15.0, 3.75, 0.3),
            "opus-4": (15.0, 75.0, 18.75, 1.5),
            "haiku-4": (1.0, 5.0, 1.25, 0.1),
            // Claude 3.5 系列
            "claude-3-5-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-3.5-sonnet": (3.0, 15.0, 3.75, 0.3),
            // Claude 3 系列
            "claude-3-opus": (15.0, 75.0, 18.75, 1.5),
            "claude-3-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-3-haiku": (0.25, 1.25, 0.3, 0.03),
            // Gemini 模型
            "gemini-2.5-pro": (1.25, 10.0, 0.31, 0.25)
        ]

        // 模型名称规范化
        let normalizedModel = normalizeModelNameForPricing(model)
        let modelPricing = pricing[normalizedModel]

        guard let pricingInfo = modelPricing else {
            return 0.0
        }

        // 计算成本
        let inputCost = Double(inputTokens) / 1_000_000 * pricingInfo.input
        let outputCost = Double(outputTokens) / 1_000_000 * pricingInfo.output
        let cacheWriteCost = Double(cacheCreationTokens) / 1_000_000 * pricingInfo.cacheWrite
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * pricingInfo.cacheRead

        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }
    
    /// 模型名称规范化
    private func normalizeModelNameForPricing(_ model: String) -> String {
        // 直接返回原始模型名，如果在定价表中有精确匹配
        let basePricing = [
            "claude-4-opus", "claude-4-sonnet", "claude-4-haiku",
            "sonnet-4", "opus-4", "haiku-4",
            "claude-3-5-sonnet", "claude-3.5-sonnet",
            "claude-3-opus", "claude-3-sonnet", "claude-3-haiku",
            "gemini-2.5-pro"
        ]

        if basePricing.contains(model) {
            return model
        }

        // 标准化模型名称
        let normalized = model.lowercased().replacingOccurrences(of: "-", with: "")

        // 模型映射表
        let mappings: [String: String] = [
            // Claude 4 变体
            "claude4opus": "claude-4-opus",
            "claude4sonnet": "claude-4-sonnet",
            "claude4haiku": "claude-4-haiku",
            "claudeopus4": "claude-4-opus",
            "claudesonnet4": "claude-4-sonnet",
            "claudehaiku4": "claude-4-haiku",
            // 具体版本号映射
            "claudesonnet420250514": "claude-4-sonnet",
            "claudeopus420250514": "claude-4-opus",
            "claudehaiku420250514": "claude-4-haiku",
            // 简化命名变体
            "opus4": "claude-4-opus",
            "sonnet4": "claude-4-sonnet",
            "haiku4": "claude-4-haiku",
            // Claude 3.5 变体
            "claude3.5sonnet": "claude-3-5-sonnet",
            "claude35sonnet": "claude-3-5-sonnet",
            "claude3sonnet35": "claude-3-5-sonnet",
            "claudesonnet35": "claude-3-5-sonnet",
            // Claude 3 变体
            "claude3opus": "claude-3-opus",
            "claude3sonnet": "claude-3-sonnet",
            "claude3haiku": "claude-3-haiku",
            "claudeopus3": "claude-3-opus",
            "claudesonnet3": "claude-3-sonnet",
            "claudehaiku3": "claude-3-haiku",
            // Gemini 模型
            "gemini2.5pro": "gemini-2.5-pro",
            "gemini25pro": "gemini-2.5-pro"
        ]

        if let mapped = mappings[normalized] {
            return mapped
        }

        // 智能匹配
        if model.contains("opus") {
            if model.contains("4") {
                return "claude-4-opus"
            } else if model.contains("3") {
                return "claude-3-opus"
            }
        } else if model.contains("sonnet") {
            if model.contains("4") {
                return "claude-4-sonnet"
            } else if model.contains("3.5") || model.contains("35") {
                return "claude-3-5-sonnet"
            } else if model.contains("3") {
                return "claude-3-sonnet"
            }
        } else if model.contains("haiku") {
            if model.contains("4") {
                return "claude-4-haiku"
            } else if model.contains("3") {
                return "claude-3-haiku"
            }
        }

        return normalized
    }
}

// MARK: - 成本统计分析器

class SingleFileCostAnalyzer {
    private let decoder = JSONDecoder()
    
    func analyzeFile(at filePath: String, filterSessionId: Bool = true) throws {
        print("📄 开始分析文件: \(filePath)")
        print("🔧 SessionId过滤: \(filterSessionId ? "启用" : "禁用")")
        print("====================================")
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw AnalysisError.fileNotFound(filePath)
        }
        
        // 从文件名提取期望的sessionId
        let fileURL = URL(fileURLWithPath: filePath)
        let expectedSessionId = extractSessionIdFromFileName(fileURL)
        print("📋 期望的SessionId: \(expectedSessionId ?? "未知")")
        
        // 解析文件
        let entries = try parseJSONLFile(fileURL, expectedSessionId: filterSessionId ? expectedSessionId : nil)
        
        // 统计分析
        try performCostAnalysis(entries: entries, expectedSessionId: expectedSessionId, filterEnabled: filterSessionId)
    }
    
    private func extractSessionIdFromFileName(_ fileURL: URL) -> String? {
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        // 简单检查是否是UUID格式
        if fileName.count >= 36 && fileName.contains("-") {
            return fileName
        }
        return nil
    }
    
    private func parseJSONLFile(_ fileURL: URL, expectedSessionId: String?) throws -> [SingleFileUsageEntry] {
        let data = try Data(contentsOf: fileURL)
        let content = String(data: data, encoding: .utf8) ?? ""
        
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var entries: [SingleFileUsageEntry] = []
        var validLines = 0
        var skippedLines = 0
        var sessionIdMismatches = 0
        var totalLines = lines.count
        
        print("\n🔍 开始解析 \(totalLines) 行数据...")
        
        for (lineNumber, line) in lines.enumerated() {
            do {
                let jsonData = line.data(using: .utf8) ?? Data()
                let rawEntry = try decoder.decode(RawJSONLEntry.self, from: jsonData)
                
                if let entry = rawEntry.toUsageEntry() {
                    // 检查sessionId是否匹配（这是修复的关键部分）
                    if let expectedSessionId = expectedSessionId,
                       entry.sessionId != expectedSessionId {
                        sessionIdMismatches += 1
                        print("⚠️  行 \(lineNumber + 1): SessionId不匹配，期望 \(expectedSessionId)，实际 \(entry.sessionId)")
                        continue
                    }
                    
                    entries.append(entry)
                    validLines += 1
                } else {
                    skippedLines += 1
                }
                
            } catch {
                skippedLines += 1
                print("❌ 行 \(lineNumber + 1): 解析失败 - \(error.localizedDescription)")
            }
        }
        
        print("\n📊 解析结果:")
        print("   总行数: \(totalLines)")
        print("   有效记录: \(validLines)")
        print("   跳过行数: \(skippedLines)")
        print("   SessionId不匹配: \(sessionIdMismatches)")
        
        return entries
    }
    
    private func performCostAnalysis(entries: [SingleFileUsageEntry], expectedSessionId: String?, filterEnabled: Bool) throws {
        guard !entries.isEmpty else {
            print("\n❌ 没有找到有效的使用记录")
            return
        }
        
        print("\n💰 成本分析报告")
        print("====================================")
        
        // 基础统计
        let totalEntries = entries.count
        let uniqueSessionIds = Set(entries.map { $0.sessionId })
        let uniqueModels = Set(entries.map { $0.model })
        
        print("📈 基础统计:")
        print("   记录总数: \(totalEntries)")
        print("   会话数量: \(uniqueSessionIds.count)")
        print("   使用模型: \(uniqueModels.count) 个")
        print("   模型列表: \(Array(uniqueModels).joined(separator: ", "))")
        
        // 显示所有的sessionId（如果有多个）
        if uniqueSessionIds.count > 1 {
            print("   所有SessionId:")
            for sessionId in uniqueSessionIds.sorted() {
                let count = entries.filter { $0.sessionId == sessionId }.count
                print("     - \(sessionId): \(count) 条记录")
            }
        }
        
        // Token统计
        let totalInputTokens = entries.reduce(0) { $0 + $1.inputTokens }
        let totalOutputTokens = entries.reduce(0) { $0 + $1.outputTokens }
        let totalCacheCreationTokens = entries.reduce(0) { $0 + $1.cacheCreationTokens }
        let totalCacheReadTokens = entries.reduce(0) { $0 + $1.cacheReadTokens }
        let totalTokens = totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
        
        print("\n🔢 Token统计:")
        print("   输入Token: \(formatNumber(totalInputTokens))")
        print("   输出Token: \(formatNumber(totalOutputTokens))")
        print("   缓存创建Token: \(formatNumber(totalCacheCreationTokens))")
        print("   缓存读取Token: \(formatNumber(totalCacheReadTokens))")
        print("   总Token: \(formatNumber(totalTokens))")
        
        // 成本统计
        let totalCost = entries.reduce(0) { $0 + $1.cost }
        
        // 按成本类型分解
        var inputCost = 0.0
        var outputCost = 0.0
        var cacheCreateCost = 0.0
        var cacheReadCost = 0.0
        
        for entry in entries {
            let modelPricing = getModelPricing(entry.model)
            inputCost += Double(entry.inputTokens) / 1_000_000 * modelPricing.input
            outputCost += Double(entry.outputTokens) / 1_000_000 * modelPricing.output
            cacheCreateCost += Double(entry.cacheCreationTokens) / 1_000_000 * modelPricing.cacheWrite
            cacheReadCost += Double(entry.cacheReadTokens) / 1_000_000 * modelPricing.cacheRead
        }
        
        print("\n💵 成本统计:")
        print("   输入成本: $\(String(format: "%.6f", inputCost))")
        print("   输出成本: $\(String(format: "%.6f", outputCost))")
        print("   缓存创建成本: $\(String(format: "%.6f", cacheCreateCost))")
        print("   缓存读取成本: $\(String(format: "%.6f", cacheReadCost))")
        print("   总成本: $\(String(format: "%.6f", totalCost))")
        
        // 按模型分组统计
        print("\n📊 按模型分组:")
        let modelGroups = Dictionary(grouping: entries, by: { $0.model })
        
        for (model, modelEntries) in modelGroups.sorted(by: { $0.key < $1.key }) {
            let modelCost = modelEntries.reduce(0) { $0 + $1.cost }
            let modelTokens = modelEntries.reduce(0) { $0 + $1.totalTokens }
            let modelCount = modelEntries.count
            
            print("   \(model):")
            print("     记录数: \(modelCount)")
            print("     Token: \(formatNumber(modelTokens))")
            print("     成本: $\(String(format: "%.6f", modelCost))")
        }
        
        // 时间分析
        print("\n⏰ 时间分析:")
        let timestamps = entries.compactMap { entry in
            ISO8601DateFormatter().date(from: entry.timestamp)
        }.sorted()
        
        if let firstTime = timestamps.first, let lastTime = timestamps.last {
            let duration = lastTime.timeIntervalSince(firstTime)
            print("   开始时间: \(formatDate(firstTime))")
            print("   结束时间: \(formatDate(lastTime))")
            print("   持续时间: \(formatDuration(duration))")
        }
        
        // SessionId验证
        if let expectedSessionId = expectedSessionId {
            let actualSessionIds = uniqueSessionIds
            if filterEnabled {
                if actualSessionIds.count == 1 && actualSessionIds.contains(expectedSessionId) {
                    print("\n✅ SessionId验证通过")
                } else {
                    print("\n⚠️  SessionId验证警告:")
                    print("   期望: \(expectedSessionId)")
                    print("   实际: \(Array(actualSessionIds).joined(separator: ", "))")
                }
            } else {
                print("\n📋 SessionId信息（未过滤）:")
                print("   文件期望: \(expectedSessionId)")
                print("   实际包含: \(Array(actualSessionIds).joined(separator: ", "))")
                if actualSessionIds.contains(expectedSessionId) {
                    let expectedCount = entries.filter { $0.sessionId == expectedSessionId }.count
                    print("   期望SessionId记录数: \(expectedCount)")
                    print("   其他SessionId记录数: \(totalEntries - expectedCount)")
                }
            }
        }
    }
    
    private func getModelPricing(_ model: String) -> (input: Double, output: Double, cacheWrite: Double, cacheRead: Double) {
        // 简化的定价表
        let pricing: [String: (input: Double, output: Double, cacheWrite: Double, cacheRead: Double)] = [
            "claude-4-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-4-opus": (15.0, 75.0, 18.75, 1.5),
            "claude-4-haiku": (1.0, 5.0, 1.25, 0.1),
            "claude-3-5-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-3.5-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-3-opus": (15.0, 75.0, 18.75, 1.5),
            "claude-3-sonnet": (3.0, 15.0, 3.75, 0.3),
            "claude-3-haiku": (0.25, 1.25, 0.3, 0.03),
            "gemini-2.5-pro": (1.25, 10.0, 0.31, 0.25)
        ]
        
        return pricing[model] ?? (0, 0, 0, 0)
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

// MARK: - 错误定义

enum AnalysisError: Error {
    case fileNotFound(String)
    case invalidFormat(String)
    
    var localizedDescription: String {
        switch self {
        case .fileNotFound(let path):
            return "文件不存在: \(path)"
        case .invalidFormat(let message):
            return "格式错误: \(message)"
        }
    }
}

// MARK: - 主程序入口

func main() {
    let arguments = CommandLine.arguments
    
    guard arguments.count > 1 else {
        print("使用方法: swift test_single_file_cost.swift <jsonl文件路径> [--no-filter]")
        print("示例: swift test_single_file_cost.swift /path/to/file.jsonl")
        print("不过滤: swift test_single_file_cost.swift /path/to/file.jsonl --no-filter")
        exit(1)
    }
    
    let filePath = arguments[1]
    let filterSessionId = !arguments.contains("--no-filter")
    
    do {
        let analyzer = SingleFileCostAnalyzer()
        try analyzer.analyzeFile(at: filePath, filterSessionId: filterSessionId)
        
        print("\n🎉 分析完成！")
        
    } catch {
        print("❌ 分析失败: \(error.localizedDescription)")
        exit(1)
    }
}

// 运行主程序
main()