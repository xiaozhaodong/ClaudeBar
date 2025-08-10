import Foundation

/// 定价模型 - 负责计算各种模型的使用成本
class PricingModel {
    static let shared = PricingModel()
    
    // 添加缓存以提高性能
    private var modelNameCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "com.claudebar.pricingmodel.cache", attributes: .concurrent)
    
    private init() {}
    
    /// 模型定价配置（每百万令牌的美元价格）
    /// 基于 2025 年 Anthropic API 定价
    private let pricing: [String: ModelPricing] = [
        // Claude 4 系列（新一代模型）
        "claude-4-opus": ModelPricing(
            input: 15.0,
            output: 75.0,
            cacheWrite: 18.75,
            cacheRead: 1.5
        ),
        "claude-4-sonnet": ModelPricing(
            input: 3.0,
            output: 15.0,
            cacheWrite: 3.75,
            cacheRead: 0.3
        ),
        "claude-4-haiku": ModelPricing(
            input: 1.0,
            output: 5.0,
            cacheWrite: 1.25,
            cacheRead: 0.1
        ),
        // 别名映射 - 简化版本
        "sonnet-4": ModelPricing(
            input: 3.0,
            output: 15.0,
            cacheWrite: 3.75,
            cacheRead: 0.3
        ),
        "opus-4": ModelPricing(
            input: 15.0,
            output: 75.0,
            cacheWrite: 18.75,
            cacheRead: 1.5
        ),
        "haiku-4": ModelPricing(
            input: 1.0,
            output: 5.0,
            cacheWrite: 1.25,
            cacheRead: 0.1
        ),
        // Claude 3.5 系列
        "claude-3-5-sonnet": ModelPricing(
            input: 3.0,
            output: 15.0,
            cacheWrite: 3.75,
            cacheRead: 0.3
        ),
        "claude-3.5-sonnet": ModelPricing(
            input: 3.0,
            output: 15.0,
            cacheWrite: 3.75,
            cacheRead: 0.3
        ),
        // Claude 3 系列
        "claude-3-opus": ModelPricing(
            input: 15.0,
            output: 75.0,
            cacheWrite: 18.75,
            cacheRead: 1.5
        ),
        "claude-3-sonnet": ModelPricing(
            input: 3.0,
            output: 15.0,
            cacheWrite: 3.75,
            cacheRead: 0.3
        ),
        "claude-3-haiku": ModelPricing(
            input: 0.25,
            output: 1.25,
            cacheWrite: 0.3,
            cacheRead: 0.03
        ),
        // Gemini 模型（基于 Google AI 官方定价，假设大部分提示 ≤ 200k tokens）
        "gemini-2.5-pro": ModelPricing(
            input: 1.25,
            output: 10.0,
            cacheWrite: 0.31,
            cacheRead: 0.25
        )
    ]
    
    /// 计算使用成本
    /// - Parameters:
    ///   - model: 模型名称
    ///   - inputTokens: 输入令牌数
    ///   - outputTokens: 输出令牌数
    ///   - cacheCreationTokens: 缓存创建令牌数
    ///   - cacheReadTokens: 缓存读取令牌数
    /// - Returns: 总成本（美元）
    /// Phase 4: 改进的成本计算方法
    func calculateCost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int
    ) -> Double {
        let modelKey = normalizeModelName(model)
        let totalTokens = inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
        
        guard let modelPricing = pricing[modelKey] else {
            // Phase 4: 改进：提供更详细的日志和统计
            print("❓ 未知模型定价: '\(model)' -> '\(modelKey)', tokens=\(totalTokens)")
            return 0.0
        }
        
        let inputCost = Double(inputTokens) / 1_000_000 * modelPricing.input
        let outputCost = Double(outputTokens) / 1_000_000 * modelPricing.output
        let cacheWriteCost = Double(cacheCreationTokens) / 1_000_000 * modelPricing.cacheWrite
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * modelPricing.cacheRead
        
        let totalCost = inputCost + outputCost + cacheWriteCost + cacheReadCost
        
        return totalCost
    }
    
    /// 获取模型的定价信息
    /// - Parameter model: 模型名称
    /// - Returns: 模型定价信息，如果未找到则返回 nil
    func getPricing(for model: String) -> ModelPricing? {
        let modelKey = normalizeModelName(model)
        return pricing[modelKey]
    }
    
    /// 获取所有支持的模型
    var supportedModels: [String] {
        return Array(pricing.keys)
    }
    
    /// 标准化模型名称以匹配定价表
    private func normalizeModelName(_ model: String) -> String {
        // 先检查缓存
        let cachedValue = cacheQueue.sync {
            return modelNameCache[model]
        }
        
        if let cached = cachedValue {
            return cached
        }
        
        // 执行标准化
        let normalized = performNormalization(model)
        
        // 存储到缓存
        cacheQueue.async(flags: .barrier) {
            self.modelNameCache[model] = normalized
        }
        
        return normalized
    }
    
    /// 实际执行模型名称标准化
    private func performNormalization(_ model: String) -> String {
        let normalized = model.lowercased().replacingOccurrences(of: "-", with: "")
        
        // 映射到定价表中的键 - 支持 ccusage 常见格式
        let mappings: [String: String] = [
            // Claude 4 变体（包含具体版本号）
            "claude4opus": "claude-4-opus",
            "claude4sonnet": "claude-4-sonnet",
            "claude4haiku": "claude-4-haiku",
            "claudeopus4": "claude-4-opus",
            "claudesonnet4": "claude-4-sonnet",
            "claudehaiku4": "claude-4-haiku",
            // 具体版本号映射（从实际数据中观察到的格式）
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
            // Gemini 模型（添加基本支持）
            "gemini2.5pro": "gemini-2.5-pro",
            "gemini25pro": "gemini-2.5-pro"
        ]
        
        if let mapped = mappings[normalized] {
            return mapped
        }
        
        // 直接匹配的情况
        if pricing.keys.contains(model) {
            return model
        }
        
        // 如果包含关键词，尝试智能匹配（参考 ccusage 的匹配策略）
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
    
    /// 格式化成本显示（与 ccusage 一致的精度）
    static func formatCost(_ cost: Double) -> String {
        return String(format: "$%.6f", cost)  // 提高精度以匹配 ccusage
    }
    
    /// 格式化成本显示（简化版本）
    static func formatCostSimple(_ cost: Double) -> String {
        if cost >= 1.0 {
            return String(format: "$%.2f", cost)
        } else if cost >= 0.01 {
            return String(format: "$%.2f", cost)
        } else {
            return String(format: "$%.6f", cost)  // 提高小数精度
        }
    }
    
    /// 获取模型的显示名称（与 ccusage 兼容）
    func getDisplayName(for model: String) -> String {
        let displayNames: [String: String] = [
            "claude-4-opus": "Claude 4 Opus",
            "claude-4-sonnet": "Claude 4 Sonnet",
            "claude-4-haiku": "Claude 4 Haiku",
            "claude-3-5-sonnet": "Claude 3.5 Sonnet",
            "claude-3-opus": "Claude 3 Opus",
            "claude-3-sonnet": "Claude 3 Sonnet",
            "claude-3-haiku": "Claude 3 Haiku"
        ]
        
        let normalizedModel = normalizeModelName(model)
        return displayNames[normalizedModel] ?? model
    }
}

