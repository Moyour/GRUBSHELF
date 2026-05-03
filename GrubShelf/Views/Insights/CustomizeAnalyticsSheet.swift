import SwiftUI

struct CustomizeAnalyticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enabledCards: Set<AnalyticsCard>
    var onDismiss: (() -> Void)?

    init(onDismiss: (() -> Void)? = nil) {
        _enabledCards = State(initialValue: AnalyticsPreferences.enabledCards)
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AnalyticsCard.allCases.sorted { $0.displayOrder < $1.displayOrder }) { card in
                        Toggle(isOn: binding(for: card)) {
                            HStack(spacing: AppSpacing.rowSpacing) {
                                Image(systemName: card.icon)
                                    .font(BrandSymbolFont.symbol(17))
                                    .foregroundStyle(.gsBrandPrimary)
                                    .frame(width: 28, alignment: .center)
                                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                                    Text(card.title)
                                        .font(BrandFont.semiBold(17))
                                        .foregroundStyle(.gsTextPrimary)
                                    Text(card.description)
                                        .font(BrandFont.regular(14))
                                        .foregroundStyle(.gsTextSecondary)
                                }
                            }
                        }
                        .font(BrandFont.regular(17))
                        .padding(AppSpacing.cardPadding)
                        .dashboardCardSurface()
                        .listRowInsets(AppSpacing.listRowCardInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Analytics cards")
                } footer: {
                    Text("Choose which analytics to show on your Analytics screen.")
                }

                Section {
                    Button("Select all") {
                        enabledCards = Set(AnalyticsCard.allCases)
                        AnalyticsPreferences.enabledCards = enabledCards
                    }
                    .font(BrandFont.regular(17))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.cardPadding)
                    .dashboardCardSurface()
                    .listRowInsets(AppSpacing.listRowCardInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    Button("Deselect all") {
                        enabledCards = []
                        AnalyticsPreferences.enabledCards = enabledCards
                    }
                    .font(BrandFont.regular(17))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.cardPadding)
                    .dashboardCardSurface()
                    .listRowInsets(AppSpacing.listRowCardInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("Customize analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        AnalyticsPreferences.enabledCards = enabledCards
                        onDismiss?()
                        dismiss()
                    }
                    .font(BrandFont.semiBold(17))
                }
            }
        }
    }

    private func binding(for card: AnalyticsCard) -> Binding<Bool> {
        Binding(
            get: { enabledCards.contains(card) },
            set: { newValue in
                if newValue {
                    enabledCards.insert(card)
                } else {
                    enabledCards.remove(card)
                }
                AnalyticsPreferences.enabledCards = enabledCards
            }
        )
    }
}
