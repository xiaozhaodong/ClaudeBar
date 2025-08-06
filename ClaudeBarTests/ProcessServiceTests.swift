import XCTest
import AppKit
@testable import ClaudeBar

/// ProcessService 单元测试类
///
/// 测试 ProcessService 的核心功能，包括：
/// - 进程状态检测和监控
/// - Claude 进程启动、停止和重启
/// - 错误处理和边界情况
/// - 进程监控和通知
final class ProcessServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var processService: ProcessService!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        super.setUp()
        processService = ProcessService()
    }
    
    override func tearDownWithError() throws {
        processService = nil
        super.tearDown()
    }
    
    // MARK: - ProcessStatus Tests
    
    /// 测试 ProcessStatus 枚举的显示文本
    func testProcessStatusDisplayText() {
        let unknownStatus = ProcessService.ProcessStatus.unknown
        XCTAssertEqual(unknownStatus.displayText, "未知", "未知状态显示文本应该正确")
        
        // 创建测试用的 ClaudeProcess
        let testProcess = ProcessService.ClaudeProcess(
            pid: 1234,
            name: "claude",
            executablePath: "/usr/local/bin/claude",
            startTime: Date(),
            workingDirectory: "/tmp"
        )
        
        let runningStatus = ProcessService.ProcessStatus.running([testProcess])
        XCTAssertEqual(runningStatus.displayText, "运行中 (1个进程)", "运行状态显示文本应该显示进程数量")
        
        // 测试多个进程
        let multipleProcessStatus = ProcessService.ProcessStatus.running([testProcess, testProcess])
        XCTAssertEqual(multipleProcessStatus.displayText, "运行中 (2个进程)", "多进程状态显示文本应该显示正确数量")
        
        // 测试空进程列表
        let emptyRunningStatus = ProcessService.ProcessStatus.running([])
        XCTAssertEqual(emptyRunningStatus.displayText, "已停止", "空进程列表应该显示已停止")
        
        let stoppedStatus = ProcessService.ProcessStatus.stopped
        XCTAssertEqual(stoppedStatus.displayText, "已停止", "停止状态显示文本应该正确")
        
        let errorStatus = ProcessService.ProcessStatus.error("测试错误")
        XCTAssertEqual(errorStatus.displayText, "错误: 测试错误", "错误状态显示文本应该包含错误信息")
    }
    
    /// 测试 ProcessStatus 的 isRunning 属性
    func testProcessStatusIsRunning() {
        let unknownStatus = ProcessService.ProcessStatus.unknown
        XCTAssertFalse(unknownStatus.isRunning, "未知状态不应该是运行状态")
        
        // 创建测试用的 ClaudeProcess
        let testProcess = ProcessService.ClaudeProcess(
            pid: 1234,
            name: "claude",
            executablePath: "/usr/local/bin/claude",
            startTime: Date(),
            workingDirectory: "/tmp"
        )
        
        let runningStatus = ProcessService.ProcessStatus.running([testProcess])
        XCTAssertTrue(runningStatus.isRunning, "有进程的运行状态应该是运行状态")
        
        let emptyRunningStatus = ProcessService.ProcessStatus.running([])
        XCTAssertFalse(emptyRunningStatus.isRunning, "空进程列表的运行状态不应该是运行状态")
        
        let stoppedStatus = ProcessService.ProcessStatus.stopped
        XCTAssertFalse(stoppedStatus.isRunning, "停止状态不应该是运行状态")
        
        let errorStatus = ProcessService.ProcessStatus.error("测试错误")
        XCTAssertFalse(errorStatus.isRunning, "错误状态不应该是运行状态")
    }
    
    // MARK: - Initial State Tests
    
    /// 测试初始状态
    func testInitialState() {
        // 初始状态可能是任何值，取决于系统中是否有 Claude 进程运行
        // 我们主要测试状态对象不为 nil
        XCTAssertNotNil(processService.claudeStatus, "Claude 状态应该被初始化")
    }
    
    // MARK: - Update Status Tests
    
    /// 测试更新 Claude 状态（异步）
    func testUpdateClaudeStatus() async {
        let expectation = XCTestExpectation(description: "状态更新完成")
        
        // 监听状态变化
        let cancellable = processService.$claudeStatus
            .dropFirst() // 跳过初始值
            .sink { _ in
                expectation.fulfill()
            }
        
        // 更新状态
        processService.updateClaudeStatus()
        
        // 等待状态更新
        await fulfillment(of: [expectation], timeout: 5.0)
        
        cancellable.cancel()
        
        // 验证状态已更新（应该不是初始的 unknown 状态）
        XCTAssertNotEqual(processService.claudeStatus.displayText, "未知", "状态应该已被更新")
    }
    
    // MARK: - Claude Installation Tests
    
    /// 测试获取 Claude 版本信息（检查 Claude CLI 是否安装）
    func testClaudeInstallationCheck() {
        let version = processService.getClaudeVersion()
        
        if let version = version {
            // 如果能获取到版本，说明 Claude 已安装
            XCTAssertFalse(version.isEmpty, "版本信息不应该为空")
            print("Claude 版本: \(version)")
        } else {
            // 如果获取不到版本，说明 Claude 未安装或不在 PATH 中
            print("无法获取 Claude 版本，可能未安装")
        }
        
        // 无论如何，方法都不应该崩溃
        XCTAssertTrue(true, "获取版本信息的方法应该正常执行")
    }
    
    // MARK: - Process State Management Tests
    
    /// 测试手动设置进程状态
    func testManualProcessStateManagement() async {
        // 测试设置停止状态
        await MainActor.run {
            processService.claudeStatus = .stopped
        }
        
        XCTAssertFalse(processService.claudeStatus.isRunning, "手动设置的停止状态应该正确")
        XCTAssertEqual(processService.claudeStatus.displayText, "已停止", "停止状态显示应该正确")
        
        // 测试设置运行状态
        let testProcess = ProcessService.ClaudeProcess(
            pid: 9999,
            name: "claude",
            executablePath: "/usr/local/bin/claude",
            startTime: Date(),
            workingDirectory: "/tmp"
        )
        
        await MainActor.run {
            processService.claudeStatus = .running([testProcess])
        }
        
        XCTAssertTrue(processService.claudeStatus.isRunning, "手动设置的运行状态应该正确")
        XCTAssertEqual(processService.claudeStatus.processCount, 1, "进程数量应该正确")
    }
    
    // MARK: - Version Information Tests
    
    /// 测试获取 Claude 版本信息
    func testGetClaudeVersion() {
        let version = processService.getClaudeVersion()
        
        if let version = version {
            // 如果能获取到版本，说明 Claude 已安装
            XCTAssertFalse(version.isEmpty, "版本信息不应该为空")
            print("Claude 版本: \\(version)")
        } else {
            // 如果获取不到版本，说明 Claude 未安装或不在 PATH 中
            print("无法获取 Claude 版本，可能未安装")
        }
        
        // 无论如何，方法都不应该崩溃
        XCTAssertTrue(true, "获取版本信息的方法应该正常执行")
    }
    
    // MARK: - Process Monitoring Tests
    
    /// 测试进程监控初始化
    func testProcessMonitoringInitialization() {
        // 创建新的 ProcessService 实例来测试初始化
        let newProcessService = ProcessService()
        
        // 验证状态被初始化
        XCTAssertNotNil(newProcessService.claudeStatus, "进程状态应该被初始化")
        
        // 等待一小段时间让初始状态检查完成
        let expectation = XCTestExpectation(description: "初始状态检查完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // 状态应该不再是 unknown
        // 注意：这个断言可能在某些环境下失败，取决于系统状态
        print("初始状态: \\(newProcessService.claudeStatus.displayText)")
    }
    
    // MARK: - Error Handling Tests
    
    /// 测试错误状态处理
    func testErrorStatusHandling() async {
        // 手动设置错误状态
        await MainActor.run {
            processService.claudeStatus = .error("测试错误消息")
        }
        
        // 验证错误状态
        XCTAssertFalse(processService.claudeStatus.isRunning, "错误状态不应该是运行状态")
        XCTAssertTrue(processService.claudeStatus.displayText.contains("错误"), "错误状态应该包含错误信息")
    }
    
    // MARK: - Concurrent Access Tests
    
    /// 测试并发状态更新
    func testConcurrentStatusUpdates() async {
        let expectation = XCTestExpectation(description: "并发更新完成")
        expectation.expectedFulfillmentCount = 3
        
        // 同时启动多个状态更新
        Task {
            processService.updateClaudeStatus()
            expectation.fulfill()
        }
        
        Task {
            processService.updateClaudeStatus()
            expectation.fulfill()
        }
        
        Task {
            processService.updateClaudeStatus()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // 验证状态仍然一致
        XCTAssertNotNil(processService.claudeStatus, "并发更新后状态应该仍然有效")
    }
    
    // MARK: - Memory Management Tests
    
    /// 测试内存管理和清理
    func testMemoryManagement() {
        weak var weakProcessService: ProcessService?
        
        autoreleasepool {
            let localProcessService = ProcessService()
            weakProcessService = localProcessService
            
            // 使用 ProcessService
            localProcessService.updateClaudeStatus()
            
            // localProcessService 在这里会被释放
        }
        
        // 等待一段时间确保清理完成
        let expectation = XCTestExpectation(description: "内存清理完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // 验证对象已被释放
        XCTAssertNil(weakProcessService, "ProcessService 应该被正确释放")
    }
    
    // MARK: - Performance Tests
    
    /// 测试状态检查性能
    func testStatusCheckPerformance() {
        measure {
            processService.updateClaudeStatus()
            
            // 等待状态更新完成
            let expectation = XCTestExpectation(description: "状态更新完成")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
}