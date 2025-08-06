#!/usr/bin/env swift

import Foundation

/// ps命令进程检测测试脚本
/// 
/// 使用ps命令检测claude进程，验证此方法的可靠性

print("=== ps命令进程检测测试 ===")
print()

// 测试函数：使用ps命令查找claude进程
func findClaudeProcessesWithPS() -> [(pid: Int32, command: String)] {
    let task = Process()
    let pipe = Pipe()
    
    // 使用ps命令查找claude进程
    // ps -ax -o pid,comm | awk '$2 == "claude"'
    task.executableURL = URL(fileURLWithPath: "/bin/ps")
    task.arguments = ["-ax", "-o", "pid,comm"]
    task.standardOutput = pipe
    task.standardError = Pipe()
    
    var processes: [(pid: Int32, command: String)] = []
    
    do {
        try task.run()
        task.waitUntilExit()
        
        guard task.terminationStatus == 0 else {
            print("❌ ps命令执行失败，退出码: \(task.terminationStatus)")
            return []
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            print("❌ 无法读取ps命令输出")
            return []
        }
        
        print("📊 ps命令原始输出:")
        print(output)
        print(String(repeating: "-", count: 50))
        
        // 解析输出
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            let components = trimmed.components(separatedBy: .whitespaces)
            if components.count >= 2 {
                let comm = components[1]
                if comm == "claude" {
                    if let pid = Int32(components[0]) {
                        processes.append((pid: pid, command: comm))
                        print("✅ 找到claude进程: PID=\(pid), comm=\(comm)")
                    }
                }
            }
        }
        
    } catch {
        print("❌ 执行ps命令时发生错误: \(error)")
    }
    
    return processes
}

// 测试函数：使用ps aux获取更详细的信息
func findClaudeProcessesWithPSAux() -> [(pid: Int32, command: String, fullCommand: String)] {
    let task = Process()
    let pipe = Pipe()
    
    task.executableURL = URL(fileURLWithPath: "/bin/ps")
    task.arguments = ["aux"]
    task.standardOutput = pipe
    task.standardError = Pipe()
    
    var processes: [(pid: Int32, command: String, fullCommand: String)] = []
    
    do {
        try task.run()
        task.waitUntilExit()
        
        guard task.terminationStatus == 0 else {
            print("❌ ps aux命令执行失败，退出码: \(task.terminationStatus)")
            return []
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            print("❌ 无法读取ps aux命令输出")
            return []
        }
        
        // 解析输出，查找claude进程
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            // 检查是否包含claude但不包含grep
            if trimmed.contains("claude") && !trimmed.contains("grep") && !trimmed.contains("ClaudeConfigManager") {
                // 解析PID（第二列）
                let components = trimmed.components(separatedBy: .whitespaces)
                if components.count >= 11, let pid = Int32(components[1]) {
                    // 获取完整命令（从第11列开始）
                    let fullCommand = components[10...].joined(separator: " ")
                    processes.append((pid: pid, command: "claude", fullCommand: fullCommand))
                    print("✅ 找到claude进程: PID=\(pid)")
                    print("   完整命令: \(fullCommand)")
                }
            }
        }
        
    } catch {
        print("❌ 执行ps aux命令时发生错误: \(error)")
    }
    
    return processes
}

// 运行测试
print("🔍 方法1: 使用 ps -ax -o pid,comm")
let method1Results = findClaudeProcessesWithPS()
print("找到 \(method1Results.count) 个claude进程")
print()

print("🔍 方法2: 使用 ps aux")
let method2Results = findClaudeProcessesWithPSAux()
print("找到 \(method2Results.count) 个claude进程")
print()

print("📋 检测结果汇总:")
print("方法1 (ps -ax): \(method1Results.count) 个进程")
print("方法2 (ps aux): \(method2Results.count) 个进程")

// 验证目标PID
let targetPIDs: [Int32] = [81870, 68604]
print()
print("🎯 目标PID验证:")
for targetPID in targetPIDs {
    let found1 = method1Results.contains { $0.pid == targetPID }
    let found2 = method2Results.contains { $0.pid == targetPID }
    print("PID \(targetPID): 方法1=\(found1 ? "✅" : "❌"), 方法2=\(found2 ? "✅" : "❌")")
}

print()
print("🔚 测试完成")