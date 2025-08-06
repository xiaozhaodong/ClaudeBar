import Foundation
import AppKit
import Darwin.Mach

// 定义 proc_pidpath 所需的常量和函数导入
private let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

// 导入 proc_pidpath 函数
@_silgen_name("proc_pidpath")
private func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

/// Claude 进程管理服务
///
/// 这个服务负责监控 Claude CLI 进程状态，包括：
/// - 检测 Claude 进程的运行状态
/// - 监控进程变化并实时更新状态
/// - 提供进程相关的信息查询功能
/// - 支持显示多个 Claude Code 进程
///
/// 该服务会自动监听系统进程变化通知，确保状态信息的实时性。
class ProcessService: ObservableObject {
    
    /// 进程内存信息结构体
    struct ProcessMemoryInfo: Codable, Hashable {
        let virtualSize: UInt64      // 虚拟内存大小 (字节)
        let residentSize: UInt64     // 物理内存大小 (字节)
        let sharedSize: UInt64       // 共享内存大小 (字节)
        
        /// 便于显示的格式化属性
        var virtualSizeMB: Double { Double(virtualSize) / 1024 / 1024 }
        var residentSizeMB: Double { Double(residentSize) / 1024 / 1024 }
        var sharedSizeMB: Double { Double(sharedSize) / 1024 / 1024 }
        
        /// 格式化的内存显示字符串
        var formattedResident: String {
            if residentSizeMB >= 1024 {
                return String(format: "%.1f GB", residentSizeMB / 1024)
            } else {
                return String(format: "%.1f MB", residentSizeMB)
            }
        }
    }
    
    /// Claude 单个进程信息
    struct ClaudeProcess: Identifiable, Hashable {
        let id = UUID()
        let pid: Int32
        let name: String
        let executablePath: String?
        let startTime: Date?
        let workingDirectory: String?
        let cpuUsage: Double?          // CPU 使用率百分比 (0-100)
        let memoryInfo: ProcessMemoryInfo? // 内存使用详细信息
        
        /// 进程的显示文本
        var displayText: String {
            var components = ["PID: \(pid)"]
            if let path = executablePath {
                components.append("路径: \(path)")
            }
            if let startTime = startTime {
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .medium
                components.append("启动时间: \(formatter.string(from: startTime))")
            }
            if let cpu = cpuUsage {
                components.append("CPU: \(String(format: "%.1f", cpu))%")
            }
            if let memory = memoryInfo {
                components.append("内存: \(memory.formattedResident)")
            }
            return components.joined(separator: ", ")
        }
        
        /// CPU 使用率显示字符串
        var cpuUsageText: String {
            if let cpu = cpuUsage {
                return String(format: "%.1f%%", cpu)
            } else {
                return "N/A"
            }
        }
        
        /// 内存使用显示字符串
        var memoryUsageText: String {
            if let memory = memoryInfo {
                return memory.formattedResident
            } else {
                return "N/A"
            }
        }
        
        /// CPU 使用率的颜色
        var cpuUsageColor: NSColor {
            guard let cpu = cpuUsage else { return .secondaryLabelColor }
            if cpu > 50 {
                return .systemRed
            } else if cpu > 20 {
                return .systemOrange
            } else {
                return .systemGreen
            }
        }
        
        /// 内存使用的颜色
        var memoryUsageColor: NSColor {
            guard let memory = memoryInfo else { return .secondaryLabelColor }
            let memoryMB = memory.residentSizeMB
            if memoryMB > 500 {
                return .systemRed
            } else if memoryMB > 200 {
                return .systemOrange
            } else {
                return .systemGreen
            }
        }
    }
    
    /// Claude 进程状态枚举
    ///
    /// 表示 Claude 进程的各种可能状态
    enum ProcessStatus {
        case unknown                           // 未知状态
        case running([ClaudeProcess])         // 运行中，包含进程列表
        case stopped                          // 已停止
        case error(String)                   // 错误状态，包含错误描述
        
