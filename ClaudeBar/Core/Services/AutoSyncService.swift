import Foundation
import SwiftUI
import Combine

// MARK: - AutoSyncServiceProtocol

/// 自动同步服务协议
/// 定义自动同步系统的核心接口，提供统一的数据同步管理
protocol AutoSyncServiceProtocol {
    
    // MARK: - 状态属性
    
    /// 当前同步状态
    var syncStatus: SyncStatus { get }
    
    /// 是否正在同步
    var isSyncing: Bool { get }
    
    /// 最后同步时间
    var lastSyncTime: Date? { get }
    
    /// 同步进度 (0.0 - 1.0)
    var syncProgress: Double { get }
    
    /// 最后同步错误
    var lastSyncError: SyncError? { get }
    
    // MARK: - 同步控制方法
    
    /// 启动自动同步
    /// 根据用户设置的间隔自动执行同步操作
    func startAutoSync() async throws
    
    /// 停止自动同步
    /// 停止定时器并清理资源
    func stopAutoSync() async
    
    /// 执行完整同步
    /// 从头开始完整同步所有数据
    /// - Returns: 同步结果统计
    func performFullSync() async throws -> SyncResult
    
    /// 执行增量同步
    /// 只同步自上次同步以来的新数据
    /// - Parameter since: 起始时间（可选，默认使用上次同步时间）
    /// - Returns: 同步结果统计
    func performIncrementalSync(since: Date?) async throws -> SyncResult
    
    /// 取消当前同步操作
    func cancelSync() async
    
    /// 暂停同步操作
    func pauseSync() async
    
    /// 恢复同步操作
    func resumeSync() async throws
    
    // MARK: - 数据管理方法
    
    /// 验证数据完整性
    /// 检查数据库与文件数据的一致性
    /// - Returns: 验证结果
    func validateDataIntegrity() async throws -> DataIntegrityResult
    
    /// 清理过期数据
    /// 根据配置清理旧的同步数据
    func cleanupExpiredData() async throws
    
    /// 获取同步统计信息
    /// 返回同步操作的详细统计数据
    /// - Returns: 同步统计信息
    func getSyncStatistics() async throws -> SyncStatistics
}

// MARK: - AutoSyncService

/// 自动同步服务实现
/// 遵循 MVVM 架构模式，提供响应式状态管理和高性能数据同步
/// 只有UI状态更新在主线程，同步逻辑在后台线程执行
class AutoSyncService: ObservableObject, AutoSyncServiceProtocol {
    
    // MARK: - Published Properties (主线程更新)
    
    /// 当前同步状态
    @Published private(set) var syncStatus: SyncStatus = .idle
    
    /// 是否正在同步
    @Published private(set) var isSyncing: Bool = false
    
    /// 最后同步时间
    @Published private(set) var lastSyncTime: Date?
    
    /// 同步进度 (0.0 - 1.0)
    @Published private(set) var syncProgress: Double = 0.0
    
    /// 最后同步错误
    @Published private(set) var lastSyncError: SyncError?
    
    /// 当前同步结果
    @Published private(set) var currentSyncResult: SyncResult?
    
    /// 自动同步是否启用
    @Published private(set) var autoSyncEnabled: Bool = false
    
    /// 自动同步定时器是否正在运行
    @Published private(set) var isAutoSyncRunning: Bool = false
    
    /// 下次同步时间
    @Published private(set) var nextSyncTime: Date?
    
    // MARK: - 计算属性
    
    /// 距离下次同步的剩余时间（秒）
    var timeUntilNextSync: TimeInterval? {
        guard let nextSyncTime = nextSyncTime else { return nil }
        let remaining = nextSyncTime.timeIntervalSinceNow
        return remaining > 0 ? remaining : 0
    }
    
    /// 下次同步倒计时显示文本
    var nextSyncCountdownText: String {
        guard let timeRemaining = timeUntilNextSync else {
            return isAutoSyncRunning ? "计算中..." : "未启用"
        }
        
        if timeRemaining <= 0 {
            return isSyncing ? "同步中..." : "即将同步"
        }
        
        let minutes = Int(timeRemaining / 60)
        let seconds = Int(timeRemaining.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒后"
        } else {
            return "\(seconds)秒后"
        }
    }
    
    /// 自动同步状态摘要
    var autoSyncStatusSummary: String {
        if !userPreferences.autoSyncEnabled {
            return "自动同步已禁用"
        }
        
        if !isAutoSyncRunning {
            return "自动同步服务已停止"
        }
        
        if isSyncing {
            return "正在同步... (\(Int(syncProgress * 100))%)"
        }
        
        let intervalName = userPreferences.currentSyncInterval.displayName
        return "每\(intervalName)自动同步，\(nextSyncCountdownText)"
    }
    
