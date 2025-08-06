#!/usr/bin/env swift

import Foundation

// 导入必要的系统调用
private let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

@_silgen_name("proc_pidpath")
private func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

/// 获取进程命令行参数
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

/// 获取进程环境变量
func getProcessEnvironment(pid: Int32) -> [String: String]? {
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size: size_t = 0
    
    if sysctl(&mib, 3, nil, &size, nil, 0) != 0 {
        return nil
    }
    
    var buffer = [UInt8](repeating: 0, count: size)
    if sysctl(&mib, 3, &buffer, &size, nil, 0) != 0 {
        return nil
    }
    
    var argc: Int32 = 0
    memcpy(&argc, buffer, MemoryLayout<Int32>.size)
    
    var offset = MemoryLayout<Int32>.size
    
    // 跳过可执行文件路径
    while offset < buffer.count && buffer[offset] != 0 {
        offset += 1
    }
    while offset < buffer.count && buffer[offset] == 0 {
        offset += 1
    }
    
    // 跳过所有参数
    for _ in 0..<argc {
        while offset < buffer.count && buffer[offset] != 0 {
            offset += 1
        }
        offset += 1
    }
    
    // 读取环境变量
    var env: [String: String] = [:]
    while offset < buffer.count {
        let start = offset
        while offset < buffer.count && buffer[offset] != 0 {
            offset += 1
        }
        
        if start < offset {
            let envData = Data(buffer[start..<offset])
            if let envStr = String(data: envData, encoding: .utf8),
               let equalIndex = envStr.firstIndex(of: "=") {
                let key = String(envStr[..<equalIndex])
                let value = String(envStr[envStr.index(after: equalIndex)...])
                env[key] = value
            }
        }
        
        offset += 1
        if offset >= buffer.count || buffer[offset] == 0 { break }
    }
    
    return env
}

print("=== sysctl node进程深度分析 ===")
print("分析node进程的命令行参数和环境变量")
print()

// 获取系统中所有进程的信息
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
let targetPIDs: [Int32] = [81870, 68604, 92007]

print("🔍 深度分析node进程...")
print(String(repeating: "-", count: 80))

for i in 0..<actualCount {
    let proc = procs[i]
    let pid = proc.kp_proc.p_pid
    
    // 获取进程名
    let comm = withUnsafePointer(to: proc.kp_proc.p_comm) {
        $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: proc.kp_proc.p_comm)) {
            String(cString: $0)
        }
    }
    
    // 只分析node进程
    if comm.lowercased() == "node" {
        print("📋 Node进程 PID \(pid)\(targetPIDs.contains(pid) ? " 🎯" : ""):")
        
        // 获取路径
        var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
        if pathLength > 0 {
            let path = String(cString: pathBuffer)
            print("   路径: \(path)")
        }
        
        // 获取命令行参数
        if let args = getProcessArguments(pid: pid) {
            print("   命令行参数 (\(args.count)个):")
            for (index, arg) in args.enumerated() {
                print("      [\(index)]: \(arg)")
                // 检查是否包含claude相关关键词
                if arg.lowercased().contains("claude") {
                    print("         🔍 包含'claude'!")
                }
            }
        } else {
            print("   ❌ 无法获取命令行参数")
        }
        
        // 获取环境变量（只显示claude相关的）
        if let env = getProcessEnvironment(pid: pid) {
            let claudeEnvs = env.filter { key, value in
                key.lowercased().contains("claude") || value.lowercased().contains("claude")
            }
            if !claudeEnvs.isEmpty {
                print("   Claude相关环境变量:")
                for (key, value) in claudeEnvs {
                    print("      \(key)=\(value)")
                }
            }
        }
        
        // 获取父进程信息
        let ppid = proc.kp_eproc.e_ppid
        print("   父进程PID: \(ppid)")
        
        print()
    }
}

print("🔚 分析完成")