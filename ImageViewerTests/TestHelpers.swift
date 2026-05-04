import Foundation
import XCTest

final class MockFileManager: FileManager {
    var directoryContents: [URL: [URL]] = [:]
    var contentsOfDirectoryHandler: ((URL, [URLResourceKey]?) throws -> [URL])?

    override func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        if let contentsOfDirectoryHandler {
            return try contentsOfDirectoryHandler(url, keys)
        }

        return directoryContents[url] ?? []
    }
}

enum TestDataFactory {
    static func makeTemporaryDirectory(prefix: String = "ImageViewerTests") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func makeTemporaryFile(
        name: String = UUID().uuidString,
        extension fileExtension: String,
        contents: Data = Data()
    ) throws -> URL {
        let directory = try makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
        try contents.write(to: fileURL, options: .atomic)
        return fileURL
    }

    static func makeTemporaryImageURL(extension fileExtension: String = "jpg") throws -> URL {
        try makeTemporaryFile(
            extension: fileExtension,
            contents: Data([0xFF, 0xD8, 0xFF, 0xD9])
        )
    }

    static func makeTemporaryVideoURL(extension fileExtension: String = "mp4") throws -> URL {
        try makeTemporaryFile(
            extension: fileExtension,
            contents: Data(repeating: 0, count: 16)
        )
    }
}

@MainActor
extension XCTestCase {
    func waitForExpectations(timeout: TimeInterval) async {
        await withCheckedContinuation { continuation in
            waitForExpectations(timeout: timeout) { error in
                if let error {
                    XCTFail("Expectation timed out: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }
}
