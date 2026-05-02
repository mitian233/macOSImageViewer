//
//  ImageViewerApp.swift
//  ImageViewer
//
//  Created by 原田蜜柑 on 2026/05/02.
//

import SwiftUI
import AppKit

@main
struct ImageViewerApp: App {
    @State private var mediaFileManager = MediaFileManager()
    @State private var mediaCacheManager = MediaCacheManager()

    private let openAction: () -> Void = {}
    private let rotateLeftAction: () -> Void = {}
    private let rotateRightAction: () -> Void = {}
    private let slideshowStartAction: () -> Void = {}
    private let zoomToFitAction: () -> Void = {}
    private let actualSizeAction: () -> Void = {}

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(perform: handleOpenURL)
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…", action: openAction)
                    .keyboardShortcut("o")
            }

            CommandGroup(after: .toolbar) {
                Button("Zoom to Fit", action: zoomToFitAction)
                    .keyboardShortcut("0")

                Button("Actual Size", action: actualSizeAction)
                    .keyboardShortcut("1")
            }

            CommandMenu("Image") {
                Button("Rotate Left", action: rotateLeftAction)
                    .keyboardShortcut("l")

                Button("Rotate Right", action: rotateRightAction)
                    .keyboardShortcut("r")
            }

            CommandMenu("Slideshow") {
                Button("Start", action: slideshowStartAction)
                    .keyboardShortcut("S", modifiers: [.command, .shift])
            }
        }
    }

    private func handleOpenURL(_ url: URL) {
        let files = mediaFileManager.findAdjacentFiles(for: url)
        mediaCacheManager.preloadAdjacent(currentIndex: mediaFileManager.currentIndex, files: files)
    }
}
