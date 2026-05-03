import SwiftUI

struct CatalogSearchSheet: View {
    @State private var searchVM: GroceryCatalogSearchViewModel
    @Environment(\.dismiss) private var dismiss

    let onSelect: (GroceryCatalogItem) -> Void
    let onAddManually: () -> Void

    init(
        catalogRepository: GroceryCatalogRepository,
        onSelect: @escaping (GroceryCatalogItem) -> Void,
        onAddManually: @escaping () -> Void
    ) {
        _searchVM = State(initialValue: GroceryCatalogSearchViewModel(repository: catalogRepository))
        self.onSelect = onSelect
        self.onAddManually = onAddManually
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        dismiss()
                        onAddManually()
                    } label: {
                        Label("Add manually", systemImage: "pencil")
                            .font(BrandFont.regular(17))
                            .foregroundStyle(.gsBrandPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(AppSpacing.cardPadding)
                    .dashboardCardSurface()
                    .listRowInsets(AppSpacing.listRowCardInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if let error = searchVM.errorMessage {
                    Section {
                        Text(error)
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.cardPadding)
                            .dashboardCardSurface()
                            .listRowInsets(AppSpacing.listRowCardInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                if searchVM.isSearching {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(AppSpacing.cardPadding)
                        .dashboardCardSurface()
                        .listRowInsets(AppSpacing.listRowCardInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }

                if !searchVM.results.isEmpty {
                    Section {
                        ForEach(searchVM.results) { item in
                            Button {
                                onSelect(item)
                                dismiss()
                            } label: {
                                HStack(spacing: AppSpacing.rowSpacing) {
                                    Text(ItemIconMapper.emoji(for: item.name, category: item.defaultCategory))
                                        .font(BrandFont.regular(24))

                                    VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                                        Text(item.name)
                                            .font(BrandFont.regular(17))
                                            .foregroundStyle(.gsTextPrimary)
                                        Text("\(item.defaultCategory) · \(item.defaultUnit.displayName)")
                                            .font(BrandFont.regular(14))
                                            .foregroundStyle(.gsTextSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.gsBrandPrimary)
                                        .font(BrandSymbolFont.symbol(20))
                                }
                            }
                            .frame(minHeight: AppSpacing.minTouchTarget)
                            .padding(AppSpacing.cardPadding)
                            .dashboardCardSurface()
                            .listRowInsets(AppSpacing.listRowCardInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("Results")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("Search grocery catalog")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchVM.searchText, prompt: "Search items (min 2 chars)…")
            .onChange(of: searchVM.searchText) {
                searchVM.performSearch()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
