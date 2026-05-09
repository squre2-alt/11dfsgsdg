import Foundation

struct BarrierBrand: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let defaultScheme: String
    let defaultPort: Int
    let defaultPath: String
}

enum BrandCatalog {
    static let brands: [BarrierBrand] = [
        .init(id: "custom", name: "自定义", defaultScheme: "http", defaultPort: 80, defaultPath: "/"),
        .init(id: "hikvision", name: "海康威视", defaultScheme: "http", defaultPort: 80, defaultPath: "/"),
        .init(id: "dahua", name: "大华", defaultScheme: "http", defaultPort: 80, defaultPath: "/"),
        .init(id: "jieshun", name: "捷顺", defaultScheme: "http", defaultPort: 80, defaultPath: "/"),
        .init(id: "ketuo", name: "科拓", defaultScheme: "http", defaultPort: 80, defaultPath: "/"),
        .init(id: "lifang", name: "立方", defaultScheme: "http", defaultPort: 80, defaultPath: "/"),
        .init(id: "baisheng", name: "百胜", defaultScheme: "http", defaultPort: 80, defaultPath: "/"),
        .init(id: "hongmen", name: "红门", defaultScheme: "http", defaultPort: 80, defaultPath: "/")
    ]

    static func brand(for id: String) -> BarrierBrand {
        brands.first { $0.id == id } ?? brands[0]
    }
}
