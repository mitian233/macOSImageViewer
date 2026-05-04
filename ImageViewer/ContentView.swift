//
//  ContentView.swift
//  ImageViewer
//
//  Created by 原田蜜柑 on 2026/05/02.
//

import SwiftUI
import AppKit

struct ContentView: View {
    internal var didAppear: ((Self) -> Void)?

    @Environment(MediaFileManager.self) private var mediaFileManager
    @Environment(MediaCacheManager.self) private var mediaCacheManager
    
    @State private var state = ImageViewerState()
    @State private var slideshowController = SlideshowController()
    
    @State private var isVideoPlaying = false
    @State private var didVideoFinish = false
    
    @State private var isFullScreen = false
    @State private var showOverlay = true
    @State private var overlayTimer: Timer?
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            
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
                    .transition(.opacity)
                } else {
                    ImageContainerView(state: state, url: currentURL)
                        .id(currentURL)
                        .transition(.opacity)
                }
            }
            
            VStack {
                if isFullScreen && showOverlay {
                    self.topOverlayBar
                        .transition(.opacity)
                }
                
                Spacer()
                
                if !isFullScreen || showOverlay {
                    if !mediaFileManager.files.isEmpty {
                        let currentURL = mediaFileManager.files[mediaFileManager.currentIndex]
                        Text("\(currentURL.lastPathComponent) — \(mediaFileManager.currentIndex + 1) / \(mediaFileManager.files.count)")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding(.bottom, 16)
                            .transition(.opacity)
                    }
                }
            }
        }
        .onContinuousHover { phase in
            if isFullScreen {
                switch phase {
                case .active(_):
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showOverlay = true
                    }
                    self.resetOverlayTimer()
                case .ended:
                    break
                }
            }
        }
        .onTapGesture {
            if isFullScreen {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showOverlay = true
                }
                self.resetOverlayTimer()
            }
        }
        .toolbar(isFullScreen ? .hidden : .visible, for: .windowToolbar)
        .toolbar {
            // 导航组
            ToolbarItemGroup(placement: .automatic) {
                ControlGroup {
                    Button(action: previousMedia) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(mediaFileManager.files.isEmpty || mediaFileManager.currentIndex == 0)
                    
                    Button(action: nextMedia) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(mediaFileManager.files.isEmpty || mediaFileManager.currentIndex == mediaFileManager.files.count - 1)
                }
            }
            
            // 缩放和旋转组
            ToolbarItemGroup(placement: .automatic) {
                ControlGroup {
                    Button(action: { state.setScale(state.scale - 0.25) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    
                    Text("\(Int(state.scale * 100))%")
                        .frame(width: 44)
                        .monospacedDigit()
                    
                    Button(action: { state.setScale(state.scale + 0.25) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    
                    Button(action: { state.rotateLeft() }) {
                        Image(systemName: "rotate.left")
                    }
                    
                    Button(action: { state.rotateRight() }) {
                        Image(systemName: "rotate.right")
                    }
                }
            }
            
            // 播放和全屏组
            ToolbarItemGroup(placement: .automatic) {
                ControlGroup {
                    Button(action: { slideshowController.toggle() }) {
                        Image(systemName: slideshowController.isRunning ? "pause.fill" : "play.fill")
                    }
                    
                    Button(action: self.toggleFullScreen) {
                        Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
            showOverlay = true
            self.resetOverlayTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
            overlayTimer?.invalidate()
            showOverlay = true
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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToPrevious)) { _ in
            previousMedia()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToNext)) { _ in
            nextMedia()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSlideshow)) { _ in
            slideshowController.toggle()
        }
        .onAppear {
            self.didAppear?(self)
        }
    }
    
    private func isVideo(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mov", "mp4", "m4v", "avi", "mkv", "webm"].contains(ext)
    }
    
    private func previousMedia() {
        withAnimation(.easeInOut(duration: 0.25)) {
            mediaFileManager.navigateToPrevious()
        }
    }
    
    private func nextMedia() {
        if mediaFileManager.currentIndex < mediaFileManager.files.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                mediaFileManager.navigateToNext()
            }
        } else if slideshowController.isRunning {
            slideshowController.stop()
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
    
    private var topOverlayBar: some View {
        HStack(spacing: 20) {
            Button(action: previousMedia) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .disabled(mediaFileManager.files.isEmpty || mediaFileManager.currentIndex == 0)
            .buttonStyle(.plain)
            
            Button(action: nextMedia) {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .disabled(mediaFileManager.files.isEmpty || mediaFileManager.currentIndex == mediaFileManager.files.count - 1)
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: { slideshowController.toggle() }) {
                Image(systemName: slideshowController.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            Button(action: toggleFullScreen) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func toggleFullScreen() {
        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
        }
    }
    
    private func resetOverlayTimer() {
        overlayTimer?.invalidate()
        overlayTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showOverlay = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(MediaFileManager())
        .environment(MediaCacheManager())
}
