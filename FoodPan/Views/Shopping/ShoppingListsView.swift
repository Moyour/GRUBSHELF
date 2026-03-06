import SwiftUI

struct ShoppingListsView: View {
    @State private var viewModel: ShoppingListsViewModel
    @Binding var showSettings: Bool

    init(viewModel: ShoppingListsViewModel, showSettings: Binding<Bool>) {
        _viewModel = State(initialValue: viewModel)
        _showSettings = showSettings
    }

    // MARK: - Computed Stats

    private var totalLists: Int { viewModel.lists.count }

    private var activeLists: Int {
        viewModel.lists.filter { !$0.transferred }.count
    }

    private var totalPendingItems: Int {
        viewModel.listItemCounts.values.reduce(0) { $0 + $1.pending }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                if !viewModel.hasLoaded {
                    Color.clear
                } else if viewModel.lists.isEmpty {
                    emptyStateView
                } else {
                    listContent
                }

                FloatingAddButton {
                    viewModel.showCreateSheet = true
                }
                .padding(AppSpacing.screenPadding)
            }
            .navigationTitle("Shop")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .background(Color.appBackground)
            .task {
                await viewModel.loadLists()
                viewModel.startObserving()
            }
            .onDisappear {
                viewModel.stopObserving()
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateShoppingListSheet(viewModel: viewModel)
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Empty State (#2)

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                Spacer(minLength: 40)

                Image("onboarding-shopping")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 200)
                    .accessibilityHidden(true)

                VStack(spacing: AppSpacing.rowSpacing) {
                    Text("No Shopping Lists Yet")
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(Color.primaryText)

                    Text("Create a list to plan your grocery trips and never forget an item.")
                        .font(AppFont.body)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.screenPadding)
                }

                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Label("Create Your First List", systemImage: "cart.badge.plus")
                        .font(AppFont.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.minTouchTarget)
                        .background(Color.primaryGreen)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - List Content with Stats (#1)

    private var listContent: some View {
        List {
            // Summary stats row
            Section {
                HStack(spacing: 0) {
                    ActionPill(
                        icon: "list.bullet.clipboard",
                        value: "\(totalLists)",
                        label: "Lists",
                        color: .accentBlue
                    )
                    ActionPill(
                        icon: "cart",
                        value: "\(activeLists)",
                        label: "Active",
                        color: .primaryGreen
                    )
                    ActionPill(
                        icon: "bag",
                        value: "\(totalPendingItems)",
                        label: "To Buy",
                        color: .warningAmber
                    )
                }
            }
            .listRowInsets(EdgeInsets(
                top: AppSpacing.rowSpacing / 2,
                leading: AppSpacing.screenPadding,
                bottom: AppSpacing.rowSpacing / 2,
                trailing: AppSpacing.screenPadding
            ))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // List cards
            ForEach(viewModel.lists) { list in
                NavigationLink(value: list) {
                    ShoppingListCard(
                        list: list,
                        counts: viewModel.listItemCounts[list.listId]
                    )
                }
                .listRowInsets(EdgeInsets(
                    top: AppSpacing.rowSpacing / 2,
                    leading: AppSpacing.screenPadding,
                    bottom: AppSpacing.rowSpacing / 2,
                    trailing: AppSpacing.screenPadding
                ))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteList(list) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: ShoppingList.self) { list in
            ShoppingListDetailView(
                list: list,
                householdId: viewModel.householdId,
                userId: viewModel.userId
            )
        }
    }
}
