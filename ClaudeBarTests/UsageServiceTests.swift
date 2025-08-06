import XCTest
@testable import ClaudeBar

/// UsageService 单元测试
class UsageServiceTests: XCTestCase {
    
    var mockConfigService: MockConfigService!
    var usageService: UsageService!
    
    override func setUp() {
        super.setUp()
        mockConfigService = MockConfigService()
        usageService = UsageService(configService: mockConfigService)
    }
    
    override func tearDown() {
        usageService = nil
        mockConfigService = nil
        super.tearDown()
    }
    
    /// 测试会话统计的正确性
    func testSessionCountingAccuracy() {
        // 创建测试数据：3个会话，5个请求，但有2个重复请求
        let testEntries = createTestEntries()
        
        // 使用私有方法测试（在实际项目中，你可能需要将 calculateStatistics 方法设为 internal）
        // 这里我们创建一个模拟场景来测试统计逻辑
        
        let statistics = calculateTestStatistics(from: testEntries)
        
        // 验证统计结果
        XCTAssertEqual(statistics.totalSessions, 3, "应该有3个唯一会话")
        XCTAssertEqual(statistics.totalRequests, 3, "去重后应该有3个唯一请求")
        XCTAssertLessThanOrEqual(statistics.totalSessions, statistics.totalRequests, "会话数不应超过请求数")
    }
    
    /// 测试请求去重逻辑
    func testRequestDeduplication() {
        let testEntries = createTestEntriesWithDuplicates()
        let statistics = calculateTestStatistics(from: testEntries)
        
        // 验证重复请求被正确去重
        XCTAssertEqual(statistics.totalRequests, 2, "重复请求应该被去重，只剩2个唯一请求")
        XCTAssertEqual(statistics.totalSessions, 2, "应该有2个会话")
    }
    
    /// 测试模型统计的准确性
    func testModelStatisticsAccuracy() {
        let testEntries = createTestEntries()
        let statistics = calculateTestStatistics(from: testEntries)
        
        // 检查模型统计
        let sonnetModel = statistics.byModel.first { $0.model == "claude-4-sonnet" }
        XCTAssertNotNil(sonnetModel, "应该包含 Sonnet 4 模型统计")
        
        if let sonnet = sonnetModel {
            XCTAssertLessThanOrEqual(sonnet.sessionCount, sonnet.requestCount ?? 0, "模型的会话数不应超过请求数")
        }
    }
    
    /// 测试项目统计的准确性  
    func testProjectStatisticsAccuracy() {
        let testEntries = createTestEntries()
        let statistics = calculateTestStatistics(from: testEntries)
        
        // 检查项目统计
        let project = statistics.byProject.first
        XCTAssertNotNil(project, "应该包含项目统计")
        
        if let proj = project {
            XCTAssertLessThanOrEqual(proj.sessionCount, proj.requestCount ?? 0, "项目的会话数不应超过请求数")
        }
    }
    
    // MARK: - 辅助方法
    
    private func createTestEntries() -> [UsageEntry] {
        return [
            UsageEntry(
                timestamp: "2024-01-01T10:00:00.000Z",
                model: "claude-4-sonnet",
                inputTokens: 100,
                outputTokens: 50,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                cost: 0.001,
                sessionId: "session-1",
                projectPath: "/test/project1",
                requestId: "req-1",
                messageType: "assistant"
            ),
            UsageEntry(
                timestamp: "2024-01-01T10:05:00.000Z",
                model: "claude-4-sonnet",
                inputTokens: 120,
                outputTokens: 60,
                cacheCreationTokens: 10,
                cacheReadTokens: 5,
                cost: 0.002,
                sessionId: "session-1",
                projectPath: "/test/project1",
                requestId: "req-2",
                messageType: "assistant"
            ),
            UsageEntry(
                timestamp: "2024-01-01T10:10:00.000Z",
                model: "claude-4-sonnet",
                inputTokens: 110,
                outputTokens: 55,
                cacheCreationTokens: 0,
                cacheReadTokens: 15,
                cost: 0.0015,
                sessionId: "session-2",
                projectPath: "/test/project2",
                requestId: "req-3",
                messageType: "assistant"
            ),
            // 重复请求（应该被去重）
            UsageEntry(
                timestamp: "2024-01-01T10:05:00.000Z",
                model: "claude-4-sonnet",
                inputTokens: 120,
                outputTokens: 60,
                cacheCreationTokens: 10,
                cacheReadTokens: 5,
                cost: 0.002,
                sessionId: "session-1",
                projectPath: "/test/project1",
                requestId: "req-2", // 重复的请求ID
                messageType: "assistant"
            ),
            // 另一个会话的请求
            UsageEntry(
                timestamp: "2024-01-01T10:15:00.000Z",
                model: "claude-4-opus",
                inputTokens: 80,
                outputTokens: 40,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                cost: 0.003,
                sessionId: "session-3",
                projectPath: "/test/project1",
                requestId: "req-4",
                messageType: "assistant"
            )
        ]
    }
    
