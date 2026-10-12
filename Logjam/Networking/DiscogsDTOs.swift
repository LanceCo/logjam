import Foundation

struct DiscogsCollectionResponse: Decodable {
    let releases: [DiscogsCollectionItem]
    let pagination: DiscogsPagination
}

struct DiscogsPagination: Decodable {
    let page: Int
    let pages: Int
}

struct DiscogsCollectionItem: Decodable {
    let id: Int
    let instanceId: Int
    let dateAdded: String?
    let basicInformation: DiscogsBasicInformation

    enum CodingKeys: String, CodingKey {
        case id
        case instanceId = "instance_id"
        case dateAdded = "date_added"
        case basicInformation = "basic_information"
    }
}

struct DiscogsBasicInformation: Decodable {
    let title: String
    let year: Int?
    let coverImage: URL?
    let artists: [DiscogsArtist]
    let genres: [String]?
    let styles: [String]?
    let formats: [DiscogsFormat]

    enum CodingKeys: String, CodingKey {
        case title, year, artists, genres, styles, formats
        case coverImage = "cover_image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        // Discogs returns an empty string (not omitted) for releases with no cover art,
        // which fails strict URL decoding — treat it as absent instead of failing the whole page.
        let coverImageString = try container.decodeIfPresent(String.self, forKey: .coverImage)
        coverImage = coverImageString.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        artists = try container.decode([DiscogsArtist].self, forKey: .artists)
        genres = try container.decodeIfPresent([String].self, forKey: .genres)
        styles = try container.decodeIfPresent([String].self, forKey: .styles)
        formats = try container.decode([DiscogsFormat].self, forKey: .formats)
    }
}

struct DiscogsArtist: Decodable {
    let name: String
}

struct DiscogsFormat: Decodable {
    let name: String
    let qty: String?
    let descriptions: [String]?
}

struct DiscogsReleaseDetail: Decodable {
    let tracklist: [DiscogsTrack]
    let extraartists: [DiscogsCredit]?
    let labels: [DiscogsLabel]?
}

struct DiscogsLabel: Codable {
    let name: String
}

struct DiscogsTrack: Codable {
    let position: String
    let title: String
    let duration: String?
}

struct DiscogsCredit: Codable {
    let name: String
    let role: String
}

struct DiscogsMarketplaceStats: Decodable {
    let lowestPrice: DiscogsPrice?
    let numForSale: Int?

    enum CodingKeys: String, CodingKey {
        case lowestPrice = "lowest_price"
        case numForSale = "num_for_sale"
    }
}

struct DiscogsPrice: Decodable {
    let value: Double
    let currency: String
}
