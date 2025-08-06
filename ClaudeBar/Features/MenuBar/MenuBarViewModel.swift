import SwiftUI
import Combine

@MainActor
class MenuBarViewModel: ObservableObject {
    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    
    func setAppState(_ appState: AppState) {
        // 避免重复设置
        guard self.appState !== appState else { return }
        
        self.appState = appState
        
        // 清除之前的订阅
        cancellables.removeAll()
        
        // 监听状态变化
        appState.$currentConfig
            .removeDuplicates { $0?.name == $1?.name }
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appState.$availableConfigs
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appState.$isLoading
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func refreshConfigs() {
        guard let appState = appState else { return }
        
        // 取消之前的刷新任务
        refreshTask?.cancel()
        
        // 防止重复刷新
        guard !appState.isLoading else { return }
        
        refreshTask = Task {
            await appState.loadConfigs()
        }
    }
    
    func switchConfig(_ config: ClaudeConfig) {
        guard let appState = appState else { return }
        
        // 防止重复切换
        guard !appState.isLoading else { return }
        guard appState.currentConfig?.name != config.name else { return }
        
        Task {
            await appState.switchConfig(config)
        }
    }
    
    deinit {
        refreshTask?.cancel()
        cancellables.removeAll()
    }
}