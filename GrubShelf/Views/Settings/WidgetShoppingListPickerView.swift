import SwiftUI

/// Lets the user choose which shopping list drives the Home Screen widget (medium/large), or the default newest-list order.
struct WidgetShoppingListPickerView: View {
    let householdId: UUID

    private let listRepository: ShoppingListRepository
    private let shoppingRepository: ShoppingRepository

    @State private var lists: [ShoppingList] = []
    @State private var isLoading = true
    @State private var preferredListId: UUID?

    init(
        householdId: UUID,
        listRepository: ShoppingListRepository = SupabaseShoppingListRepository(),
        shoppingRepository: ShoppingRepository = SupabaseShoppingRepository()
    ) {
        self.householdId = householdId
        self.listRepository = listRepository
        self.shoppingRepository = shoppingRepository
        _preferredListId = State(initialValue: ShoppingListWidgetPreferences.pinnedListId())
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lists.isEmpty {
                ScrollView {
                    VStack(spacing: AppSpacing.sectionSpacing) {
                        Spacer(minLength: AppSpacing.scrollVerticalBreathingRoom)
                        TabEmptyStateHero(
                            systemName: "cart",
                            symbolFontSize: EmptyStateMetrics.tabHeroSymbolSizeCompact,
                            symbolWeight: .bold
                        )
                        EmptyStateCopyCard(
                            title: String(localized: "No shopping lists"),
                            subtitle: String(localized: "Create a list in Shop, then choose it here.")
                        )
                        Spacer(minLength: AppSpacing.scrollVerticalBreathingRoom)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                Form {
                    Section {
                        selectionRow(
                            title: "Newest list (default)",
                            subtitle: "Matches the top list in Shop — same order as when you open Shop.",
                            isSelected: preferredListId == nil
                        ) {
                            Task { await applySelection(listId: nil) }
                        }
                    }

                    Section("Show this list on the widget") {
                        ForEach(lists) { list in
                            selectionRow(
                                title: list.name,
                                subtitle: nil,
                                isSelected: preferredListId == list.listId
                            ) {
                                Task { await applySelection(listId: list.listId) }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.gsBackground)
        .navigationTitle("Widget list")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadLists()
        }
    }

    private func selectionRow(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.rowSpacing) {
                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    Text(title)
                        .font(BrandFont.regular(17))
                        .foregroundStyle(.gsTextPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(BrandSymbolFont.symbol(20))
                        .foregroundStyle(.gsBrandPrimary)
                        .accessibilityLabel("Selected")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadLists() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await listRepository.fetchAll(householdId: householdId)
            lists = fetched.filter { !$0.transferred }
            preferredListId = ShoppingListWidgetPreferences.pinnedListId()
        } catch {
            lists = []
        }
    }

    private func applySelection(listId: UUID?) async {
        if let listId {
            ShoppingListWidgetPreferences.setPinnedList(listId)
        } else {
            ShoppingListWidgetPreferences.clearPinnedList()
        }
        preferredListId = ShoppingListWidgetPreferences.pinnedListId()
        await syncWidgetSnapshot()
    }

    private func syncWidgetSnapshot() async {
        guard let fetchedLists = try? await listRepository.fetchAll(householdId: householdId),
              let items = try? await shoppingRepository.fetchAll(householdId: householdId) else { return }
        ShoppingListWidgetDataStore.shared.sync(lists: fetchedLists, items: items)
    }
}

#Preview {
    NavigationStack {
        WidgetShoppingListPickerView(householdId: UUID())
    }
}
