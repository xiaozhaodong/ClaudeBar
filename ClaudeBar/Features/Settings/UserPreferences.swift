//
//  UserPreferences.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI
import Foundation

class UserPreferences: ObservableObject {
    // 应用设置
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    
    @Published var hideDockIcon: Bool {
        didSet { UserDefaults.standard.set(hideDockIcon, forKey: "hideDockIcon") }
    }
    
    @Published var showInStatusBar: Bool {
        didSet { UserDefaults.standard.set(showInStatusBar, forKey: "showInStatusBar") }
    }
    
    // 通知设置
    @Published var showSuccessNotifications: Bool {
        didSet { UserDefaults.standard.set(showSuccessNotifications, forKey: "showSuccessNotifications") }
    }
    
    @Published var showErrorNotifications: Bool {
        didSet { UserDefaults.standard.set(showErrorNotifications, forKey: "showErrorNotifications") }
    }
    
    // 自动刷新设置
    @Published var enableAutoRefresh: Bool {
        didSet { UserDefaults.standard.set(enableAutoRefresh, forKey: "enableAutoRefresh") }
    }
    
    @Published var refreshInterval: Int {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }
    
    // 界面设置
    @Published var compactMode: Bool {
        didSet { UserDefaults.standard.set(compactMode, forKey: "compactMode") }
    }
    
    @Published var enableAnimations: Bool {
        didSet { UserDefaults.standard.set(enableAnimations, forKey: "enableAnimations") }
    }
    
    // 外观设置
    @Published var colorScheme: String {
        didSet { UserDefaults.standard.set(colorScheme, forKey: "colorScheme") }
    }
    
    @Published var accentColor: String {
        didSet { UserDefaults.standard.set(accentColor, forKey: "accentColor") }
    }
    
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    
    @Published var menuBarIconStyle: String {
        didSet { UserDefaults.standard.set(menuBarIconStyle, forKey: "menuBarIconStyle") }
    }
    
    // 开发者选项
    @Published var enableDebugLogging: Bool {
        didSet { UserDefaults.standard.set(enableDebugLogging, forKey: "enableDebugLogging") }
    }
    
    init() {
        // 初始化所有设置，从 UserDefaults 读取或使用默认值
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.hideDockIcon = UserDefaults.standard.bool(forKey: "hideDockIcon")
        self.showInStatusBar = UserDefaults.standard.object(forKey: "showInStatusBar") as? Bool ?? true
        
        self.showSuccessNotifications = UserDefaults.standard.object(forKey: "showSuccessNotifications") as? Bool ?? true
        self.showErrorNotifications = UserDefaults.standard.object(forKey: "showErrorNotifications") as? Bool ?? true
        
        self.enableAutoRefresh = UserDefaults.standard.bool(forKey: "enableAutoRefresh")
        self.refreshInterval = UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 30
        
        self.compactMode = UserDefaults.standard.bool(forKey: "compactMode")
        self.enableAnimations = UserDefaults.standard.object(forKey: "enableAnimations") as? Bool ?? true
        
        self.colorScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "auto"
        self.accentColor = UserDefaults.standard.string(forKey: "accentColor") ?? "blue"
        self.fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Double ?? 14.0
        self.menuBarIconStyle = UserDefaults.standard.string(forKey: "menuBarIconStyle") ?? "terminal"
        
        self.enableDebugLogging = UserDefaults.standard.bool(forKey: "enableDebugLogging")
    }
    
    func resetToDefaults() {
        launchAtLogin = false
        hideDockIcon = false
        showInStatusBar = true
        showSuccessNotifications = true
        showErrorNotifications = true
        enableAutoRefresh = false
        refreshInterval = 30
        compactMode = false
        enableAnimations = true
        colorScheme = "auto"
        accentColor = "blue"
        fontSize = 14.0
        menuBarIconStyle = "terminal"
        enableDebugLogging = false
    }
}