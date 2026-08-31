import Foundation
import os

actor DiscogsClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.discogs.com")!
    private let userAgent = "Logjam/1.0 +personal-use"
    private let logger = Logger(subsystem: "com.lanceconzett.Logjam", category: "DiscogsClient")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCollectionPage(username: String, page: Int, perPage: Int = 100) async throws -> DiscogsCollectionResponse {
        let request = try makeRequest(
            path: "/users/\(username)/collection/folders/0/releases",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]
        )
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return try decode(DiscogsCollectionResponse.self, from: data)
    }

    func fetchReleaseDetail(releaseID: Int) async throws -> DiscogsReleaseDetail {
        let request = try makeRequest(path: "/releases/\(releaseID)")
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return try decode(DiscogsReleaseDetail.self, from: data)
    }

    func fetchMarketplaceStats(releaseID: Int) async throws -> DiscogsMarketplaceStats {
        let request = try makeRequest(path: "/marketplace/stats/\(releaseID)")
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return try decode(DiscogsMarketplaceStats.self, from: data)
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw DiscogsClientError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw DiscogsClientError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let token = try? KeychainStore.shared.readDiscogsToken() {
            request.setValue("Discogs token=\(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            let description = Self.describe(error)
            logger.error("Decoding \(String(describing: type), privacy: .public) failed: \(description, privacy: .public)")
            if let json = String(data: data.prefix(4000), encoding: .utf8) {
                logger.debug("Response snippet for failed decode: \(json, privacy: .public)")
            }
            throw DiscogsClientError.decodingFailed(description)
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map(\.stringValue).joined(separator: ".")
        }
        switch error {
        case .typeMismatch(let type, let context):
            return "expected \(type) at '\(path(context))' — \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "missing value for \(type) at '\(path(context))' — \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "missing key '\(key.stringValue)' at '\(path(context))' — \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "corrupted data at '\(path(context))' — \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw DiscogsClientError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw DiscogsClientError.httpError(status: http.statusCode)
        }
    }
}

enum DiscogsClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(status: Int)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Discogs request URL."
        case .invalidResponse:
            return "Invalid response from Discogs."
        case .httpError(let status):
            return "Discogs returned HTTP \(status)."
        case .decodingFailed(let detail):
            return "Couldn't parse Discogs response: \(detail)"
        }
    }
}
