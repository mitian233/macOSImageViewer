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
    @State private var viewerState = ImageViewerState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(perform: handleOpenURL)
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {}
                    .keyboardShortcut("o")
            }

            CommandGroup(after: .toolbar) {
                Button("Zoom to Fit") { viewerState.zoomToFit() }
                    .keyboardShortcut("0")

                Button("Actual Size") { viewerState.zoomToActualSize() }
                    .keyboardShortcut("1")
            }

            CommandMenu("Image") {
                Button("Rotate Left") { viewerState.rotateLeft() }
                    .keyboardShortcut("l")

                Button("Rotate Right") { viewerState.rotateRight() }
                    .keyboardShortcut("r")
            }

            CommandMenu("Slideshow") {
                Button("Start") {}
                    .keyboardShortcut("S", modifiers: [.command, .shift])
            }
        }
    }

    private func handleOpenURL(_ url: URL) {
        let files = mediaFileManager.findAdjacentFiles(for: url)
        mediaCacheManager.preloadAdjacent(currentIndex: mediaFileManager.currentIndex, files: files)
    }
}
