//
//  SyncStatusComponents.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/8/17.
//

import SwiftUI

// MARK: - Sync Status View

/// 主要的同步状态显示组件
/// 提供完整的同步状态信息展示，支持不同显示模式
struct SyncStatusView: View {
    @ObservedObject var autoSyncService: AutoSyncService
    let displayMode: DisplayMode
    let showDetails: Bool
    
    /// 显示模式
    enum DisplayMode {
        case compact    // 紧凑模式 - 适用于菜单栏
        case detailed   // 详细模式 - 适用于主界面
        case card       // 卡片模式 - 适用于设置页面
    }
    
    init(
        autoSyncService: AutoSyncService,
        displayMode: DisplayMode = .detailed,
        showDetails: Bool = true
    ) {
        self.autoSyncService = autoSyncService
        self.displayMode = displayMode
        self.showDetails = showDetails
    }
    
    var body: some View {
        switch displayMode {
        case .compact:
            compactView
        case .detailed:
            detailedView
        case .card:
            cardView
        }
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            SyncStatusIndicator(
                status: autoSyncService.syncStatus,
                size: .small,
                animated: autoSyncService.isSyncing
            )
            
            if autoSyncService.isSyncing {
                Text(autoSyncService.syncStatus.displayName)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Detailed View
    
    private var detailedView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 状态标题行
            HStack(spacing: DesignTokens.Spacing.sm) {
                SyncStatusIndicator(
                    status: autoSyncService.syncStatus,
                    size: .medium,
                    animated: autoSyncService.isSyncing
                )
                
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("同步状态")
                        .font(DesignTokens.Typography.subtitle)
                        .foregroundColor(DesignTokens.Colors.primaryText)
                    
                    Text(autoSyncService.syncStatus.displayName)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(statusTextColor)
                }
                
                Spacer()
                
                if showDetails {
                    syncActionButtons
                }
            }
            
            // 进度条
            if autoSyncService.isSyncing {
                SyncProgressView(
                    progress: autoSyncService.syncProgress,
                    style: .detailed
                )
            }
            
            // 详细信息
            if showDetails {
                syncDetailsView
            }
            
            // 错误信息
            if let error = autoSyncService.lastSyncError {
                SyncErrorView(
                    error: error,
                    style: .inline
                )
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                .fill(DesignTokens.Colors.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Card View
    
    private var cardView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("自动同步")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                
                Spacer()
                
                SyncStatusBadge(status: autoSyncService.syncStatus)
            }
            
            if autoSyncService.autoSyncEnabled {
                syncScheduleInfo
            } else {
                Text("自动同步已禁用")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
            }
            
            if autoSyncService.isSyncing {
                SyncProgressView(
                    progress: autoSyncService.syncProgress,
                    style: .compact
                )
            }
        }
        .cardStyle()
    }
    
    // MARK: - Private Views
    
    private var syncActionButtons: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if autoSyncService.isSyncing {
                if autoSyncService.syncStatus.canPause {
                    QuickActionButton(icon: "pause.fill") {
                        Task {
                            await autoSyncService.pauseSync()
                        }
                    }
                }
                
                if autoSyncService.syncStatus.canCancel {
                    QuickActionButton(icon: "xmark") {
                        Task {
                            await autoSyncService.cancelSync()
                        }
                    }
                }
            } else if autoSyncService.syncStatus.canResume {
                QuickActionButton(icon: "play.fill") {
                    Task {
                        try? await autoSyncService.resumeSync()
                    }
                }
            } else if autoSyncService.syncStatus.canRetry {
                QuickActionButton(icon: "arrow.clockwise") {
                    Task {
                        try? await autoSyncService.performIncrementalSync()
                    }
                }
            }
        }
    }
    
    private var syncDetailsView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if let lastSyncTime = autoSyncService.lastSyncTime {
                SyncInfoRow(
                    icon: "clock",
                    label: "上次同步",
                    value: formatRelativeTime(lastSyncTime)
                )
            }
            
            if let nextSyncTime = autoSyncService.nextSyncTime {
                SyncInfoRow(
                    icon: "timer",
                    label: "下次同步",
                    value: formatRelativeTime(nextSyncTime)
                )
            }
            
            if let result = autoSyncService.currentSyncResult {
                SyncInfoRow(
                    icon: "doc.text",
                    label: "处理项目",
                    value: "\(result.processedItems) 项"
                )
            }
        }
    }
    
    private var syncScheduleInfo: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if let nextSync = autoSyncService.nextSyncTime {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: DesignTokens.Typography.IconSize.small))
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                    
                    Text("下次同步: \(formatRelativeTime(nextSync))")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                }
            }
            
            if let lastSync = autoSyncService.lastSyncTime {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: DesignTokens.Typography.IconSize.small))
                        .foregroundColor(DesignTokens.Colors.success)
                    
                    Text("上次同步: \(formatRelativeTime(lastSync))")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusTextColor: Color {
        switch autoSyncService.syncStatus {
        case .completed:
            return DesignTokens.Colors.success
        case .failed:
            return DesignTokens.Colors.error
        case .cancelled:
            return DesignTokens.Colors.warning
        default:
            return DesignTokens.Colors.primaryText
        }
    }
    
    private var borderColor: Color {
        switch autoSyncService.syncStatus {
        case .completed:
            return DesignTokens.Colors.success.opacity(0.3)
        case .failed:
            return DesignTokens.Colors.error.opacity(0.3)
        case .syncing, .parsing, .scanning, .validating:
            return DesignTokens.Colors.primary.opacity(0.3)
        default:
            return DesignTokens.Colors.separator
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Sync Status Indicator

/// 同步状态指示器 - 显示状态图标和动画
struct SyncStatusIndicator: View {
    let status: SyncStatus
    let size: Size
    let animated: Bool
    
    enum Size {
        case small, medium, large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 24
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }
    }
    
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Image(systemName: status.iconName)
            .font(.system(size: size.fontSize, weight: .medium))
            .foregroundColor(Color(
                red: status.color.red,
                green: status.color.green,
                blue: status.color.blue
            ))
            .frame(width: size.dimension, height: size.dimension)
            .rotationEffect(.degrees(rotationAngle))
            .onAppear {
                if animated && shouldRotate {
                    startRotationAnimation()
                }
            }
            .onChange(of: animated) { newValue in
                if newValue && shouldRotate {
                    startRotationAnimation()
                } else {
                    stopRotationAnimation()
                }
            }
    }
    
    private var shouldRotate: Bool {
        return status == .syncing || status == .scanning || status == .parsing
    }
    
    private func startRotationAnimation() {
        withAnimation(
            Animation.linear(duration: 1.0)
                .repeatForever(autoreverses: false)
        ) {
            rotationAngle = 360
        }
    }
    
    private func stopRotationAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            rotationAngle = 0
        }
    }
}

