import SwiftUI

@main
struct ClaudeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    init() {
        // 由于 @StateObject 延迟初始化的特性，我们需要在 body 中设置
    }
    
    var body: some Scene {
        let _ = {
            // 在 body 开始时立即设置 AppDelegate
            appDelegate.appState = appState
        }()
        
        return Group {
            // 主窗口 - 始终存在，通过 AppDelegate 控制显示/隐藏
            WindowGroup("ClaudeBar") {
                MainPopoverView()
                    .environmentObject(appState)
            }
            .windowStyle(.hiddenTitleBar)
            .windowResizability(.contentSize)
            .defaultSize(width: 800, height: 600)
            .defaultPosition(.center)
            
            // 设置窗口（如果需要的话）
            Settings {
                EmptyView()
            }
            .windowResizability(.contentSize)
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 0, height: 0)
        }
    }
}