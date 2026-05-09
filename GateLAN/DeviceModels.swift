import Foundation

struct BarrierDevice: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var brandID: String
    var host: String
    var port: Int
    var scheme: String
    var path: String
    var note: String
    var lastCheckedAt: Date?
    var isOnline: Bool?

    var brand: BarrierBrand {
        BrandCatalog.brand(for: brandID)
    }

    var displayAddress: String {
        "\(scheme)://\(host):\(port)\(normalizedPath)"
    }

    var normalizedPath: String {
        guard !path.isEmpty else { return "/" }
        return path.hasPrefix("/") ? path : "/\(path)"
    }

    var adminURL: URL? {
        URL(string: displayAddress)
    }
}

struct StoredCredential: Codable, Equatable {
    var username: String
    var password: String
}

struct DiscoveredService: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var type: String
    var endpointDescription: String
    var scheme: String
    var port: Int
}
