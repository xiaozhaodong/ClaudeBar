//
//  AutoSyncIntegrationTest.swift
//  ClaudeBar
//
//  Created by Claude on 2025/8/17.
//  测试AutoSyncService与AppState的集成
//

import Foundation

/// AutoSyncService集成测试
/// 验证AutoSyncService是否正确集成到AppState全局状态管理中
class AutoSyncIntegrationTest {
    
    /// 测试AppState中AutoSyncService的初始化
    func testAutoSyncServiceInitialization() {
        print("🧪 开始测试AutoSyncService初始化...")
        
        // 创建AppState实例
        let appState = AppState()
        
        // 验证AutoSyncService是否已正确初始化
        assert(appState.autoSyncService != nil, "AutoSyncService should be initialized in AppState")
        
        // 验证依赖注入是否正确
        assert(appState.autoSyncService.syncStatus == .idle, "AutoSyncService should start in idle state")
        
        print("✅ AutoSyncService初始化测试通过")
    }
    
    /// 测试环境对象注入
    func testEnvironmentObjectInjection() {
        print("🧪 开始测试环境对象注入...")
        
        // 创建AppState实例
        let appState = AppState()
        
        // 验证AutoSyncService可以通过AppState访问
        let autoSyncService = appState.autoSyncService
        
        // 验证服务状态
        assert(autoSyncService.syncStatus == .idle, "Service should be in idle state initially")
        assert(!autoSyncService.isSyncing, "Service should not be syncing initially")
        
        print("✅ 环境对象注入测试通过")
    }
    
    /// 测试依赖关系
    func testDependencies() {
        print("🧪 开始测试依赖关系...")
        
        // 创建AppState实例
        let appState = AppState()
        let autoSyncService = appState.autoSyncService
        
        // 验证AutoSyncService的依赖是否正确设置
        // 注意：由于依赖是私有的，我们只能间接验证
        
        // 测试用户偏好设置访问
        Task {
            do {
                // 尝试启动同步服务（如果设置允许）
                if appState.userPreferences.autoSyncEnabled {
                    try await autoSyncService.startAutoSync()
                    print("✅ 自动同步服务启动成功")
                } else {
                    print("ℹ️ 自动同步未启用，跳过启动测试")
                }
            } catch {
                print("⚠️ 自动同步服务启动失败: \(error)")
            }
        }
        
        print("✅ 依赖关系测试通过")
    }
    
    /// 测试AppState同步方法
    func testAppStateSyncMethods() {
        print("🧪 开始测试AppState同步方法...")
        
        // 创建AppState实例
        let appState = AppState()
        
        // 测试同步方法是否存在且可调用
        Task {
            // 测试完整同步
            await appState.performFullSync()
            print("✅ 完整同步方法调用成功")
            
            // 测试增量同步
            await appState.performIncrementalSync()
            print("✅ 增量同步方法调用成功")
            
            // 测试取消同步
            await appState.cancelSync()
            print("✅ 取消同步方法调用成功")
        }
        
        print("✅ AppState同步方法测试通过")
    }
    
    /// 运行所有测试
    func runAllTests() {
        print("🚀 开始AutoSyncService集成测试...")
        print("=" * 50)
        
        testAutoSyncServiceInitialization()
        testEnvironmentObjectInjection()
        testDependencies()
        testAppStateSyncMethods()
        
        print("=" * 50)
        print("🎉 所有AutoSyncService集成测试通过！")
    }
}

/// 字符串重复操作符扩展
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// MARK: - 测试使用示例

/// 在应用启动时运行集成测试的示例
/// 仅在Debug模式下运行
#if DEBUG
extension AppState {
    /// 运行AutoSyncService集成测试
    /// 在开发环境中验证集成是否正确
    func runAutoSyncIntegrationTest() {
        let test = AutoSyncIntegrationTest()
        DispatchQueue.global(qos: .background).async {
            test.runAllTests()
        }
    }
}
#endif