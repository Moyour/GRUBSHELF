import Foundation
import os
import Supabase

/// Creates a debounced `AsyncStream` that observes Supabase Realtime changes on a table,
/// refetches after a 300 ms quiet period, and yields the updated collection.
///
/// This replaces the ~40-line boilerplate previously duplicated across every repository.
func observeWithDebounce<T: Sendable>(
    client: SupabaseClient,
    channelName: String,
    table: String,
    filterColumn: String,
    filterValue: any RealtimePostgresFilterValue,
    logCategory: String,
    fetch: @escaping @Sendable () async throws -> [T]
) -> AsyncStream<[T]> {
    AsyncStream { continuation in
        let channel = client.realtimeV2.channel(channelName)

        let task = Task {
            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: table,
                filter: .eq(filterColumn, value: filterValue)
            )

            try? await channel.subscribeWithError()

            var debounceTask: Task<Void, Never>?
            for await _ in changes {
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    do {
                        let items = try await fetch()
                        continuation.yield(items)
                    } catch {
                        Logger(subsystem: "com.grubshelf", category: logCategory)
                            .error("Realtime refetch failed: \(error.localizedDescription)")
                    }
                }
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
            Task { await channel.unsubscribe() }
        }
    }
}
