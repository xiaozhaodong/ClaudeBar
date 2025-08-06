import Foundation
import os.log

/// 日志服务，用于统一管理应用日志
class Logger {
    static let shared = Logger()
    
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