import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ImageViewer

@MainActor
final class MediaCacheManagerTests: XCTestCase {
    func test_imageFor_whenImageIsMissing_returnsNil() throws {
        let manager = MediaCacheManager()
        let url = try makeImageURL(name: "missing-image", extension: "png")

        XCTAssertNil(manager.image(for: url))
    }

    func test_imageFor_whenImageIsCached_returnsImage() async throws {
        let manager = MediaCacheManager()
        let url = try makeImageURL(name: "cached-image", extension: "png")

        manager.preloadAdjacent(currentIndex: 0, files: [url], radius: 0)
        await waitUntilCached(urls: [url], manager: manager)

        XCTAssertNotNil(manager.image(for: url))
    }

    func test_clearCache_afterCachedImage_removesEntry() async throws {
        let manager = MediaCacheManager()
        let url = try makeImageURL(name: "clear-cache-image", extension: "jpg")

        manager.preloadAdjacent(currentIndex: 0, files: [url], radius: 0)
        await waitUntilCached(urls: [url], manager: manager)
        XCTAssertNotNil(manager.image(for: url))

        manager.clearCache()

        XCTAssertNil(manager.image(for: url))
    }

    func test_preloadAdjacent_whenCenterIndexCachesImageFormats_cachesOnlyImages() async throws {
        let manager = MediaCacheManager()
        let files = try makeMixedMediaFiles()

        manager.preloadAdjacent(currentIndex: 2, files: files, radius: 1)
        await waitUntilCached(urls: [files[2], files[3]], manager: manager)

        XCTAssertNil(manager.image(for: files[1]))
        XCTAssertNotNil(manager.image(for: files[2]))
        XCTAssertNotNil(manager.image(for: files[3]))
        XCTAssertNil(manager.image(for: files[4]))
    }

    func test_preloadAdjacent_whenIndexIsAtStart_clampsLowerBound() async throws {
        let manager = MediaCacheManager()
        let files = try makeMixedMediaFiles()

        manager.preloadAdjacent(currentIndex: 0, files: files, radius: 2)
        await waitUntilCached(urls: [files[0], files[2]], manager: manager)

        XCTAssertNotNil(manager.image(for: files[0]))
        XCTAssertNil(manager.image(for: files[1]))
        XCTAssertNotNil(manager.image(for: files[2]))
        XCTAssertNil(manager.image(for: files[3]))
    }

    func test_preloadAdjacent_whenIndexIsAtEnd_clampsUpperBound() async throws {
        let manager = MediaCacheManager()
        let files = try makeMixedMediaFiles()

        manager.preloadAdjacent(currentIndex: files.count - 1, files: files, radius: 2)
        await waitUntilCached(urls: [files[2], files[3]], manager: manager)

        XCTAssertNil(manager.image(for: files[0]))
        XCTAssertNil(manager.image(for: files[1]))
        XCTAssertNotNil(manager.image(for: files[2]))
        XCTAssertNotNil(manager.image(for: files[3]))
        XCTAssertNil(manager.image(for: files[4]))
    }

    func test_preloadAdjacent_whenFilesIsEmpty_doesNothing() async throws {
        let manager = MediaCacheManager()
        let url = try makeImageURL(name: "empty-files-image", extension: "png")

        manager.preloadAdjacent(currentIndex: 0, files: [], radius: 2)
        await waitBriefly()

        XCTAssertNil(manager.image(for: url))
    }

    func test_preloadAdjacent_whenRadiusIsNegative_doesNothing() async throws {
        let manager = MediaCacheManager()
        let url = try makeImageURL(name: "negative-radius-image", extension: "png")

        manager.preloadAdjacent(currentIndex: 0, files: [url], radius: -1)
        await waitBriefly()

        XCTAssertNil(manager.image(for: url))
    }

    func test_preloadAdjacent_whenFilesIncludeVideoExtensions_skipsVideoFiles() async throws {
        let manager = MediaCacheManager()
        let files = try makeMixedMediaFiles()

        manager.preloadAdjacent(currentIndex: 2, files: files, radius: 2)
        await waitUntilCached(urls: [files[0], files[2], files[3]], manager: manager)

        XCTAssertNotNil(manager.image(for: files[0]))
        XCTAssertNil(manager.image(for: files[1]))
        XCTAssertNotNil(manager.image(for: files[2]))
        XCTAssertNotNil(manager.image(for: files[3]))
        XCTAssertNil(manager.image(for: files[4]))
    }

    private func waitBriefly(timeout: TimeInterval = 0.25) async {
        let expectation = expectation(description: "brief wait")
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            expectation.fulfill()
        }
        await waitForExpectations(timeout: timeout + 0.5)
    }

    private func waitUntilCached(
        urls: [URL],
        manager: MediaCacheManager,
        timeout: TimeInterval = 0.5
    ) async {
        let expectation = expectation(description: "wait for cached images")
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            expectation.fulfill()
        }

        await waitForExpectations(timeout: timeout + 0.5)

        XCTAssertTrue(urls.allSatisfy { manager.image(for: $0) != nil })
    }

    private func makeMixedMediaFiles() throws -> [URL] {
        let directory = try TestDataFactory.makeTemporaryDirectory(prefix: "MediaCacheManagerTests")
        return [
            try makeImageFile(in: directory, name: "one", extension: "jpg", fileType: .jpeg),
            try makeVideoFile(in: directory, name: "two", extension: "mov"),
            try makeImageFile(in: directory, name: "three", extension: "png", fileType: .png),
            try makeImageFile(in: directory, name: "four", extension: "gif", fileType: .gif),
            try makeVideoFile(in: directory, name: "five", extension: "mp4")
        ]
    }

    private func makeImageURL(name: String, `extension`: String) throws -> URL {
        let directory = try TestDataFactory.makeTemporaryDirectory(prefix: "MediaCacheManagerTests")
        let fileType: UTType

        switch `extension` {
        case "jpg", "jpeg":
            fileType = .jpeg
        case "png":
            fileType = .png
        case "gif":
            fileType = .gif
        default:
            fileType = .png
        }

        return try makeImageFile(in: directory, name: name, extension: `extension`, fileType: fileType)
    }

    private func makeImageFile(
        in directory: URL,
        name: String,
        extension fileExtension: String,
        fileType: UTType
    ) throws -> URL {
        let url = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
        let data = try makeImageData(fileType: fileType)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makeVideoFile(
        in directory: URL,
        name: String,
        extension fileExtension: String
    ) throws -> URL {
        let url = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
        try Data(repeating: 0x00, count: 32).write(to: url, options: .atomic)
        return url
    }

    private func makeImageData(fileType: UTType) throws -> Data {
        let width = 1
        let height = 1
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        var pixel: [UInt8] = [255, 0, 0, 255]

        guard let context = CGContext(
            data: &pixel,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "MediaCacheManagerTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap context"])
        }

        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "MediaCacheManagerTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"])
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, fileType.identifier as CFString, 1, nil) else {
            throw NSError(domain: "MediaCacheManagerTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "MediaCacheManagerTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize image destination"])
        }

        return data as Data
    }
}