/// 模型定价结构
struct ModelPricing {
    let input: Double        // 输入令牌价格（每百万令牌）
    let output: Double       // 输出令牌价格（每百万令牌）
    let cacheWrite: Double   // 缓存写入价格（每百万令牌）
    let cacheRead: Double    // 缓存读取价格（每百万令牌）
    
    /// 计算单次使用的总成本
    func calculateTotalCost(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int
    ) -> Double {
        let inputCost = Double(inputTokens) / 1_000_000 * input
        let outputCost = Double(outputTokens) / 1_000_000 * output
        let cacheWriteCost = Double(cacheCreationTokens) / 1_000_000 * cacheWrite
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * cacheRead
        
        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }
    
    /// 获取成本分解
    func getCostBreakdown(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int
    ) -> CostBreakdown {
        return CostBreakdown(
            inputCost: Double(inputTokens) / 1_000_000 * input,
            outputCost: Double(outputTokens) / 1_000_000 * output,
            cacheWriteCost: Double(cacheCreationTokens) / 1_000_000 * cacheWrite,
            cacheReadCost: Double(cacheReadTokens) / 1_000_000 * cacheRead
        )
    }
}

/// 成本分解结构
struct CostBreakdown {
    let inputCost: Double
    let outputCost: Double
    let cacheWriteCost: Double
    let cacheReadCost: Double
    
    var totalCost: Double {
        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }
    
    /// 格式化显示
    var formattedBreakdown: String {
        var components: [String] = []
        
        if inputCost > 0 {
            components.append("输入: \(PricingModel.formatCost(inputCost))")
        }
        if outputCost > 0 {
            components.append("输出: \(PricingModel.formatCost(outputCost))")
        }
        if cacheWriteCost > 0 {
            components.append("缓存写入: \(PricingModel.formatCost(cacheWriteCost))")
        }
        if cacheReadCost > 0 {
            components.append("缓存读取: \(PricingModel.formatCost(cacheReadCost))")
        }
        
        return components.joined(separator: " + ")
    }
}