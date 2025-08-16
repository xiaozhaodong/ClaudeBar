#!/usr/bin/env swift

import Foundation

func checkSessionIds(in filePath: String) {
    do {
        let content = try String(contentsOfFile: filePath)
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        print("📄 分析文件: \(URL(fileURLWithPath: filePath).lastPathComponent)")
        print("====================================")
        
        var sessionIdCounts: [String: Int] = [:]
        var sessionIdWithUsage: [String: Int] = [:]
        var sessionIdWithCost: [String: Int] = [:]
        
        for (lineNum, line) in lines.enumerated() {
            guard let data = line.data(using: .utf8) else { continue }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let sessionId = json["sessionId"] as? String {
                        sessionIdCounts[sessionId, default: 0] += 1
                        
                        // 检查是否有usage数据
                        if json["usage"] != nil || json["message"] != nil {
                            sessionIdWithUsage[sessionId, default: 0] += 1
                        }
                        
                        // 检查是否有cost数据
                        if json["cost"] != nil || json["costUSD"] != nil {
                            sessionIdWithCost[sessionId, default: 0] += 1
                        }
                    }
                }
            } catch {
                // 忽略解析错误
            }
        }
        
        let expectedSessionId = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        
        print("📋 期望SessionId: \(expectedSessionId)")
        print("📊 发现的SessionId:")
        
        for sessionId in sessionIdCounts.keys.sorted() {
            let total = sessionIdCounts[sessionId] ?? 0
            let withUsage = sessionIdWithUsage[sessionId] ?? 0
            let withCost = sessionIdWithCost[sessionId] ?? 0
            let isExpected = sessionId == expectedSessionId ? "✅" : "⚠️ "
            
            print("   \(isExpected) \(sessionId):")
            print("     总记录: \(total)")
            print("     有usage: \(withUsage)")
            print("     有cost: \(withCost)")
        }
        
        // 计算如果不过滤vs过滤的差异
        let otherSessionRecords = sessionIdCounts.filter { $0.key != expectedSessionId }
        let otherSessionTotal = otherSessionRecords.values.reduce(0, +)
        let otherSessionWithUsage = sessionIdWithUsage.filter { $0.key != expectedSessionId }.values.reduce(0, +)
        
        print("\n🔍 过滤影响分析:")
        print("   期望SessionId记录: \(sessionIdCounts[expectedSessionId] ?? 0)")
        print("   其他SessionId记录: \(otherSessionTotal)")
        print("   其他SessionId中有usage的: \(otherSessionWithUsage)")
        
        if otherSessionWithUsage > 0 {
            print("   💰 潜在成本重复累计风险: 有 \(otherSessionWithUsage) 条其他会话的成本记录可能被错误统计")
        } else {
            print("   ✅ 无成本重复累计风险: 其他SessionId记录都无usage数据")
        }
        
    } catch {
        print("❌ 读取文件失败: \(error)")
    }
}

// 主程序
guard CommandLine.arguments.count > 1 else {
    print("使用方法: swift check_session_ids.swift <jsonl文件路径>")
    exit(1)
}

checkSessionIds(in: CommandLine.arguments[1])