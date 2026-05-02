import Foundation
import Observation

extension Notification.Name {
    static let navigateToPrevious = Notification.Name("navigateToPrevious")
    static let navigateToNext = Notification.Name("navigateToNext")
    static let toggleSlideshow = Notification.Name("toggleSlideshow")
}

@Observable
final class MediaFileManager {
    var files: [URL] = []
    var currentIndex: Int = 0

    private let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic",
        "mov", "mp4", "m4v"
    ]

    func loadMedia(in directory: URL) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )

            files = contents
                .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            currentIndex = files.isEmpty ? 0 : min(currentIndex, files.count - 1)
        } catch {
            files = []
            currentIndex = 0
        }
    }

    @discardableResult
    func findAdjacentFiles(for url: URL) -> [URL] {
        let directory = url.deletingLastPathComponent()

        if files.isEmpty || files.first?.deletingLastPathComponent() != directory {
            loadMedia(in: directory)
        }

        if let index = files.firstIndex(of: url) {
            currentIndex = index
        } else {
            currentIndex = 0
        }

        return files
    }
    
    func navigateToPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }
    
    func navigateToNext() {
        guard currentIndex < files.count - 1 else { return }
        currentIndex += 1
    }
}
