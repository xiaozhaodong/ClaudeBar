#!/usr/bin/env swift

import Foundation

// 定义 proc_pidpath 所需的常量和函数导入
private let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

// 导入 proc_pidpath 函数
@_silgen_name("proc_pidpath")
private func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

/// 内存信息结构体
struct ProcessMemoryInfo {
    let virtualSize: UInt64      // 虚拟内存大小 (字节)
    let residentSize: UInt64     // 物理内存大小 (字节)
    let sharedSize: UInt64       // 共享内存大小 (字节)
    
    var virtualSizeMB: Double { Double(virtualSize) / 1024 / 1024 }
    var residentSizeMB: Double { Double(residentSize) / 1024 / 1024 }
    var sharedSizeMB: Double { Double(sharedSize) / 1024 / 1024 }
    
    var displayText: String {
        return String(format: "虚拟: %.1f MB, 物理: %.1f MB", virtualSizeMB, residentSizeMB)
    }
}

/// 测试性能监控功能
func testPerformanceMonitoring() {
    print("🚀 开始测试进程性能监控功能...")
    
    // 首先找到一些进程来测试
    let testPIDs = getTestProcesses()
    
    if testPIDs.isEmpty {
        print("❌ 没有找到可测试的进程")
        return
    }
    
    print("📊 找到 \(testPIDs.count) 个测试进程，开始性能监控测试...")
    
    for pid in testPIDs {
        print("\n🔍 测试进程 PID: \(pid)")
        
        // 获取进程名称
        if let processName = getProcessName(pid: pid) {
            print("   进程名: \(processName)")
        }
        
        // 获取进程路径
        if let processPath = getProcessPath(pid: pid) {
            print("   进程路径: \(processPath)")
        }
        
        // 测试 CPU 使用率获取
        print("   🖥️ 测试 CPU 使用率获取...")
        if let cpuUsage = getProcessCPUUsage(pid: pid) {
            print("   ✅ CPU 使用率: \(String(format: "%.2f", cpuUsage))%")
        } else {
            print("   ❌ 无法获取 CPU 使用率")
            testTaskForPidError(pid: pid)
        }
        
        // 测试内存信息获取
        print("   💾 测试内存信息获取...")
        if let memoryInfo = getProcessMemoryInfo(pid: pid) {
            print("   ✅ 内存信息: \(memoryInfo.displayText)")
        } else {
            print("   ❌ 无法获取内存信息")
            testTaskForPidError(pid: pid)
        }
        
        // 测试使用 sysctl 的替代方法
        print("   🔄 测试 sysctl 替代方法...")
        if let (cpuUsage, memoryMB) = getProcessInfoBySysctl(pid: pid) {
            print("   ✅ sysctl - CPU: \(String(format: "%.2f", cpuUsage))%, 内存: \(String(format: "%.1f", memoryMB)) MB")
        } else {
            print("   ❌ sysctl 方法也失败")
        }
    }
    
    print("\n🎯 开始专门测试 Claude 进程...")
    testClaudeProcessPerformance()
}

/// 获取一些测试进程的 PID
func getTestProcesses() -> [Int32] {
    var pids: [Int32] = []
    
    // 获取当前进程
    pids.append(getpid())
    
    // 通过 sysctl 获取一些系统进程
    var size: size_t = 0
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
    
    if sysctl(&mib, 4, nil, &size, nil, 0) == 0 {
        let count = size / MemoryLayout<kinfo_proc>.size
        var procs = Array<kinfo_proc>(repeating: kinfo_proc(), count: count)
        
        if sysctl(&mib, 4, &procs, &size, nil, 0) == 0 {
            let actualCount = size / MemoryLayout<kinfo_proc>.size
            var nodeCount = 0
            
            for i in 0..<min(actualCount, 100) { // 只检查前100个进程
                let proc = procs[i]
                let pid = proc.kp_proc.p_pid
                
                let comm = withUnsafePointer(to: proc.kp_proc.p_comm) {
                    $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: proc.kp_proc.p_comm)) {
                        String(cString: $0)
                    }
                }
                
                // 收集一些 node 进程用于测试
                if comm.lowercased() == "node" && nodeCount < 3 {
                    pids.append(pid)
                    nodeCount += 1
                }
            }
        }
    }
    
    return Array(pids.prefix(5)) // 最多测试5个进程
}

