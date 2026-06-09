import Foundation
import UIKit

final class StorageService {
    static let shared = StorageService()
    private init() {}

    // MARK: - Upload Task Attachment
    func uploadTaskAttachment(image: UIImage, userId: String, taskId: String) async throws -> String {
        let fileName = "\(userId)/submissions/\(taskId)/\(timestamp())-\(UUID().uuidString).jpg"
        return try await upload(image: image, fileName: fileName)
    }

    // MARK: - Upload Water Attachment
    func uploadWaterAttachment(image: UIImage, userId: String) async throws -> String {
        let fileName = "\(userId)/waterLogs/\(timestamp())-\(UUID().uuidString).jpg"
        return try await upload(image: image, fileName: fileName)
    }

    // MARK: - Core Upload (Supabase Storage)
    private func upload(image: UIImage, fileName: String, quality: CGFloat = 0.75) async throws -> String {
        guard SupabaseConfig.isConfigured else {
            throw StorageError.notConfigured
        }
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw StorageError.compressionFailed
        }

        let encodedPath = fileName
            .split(separator: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")

        guard let uploadURL = URL(string: "\(SupabaseConfig.url)/storage/v1/object/\(SupabaseConfig.bucket)/\(encodedPath)") else {
            throw StorageError.uploadFailed("Invalid Supabase URL")
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StorageError.uploadFailed("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: responseData, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw StorageError.uploadFailed(msg)
        }

        return "\(SupabaseConfig.url)/storage/v1/object/public/\(SupabaseConfig.bucket)/\(encodedPath)"
    }

    // MARK: - Delete
    func deleteFile(at urlString: String) async throws {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: urlString),
              url.path.contains("/storage/v1/object/public/\(SupabaseConfig.bucket)/") else { return }

        let prefix = "/storage/v1/object/public/\(SupabaseConfig.bucket)/"
        guard let range = url.path.range(of: prefix) else { return }
        let objectPath = String(url.path[range.upperBound...])

        guard let deleteURL = URL(string: "\(SupabaseConfig.url)/storage/v1/object/\(SupabaseConfig.bucket)/\(objectPath)") else {
            return
        }

        var request = URLRequest(url: deleteURL)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

        _ = try await URLSession.shared.data(for: request)
    }

    private func timestamp() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }
}

enum StorageError: LocalizedError {
    case compressionFailed
    case notConfigured
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image. Please try again."
        case .notConfigured:
            return "Supabase is not configured. Add Supabase.plist with your project URL and anon key."
        case .uploadFailed(let message):
            return "Image upload failed: \(message)"
        }
    }
}
