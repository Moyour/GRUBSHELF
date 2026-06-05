import Foundation
import Network
import Observation

/// Monitors network connectivity status using NWPathMonitor.
/// Provides real-time updates when device goes online/offline.
@MainActor
@Observable
final class NetworkMonitor {
    /// Shared singleton instance
    static let shared = NetworkMonitor()

    /// Current network connectivity status
    private(set) var isConnected = true

    /// Whether monitoring has started
    private(set) var isMonitoring = false

    /// Incremented each time network reconnects after being offline
    private(set) var reconnectionCount = 0

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.grubshelf.networkmonitor")

    private init() {}

    /// Start monitoring network status
    func startMonitoring() {
        guard !isMonitoring else { return }

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                let wasConnected = self.isConnected
                let nowConnected = path.status == .satisfied

                self.isConnected = nowConnected

                // Increment reconnection count when transitioning from offline to online
                if !wasConnected && nowConnected {
                    self.reconnectionCount += 1
                }
            }
        }

        monitor.start(queue: queue)
        isMonitoring = true
    }

    /// Stop monitoring network status
    func stopMonitoring() {
        guard isMonitoring else { return }

        monitor.cancel()
        isMonitoring = false
    }
}
