import AppKit
import SwiftUI
import XCTest
import ViewInspector
@testable import ImageViewer

@MainActor
final class ContentViewTests: XCTestCase {
    private enum ImageCreationError: Error {
        case pngRepresentationUnavailable
    }

    private func makeManagers(
        files: [URL] = [],
        currentIndex: Int = 0
    ) -> (mediaFileManager: MediaFileManager, mediaCacheManager: MediaCacheManager) {
        let mediaFileManager = MediaFileManager()
        mediaFileManager.files = files
        mediaFileManager.currentIndex = currentIndex

        let mediaCacheManager = MediaCacheManager()

        return (mediaFileManager, mediaCacheManager)
    }

    private func makeTemporaryPNGFile(name: String = UUID().uuidString) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageViewerTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent(name).appendingPathExtension("png")
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1, height: 1)).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageCreationError.pngRepresentationUnavailable
        }

        try pngData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func test_contentView_whenMediaIsEmpty_showsEmptyStateAndViewHierarchy() throws {
        let (mediaFileManager, mediaCacheManager) = makeManagers()
        var sut = ContentView()

        let exp = sut.on(\.didAppear) { view in
            XCTAssertEqual(view.findAll(ViewType.ZStack.self).count, 1)
            XCTAssertEqual(view.findAll(ViewType.VStack.self).count, 1)
            XCTAssertEqual(try view.find(text: "No media found").string(), "No media found")
        }

        ViewHosting.host(view: sut.environment(mediaFileManager).environment(mediaCacheManager))
        wait(for: [exp], timeout: 1)
    }

    func test_contentView_whenMediaIsEmpty_rendersToolbarButtonsWithDisabledNavigation() throws {
        let (mediaFileManager, mediaCacheManager) = makeManagers()
        var sut = ContentView()

        let exp = sut.on(\.didAppear) { view in
            let buttons = view.findAll(ViewType.Button.self)

            XCTAssertEqual(buttons.count, 8)
            XCTAssertTrue(buttons[0].isDisabled())
            XCTAssertTrue(buttons[1].isDisabled())
            XCTAssertFalse(buttons[2].isDisabled())
            XCTAssertFalse(buttons[3].isDisabled())
            XCTAssertFalse(buttons[4].isDisabled())
            XCTAssertFalse(buttons[5].isDisabled())
            XCTAssertFalse(buttons[6].isDisabled())
            XCTAssertFalse(buttons[7].isDisabled())
        }

        ViewHosting.host(view: sut.environment(mediaFileManager).environment(mediaCacheManager))
        wait(for: [exp], timeout: 1)
    }

    func test_contentView_whenMediaExists_displaysCurrentFileStatusText() throws {
        let files = [
            URL(fileURLWithPath: "/tmp/alpha.jpg"),
            URL(fileURLWithPath: "/tmp/beta.jpg")
        ]
        let (mediaFileManager, mediaCacheManager) = makeManagers(files: files, currentIndex: 0)
        var sut = ContentView()

        let exp = sut.on(\.didAppear) { view in
            XCTAssertEqual(try view.find(text: "alpha.jpg — 1 / 2").string(), "alpha.jpg — 1 / 2")
        }

        ViewHosting.host(view: sut.environment(mediaFileManager).environment(mediaCacheManager))
        wait(for: [exp], timeout: 1)
    }

    func test_contentView_whenCurrentIndexChanges_updatesStatusText() throws {
        let files = [
            URL(fileURLWithPath: "/tmp/alpha.jpg"),
            URL(fileURLWithPath: "/tmp/beta.jpg")
        ]
        let (mediaFileManager, mediaCacheManager) = makeManagers(files: files, currentIndex: 0)
        var sut = ContentView()

        let indexChanged = expectation(description: "index changed")
        let statusUpdated = expectation(description: "status text updated")
        
        let exp = sut.on(\.didAppear) { view in
            indexChanged.fulfill()
            mediaFileManager.currentIndex = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                do {
                    let updated = try view.find(text: "beta.jpg — 2 / 2")
                    XCTAssertEqual(try updated.string(), "beta.jpg — 2 / 2")
                    statusUpdated.fulfill()
                } catch {
                    XCTFail("Failed to find updated status text: \(error)")
                }
            }
        }

        ViewHosting.host(view: sut.environment(mediaFileManager).environment(mediaCacheManager))
        wait(for: [exp, indexChanged, statusUpdated], timeout: 1)
    }

    func test_contentView_whenEnvironmentManagersAreInjected_viewRendersWithoutCrash() throws {
        let fileA = try makeTemporaryPNGFile(name: "alpha")
        let fileB = try makeTemporaryPNGFile(name: "beta")
        let files = [fileA, fileB]
        let (mediaFileManager, mediaCacheManager) = makeManagers(files: files, currentIndex: 0)
        var sut = ContentView()

        let didAppear = expectation(description: "content view appeared")

        let exp = sut.on(\.didAppear) { view in
            didAppear.fulfill()
            // Verify view hierarchy is intact
            XCTAssertEqual(view.findAll(ViewType.ZStack.self).count, 1)
            XCTAssertEqual(view.findAll(ViewType.VStack.self).count, 1)
        }

        ViewHosting.host(view: sut.environment(mediaFileManager).environment(mediaCacheManager))
        wait(for: [exp, didAppear], timeout: 1)
    }
}
