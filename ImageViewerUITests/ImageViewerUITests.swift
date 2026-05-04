//
//  ImageViewerUITests.swift
//  ImageViewerUITests
//
//  Created by 原田蜜柑 on 2026/05/02.
//

import XCTest

final class ImageViewerUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.exists, "App window should exist after launch")
    }
}