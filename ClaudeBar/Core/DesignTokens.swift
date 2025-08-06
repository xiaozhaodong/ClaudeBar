//
//  DesignTokens.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/8/1.
//

import SwiftUI

// MARK: - Design System Tokens

/// 统一的设计系统，定义应用中所有设计相关的常量
/// 确保整个应用的视觉一致性和可维护性
struct DesignTokens {
    
    // MARK: - Typography System
    
    struct Typography {
        /// 页面主标题 - 24pt, bold
        static let pageTitle = Font.system(size: 24, weight: .bold)
        
        /// 区域标题 - 18pt, semibold
        static let sectionTitle = Font.system(size: 18, weight: .semibold)
        
        /// 副标题 - 16pt, medium
        static let subtitle = Font.system(size: 16, weight: .medium)
        
        /// 正文内容 - 14pt, medium
        static let body = Font.system(size: 14, weight: .medium)
        
        /// 正文常规 - 14pt, regular
        static let bodyRegular = Font.system(size: 14, weight: .regular)
        
        /// 说明文字 - 13pt, regular
        static let caption = Font.system(size: 13, weight: .regular)
        
        /// 小号文字 - 12pt, medium
        static let small = Font.system(size: 12, weight: .medium)
        
        /// 导航标签 - 14pt, medium/semibold (选中时)
        static let navigationLabel = Font.system(size: 14, weight: .medium)
        static let navigationLabelSelected = Font.system(size: 14, weight: .semibold)
        
        /// 按钮文字 - 14pt, medium
        static let button = Font.system(size: 14, weight: .medium)
        
        /// 图标字体大小
        struct IconSize {
            static let small: CGFloat = 12
            static let medium: CGFloat = 16
            static let large: CGFloat = 20
            static let extraLarge: CGFloat = 24
        }
    }
    
    // MARK: - Spacing System
    
    struct Spacing {
        /// 基础单位 - 4pt
        static let base: CGFloat = 4
        
        /// 特小间距 - 4pt
        static let xs: CGFloat = 4
        
        /// 小间距 - 8pt
        static let sm: CGFloat = 8
        
        /// 中等间距 - 12pt
        static let md: CGFloat = 12
        
        /// 大间距 - 16pt
        static let lg: CGFloat = 16
        
        /// 特大间距 - 20pt
        static let xl: CGFloat = 20
        
        /// 超大间距 - 24pt
        static let xxl: CGFloat = 24
        
        /// 巨大间距 - 32pt
        static let xxxl: CGFloat = 32
        
        /// 页面级间距
        struct Page {
            /// 页面内边距 - 24pt
            static let padding: CGFloat = 24
            
            /// 组件间距 - 20pt
            static let componentSpacing: CGFloat = 20
            
            /// 卡片内边距 - 20pt
            static let cardPadding: CGFloat = 20
        }
        
        /// 组件级间距
        struct Component {
            /// 卡片内部元素间距 - 16pt
            static let cardInner: CGFloat = 16
            
            /// 行内元素间距 - 12pt
            static let rowInner: CGFloat = 12
            
            /// 设置行垂直间距 - 12pt
            static let settingRowSpacing: CGFloat = 12
            
            /// 按钮内边距
            static let buttonPadding: CGFloat = 16
        }
    }
    
    // MARK: - Size System
    
    struct Size {
        /// 按钮高度
        struct Button {
            static let small: CGFloat = 28
            static let medium: CGFloat = 32
            static let large: CGFloat = 36
            static let extraLarge: CGFloat = 40
        }
        
        /// 图标框架大小
        struct Icon {
            static let small: CGFloat = 16
            static let medium: CGFloat = 20
            static let large: CGFloat = 24
            static let extraLarge: CGFloat = 28
        }
        
        /// 圆角半径
        struct Radius {
            static let small: CGFloat = 6
            static let medium: CGFloat = 8
            static let large: CGFloat = 10
            static let extraLarge: CGFloat = 12
        }
        
        /// 导航相关尺寸
        struct Navigation {
            /// 侧边栏宽度
            static let sidebarWidth: CGFloat = 280
            
            /// 分隔线宽度
            static let separatorWidth: CGFloat = 1
        }
    }
    
    // MARK: - Color Extensions
    
    struct Colors {
        /// 主色调
        static let primary = Color.blue
        static let primaryVariant = Color.blue.opacity(0.8)
        
        /// 状态颜色
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        
        /// 语义化颜色
        static let accent = Color.blue
        static let accentLight = Color.blue.opacity(0.1)
        static let accentBorder = Color.blue.opacity(0.2)
        
        /// 背景颜色（系统）
        static let windowBackground = Color(.windowBackgroundColor)
        static let controlBackground = Color(.controlBackgroundColor)
        static let selectedBackground = Color(.selectedControlColor).opacity(0.1)
        
        /// 分隔线颜色
        static let separator = Color(.separatorColor)
        
        /// 文本颜色（系统）
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        
        // MARK: - 统计页面专用颜色
        
