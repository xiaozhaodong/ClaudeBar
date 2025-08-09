import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var appState: AppState! {
        didSet {
            if appState != nil && statusItemManager == nil {
                setupStatusItemManager()
                loadConfigs()
                setupMainWindowObserver()
            }
        }
    }
    private var statusItemManager: StatusItemManager?
    private var cancellables = Set<AnyCancellable>()
    private weak var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 首次启动时显示 Dock 图标和主窗口
        NSApp.setActivationPolicy(.regular)

        // AppState 会由主应用传入，不在这里初始化
        // 如果已经有 appState，则立即设置
        if appState != nil {
            setupStatusItemManager()
            loadConfigs()

            // 设置首次启动状态（在设置观察者之前）
            appState.showingMainWindow = true

            // 然后设置观察者
            setupMainWindowObserver()
        }

        // 延迟一点查找主窗口，确保 SwiftUI 窗口已创建
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.findAndSetupMainWindow()
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
        cancellables.removeAll()
        // 清理窗口代理
        mainWindow?.delegate = nil
    }
    
    private func setupMainWindowObserver() {
        guard appState != nil else { return }
        
        // 监听主窗口状态变化
        appState.$showingMainWindow
            .sink { [weak self] (shouldShow: Bool) in
                if shouldShow {
                    self?.showMainWindow()
                } else {
                    self?.hideMainWindow()
                }
            }
            .store(in: &cancellables)
    }
    
    private func findAndSetupMainWindow() {
        // 查找 ClaudeBar 主窗口
        for window in NSApp.windows {
            // 通过窗口标题来识别主窗口（简化检测逻辑以避免泛型问题）
            if window.title == "ClaudeBar" ||
               (window.contentViewController != nil && window.title.isEmpty && window.level == .normal) {
                mainWindow = window

                // 设置窗口代理来拦截关闭事件
                window.delegate = self

                // 首次启动时显示窗口，后续根据状态决定
                if appState?.showingMainWindow == true {
                    // 显示窗口
                    window.makeKeyAndOrderFront(nil)
                    window.center()
                } else {
                    // 隐藏窗口
                    window.orderOut(nil)
                }

                break
            }
        }

        // 如果没有找到窗口，稍后再试（窗口可能还没创建完成）
        if mainWindow == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.findAndSetupMainWindow()
            }
        }
    }
    
    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 阻止窗口真正关闭，改为隐藏
        if sender === mainWindow {
            appState?.closeMainWindow()
            return false // 阻止关闭
        }
        return true // 其他窗口正常关闭
    }
    
    private func showMainWindow() {
        // 如果还没找到主窗口，先尝试查找
        if mainWindow == nil {
            findAndSetupMainWindow()
        }

        // 确保有主窗口可用
        if mainWindow == nil {
            // 如果仍然找不到窗口，尝试从所有窗口中找到合适的
            if let window = NSApp.windows.first(where: { $0.title == "ClaudeBar" || (!$0.title.isEmpty && $0.level == .normal) }) {
                mainWindow = window
                window.delegate = self
            } else {
                print("警告: 找不到主窗口")
                return
            }
        }

        // 现在可以安全地使用主窗口
        guard let window = mainWindow else {
            print("错误: 主窗口仍然为 nil")
            return
        }

        // 显示窗口时切换为普通应用模式，显示 Dock 图标
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // 显示并聚焦窗口
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.center() // 居中显示
    }
    
    private func hideMainWindow() {
        guard let window = mainWindow else { return }
        window.orderOut(nil)

        // 隐藏窗口时切换为菜单栏应用模式，隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
    }
}