import Foundation
import ObjectiveC.runtime
import Testing
@testable import ImageViewer

@Suite(.serialized)
struct MediaFileManagerTests {
    @Test func test_loadMedia_inSupportedDirectory_filtersAndSortsFiles() {
        FileManagerSwizzle.installIfNeeded()
        withMockedFileManager { mock in
            let directory = directoryURL("/tmp/media")
            mock.directoryContents[directory] = [
                fileURL("/tmp/media", "z.mp4"),
                fileURL("/tmp/media", "b.txt"),
                fileURL("/tmp/media", "a.png"),
                fileURL("/tmp/media", "c.JPG")
            ]

            let manager = MediaFileManager()
            manager.loadMedia(in: directory)

            #expect(manager.files == [
                fileURL("/tmp/media", "a.png"),
                fileURL("/tmp/media", "c.JPG"),
                fileURL("/tmp/media", "z.mp4")
            ])
            #expect(manager.currentIndex == 0)
        }
    }

    @Test func test_loadMedia_emptyDirectory_clearsFilesAndResetsIndex() {
        FileManagerSwizzle.installIfNeeded()
        withMockedFileManager { mock in
            let directory = directoryURL("/tmp/empty")
            mock.directoryContents[directory] = []

            let manager = MediaFileManager()
            manager.currentIndex = 3
            manager.loadMedia(in: directory)

            #expect(manager.files.isEmpty)
            #expect(manager.currentIndex == 0)
        }
    }

    @Test func test_loadMedia_nonexistentDirectory_clearsFilesAndResetsIndex() {
        FileManagerSwizzle.installIfNeeded()
        let manager = MediaFileManager()
        manager.files = [fileURL("/tmp/old", "a.jpg")]
        manager.currentIndex = 2

        manager.loadMedia(in: directoryURL("/tmp/does-not-exist"))

        #expect(manager.files.isEmpty)
        #expect(manager.currentIndex == 0)
    }

    @Test func test_loadMedia_unreadableDirectory_handlesErrorAndResetsState() {
        FileManagerSwizzle.installIfNeeded()
        withMockedFileManager { mock in
            let directory = directoryURL("/tmp/blocked")
            struct TestError: Error {}
            mock.contentsOfDirectoryHandler = { _, _ in throw TestError() }

            let manager = MediaFileManager()
            manager.files = [fileURL("/tmp/old", "a.jpg")]
            manager.currentIndex = 1
            manager.loadMedia(in: directory)

            #expect(manager.files.isEmpty)
            #expect(manager.currentIndex == 0)
        }
    }

    @Test func test_loadMedia_clampsCurrentIndexWhenDirectoryShrinks() {
        FileManagerSwizzle.installIfNeeded()
        withMockedFileManager { mock in
            let directory = directoryURL("/tmp/shrunk")
            mock.directoryContents[directory] = [
                fileURL("/tmp/shrunk", "a.jpg"),
                fileURL("/tmp/shrunk", "b.jpg")
            ]

            let manager = MediaFileManager()
            manager.currentIndex = 9
            manager.loadMedia(in: directory)

            #expect(manager.files.count == 2)
            #expect(manager.currentIndex == 1)
        }
    }

    @Test func test_findAdjacentFiles_existingFile_loadsSameDirectoryAndSetsIndex() {
        FileManagerSwizzle.installIfNeeded()
        withMockedFileManager { mock in
            let directory = directoryURL("/tmp/album")
            let files = [
                fileURL("/tmp/album", "a.jpg"),
                fileURL("/tmp/album", "b.png"),
                fileURL("/tmp/album", "c.mp4")
            ]
            mock.directoryContents[directory] = files

            let manager = MediaFileManager()
            let result = manager.findAdjacentFiles(for: files[1])

            #expect(result == files)
            #expect(manager.files == files)
            #expect(manager.currentIndex == 1)
        }
    }

    @Test func test_findAdjacentFiles_missingFile_setsIndexToZeroAndReturnsLoadedFiles() {
        FileManagerSwizzle.installIfNeeded()
        withMockedFileManager { mock in
            let directory = directoryURL("/tmp/album")
            let files = [
                fileURL("/tmp/album", "a.jpg"),
                fileURL("/tmp/album", "b.png")
            ]
            mock.directoryContents[directory] = files

            let manager = MediaFileManager()
            let result = manager.findAdjacentFiles(for: fileURL("/tmp/album", "missing.gif"))

            #expect(result == files)
            #expect(manager.currentIndex == 0)
        }
    }

    @Test func test_findAdjacentFiles_differentDirectory_reloadsTargetDirectory() {
        FileManagerSwizzle.installIfNeeded()
        withMockedFileManager { mock in
            let firstDirectory = directoryURL("/tmp/first")
            let secondDirectory = directoryURL("/tmp/second")
            let firstFiles = [fileURL("/tmp/first", "a.jpg")]
            let secondFiles = [
                fileURL("/tmp/second", "x.jpg"),
                fileURL("/tmp/second", "y.png")
            ]
            mock.directoryContents[firstDirectory] = firstFiles
            mock.directoryContents[secondDirectory] = secondFiles

            let manager = MediaFileManager()
            manager.loadMedia(in: firstDirectory)
            #expect(manager.files == firstFiles)

            let result = manager.findAdjacentFiles(for: secondFiles[1])

            #expect(result == secondFiles)
            #expect(manager.files == secondFiles)
            #expect(manager.currentIndex == 1)
        }
    }

    @Test func test_navigateToPrevious_whenIndexGreaterThanZero_decrementsIndex() {
        let manager = MediaFileManager()
        manager.files = [fileURL("/tmp", "a.jpg"), fileURL("/tmp", "b.jpg")]
        manager.currentIndex = 1

        manager.navigateToPrevious()

        #expect(manager.currentIndex == 0)
    }

    @Test func test_navigateToPrevious_whenAtStart_keepsIndexAtZero() {
        let manager = MediaFileManager()
        manager.files = [fileURL("/tmp", "a.jpg")]
        manager.currentIndex = 0

        manager.navigateToPrevious()

        #expect(manager.currentIndex == 0)
    }

    @Test func test_navigateToNext_whenIndexLessThanLast_incrementsIndex() {
        let manager = MediaFileManager()
        manager.files = [fileURL("/tmp", "a.jpg"), fileURL("/tmp", "b.jpg")]
        manager.currentIndex = 0

        manager.navigateToNext()

        #expect(manager.currentIndex == 1)
    }

    @Test func test_navigateToNext_whenAtEnd_keepsIndexAtLast() {
        let manager = MediaFileManager()
        manager.files = [fileURL("/tmp", "a.jpg"), fileURL("/tmp", "b.jpg")]
        manager.currentIndex = 1

        manager.navigateToNext()

        #expect(manager.currentIndex == 1)
    }

    @Test func test_loadMedia_supportsUppercaseAndLowercaseExtensions() {
        FileManagerSwizzle.installIfNeeded()
        withMockedFileManager { mock in
            let directory = directoryURL("/tmp/case")
            mock.directoryContents[directory] = [
                fileURL("/tmp/case", "a.JPEG"),
                fileURL("/tmp/case", "b.PnG"),
                fileURL("/tmp/case", "c.MP4"),
                fileURL("/tmp/case", "d.md")
            ]

            let manager = MediaFileManager()
            manager.loadMedia(in: directory)

            #expect(manager.files == [
                fileURL("/tmp/case", "a.JPEG"),
                fileURL("/tmp/case", "b.PnG"),
                fileURL("/tmp/case", "c.MP4")
            ])
        }
    }
}

