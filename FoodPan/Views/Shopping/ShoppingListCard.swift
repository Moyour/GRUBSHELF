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
        VStack(alignment: .leading, spacing: 10) {
            // Header: name + status
            HStack(alignment: .center) {
                // Icon
                Image(systemName: isComplete ? "checkmark.circle.fill" : "cart.fill")
                    .font(.title3)
                    .foregroundStyle(isComplete ? Color.successGreen : Color.accentBlue)
                    .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                    .background(
                        (isComplete ? Color.successGreen : Color.accentBlue).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.iconRadius))

                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(1)

                    Text(list.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(AppFont.badgeLabel)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()

                // Status badge
                if list.transferred {
                    Text("Transferred")
                        .font(AppFont.badgeLabel)
                        .foregroundStyle(Color.successGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.successGreen.opacity(0.12))
                        .clipShape(Capsule())
                } else if isComplete {
                    Text("Ready")
                        .font(AppFont.badgeLabel)
                        .foregroundStyle(Color.primaryGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primaryGreen.opacity(0.12))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText.opacity(0.5))
            }

            // Progress section
            if totalItems > 0 {
                VStack(spacing: 6) {
                    ProgressView(value: progress)
                        .tint(isComplete ? Color.successGreen : Color.primaryGreen)

                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "checklist")
                                .font(AppFont.badgeLabel)
                                .foregroundStyle(Color.secondaryText)
                            Text("\(counts?.completed ?? 0)/\(totalItems)")
                                .font(AppFont.detail)
                                .foregroundStyle(Color.secondaryText)
                        }

                        Spacer()

                        if let pending = counts?.pending, pending > 0 {
                            Text("\(pending) to go")
                                .font(AppFont.detail)
                                .foregroundStyle(Color.accentBlue)
                        } else {
                            Text("All done!")
                                .font(AppFont.detail)
                                .foregroundStyle(Color.successGreen)
                        }
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(AppFont.badgeLabel)
                        .foregroundStyle(Color.secondaryText)
                    Text("No items yet — tap to add")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .cardShadow()
    }
}