    /// 定时器健康状态
    var timerHealthStatus: String {
        
        if !isAutoSyncRunning {
            return "定时器未运行"
        }
        
        guard syncTimer != nil else {
            return "定时器不存在"
        }
        
        let stats = timerValidation.getStatsSummary()
        return "DispatchSourceTimer 运行正常\n\(stats)"
    }
    
    // MARK: - Dependencies
    
    private let usageService: HybridUsageService
    private let userPreferences: UserPreferences
    private let logger: AutoSyncLogger
    
    // MARK: - Private Properties
    
    /// 同步定时器（使用 DispatchSourceTimer 避免主线程 RunLoop 冲突）
    private var syncTimer: DispatchSourceTimer?
    
    /// 定时器有效性检查
    private var timerValidation = TimerValidation()
    
    /// 当前同步任务
    private var currentSyncTask: Task<Void, Never>?
    
    /// 取消令牌
    private var cancellationToken: CancellationToken
    
    /// 同步队列（串行，确保同步操作的线程安全）
    private let syncQueue = DispatchQueue(label: "com.claudebar.autosync", qos: .utility)
    
    /// Combine订阅集合
    private var cancellables = Set<AnyCancellable>()
    
    /// 同步开始时间（用于计算耗时）
    private var syncStartTime: Date?
    
    /// 暂停状态
    private var isPaused: Bool = false
    
    /// 暂停前的状态
    private var statusBeforePause: SyncStatus?
    
    /// 定时器锁，确保定时器操作的线程安全
    private let timerLock = NSLock()
    
    /// 应用生命周期监听是否已设置
    private var lifecycleObserversSetup: Bool = false
    
    // MARK: - Initialization
    
    /// 初始化自动同步服务
    /// - Parameters:
    ///   - usageService: 使用统计服务
    ///   - userPreferences: 用户偏好设置
    ///   - logger: 日志服务（可选，默认使用共享实例）
    init(
        usageService: HybridUsageService,
        userPreferences: UserPreferences,
        logger: AutoSyncLogger = Logger.autoSync
    ) {
        self.usageService = usageService
        self.userPreferences = userPreferences
        self.logger = logger
        self.cancellationToken = CancellationToken()
        
        // 从用户设置中读取初始状态
        self.autoSyncEnabled = userPreferences.autoSyncEnabled
        self.lastSyncTime = userPreferences.lastFullSyncDate
        
        // 监听用户设置变化
        setupPreferencesObserver()
        
        logger.info("AutoSyncService 初始化完成")
    }
    
    deinit {
        // 清理资源
        currentSyncTask?.cancel()
        syncTimer?.cancel()
        cancellables.removeAll()
        logger.info("AutoSyncService 已释放")
    }
    
    // MARK: - AutoSyncServiceProtocol Implementation
    
    /// 启动自动同步
    func startAutoSync() async throws {
        logger.syncStarted("自动同步服务", details: "间隔: \(userPreferences.currentSyncInterval.displayName)")
        
        // 验证配置有效性
        guard userPreferences.autoSyncEnabled else {
            throw SyncError.syncConfigInvalid("自动同步未启用")
        }
        
        guard userPreferences.syncInterval > 0 else {
            throw SyncError.syncIntervalInvalid
        }
        
        // 移除同步锁，避免主线程阻塞
        // 使用简单的状态检查代替锁
        if isAutoSyncRunning && syncTimer != nil {
            logger.syncSkipped("自动同步启动", reason: "定时器已在运行")
            return
        }
        
        // 停止现有定时器（如果有）
        await stopAutoSyncInternal(fromStartMethod: true)
        
        // 更新状态
        Task { @MainActor in
            autoSyncEnabled = true
            isAutoSyncRunning = true
        }
        
        // 启动定时器
        setupAutoSyncTimer()
        
        // 设置应用生命周期监听（仅首次）
        if !lifecycleObserversSetup {
            setupApplicationLifecycleObservers()
            lifecycleObserversSetup = true
        }
        
        // 发送服务启动通知
        NotificationCenter.default.post(
            name: .syncServiceDidStart,
            object: nil,
            userInfo: [
                SyncNotificationKeys.syncInterval: userPreferences.syncInterval,
                SyncNotificationKeys.autoSyncEnabled: true
            ]
        )
        
        logger.syncCompleted("自动同步服务启动", details: "下次同步: \(nextSyncTime?.formatted(date: .abbreviated, time: .shortened) ?? "未知")")
    }
    
    /// 停止自动同步
    func stopAutoSync() async {
        await stopAutoSyncInternal(fromStartMethod: false)
    }
    
