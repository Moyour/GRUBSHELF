import SwiftUI

struct PendingApprovalsView: View {
    @State private var viewModel: PendingApprovalsViewModel
    @State private var itemToReject: PantryItem?
    @State private var shoppingItemToReject: ShoppingItem?
    @State private var rejectReasonText = ""
    @State private var showApproveAllPantryConfirm = false
    @State private var showApproveAllShoppingConfirm = false
    @Environment(\.dismiss) private var dismiss

    init(householdId: UUID) {
        _viewModel = State(initialValue: PendingApprovalsViewModel(householdId: householdId))
    }

    private var showBulkMenu: Bool {
        viewModel.pendingPantryItems.count >= 2 || viewModel.pendingShoppingItems.count >= 2
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                if viewModel.pendingPantryItems.isEmpty
                    && viewModel.pendingShoppingItems.isEmpty
                    && !viewModel.isLoading {
                    EmptyStateInlineBlock(
                        systemName: "checkmark.circle",
                        symbolSize: 34,
                        title: String(localized: "All caught up"),
                        subtitle: String(localized: "No pantry or shopping items are waiting for approval.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.sectionSpacing)
                }

                if !viewModel.pendingPantryItems.isEmpty {
                    section(title: "Pantry", count: viewModel.pendingPantryItems.count) {
                        ForEach(viewModel.pendingPantryItems) { item in
                            pendingPantryCard(item)
                        }
                    }
                }

                if !viewModel.pendingShoppingItems.isEmpty {
                    section(title: "Shopping", count: viewModel.pendingShoppingItems.count) {
                        ForEach(viewModel.pendingShoppingItems) { item in
                            pendingShoppingCard(item)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.vertical, AppSpacing.rowSpacing)
        }
        .background(.gsBackground)
        .navigationTitle("Pending approvals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            if showBulkMenu {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if viewModel.pendingPantryItems.count >= 2 {
                            Button {
                                showApproveAllPantryConfirm = true
                            } label: {
                                Label(
                                    "Approve all pantry (\(viewModel.pendingPantryItems.count))",
                                    systemImage: "checkmark.circle.fill"
                                )
                            }
                        }
                        if viewModel.pendingShoppingItems.count >= 2 {
                            Button {
                                showApproveAllShoppingConfirm = true
                            } label: {
                                Label(
                                    "Approve all shopping (\(viewModel.pendingShoppingItems.count))",
                                    systemImage: "checkmark.circle.fill"
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Bulk approve")
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.totalPendingCount) { _, count in
            guard !viewModel.isLoading, count == 0 else { return }
            dismiss()
        }
        .confirmationDialog(
            "Approve all \(viewModel.pendingPantryItems.count) pantry items?",
            isPresented: $showApproveAllPantryConfirm,
            titleVisibility: .visible
        ) {
            Button("Approve all") {
                Task { await viewModel.approveAllPantry() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This approves every pending pantry submission at once.")
        }
        .confirmationDialog(
            "Approve all \(viewModel.pendingShoppingItems.count) shopping items?",
            isPresented: $showApproveAllShoppingConfirm,
            titleVisibility: .visible
        ) {
            Button("Approve all") {
                Task { await viewModel.approveAllShopping() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This approves every pending shopping submission at once.")
        }
        .rejectItemAlert(
            title: "Reject pantry item?",
            itemName: itemToReject?.name,
            isPresented: .init(
                get: { itemToReject != nil },
                set: { if !$0 { itemToReject = nil } }
            ),
            reasonText: $rejectReasonText
        ) { reason in
            if let item = itemToReject {
                Task { await viewModel.rejectPantryItem(item, reason: reason) }
            }
            itemToReject = nil
        }
        .rejectItemAlert(
            title: "Reject shopping item?",
            itemName: shoppingItemToReject?.name,
            isPresented: .init(
                get: { shoppingItemToReject != nil },
                set: { if !$0 { shoppingItemToReject = nil } }
            ),
            reasonText: $rejectReasonText
        ) { reason in
            if let item = shoppingItemToReject {
                Task { await viewModel.rejectShoppingItem(item, reason: reason) }
            }
            shoppingItemToReject = nil
        }
    }

    private func pendingPantryCard(_ item: PantryItem) -> some View {
        PendingApprovalItemCard(
            title: item.name,
            subtitle: item.pendingApprovalSubtitle,
            detail: item.storageLocation.displayName,
            showsActions: true,
            onApprove: { Task { await viewModel.approvePantryItem(item) } },
            onReject: {
                itemToReject = item
                rejectReasonText = ""
            }
        )
    }

    private func pendingShoppingCard(_ item: ShoppingItem) -> some View {
        PendingApprovalItemCard(
            title: item.name,
            subtitle: PendingApprovalCopy.shoppingSubtitle,
            showsActions: true,
            onApprove: { Task { await viewModel.approveShoppingItem(item) } },
            onReject: {
                shoppingItemToReject = item
                rejectReasonText = ""
            }
        )
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
            Text("\(title) (\(count))")
                .font(BrandFont.semiBold(18))
                .foregroundStyle(.gsTextPrimary)
            Text(PendingApprovalCopy.adminHint)
                .font(BrandFont.regular(13))
                .foregroundStyle(.gsTextSecondary)
            content()
        }
    }
}
