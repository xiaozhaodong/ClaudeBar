# Claude 配置管理器 - CPU/内存检测优化方案

## 项目背景

**当前问题：**
- CPU 使用率检测不准确，显示为 0% 或 N/A
- 内存检测正常，但与系统活动监视器存在差异
- 沙盒环境限制了系统 API 的访问能力

**项目目标：**
- 不上架 App Store，采用直接分发
- 获得与系统活动监视器一致的 CPU/内存数据
- 简化架构，提高维护性

## 技术方案

### 方案选择：移除沙盒限制 + 系统命令

**核心思路：**
既然不上架 App Store，移除沙盒限制，直接使用系统命令获取准确的进程信息。

### 实现步骤

#### 1. 项目配置修改
- **文件：** `ClaudeConfigManager.entitlements`
- **操作：** 移除 `com.apple.security.app-sandbox` 权限
- **保留：** 必要的网络访问等权限

#### 2. ProcessService 重构
- **文件：** `ClaudeConfigManager/Core/Services/ProcessService.swift`
- **当前问题：** `libproc` API 在沙盒中功能受限
- **解决方案：** 使用 `Process()` 执行 `ps` 命令

**新的 CPU 检测实现：**
```swift
// 推荐方案：直接执行 ps 命令
ps -p <pid> -o pcpu,rss,etime

// 备选方案：优化 libproc 实现（非沙盒环境下更可靠）
proc_pidinfo(pid, PROC_PIDTASKINFO, ...)
```

#### 3. 关键修改点

**主要函数需要重写：**
- `getProcessCPUUsage(pid: Int32) -> Double?`
- `getProcessMemoryInfo(pid: Int32) -> ProcessMemoryInfo?`
- `findClaudeProcesses() -> [ClaudeProcess]`

**实现策略：**
1. 优先使用 `ps` 命令获取数据
2. 保留现有 `libproc` 实现作为降级备选
3. 添加权限检查和错误处理

#### 4. 用户体验优化
- 应用启动时检查权限状态
- 引导用户在系统偏好设置中授权
- 提供清晰的错误提示和解决建议

### 技术细节

#### CPU 使用率获取
```swift
// 新的实现方案
private func getProcessCPUUsageByCommand(pid: Int32) -> Double? {
    let process = Process()
    process.launchPath = "/bin/ps"
    process.arguments = ["-p", "\(pid)", "-o", "pcpu="]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    process.launch()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
       let cpuUsage = Double(output) {
        return cpuUsage
    }
    return nil
}
```

#### 内存使用率获取
```swift
// 获取内存信息（RSS 以 KB 为单位）
private func getProcessMemoryByCommand(pid: Int32) -> ProcessMemoryInfo? {
    let process = Process()
    process.launchPath = "/bin/ps"
    process.arguments = ["-p", "\(pid)", "-o", "rss="]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    process.launch()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
       let rssKB = UInt64(output) {
        let rssBytes = rssKB * 1024
        return ProcessMemoryInfo(
            virtualSize: 0, // ps 命令不直接提供虚拟内存大小
            residentSize: rssBytes,
            sharedSize: 0
        )
    }
    return nil
}
```

#### 权限检查
```swift
// 检查是否有执行系统命令的权限
private func checkSystemCommandPermission() -> Bool {
    let process = Process()
    process.launchPath = "/bin/ps"
    process.arguments = ["--version"]
    
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}
```

#### 综合进程信息获取
```swift
// 一次性获取进程的 CPU 和内存信息
private func getProcessInfoByCommand(pid: Int32) -> (cpu: Double?, memory: ProcessMemoryInfo?) {
    let process = Process()
    process.launchPath = "/bin/ps"
    process.arguments = ["-p", "\(pid)", "-o", "pcpu,rss"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    process.launch()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
        let lines = output.components(separatedBy: .newlines)
        if lines.count >= 2 { // 第一行是标题，第二行是数据
            let values = lines[1].trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces)
            if values.count >= 2 {
                let cpu = Double(values[0])
                if let rssKB = UInt64(values[1]) {
                    let memory = ProcessMemoryInfo(
                        virtualSize: 0,
                        residentSize: rssKB * 1024,
                        sharedSize: 0
                    )
                    return (cpu: cpu, memory: memory)
                }
            }
        }
    }
    return (cpu: nil, memory: nil)
}
```

## 预期效果

### 功能改进
- CPU 使用率数据与活动监视器完全一致
- 内存使用数据更加准确
- 实时性更好，响应更快

### 架构简化
- 移除复杂的 XPC + 特权辅助工具方案
- 代码结构更清晰，维护成本更低
- 不需要用户输入管理员密码

### 用户体验
- 一次性权限授权即可
- 安装和使用更简单
- 错误提示更友好

## 注意事项

### 分发方式
- 需要代码签名避免安全警告
- 考虑公证版本提高用户信任度
- 提供清晰的安装说明

### 兼容性
- 保留现有实现作为备选方案
- 确保在权限不足时能优雅降级
- 支持不同 macOS 版本的差异

### 安全性
- 只获取必要的进程信息
- 不保存敏感系统数据
- 遵循最小权限原则

## 相关文件

**需要修改的文件：**
1. `ClaudeConfigManager.entitlements` - 权限配置
2. `ProcessService.swift` - 核心进程检测逻辑
3. `AppState.swift` - 可能需要添加权限状态管理
4. `MenuBarView.swift` - 可能需要添加权限引导界面

**测试重点：**
1. 不同进程状态下的 CPU 检测准确性
2. 内存使用数据的精确度
3. 权限缺失时的降级行为
4. 错误处理和用户提示

## 实现优先级

### 第一阶段：基础功能
1. 修改 entitlements 文件，移除沙盒限制
2. 实现基于 `ps` 命令的 CPU/内存检测
3. 验证数据准确性

### 第二阶段：优化和容错
1. 添加权限检查机制
2. 实现降级方案
3. 优化错误处理

### 第三阶段：用户体验
1. 添加权限引导界面
2. 优化错误提示
3. 完善文档和说明

---

**创建时间：** 2025-07-29  
**版本：** 1.0  
**状态：** 待实施