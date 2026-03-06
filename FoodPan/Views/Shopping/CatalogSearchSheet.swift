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
                            .font(AppFont.body)
                            .foregroundStyle(Color.primaryGreen)
                    }
                }

                if let error = searchVM.errorMessage {
                    Section {
                        Text(error)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.errorRed)
                    }
                }

                if searchVM.isSearching {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }

                if !searchVM.results.isEmpty {
                    Section {
                        ForEach(searchVM.results) { item in
                            Button {
                                onSelect(item)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(AppFont.body)
                                            .foregroundStyle(Color.primaryText)
                                        Text("\(item.defaultCategory) · \(item.defaultUnit.displayName)")
                                            .font(AppFont.caption)
                                            .foregroundStyle(Color.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.primaryGreen)
                                        .font(.title3)
                                }
                            }
                            .frame(minHeight: AppSpacing.minTouchTarget)
                        }
                    } header: {
                        Text("Results")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Search Grocery Catalog")
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
