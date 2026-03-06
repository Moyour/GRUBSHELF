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
        case .success: .successGreen
        case .error: .errorRed
        case .warning: .warningAmber
        case .info: .accentBlue
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tintColor)

            Text(message.text)
                .font(AppFont.body)
                .foregroundStyle(Color.primaryText)
                .lineLimit(2)

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - View Modifier

struct ToastModifier: ViewModifier {
    let toast: ToastManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message = toast.current {
                ToastView(message: message) {
                    toast.dismiss()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
                .zIndex(999)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: toast.current)
    }
}

extension View {
    func toastOverlay(_ manager: ToastManager = .shared) -> some View {
        modifier(ToastModifier(toast: manager))
    }
}
