#!/usr/bin/env swift

import Foundation

// 导入必要的系统调用
private let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

@_silgen_name("proc_pidpath")
private func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

/// 优化的claude进程检测函数
func getProcessArguments(pid: Int32) -> [String]? {
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size: size_t = 0
    
    // 获取需要的缓冲区大小
    if sysctl(&mib, 3, nil, &size, nil, 0) != 0 {
        return nil
    }
    
    var buffer = [UInt8](repeating: 0, count: size)
    if sysctl(&mib, 3, &buffer, &size, nil, 0) != 0 {
        return nil
    }
    
    // 解析命令行参数
    var argc: Int32 = 0
    memcpy(&argc, buffer, MemoryLayout<Int32>.size)
    
    var offset = MemoryLayout<Int32>.size
    var args: [String] = []
    
    // 跳过可执行文件路径
    while offset < buffer.count && buffer[offset] != 0 {
        offset += 1
    }
    
    // 跳过空字节
    while offset < buffer.count && buffer[offset] == 0 {
        offset += 1
    }
    
    // 读取参数
    for _ in 0..<argc {
        if offset >= buffer.count { break }
        
        let start = offset
        while offset < buffer.count && buffer[offset] != 0 {
            offset += 1
        }
        
        if start < offset {
            let argData = Data(buffer[start..<offset])
            if let arg = String(data: argData, encoding: .utf8) {
                args.append(arg)
            }
        }
        
        // 跳过空字节
        offset += 1
    }
    
    return args
}

/// 检查是否为claude进程（优化版）
func isClaudeProcess(pid: Int32, comm: String) -> Bool {
    // 首先检查是否为node进程
    guard comm.lowercased() == "node" else {
        return false
    }
    
    // 排除我们自己的应用
    if comm.contains("ClaudeConfigManager") {
        return false
    }
    
    // 获取命令行参数
    guard let args = getProcessArguments(pid: pid), !args.isEmpty else {
        return false
    }
    
    // 检查第一个参数是否为"claude"
    return args[0].lowercased() == "claude"
}

/// 查找所有claude进程
func findAllClaudeProcesses() -> [(pid: Int32, comm: String, path: String?, args: [String])] {
    var processes: [(pid: Int32, comm: String, path: String?, args: [String])] = []
    
    // 获取系统中所有进程的信息
    var size: size_t = 0
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
    
    if sysctl(&mib, 4, nil, &size, nil, 0) != 0 {
        print("❌ 无法获取进程列表大小")
        return []
    }
    
    let count = size / MemoryLayout<kinfo_proc>.size
    var procs = Array<kinfo_proc>(repeating: kinfo_proc(), count: count)
    
    if sysctl(&mib, 4, &procs, &size, nil, 0) != 0 {
        print("❌ 无法获取进程列表")
        return []
    }
    
    let actualCount = size / MemoryLayout<kinfo_proc>.size
    print("📊 sysctl 获取到 \(actualCount) 个进程")
    
    for i in 0..<actualCount {
        let proc = procs[i]
        let pid = proc.kp_proc.p_pid
        
        // 获取进程名
        let comm = withUnsafePointer(to: proc.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: proc.kp_proc.p_comm)) {
                String(cString: $0)
            }
        }
        
        // 使用优化的检测函数
        if isClaudeProcess(pid: pid, comm: comm) {
            // 获取进程的完整路径
            var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
            var executablePath: String? = nil
            if pathLength > 0 {
                executablePath = String(cString: pathBuffer)
            }
            
            // 获取命令行参数
            let args = getProcessArguments(pid: pid) ?? []
            
            processes.append((pid: pid, comm: comm, path: executablePath, args: args))
            print("✅ 找到 Claude 进程: PID=\(pid), 路径=\(executablePath ?? "未知")")
            print("   命令行参数: \(args)")
        }
    }
    
    return processes
}

print("=== 优化的claude进程检测测试 ===")
print()

let claudeProcesses = findAllClaudeProcesses()

print()
print("📋 检测结果:")
print("找到 \(claudeProcesses.count) 个 Claude CLI 进程")

for process in claudeProcesses {
    print("• PID: \(process.pid)")
    print("  路径: \(process.path ?? "未知")")
    print("  参数: \(process.args)")
}

print()
print("🧪 验证目标PID:")
let targetPIDs: [Int32] = [81870, 68604, 92007]
for targetPID in targetPIDs {
    let found = claudeProcesses.contains { $0.pid == targetPID }
    print("PID \(targetPID): \(found ? "✅ 检测到" : "❌ 未检测到")")
}

print()
print("🔚 测试完成")