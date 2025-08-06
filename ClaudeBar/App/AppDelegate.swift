import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState! {
        didSet {
            if appState != nil && statusItemManager == nil {
                setupStatusItemManager()
                loadConfigs()
            }
        }
    }
    private var statusItemManager: StatusItemManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 显示 Dock 图标，因为现在有主窗口
        NSApp.setActivationPolicy(.regular)
        
        // AppState 会由主应用传入，不在这里初始化
        // 如果已经有 appState，则立即设置
        if appState != nil {
            setupStatusItemManager()
            loadConfigs()
        }
    }
    
    private func setupStatusItemManager() {
        guard appState != nil else { return }
        statusItemManager = StatusItemManager(appState: appState)
    }
    
    private func loadConfigs() {
        guard appState != nil else { return }
        Task {
            await appState.loadConfigs()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        statusItemManager = nil
    }
}