    /// 内部停止自动同步方法
    private func stopAutoSyncInternal(fromStartMethod: Bool) async {
        if !fromStartMethod {
            logger.syncStarted("停止自动同步服务")
        }
        
        // 线程安全的定时器操作
        
        // 更新状态
        if !fromStartMethod {
            Task { @MainActor in
                autoSyncEnabled = false
            }
        }
        Task { @MainActor in
            isAutoSyncRunning = false
        }
        
        // 取消当前同步任务
        if !fromStartMethod {
            await cancelSync()
        }
        
        // 停止并清理定时器
        if let timer = syncTimer {
            timer.cancel()
            syncTimer = nil
        }
        
        // 清理定时器状态
        Task { @MainActor in
            nextSyncTime = nil
        }
        timerValidation.reset()
        
        // 发送服务停止通知
        if !fromStartMethod {
            NotificationCenter.default.post(
                name: .syncServiceDidStop,
                object: nil,
                userInfo: [SyncNotificationKeys.reason: "userRequest"]
            )
            
            logger.syncCompleted("自动同步服务停止")
        }
    }
    
    /// 执行完整同步
    func performFullSync() async throws -> SyncResult {
        return try await logger.measureSyncTime({
            try await performSync(type: .full)
        }, operationName: "完整同步")
    }
    
    /// 执行增量同步
    func performIncrementalSync(since: Date? = nil) async throws -> SyncResult {
        let sinceDate = since ?? lastSyncTime
        let operation = sinceDate != nil ? "增量同步" : "首次同步"
        
        return try await logger.measureSyncTime({
            try await performSync(type: .incremental(since: sinceDate))
        }, operationName: operation)
    }
    
    /// 取消当前同步操作
    func cancelSync() async {
        guard isSyncing else { return }
        
        logger.info("取消同步操作")
        
        // 设置取消标志
        cancellationToken.cancel()
        
        // 取消当前任务
        currentSyncTask?.cancel()
        currentSyncTask = nil
        
        // 更新状态
        updateSyncStatus(.cancelled)
        Task { @MainActor in
            isSyncing = false
            syncProgress = 0.0
        }
        syncStartTime = nil
        
        // 重置取消令牌
        cancellationToken = CancellationToken()
    }
    
    /// 暂停同步操作
    func pauseSync() async {
        guard isSyncing && syncStatus.canPause else { return }
        
        logger.info("暂停同步操作")
        
        // 保存当前状态
        statusBeforePause = syncStatus
        isPaused = true
        
        // 更新状态
        updateSyncStatus(.paused)
    }
    
    /// 恢复同步操作
    func resumeSync() async throws {
        guard isPaused && syncStatus.canResume else { return }
        
        logger.info("恢复同步操作")
        
        isPaused = false
        
        // 恢复之前的状态
        if let previousStatus = statusBeforePause {
            updateSyncStatus(previousStatus)
            statusBeforePause = nil
        }
    }
    
    /// 验证数据完整性
    func validateDataIntegrity() async throws -> DataIntegrityResult {
        logger.syncStarted("数据完整性验证")
        
        // 检查是否正在同步
        guard !isSyncing else {
            throw SyncError.syncInProgress
        }
        
        return try await logger.measureSyncTime({
            // TODO: 实现具体的数据完整性检查逻辑
            return DataIntegrityResult(
                isValid: true,
                checkedItems: 0,
                issuesFound: 0,
                details: []
            )
        }, operationName: "数据完整性验证")
    }
    
    /// 清理过期数据
    func cleanupExpiredData() async throws {
        logger.syncStarted("清理过期数据")
        
        return try await logger.measureSyncTime({
            // TODO: 实现具体的数据清理逻辑
            logger.syncCompleted("清理过期数据", details: "暂未实现")
        }, operationName: "清理过期数据")
    }
    
    /// 获取同步统计信息
    func getSyncStatistics() async throws -> SyncStatistics {
        // TODO: 实现同步统计信息收集
        return SyncStatistics(
            totalSyncs: 0,
            successfulSyncs: 0,
            failedSyncs: 0,
            averageSyncTime: 0,
            lastSyncDuration: 0,
            totalDataProcessed: 0
        )
    }
    
    // MARK: - Private Methods
    
    /// 执行同步操作的核心逻辑
    /// - Parameter type: 同步类型
    /// - Returns: 同步结果
    private func performSync(type: SyncType) async throws -> SyncResult {
        // 检查是否已在同步中
        guard !isSyncing else {
            throw SyncError.syncInProgress
        }
        
        // 重置状态
        Task { @MainActor in
            lastSyncError = nil
            syncProgress = 0.0
            isSyncing = true
        }
        syncStartTime = Date()
        
        // 设置同步状态
        updateSyncStatus(.preparing)
        
        // 发送同步开始通知
        NotificationCenter.default.post(
            name: .usageDataSyncDidStart,
            object: nil,
            userInfo: [SyncNotificationKeys.syncType: type.description]
        )
        
        // 创建同步任务
        return try await withTaskCancellationHandler {
            try await performSyncInternal(type: type)
        } onCancel: {
            Task { @MainActor in
                await self.cancelSync()
            }
        }
    }
    
