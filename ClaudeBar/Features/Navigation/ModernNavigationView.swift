//
//  ModernNavigationView.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI

// MARK: - Modern Navigation View

struct ModernNavigationView: View {
    @Binding var selectedTab: NavigationTab
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航菜单
            SidebarNavigationView(
                selectedTab: $selectedTab
            )
            .frame(width: 280)
            .background(Color(.controlBackgroundColor))
            
            // 分隔线
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(width: 1)
            
            // 右侧内容区域
            NavigationContentView(selectedTab: selectedTab)
                .frame(maxWidth: .infinity)
                .background(Color(.windowBackgroundColor))
        }
    }
}