/// 获取进程名称
func getProcessName(pid: Int32) -> String? {
    var size: size_t = 0
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    
    if sysctl(&mib, 4, nil, &size, nil, 0) != 0 {
        return nil
    }
    
    var proc = kinfo_proc()
    if sysctl(&mib, 4, &proc, &size, nil, 0) != 0 {
        return nil
    }
    
    return withUnsafePointer(to: proc.kp_proc.p_comm) {
        $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: proc.kp_proc.p_comm)) {
            String(cString: $0)
        }
    }
}

/// 获取进程路径
func getProcessPath(pid: Int32) -> String? {
    var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
    let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
    if pathLength > 0 {
        return String(cString: pathBuffer)
    }
    return nil
}

/// 获取进程 CPU 使用率
func getProcessCPUUsage(pid: Int32) -> Double? {
    var task: mach_port_t = 0
    
    // 获取进程任务句柄
    let kr = task_for_pid(mach_task_self_, pid, &task)
    guard kr == KERN_SUCCESS else {
        print("      ❌ task_for_pid 失败: \(kr)")
        return nil
    }
    
    defer {
        mach_port_deallocate(mach_task_self_, task)
    }
    
    // 获取任务基本信息
    var basicInfo = task_basic_info()
    var basicInfoCount = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size / MemoryLayout<integer_t>.size)
    
    let basicResult = withUnsafeMutablePointer(to: &basicInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(basicInfoCount)) {
            task_info(task, task_flavor_t(TASK_BASIC_INFO), $0, &basicInfoCount)
        }
    }
    
    guard basicResult == KERN_SUCCESS else {
        print("      ❌ TASK_BASIC_INFO 失败: \(basicResult)")
        return nil
    }
    
    // 获取任务线程时间信息
    var threadInfo = task_thread_times_info()
    var threadInfoCount = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size / MemoryLayout<integer_t>.size)
    
    let threadResult = withUnsafeMutablePointer(to: &threadInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) {
            task_info(task, task_flavor_t(TASK_THREAD_TIMES_INFO), $0, &threadInfoCount)
        }
    }
    
    guard threadResult == KERN_SUCCESS else {
        print("      ❌ TASK_THREAD_TIMES_INFO 失败: \(threadResult)")
        return nil
    }
    
    // 计算总 CPU 时间（用户时间 + 系统时间）
    let userTime = Double(threadInfo.user_time.seconds) + Double(threadInfo.user_time.microseconds) / 1_000_000
    let systemTime = Double(threadInfo.system_time.seconds) + Double(threadInfo.system_time.microseconds) / 1_000_000
    let totalTime = userTime + systemTime
    
    // 简化的 CPU 使用率计算 - 基于总运行时间
    let cpuUsage = min(totalTime * 0.1, 100.0) // 调整系数
    
    return cpuUsage
}

/// 获取进程内存信息
func getProcessMemoryInfo(pid: Int32) -> ProcessMemoryInfo? {
    var task: mach_port_t = 0
    
    // 获取进程任务句柄
    let kr = task_for_pid(mach_task_self_, pid, &task)
    guard kr == KERN_SUCCESS else {
        print("      ❌ task_for_pid 失败: \(kr)")
        return nil
    }
    
    defer {
        mach_port_deallocate(mach_task_self_, task)
    }
    
    // 获取任务基本信息
    var basicInfo = task_basic_info()
    var basicInfoCount = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size / MemoryLayout<integer_t>.size)
    
    let basicResult = withUnsafeMutablePointer(to: &basicInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(basicInfoCount)) {
            task_info(task, task_flavor_t(TASK_BASIC_INFO), $0, &basicInfoCount)
        }
    }
    
    guard basicResult == KERN_SUCCESS else {
        print("      ❌ TASK_BASIC_INFO 失败: \(basicResult)")
        return nil
    }
    
    // 尝试获取虚拟内存信息
    var vmInfo = task_vm_info()
    var vmInfoCount = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<integer_t>.size)
    
    let vmResult = withUnsafeMutablePointer(to: &vmInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmInfoCount)) {
            task_info(task, task_flavor_t(TASK_VM_INFO), $0, &vmInfoCount)
        }
    }
    
    if vmResult == KERN_SUCCESS {
        // 使用详细的虚拟内存信息
        return ProcessMemoryInfo(
            virtualSize: UInt64(vmInfo.virtual_size),
            residentSize: UInt64(vmInfo.resident_size),
            sharedSize: UInt64(vmInfo.resident_size_peak) // 使用峰值作为共享内存的估算
        )
    } else {
        print("      ⚠️ TASK_VM_INFO 失败: \(vmResult), 使用基本信息")
        // 回退到基本信息
        return ProcessMemoryInfo(
            virtualSize: UInt64(basicInfo.virtual_size),
            residentSize: UInt64(basicInfo.resident_size),
            sharedSize: 0
        )
    }
}