    /// 内部同步实现
    /// - Parameter type: 同步类型
    /// - Returns: 同步结果
    private func performSyncInternal(type: SyncType) async throws -> SyncResult {
        do {
            let result = try await executeSync(type: type)
            
            // 同步成功，更新状态
            await handleSyncSuccess(result: result)
            return result
            
        } catch {
            // 同步失败，处理错误
            await handleSyncError(error)
            throw error
        }
    }
    
    /// 执行具体的同步逻辑
    /// - Parameter type: 同步类型
    /// - Returns: 同步结果
    private func executeSync(type: SyncType) async throws -> SyncResult {
        switch type {
        case .full:
            // 全量同步使用正确的 performFullDataMigration 方法
            return try await performFullSyncUsingMigration()
        case .incremental(let since):
            return try await performIncrementalSyncInternal(since: since)
        }
    }
    
    /// 使用 HybridUsageService.performFullDataMigration 执行全量同步
    /// - Returns: 同步结果
    private func performFullSyncUsingMigration() async throws -> SyncResult {
        var processedItems = 0
        var errors: [SyncError] = []
        
        logger.info("开始执行全量同步（使用 performFullDataMigration）")
        
        // 调用正确的全量数据迁移方法
        updateSyncStatus(.syncing)
        updateProgress(0.1, description: "准备全量数据迁移...")
        
        do {
            let migrationResult = try await usageService.performFullDataMigration { progress, description in
                Task { @MainActor in
                    let totalProgress = 0.1 + (progress * 0.85) // 映射到10%-95%区间
                    self.updateProgress(totalProgress, description: description)
                }
            }
            
            processedItems = migrationResult.insertedEntries
            logger.info("全量同步完成：\(migrationResult.insertedEntries) 条记录同步到数据库")
            
        } catch {
            let syncError = SyncError.databaseUpdateFailed("全量同步失败", error)
            errors.append(syncError)
            throw syncError
        }
        
        updateProgress(1.0, description: "全量同步完成")
        
        return SyncResult(
            type: .full,
            success: true,
            processedItems: processedItems,
            skippedItems: 0,
            errors: errors,
            duration: Date().timeIntervalSince(syncStartTime ?? Date()),
            startTime: syncStartTime ?? Date(),
            endTime: Date()
        )
    }
    
    /// 执行增量同步的具体实现
    /// - Parameter since: 起始时间
    /// - Returns: 同步结果
    private func performIncrementalSyncInternal(since: Date?) async throws -> SyncResult {
        var processedItems = 0
        var errors: [SyncError] = []
        
        logger.info("开始执行全量同步（替代增量同步）")
        
        // 调用全量数据迁移
        updateSyncStatus(.syncing)
        updateProgress(0.1, description: "准备全量数据迁移...")
        
        do {
            let migrationResult = try await usageService.performFullDataMigration { progress, description in
                Task { @MainActor in
                    let totalProgress = 0.1 + (progress * 0.85) // 映射到10%-95%区间
                    self.updateProgress(totalProgress, description: description)
                }
            }
            
            processedItems = migrationResult.insertedEntries
            logger.info("全量同步完成：\(migrationResult.insertedEntries) 条记录同步到数据库")
            
        } catch {
            let syncError = SyncError.databaseUpdateFailed("全量同步失败", error)
            errors.append(syncError)
            throw syncError
        }
        
        updateProgress(1.0, description: "全量同步完成")
        
        return SyncResult(
            type: .incremental(since: since),
            success: true,
            processedItems: processedItems,
            skippedItems: 0,
            errors: errors,
            duration: Date().timeIntervalSince(syncStartTime ?? Date()),
            startTime: syncStartTime ?? Date(),
            endTime: Date()
        )
    }
    
    /// 处理同步成功
    /// - Parameter result: 同步结果
    private func handleSyncSuccess(result: SyncResult) async {
        // 更新状态
        updateSyncStatus(.completed)
        Task { @MainActor in
            isSyncing = false
            lastSyncTime = Date()
            currentSyncResult = result
        }
        
        // 更新用户设置中的最后同步时间
        if case .full = result.type {
            userPreferences.lastFullSyncDate = lastSyncTime
        }
        
        // 发送成功通知
        NotificationCenter.default.post(
            name: .usageDataSyncDidComplete,
            object: nil,
            userInfo: [
                SyncNotificationKeys.success: true,
                SyncNotificationKeys.itemsCount: result.processedItems
            ]
        )
        
        logger.syncCompleted("数据同步", details: "处理 \(result.processedItems) 项，耗时 \(String(format: "%.1f", result.duration))秒")
    }
    
