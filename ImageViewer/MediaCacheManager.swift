import AppKit
import Foundation
import Observation

@Observable
final class MediaCacheManager {
    private let cache = NSCache<NSURL, NSImage>()

    init() {
        cache.countLimit = 20
    }

    func preloadAdjacent(currentIndex: Int, files: [URL], radius: Int = 2) {
        guard !files.isEmpty, radius >= 0 else { return }

        let lowerBound = max(0, currentIndex - radius)
        let upperBound = min(files.count - 1, currentIndex + radius)

        guard lowerBound <= upperBound else { return }

        for index in lowerBound...upperBound {
            let url = files[index]
            guard shouldCacheMedia(at: url) else { continue }
            let key = url as NSURL

            if cache.object(forKey: key) != nil {
                continue
            }

            Task.detached(priority: .utility) { [cache] in
                guard let image = NSImage(contentsOf: url) else { return }
                cache.setObject(image, forKey: key)
            }
        }
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    private func shouldCacheMedia(at url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()

        if isVideoExtension(ext) {
            return false
        }

        return isImageExtension(ext)
    }

    private func isImageExtension(_ ext: String) -> Bool {
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic":
            return true
        default:
            return false
        }
    }

    private func isVideoExtension(_ ext: String) -> Bool {
        switch ext {
        case "mov", "mp4", "m4v", "avi", "mkv", "webm":
            return true
        default:
            return false
        }
    }
}
