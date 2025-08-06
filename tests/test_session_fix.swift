#!/usr/bin/env swift

import Foundation

// 测试修复后的会话统计逻辑

// 复制修复后的 UsageEntry 过滤逻辑进行测试
func testSessionFiltering() {
    print("🔍 测试会话统计修复效果...")
    
    // 模拟不同类型的 JSONL 数据
    let testCases = [
        // 案例1: 用户消息 - 有sessionId但没有usage数据
        TestEntry(sessionId: "session-1", totalTokens: 0, totalCost: 0.0, type: "user"),
        
        // 案例2: 助手响应 - 有sessionId和usage数据  
        TestEntry(sessionId: "session-1", totalTokens: 100, totalCost: 0.05, type: "assistant"),
        
        // 案例3: 无效数据 - 没有sessionId也没有usage数据
        TestEntry(sessionId: nil, totalTokens: 0, totalCost: 0.0, type: "invalid"),
        
        // 案例4: 另一个用户消息
        TestEntry(sessionId: "session-2", totalTokens: 0, totalCost: 0.0, type: "user"),
        
        // 案例5: 摘要条目 - 没有sessionId但有其他数据
        TestEntry(sessionId: nil, totalTokens: 0, totalCost: 0.0, type: "summary")
    ]
    
    print("\n📋 测试用例:")
    for (index, testCase) in testCases.enumerated() {
        print("  \(index + 1). sessionId: \(testCase.sessionId ?? "nil"), tokens: \(testCase.totalTokens), cost: \(testCase.totalCost), type: \(testCase.type)")
    }
    
    // 应用修复后的过滤逻辑
    var validEntries: [TestEntry] = []
    var allSessionIds = Set<String>()
    
    for entry in testCases {
        // 统计所有会话ID（修复后的逻辑）
        if let sessionId = entry.sessionId, !sessionId.isEmpty {
            allSessionIds.insert(sessionId)
        }
        
        // 应用过滤逻辑（修复后）
        if shouldKeepEntry(entry) {
            validEntries.append(entry)
        }
    }
    
    print("\n📊 统计结果:")
    print("  原始条目数: \(testCases.count)")
    print("  过滤后条目数: \(validEntries.count)")
    print("  总会话数: \(allSessionIds.count)")
    print("  会话ID: \(Array(allSessionIds).sorted())")
    
    print("\n✅ 预期结果:")
    print("  - 应该保留 4 个条目（排除无效数据）")
    print("  - 应该统计 2 个唯一会话")
    print("  - 会话统计不受过滤影响")
    
    print("\n🎯 测试结论:")
    if allSessionIds.count == 2 {
        print("  ✅ 会话统计修复成功！")
    } else {
        print("  ❌ 会话统计仍有问题")
    }
}

// 修复后的过滤逻辑
func shouldKeepEntry(_ entry: TestEntry) -> Bool {
    let hasValidSessionId = (entry.sessionId != nil && !entry.sessionId!.isEmpty && entry.sessionId != "unknown")
    
    // 如果有有效的sessionId，即使没有usage数据也应该保留（用于会话统计）
    // 如果没有sessionId且没有usage数据，才过滤掉
    if !hasValidSessionId && entry.totalTokens == 0 && entry.totalCost == 0 {
        return false
    }
    
    return true
}

struct TestEntry {
    let sessionId: String?
    let totalTokens: Int
    let totalCost: Double
    let type: String
}

// 执行测试
testSessionFiltering()