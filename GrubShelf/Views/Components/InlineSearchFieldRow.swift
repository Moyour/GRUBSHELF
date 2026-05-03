import SwiftUI

/// Shared inline search row (magnifying glass + field + optional clear). Use everywhere we show a search field inside a card for visual consistency.
struct InlineSearchFieldRow: View {
    @Binding var text: String
    let placeholder: String
    var submitLabel: SubmitLabel = .search
    var autocorrectionDisabled: Bool = false
    var showClearButton: Bool = true
    var accessibilityLabel: String = "Search"
    var onSubmit: (() -> Void)?
    var onClear: (() -> Void)?

    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: AppSpacing.smallSpacing) {
            Image(systemName: "magnifyingglass")
                .font(BrandSymbolFont.symbol(15, weight: .regular))
                .foregroundStyle(.gsTextSecondary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .font(BrandFont.regular(15))
                .focused($isFocused)
                .autocorrectionDisabled(autocorrectionDisabled)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }

            if showClearButton, !text.isEmpty {
                Button {
                    text = ""
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(BrandSymbolFont.symbol(15, weight: .regular))
                        .foregroundStyle(.gsTextSecondary)
                }
                .buttonStyle(.plain)
                .frame(minWidth: AppSpacing.minTouchTarget, minHeight: AppSpacing.minTouchTarget)
                .contentShape(Rectangle())
                .accessibilityLabel("Clear")
            }
        }
        .padding(.vertical, AppSpacing.compactGap)
        .frame(minHeight: AppSpacing.inlineSearchRowMinHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}
