//
//  ContentView.swift
//  ImageViewer
//
//  Created by 原田蜜柑 on 2026/05/02.
//

import SwiftUI

struct ContentView: View {
    @Environment(MediaFileManager.self) private var mediaFileManager
    @Environment(MediaCacheManager.self) private var mediaCacheManager
    
    @State private var state = ImageViewerState()
    @State private var slideshowController = SlideshowController()
    
    @State private var isVideoPlaying = false
    @State private var didVideoFinish = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if mediaFileManager.files.isEmpty {
                Text("No media found")
                    .foregroundColor(.secondary)
            } else {
                let currentURL = mediaFileManager.files[mediaFileManager.currentIndex]
                
                if isVideo(url: currentURL) {
                    VideoDisplayView(
                        url: currentURL,
                        isPlaying: $isVideoPlaying,
                        didFinish: $didVideoFinish
                    )
                    .id(currentURL)
                } else {
                    ImageDisplayView(state: state, url: currentURL)
                        .id(currentURL)
                }
            }
            
            VStack {
                Spacer()
                if !mediaFileManager.files.isEmpty {
                    let currentURL = mediaFileManager.files[mediaFileManager.currentIndex]
                    Text("\(currentURL.lastPathComponent) — \(mediaFileManager.currentIndex + 1) / \(mediaFileManager.files.count)")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 16)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Button(action: previousMedia) {
                    Image(systemName: "chevron.left")
                }
                .disabled(mediaFileManager.files.isEmpty || mediaFileManager.currentIndex == 0)
                
                Button(action: nextMedia) {
                    Image(systemName: "chevron.right")
                }
                .disabled(mediaFileManager.files.isEmpty || mediaFileManager.currentIndex == mediaFileManager.files.count - 1)
                
                Divider()
                
                Button(action: { state.scale = max(ImageViewerState.minimumScale, state.scale - 0.25) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                
                Text("\(Int(state.scale * 100))%")
                    .frame(width: 50)
                
                Button(action: { state.scale = min(ImageViewerState.maximumScale, state.scale + 0.25) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                
                Divider()
                
                Button(action: { state.rotateLeft() }) {
                    Image(systemName: "rotate.left")
                }
                
                Button(action: { state.rotateRight() }) {
                    Image(systemName: "rotate.right")
                }
                
                Divider()
                
                Button(action: { slideshowController.toggle() }) {
                    Image(systemName: slideshowController.isRunning ? "pause.fill" : "play.fill")
                }
            }
        }
        .onAppear {
            setupSlideshow()
        }
        .onChange(of: mediaFileManager.currentIndex) { _, newIndex in
            handleIndexChange(newIndex)
        }
        .onChange(of: didVideoFinish) { _, finished in
            if finished && slideshowController.isRunning {
                nextMedia()
            }
        }
    }
    
    private func isVideo(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mov", "mp4", "m4v", "avi", "mkv", "webm"].contains(ext)
    }
    
    private func previousMedia() {
        if mediaFileManager.currentIndex > 0 {
            mediaFileManager.currentIndex -= 1
        }
    }
    
    private func nextMedia() {
        if mediaFileManager.currentIndex < mediaFileManager.files.count - 1 {
            mediaFileManager.currentIndex += 1
        } else if slideshowController.isRunning {
            mediaFileManager.currentIndex = 0
        }
    }
    
    private func handleIndexChange(_ newIndex: Int) {
        state.resetView()
        mediaCacheManager.preloadAdjacent(currentIndex: newIndex, files: mediaFileManager.files)
    }
    
    private func setupSlideshow() {
        slideshowController.onAdvance = {
            if !mediaFileManager.files.isEmpty {
                let currentURL = mediaFileManager.files[mediaFileManager.currentIndex]
                if !isVideo(url: currentURL) {
                    nextMedia()
                }
            }
        }
        
        slideshowController.onCanContinue = {
            return true
        }
    }
}

#Preview {
    ContentView()
        .environment(MediaFileManager())
        .environment(MediaCacheManager())
}