        /// 统计卡片渐变色
        struct StatCard {
            static let costGradient = LinearGradient(
                colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            static let sessionGradient = LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            static let tokenGradient = LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.orange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            static let averageGradient = LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        /// 图表颜色
        struct Chart {
            static let low = Color.blue.opacity(0.8)
            static let medium = Color.orange.opacity(0.8)
            static let high = Color.red.opacity(0.8)
            static let background = Color.gray.opacity(0.1)
            static let grid = Color.gray.opacity(0.2)
        }
        
        /// 模型颜色映射
        struct Model {
            static let opus = Color.purple
            static let sonnet = Color.blue  
            static let haiku = Color.green
            static let defaultColor = Color.gray
        }
        
        /// 令牌类型颜色
        struct Token {
            static let input = Color.blue
            static let output = Color.green
            static let cacheWrite = Color.orange
            static let cacheRead = Color.purple
        }
        
        /// 趋势指示颜色
        struct Trend {
            static let up = Color.green
            static let down = Color.red
            static let neutral = Color.gray
        }
    }
    
    // MARK: - Animation System
    
    struct Animation {
        /// 快速动画 - 0.15秒
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        
        /// 标准动画 - 0.2秒
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.2)
        
        /// 慢速动画 - 0.3秒
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.3)
        
        /// 页面切换动画 - 0.3秒
        static let pageTransition = SwiftUI.Animation.easeInOut(duration: 0.3)
        
        /// 卡片悬停动画 - 0.15秒
        static let cardHover = SwiftUI.Animation.easeInOut(duration: 0.15)
        
        /// 图表动画 - 0.5秒
        static let chart = SwiftUI.Animation.easeInOut(duration: 0.5)
    }
    
    // MARK: - Shadow System
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        /// 轻微阴影 - 卡片悬停
        static let light = Shadow(
            color: Color.black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
        
        /// 标准阴影 - 普通卡片
        static let standard = Shadow(
            color: Color.black.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4
        )
        
        /// 深度阴影 - 弹出层
        static let heavy = Shadow(
            color: Color.black.opacity(0.2),
            radius: 16,
            x: 0,
            y: 8
        )
    }
}

// MARK: - Design Token Extensions

extension View {
    /// 应用标准卡片样式
    func cardStyle() -> some View {
        self
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.extraLarge)
                    .fill(DesignTokens.Colors.controlBackground)
            )
    }
    
    /// 应用设置卡片样式
    func settingsCardStyle() -> some View {
        self
            .padding(DesignTokens.Spacing.Page.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.extraLarge)
                    .fill(DesignTokens.Colors.controlBackground)
            )
    }
    
    /// 应用标准按钮样式
    func standardButtonStyle(height: CGFloat = DesignTokens.Size.Button.large) -> some View {
        self
            .frame(height: height)
            .font(DesignTokens.Typography.button)
    }
    
    /// 应用页面级内边距
    func pageContentPadding() -> some View {
        self.padding(DesignTokens.Spacing.Page.padding)
    }
    
    /// 应用组件间距
    func componentSpacing() -> some View {
        self.padding(.vertical, DesignTokens.Spacing.Page.componentSpacing / 2)
    }
    
    // MARK: - 统计页面专用样式
    
    /// 统计卡片样式（带渐变背景）
    func statCardStyle(gradient: LinearGradient, shadow: Bool = false) -> some View {
        self
            .padding(DesignTokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                    .fill(gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                            .fill(DesignTokens.Colors.controlBackground)
                            .opacity(0.9)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                    .stroke(DesignTokens.Colors.separator.opacity(0.3), lineWidth: 1)
            )
            .conditionalShadow(enabled: shadow)
    }
    
    /// 条件性阴影应用
    private func conditionalShadow(enabled: Bool) -> some View {
        Group {
            if enabled {
                self.shadow(
                    color: DesignTokens.Shadow.standard.color,
                    radius: DesignTokens.Shadow.standard.radius,
                    x: DesignTokens.Shadow.standard.x,
                    y: DesignTokens.Shadow.standard.y
                )
            } else {
                self
            }
        }
    }
    
    /// 悬停效果
    func hoverEffect() -> some View {
        self
            .scaleEffect(1.0)
            .onHover { isHovering in
                withAnimation(DesignTokens.Animation.cardHover) {
                    // 这里可以添加悬停状态的变化
                }
            }
    }
    
    /// 骨架屏动画效果
    func skeletonAnimation() -> some View {
        self
            .opacity(0.6)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(15))
                    .animation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: UUID()
                    )
            )
            .clipped()
    }
}

// MARK: - Common UI Components

struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.Page.componentSpacing) {
                // Typography examples
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("设计系统预览")
                        .font(DesignTokens.Typography.pageTitle)
                        .foregroundColor(DesignTokens.Colors.primaryText)
                    
                    Text("区域标题示例")
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundColor(DesignTokens.Colors.primaryText)
                    
                    Text("副标题示例文字")
                        .font(DesignTokens.Typography.subtitle)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                    
                    Text("这是正文内容的示例，使用标准字体大小和行高。")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.primaryText)
                    
                    Text("这是说明文字，通常用于补充信息和提示。")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                }
                .cardStyle()
                
                // Button examples
                VStack(spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Button("标准按钮") {}
                            .standardButtonStyle()
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                                    .fill(DesignTokens.Colors.primary)
                            )
                        
                        Button("次要按钮") {}
                            .standardButtonStyle()
                            .foregroundColor(DesignTokens.Colors.primary)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                                    .fill(DesignTokens.Colors.accentLight)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                                            .stroke(DesignTokens.Colors.accentBorder, lineWidth: 1)
                                    )
                            )
                    }
                }
                .cardStyle()
            }
            .pageContentPadding()
        }
        .navigationTitle("设计系统")
    }
}

#Preview {
    DesignSystemPreview()
}