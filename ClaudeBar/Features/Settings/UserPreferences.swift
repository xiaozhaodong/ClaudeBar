//
//  UserPreferences.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI
import Foundation

// 同步间隔选项枚举
enum SyncInterval: Int, CaseIterable {
    case fiveMinutes = 300      // 5分钟
    case tenMinutes = 600       // 10分钟
    case fifteenMinutes = 900   // 15分钟
    case thirtyMinutes = 1800   // 30分钟
    case oneHour = 3600         // 1小时
    
    var displayName: String {
        switch self {
        case .fiveMinutes: return "5分钟"
        case .tenMinutes: return "10分钟"
        case .fifteenMinutes: return "15分钟"
        case .thirtyMinutes: return "30分钟"
        case .oneHour: return "1小时"
        }
    }
}

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
    
    // 自动同步设置
    @Published var autoSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(autoSyncEnabled, forKey: "autoSyncEnabled") }
    }
    
    @Published var syncInterval: Int {
        didSet { UserDefaults.standard.set(syncInterval, forKey: "syncInterval") }
    }
    
    @Published var lastFullSyncDate: Date? {
        didSet { 
            if let date = lastFullSyncDate {
                UserDefaults.standard.set(date, forKey: "lastFullSyncDate")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastFullSyncDate")
            }
        }
    }
    
    @Published var showSyncNotifications: Bool {
        didSet { UserDefaults.standard.set(showSyncNotifications, forKey: "showSyncNotifications") }
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
        
        self.autoSyncEnabled = UserDefaults.standard.bool(forKey: "autoSyncEnabled")
        self.syncInterval = UserDefaults.standard.object(forKey: "syncInterval") as? Int ?? SyncInterval.fifteenMinutes.rawValue
        self.lastFullSyncDate = UserDefaults.standard.object(forKey: "lastFullSyncDate") as? Date
        self.showSyncNotifications = UserDefaults.standard.object(forKey: "showSyncNotifications") as? Bool ?? true
        
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
        autoSyncEnabled = false
        syncInterval = SyncInterval.fifteenMinutes.rawValue
        lastFullSyncDate = nil
        showSyncNotifications = true
        enableDebugLogging = false
    }
    
    // MARK: - 便利方法
    
    /// 获取当前同步间隔的枚举值
    var currentSyncInterval: SyncInterval {
        return SyncInterval(rawValue: syncInterval) ?? .fifteenMinutes
    }
    
    /// 设置同步间隔
    func setSyncInterval(_ interval: SyncInterval) {
        syncInterval = interval.rawValue
    }
}