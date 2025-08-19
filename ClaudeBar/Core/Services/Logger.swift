import Foundation
import os.log

/// 日志服务，用于统一管理应用日志
class Logger {
    static let shared = Logger()
    
    /// 自动同步专用日志子系统
    static let autoSync = AutoSyncLogger()
    
    private let osLog: OSLog
    
    private init() {
        self.osLog = OSLog(subsystem: "com.claude.configmanager", category: "general")
    }
    
    /// 记录信息日志
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        os_log("%@", log: osLog, type: .info, logMessage)
        print("ℹ️ \(logMessage)")
    }
    
    /// 记录警告日志
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        os_log("%@", log: osLog, type: .default, logMessage)
        print("⚠️ \(logMessage)")
    }
    
    /// 记录错误日志
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        var logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        if let error = error {
            logMessage += " - Error: \(error.localizedDescription)"
        }
        
        os_log("%@", log: osLog, type: .error, logMessage)
        print("❌ \(logMessage)")
    }
    
    /// 记录调试日志
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        os_log("%@", log: osLog, type: .debug, logMessage)
        #if DEBUG
        print("🐛 \(logMessage)")
        #endif
    }
    
    /// 记录性能相关日志
    func performance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        os_log("%@", log: osLog, type: .debug, logMessage)
        print("📊 \(logMessage)")
    }
    
    /// 测量代码执行时间
    func measureTime<T>(_ operation: () throws -> T, description: String) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        performance("\(description) 耗时: \(String(format: "%.2f", timeElapsed * 1000))ms")
        return result
    }
    
    /// 异步测量代码执行时间
    func measureTime<T>(_ operation: () async throws -> T, description: String) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        performance("\(description) 耗时: \(String(format: "%.2f", timeElapsed * 1000))ms")
        return result
    }
}

// MARK: - AutoSyncLogger

/// 自动同步专用日志记录器
class AutoSyncLogger {
    private let osLog: OSLog
    private let emoji = "🔄"
    
    fileprivate init() {
        self.osLog = OSLog(subsystem: "com.claude.configmanager", category: "autoSync")
    }
    
    // MARK: - 基础日志方法
    
    /// 记录信息日志
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        os_log("%@", log: osLog, type: .info, logMessage)
        print("\(emoji) ℹ️ \(logMessage)")
    }
    
    /// 记录调试日志
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        os_log("%@", log: osLog, type: .debug, logMessage)
        #if DEBUG
        print("\(emoji) 🐛 \(logMessage)")
        #endif
    }
    
    /// 记录警告日志
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        os_log("%@", log: osLog, type: .default, logMessage)
        print("\(emoji) ⚠️ \(logMessage)")
    }
    
    /// 记录错误日志
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        var logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        if let error = error {
            logMessage += " - Error: \(error.localizedDescription)"
        }
        
        os_log("%@", log: osLog, type: .error, logMessage)
        print("\(emoji) ❌ \(logMessage)")
    }
    
    /// 记录性能相关日志
    func performance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        os_log("%@", log: osLog, type: .debug, logMessage)
        print("\(emoji) 📊 \(logMessage)")
    }
    
    // MARK: - 同步专用便捷方法
    
    /// 记录同步开始
    func syncStarted(_ operation: String, details: String? = nil) {
        let message = details != nil ? "\(operation) 开始 - \(details!)" : "\(operation) 开始"
        info("🚀 \(message)")
    }
    
    /// 记录同步完成
    func syncCompleted(_ operation: String, details: String? = nil) {
        let message = details != nil ? "\(operation) 完成 - \(details!)" : "\(operation) 完成"
        info("✅ \(message)")
    }
    
    /// 记录同步进度
    func syncProgress(_ operation: String, progress: String) {
        info("📊 \(operation) 进度: \(progress)")
    }
    
    /// 记录同步错误
    func syncError(_ operation: String, error: Error, context: String? = nil) {
        let message = context != nil ? "\(operation) 失败 (\(context!))" : "\(operation) 失败"
        self.error("❌ \(message)", error: error)
    }
    
    /// 记录同步跳过
    func syncSkipped(_ operation: String, reason: String) {
        info("⏭️ \(operation) 跳过: \(reason)")
    }
    
    /// 记录同步冲突
    func syncConflict(_ operation: String, details: String) {
        warning("⚡ \(operation) 冲突: \(details)")
    }
    
    /// 记录数据处理统计
    func dataStats(_ operation: String, processed: Int, total: Int? = nil, unit: String = "项") {
        if let total = total {
            info("📈 \(operation) 数据统计: 已处理 \(processed)/\(total) \(unit)")
        } else {
            info("📈 \(operation) 数据统计: 已处理 \(processed) \(unit)")
        }
    }
    
    /// 记录文件操作
    func fileOperation(_ operation: String, filePath: String, result: String? = nil) {
        let message = result != nil ? "\(operation): \(filePath) - \(result!)" : "\(operation): \(filePath)"
        info("📁 \(message)")
    }
    
    /// 记录网络操作
    func networkOperation(_ operation: String, endpoint: String? = nil, result: String? = nil) {
        var message = "🌐 \(operation)"
        if let endpoint = endpoint {
            message += " (\(endpoint))"
        }
        if let result = result {
            message += " - \(result)"
        }
        info(message)
    }
    
    /// 测量同步操作执行时间
    func measureSyncTime<T>(_ operation: () throws -> T, operationName: String) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        syncStarted(operationName)
        
        let result = try operation()
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let timeString = String(format: "%.2f", timeElapsed * 1000)
        syncCompleted(operationName, details: "耗时 \(timeString)ms")
        
        return result
    }
    
    /// 异步测量同步操作执行时间
    func measureSyncTime<T>(_ operation: () async throws -> T, operationName: String) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        syncStarted(operationName)
        
        let result = try await operation()
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let timeString = String(format: "%.2f", timeElapsed * 1000)
        syncCompleted(operationName, details: "耗时 \(timeString)ms")
        
        return result
    }
    
    /// 记录批量操作进度
    func batchProgress<T>(_ items: [T], currentIndex: Int, operation: String, itemDescription: ((T) -> String)? = nil) {
        let progress = "\(currentIndex + 1)/\(items.count)"
        if let itemDescription = itemDescription {
            let itemDesc = itemDescription(items[currentIndex])
            syncProgress(operation, progress: "\(progress) - \(itemDesc)")
        } else {
            syncProgress(operation, progress: progress)
        }
    }
}