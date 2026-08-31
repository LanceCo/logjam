import UIKit
import CryptoKit

/// Memory + disk cache for remote album art. `AsyncImage` alone re-fetches on every
/// appearance and has no cross-launch persistence, which is why newly synced covers
/// would go blank until a force-quit/relaunch happened to line up with a successful
/// fetch. This cache makes a given URL's bytes available instantly after the first
/// successful load, for the rest of the app session and across relaunches, and
/// de-dupes concurrent requests for the same URL.
actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let diskCacheURL: URL
    private var inFlightTasks: [URL: Task<UIImage, Error>] = [:]

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = caches.appendingPathComponent("AlbumArtCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        if let existing = inFlightTasks[url] {
            return try await existing.value
        }

        let task = Task<UIImage, Error> {
            if let diskImage = loadFromDisk(url: url) {
                memoryCache.setObject(diskImage, forKey: url as NSURL)
                return diskImage
            }
            return try await fetchAndCache(url: url)
        }
        inFlightTasks[url] = task
        defer { inFlightTasks[url] = nil }
        return try await task.value
    }

    private func fetchAndCache(url: URL) async throws -> UIImage {
        var lastError: Error = URLError(.unknown)
        for attempt in 0..<3 {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                memoryCache.setObject(image, forKey: url as NSURL)
                saveToDisk(data: data, url: url)
                return image
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 300_000_000 * UInt64(attempt + 1))
                }
            }
        }
        throw lastError
    }

    private func diskPath(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined()
        return diskCacheURL.appendingPathComponent(filename)
    }

    private func loadFromDisk(url: URL) -> UIImage? {
        let path = diskPath(for: url)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(data: Data, url: URL) {
        try? data.write(to: diskPath(for: url), options: .atomic)
    }
}