        /// 判断是否有进程正在运行
        var isRunning: Bool {
            if case .running(let processes) = self {
                return !processes.isEmpty
            }
            return false
        }
        
        /// 获取运行中的进程数量
        var processCount: Int {
            if case .running(let processes) = self {
                return processes.count
            }
            return 0
        }
        
        /// 获取运行中的进程列表
        var processes: [ClaudeProcess] {
            if case .running(let processes) = self {
                return processes
            }
            return []
        }
        
        /// 状态显示文本
        var displayText: String {
            switch self {
            case .unknown:
                return "检查状态中..."
            case .running(let processes):
                if processes.isEmpty {
                    return "Claude 未运行"
                } else {
                    return "Claude 运行中 (\(processes.count))"
                }
            case .stopped:
                return "Claude 未运行"
            case .error(let message):
                return "状态错误: \(message)"
            }
        }
    }
    
    // MARK: - 属性
    
    /// 当前 Claude 进程状态
    @Published var processStatus: ProcessStatus = .unknown
    
    /// 进程状态刷新的时间间隔（秒）
    private let refreshInterval: TimeInterval = 5.0
    
    /// 定时器用于定期刷新进程状态
    private var statusTimer: Timer?
    
    /// 是否正在运行状态监控
    private var isMonitoring = false
    
    /// NSWorkspace 实例，用于获取运行中的应用程序
    private let workspace: NSWorkspace
    
    // MARK: - 初始化
    
    /// 初始化进程服务
    ///
    /// - Parameter workspace: NSWorkspace 实例，主要用于测试时的依赖注入
    init(workspace: NSWorkspace = NSWorkspace.shared) {
        self.workspace = workspace
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - 公共方法
    
    /// 开始监控 Claude 进程状态
    ///
    /// 启动定时器定期检查 Claude CLI 进程的运行状态
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // 立即检查一次状态
        refreshStatus()
        
        // 启动定时器
        statusTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }
    
    /// 停止监控 Claude 进程状态
    func stopMonitoring() {
        isMonitoring = false
        statusTimer?.invalidate()
        statusTimer = nil
    }
    
    /// 手动刷新进程状态
    ///
    /// 立即检查 Claude CLI 进程的运行状态并更新 `processStatus` 属性
    func refreshStatus() {
        Task { @MainActor in
            let newStatus = await checkClaudeProcessStatus()
            if !statusEqual(newStatus, processStatus) {
                processStatus = newStatus
            }
        }
    }
    
    /// 检查两个进程状态是否相等
    ///
    /// - Parameters:
    ///   - status1: 第一个状态
    ///   - status2: 第二个状态
    /// - Returns: 如果状态相等则返回 true
    private func statusEqual(_ status1: ProcessStatus, _ status2: ProcessStatus) -> Bool {
        switch (status1, status2) {
        case (.unknown, .unknown), (.stopped, .stopped):
            return true
        case (.running(let processes1), .running(let processes2)):
            return processes1 == processes2
        case (.error(let error1), .error(let error2)):
            return error1 == error2
        default:
            return false
        }
    }
    
    // MARK: - 私有方法
    