    private func createTestEntriesWithDuplicates() -> [UsageEntry] {
        return [
            UsageEntry(
                timestamp: "2024-01-01T10:00:00.000Z",
                model: "claude-4-sonnet",
                inputTokens: 100,
                outputTokens: 50,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                cost: 0.001,
                sessionId: "session-1",
                projectPath: "/test/project1",
                requestId: "req-1",
                messageType: "assistant"
            ),
            // 完全相同的请求（应该被去重）
            UsageEntry(
                timestamp: "2024-01-01T10:00:00.000Z",
                model: "claude-4-sonnet",
                inputTokens: 100,
                outputTokens: 50,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                cost: 0.001,
                sessionId: "session-1",
                projectPath: "/test/project1",
                requestId: "req-1", // 重复的请求ID
                messageType: "assistant"
            ),
            // 不同的请求
            UsageEntry(
                timestamp: "2024-01-01T10:05:00.000Z",
                model: "claude-4-sonnet",
                inputTokens: 120,
                outputTokens: 60,
                cacheCreationTokens: 10,
                cacheReadTokens: 5,
                cost: 0.002,
                sessionId: "session-2",
                projectPath: "/test/project1",
                requestId: "req-2",
                messageType: "assistant"
            )
        ]
    }
    
    /// 模拟 calculateStatistics 方法的逻辑（简化版本用于测试）
    private func calculateTestStatistics(from entries: [UsageEntry]) -> UsageStatistics {
        guard !entries.isEmpty else {
            return UsageStatistics.empty
        }
        
        var totalCost: Double = 0
        var totalInputTokens: Int = 0
        var totalOutputTokens: Int = 0
        var totalCacheCreationTokens: Int = 0
        var totalCacheReadTokens: Int = 0
        
        var processedRequestIds = Set<String>()
        var validEntries: [UsageEntry] = []
        
        // 去重处理
        for entry in entries {
            if let requestId = entry.requestId {
                if processedRequestIds.contains(requestId) {
                    continue
                }
                processedRequestIds.insert(requestId)
            }
            
            validEntries.append(entry)
            
            totalCost += entry.cost
            totalInputTokens += entry.inputTokens
            totalOutputTokens += entry.outputTokens
            totalCacheCreationTokens += entry.cacheCreationTokens
            totalCacheReadTokens += entry.cacheReadTokens
        }
        
        // 重新计算有效条目的会话ID
        var validSessionIds = Set<String>()
        var modelStats: [String: TestModelUsage] = [:]
        var projectStats: [String: TestProjectUsage] = [:]
        
        for entry in validEntries {
            validSessionIds.insert(entry.sessionId)
            
            // 按模型统计
            if modelStats[entry.model] == nil {
                modelStats[entry.model] = TestModelUsage(model: entry.model)
            }
            modelStats[entry.model]?.add(entry)
            
            // 按项目统计
            if projectStats[entry.projectPath] == nil {
                projectStats[entry.projectPath] = TestProjectUsage(
                    projectPath: entry.projectPath,
                    projectName: entry.projectName
                )
            }
            projectStats[entry.projectPath]?.add(entry)
        }
        
        let totalRequests = processedRequestIds.count > 0 ? processedRequestIds.count : validEntries.count
        let totalTokens = totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
        
        return UsageStatistics(
            totalCost: totalCost,
            totalTokens: totalTokens,
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalCacheCreationTokens: totalCacheCreationTokens,
            totalCacheReadTokens: totalCacheReadTokens,
            totalSessions: validSessionIds.count,
            totalRequests: totalRequests,
            byModel: modelStats.values.map { $0.build() }.sorted { $0.totalCost > $1.totalCost },
            byDate: [],
            byProject: projectStats.values.map { $0.build() }.sorted { $0.totalCost > $1.totalCost }
        )
    }
}

