import AVFoundation
import AVKit
import SwiftUI

struct VideoDisplayView: View {
    let url: URL
    @Binding var isPlaying: Bool
    @Binding var didFinish: Bool

    var body: some View {
        VideoPlayerView(url: url, isPlaying: $isPlaying, didFinish: $didFinish)
            .accessibilityIdentifier("VideoPlayerView")
            .onTapGesture {
                isPlaying.toggle()
            }
            .onAppear {
                didFinish = false
                isPlaying = true
            }
            .onDisappear {
                isPlaying = false
                didFinish = false
            }
            .overlay(alignment: .bottom) {
                if !isPlaying {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 60))
                        .opacity(0.8)
                        .accessibilityIdentifier("VideoPlayOverlay")
                }
            }
    }
}

struct VideoPlayerView: NSViewRepresentable {
    static let didFinishNotification = Notification.Name("VideoPlayerViewDidFinishPlayback")

    let url: URL
    @Binding var isPlaying: Bool
    @Binding var didFinish: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, isPlaying: $isPlaying, didFinish: $didFinish)
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = context.coordinator.player
        playerView.controlsStyle = .default
        playerView.showsFrameSteppingButtons = false
        playerView.allowsPictureInPicturePlayback = true

        context.coordinator.play()

        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        context.coordinator.updateBindings(isPlaying: $isPlaying, didFinish: $didFinish)

        if context.coordinator.currentURL != url {
            context.coordinator.replaceCurrentItem(with: url)
            nsView.player = context.coordinator.player
            didFinish = false
        }

        if isPlaying {
            context.coordinator.play()
        } else {
            context.coordinator.pause()
        }
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: Coordinator) {
        coordinator.reset()
        nsView.player = nil
    }

    final class Coordinator: NSObject {
        let player: AVPlayer
        private(set) var currentURL: URL

        private var isPlaying: Binding<Bool>
        private var didFinish: Binding<Bool>
        private var didPlayToEndObserver: NSObjectProtocol?

        init(url: URL, isPlaying: Binding<Bool>, didFinish: Binding<Bool>) {
            self.player = AVPlayer(url: url)
            self.currentURL = url
            self.isPlaying = isPlaying
            self.didFinish = didFinish
            super.init()
            observeDidPlayToEnd(for: player.currentItem)
        }

        deinit {
            removeDidPlayToEndObserver()
        }

        func updateBindings(isPlaying: Binding<Bool>, didFinish: Binding<Bool>) {
            self.isPlaying = isPlaying
            self.didFinish = didFinish
        }

        func replaceCurrentItem(with url: URL) {
            currentURL = url
            removeDidPlayToEndObserver()

            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            observeDidPlayToEnd(for: item)
        }

        func play() {
            didFinish.wrappedValue = false
            player.play()
            isPlaying.wrappedValue = true
        }

        func pause() {
            player.pause()
            isPlaying.wrappedValue = false
        }

        func reset() {
            player.pause()
            player.seek(to: .zero)
            isPlaying.wrappedValue = false
        }

        private func observeDidPlayToEnd(for item: AVPlayerItem?) {
            guard let item else { return }

            didPlayToEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] notification in
                self?.handleDidPlayToEnd(notification)
            }
        }

        private func removeDidPlayToEndObserver() {
            guard let didPlayToEndObserver else { return }

            NotificationCenter.default.removeObserver(didPlayToEndObserver)
            self.didPlayToEndObserver = nil
        }

        private func handleDidPlayToEnd(_ notification: Notification) {
            player.pause()
            isPlaying.wrappedValue = false
            didFinish.wrappedValue = true

            NotificationCenter.default.post(
                name: VideoPlayerView.didFinishNotification,
                object: player,
                userInfo: ["sourceNotification": notification]
            )
        }
    }
}
