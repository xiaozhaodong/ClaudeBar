#!/usr/bin/env swift

import Foundation

// MARK: - 会话统计测试脚本
// 用于验证 Claude Code JSONL 数据中的实际会话总数

struct SessionCountTest {
    
    /// 执行会话统计测试
    static func run() async {
        print("🔍 开始会话统计测试...")
        
        let claudeDirectory = getClaudeDirectory()
        let projectsDirectory = claudeDirectory.appendingPathComponent("projects")
        
        guard FileManager.default.fileExists(atPath: projectsDirectory.path) else {
            print("❌ 错误: projects 目录不存在: \(projectsDirectory.path)")
            return
        }
        
        print("📂 扫描目录: \(projectsDirectory.path)")
        
        do {
            // 1. 扫描所有 JSONL 文件
            let jsonlFiles = try await findAllJSONLFiles(in: projectsDirectory)
            print("📄 找到 \(jsonlFiles.count) 个 JSONL 文件")
            
            // 2. 统计会话ID
            let sessionStats = await countSessions(from: jsonlFiles)
            
            // 3. 输出统计结果
            printResults(sessionStats)
            
        } catch {
            print("❌ 错误: \(error)")
        }
    }
    
    /// 获取 Claude 目录
    static func getClaudeDirectory() -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(".claude")
    }
    
    /// 查找所有 JSONL 文件
    static func findAllJSONLFiles(in directory: URL) async throws -> [URL] {
        var jsonlFiles: [URL] = []
        
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
        
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            throw TestError.directoryEnumerationFailed
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                
                if let isDirectory = resourceValues.isDirectory, !isDirectory,
                   let name = resourceValues.name, name.hasSuffix(".jsonl") {
                    jsonlFiles.append(fileURL)
                }
            } catch {
                print("⚠️ 跳过文件: \(fileURL.path) - \(error)")
            }
        }
        
        return jsonlFiles
    }
    
    /// 统计会话数据
    static func countSessions(from files: [URL]) async -> SessionStatistics {
        var allSessionIds = Set<String>()
        var fileSessionCount: [String: Int] = [:]
        var totalLines = 0
        var validLines = 0
        var errorLines = 0
        var filesWithSessions = 0
        var filesWithoutSessions = 0
        
        print("\n📊 开始分析 \(files.count) 个文件...")
        
        for (index, fileURL) in files.enumerated() {
            let fileName = fileURL.lastPathComponent
            var fileSessionIds = Set<String>()
            
            if index % 100 == 0 && index > 0 {
                print("已处理 \(index)/\(files.count) 个文件...")
            }
            
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                totalLines += lines.count
                
                for line in lines {
                    guard let data = line.data(using: .utf8) else { continue }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            validLines += 1
                            
                            // 提取 sessionId
                            if let sessionId = json["sessionId"] as? String, !sessionId.isEmpty {
                                allSessionIds.insert(sessionId)
                                fileSessionIds.insert(sessionId)
                            }
                        }
                    } catch {
                        errorLines += 1
                    }
                }
                
                // 记录每个文件的会话数
                if !fileSessionIds.isEmpty {
                    fileSessionCount[fileName] = fileSessionIds.count
                    filesWithSessions += 1
                } else {
                    filesWithoutSessions += 1
                }
                
            } catch {
                print("⚠️ 无法读取文件: \(fileName) - \(error)")
                errorLines += 1
            }
        }
        
        return SessionStatistics(
            totalUniqueeSessions: allSessionIds.count,
            totalFiles: files.count,
            filesWithSessions: filesWithSessions,
            filesWithoutSessions: filesWithoutSessions,
            totalLines: totalLines,
            validLines: validLines,
            errorLines: errorLines,
            fileSessionCount: fileSessionCount,
            sessionIds: allSessionIds
        )
    }
    
    /// 输出统计结果
    static func printResults(_ stats: SessionStatistics) {
        print("\n" + "="*60)
        print("📈 会话统计测试结果")
        print("="*60)
        
        print("\n🎯 核心统计:")
        print("  总会话数(唯一sessionId): \(stats.totalUniqueeSessions)")
        print("  总文件数: \(stats.totalFiles)")
        print("  有会话的文件数: \(stats.filesWithSessions)")
        print("  无会话的文件数: \(stats.filesWithoutSessions)")
        
        print("\n📄 数据处理:")
        print("  总行数: \(formatNumber(stats.totalLines))")
        print("  有效JSON行数: \(formatNumber(stats.validLines))")
        print("  错误行数: \(formatNumber(stats.errorLines))")
        print("  有效率: \(String(format: "%.2f", Double(stats.validLines) / Double(stats.totalLines) * 100))%")
        
        print("\n📊 会话分布分析:")
        let sortedFiles = stats.fileSessionCount.sorted { $0.value > $1.value }
        
        if !sortedFiles.isEmpty {
            print("  会话数最多的前10个文件:")
            for (index, (fileName, count)) in sortedFiles.prefix(10).enumerated() {
                print("    \(index + 1). \(fileName): \(count) 个会话")
            }
        }
        
        // 统计会话ID长度分布
        let sessionIdLengths = stats.sessionIds.map { $0.count }
        if !sessionIdLengths.isEmpty {
            let avgLength = sessionIdLengths.reduce(0, +) / sessionIdLengths.count
            let minLength = sessionIdLengths.min() ?? 0
            let maxLength = sessionIdLengths.max() ?? 0
            
            print("\n🔍 会话ID特征:")
            print("  平均长度: \(avgLength) 字符")
            print("  最短长度: \(minLength) 字符")  
            print("  最长长度: \(maxLength) 字符")
            
            // 显示几个示例sessionId
            let sampleIds = Array(stats.sessionIds.prefix(5))
            print("  示例ID:")
            for id in sampleIds {
                print("    \(id)")
            }
        }
        
        print("\n✅ 测试完成!")
        print("📋 建议: ClaudeBar 的总会话数应该显示为 \(stats.totalUniqueeSessions)")
        print("="*60)
    }
    
    /// 格式化数字显示
    static func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - 数据模型

struct SessionStatistics {
    let totalUniqueeSessions: Int
    let totalFiles: Int
    let filesWithSessions: Int
    let filesWithoutSessions: Int
    let totalLines: Int
    let validLines: Int
    let errorLines: Int
    let fileSessionCount: [String: Int]
    let sessionIds: Set<String>
}

enum TestError: Error {
    case directoryEnumerationFailed
    case invalidJSONFormat
    
    var localizedDescription: String {
        switch self {
        case .directoryEnumerationFailed:
            return "无法枚举目录"
        case .invalidJSONFormat:
            return "无效的JSON格式"
        }
    }
}

// MARK: - 字符串扩展

extension String {
    static func *(string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// MARK: - 执行测试

Task {
    await SessionCountTest.run()
    exit(0)
}

// 保持脚本运行
RunLoop.main.run()