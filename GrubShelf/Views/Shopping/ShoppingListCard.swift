import SwiftUI

struct ShoppingListCard: View {
    let list: ShoppingList
    let counts: (pending: Int, completed: Int)?

    private var totalItems: Int {
        guard let counts else { return 0 }
        return counts.pending + counts.completed
    }

    private var progress: Double {
        guard totalItems > 0, let counts else { return 0 }
        return Double(counts.completed) / Double(totalItems)
    }

    private var isComplete: Bool {
        totalItems > 0 && counts?.pending == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.mediumSpacing) {
            // Header: name + status
            HStack(alignment: .center) {
                // Icon
                Image(systemName: isComplete ? "checkmark.circle.fill" : "cart.fill")
                    .font(BrandSymbolFont.symbol(20))
                    .foregroundStyle(isComplete ? .gsSuccess : .gsBrandPrimary)
                    .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                    .background(
                        (isComplete ? Color.gsSuccess : Color.gsBrandPrimary).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.iconRadius))

                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                    Text(list.name)
                        .font(BrandFont.semiBold(18))
                        .foregroundStyle(.gsTextPrimary)
                        .lineLimit(1)

                    Text(list.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                }

                Spacer()

                if list.transferred {
                    StatusBadgeView(status: .custom(
                        label: "Transferred",
                        icon: "arrow.right.circle.fill",
                        color: .gsSuccess
                    ))
                } else if isComplete {
                    StatusBadgeView(status: .done)
                }

                Image(systemName: "chevron.right")
                    .font(BrandSymbolFont.symbol(11, weight: .semibold))
                    .foregroundStyle(.gsTextSecondary.opacity(0.38))
            }

            // Progress section
            if totalItems > 0 {
                VStack(spacing: AppSpacing.denseSpacing) {
                    ProgressView(value: progress)
                        .tint(.gsBrandPrimary)

                    HStack {
                        HStack(spacing: AppSpacing.compactGap) {
                            Image(systemName: "checklist")
                                .font(BrandSymbolFont.symbol(13))
                                .foregroundStyle(.gsTextSecondary)
                            Text("\(counts?.completed ?? 0)/\(totalItems)")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                        }

                        Spacer()

                        if let pending = counts?.pending, pending > 0 {
                            Text("\(pending) to go")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsBrandPrimary)
                        }
                    }
                }
            } else {
                HStack(spacing: AppSpacing.denseSpacing) {
                    Image(systemName: "tray")
                        .font(BrandSymbolFont.symbol(13))
                        .foregroundStyle(.gsTextSecondary)
                    Text("Empty list — tap to add things")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .dashboardCardSurface()
    }
}