    /// 处理同步错误
    /// - Parameter error: 错误信息
    private func handleSyncError(_ error: Error) async {
        // 转换为同步错误类型
        let syncError: SyncError
        if let se = error as? SyncError {
            syncError = se
        } else {
            syncError = .syncDataConflict("未知同步错误: \(error.localizedDescription)")
        }
        
        // 更新状态
        updateSyncStatus(.failed)
        Task { @MainActor in
            isSyncing = false
            lastSyncError = syncError
        }
        
        // 发送错误通知
        NotificationCenter.default.post(
            name: .usageDataSyncDidComplete,
            object: nil,
            userInfo: [
                SyncNotificationKeys.success: false,
                SyncNotificationKeys.error: syncError
            ]
        )
        
        NotificationCenter.default.post(
            name: .syncErrorDidOccur,
            object: nil,
            userInfo: [
                SyncNotificationKeys.error: syncError,
                SyncNotificationKeys.context: "数据同步",
                SyncNotificationKeys.canRetry: syncError.isRecoverable
            ]
        )
        
        logger.syncError("数据同步", error: syncError)
    }
    
    /// 更新同步状态
    /// - Parameter status: 新状态
    private func updateSyncStatus(_ status: SyncStatus) {
        Task { @MainActor in
            let previousStatus = syncStatus
            syncStatus = status
            
            // 发送状态变更通知
            NotificationCenter.default.post(
                name: .syncStatusDidChange,
                object: nil,
                userInfo: [
                    SyncNotificationKeys.status: status,
                    SyncNotificationKeys.previousStatus: previousStatus
                ]
            )
            
            logger.info("同步状态变更: \(previousStatus.displayName) -> \(status.displayName)")
        }
    }
    
    /// 更新同步进度
    /// - Parameters:
    ///   - progress: 进度值 (0.0 - 1.0)
    ///   - description: 进度描述
    private func updateProgress(_ progress: Double, description: String? = nil) {
        Task { @MainActor in
            syncProgress = min(max(progress, 0.0), 1.0)
            
            // 发送进度更新通知
            NotificationCenter.default.post(
                name: .syncProgressDidUpdate,
                object: nil,
                userInfo: [
                    SyncNotificationKeys.progress: syncProgress,
                    SyncNotificationKeys.currentItem: description as Any
                ]
            )
            
            if let description = description {
                logger.syncProgress("数据同步", progress: "\(Int(progress * 100))% - \(description)")
            }
        }
    }
    
    /// 检查是否已取消
    private func checkCancellation() async throws {
        if cancellationToken.isCancelled || Task.isCancelled {
            throw SyncError.syncCancelled
        }
        
        // 检查暂停状态
        if isPaused {
            // 等待恢复或取消
            while isPaused && !cancellationToken.isCancelled && !Task.isCancelled {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        
        if cancellationToken.isCancelled || Task.isCancelled {
            throw SyncError.syncCancelled
        }
    }
    
    /// 设置自动同步定时器
    private func setupAutoSyncTimer() {
        let interval = TimeInterval(userPreferences.syncInterval)
        
        // 记录定时器创建信息
        logger.info("创建自动同步定时器，间隔: \(userPreferences.currentSyncInterval.displayName)")
        
        // 验证间隔有效性
        guard interval > 0 else {
            logger.error("无效的同步间隔: \(interval)")
            return
        }
        
        // 使用 DispatchSourceTimer 避免与 ProcessService 的 Timer 冲突
        let timer = DispatchSource.makeTimerSource(queue: syncQueue)
        syncTimer = timer
        
        // 设置定时器间隔和容差
        let intervalNanos = UInt64(interval * 1_000_000_000) // 转换为纳秒
        let toleranceNanos = UInt64(min(interval * 0.1, 30.0) * 1_000_000_000) // 最大容差30秒
        
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .nanoseconds(Int(toleranceNanos)))
        
        // 设置定时器事件处理
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.logger.info("🔥 DispatchTimer 触发，准备执行全量同步")
                await self?.handleTimerFired()
            }
        }
        
        // 启动定时器
        timer.resume()
        
        // 确认定时器创建成功
        logger.info("✅ DispatchSourceTimer 创建成功并已启动")
        
        // 记录定时器验证信息
        timerValidation.recordTimerCreation(interval: interval)
        
        // 计算并设置下次同步时间
        updateNextSyncTime()
        
