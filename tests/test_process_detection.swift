#!/usr/bin/env swift

import Foundation

// 定义 proc_pidpath 所需的常量和函数导入
private let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

// 导入 proc_pidpath 函数
@_silgen_name("proc_pidpath")
private func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

/// 简化版进程检测测试
func testProcessDetection() {
    print("🚀 开始测试 Claude CLI 进程检测...")
    
    // 获取系统中所有进程的 PID 列表
    var size: size_t = 0
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
    
    if sysctl(&mib, 4, nil, &size, nil, 0) != 0 {
        print("❌ 无法获取进程列表大小")
        return
    }
    
    let count = size / MemoryLayout<kinfo_proc>.size
    var procs = Array<kinfo_proc>(repeating: kinfo_proc(), count: count)
    
    if sysctl(&mib, 4, &procs, &size, nil, 0) != 0 {
        print("❌ 无法获取进程列表")
        return
    }
    
    let actualCount = size / MemoryLayout<kinfo_proc>.size
    var claudeProcesses = 0
    var nodeProcesses = 0
    
    print("📊 共找到 \(actualCount) 个系统进程，开始检测...")
    
    for i in 0..<actualCount {
        let proc = procs[i]
        let pid = proc.kp_proc.p_pid
        
        // 获取进程名
        let comm = withUnsafePointer(to: proc.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: proc.kp_proc.p_comm)) {
                String(cString: $0)
            }
        }
        
        // 先记录所有 node 进程
        if comm.lowercased() == "node" {
            nodeProcesses += 1
            
            // 获取进程路径
            var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
            let executablePath = pathLength > 0 ? String(cString: pathBuffer) : "未知"
            
            print("🔍 找到 Node.js 进程: PID=\(pid), 路径=\(executablePath)")
            
            // 检查是否包含 claude 关键词
            let pathLower = executablePath.lowercased()
            if pathLower.contains("claude") {
                print("   ⭐ 此 Node.js 进程路径包含 'claude'")
            }
            
            // 立即检查这个进程是否为 Claude CLI
            print("   🔍 开始检查此进程是否为 Claude CLI...")
            if isClaudeProcessBySysctl(pid: pid, comm: comm) {
                print("   ✅ 确认为 Claude CLI 进程！")
            } else {
                print("   ❌ 不是 Claude CLI 进程")
            }
        }
        
        // 检查是否是 Claude CLI 进程
        if isClaudeProcessBySysctl(pid: pid, comm: comm) {
            claudeProcesses += 1
            
            // 尝试获取进程的完整路径
            var executablePath: String? = nil
            var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
            if pathLength > 0 {
                executablePath = String(cString: pathBuffer)
            }
            
            print("🎯 找到 Claude CLI 进程:")
            print("   PID: \(pid)")
            print("   命令名: \(comm)")
            print("   路径: \(executablePath ?? "未知")")
            print("")
        }
    }
    
    print("📈 统计结果:")
    print("   Node.js 进程总数: \(nodeProcesses)")
    print("   Claude CLI 进程总数: \(claudeProcesses)")
    print("✅ 检测完成！")
}

/// 通过 sysctl 数据检查是否为 Claude 进程
func isClaudeProcessBySysctl(pid: Int32, comm: String) -> Bool {
    print("     🔍 isClaudeProcessBySysctl 被调用: PID=\(pid), comm=\(comm)")
    
    // 排除我们自己的应用和系统进程
    if comm.contains("ClaudeConfigManager") || pid == 0 || pid == 1 {
        print("     ❌ 排除系统进程或自身应用")
        return false
    }
    
    // 检查进程名是否为 "claude"
    if comm.lowercased() == "claude" {
        print("✅ 发现直接运行的 claude 进程: PID=\(pid)")
        return true
    }
    
    // 对于 node 进程，通过 proc_pidpath() 获取完整路径进行检测
    if comm.lowercased() == "node" {
        print("     🔍 检测到 node 进程，开始路径分析...")
        // 使用 proc_pidpath() 获取进程的完整可执行文件路径
        var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
        
        if pathLength > 0 {
            let executablePath = String(cString: pathBuffer)
            print("     📂 可执行文件路径: \(executablePath)")
            
            // 检查路径中是否包含 claude 相关关键词
            let pathLower = executablePath.lowercased()
            let claudeKeywords = [
                "/claude",
                "claude-cli",  
                "claude/bin",
                "claude/dist",
                "claude.js",
                "claude-code",
                "anthropic/claude"
            ]
            
            for keyword in claudeKeywords {
                if pathLower.contains(keyword) && !pathLower.contains("claudeconfigmanager") {
                    print("✅ 通过路径关键词识别为 Claude CLI 进程: PID=\(pid), 关键词=\(keyword)")
                    return true
                }
            }
            
            // 检查是否是通过 npm 全局安装的 claude 包
            if pathLower.contains("node_modules") && pathLower.contains("claude") && !pathLower.contains("claudeconfigmanager") {
                print("✅ 识别为 npm 安装的 Claude CLI 进程: PID=\(pid)")
                return true
            }
            
            // 特殊情况：检查是否是 nvm 安装的 claude（检查是否存在对应的 claude 脚本）
            if pathLower.contains("/nvm/versions/node/") && pathLower.hasSuffix("/bin/node") {
                print("   🔍 检测到 nvm node 进程，进行 Claude CLI 检查...")
                
                // 构造可能的 claude 脚本路径
                let claudeScriptPath = executablePath.replacingOccurrences(of: "/node", with: "/claude")
                print("   🔍 检查 claude 脚本路径: \(claudeScriptPath)")
                
                if FileManager.default.fileExists(atPath: claudeScriptPath) {
                    print("✅ 通过 nvm claude 脚本识别为 Claude CLI 进程: PID=\(pid), 脚本路径=\(claudeScriptPath)")
                    return true
                }
                
                // 检查是否存在 @anthropic-ai/claude-code 包
                let nodeDir = (executablePath as NSString).deletingLastPathComponent
                let nodeModulesPath = (nodeDir as NSString).appendingPathComponent("../lib/node_modules/@anthropic-ai/claude-code")
                let normalizedPath = URL(fileURLWithPath: nodeModulesPath).standardized.path
                print("   🔍 检查 @anthropic-ai/claude-code 包路径: \(normalizedPath)")
                
                if FileManager.default.fileExists(atPath: normalizedPath) {
                    print("✅ 通过 @anthropic-ai/claude-code 包识别为 Claude CLI 进程: PID=\(pid), 包路径=\(normalizedPath)")
                    return true
                } else {
                    print("   ❌ @anthropic-ai/claude-code 包不存在")
                }
                
                print("   ❌ 未找到 Claude CLI 相关文件")
            }
        }
    }
    
    // 检查其他可能的 Claude 相关进程名
    let claudeNames = ["claude-cli", "claude-code"]
    for name in claudeNames {
        if comm.lowercased().contains(name) {
            print("✅ 通过进程名识别为 Claude CLI: PID=\(pid), comm=\(comm)")
            return true
        }
    }
    
    print("     ❌ 未通过任何 Claude CLI 检测条件")
    return false
}

// 运行测试
testProcessDetection()