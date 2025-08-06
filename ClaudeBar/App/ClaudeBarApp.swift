import SwiftUI

@main
struct ClaudeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        // 主窗口
        WindowGroup {
            MainPopoverView()
                .environmentObject(appState)
                .onAppear {
                    // 将 appState 传递给 AppDelegate
                    appDelegate.appState = appState
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 600)
        
        // 设置窗口（如果需要的话）
        Settings {
            EmptyView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 0, height: 0)
    }
}