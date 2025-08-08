//
//  NavigationTab.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI

// MARK: - Navigation Tab Definition

enum NavigationTab: String, CaseIterable, Identifiable {
    case configManagement = "config"
    case usageStatistics = "usage"
    case processMonitor = "process"
    case systemStatus = "system"
    case toolbox = "toolbox"
    case settings = "settings"
    case help = "help"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .configManagement:
            return "API 端点管理"
        case .usageStatistics:
            return "使用统计"
        case .processMonitor:
            return "进程监控"
        case .systemStatus:
            return "系统状态"
        case .toolbox:
            return "工具箱"
        case .settings:
            return "设置"
        case .help:
            return "帮助"
        }
    }
    
    var icon: String {
        switch self {
        case .configManagement:
            return "gearshape.2.fill"
        case .usageStatistics:
            return "chart.bar.fill"
        case .processMonitor:
            return "chart.line.uptrend.xyaxis"
        case .systemStatus:
            return "info.circle.fill"
        case .toolbox:
            return "wrench.and.screwdriver.fill"
        case .settings:
            return "gearshape.fill"
        case .help:
            return "questionmark.circle.fill"
        }
    }
}