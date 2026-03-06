import Foundation
import Observation

struct ToastMessage: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let style: Style

    enum Style: Equatable {
        case success
        case error
        case warning
        case info
    }
}

@Observable
final class ToastManager {
    static let shared = ToastManager()

    private(set) var current: ToastMessage?
    private var dismissTask: Task<Void, Never>?

    func show(_ text: String, style: ToastMessage.Style = .success, duration: TimeInterval = 2.5) {
        dismissTask?.cancel()
        current = ToastMessage(text: text, style: style)

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}
