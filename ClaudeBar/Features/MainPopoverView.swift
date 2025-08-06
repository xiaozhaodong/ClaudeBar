//
//  MainPopoverView.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI

// MARK: - Main Popover View

struct MainPopoverView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MenuBarViewModel()
    @State private var selectedTab: NavigationTab = .overview
    
    var body: some View {
        NavigationView {
            // 现代化导航界面
            ModernNavigationView(
                selectedTab: $selectedTab
            )
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            viewModel.setAppState(appState)
        }
    }
}

#Preview {
    MainPopoverView()
        .environmentObject(AppState())
}