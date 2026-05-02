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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(perform: handleOpenURL)
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { }
                    .keyboardShortcut("o")
            }

            CommandMenu("Image") {
                Button("Rotate Left") { }
                    .keyboardShortcut("l")

                Button("Rotate Right") { }
                    .keyboardShortcut("r")
            }

            CommandMenu("Slideshow") {
                Button("Start") { }
                    .keyboardShortcut("S", modifiers: [.command, .shift])
            }
        }
    }

    private func handleOpenURL(_ url: URL) {
        let files = mediaFileManager.findAdjacentFiles(for: url)
        mediaCacheManager.preloadAdjacent(currentIndex: mediaFileManager.currentIndex, files: files)
    }
}