/// 使用 sysctl 的替代方法获取进程信息
func getProcessInfoBySysctl(pid: Int32) -> (cpuUsage: Double, memoryMB: Double)? {
    var size: size_t = 0
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    
    if sysctl(&mib, 4, nil, &size, nil, 0) != 0 {
        return nil
    }
    
    var proc = kinfo_proc()
    if sysctl(&mib, 4, &proc, &size, nil, 0) != 0 {
        return nil
    }
    
    // 从 kinfo_proc 获取基本信息
    let cpuUsage = Double(proc.kp_proc.p_pctcpu) / 100.0 // p_pctcpu 是百分比值
    
    // 使用 kinfo_proc 中可用的内存信息
    // kp_eproc.e_vm 不包含我们需要的字段，所以使用其他方法
    let memoryMB = 0.0 // 占位符，sysctl 方法无法直接获取内存信息
    
    return (cpuUsage, memoryMB)
}

/// 测试 task_for_pid 错误
func testTaskForPidError(pid: Int32) {
    var task: mach_port_t = 0
    let kr = task_for_pid(mach_task_self_, pid, &task)
    
    switch kr {
    case KERN_SUCCESS:
        print("      ✅ task_for_pid 成功")
        mach_port_deallocate(mach_task_self_, task)
    case KERN_FAILURE:
        print("      ❌ KERN_FAILURE - 一般性失败")
    case KERN_INVALID_ARGUMENT:
        print("      ❌ KERN_INVALID_ARGUMENT - 无效参数")
    case KERN_NO_ACCESS:
        print("      ❌ KERN_NO_ACCESS - 权限不足")
    default:
        print("      ❌ task_for_pid 失败，错误码: \(kr)")
    }
}

/// 专门测试 Claude 进程性能
func testClaudeProcessPerformance() {
    print("\n🎯 寻找 Claude 进程进行性能测试...")
    
    var size: size_t = 0
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
    
    if sysctl(&mib, 4, nil, &size, nil, 0) != 0 {
        print("❌ 无法获取进程列表")
        return
    }
    
    let count = size / MemoryLayout<kinfo_proc>.size
    var procs = Array<kinfo_proc>(repeating: kinfo_proc(), count: count)
    
    if sysctl(&mib, 4, &procs, &size, nil, 0) != 0 {
        print("❌ 无法获取进程信息")
        return
    }
    
    let actualCount = size / MemoryLayout<kinfo_proc>.size
    var claudeProcesses: [Int32] = []
    
    for i in 0..<actualCount {
        let proc = procs[i]
        let pid = proc.kp_proc.p_pid
        
        let comm = withUnsafePointer(to: proc.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: proc.kp_proc.p_comm)) {
                String(cString: $0)
            }
        }
        
        // 检查是否是 Claude 相关进程
        if comm.lowercased() == "node" {
            if let path = getProcessPath(pid: pid), path.lowercased().contains("claude") {
                claudeProcesses.append(pid)
            }
        } else if comm.lowercased().contains("claude") {
            claudeProcesses.append(pid)
        }
    }
    
    if claudeProcesses.isEmpty {
        print("❌ 没有找到 Claude 进程")
        return
    }
    
    print("🎯 找到 \(claudeProcesses.count) 个 Claude 进程")
    
    for pid in claudeProcesses {
        print("\n🔍 Claude 进程 PID: \(pid)")
        
        if let processName = getProcessName(pid: pid) {
            print("   进程名: \(processName)")
        }
        
        if let processPath = getProcessPath(pid: pid) {
            print("   进程路径: \(processPath)")
        }
        
        // 测试性能监控
        if let cpuUsage = getProcessCPUUsage(pid: pid) {
            print("   ✅ CPU 使用率: \(String(format: "%.2f", cpuUsage))%")
        } else {
            print("   ❌ 无法获取 CPU 使用率")
        }
        
        if let memoryInfo = getProcessMemoryInfo(pid: pid) {
            print("   ✅ 内存信息: \(memoryInfo.displayText)")
        } else {
            print("   ❌ 无法获取内存信息")
        }
        
        // 测试 sysctl 方法
        if let (cpuUsage, memoryMB) = getProcessInfoBySysctl(pid: pid) {
            print("   ✅ sysctl 方法 - CPU: \(String(format: "%.2f", cpuUsage))%, 内存: \(String(format: "%.1f", memoryMB)) MB")
        } else {
            print("   ❌ sysctl 方法失败")
        }
    }
}

// 运行测试
testPerformanceMonitoring()