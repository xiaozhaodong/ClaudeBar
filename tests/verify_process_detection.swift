#!/usr/bin/swift

import Foundation

// 定义 proc_pidpath 所需的常量和函数导入
private let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

// 导入 proc_pidpath 函数
@_silgen_name("proc_pidpath")
private func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

print("🔍 开始验证 Claude 进程检测逻辑...")
print(String(repeating: "=", count: 50))

// 首先用 ps 命令查看当前的 claude 进程
print("\n📋 使用 ps 命令查看当前 claude 进程:")
let task = Process()
let pipe = Pipe()

task.executableURL = URL(fileURLWithPath: "/bin/ps")
task.arguments = ["-ax", "-o", "pid,comm,args"]
task.standardOutput = pipe

do {
    try task.run()
    task.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        let lines = output.components(separatedBy: "\n")
        
        print("查找包含 'claude' 的进程:")
        for line in lines {
            if line.lowercased().contains("claude") && !line.isEmpty {
                print("  \(line)")
            }
        }
    }
} catch {
    print("❌ 执行 ps 命令失败: \(error)")
}

print("\n" + String(repeating: "=", count: 50))
print("🧪 使用 sysctl 方法检测进程:")

// 获取系统中所有进程的 PID 列表
var size: size_t = 0
var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]

if sysctl(&mib, 4, nil, &size, nil, 0) != 0 {
    print("❌ 无法获取进程列表大小")
    exit(1)
}

let count = size / MemoryLayout<kinfo_proc>.size
var procs = Array<kinfo_proc>(repeating: kinfo_proc(), count: count)

if sysctl(&mib, 4, &procs, &size, nil, 0) != 0 {
    print("❌ 无法获取进程列表")
    exit(1)
}

let actualCount = size / MemoryLayout<kinfo_proc>.size
print("✅ sysctl 获取到 \(actualCount) 个进程")

var foundClaudeProcesses = 0
var allClaudeRelated: [(Int32, String)] = []

for i in 0..<actualCount {
    let proc = procs[i]
    let pid = proc.kp_proc.p_pid
    
    // 获取进程名
    let comm = withUnsafePointer(to: proc.kp_proc.p_comm) {
        $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: proc.kp_proc.p_comm)) {
            String(cString: $0)
        }
    }
    
    // 记录所有包含 claude 的进程（用于调试）
    if comm.lowercased().contains("claude") {
        allClaudeRelated.append((pid, comm))
    }
    
    // 应用我们的检测逻辑
    if isClaudeProcess(pid: pid, comm: comm) {
        foundClaudeProcesses += 1
        
        // 尝试获取进程的完整路径
        var executablePath: String? = nil
        var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
        if pathLength > 0 {
            executablePath = String(cString: pathBuffer)
        }
        
        print("✅ 找到 Claude 进程:")
        print("   PID: \(pid)")
        print("   comm: '\(comm)'")
        print("   路径: \(executablePath ?? "未知")")
        print("")
    }
}

print("📊 检测结果统计:")
print("   找到的 Claude 进程: \(foundClaudeProcesses) 个")
print("   所有包含 'claude' 的进程: \(allClaudeRelated.count) 个")

if !allClaudeRelated.isEmpty {
    print("\n🔍 所有包含 'claude' 的进程详情:")
    for (pid, comm) in allClaudeRelated {
        let isMatch = isClaudeProcess(pid: pid, comm: comm)
        print("   PID \(pid): '\(comm)' -> \(isMatch ? "✅匹配" : "❌不匹配")")
    }
}

if foundClaudeProcesses == 0 {
    print("\n⚠️  没有找到 Claude 进程！")
    print("可能的原因:")
    print("1. Claude CLI 没有在运行")
    print("2. 检测逻辑有问题")
    print("3. 进程名称不是预期的 'claude'")
}

/// 检查是否为 Claude CLI 进程（简化版）
func isClaudeProcess(pid: Int32, comm: String) -> Bool {
    // 排除我们自己的应用
    if comm.contains("ClaudeConfigManager") {
        return false
    }
    
    // 简单检查：进程名就是 "claude"
    return comm.lowercased() == "claude"
}

print("\n🎯 验证完成!")