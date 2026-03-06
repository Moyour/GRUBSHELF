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
                            HStack(spacing: 12) {
                                Image(systemName: card.icon)
                                    .font(.body)
                                    .foregroundStyle(Color.primaryGreen)
                                    .frame(width: 28, alignment: .center)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.title)
                                        .font(AppFont.button)
                                        .foregroundStyle(Color.primaryText)
                                    Text(card.description)
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                        }
                        .font(AppFont.body)
                    }
                } header: {
                    Text("Analytics Cards")
                } footer: {
                    Text("Choose which analytics to show on your Analytics screen.")
                }

                Section {
                    Button("Select All") {
                        enabledCards = Set(AnalyticsCard.allCases)
                        AnalyticsPreferences.enabledCards = enabledCards
                    }
                    .font(AppFont.body)

                    Button("Deselect All") {
                        enabledCards = []
                        AnalyticsPreferences.enabledCards = enabledCards
                    }
                    .font(AppFont.body)
                }
            }
            .navigationTitle("Customize Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        AnalyticsPreferences.enabledCards = enabledCards
                        onDismiss?()
                        dismiss()
                    }
                    .font(AppFont.button)
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
