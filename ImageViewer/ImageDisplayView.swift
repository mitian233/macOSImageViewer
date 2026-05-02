import AppKit
import SwiftUI

struct ImageDisplayView: View {
    @Bindable var state: ImageViewerState
    let url: URL?

    @State private var image: NSImage?
    @State private var imageSize: CGSize = .zero
    @State private var magnificationStartScale: CGFloat?
    @State private var dragStartOffset: CGSize?
    @State private var imageLoadTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(state.scale)
                        .offset(state.offset)
                        .rotationEffect(state.rotation)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .highPriorityGesture(magnificationGesture(in: proxy.size))
                        .gesture(dragGesture(in: proxy.size))
                        .gesture(doubleTapGesture(in: proxy.size))
                        .accessibilityLabel(imageAccessibilityLabel)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(url == nil ? 0 : 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onChange(of: url, initial: true) {
                loadImage(from: url)
            }
            .onChange(of: proxy.size) {
                state.offset = clampedOffset(state.offset, in: proxy.size)
            }
        }
    }

    private var imageAccessibilityLabel: Text {
        if let url {
            Text(url.lastPathComponent)
        } else {
            Text("Image")
        }
    }

    private func magnificationGesture(in containerSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let startScale = magnificationStartScale ?? state.scale
                magnificationStartScale = startScale

                state.scale = ImageViewerState.clampScale(startScale * value)
                state.offset = clampedOffset(state.offset, in: containerSize)
            }
            .onEnded { value in
                let startScale = magnificationStartScale ?? state.scale
                magnificationStartScale = nil

                state.scale = ImageViewerState.clampScale(startScale * value)
                state.offset = clampedOffset(state.offset, in: containerSize)
            }
    }

    private func dragGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard state.scale > 1.0 else {
                    dragStartOffset = nil
                    state.offset = .zero
                    return
                }

                let startOffset = dragStartOffset ?? state.offset
                dragStartOffset = startOffset

                let proposedOffset = CGSize(
                    width: startOffset.width + value.translation.width,
                    height: startOffset.height + value.translation.height
                )
                state.offset = clampedOffset(proposedOffset, in: containerSize)
            }
            .onEnded { value in
                guard let startOffset = dragStartOffset, state.scale > 1.0 else {
                    dragStartOffset = nil
                    state.offset = .zero
                    return
                }

                let proposedOffset = CGSize(
                    width: startOffset.width + value.translation.width,
                    height: startOffset.height + value.translation.height
                )
                dragStartOffset = nil
                state.offset = clampedOffset(proposedOffset, in: containerSize)
            }
    }

    private func doubleTapGesture(in containerSize: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                state.scale = state.scale == 1.0 ? 2.0 : 1.0
                state.offset = clampedOffset(state.offset, in: containerSize)
            }
    }

    private func loadImage(from url: URL?) {
        imageLoadTask?.cancel()
        state.currentImageURL = url
        image = nil
        imageSize = .zero
        state.offset = .zero

        guard let url else { return }

        imageLoadTask = Task {
            let loadedImage = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value

            guard !Task.isCancelled, state.currentImageURL == url else { return }

            image = loadedImage
            imageSize = loadedImage?.size ?? .zero
        }
    }

    private func clampedOffset(_ offset: CGSize, in containerSize: CGSize) -> CGSize {
        guard state.scale > 1.0 else { return .zero }

        let fittedSize = fittedImageSize(in: containerSize)
        let horizontalLimit = max(0, (fittedSize.width * state.scale - containerSize.width) / 2)
        let verticalLimit = max(0, (fittedSize.height * state.scale - containerSize.height) / 2)

        return CGSize(
            width: min(horizontalLimit, max(-horizontalLimit, offset.width)),
            height: min(verticalLimit, max(-verticalLimit, offset.height))
        )
    }

    private func fittedImageSize(in containerSize: CGSize) -> CGSize {
        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0
        else {
            return .zero
        }

        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        if imageAspectRatio > containerAspectRatio {
            let width = containerSize.width
            return CGSize(width: width, height: width / imageAspectRatio)
        } else {
            let height = containerSize.height
            return CGSize(width: height * imageAspectRatio, height: height)
        }
    }
}

#Preview {
    @Previewable @State var state = ImageViewerState()

    ImageDisplayView(state: state, url: nil)
        .frame(width: 640, height: 480)
}
