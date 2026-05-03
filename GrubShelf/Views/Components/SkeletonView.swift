import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var offset: CGFloat = -200

    func body(content: Content) -> some View {
        content
            .overlay(
                Color.gsSurface.opacity(0.3)
                    .frame(width: 80)
                    .blur(radius: 12)
                    .offset(x: offset)
                    .clipped()
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    offset = 400
                }
            }
    }
}

// MARK: - Skeleton Primitives

struct SkeletonLine: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color.gsShimmer.opacity(0.15))
            .frame(width: width, height: height)
            .modifier(ShimmerModifier())
            .clipShape(RoundedRectangle(cornerRadius: height / 2))
    }
}

struct SkeletonCircle: View {
    var diameter: CGFloat = 36

    var body: some View {
        Circle()
            .fill(Color.gsShimmer.opacity(0.15))
            .frame(width: diameter, height: diameter)
            .modifier(ShimmerModifier())
            .clipShape(Circle())
    }
}

// MARK: - Pantry Skeleton

struct PantrySkeletonView: View {
    var body: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            // Summary strip (matches `PantrySummaryStrip`)
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                SkeletonLine(width: 140, height: 12)
                HStack(spacing: AppSpacing.smallSpacing) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: AppSpacing.denseSpacing) {
                            HStack {
                                SkeletonCircle(diameter: 28)
                                SkeletonCircle(diameter: 20)
                            }
                            SkeletonLine(width: 36, height: 16)
                            SkeletonLine(width: 52, height: 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.rowSpacing)
                        .dashboardCardSurface()
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .dashboardCardSurfaceElevated()
            .padding(.horizontal, AppSpacing.screenPadding)

            ForEach(0..<6, id: \.self) { _ in
                HStack(alignment: .top, spacing: AppSpacing.rowSpacing) {
                    SkeletonCircle(diameter: 36)
                    VStack(alignment: .leading, spacing: AppSpacing.denseSpacing) {
                        SkeletonLine(height: 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(width: nil)
                            .mask(
                                HStack {
                                    Rectangle().frame(width: UIScreen.main.bounds.width * 0.5)
                                    Spacer()
                                }
                            )
                        SkeletonLine(height: 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .mask(
                                HStack {
                                    Rectangle().frame(width: UIScreen.main.bounds.width * 0.3)
                                    Spacer()
                                }
                            )
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: AppSpacing.denseSpacing) {
                        SkeletonLine(width: 72, height: 12)
                        SkeletonLine(width: 96, height: 10)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
        .padding(.top, AppSpacing.sectionSpacing)
        .accessibilityHidden(true)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Shopping Skeleton

struct ShoppingSkeletonView: View {
    var body: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    HStack(spacing: AppSpacing.rowSpacing) {
                        SkeletonCircle(diameter: 36)
                        VStack(alignment: .leading, spacing: AppSpacing.denseSpacing) {
                            SkeletonLine(height: 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .mask(
                                    HStack {
                                        Rectangle().frame(width: UIScreen.main.bounds.width * 0.4)
                                        Spacer()
                                    }
                                )
                            SkeletonLine(height: 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .mask(
                                    HStack {
                                        Rectangle().frame(width: UIScreen.main.bounds.width * 0.25)
                                        Spacer()
                                    }
                                )
                        }
                    }
                    SkeletonLine(height: 6)
                }
                .padding(AppSpacing.cardPadding)
                .dashboardCardSurface()
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, AppSpacing.sectionSpacing)
        .accessibilityHidden(true)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Dashboard Skeleton

struct DashboardSkeletonView: View {
    var body: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            // Hero placeholder
            RoundedRectangle(cornerRadius: AppSpacing.heroRadius)
                .fill(Color.gsShimmer.opacity(0.15))
                .frame(height: 80)
                .modifier(ShimmerModifier())
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.heroRadius))
                .padding(.horizontal, AppSpacing.screenPadding)

            // 3 small accent cards
            HStack(spacing: AppSpacing.mediumSpacing) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                        .fill(Color.gsShimmer.opacity(0.15))
                        .frame(height: 100)
                        .modifier(ShimmerModifier())
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            // 2 large cards
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .fill(Color.gsShimmer.opacity(0.15))
                    .frame(height: 120)
                    .modifier(ShimmerModifier())
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                    .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
        .padding(.top, AppSpacing.rowSpacing)
        .accessibilityHidden(true)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Feed skeleton (Home)

struct FeedSkeletonStack: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                SkeletonLine(width: 120, height: 12)
                SkeletonLine(height: 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        HStack {
                            Rectangle().frame(width: UIScreen.main.bounds.width * 0.55)
                            Spacer()
                        }
                    )
                SkeletonLine(height: 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        HStack {
                            Rectangle().frame(width: UIScreen.main.bounds.width * 0.85)
                            Spacer()
                        }
                    )
            }
            SkeletonLine(width: 48, height: 11)
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                    HStack {
                        SkeletonLine(width: 56, height: 10)
                        Spacer()
                        SkeletonLine(width: 44, height: 22)
                    }
                    SkeletonLine(height: 16)
                    SkeletonLine(height: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .mask(
                            HStack {
                                Rectangle().frame(width: UIScreen.main.bounds.width * 0.72)
                                Spacer()
                            }
                        )
                }
                .padding(AppSpacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.heroRadius - 4, style: .continuous)
                        .fill(Color.gsShimmer.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.heroRadius - 4, style: .continuous)
                        .strokeBorder(Color.gsBorder.opacity(0.2), lineWidth: 1)
                )
            }
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(Color.gsShimmer.opacity(0.15))
                .frame(height: 52)
                .modifier(ShimmerModifier())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading household feed")
    }
}