// MARK: - Sync Progress View

/// 同步进度条组件
struct SyncProgressView: View {
    let progress: Double
    let style: Style
    let description: String?
    
    enum Style {
        case compact, detailed
    }
    
    init(progress: Double, style: Style = .detailed, description: String? = nil) {
        self.progress = progress
        self.style = style
        self.description = description
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if style == .detailed {
                HStack {
                    Text("同步进度")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                }
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: progressBarRadius)
                        .fill(DesignTokens.Colors.separator.opacity(0.3))
                        .frame(height: progressBarHeight)
                    
                    // 进度
                    RoundedRectangle(cornerRadius: progressBarRadius)
                        .fill(progressGradient)
                        .frame(
                            width: geometry.size.width * min(max(progress, 0), 1),
                            height: progressBarHeight
                        )
                        .animation(DesignTokens.Animation.standard, value: progress)
                }
            }
            .frame(height: progressBarHeight)
            
            if let description = description, style == .detailed {
                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
    }
    
    private var progressBarHeight: CGFloat {
        style == .compact ? 4 : 6
    }
    
    private var progressBarRadius: CGFloat {
        progressBarHeight / 2
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [
                DesignTokens.Colors.primary,
                DesignTokens.Colors.primary.opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Sync Info Row

/// 同步信息行组件
struct SyncInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let valueColor: Color
    
    init(icon: String, label: String, value: String, valueColor: Color = DesignTokens.Colors.primaryText) {
        self.icon = icon
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.Typography.IconSize.small, weight: .medium))
                .foregroundColor(DesignTokens.Colors.secondaryText)
                .frame(width: 16)
            
            Text(label)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Sync Status Badge

/// 同步状态徽章
struct SyncStatusBadge: View {
    let status: SyncStatus
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: status.iconName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(badgeTextColor)
            
            Text(status.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(badgeTextColor)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.small)
                .fill(badgeBackgroundColor)
        )
    }
    
    private var badgeTextColor: Color {
        switch status {
        case .completed:
            return DesignTokens.Colors.success
        case .failed:
            return DesignTokens.Colors.error
        case .syncing, .scanning, .parsing, .validating:
            return DesignTokens.Colors.primary
        case .cancelled:
            return DesignTokens.Colors.warning
        default:
            return DesignTokens.Colors.secondaryText
        }
    }
    
    private var badgeBackgroundColor: Color {
        switch status {
        case .completed:
            return DesignTokens.Colors.success.opacity(0.1)
        case .failed:
            return DesignTokens.Colors.error.opacity(0.1)
        case .syncing, .scanning, .parsing, .validating:
            return DesignTokens.Colors.primary.opacity(0.1)
        case .cancelled:
            return DesignTokens.Colors.warning.opacity(0.1)
        default:
            return DesignTokens.Colors.separator.opacity(0.1)
        }
    }
}

// MARK: - Sync Error View

