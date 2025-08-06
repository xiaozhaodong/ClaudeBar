#!/usr/bin/env swift

import Foundation

// 调试会话解析问题 - 模拟 ClaudeBar 的完整解析流程

struct DebugSessionParsing {
    
    static func run() async {
        print("🔍 调试会话解析问题...")
        
        // 1. 检查原始数据
        await checkRawData()
        
        // 2. 模拟 JSONL 解析过程
        await simulateJSONLParsing()
        
        // 3. 模拟 UsageEntry 转换过程
        await simulateUsageEntryConversion()
        
        // 4. 模拟最终统计计算
        await simulateStatisticsCalculation()
    }
    
    // 检查原始数据
    static func checkRawData() async {
        print("\n📂 步骤1: 检查原始数据...")
        
        let claudeDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
        
        guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
            print("❌ projects 目录不存在")
            return
        }
        
        // 统计原始会话数
        var allSessionIds = Set<String>()
        var sampleEntries: [[String: Any]] = []
        
        do {
            let jsonlFiles = try await findJSONLFiles(in: projectsDirectory)
            print("  找到 \(jsonlFiles.count) 个 JSONL 文件")
            
            // 只处理前几个文件作为样本
            for fileURL in jsonlFiles.prefix(5) {
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let lines = content.components(separatedBy: .newlines)
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    
                    for line in lines.prefix(3) { // 每个文件只取前3行作为样本
                        if let data = line.data(using: .utf8),
                           let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            
                            if let sessionId = json["sessionId"] as? String, !sessionId.isEmpty {
                                allSessionIds.insert(sessionId)
                            }
                            
                            if sampleEntries.count < 10 {
                                sampleEntries.append(json)
                            }
                        }
                    }
                } catch {
                    print("  ⚠️ 读取文件失败: \(fileURL.lastPathComponent)")
                }
                
