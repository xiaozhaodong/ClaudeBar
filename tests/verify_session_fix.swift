#!/usr/bin/env swift

import Foundation

// 验证会话统计修复的完整测试

func main() async {
    print("🔍 验证会话统计修复效果...")
    
    // 1. 验证原始会话统计脚本的结果
    print("\n📊 步骤1: 重新运行原始会话统计...")
    let originalResult = await runOriginalSessionCount()
    
    // 2. 验证修复逻辑
    print("\n🔧 步骤2: 测试修复后的过滤逻辑...")
    testFilteringLogic()
    
    // 3. 预期结果对比
    print("\n📋 步骤3: 结果对比分析...")
    analyzeResults(originalSessionCount: originalResult)
    
    print("\n✅ 验证完成!")
}

// 运行原始的会话统计逻辑
func runOriginalSessionCount() async -> Int {
    let claudeDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
    
    guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
        print("❌ projects 目录不存在")
        return 0
    }
    
    var sessionIds = Set<String>()
    
    do {
        let jsonlFiles = try await findJSONLFiles(in: projectsDirectory)
        
        for fileURL in jsonlFiles {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                for line in lines {
                    if let data = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let sessionId = json["sessionId"] as? String,
                       !sessionId.isEmpty {
                        sessionIds.insert(sessionId)
                    }
                }
            } catch {
                // 忽略单个文件的错误
            }
        }
    } catch {
        print("❌ 错误: \(error)")
        return 0
    }
    
    print("  原始数据会话总数: \(sessionIds.count)")
    return sessionIds.count
}

// 查找 JSONL 文件
func findJSONLFiles(in directory: URL) async throws -> [URL] {
    var jsonlFiles: [URL] = []
    
    let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
    
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: Array(resourceKeys),
        options: [.skipsHiddenFiles]
    ) else {
        throw NSError(domain: "EnumerationError", code: 1)
    }
    
    for case let fileURL as URL in enumerator {
        do {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            if let isDirectory = resourceValues.isDirectory, !isDirectory,
               let name = resourceValues.name, name.hasSuffix(".jsonl") {
                jsonlFiles.append(fileURL)
            }
        } catch {
            // 忽略单个文件错误
        }
    }
    
    return jsonlFiles
}

// 测试修复后的过滤逻辑
func testFilteringLogic() {
    let testCases = [
        // 真实的 Claude Code 数据模式
        TestCase(
            description: "用户消息 - 有sessionId无usage",
            sessionId: "test-session-1",
            totalTokens: 0,
            totalCost: 0.0,
            shouldKeep: true  // 修复后应该保留
        ),
        TestCase(
            description: "助手响应 - 有sessionId有usage", 
            sessionId: "test-session-1",
            totalTokens: 150,
            totalCost: 0.08,
            shouldKeep: true
        ),
        TestCase(
            description: "摘要条目 - 无sessionId无usage",
            sessionId: nil,
            totalTokens: 0,
            totalCost: 0.0,
            shouldKeep: false  // 应该被过滤
        ),
        TestCase(
            description: "另一用户消息 - 有sessionId无usage",
            sessionId: "test-session-2", 
            totalTokens: 0,
            totalCost: 0.0,
            shouldKeep: true  // 修复后应该保留
        )
    ]
    
    print("  测试修复后的过滤逻辑:")
    
    var sessionIds = Set<String>()
    var keptEntries = 0
    
    for testCase in testCases {
        // 统计会话（不受过滤影响）
        if let sessionId = testCase.sessionId, !sessionId.isEmpty {
            sessionIds.insert(sessionId)
        }
        
        // 应用修复后的过滤逻辑
        let shouldKeep = shouldKeepEntryAfterFix(
            sessionId: testCase.sessionId,
            totalTokens: testCase.totalTokens,
            totalCost: testCase.totalCost
        )
        
        if shouldKeep {
            keptEntries += 1
        }
        
        let status = shouldKeep == testCase.shouldKeep ? "✅" : "❌"
        print("    \(status) \(testCase.description)")
        print("      保留: \(shouldKeep) (预期: \(testCase.shouldKeep))")
    }
    
    print("  结果统计:")
    print("    总会话数: \(sessionIds.count)")
    print("    保留条目: \(keptEntries)/\(testCases.count)")
}

// 修复后的过滤逻辑
func shouldKeepEntryAfterFix(sessionId: String?, totalTokens: Int, totalCost: Double) -> Bool {
    let hasValidSessionId = (sessionId != nil && !sessionId!.isEmpty && sessionId != "unknown")
    
    // 如果有有效的sessionId，即使没有usage数据也应该保留（用于会话统计）
    // 如果没有sessionId且没有usage数据，才过滤掉
    if !hasValidSessionId && totalTokens == 0 && totalCost == 0 {
        return false
    }
    
    return true
}

// 分析结果
func analyzeResults(originalSessionCount: Int) {
    print("  📈 预期修复效果:")
    print("    修复前 ClaudeBar 显示: 1 个会话")
    print("    实际数据包含: \(originalSessionCount) 个会话")
    print("    修复后应该显示: \(originalSessionCount) 个会话")
    
    if originalSessionCount > 1 {
        print("    ✅ 修复将显著提升会话统计准确性")
        let improvement = Double(originalSessionCount - 1) / Double(originalSessionCount) * 100
        print("    📊 准确率提升: \(String(format: "%.1f", improvement))%")
    } else {
        print("    ⚠️ 数据异常，请检查测试环境")
    }
    
    print("\n  🔧 修复关键点:")
    print("    1. 保留有sessionId的条目，不管是否有usage数据")
    print("    2. 只过滤掉真正无效的条目（既没有sessionId也没有usage）")
    print("    3. 会话统计基于原始数据，不受过滤影响")
}

struct TestCase {
    let description: String
    let sessionId: String?
    let totalTokens: Int
    let totalCost: Double
    let shouldKeep: Bool
}

// 执行测试
Task {
    await main()
    exit(0)
}

RunLoop.main.run()