/// 同步错误显示组件
struct SyncErrorView: View {
    let error: SyncError
    let style: Style
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    enum Style {
        case inline     // 内联显示
        case popup      // 弹出式显示
        case banner     // 横幅式显示
    }
    
    init(
        error: SyncError,
        style: Style = .inline,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.style = style
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        switch style {
        case .inline:
            inlineErrorView
        case .popup:
            popupErrorView
        case .banner:
            bannerErrorView
        }
    }
    
    // MARK: - Error View Styles
    
    private var inlineErrorView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: error.severity.iconName)
                    .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                    .foregroundColor(errorColor)
                
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(error.severity.displayName)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(errorColor)
                    
                    Text(error.localizedDescription)
                        .font(DesignTokens.Typography.bodyRegular)
                        .foregroundColor(DesignTokens.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                errorActionButtons
            }
            
            if let suggestion = error.recoverySuggestion, !suggestion.isEmpty {
                Text(suggestion)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28) // 对齐图标后的文本
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                .fill(errorBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                .stroke(errorColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var popupErrorView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 标题行
            HStack {
                Image(systemName: error.severity.iconName)
                    .font(.system(size: DesignTokens.Typography.IconSize.large, weight: .medium))
                    .foregroundColor(errorColor)
                
                Text(error.severity.displayName)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                
                Spacer()
                
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: DesignTokens.Typography.IconSize.medium))
                            .foregroundColor(DesignTokens.Colors.secondaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // 错误描述
            Text(error.localizedDescription)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            // 恢复建议
            if let suggestion = error.recoverySuggestion, !suggestion.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("解决方案")
                        .font(DesignTokens.Typography.subtitle)
                        .foregroundColor(DesignTokens.Colors.primaryText)
                    
                    Text(suggestion)
                        .font(DesignTokens.Typography.bodyRegular)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // 操作按钮
            HStack {
                Spacer()
                
                if error.isRecoverable, let onRetry = onRetry {
                    ActionButton(
                        title: "重试",
                        icon: "arrow.clockwise",
                        color: DesignTokens.Colors.primary,
                        action: onRetry
                    )
                }
                
                ActionButton(
                    title: error.userAction.displayName,
                    icon: "info.circle",
                    color: DesignTokens.Colors.secondaryText,
                    action: { /* 根据具体的 userAction 执行对应操作 */ }
                )
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.extraLarge)
                .fill(DesignTokens.Colors.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.extraLarge)
                .stroke(DesignTokens.Colors.separator, lineWidth: 1)
        )
        .shadow(
            color: DesignTokens.Shadow.heavy.color,
            radius: DesignTokens.Shadow.heavy.radius,
            x: DesignTokens.Shadow.heavy.x,
            y: DesignTokens.Shadow.heavy.y
        )
    }
    
    private var bannerErrorView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: error.severity.iconName)
                .font(.system(size: DesignTokens.Typography.IconSize.medium, weight: .medium))
                .foregroundColor(errorColor)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(error.localizedDescription)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            errorActionButtons
        }
        .padding(DesignTokens.Spacing.md)
        .background(errorBackgroundColor)
    }
    
    private var errorActionButtons: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if error.isRecoverable, let onRetry = onRetry {
                QuickActionButton(icon: "arrow.clockwise", action: onRetry)
            }
            
            if let onDismiss = onDismiss {
                QuickActionButton(icon: "xmark", action: onDismiss)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var errorColor: Color {
        switch error.severity {
        case .warning:
            return DesignTokens.Colors.warning
        case .error:
            return DesignTokens.Colors.error
        case .critical:
            return DesignTokens.Colors.error
        }
    }
    
    private var errorBackgroundColor: Color {
        switch error.severity {
        case .warning:
            return DesignTokens.Colors.warning.opacity(0.1)
        case .error:
            return DesignTokens.Colors.error.opacity(0.1)
        case .critical:
            return DesignTokens.Colors.error.opacity(0.15)
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct SyncStatusComponents_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 紧凑模式预览
            SyncStatusView(
                autoSyncService: mockAutoSyncService(),
                displayMode: .compact
            )
            .previewDisplayName("Compact Mode")
            
            // 详细模式预览
            SyncStatusView(
                autoSyncService: mockAutoSyncService(),
                displayMode: .detailed
            )
            .previewDisplayName("Detailed Mode")
            
            // 卡片模式预览
            SyncStatusView(
                autoSyncService: mockAutoSyncService(),
                displayMode: .card
            )
            .previewDisplayName("Card Mode")
            
            // 错误状态预览
            SyncErrorView(
                error: .fileNotFound("test.jsonl"),
                style: .popup
            )
            .previewDisplayName("Error View")
        }
        .padding()
    }
    
    static func mockAutoSyncService() -> AutoSyncService {
        // 这里需要创建一个 mock 服务用于预览
        // 实际实现中需要根据具体需求调整
        fatalError("Mock service needed for preview")
    }
}
#endif