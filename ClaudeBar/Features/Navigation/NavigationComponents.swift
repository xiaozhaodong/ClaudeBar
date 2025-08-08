//
//  NavigationComponents.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI

// MARK: - Navigation Tab Item

struct NavigationTabItem: View {
    let tab: NavigationTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(tab.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(textColor)
                
                Spacer()
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 3, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundFill)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var iconColor: Color {
        if isSelected {
            return .blue
        } else {
            return isHovered ? .primary : .secondary
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .primary
        } else {
            return isHovered ? .primary : .secondary
        }
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return Color.blue.opacity(0.1)
        } else if isHovered {
            return Color.gray.opacity(0.08)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Navigation Content View

struct NavigationContentView: View {
    let selectedTab: NavigationTab
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            switch selectedTab {
            case .configManagement:
                ConfigManagementPageView()
            case .usageStatistics:
                UsageStatisticsView(configService: appState.configService)
            case .processMonitor:
                ProcessMonitorPageView()
            case .systemStatus:
                SystemStatusPageView()
            case .toolbox:
                ToolboxPageView()
            case .settings:
                SettingsPageView()
            case .help:
                HelpPageView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
    }
}