#!/usr/bin/env swift

import Foundation

// 定价模型（与测试脚本一致）
struct ModelPricing {
    let input: Double
    let output: Double
    let cacheWrite: Double
    let cacheRead: Double
    
    func calculateCost(inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int) -> Double {
        let inputCost = Double(inputTokens) / 1_000_000 * input
        let outputCost = Double(outputTokens) / 1_000_000 * output
        let cacheWriteCost = Double(cacheCreationTokens) / 1_000_000 * cacheWrite
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * cacheRead
        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }
}

// 我们的定价表
let ourPricingTable: [String: ModelPricing] = [
    "claude-4-opus": ModelPricing(input: 15.0, output: 75.0, cacheWrite: 18.75, cacheRead: 1.5),
    "claude-4-sonnet": ModelPricing(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3),
    "claude-4-haiku": ModelPricing(input: 1.0, output: 5.0, cacheWrite: 1.25, cacheRead: 0.1),
    "claude-3-5-sonnet": ModelPricing(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3),
    "claude-3-opus": ModelPricing(input: 15.0, output: 75.0, cacheWrite: 18.75, cacheRead: 1.5),
    "claude-3-sonnet": ModelPricing(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3),
    "claude-3-haiku": ModelPricing(input: 0.25, output: 1.25, cacheWrite: 0.3, cacheRead: 0.03),
    "gemini-2.5-pro": ModelPricing(input: 2.5, output: 10.0, cacheWrite: 3.125, cacheRead: 0.25)
]

// ccusage 可能使用的定价表（基于官方文档）
let ccusagePricingTable: [String: ModelPricing] = [
    "claude-4-opus": ModelPricing(input: 15.0, output: 75.0, cacheWrite: 18.75, cacheRead: 1.5),
    "claude-4-sonnet": ModelPricing(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3),
    "claude-4-haiku": ModelPricing(input: 1.0, output: 5.0, cacheWrite: 1.25, cacheRead: 0.1),
    "claude-3-5-sonnet": ModelPricing(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3),
    "claude-3-opus": ModelPricing(input: 15.0, output: 75.0, cacheWrite: 18.75, cacheRead: 1.5),
    "claude-3-sonnet": ModelPricing(input: 3.0, output: 15.0, cacheWrite: 3.75, cacheRead: 0.3),
    "claude-3-haiku": ModelPricing(input: 0.25, output: 1.25, cacheWrite: 0.3, cacheRead: 0.03),
    // ccusage 可能对 Gemini 使用不同的定价
    "gemini-2.5-pro": ModelPricing(input: 2.5, output: 10.0, cacheWrite: 3.125, cacheRead: 0.25)
]

func normalizeModelName(_ model: String) -> String {
    let normalized = model.lowercased().replacingOccurrences(of: "-", with: "")
    
    let mappings: [String: String] = [
        "claudesonnet420250514": "claude-4-sonnet",
        "claudeopus420250514": "claude-4-opus",
        "claudehaiku420250514": "claude-4-haiku",
        "gemini2.5pro": "gemini-2.5-pro",
        "gemini25pro": "gemini-2.5-pro"
    ]
    
    if let mapped = mappings[normalized] {
        return mapped
    }
    
    if ourPricingTable.keys.contains(model) {
        return model
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
    } else if model.contains("gemini") && model.contains("2.5") {
        return "gemini-2.5-pro"
    }
    
    return normalized
}

