#!/usr/bin/env swift

import Foundation

// 导入必要的系统调用
private let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

@_silgen_name("proc_pidpath")
private func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

/// sysctl 进程检测测试脚本（专注node进程分析）
/// 
/// 专门分析所有node进程，寻找claude的识别特征

print("=== sysctl node进程分析测试 ===")
print("查找目标进程: PID 81870 和 68604")
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
print("📊 sysctl 获取到 \(actualCount) 个进程")
print()

// 目标PID列表
let targetPIDs: [Int32] = [81870, 68604]
var foundTargets = [Int32: (comm: String, path: String?)]()
var nodeProcesses = [(pid: Int32, comm: String, path: String?)]()

print("🔍 扫描所有node进程...")
print(String(repeating: "-", count: 80))

for i in 0..<actualCount {
    let proc = procs[i]
    let pid = proc.kp_proc.p_pid
    
    // 获取进程名 (p_comm)
    let comm = withUnsafePointer(to: proc.kp_proc.p_comm) {
        $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: proc.kp_proc.p_comm)) {
            String(cString: $0)
        }
    }
    
    // 只关注node进程
    if comm.lowercased() == "node" {
        // 获取进程的完整路径
        var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
        var executablePath: String? = nil
        if pathLength > 0 {
            executablePath = String(cString: pathBuffer)
        }
        
        nodeProcesses.append((pid: pid, comm: comm, path: executablePath))
        
        // 检查是否是目标PID
        if targetPIDs.contains(pid) {
            foundTargets[pid] = (comm: comm, path: executablePath)
            print("🎯 找到目标node进程 PID \(pid):")
        } else {
            print("📋 普通node进程 PID \(pid):")
        }
        
        print("   p_comm: '\(comm)'")
        print("   路径: \(executablePath ?? "无法获取")")
        
        // 尝试通过路径特征判断是否可能是claude
        if let path = executablePath {
            let pathLower = path.lowercased()
            let isLikelyClaude = pathLower.contains("claude") || 
                               path.contains(".nvm") || 
                               path.contains("node")
            print("   可能是claude: \(isLikelyClaude ? "是" : "否") (基于路径分析)")
        }
        print()
    }
}

print(String(repeating: "=", count: 80))
print("📋 node进程分析结果:")
print()

print("🔍 找到 \(nodeProcesses.count) 个node进程")
print()

// 检查目标PID
print("🎯 目标PID检查结果:")
for targetPID in targetPIDs {
    if let target = foundTargets[targetPID] {
        print("   PID \(targetPID): ✅ 找到")
        print("      p_comm: '\(target.comm)'")
        print("      路径: \(target.path ?? "未知")")
    } else {
        print("   PID \(targetPID): ❌ 未找到")
    }
}
print()

// 分析路径特征
print("🔍 路径特征分析:")
var nvmNodes = 0
var systemNodes = 0
var brewNodes = 0
var unknownNodes = 0

for process in nodeProcesses {
    guard let path = process.path else {
        unknownNodes += 1
        continue
    }
    
    if path.contains(".nvm") {
        nvmNodes += 1
    } else if path.contains("/usr/local") || path.contains("/opt/homebrew") {
        brewNodes += 1
    } else if path.contains("/usr/bin") || path.contains("/bin") {
        systemNodes += 1
    } else {
        unknownNodes += 1
    }
}

print("   .nvm路径的node进程: \(nvmNodes)个")
print("   brew路径的node进程: \(brewNodes)个")
print("   系统路径的node进程: \(systemNodes)个")
print("   其他/未知路径: \(unknownNodes)个")
print()

// 提出检测策略
print("💡 claude检测策略建议:")
if !foundTargets.isEmpty {
    print("   1. 检测p_comm == 'node'的进程")
    print("   2. 获取进程路径，优先考虑.nvm路径的node")
    print("   3. 可以考虑检查进程的命令行参数（需要额外系统调用）")
} else {
    print("   ❌ 目标进程未找到，无法分析特征")
}

print()
print("🔚 测试完成")