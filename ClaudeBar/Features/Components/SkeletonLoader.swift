import SwiftUI

/// 骨架屏加载组件
/// 用于在数据加载时显示内容占位符，提供更好的用户体验
struct SkeletonLoader: View {
    let config: SkeletonConfig
    @State private var animationOffset: CGFloat = -1
    
    init(_ config: SkeletonConfig = .default) {
        self.config = config
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: config.cornerRadius)
            .fill(config.baseColor)
            .overlay(
                RoundedRectangle(cornerRadius: config.cornerRadius)
                    .fill(shimmerGradient)
                    .mask(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.black.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .scaleEffect(x: 3, y: 1)
                            .offset(x: animationOffset * 300) // 使用固定宽度代替 UIScreen
                    )
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: config.animationDuration)
                        .repeatForever(autoreverses: false)
                ) {
                    animationOffset = 1
                }
            }
    }
    
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                config.shimmerColor.opacity(0),
                config.shimmerColor.opacity(0.5),
                config.shimmerColor.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// 骨架屏配置
struct SkeletonConfig {
    let baseColor: Color
    let shimmerColor: Color
    let cornerRadius: CGFloat
    let animationDuration: Double
    
    static let `default` = SkeletonConfig(
        baseColor: Color.gray.opacity(0.2),
        shimmerColor: Color.white,
        cornerRadius: DesignTokens.Size.Radius.medium,
        animationDuration: 1.5
    )
    
    static let card = SkeletonConfig(
        baseColor: Color.gray.opacity(0.15),
        shimmerColor: Color.white,
        cornerRadius: DesignTokens.Size.Radius.large,
        animationDuration: 1.8
    )
    
    static let text = SkeletonConfig(
        baseColor: Color.gray.opacity(0.25),
        shimmerColor: Color.white,
        cornerRadius: DesignTokens.Size.Radius.small,
        animationDuration: 1.2
    )
}

// MARK: - 专用骨架屏组件

/// 统计卡片骨架屏
struct StatCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                SkeletonLoader(.text)
                    .frame(width: 20, height: 16)
                
                Spacer()
            }
            
            SkeletonLoader(.text)
                .frame(height: 28)
                .frame(maxWidth: 120)
            
            SkeletonLoader(.text)
                .frame(height: 16)
                .frame(maxWidth: 80)
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                .fill(DesignTokens.Colors.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.large)
                .stroke(DesignTokens.Colors.separator.opacity(0.3), lineWidth: 1)
        )
    }
}

/// 模型行骨架屏
struct ModelRowSkeleton: View {
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                SkeletonLoader(.default)
                    .frame(width: 8, height: 8)
                    .clipShape(Circle())
                
                SkeletonLoader(.text)
                    .frame(width: 80, height: 14)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                SkeletonLoader(.text)
                    .frame(width: 60, height: 14)
                
                SkeletonLoader(.text)
                    .frame(width: 40, height: 12)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignTokens.Colors.controlBackground.opacity(0.5))
        )
    }
}

/// 项目行骨架屏
struct ProjectRowSkeleton: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                SkeletonLoader(.text)
                    .frame(width: 120, height: 14)
                
                SkeletonLoader(.text)
                    .frame(width: 200, height: 12)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                SkeletonLoader(.text)
                    .frame(width: 60, height: 14)
                
                SkeletonLoader(.text)
                    .frame(width: 40, height: 12)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignTokens.Colors.controlBackground.opacity(0.5))
        )
    }
}

/// 图表骨架屏
struct ChartSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            SkeletonLoader(.text)
                .frame(width: 100, height: 18)
            
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    SkeletonLoader(.default)
                        .frame(width: 12, height: CGFloat.random(in: 20...120))
                }
            }
            .frame(height: 140)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonLoader(.text)
                        .frame(width: 60, height: 12)
                    SkeletonLoader(.text)
                        .frame(width: 40, height: 14)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    SkeletonLoader(.text)
                        .frame(width: 80, height: 12)
                    SkeletonLoader(.text)
                        .frame(width: 60, height: 14)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    SkeletonLoader(.text)
                        .frame(width: 70, height: 12)
                    SkeletonLoader(.text)
                        .frame(width: 50, height: 14)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                    .fill(DesignTokens.Colors.controlBackground)
            )
        }
    }
}

/// 完整的使用统计页面骨架屏
struct UsageStatisticsSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // 概览卡片骨架屏
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        StatCardSkeleton()
                    }
                }
                
                // 标签页内容骨架屏
                VStack(spacing: 0) {
                    // 标签选择器骨架屏
                    HStack {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonLoader(.text)
                                .frame(width: 60, height: 32)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Size.Radius.medium)
                            .fill(DesignTokens.Colors.controlBackground)
                    )
                    
                    // 内容区域骨架屏
                    VStack(spacing: DesignTokens.Spacing.md) {
                        ChartSkeleton()
                    }
                    .padding(.top, DesignTokens.Spacing.lg)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("骨架屏组件预览")
            .font(.headline)
        
        StatCardSkeleton()
        
        ModelRowSkeleton()
        
        ProjectRowSkeleton()
        
        ChartSkeleton()
            .frame(height: 200)
    }
    .padding()
    .frame(width: 500)
}