    /// 解析 ps 命令输出中的 Claude 进程信息
    ///
    /// - Parameter psLine: ps 命令的单行输出，格式：PID %CPU RSS VSZ COMM ARGS
    /// - Returns: 解析出的 ClaudeProcess 对象，如果解析失败则返回 nil
    private func parseClaudeProcessFromPS(_ psLine: String) -> ClaudeProcess? {
        let trimmedLine = psLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // 至少需要：PID %CPU RSS VSZ COMM
        guard components.count >= 5 else {
            print("⚠️  ps 输出格式不正确: \(trimmedLine)")
            return nil
        }
        
        // 解析基本字段
        guard let pid = Int32(components[0]),
              let cpuUsage = Double(components[1]),
              let rssKB = UInt64(components[2]),
              let vszKB = UInt64(components[3]) else {
            print("⚠️  无法解析进程数据: \(trimmedLine)")
            return nil
        }
        
        let comm = components[4]
        
        // 验证是否为 claude 进程
        guard comm.lowercased() == "claude" else {
            return nil
        }
        
        // 构建初始内存信息（使用 ps 的 RSS 和 VSZ，KB 单位）
        let psMemoryInfo = ProcessMemoryInfo(
            virtualSize: vszKB * 1024,  // 转换为字节
            residentSize: rssKB * 1024, // 转换为字节
            sharedSize: 0
        )
        
        // 尝试使用 top 命令获取更精确的内存数据（更接近活动监视器）
        let finalMemoryInfo = getProcessMemoryByTop(pid: pid) ?? psMemoryInfo
        
        // 获取进程的完整路径
        let executablePath = getProcessPath(pid: pid)
        
        // 构建 ClaudeProcess 对象
        let process = ClaudeProcess(
            pid: pid,
            name: "Claude CLI",
            executablePath: executablePath,
            startTime: nil,
            workingDirectory: nil,
            cpuUsage: cpuUsage,
            memoryInfo: finalMemoryInfo
        )
        
        let memorySource = (finalMemoryInfo.residentSize == psMemoryInfo.residentSize) ? "ps" : "top"
        print("📊 解析 Claude 进程: PID=\(pid), CPU=\(String(format: "%.1f%%", cpuUsage)), 内存=\(finalMemoryInfo.formattedResident) (来源:\(memorySource))")
        
        return process
    }
    
    /// 高性能的 Claude 进程发现方法（优化版）
    ///
    /// 使用单条 ps 命令直接获取所有 claude 进程的完整信息，
    /// 避免了 sysctl 的全进程扫描，大幅提升性能
    ///
    /// - Returns: 找到的 Claude CLI 进程列表
    private func findAllClaudeProcesses() -> [ClaudeProcess] {
        let startTime = Date()
        var processes = [ClaudeProcess]()
        
        // 使用 ps + grep 组合命令直接筛选 claude 进程
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "ps -eo pid,pcpu,rss,vsz,comm,args | grep claude | grep -v grep | grep -v ClaudeConfigManager"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // 忽略错误输出
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // grep 没找到匹配时退出码是 1，这是正常的
            guard process.terminationStatus == 0 || process.terminationStatus == 1 else {
                print("❌ ps+grep 命令执行失败，退出码: \(process.terminationStatus)")
                return []
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                print("❌ 无法读取 ps+grep 命令输出")
                return []
            }
            
            // 如果没有输出，说明没有找到 claude 进程
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedOutput.isEmpty {
                let duration = Date().timeIntervalSince(startTime) * 1000
                print("🚀 高性能检测完成: 找到 0 个进程，耗时 \(String(format: "%.1f", duration))ms")
                return []
            }
            
            // 解析每一行输出
            let lines = trimmedOutput.components(separatedBy: .newlines)
            for line in lines {
                if let claudeProcess = parseClaudeProcessFromPS(line) {
                    processes.append(claudeProcess)
                }
            }
            
        } catch {
            print("❌ 执行 ps+grep 命令失败: \(error)")
            return []
        }
        
        let duration = Date().timeIntervalSince(startTime) * 1000
        print("🚀 高性能检测完成: 找到 \(processes.count) 个进程，耗时 \(String(format: "%.1f", duration))ms")
        
