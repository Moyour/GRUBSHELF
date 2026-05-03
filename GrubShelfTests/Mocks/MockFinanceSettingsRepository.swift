import Foundation
@testable import GrubShelf

final class MockFinanceSettingsRepository: FinanceSettingsRepository, @unchecked Sendable {
    var settings: FinanceSettings?
    var shouldThrow = false

    func fetch(userId: UUID) async throws -> FinanceSettings? {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return settings
    }

    func upsert(_ settings: FinanceSettings) async throws -> FinanceSettings {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        self.settings = settings
        return settings
    }
}