        // 计算显示用的下次同步时间（避免竞态条件）
        let nextSyncDisplay = Date().addingTimeInterval(interval)
        logger.info("同步定时器已启动，间隔: \(userPreferences.currentSyncInterval.displayName)，下次执行: \(nextSyncDisplay.formatted(date: .abbreviated, time: .shortened))")
    }
    
    /// 处理定时器触发事件
    private func handleTimerFired() async {
        // 验证定时器仍然有效
        guard let timer = syncTimer else {
            logger.warning("收到定时器触发但定时器不存在，忽略")
            return
        }
        
        // 验证自动同步仍处于启用状态
        guard userPreferences.autoSyncEnabled && isAutoSyncRunning else {
            logger.info("自动同步已禁用，停止定时器")
            await stopAutoSync()
            return
        }
        
        // 检查是否有同步正在进行
        guard !isSyncing else {
            logger.syncSkipped("定时同步", reason: "上次同步仍在进行中")
            // 更新下次同步时间（延迟到下个周期）
            updateNextSyncTime()
            return
        }
        
        let scheduledTime = nextSyncTime ?? Date()
        let actualTime = Date()
        let delay = actualTime.timeIntervalSince(scheduledTime)
        
        // 记录定时器触发延迟
        if abs(delay) > 5.0 { // 延迟超过5秒记录警告
            logger.warning("定时同步触发延迟: \(String(format: "%.1f", delay))秒")
        }
        
        // 更新定时器验证统计
        timerValidation.recordTimerFired(delay: delay)
        
        // 发送定时同步触发通知
        NotificationCenter.default.post(
            name: .scheduledSyncDidTrigger,
            object: nil,
            userInfo: [
                SyncNotificationKeys.scheduledTime: scheduledTime,
                SyncNotificationKeys.actualTime: actualTime,
                SyncNotificationKeys.delay: delay
            ]
        )
        
        // 更新下次同步时间
        updateNextSyncTime()
        
        // 执行全量同步
        do {
            logger.syncStarted("定时全量同步", details: "预定时间: \(scheduledTime.formatted(date: .abbreviated, time: .shortened))")
            _ = try await performFullSync()
            
            // 记录成功的定时同步
            timerValidation.recordSuccessfulSync()
            logger.syncCompleted("定时全量同步")
            
        } catch {
            // 记录失败的定时同步
            timerValidation.recordFailedSync()
            logger.syncError("定时全量同步", error: error)
            
            // 检查是否需要停止自动同步（连续失败过多）
            if timerValidation.shouldStopAutoSync() {
                logger.warning("连续同步失败过多，暂停自动同步")
                await stopAutoSync()
                
                // 发送错误通知，建议用户检查配置
                NotificationCenter.default.post(
                    name: .syncErrorDidOccur,
                    object: nil,
                    userInfo: [
                        SyncNotificationKeys.error: error,
                        SyncNotificationKeys.context: "自动同步连续失败",
                        SyncNotificationKeys.canRetry: true
                    ]
                )
            }
        }
    }
    
    /// 更新下次同步时间
    private func updateNextSyncTime() {
        let interval = TimeInterval(userPreferences.syncInterval)
        let nextTime = Date().addingTimeInterval(interval)
        
        Task { @MainActor in
            nextSyncTime = nextTime
        }
        
        logger.debug("下次同步时间更新为: \(nextTime.formatted(date: .abbreviated, time: .shortened))")
    }
    
    /// 设置用户偏好监听
    private func setupPreferencesObserver() {
        // 监听自动同步开关变化
        userPreferences.$autoSyncEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    self.logger.info("自动同步开关变更: \(enabled ? "启用" : "禁用")")
                    
                    if enabled {
                        // 启用自动同步
                        do {
                            try await self.startAutoSync()
                        } catch {
                            self.logger.syncError("响应设置变更启动自动同步", error: error)
                        }
                    } else {
                        // 禁用自动同步
                        await self.stopAutoSync()
                    }
                }
            }
            .store(in: &cancellables)
        
        // 监听同步间隔变化
        userPreferences.$syncInterval
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newInterval in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    let intervalEnum = SyncInterval(rawValue: newInterval) ?? .fifteenMinutes
                    self.logger.info("同步间隔变更: \(intervalEnum.displayName)")
                    
                    // 如果自动同步已启用，重新启动定时器以应用新间隔
                    if self.isAutoSyncRunning && self.userPreferences.autoSyncEnabled {
                        self.logger.info("重新启动定时器以应用新的同步间隔")
                        do {
                            // 先停止现有定时器，再启动新定时器以应用新间隔
                            self.logger.debug("停止现有定时器...")
                            await self.stopAutoSync()
                            self.logger.debug("启动新定时器...")
                            try await self.startAutoSync()
                        } catch {
                            self.logger.syncError("响应间隔变更重启自动同步", error: error)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// 设置应用生命周期监听
    private func setupApplicationLifecycleObservers() {
        // 监听应用进入后台
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.logger.info("应用进入后台")
                self?.handleApplicationDidEnterBackground()
            }
            .store(in: &cancellables)
        
        // 监听应用进入前台
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.logger.info("应用进入前台")
                self?.handleApplicationDidBecomeActive()
            }
            .store(in: &cancellables)
            
        // 监听应用即将终止
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.logger.info("应用即将终止，清理自动同步资源")
                Task { @MainActor [weak self] in
                    await self?.stopAutoSync()
                }
            }
            .store(in: &cancellables)
    }
    
    /// 处理应用进入后台
    private func handleApplicationDidEnterBackground() {
        // 可以选择暂停同步或继续运行
        // 对于macOS应用，通常可以继续运行
        logger.info("应用进入后台，自动同步继续运行")
        
        // 记录进入后台的时间，用于前台恢复时的检查
        timerValidation.recordBackgroundTime()
    }
    
    /// 处理应用进入前台
    private func handleApplicationDidBecomeActive() {
        logger.info("应用进入前台")
        
        // 检查定时器是否仍然有效
        
        let needsRestart = timerValidation.shouldRestartTimerAfterBackground()
        
        if isAutoSyncRunning && userPreferences.autoSyncEnabled {
            if syncTimer != nil {
                if needsRestart {
                    logger.info("应用从后台恢复，重启自动同步定时器")
                    Task { @MainActor [weak self] in
                        do {
                            try await self?.startAutoSync()
                        } catch {
                            self?.logger.syncError("前台恢复重启自动同步", error: error)
                        }
                    }
                } else {
                    logger.info("应用从后台恢复，定时器状态正常")
                }
            } else {
                logger.warning("应用从后台恢复，发现定时器不存在，重新启动")
                Task { @MainActor [weak self] in
                    do {
                        try await self?.startAutoSync()
                    } catch {
                        self?.logger.syncError("恢复缺失定时器", error: error)
                    }
                }
            }
        }
    }
    
    // MARK: - 公共便利方法
    
    /// 重启自动同步（如果当前已启用）
    /// 用于配置变更后刷新定时器设置
    func restartAutoSyncIfNeeded() async {
        guard userPreferences.autoSyncEnabled && isAutoSyncRunning else {
            logger.info("自动同步未启用或未运行，跳过重启")
            return
        }
        
        logger.info("重启自动同步以应用最新配置")
        do {
            try await startAutoSync()
        } catch {
            logger.syncError("重启自动同步", error: error)
        }
    }
    
    /// 获取定时器统计信息
    func getTimerStatistics() -> (fires: Int, successRate: Double, averageDelay: TimeInterval) {
        
        return (
            fires: timerValidation.totalFires,
            successRate: timerValidation.successRate,
            averageDelay: timerValidation.averageDelay
        )
    }
    
    /// 强制触发一次同步（不影响定时器调度）
    func triggerManualSync() async throws -> SyncResult {
        logger.syncStarted("手动触发同步")
        return try await performIncrementalSync()
    }
    
    /// 检查定时器健康状态
    func checkTimerHealth() -> Bool {
        
        guard isAutoSyncRunning else { return false }
        guard syncTimer != nil else { return false }
        
        return true
    }
    
    /// 获取详细的自动同步状态信息
    func getDetailedStatus() -> AutoSyncDetailedStatus {
        return AutoSyncDetailedStatus(
            isEnabled: userPreferences.autoSyncEnabled,
            isRunning: isAutoSyncRunning,
            isSyncing: isSyncing,
            interval: userPreferences.currentSyncInterval,
            nextSyncTime: nextSyncTime,
            lastSyncTime: lastSyncTime,
            lastError: lastSyncError,
            timerHealth: checkTimerHealth(),
            statistics: getTimerStatistics()
        )
    }
}

