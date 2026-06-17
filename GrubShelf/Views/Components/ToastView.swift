import SwiftUI

struct ToastView: View {
    let message: ToastMessage
    let onDismiss: () -> Void

    private var icon: String {
        switch message.style {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    private var tintColor: Color {
        switch message.style {
        case .success: .gsSuccess
        case .error: .gsDanger
        case .warning: .gsWarning
        case .info: .gsAccent
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.mediumSpacing) {
            Image(systemName: icon)
                .font(BrandSymbolFont.symbol(17, weight: .semibold))
                .foregroundStyle(tintColor)

            Text(message.text)
                .font(BrandFont.regular(17))
                .foregroundStyle(.gsTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(BrandSymbolFont.symbol(12, weight: .semibold))
                    .foregroundStyle(.gsTextSecondary)
            }
            .frame(minWidth: AppSpacing.minTouchTarget, minHeight: AppSpacing.minTouchTarget)
            .contentShape(Rectangle())
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.toastVerticalPadding)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - View Modifier

struct ToastModifier: ViewModifier {
    @Bindable var toast: ToastManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message = toast.current {
                ToastView(message: message) {
                    toast.dismiss()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, AppSpacing.smallSpacing)
                .zIndex(100_000)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: toast.current?.id)
    }
}

extension View {
    func toastOverlay(_ manager: ToastManager = .shared) -> some View {
        modifier(ToastModifier(toast: manager))
    }
}
