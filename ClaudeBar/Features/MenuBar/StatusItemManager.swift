import AppKit
import SwiftUI
import Combine

@MainActor
class StatusItemManager: NSObject, ObservableObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let appState: AppState
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    
    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
        setupPopover()
        setupStateObservers()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusButton = statusItem?.button else { return }
        
        // 设置图标
        statusButton.image = createStatusIcon()
        statusButton.imagePosition = .imageOnly
        statusButton.target = self
        statusButton.action = #selector(togglePopover)
        
        // 更新图标状态
        updateIcon()
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 450)
        popover?.behavior = .transient // 确保失去焦点时自动关闭
        popover?.animates = true
        
        // 设置代理以处理失去焦点的关闭事件
        popover?.delegate = self
        
        // 创建菜单栏界面
        let menuBarView = MenuBarView()
            .environmentObject(appState)
        
        popover?.contentViewController = NSHostingController(rootView: menuBarView)
    }
    
    @objc private func togglePopover() {
        guard let statusButton = statusItem?.button,
              let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // 智能刷新：只有在必要时才刷新配置
            Task {
                await appState.loadConfigsIfNeeded()
            }
            
            popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
            
            // 激活应用以确保 popover 正常显示
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func setupStateObservers() {
        // 监听当前配置变化
        appState.$currentConfig
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)
        
        // 监听加载状态变化
        appState.$isLoading
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)
        
        // 监听进程状态变化
        appState.$claudeProcessStatus
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)
        
        // 监听错误状态变化
        appState.$errorMessage
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)
        
        // 监听成功消息变化
        appState.$successMessage
            .sink { [weak self] (_: String?) in
                Task { @MainActor in
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)
    }
    
    
    private func createStatusIcon() -> NSImage? {
        let iconName = getCurrentIconName()
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        
        if let baseImage = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let image = baseImage.withSymbolConfiguration(config) ?? baseImage
            
            // 根据状态设置图标颜色
            if let tintedImage = createTintedIcon(from: image) {
                return tintedImage
            }
            
            return image
        }
        
        return nil
    }
    
    private func createTintedIcon(from image: NSImage) -> NSImage? {
        let tintColor = getCurrentIconColor()
        
        let tintedImage = NSImage(size: image.size)
        tintedImage.lockFocus()
        
        // 绘制原始图标
        image.draw(in: NSRect(origin: .zero, size: image.size))
        
        // 应用颜色遮罩
        tintColor.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        
        tintedImage.unlockFocus()
        
        return tintedImage
    }
    
    private func getCurrentIconName() -> String {
        if appState.isLoading {
            return "arrow.triangle.2.circlepath"
        } else if appState.errorMessage != nil {
            return "exclamationmark.triangle.fill"
        } else if let currentConfig = appState.currentConfig {
            if currentConfig.isValid {
                switch appState.claudeProcessStatus {
                case .running(_):
                    return "terminal.fill"
                case .stopped:
                    return "terminal"
                case .error(_):
                    return "exclamationmark.triangle.fill"
                case .unknown:
                    return "questionmark.circle.fill"
                }
            } else {
                return "exclamationmark.triangle.fill"
            }
        } else {
            return "questionmark.circle.fill"
        }
    }
    
    private func getCurrentIconColor() -> NSColor {
        if appState.isLoading {
            return NSColor.systemBlue
        } else if appState.errorMessage != nil {
            return NSColor.systemRed
        } else if let currentConfig = appState.currentConfig {
            if currentConfig.isValid {
                switch appState.claudeProcessStatus {
                case .running(_):
                    return NSColor.systemGreen
                case .stopped:
                    return NSColor.systemGray
                case .error(_):
                    return NSColor.systemRed
                case .unknown:
                    return NSColor.systemOrange
                }
            } else {
                return NSColor.systemOrange
            }
        } else {
            return NSColor.systemGray
        }
    }
    
    private func updateIcon() {
        guard let statusButton = statusItem?.button else { return }
        
        // 更新图标
        statusButton.image = createStatusIcon()
        
        // 更新工具提示
        statusButton.toolTip = createToolTip()
        
        // 添加动画效果（仅在加载时）
        if appState.isLoading {
            addLoadingAnimation(to: statusButton)
        } else {
            removeLoadingAnimation(from: statusButton)
        }
    }
    
    private func createToolTip() -> String {
        var tooltip = "Claude CLI API 切换器"
        
        if appState.isLoading {
            tooltip += " - 加载中..."
        } else if let errorMessage = appState.errorMessage {
            tooltip += " - 错误: \(errorMessage)"
        } else if let successMessage = appState.successMessage {
            tooltip += " - \(successMessage)"
        } else if let currentConfig = appState.currentConfig {
            tooltip += " - 当前: \(currentConfig.name)"
            
            switch appState.claudeProcessStatus {
            case .running(_):
                tooltip += " (运行中)"
            case .stopped:
                tooltip += " (已停止)"
            case .error(let message):
                tooltip += " (错误: \(message))"
            case .unknown:
                tooltip += " (状态未知)"
            }
        } else {
            tooltip += " - 无配置"
        }
        
        return tooltip
    }
    
    private func addLoadingAnimation(to button: NSStatusBarButton) {
        // 移除现有动画
        button.layer?.removeAllAnimations()
        
        // 添加旋转动画
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = 1.0
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        
        button.layer?.add(rotation, forKey: "loadingRotation")
    }
    
    private func removeLoadingAnimation(from button: NSStatusBarButton) {
        button.layer?.removeAnimation(forKey: "loadingRotation")
    }
    
    // MARK: - NSPopoverDelegate
    
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        // 允许popover关闭，这在失去焦点时会被调用
        return true
    }
    
    func popoverDidClose(_ notification: Notification) {
        // Popover已关闭，可以在这里执行清理工作
        print("菜单栏已隐藏")
    }
    
    deinit {
        cancellables.removeAll()
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}
