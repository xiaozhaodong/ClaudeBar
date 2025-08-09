//
//  SidebarNavigationView.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI

// MARK: - Sidebar Navigation View

struct SidebarNavigationView: View {
    @Binding var selectedTab: NavigationTab
    
    var body: some View {
        VStack(spacing: 0) {
            // 应用头部
            SidebarHeaderSection()
            
            // 导航菜单项
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(NavigationTab.allCases) { tab in
                        NavigationTabItem(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Spacer()
            
            // 底部区域
            SidebarBottomSection()
        }
    }
}

// MARK: - Sidebar Header Section

struct SidebarHeaderSection: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 应用图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "terminal.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude 配置管理器")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("运行正常")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // 分隔线
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 1)
        }
    }
}

// MARK: - Sidebar Bottom Section

struct SidebarBottomSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 1)

            VStack(spacing: 8) {
                // 关闭按钮
                HStack {
                    Spacer()

                    Button(action: {
                        appState.closeMainWindow()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)

                            Text("关闭窗口")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        // 可以添加悬停效果
                    }

                    Spacer()
                }

                // 版本信息
                HStack {
                    Text("版本 1.0.0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("菜单栏应用")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}