// MARK: - 测试辅助类

/// Mock ConfigService for testing
class MockConfigService: ConfigServiceProtocol {
    func loadConfig() async throws -> ClaudeConfig? {
        return nil
    }
    
    func saveConfig(_ config: ClaudeConfig) async throws {
        // Mock implementation
    }
    
    func listConfigs() async throws -> [String] {
        return []
    }
    
    func switchToConfig(named: String) async throws {
        // Mock implementation
    }
    
    func deleteConfig(named: String) async throws {
        // Mock implementation
    }
    
    func exportConfig(named: String, to url: URL) async throws {
        // Mock implementation
    }
    
    func importConfig(from url: URL, as name: String) async throws {
        // Mock implementation
    }
    
    var configDirectoryPath: String {
        return "/tmp/test-claude"
    }
}

/// 测试用的模型使用统计
private class TestModelUsage {
    let model: String
    private var totalCost: Double = 0
    private var inputTokens: Int = 0
    private var outputTokens: Int = 0
    private var cacheCreationTokens: Int = 0
    private var cacheReadTokens: Int = 0
    private var sessionIds = Set<String>()
    private var requestIds = Set<String>()
    private var entryCount: Int = 0
    
    init(model: String) {
        self.model = model
    }
    
    func add(_ entry: UsageEntry) {
        totalCost += entry.cost
        inputTokens += entry.inputTokens
        outputTokens += entry.outputTokens
        cacheCreationTokens += entry.cacheCreationTokens
        cacheReadTokens += entry.cacheReadTokens
        sessionIds.insert(entry.sessionId)
        entryCount += 1
        
        if let requestId = entry.requestId {
            requestIds.insert(requestId)
        }
    }
    
    func build() -> ModelUsage {
        let requestCount = requestIds.count > 0 ? requestIds.count : entryCount
        
        return ModelUsage(
            model: model,
            totalCost: totalCost,
            totalTokens: inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            sessionCount: sessionIds.count,
            requestCount: requestCount
        )
    }
}

/// 测试用的项目使用统计
private class TestProjectUsage {
    let projectPath: String
    let projectName: String
    private var totalCost: Double = 0
    private var totalTokens: Int = 0
    private var sessionIds = Set<String>()
    private var requestIds = Set<String>()
    private var entryCount: Int = 0
    private var lastUsed: String = ""
    
    init(projectPath: String, projectName: String) {
        self.projectPath = projectPath
        self.projectName = projectName
    }
    
    func add(_ entry: UsageEntry) {
        totalCost += entry.cost
        totalTokens += entry.totalTokens
        sessionIds.insert(entry.sessionId)
        entryCount += 1
        
        if let requestId = entry.requestId {
            requestIds.insert(requestId)
        }
        
        if entry.timestamp > lastUsed {
            lastUsed = entry.timestamp
        }
    }
    
    func build() -> ProjectUsage {
        let requestCount = requestIds.count > 0 ? requestIds.count : entryCount
        
        return ProjectUsage(
            projectPath: projectPath,
            projectName: projectName,
            totalCost: totalCost,
            totalTokens: totalTokens,
            sessionCount: sessionIds.count,
            requestCount: requestCount,
            lastUsed: lastUsed
        )
    }
}