// MARK: - Supporting Types

/// 自动同步详细状态信息
struct AutoSyncDetailedStatus {
    let isEnabled: Bool
    let isRunning: Bool
    let isSyncing: Bool
    let interval: SyncInterval
    let nextSyncTime: Date?
    let lastSyncTime: Date?
    let lastError: SyncError?
    let timerHealth: Bool
    let statistics: (fires: Int, successRate: Double, averageDelay: TimeInterval)
    
    /// 状态摘要文本
    var summaryText: String {
        if !isEnabled {
            return "自动同步已禁用"
        }
        
        if !isRunning {
            return "自动同步服务已停止"
        }
        
        if !timerHealth {
            return "定时器状态异常"
        }
        
        if isSyncing {
            return "正在同步中..."
        }
        
        if let nextSyncTime = nextSyncTime {
            let timeRemaining = nextSyncTime.timeIntervalSinceNow
            if timeRemaining > 0 {
                let minutes = Int(timeRemaining / 60)
                return "下次同步: \(minutes)分钟后"
            } else {
                return "即将同步"
            }
        }
        
        return "自动同步运行正常"
    }
    
    /// 健康评分 (0-100)
    var healthScore: Int {
        var score = 0
        
        // 基础功能 (40分)
        if isEnabled { score += 20 }
        if isRunning { score += 20 }
        
        // 定时器健康 (30分)
        if timerHealth { score += 30 }
        
        // 同步成功率 (30分)
        let successRateScore = Int(statistics.successRate * 30)
        score += successRateScore
        
        return min(score, 100)
    }
}

