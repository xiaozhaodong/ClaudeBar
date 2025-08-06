//
//  OverviewPageView.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI

// MARK: - Overview Page View

struct OverviewPageView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 欢迎区域
                WelcomeSection()
                
                // 当前配置卡片
                CurrentConfigOverviewCard(currentConfig: appState.currentConfig)
                
                // 快速状态概览
                QuickStatusOverview()
                
                // 最近活动
                RecentActivitySection()
            }
            .padding(24)
        }
        .navigationTitle("概览")
    }
}

// MARK: - Welcome Section

struct WelcomeSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("欢迎使用 Claude 配置管理器")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("管理和切换您的 Claude CLI 配置")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }
}

// MARK: - Current Config Overview Card

struct CurrentConfigOverviewCard: View {
    let currentConfig: ClaudeConfig?
    
    private var statusColor: Color {
        if let config = currentConfig {
            return config.isValid ? .green : .red
        } else {
            return .orange
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("当前配置")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            
            if let config = currentConfig {
                VStack(spacing: 12) {
                    MainConfigDetailRow(
                        icon: "text.badge.checkmark",
                        label: "配置名称",
                        value: config.name,
                        valueColor: .primary
                    )
                    
                    MainConfigDetailRow(
                        icon: "link",
                        label: "API 端点",
                        value: config.baseURLDisplay,
                        valueColor: .secondary
                    )
                    
                    MainConfigDetailRow(
                        icon: "key.fill",
                        label: "API Token",
                        value: config.tokenPreview,
                        valueColor: .secondary
                    )
                    
                    MainConfigDetailRow(
                        icon: "checkmark.shield.fill",
                        label: "配置状态",
                        value: config.isValid ? "正常" : "无效",
                        valueColor: config.isValid ? .green : .red
                    )
                }
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                        
                        Text("暂无当前配置")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    Text("请先选择或创建一个配置文件")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

// MARK: - Quick Status Overview (Placeholder)

struct QuickStatusOverview: View {
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatusOverviewCard(
                title: "可用配置",
                value: "3",
                icon: "gearshape.2.fill",
                color: .blue
            )
            
            StatusOverviewCard(
                title: "Claude 进程",
                value: "运行中",
                icon: "terminal.fill",
                color: .green
            )
            
            StatusOverviewCard(
                title: "系统状态",
                value: "正常",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }
}

// MARK: - Status Overview Card

struct StatusOverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

// MARK: - Recent Activity Section

struct RecentActivitySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近活动")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ActivityItem(
                    icon: "arrow.clockwise",
                    title: "刷新配置列表",
                    time: "刚刚",
                    color: .blue
                )
                
                ActivityItem(
                    icon: "gearshape.fill",
                    title: "切换到生产配置",
                    time: "5分钟前",
                    color: .green
                )
                
                ActivityItem(
                    icon: "folder.fill",
                    title: "打开配置目录",
                    time: "10分钟前",
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

// MARK: - Activity Item

struct ActivityItem: View {
    let icon: String
    let title: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Main Config Detail Row

struct MainConfigDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 4)
    }
}