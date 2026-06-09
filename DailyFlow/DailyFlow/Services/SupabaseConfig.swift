import Foundation

enum SupabaseConfig {
    private static let plist: [String: Any]? = {
        guard
            let url = Bundle.main.url(forResource: "Supabase", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return dict
    }()

    static var url: String {
        (plist?["SUPABASE_URL"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static var anonKey: String {
        (plist?["SUPABASE_ANON_KEY"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var bucket: String {
        (plist?["SUPABASE_BUCKET"] as? String ?? "images")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var isConfigured: Bool {
        !url.isEmpty && !anonKey.isEmpty && URL(string: url) != nil
    }
}