/// 同步类型
fileprivate enum SyncType {
    case full
    case incremental(since: Date?)
    
    var description: String {
        switch self {
        case .full:
            return "full"
        case .incremental:
            return "incremental"
        }
    }
}

/// 同步结果
struct SyncResult {
    fileprivate let type: SyncType
    let success: Bool
    let processedItems: Int
    let skippedItems: Int
    let errors: [SyncError]
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
    
    /// 错误数量
    var errorCount: Int {
        return errors.count
    }
    
    /// 成功率
    var successRate: Double {
        let total = processedItems + skippedItems
        guard total > 0 else { return 1.0 }
        return Double(processedItems) / Double(total)
    }
}

/// 数据完整性检查结果
struct DataIntegrityResult {
    let isValid: Bool
    let checkedItems: Int
    let issuesFound: Int
    let details: [String]
}

/// 同步统计信息
struct SyncStatistics {
    let totalSyncs: Int
    let successfulSyncs: Int
    let failedSyncs: Int
    let averageSyncTime: TimeInterval
    let lastSyncDuration: TimeInterval
    let totalDataProcessed: Int
    
    /// 成功率
    var successRate: Double {
        guard totalSyncs > 0 else { return 0.0 }
        return Double(successfulSyncs) / Double(totalSyncs)
    }
}

/// 取消令牌
private class CancellationToken {
    private(set) var isCancelled: Bool = false
    
    func cancel() {
        isCancelled = true
    }
}

/// 定时器验证和统计管理
private class TimerValidation {
    /// 定时器创建时间
    private var timerCreatedAt: Date?
    
    /// 定时器间隔
    private var timerInterval: TimeInterval = 0
    
    /// 触发次数统计
    private(set) var totalFires: Int = 0
    
    /// 成功同步次数
    private var successfulSyncs: Int = 0
    
    /// 失败同步次数
    private var failedSyncs: Int = 0
    
    /// 连续失败次数
    private var consecutiveFailures: Int = 0
    
    /// 最大连续失败次数（超过此数量将暂停自动同步）
    private let maxConsecutiveFailures: Int = 5
    
    /// 总延迟时间（秒）
    private var totalDelayTime: TimeInterval = 0
    
    /// 平均延迟时间
    var averageDelay: TimeInterval {
        return totalFires > 0 ? totalDelayTime / Double(totalFires) : 0
    }
    
    /// 成功率
    var successRate: Double {
        let totalAttempts = successfulSyncs + failedSyncs
        return totalAttempts > 0 ? Double(successfulSyncs) / Double(totalAttempts) : 1.0
    }
    
    /// 应用进入后台的时间
    private var backgroundTime: Date?
    
    /// 记录定时器创建
    func recordTimerCreation(interval: TimeInterval) {
        timerCreatedAt = Date()
        timerInterval = interval
        reset()
    }
    
    /// 记录定时器触发
    func recordTimerFired(delay: TimeInterval) {
        totalFires += 1
        totalDelayTime += abs(delay)
    }
    
    /// 记录成功同步
    func recordSuccessfulSync() {
        successfulSyncs += 1
        consecutiveFailures = 0 // 重置连续失败计数
    }
    
    /// 记录失败同步
    func recordFailedSync() {
        failedSyncs += 1
        consecutiveFailures += 1
    }
    
    /// 记录应用进入后台时间
    func recordBackgroundTime() {
        backgroundTime = Date()
    }
    
    /// 检查是否应该停止自动同步（连续失败过多）
    func shouldStopAutoSync() -> Bool {
        return consecutiveFailures >= maxConsecutiveFailures
    }
    
    /// 检查从后台恢复后是否需要重启定时器
    func shouldRestartTimerAfterBackground() -> Bool {
        guard let backgroundTime = backgroundTime,
              let timerCreatedAt = timerCreatedAt else {
            return false
        }
        
        let backgroundDuration = Date().timeIntervalSince(backgroundTime)
        let timerAge = Date().timeIntervalSince(timerCreatedAt)
        
        // 如果后台时间超过2个同步周期，或定时器运行时间超过1小时，建议重启
        return backgroundDuration > (timerInterval * 2) || timerAge > 3600
    }
    
    /// 重置统计信息
    func reset() {
        totalFires = 0
        successfulSyncs = 0
        failedSyncs = 0
        consecutiveFailures = 0
        totalDelayTime = 0
        backgroundTime = nil
    }
    
    /// 获取统计摘要
    func getStatsSummary() -> String {
        return """
        定时器统计:
        - 触发次数: \(totalFires)
        - 成功同步: \(successfulSyncs)
        - 失败同步: \(failedSyncs)
        - 连续失败: \(consecutiveFailures)
        - 成功率: \(String(format: "%.1f", successRate * 100))%
        - 平均延迟: \(String(format: "%.2f", averageDelay))秒
        """
    }
}