private enum FileManagerSwizzle {
    static var installed = false
    static var activeMock: MockFileManager?

    static func installIfNeeded() {
        guard !installed else { return }
        installed = true

        let originalSelector = #selector(FileManager.contentsOfDirectory(at:includingPropertiesForKeys:options:))
        let swizzledSelector = #selector(FileManager.iv_test_contentsOfDirectory(at:includingPropertiesForKeys:options:))

        guard
            let originalMethod = class_getInstanceMethod(FileManager.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(FileManager.self, swizzledSelector)
        else {
            fatalError("Failed to install FileManager swizzle")
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension FileManager {
    @objc dynamic func iv_test_contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        if let mock = FileManagerSwizzle.activeMock {
            if let handler = mock.contentsOfDirectoryHandler {
                return try handler(url, keys)
            }

            return mock.directoryContents[url] ?? []
        }

        return try iv_test_contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
    }
}

private extension MediaFileManagerTests {
    func withMockedFileManager(_ body: (MockFileManager) throws -> Void) rethrows {
        let mock = MockFileManager()
        FileManagerSwizzle.activeMock = mock
        defer { FileManagerSwizzle.activeMock = nil }
        try body(mock)
    }

    func directoryURL(_ path: String) -> URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    func fileURL(_ directory: String, _ name: String) -> URL {
        directoryURL(directory).appendingPathComponent(name, isDirectory: false)
    }
}
