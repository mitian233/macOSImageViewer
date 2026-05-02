//
//  ImageViewerApp.swift
//  ImageViewer
//
//  Created by 原田蜜柑 on 2026/05/02.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct ImageViewerApp: App {
    @State private var mediaFileManager = MediaFileManager()
    @State private var mediaCacheManager = MediaCacheManager()
    @State private var viewerState = ImageViewerState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(mediaFileManager)
                .environment(mediaCacheManager)
                .onOpenURL(perform: handleOpenURL)
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { presentOpenPanel() }
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

    @MainActor
    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [
            .image, .movie,
            UTType(filenameExtension: "heic") ?? .image,
            UTType(filenameExtension: "gif") ?? .image
        ]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        handleOpenSelection(url)
    }

    @MainActor
    private func handleOpenSelection(_ url: URL) {
        if url.hasDirectoryPath {
            mediaFileManager.loadMedia(in: url)
        } else {
            let files = mediaFileManager.findAdjacentFiles(for: url)
            mediaCacheManager.preloadAdjacent(currentIndex: mediaFileManager.currentIndex, files: files)
        }
    }

    @MainActor
    private func handleOpenURL(_ url: URL) {
        handleOpenSelection(url)
    }
}