                if allSessionIds.count >= 10 { // 收集足够样本后停止
                    break
                }
            }
        } catch {
            print("❌ 错误: \(error)")
            return
        }
        
        print("  样本中的唯一会话数: \(allSessionIds.count)")
        print("  样本条目数: \(sampleEntries.count)")
        
        // 显示样本数据结构
        if let first = sampleEntries.first {
            print("  样本数据结构:")
            for key in Array(first.keys).prefix(10) {
                print("    \(key): \(type(of: first[key]))")
            }
        }
    }
    
    // 模拟 JSONL 解析过程
    static func simulateJSONLParsing() async {
        print("\n🔄 步骤2: 模拟 JSONL 解析过程...")
        
        // 模拟一些典型的 JSONL 条目
        let sampleJSONL = [
            """
            {"sessionId":"test-session-1","type":"user","message":{"role":"user","content":"测试消息"},"timestamp":"2025-08-06T01:14:00.000Z"}
            """,
            """
            {"sessionId":"test-session-1","type":"assistant","message":{"role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"text","text":"回复"}]},"timestamp":"2025-08-06T01:14:05.000Z"}
            """,
            """
            {"type":"summary","summary":"测试摘要","leafUuid":"uuid-123"}
            """
        ]
        
        print("  解析样本 JSONL 数据...")
        
        for (index, jsonlLine) in sampleJSONL.enumerated() {
            print("  \n  条目 \(index + 1):")
            
            if let data = jsonlLine.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // 提取关键信息
                let sessionId = json["sessionId"] as? String
                let type = json["type"] as? String
                let hasMessage = json["message"] != nil
                let hasUsage = (json["message"] as? [String: Any])?["usage"] != nil
                
                print("    sessionId: \(sessionId ?? "nil")")
                print("    type: \(type ?? "nil")")
                print("    hasMessage: \(hasMessage)")
                print("    hasUsage: \(hasUsage)")
                
                // 模拟 RawJSONLEntry 解析
                let wouldBeProcessed = simulateRawJSONLEntryParsing(json)
                print("    会被 RawJSONLEntry 处理: \(wouldBeProcessed)")
            } else {
                print("    ❌ JSON 解析失败")
            }
        }
    }
    
    // 模拟 UsageEntry 转换过程
    static func simulateUsageEntryConversion() async {
        print("\n🔄 步骤3: 模拟 UsageEntry 转换过程...")
        
        let testCases = [
            TestRawEntry(
                sessionId: "test-session-1",
                type: "user",
                hasUsage: false,
                totalTokens: 0,
                totalCost: 0.0
            ),
            TestRawEntry(
                sessionId: "test-session-1", 
                type: "assistant",
                hasUsage: true,
                totalTokens: 30,
                totalCost: 0.002
            ),
            TestRawEntry(
                sessionId: nil,
                type: "summary",
                hasUsage: false,
                totalTokens: 0,
                totalCost: 0.0
            )
        ]
        
        print("  测试 toUsageEntry 转换逻辑:")
        
        var sessionIds = Set<String>()
        var convertedEntries = 0
        
        for (index, testCase) in testCases.enumerated() {
            print("  \n  测试用例 \(index + 1):")
            print("    类型: \(testCase.type ?? "nil"), sessionId: \(testCase.sessionId ?? "nil")")
            print("    tokens: \(testCase.totalTokens), cost: \(testCase.totalCost)")
            
            // 统计会话ID（在转换前）
            if let sessionId = testCase.sessionId, !sessionId.isEmpty {
                sessionIds.insert(sessionId)
            }
            
            // 模拟修复后的过滤逻辑
            let shouldConvert = simulateToUsageEntryConversion(testCase)
            print("    转换结果: \(shouldConvert ? "保留" : "过滤")")
            
            if shouldConvert {
                convertedEntries += 1
            }
        }
        
        print("  \n  转换统计:")
        print("    原始条目: \(testCases.count)")  
        print("    转换后条目: \(convertedEntries)")
        print("    唯一会话数: \(sessionIds.count)")
    }
    
    // 模拟最终统计计算
    static func simulateStatisticsCalculation() async {
        print("\n📊 步骤4: 模拟最终统计计算...")
        
        // 模拟实际的 UsageService.calculateStatistics 逻辑
        print("  模拟 UsageService.calculateStatistics...")
        
        let mockEntries = [
            MockUsageEntry(sessionId: "session-1", hasData: false),
            MockUsageEntry(sessionId: "session-1", hasData: true),
            MockUsageEntry(sessionId: "session-2", hasData: false),
            MockUsageEntry(sessionId: "session-3", hasData: true),
        ]
        
        // 第1步：基于原始数据统计会话（这是关键）
        var allSessionIds = Set<String>()
        for entry in mockEntries {
            allSessionIds.insert(entry.sessionId)
        }
        
        print("  原始数据会话统计: \(allSessionIds.count)")
        
        // 第2步：应用去重过滤
        let filteredEntries = mockEntries.filter { $0.hasData }
        print("  过滤后条目数: \(filteredEntries.count)")
        
        // 第3步：最终统计应该使用原始会话数
        let finalSessionCount = allSessionIds.count
        print("  最终会话数应该是: \(finalSessionCount)")
        
        print("\n🎯 关键发现:")
        print("  - 会话统计应该基于原始数据，不受过滤影响")
        print("  - 如果显示仍为1，可能是应用没有重新构建或缓存问题")
    }
    
    // 辅助函数
    static func findJSONLFiles(in directory: URL) async throws -> [URL] {
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
                // 忽略错误
            }
        }
        
        return jsonlFiles
    }
    
    static func simulateRawJSONLEntryParsing(_ json: [String: Any]) -> Bool {
        // 模拟 RawJSONLEntry 的解析逻辑
        return json["sessionId"] != nil || json["usage"] != nil || json["cost"] != nil
    }
    
    static func simulateToUsageEntryConversion(_ testCase: TestRawEntry) -> Bool {
        // 应用修复后的过滤逻辑
        let hasValidSessionId = (testCase.sessionId != nil && !testCase.sessionId!.isEmpty && testCase.sessionId != "unknown")
        
        // 修复后的逻辑：如果有有效sessionId，即使没有usage数据也保留
        if !hasValidSessionId && testCase.totalTokens == 0 && testCase.totalCost == 0 {
            return false
        }
        
        return true
    }
}

struct TestRawEntry {
    let sessionId: String?
    let type: String?
    let hasUsage: Bool
    let totalTokens: Int
    let totalCost: Double
}

struct MockUsageEntry {
    let sessionId: String
    let hasData: Bool
}

// 执行调试
Task {
    await DebugSessionParsing.run()
    exit(0)
}

RunLoop.main.run()