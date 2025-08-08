import SwiftUI
import Foundation

/// 缓存状态指示器组件
struct CacheStatusIndicator: View {
    let status: CacheStatus
    let metadata: CacheMetadata?
    let onRefresh: () async -> Void
    
    @State private var isHovered = false
    @State private var showTooltip = false
    @State private var currentTime = Date()
    
    // 定时器用于更新时间显示
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 状态图标
            statusIcon
            
            // 状态信息
            statusInfo
            
            // 刷新按钮（仅在需要时显示）
            if status.needsRefresh {
                refreshButton
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(statusBackgroundColor)
        .cornerRadius(DesignTokens.Size.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                .stroke(statusBorderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
                showTooltip = hovering
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .overlay(
            // 提示信息
            tooltipView,
            alignment: .topTrailing
        )
    }
    
    /// 状态图标
    private var statusIcon: some View {
        Image(systemName: status.iconName)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color(
                red: status.color.red,
                green: status.color.green,
                blue: status.color.blue
            ))
            .rotationEffect(.degrees(status == .loading ? 360 : 0))
            .animation(
                status == .loading 
                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                    : .default,
                value: status == .loading
            )
    }
    
    /// 状态信息
    private var statusInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 主状态文本
            Text(status.displayName)
                .font(DesignTokens.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            // 详细时间信息
            if let metadata = metadata {
                statusDetailText(metadata)
                    .font(DesignTokens.Typography.small)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// 状态详细文本
    private func statusDetailText(_ metadata: CacheMetadata) -> Text {
        switch status {
        case .fresh:
            return Text("更新于 \(metadata.formattedCacheTime)")
        case .stale:
            let minutesToExpiry = Int(max(0, metadata.timeToExpiry / 60))
            return Text("\(minutesToExpiry) 分钟后过期")
        case .expired:
            return Text("已过期")
        case .loading:
            return Text("正在加载...")
        case .empty:
            return Text("无缓存数据")
        case .error:
            return Text("缓存错误")
        }
    }
    
    /// 刷新按钮
    private var refreshButton: some View {
        Button(action: {
            Task {
                await onRefresh()
            }
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    /// 状态背景色
    private var statusBackgroundColor: Color {
        switch status {
        case .fresh:
            return Color.green.opacity(0.1)
        case .stale:
            return Color.orange.opacity(0.1)
        case .expired:
            return Color.red.opacity(0.1)
        case .loading:
            return Color.blue.opacity(0.1)
        case .empty, .error:
            return Color.gray.opacity(0.1)
        }
    }
    
    /// 状态边框色
    private var statusBorderColor: Color {
        switch status {
        case .fresh:
            return Color.green.opacity(0.3)
        case .stale:
            return Color.orange.opacity(0.3)
        case .expired:
            return Color.red.opacity(0.3)
        case .loading:
            return Color.blue.opacity(0.3)
        case .empty, .error:
            return Color.gray.opacity(0.3)
        }
    }
    
    /// 提示信息视图
    private var tooltipView: some View {
        Group {
            if showTooltip, let metadata = metadata {
                VStack(alignment: .leading, spacing: 4) {
                    Text("缓存详情")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("缓存时间: \(metadata.formattedCacheTime)")
                    Text("过期时间: \(metadata.formattedExpiryTime)")
                    Text("命中次数: \(metadata.hitCount)")
                    Text("数据大小: \(metadata.formattedDataSize)")
                    
                    if metadata.isNearExpiry && status == .fresh {
                        Text("⚠️ 即将过期")
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(radius: 4)
                )
                .offset(x: -120, y: 25)
            }
        }
    }
}

/// 简化版缓存状态指示器（用于空间有限的地方）
struct CompactCacheStatusIndicator: View {
    let status: CacheStatus
    let metadata: CacheMetadata?
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(
                    red: status.color.red,
                    green: status.color.green,
                    blue: status.color.blue
                ))
            
            if let metadata = metadata, status == .stale {
                Text("\(Int(max(0, metadata.timeToExpiry / 60)))m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// 缓存过期提醒组件
struct CacheExpiryReminder: View {
    let metadata: CacheMetadata
    let onRefresh: () async -> Void
    
    @State private var isVisible = true
    
    var body: some View {
        Group {
            if isVisible && metadata.isNearExpiry {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("数据即将过期")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("将在 \(Int(metadata.timeToExpiry / 60)) 分钟后过期")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("刷新") {
                        Task {
                            await onRefresh()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                    .controlSize(.small)
                    
                    Button(action: {
                        withAnimation {
                            isVisible = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .transition(.opacity.combined(with: .slide))
            }
        }
    }
}

#Preview("缓存状态指示器") {
    VStack(spacing: 20) {
        CacheStatusIndicator(
            status: .fresh,
            metadata: CacheMetadata(
                status: .fresh,
                cacheTime: Date().addingTimeInterval(-300),
                expiryTime: Date().addingTimeInterval(1500),
                hitCount: 3,
                dataSize: 1024
            ),
            onRefresh: {}
        )
        
        CacheStatusIndicator(
            status: .stale,
            metadata: CacheMetadata(
                status: .stale,
                cacheTime: Date().addingTimeInterval(-1500),
                expiryTime: Date().addingTimeInterval(240),
                hitCount: 5,
                dataSize: 2048
            ),
            onRefresh: {}
        )
        
        CacheStatusIndicator(
            status: .expired,
            metadata: CacheMetadata(
                status: .expired,
                cacheTime: Date().addingTimeInterval(-1800),
                expiryTime: Date().addingTimeInterval(-60),
                hitCount: 8,
                dataSize: 3072
            ),
            onRefresh: {}
        )
    }
    .padding()
}