func main() {
    print("🔍 成本差异分析 - 寻找 $0.80 差异的根源")
    print("=" * 60)
    
    // 首先获取我们的统计数据
    let projectsDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude")
        .appendingPathComponent("projects")
    
    let entries = parseAllJSONLFiles(in: projectsDirectory)
    let deduplicatedEntries = applyAggressiveDeduplication(entries: entries)
    
    print("📊 数据概览:")
    print("原始条目: \(entries.count)")
    print("去重后条目: \(deduplicatedEntries.count)")
    
    // 按模型分组分析成本
    var modelStats: [String: (count: Int, inputTokens: Int, outputTokens: Int, cacheCreate: Int, cacheRead: Int, ourCost: Double, ccusageCost: Double)] = [:]
    
    for entry in deduplicatedEntries {
        let normalizedModel = normalizeModelName(entry.model)
        
        let ourCost = calculateCost(model: entry.model, pricingTable: ourPricingTable, inputTokens: entry.inputTokens, outputTokens: entry.outputTokens, cacheCreationTokens: entry.cacheCreationTokens, cacheReadTokens: entry.cacheReadTokens)
        
        let ccusageCost = calculateCost(model: entry.model, pricingTable: ccusagePricingTable, inputTokens: entry.inputTokens, outputTokens: entry.outputTokens, cacheCreationTokens: entry.cacheCreationTokens, cacheReadTokens: entry.cacheReadTokens)
        
        if var stats = modelStats[normalizedModel] {
            stats.count += 1
            stats.inputTokens += entry.inputTokens
            stats.outputTokens += entry.outputTokens
            stats.cacheCreate += entry.cacheCreationTokens
            stats.cacheRead += entry.cacheReadTokens
            stats.ourCost += ourCost
            stats.ccusageCost += ccusageCost
            modelStats[normalizedModel] = stats
        } else {
            modelStats[normalizedModel] = (
                count: 1,
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens,
                cacheCreate: entry.cacheCreationTokens,
                cacheRead: entry.cacheReadTokens,
                ourCost: ourCost,
                ccusageCost: ccusageCost
            )
        }
    }
    
    print("\n📊 按模型分析成本差异:")
    print("模型".padding(toLength: 20, withPad: " ", startingAt: 0) + " | 条目数 | 我们的成本 | ccusage成本 | 差异")
    print("-" * 80)
    
    var totalOurCost = 0.0
    var totalCcusageCost = 0.0
    
    for (model, stats) in modelStats.sorted(by: { $0.key < $1.key }) {
        let diff = stats.ourCost - stats.ccusageCost
        totalOurCost += stats.ourCost
        totalCcusageCost += stats.ccusageCost
        
        print("\(model.padding(toLength: 20, withPad: " ", startingAt: 0)) | \(String(stats.count).padding(toLength: 6, withPad: " ", startingAt: 0)) | $\(String(format: "%.4f", stats.ourCost).padding(toLength: 9, withPad: " ", startingAt: 0)) | $\(String(format: "%.4f", stats.ccusageCost).padding(toLength: 10, withPad: " ", startingAt: 0)) | $\(String(format: "%.4f", diff))")
    }
    
    print("-" * 80)
    print("总计".padding(toLength: 20, withPad: " ", startingAt: 0) + " |        | $\(String(format: "%.4f", totalOurCost).padding(toLength: 9, withPad: " ", startingAt: 0)) | $\(String(format: "%.4f", totalCcusageCost).padding(toLength: 10, withPad: " ", startingAt: 0)) | $\(String(format: "%.4f", totalOurCost - totalCcusageCost))")
    
    print("\n🔍 详细分析:")
    print("我们的总成本: $\(String(format: "%.6f", totalOurCost))")
    print("ccusage 成本: $2880.98")
    print("实际差异: $\(String(format: "%.6f", totalOurCost - 2880.98))")
    
    // 检查是否有未知模型
    print("\n⚠️ 未知模型检查:")
    let unknownModels = Set(entries.map { $0.model }).subtracting(Set(ourPricingTable.keys.map { normalizeModelName($0) }))
    if unknownModels.isEmpty {
        print("✅ 所有模型都有定价信息")
    } else {
        print("❌ 发现未知模型: \(unknownModels)")
    }
    
    // 精度分析
    print("\n🔬 精度分析:")
    print("差异金额: $\(String(format: "%.6f", totalOurCost - 2880.98))")
    print("差异百分比: \(String(format: "%.6f", (totalOurCost - 2880.98) / 2880.98 * 100))%")
    
    if abs(totalOurCost - 2880.98) < 1.0 {
        print("✅ 差异小于 $1，属于正常范围")
        if abs(totalOurCost - 2880.98) < 0.1 {
            print("🎯 差异小于 $0.1，精度极高！")
        }
    }
}

// 简化的数据结构和解析函数
struct SimpleUsageEntry {
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let timestamp: String
    let sessionId: String
    let requestId: String?
    let messageId: String?
}

func parseAllJSONLFiles(in directory: URL) -> [SimpleUsageEntry] {
    // 这里使用简化版本，实际应该与测试脚本一致
    // 为了分析，我们假设已经有了数据
    return []
}

func applyAggressiveDeduplication(entries: [SimpleUsageEntry]) -> [SimpleUsageEntry] {
    // 简化版本
    return entries
}

func calculateCost(model: String, pricingTable: [String: ModelPricing], inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int) -> Double {
    let normalizedModel = normalizeModelName(model)
    guard let pricing = pricingTable[normalizedModel] else {
        return 0.0
    }
    return pricing.calculateCost(inputTokens: inputTokens, outputTokens: outputTokens, cacheCreationTokens: cacheCreationTokens, cacheReadTokens: cacheReadTokens)
}

main()
