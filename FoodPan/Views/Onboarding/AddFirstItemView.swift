import SwiftUI

struct AddFirstItemView: View {
    let householdId: UUID
    let userId: UUID
    var onItemAdded: () -> Void

    @State private var itemName = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Spacer()

            Image(systemName: "cart.badge.plus")
                .font(.system(size: AppFont.emptyStateIconSizeSecondary))
                .foregroundStyle(Color.primaryGreen)

            Text("Add Your First Item")
                .font(AppFont.largeTitle)
                .foregroundStyle(Color.primaryText)

            Text("Start tracking your pantry by adding an item.")
                .font(AppFont.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.screenPadding)

            TextField("e.g. Milk, Rice, Eggs…", text: $itemName)
                .font(AppFont.body)
                .padding()
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                        .stroke(Color.divider, lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.screenPadding)

            Button {
                Task { await addItem() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.minTouchTarget)
                } else {
                    Text("Add to Pantry")
                        .font(AppFont.button)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.minTouchTarget)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.primaryGreen)
            .disabled(itemName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            .padding(.horizontal, AppSpacing.screenPadding)

            Button("Skip for now") {
                onItemAdded()
            }
            .font(AppFont.caption)
            .foregroundStyle(Color.secondaryText)

            Spacer()
        }
        .background(Color.appBackground)
    }

    private func addItem() async {
        isLoading = true
        let trimmedName = itemName.trimmingCharacters(in: .whitespaces)

        do {
            let repo = SupabasePantryRepository()
            let existing = try await repo.fetchAll(householdId: householdId)
            let match = existing.first { item in
                !item.archived &&
                item.name.caseInsensitiveCompare(trimmedName) == .orderedSame &&
                item.unit == .pcs &&
                item.expiryDate == nil
            }

            if var matched = match {
                matched.quantity += 1
                matched.updatedAt = .now
                _ = try await repo.update(matched)
            } else {
                let item = PantryItem(
                    itemId: UUID(),
                    householdId: householdId,
                    name: trimmedName,
                    quantity: 1,
                    unit: .pcs,
                    category: "Other",
                    expiryDate: nil,
                    costPerUnitMinor: nil,
                    lowStockThreshold: 1,
                    createdBy: userId,
                    createdAt: .now,
                    updatedAt: .now,
                    archived: false,
                    lastQuantityUpdateDate: .now,
                    expectedUsageCycleDays: PantryItem.defaultUsageCycleDays(for: "Other")
                )
                _ = try await repo.add(item)
            }
            onItemAdded()
        } catch {
            ToastManager.shared.show("Failed to add item", style: .error)
        }
        isLoading = false
    }
}
