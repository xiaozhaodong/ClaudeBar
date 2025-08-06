#!/usr/bin/env swift

import Foundation

print("🔍 简化版进程检测测试")

// 先用 ps 命令确认 claude 进程存在
let task = Process()
let pipe = Pipe()

task.executableURL = URL(fileURLWithPath: "/bin/ps")
task.arguments = ["-ax", "-o", "pid,comm"]
task.standardOutput = pipe

do {
    try task.run()
    task.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        let lines = output.components(separatedBy: "\n")
        
        print("\n📋 ps 命令找到的 claude 进程:")
        var psClaudeCount = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("claude") && !trimmed.isEmpty {
                let parts = trimmed.components(separatedBy: .whitespaces)
                if parts.count >= 2 {
                    let pid = parts[0]
                    let comm = parts[1]
                    if comm.lowercased() == "claude" {
                        print("  ✅ PID \(pid): \(comm)")
                        psClaudeCount += 1
                    } else {
                        print("  ❌ PID \(pid): \(comm) (不匹配)")
                    }
                }
            }
        }
        print("ps 找到 \(psClaudeCount) 个匹配的 claude 进程")
    }
} catch {
    print("❌ ps 命令失败: \(error)")
}

print("\n🎯 测试完成！")