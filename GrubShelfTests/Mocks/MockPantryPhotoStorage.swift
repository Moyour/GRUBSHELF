import Foundation
@testable import GrubShelf

final class MockPantryPhotoStorage: PantryPhotoStorage, @unchecked Sendable {
    var uploadedPaths: [String] = []
    var shouldThrow = false

    func uploadPhoto(data: Data, householdId: UUID, itemId: UUID) async throws -> String {
        if shouldThrow { throw NSError(domain: "test.photo", code: 1) }
        let path = "\(householdId.uuidString)/\(itemId.uuidString).jpg"
        uploadedPaths.append(path)
        return path
    }

    func publicURL(for photoPath: String) -> URL? {
        URL(string: "https://example.com/\(photoPath)")
    }
}
