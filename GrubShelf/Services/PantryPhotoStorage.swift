import Foundation
import Supabase

protocol PantryPhotoStorage: Sendable {
    func uploadPhoto(data: Data, householdId: UUID, itemId: UUID) async throws -> String
    func publicURL(for photoPath: String) -> URL?
}

struct SupabasePantryPhotoStorage: PantryPhotoStorage {
    static let bucketName = "pantry-item-photos"

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func uploadPhoto(data: Data, householdId: UUID, itemId: UUID) async throws -> String {
        let path = "\(householdId.uuidString)/\(itemId.uuidString).jpg"
        _ = try await client.storage
            .from(Self.bucketName)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        return path
    }

    func publicURL(for photoPath: String) -> URL? {
        try? client.storage.from(Self.bucketName).getPublicURL(path: photoPath)
    }
}
