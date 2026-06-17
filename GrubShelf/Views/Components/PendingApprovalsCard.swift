import SwiftUI

// MARK: - Copy

enum PendingApprovalCopy {
    static let homeSubtitle = "Approve or reject each submission"
    static let adminHint = "Use Approve or Reject on each item below."
    static let memberWaitingTitle = "Waiting for approval"
    static let memberWaitingHint = "An admin will review these before they appear."
    static let rejectedTitle = "Rejected"
    static let shoppingSubtitle = "Shopping list"
    static let emptyTitle = "All caught up"
    static let emptySubtitle = "No pantry or shopping items are waiting for approval."
}

// MARK: - Home card

struct PendingApprovalsCard: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.rowSpacing) {
                Image(systemName: "tray.full.fill")
                    .font(BrandSymbolFont.symbol(20, weight: .semibold))
                    .foregroundStyle(.gsWarning)
                    .frame(width: 44, height: 44)
                    .background(Color.gsWarning.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                    Text("\(count) item\(count == 1 ? "" : "s") need approval")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                    Text(PendingApprovalCopy.homeSubtitle)
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                }

                Spacer(minLength: AppSpacing.smallSpacing)

                Image(systemName: "chevron.right")
                    .font(BrandSymbolFont.symbol(13, weight: .semibold))
                    .foregroundStyle(.gsTextSecondary)
            }
            .padding(AppSpacing.cardPadding)
            .dashboardCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) items need approval")
        .accessibilityHint("Opens pending approvals")
    }
}

// MARK: - Item card

struct PendingApprovalItemCard: View {
    let title: String
    let subtitle: String
    var detail: String? = nil
    var status: ApprovalStatus = .pending
    let showsActions: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack(alignment: .top, spacing: AppSpacing.rowSpacing) {
                Image(systemName: iconName)
                    .font(BrandSymbolFont.symbol(26, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                    Text(title)
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                        .lineLimit(2)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(BrandFont.regular(13))
                            .foregroundStyle(.gsTextSecondary.opacity(0.9))
                    }
                }

                Spacer(minLength: AppSpacing.smallSpacing)

                if !showsActions || status != .pending {
                    ApprovalStatusBadge(status: status)
                }
            }

            if showsActions {
                HStack(spacing: AppSpacing.smallSpacing) {
                    Button(role: .destructive, action: onReject) {
                        Label("Reject", systemImage: "xmark")
                            .font(BrandFont.semiBold(15))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.compactGap)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gsDanger)

                    Button(action: onApprove) {
                        Label("Approve", systemImage: "checkmark")
                            .font(BrandFont.semiBold(15))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.compactGap)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gsSuccess)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .dashboardCardSurfaceElevated()
        .accessibilityElement(children: showsActions ? .contain : .combine)
        .accessibilityHint(showsActions ? "Approve or reject this submission" : "Waiting for admin review")
    }

    private var iconName: String {
        switch status {
        case .approved: "checkmark.circle.fill"
        case .pending: "hourglass.circle.fill"
        case .rejected: "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .approved: .gsSuccess
        case .pending: .gsWarning
        case .rejected: .gsDanger
        }
    }
}

// MARK: - Badge

struct ApprovalStatusBadge: View {
    let status: ApprovalStatus

    var body: some View {
        Text(label)
            .font(BrandFont.medium(12))
            .padding(.horizontal, AppSpacing.smallSpacing)
            .padding(.vertical, AppSpacing.compactGap)
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .approved: "Approved"
        case .pending: "Pending"
        case .rejected: "Rejected"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .approved: .gsSuccess
        case .pending: .gsWarning
        case .rejected: .gsDanger
        }
    }
}

// MARK: - Pantry sections

extension PantryItem {
    var pendingApprovalSubtitle: String {
        "\(quantity.formatted()) \(unit.abbreviation) · \(category)"
    }
}

struct PendingApprovalPantrySection: View {
    enum Role {
        case admin
        case memberWaiting
        case memberRejected
    }

