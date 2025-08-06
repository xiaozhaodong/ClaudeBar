#!/usr/bin/env swift

import Foundation

print("=== ps命令进程检测测试（简化版） ===")

// 方法1：直接使用ps过滤claude
func testMethod1() {
    print("🔍 方法1: ps -ax -o pid,comm | grep claude")
    
    let task = Process()
    let pipe = Pipe()
    
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", "ps -ax -o pid,comm | grep claude | grep -v grep"]
    task.standardOutput = pipe
    task.standardError = Pipe()
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
            print("输出:")
            print(output)
            
            // 解析进程
            let lines = output.components(separatedBy: .newlines)
            var count = 0
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    count += 1
                    let components = trimmed.components(separatedBy: .whitespaces)
                    if components.count >= 2 {
                        print("找到进程: PID=\(components[0]), comm=\(components[1])")
                    }
                }
            }
            print("总共找到 \(count) 个claude进程")
        } else {
            print("❌ 未找到claude进程")
        }
    } catch {
        print("❌ 执行失败: \(error)")
    }
}

// 方法2：验证特定PID
func testMethod2() {
    print("\n🔍 方法2: 验证特定PID")
    let targetPIDs = [81870, 68604]
    
    for pid in targetPIDs {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "ps -p \(pid) -o comm= 2>/dev/null || echo 'NOT_FOUND'"]
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let result = output.trimmingCharacters(in: .whitespaces)
                if result == "NOT_FOUND" {
                    print("PID \(pid): ❌ 进程不存在")
                } else {
                    print("PID \(pid): ✅ comm='\(result)'")
                }
            }
        } catch {
            print("PID \(pid): ❌ 检查失败: \(error)")
        }
    }
}

testMethod1()
testMethod2()

print("\n🔚 测试完成")