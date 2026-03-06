import Foundation

protocol FinanceSettingsRepository: Sendable {
    func fetch(userId: UUID) async throws -> FinanceSettings?
    func upsert(_ settings: FinanceSettings) async throws -> FinanceSettings
}