        return processes
    }
    
    /// 检查是否有执行系统命令的权限
    ///
    /// - Returns: 如果有权限执行 ps 命令则返回 true
    private func checkSystemCommandPermission() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(getpid())", "-o", "pid="] // 检查自己的进程ID
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("无法执行 ps 命令: \(error)")
            return false
        }
    }
    
    /// 通过 ps 命令获取进程的 CPU 使用率
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: CPU 使用率百分比 (0-100)，如果无法获取则返回 nil
    private func getProcessCPUUsageByCommand(pid: Int32) -> Double? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "pcpu="]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // 忽略错误输出
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                print("ps 命令执行失败，PID: \(pid), 退出码: \(process.terminationStatus)")
                return nil
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let cpuUsage = Double(output) {
                print("进程 \(pid) 通过 ps 命令获取的 CPU 使用率: \(cpuUsage)%")
                return cpuUsage
            }
        } catch {
            print("执行 ps 命令失败: \(error)")
        }
        
        return nil
    }
    
    /// 通过 top 命令获取进程的内存信息（更接近活动监视器）
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: 进程内存信息，如果无法获取则返回 nil
    private func getProcessMemoryByTop(pid: Int32) -> ProcessMemoryInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = ["-pid", "\(pid)", "-l", "1", "-stats", "pid,mem,rsize,vsize"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // 忽略错误输出
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                print("top 命令执行失败，PID: \(pid), 退出码: \(process.terminationStatus)")
                return nil
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // 查找进程行，格式类似：14638  226M 226M N/A
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.trimmingCharacters(in: .whitespaces).hasPrefix("\(pid)") {
                        let values = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            .components(separatedBy: .whitespaces)
                            .filter { !$0.isEmpty }
                        
                        if values.count >= 3 {
                            // 解析内存值，格式如 "226M" 或 "1.5G"
                            let memString = values[1]
                            if let memBytes = parseMemorySize(memString) {
                                print("进程 \(pid) 通过 top 命令获取的内存使用: \(memString) (\(memBytes/1024/1024) MB)")
                                return ProcessMemoryInfo(
                                    virtualSize: 0, // top 的 vsize 有时显示 N/A
                                    residentSize: memBytes,
                                    sharedSize: 0
                                )
                            }
                        }
                        break
                    }
                }
            }
        } catch {
            print("执行 top 命令失败: \(error)")
        }
        
        return nil
    }
    
    /// 解析内存大小字符串（如 "226M", "1.5G"）
    ///
    /// - Parameter memString: 内存大小字符串
    /// - Returns: 内存大小（字节），如果解析失败则返回 nil
    private func parseMemorySize(_ memString: String) -> UInt64? {
        let trimmed = memString.trimmingCharacters(in: .whitespaces).uppercased()
        
        // 移除最后的单位字符
        let numberPart = String(trimmed.dropLast())
        let unit = trimmed.last
        
        guard let value = Double(numberPart) else {
            return nil
        }
        
        let multiplier: UInt64
        switch unit {
        case "K":
            multiplier = 1024
        case "M":
            multiplier = 1024 * 1024
        case "G":
            multiplier = 1024 * 1024 * 1024
        case "T":
            multiplier = 1024 * 1024 * 1024 * 1024
        default:
            // 如果没有单位，假设是字节
            multiplier = 1
        }
        
        return UInt64(value * Double(multiplier))
    }
    
    /// 通过 ps 命令获取进程的内存信息（备用方法）
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: 进程内存信息，如果无法获取则返回 nil
    private func getProcessMemoryByCommand(pid: Int32) -> ProcessMemoryInfo? {
        // 优先使用 top 命令（更接近活动监视器）
        if let memoryInfo = getProcessMemoryByTop(pid: pid) {
            return memoryInfo
        }
        
        // 回退到 ps 命令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        // 使用多个字段获取更准确的内存信息：rss (KB), vsz (KB)
        process.arguments = ["-p", "\(pid)", "-o", "rss,vsz"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // 忽略错误输出
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                print("ps 命令执行失败，PID: \(pid), 退出码: \(process.terminationStatus)")
                return nil
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let lines = output.components(separatedBy: .newlines)
                if lines.count >= 2 { // 第一行是标题，第二行是数据
                    let values = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
                    
                    if values.count >= 2 {
                        if let rssKB = UInt64(values[0]), let vszKB = UInt64(values[1]) {
                            // macOS ps 命令：RSS 和 VSZ 都以 KB 为单位
                            let rssBytes = rssKB * 1024
                            let vszBytes = vszKB * 1024
                            
                            print("进程 \(pid) 通过 ps 命令获取的内存使用（备用）: RSS=\(rssKB) KB (\(rssBytes/1024/1024) MB), VSZ=\(vszKB) KB (\(vszBytes/1024/1024) MB)")
                            
                            return ProcessMemoryInfo(
                                virtualSize: vszBytes,
                                residentSize: rssBytes,
                                sharedSize: 0
                            )
                        }
                    }
                }
            }
        } catch {
            print("执行 ps 命令失败: \(error)")
        }
        
        return nil
    }
    
    /// 通过系统命令一次性获取进程的 CPU 和内存信息
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: 包含 CPU 使用率和内存信息的元组
    private func getProcessInfoByCommand(pid: Int32) -> (cpu: Double?, memory: ProcessMemoryInfo?) {
        // 优先使用 top 命令（更准确且与活动监视器一致）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = ["-pid", "\(pid)", "-l", "1", "-stats", "pid,cpu,mem,rsize,vsize"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // 忽略错误输出
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                print("top 命令执行失败，PID: \(pid), 退出码: \(process.terminationStatus)")
                // 回退到分别获取
                return (cpu: getProcessCPUUsageByCommand(pid: pid), memory: getProcessMemoryByCommand(pid: pid))
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // 查找进程行，格式类似：14638  0.0  226M 226M N/A
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.trimmingCharacters(in: .whitespaces).hasPrefix("\(pid)") {
                        let values = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            .components(separatedBy: .whitespaces)
                            .filter { !$0.isEmpty }
                        
                        if values.count >= 4 {
                            // 解析 CPU 和内存值
                            let cpu = Double(values[1]) // CPU 百分比
                            let memString = values[2]   // 内存大小如 "226M"
                            
                            if let memBytes = parseMemorySize(memString) {
                                let memory = ProcessMemoryInfo(
                                    virtualSize: 0, // top 的 vsize 有时显示 N/A
                                    residentSize: memBytes,
                                    sharedSize: 0
                                )
                                print("进程 \(pid) 通过 top 命令获取的信息: CPU=\(cpu ?? 0)%, 内存=\(memString) (\(memBytes/1024/1024) MB)")
                                return (cpu: cpu, memory: memory)
                            }
                        } else if values.count >= 3 {
                            // 降级处理：只有部分字段
                            let cpu = Double(values[1])
                            let memString = values[2]
                            
                            if let memBytes = parseMemorySize(memString) {
                                let memory = ProcessMemoryInfo(
                                    virtualSize: 0,
                                    residentSize: memBytes,
                                    sharedSize: 0
                                )
                                print("进程 \(pid) 通过 top 命令获取的信息（简化）: CPU=\(cpu ?? 0)%, 内存=\(memString) (\(memBytes/1024/1024) MB)")
                                return (cpu: cpu, memory: memory)
                            }
                        }
                        break
                    }
                }
            }
        } catch {
            print("执行 top 命令失败: \(error)")
        }
        
        // 如果 top 命令失败，回退到 ps 命令
        return getProcessInfoByPS(pid: pid)
    }
    
    /// 通过 ps 命令获取进程信息（备用方法）
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: 包含 CPU 使用率和内存信息的元组
    private func getProcessInfoByPS(pid: Int32) -> (cpu: Double?, memory: ProcessMemoryInfo?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        // 获取 CPU（百分比）、RSS（KB）和 VSZ（KB）
        process.arguments = ["-p", "\(pid)", "-o", "pcpu,rss,vsz"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // 忽略错误输出
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                print("ps 命令执行失败，PID: \(pid), 退出码: \(process.terminationStatus)")
                return (cpu: nil, memory: nil)
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let lines = output.components(separatedBy: .newlines)
                if lines.count >= 2 { // 第一行是标题，第二行是数据
                    let values = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
                    
                    if values.count >= 3 {
                        let cpu = Double(values[0])
                        if let rssKB = UInt64(values[1]), let vszKB = UInt64(values[2]) {
                            // macOS ps 命令：RSS 和 VSZ 都以 KB 为单位
                            let rssBytes = rssKB * 1024
                            let vszBytes = vszKB * 1024
                            
                            let memory = ProcessMemoryInfo(
                                virtualSize: vszBytes,
                                residentSize: rssBytes,
                                sharedSize: 0
                            )
                            
                            print("进程 \(pid) 通过 ps 命令获取的信息（备用）: CPU=\(cpu ?? 0)%, RSS=\(rssKB) KB (\(rssBytes/1024/1024) MB), VSZ=\(vszKB) KB (\(vszBytes/1024/1024) MB)")
                            return (cpu: cpu, memory: memory)
                        }
                    } else if values.count >= 2 {
                        // 降级处理：只有 CPU 和 RSS
                        let cpu = Double(values[0])
                        if let rssKB = UInt64(values[1]) {
                            let rssBytes = rssKB * 1024
                            let memory = ProcessMemoryInfo(
                                virtualSize: 0,
                                residentSize: rssBytes,
                                sharedSize: 0
                            )
                            print("进程 \(pid) 通过 ps 命令获取的信息（简化备用）: CPU=\(cpu ?? 0)%, RSS=\(rssKB) KB (\(rssBytes/1024/1024) MB)")
                            return (cpu: cpu, memory: memory)
                        }
                    }
                }
            }
        } catch {
            print("执行 ps 命令失败: \(error)")
        }
        
        return (cpu: nil, memory: nil)
    }
    
    /// 异步检查 Claude CLI 进程状态
    ///
    /// - Returns: 当前的进程状态
    private func checkClaudeProcessStatus() async -> ProcessStatus {
        let claudeProcesses = await Task.detached { [weak self] in
            return self?.findAllClaudeProcesses() ?? []
        }.value
        
        return claudeProcesses.isEmpty ? .stopped : .running(claudeProcesses)
    }
    
    
    
    /// 获取指定进程的可执行文件路径
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: 可执行文件路径，如果无法获取则返回 nil
    private func getProcessPath(pid: Int32) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
        if pathLength > 0 {
            return String(cString: pathBuffer)
        }
        return nil
    }
    
    /// 获取进程的 CPU 使用率
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: CPU 使用率百分比 (0-100)，如果无法获取则返回 nil
    private func getProcessCPUUsage(pid: Int32) -> Double? {
        // 优先使用 ps 命令方法（非沙盒环境下更准确）
        if let cpuUsage = getProcessCPUUsageByCommand(pid: pid) {
            return cpuUsage
        }
        
        // 回退到 libproc 方法，与内存信息获取方式保持一致
        if let cpuUsage = getProcessCPUUsageByLibproc(pid: pid) {
            return cpuUsage
        }
        
        // 回退到 sysctl 方法
        if let cpuUsage = getProcessCPUUsageBySysctl(pid: pid) {
            return cpuUsage
        }
        
        // 最后回退到 task_for_pid 方法
        return getProcessCPUUsageByTaskInfo(pid: pid)
    }
    
    /// 通过 libproc 获取 CPU 使用率
    ///
    /// - Parameter pid: 进程 ID  
    /// - Returns: CPU 使用率百分比，如果无法获取则返回 nil
    private func getProcessCPUUsageByLibproc(pid: Int32) -> Double? {
        // 获取进程的任务信息
        var taskInfo = proc_taskinfo()
        let taskSize = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
        
        guard taskSize == Int32(MemoryLayout<proc_taskinfo>.size) else {
            print("无法通过 libproc 获取进程 \(pid) 的任务信息")
            return nil
        }
        
        // 使用总的 CPU 时间（纳秒）
        let totalUserTime = taskInfo.pti_total_user    // 纳秒
        let totalSystemTime = taskInfo.pti_total_system // 纳秒
        let totalCpuTime = totalUserTime + totalSystemTime
        
        print("进程 \(pid) CPU 时间: user=\(totalUserTime)ns, system=\(totalSystemTime)ns, total=\(totalCpuTime)ns")
        print("进程 \(pid) 线程信息: 总线程=\(taskInfo.pti_threadnum), 运行中=\(taskInfo.pti_numrunning)")
        
        // 获取进程启动时间
        var basicInfo = proc_bsdinfo()
        let basicSize = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &basicInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
        
        guard basicSize == Int32(MemoryLayout<proc_bsdinfo>.size) else {
            print("无法获取进程 \(pid) 的基本信息")
            return nil
        }
        
        // 计算进程运行时间
        let startTime = TimeInterval(basicInfo.pbi_start_tvsec) + TimeInterval(basicInfo.pbi_start_tvusec) / 1_000_000
        let currentTime = Date().timeIntervalSince1970
        let elapsedTime = currentTime - startTime
        
        print("进程 \(pid) 运行时间: \(elapsedTime) 秒")
        
        if elapsedTime > 0 && totalCpuTime > 0 {
            // 计算 CPU 使用率：CPU 时间 / 运行时间 * 100
            let elapsedNanos = UInt64(elapsedTime * 1_000_000_000)
            let cpuUsage = (Double(totalCpuTime) / Double(elapsedNanos)) * 100.0
            let clampedUsage = min(max(cpuUsage, 0.0), 100.0)
            
            print("进程 \(pid) 通过 libproc 计算的 CPU 使用率: \(clampedUsage)%")
            return clampedUsage
        }
        
        return nil
    }
    
    /// 通过 sysctl 获取进程 CPU 使用率
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: CPU 使用率百分比，如果无法获取则返回 nil
    private func getProcessCPUUsageBySysctl(pid: Int32) -> Double? {
        var size: size_t = 0
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        
        if sysctl(&mib, 4, nil, &size, nil, 0) != 0 {
            print("sysctl 获取进程信息大小失败，PID: \(pid)")
            return nil
        }
        
        var proc = kinfo_proc()
        if sysctl(&mib, 4, &proc, &size, nil, 0) != 0 {
            print("sysctl 获取进程信息失败，PID: \(pid)")
            return nil
        }
        
        // 检查进程状态
        let processStatus = proc.kp_proc.p_stat
        print("进程 \(pid) 状态: \(processStatus)")
        
        // p_pctcpu 是基于内核时钟周期的值
        let rawCpu = proc.kp_proc.p_pctcpu
        print("进程 \(pid) 原始 p_pctcpu 值: \(rawCpu)")
        
        // 不同的计算方法，因为 p_pctcpu 可能需要不同的转换
        if rawCpu > 0 {
            // 尝试更直接的转换方法
            let cpuUsage = Double(rawCpu) / 256.0 * 100.0
            print("进程 \(pid) 计算的 CPU 使用率: \(cpuUsage)%")
            return min(max(cpuUsage, 0.0), 100.0)
        }
        
        // 如果 p_pctcpu 为 0，尝试使用其他字段计算 CPU 使用率
        return nil
    }
    
    /// 通过 task_info 获取进程 CPU 使用率
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: CPU 使用率百分比，如果无法获取则返回 nil
    private func getProcessCPUUsageByTaskInfo(pid: Int32) -> Double? {
        var task: mach_port_t = 0
        
        // 获取进程任务句柄
        let kr = task_for_pid(mach_task_self_, pid, &task)
        guard kr == KERN_SUCCESS else {
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
            return nil
        }
        
        // 计算总 CPU 时间（用户时间 + 系统时间）
        let userTime = Double(threadInfo.user_time.seconds) + Double(threadInfo.user_time.microseconds) / 1_000_000
        let systemTime = Double(threadInfo.system_time.seconds) + Double(threadInfo.system_time.microseconds) / 1_000_000
        let totalTime = userTime + systemTime
        
        // 简化的 CPU 使用率计算
        return min(totalTime * 0.1, 100.0) // 调整系数使其更合理
    }
    
    /// 获取进程的内存使用信息
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: 进程内存信息，如果无法获取则返回 nil
    private func getProcessMemoryInfo(pid: Int32) -> ProcessMemoryInfo? {
        // 优先使用 ps 命令方法（非沙盒环境下更准确）
        if let memoryInfo = getProcessMemoryByCommand(pid: pid) {
            return memoryInfo
        }
        
        // 回退到 libproc 方法（更兼容沙盒环境）
        if let memoryInfo = getProcessMemoryInfoByLibproc(pid: pid) {
            return memoryInfo
        }
        
        // 回退到 task_for_pid 方法（仅对自己的进程有效）
        return getProcessMemoryInfoByTaskInfo(pid: pid)
    }
    
    /// 通过 libproc 获取进程内存信息
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: 进程内存信息，如果无法获取则返回 nil
    private func getProcessMemoryInfoByLibproc(pid: Int32) -> ProcessMemoryInfo? {
        // 使用 libproc 的 proc_pidinfo 获取内存信息
        var taskInfo = proc_taskinfo()
        let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
        
        guard size == Int32(MemoryLayout<proc_taskinfo>.size) else {
            return nil
        }
        
        return ProcessMemoryInfo(
            virtualSize: taskInfo.pti_virtual_size,
            residentSize: taskInfo.pti_resident_size,
            sharedSize: 0  // libproc 不直接提供共享内存信息
        )
    }
    
    /// 通过 task_info 获取进程内存信息
    ///
    /// - Parameter pid: 进程 ID
    /// - Returns: 进程内存信息，如果无法获取则返回 nil
    private func getProcessMemoryInfoByTaskInfo(pid: Int32) -> ProcessMemoryInfo? {
        var task: mach_port_t = 0
        
        // 获取进程任务句柄
        let kr = task_for_pid(mach_task_self_, pid, &task)
        guard kr == KERN_SUCCESS else {
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
            return nil
        }
        
        // 获取虚拟内存信息
        var vmInfo = task_vm_info()
        var vmInfoCount = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<integer_t>.size)
        
        let vmResult = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmInfoCount)) {
                task_info(task, task_flavor_t(TASK_VM_INFO), $0, &vmInfoCount)
            }
        }
        
        let virtualSize: UInt64
        let residentSize: UInt64
        let sharedSize: UInt64
        
        if vmResult == KERN_SUCCESS {
            virtualSize = UInt64(vmInfo.virtual_size)
            residentSize = UInt64(vmInfo.resident_size)
            sharedSize = UInt64(vmInfo.compressed)
        } else {
            // 如果无法获取详细信息，使用基本信息
            virtualSize = UInt64(basicInfo.virtual_size)
            residentSize = UInt64(basicInfo.resident_size)
            sharedSize = 0
        }
        
        return ProcessMemoryInfo(
            virtualSize: virtualSize,
            residentSize: residentSize,
            sharedSize: sharedSize
        )
    }
    
    /// 获取 Claude 版本信息（简化版）
    ///
    /// - Returns: Claude CLI 版本字符串，如果无法获取则返回 nil
    func getClaudeVersion() async -> String? {
        let commonPaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/bin/claude"
        ]
        
        for path in commonPaths {
            let task = Process()
            let pipe = Pipe()
            
            task.executableURL = URL(fileURLWithPath: path)
            task.arguments = ["--version"]
            task.standardOutput = pipe
            task.standardError = Pipe()
            
            do {
                try task.run()
                task.waitUntilExit()
                
                guard task.terminationStatus == 0 else { continue }
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !version.isEmpty {
                    return version
                }
            } catch {
                // 尝试下一个路径
                continue
            }
        }
        
        return nil
    }
}