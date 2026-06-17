import StoreKit
import SwiftUI

struct PaywallView: View {
    let featureGateService: FeatureGateService
    let storeKitService: StoreKitService
    let subscriptionService: SubscriptionService
    let householdId: UUID
    let userId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PlanSelection = .yearly
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private var triggerFeature: SubscriptionFeature? {
        featureGateService.paywallTriggerFeature
    }

    private var limitInfo: FeatureLimitCheck? {
        featureGateService.paywallLimitInfo
    }

    enum PlanSelection { case monthly, yearly }

    private var selectedProduct: Product? {
        selectedPlan == .yearly
            ? storeKitService.yearlyProduct
            : storeKitService.monthlyProduct
    }

    private var selectedPlanPriceLabel: String {
        guard let product = selectedProduct else {
            return selectedPlan == .yearly ? "$54.99/year" : "$4.99/month"
        }
        let period = selectedPlan == .yearly ? "/year" : "/month"
        return "\(product.displayPrice)\(period)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    // Header
                    headerSection

                    // Feature list
                    premiumFeaturesList

                    // Pricing
                    pricingSection

                    // Purchase button
                    purchaseButton

                    // Restore link
                    restoreLink

                    // Legal footer
                    legalFooter
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.rowSpacing)
                .padding(.bottom, AppSpacing.sectionSpacing)
            }
            .background(.gsBackground)
            .navigationTitle("GrubShelf Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(BrandFont.semiBold(15))
                }
            }
            .tint(.gsBrandPrimary)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            ZStack {
                Circle()
                    .fill(.gsBrandPrimary.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: triggerFeature?.systemImage ?? "star.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.gsBrandPrimary)
            }

            if let feature = triggerFeature {
                Text("Upgrade to unlock \(feature.displayTitle)")
                    .font(BrandFont.semiBold(22))
                    .foregroundStyle(.gsTextPrimary)
                    .multilineTextAlignment(.center)

                if let info = limitInfo, !info.isUnlimited {
                    Text("You've used \(info.currentUsage) of \(info.limitValue) on the free plan.")
                        .font(BrandFont.regular(15))
                        .foregroundStyle(.gsTextSecondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Upgrade to Premium")
                    .font(BrandFont.semiBold(22))
                    .foregroundStyle(.gsTextPrimary)
                    .multilineTextAlignment(.center)
                Text("Unlock everything GrubShelf has to offer.")
                    .font(BrandFont.regular(15))
                    .foregroundStyle(.gsTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, AppSpacing.rowSpacing)
    }

    // MARK: - Features List

    @ViewBuilder
    private var premiumFeaturesList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            premiumRow(icon: "refrigerator", title: "Unlimited pantry items", subtitle: "Free: 150 items")
            premiumRow(icon: "cart", title: "Unlimited shopping lists", subtitle: "Free: 3 lists")
            premiumRow(icon: "person.2", title: "Unlimited family members", subtitle: "Free: 2 members")
            premiumRow(icon: "barcode.viewfinder", title: "Unlimited barcode scans", subtitle: "Free: 20/month")
            premiumRow(icon: "square.and.arrow.up", title: "Export data (JSON & CSV)", subtitle: "Premium only")
            premiumRow(icon: "camera", title: "Photo recognition", subtitle: "Premium only")
        }
        .padding(AppSpacing.cardPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }

    @ViewBuilder
    private func premiumRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            Image(systemName: icon)
                .font(BrandSymbolFont.symbol(17))
                .foregroundStyle(.gsBrandPrimary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                Text(title)
                    .font(BrandFont.semiBold(15))
                    .foregroundStyle(.gsTextPrimary)
                Text(subtitle)
                    .font(BrandFont.regular(13))
                    .foregroundStyle(.gsTextSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(BrandSymbolFont.symbol(17))
                .foregroundStyle(.gsSuccess)
        }
    }

    // MARK: - Pricing

    @ViewBuilder
    private var pricingSection: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            // Yearly card
            pricingCard(
                title: "Yearly",
                price: storeKitService.yearlyProduct?.displayPrice ?? "$54.99",
                period: "/year",
                savings: "Save 8%",
                isSelected: selectedPlan == .yearly
            ) {
                selectedPlan = .yearly
            }

            // Monthly card
            pricingCard(
                title: "Monthly",
                price: storeKitService.monthlyProduct?.displayPrice ?? "$4.99",
                period: "/month",
                savings: nil,
                isSelected: selectedPlan == .monthly
            ) {
                selectedPlan = .monthly
            }
        }
    }

    @ViewBuilder
    private func pricingCard(
        title: String,
        price: String,
        period: String,
        savings: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    HStack(spacing: AppSpacing.smallSpacing) {
                        Text(title)
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                        if let savings {
                            Text(savings)
                                .font(BrandFont.semiBold(12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.smallSpacing)
                                .padding(.vertical, AppSpacing.compactGap)
                                .background(.gsBrandPrimary, in: Capsule())
                        }
                    }
                    HStack(spacing: 0) {
                        Text(price)
                            .font(BrandFont.semiBold(15))
                            .foregroundStyle(.gsTextPrimary)
                        Text(period)
                            .font(BrandFont.regular(13))
                            .foregroundStyle(.gsTextSecondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(BrandSymbolFont.symbol(22))
                    .foregroundStyle(isSelected ? .gsBrandPrimary : .gsTextSecondary.opacity(0.4))
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                    .stroke(isSelected ? Color.gsBrandPrimary : Color.gsTextSecondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Purchase Button

    @ViewBuilder
    private var purchaseButton: some View {
        Button {
            Task { await performPurchase() }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Subscribe Now")
                        .font(BrandFont.semiBold(17))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.minTouchTarget)
            .foregroundStyle(.white)
            .background(.gsBrandPrimary, in: RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
        }
        .disabled(isPurchasing)

        if let error = errorMessage {
            Text(error)
                .font(BrandFont.regular(13))
                .foregroundStyle(.gsDanger)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Restore & Legal

    @ViewBuilder
    private var restoreLink: some View {
        Button {
            Task {
                await storeKitService.restorePurchases()
                if storeKitService.hasActiveSubscription {
                    dismiss()
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(BrandFont.regular(15))
                .foregroundStyle(.gsBrandPrimary)
        }
    }

    @ViewBuilder
    private var legalFooter: some View {
        VStack(spacing: AppSpacing.compactGap) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription auto-renews unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Settings.")
                .font(BrandFont.regular(11))
                .foregroundStyle(.gsTextSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: AppSpacing.rowSpacing) {
                Link("Terms of Use", destination: URL(string: "https://grubshelf.com/terms")!)
                    .font(BrandFont.regular(11))
                Link("Privacy Policy", destination: URL(string: "https://grubshelf.com/privacy")!)
                    .font(BrandFont.regular(11))
            }
        }
    }

    // MARK: - Actions

    private func performPurchase() async {
        let product: Product? = selectedPlan == .yearly
            ? storeKitService.yearlyProduct
            : storeKitService.monthlyProduct

        guard let product else {
            errorMessage = "Products not available. Please try again."
            return
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let transaction = try await storeKitService.purchase(product)
            if transaction != nil {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