    let role: Role
    let items: [PantryItem]
    var onReviewAll: (() -> Void)? = nil
    var onApprove: (PantryItem) -> Void = { _ in }
    var onReject: (PantryItem) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
            header
            if role == .admin {
                Text(PendingApprovalCopy.adminHint)
                    .font(BrandFont.regular(13))
                    .foregroundStyle(.gsTextSecondary)
            } else if role == .memberWaiting {
                Text(PendingApprovalCopy.memberWaitingHint)
                    .font(BrandFont.regular(13))
                    .foregroundStyle(.gsTextSecondary)
            }
            ForEach(items) { item in
                PendingApprovalItemCard(
                    title: item.name,
                    subtitle: item.pendingApprovalSubtitle,
                    detail: item.storageLocation.displayName,
                    status: role == .memberRejected ? .rejected : .pending,
                    showsActions: role == .admin,
                    onApprove: { onApprove(item) },
                    onReject: { onReject(item) }
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var header: some View {
        switch role {
        case .admin:
            HStack {
                Text("Pending approval (\(items.count))")
                    .font(BrandFont.semiBold(15))
                    .foregroundStyle(.gsTextSecondary)
                Spacer()
                if items.count > 1, let onReviewAll {
                    Button("See all", action: onReviewAll)
                        .font(BrandFont.medium(14))
                }
            }
        case .memberWaiting:
            Text(PendingApprovalCopy.memberWaitingTitle)
                .font(BrandFont.semiBold(15))
                .foregroundStyle(.gsTextSecondary)
        case .memberRejected:
            Text(PendingApprovalCopy.rejectedTitle)
                .font(BrandFont.semiBold(15))
                .foregroundStyle(.gsTextSecondary)
        }
    }
}

// MARK: - Shopping inline section

struct PendingApprovalShoppingSection: View {
    let items: [ShoppingItem]
    var isAdmin: Bool
    var onApprove: (ShoppingItem) -> Void = { _ in }
    var onReject: (ShoppingItem) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
            Text(isAdmin ? "Pending approval" : PendingApprovalCopy.memberWaitingTitle)
                .font(BrandFont.semiBold(14))
                .foregroundStyle(.gsTextSecondary)
                .padding(.horizontal, AppSpacing.cardPadding)

            if isAdmin {
                Text(PendingApprovalCopy.adminHint)
                    .font(BrandFont.regular(13))
                    .foregroundStyle(.gsTextSecondary)
                    .padding(.horizontal, AppSpacing.cardPadding)
            }

            ForEach(items) { item in
                PendingApprovalItemCard(
                    title: item.name,
                    subtitle: PendingApprovalCopy.shoppingSubtitle,
                    showsActions: isAdmin,
                    onApprove: { onApprove(item) },
                    onReject: { onReject(item) }
                )
                .padding(.horizontal, AppSpacing.cardPadding)
            }
        }
    }
}

// MARK: - Reject alert helper

struct RejectItemAlertModifier: ViewModifier {
    let title: String
    let itemName: String?
    @Binding var isPresented: Bool
    @Binding var reasonText: String
    let onReject: (String?) -> Void

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            TextField("Reason (optional)", text: $reasonText)
            Button("Reject", role: .destructive) {
                let trimmed = reasonText.trimmingCharacters(in: .whitespacesAndNewlines)
                onReject(trimmed.isEmpty ? nil : trimmed)
                reasonText = ""
            }
            Button("Cancel", role: .cancel) {
                reasonText = ""
            }
        } message: {
            if let itemName {
                Text("\"\(itemName)\" won’t be added until approved.")
            }
        }
    }
}

extension View {
    func rejectItemAlert(
        title: String,
        itemName: String?,
        isPresented: Binding<Bool>,
        reasonText: Binding<String>,
        onReject: @escaping (String?) -> Void
    ) -> some View {
        modifier(RejectItemAlertModifier(
            title: title,
            itemName: itemName,
            isPresented: isPresented,
            reasonText: reasonText,
            onReject: onReject
        ))
    }
}
