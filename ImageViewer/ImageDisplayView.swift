// NOTE: This view is currently unused. ImageContainerView provides superior trackpad gesture support.

import AppKit
import ImageIO
import SwiftUI

struct ImageDisplayView: View {
    @Bindable var state: ImageViewerState
    let url: URL?

    @State private var image: NSImage?
    @State private var imageSize: CGSize = .zero
    @State private var isAnimatedGIF = false
    @State private var magnificationStartScale: CGFloat?
    @State private var dragStartOffset: CGSize?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear

                if let image {
                    displayView(for: image)
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
            .onChange(of: url) {
                resetForNewImage(url)
            }
            .task(id: url) {
                await loadImageTask(url: url)
            }
            .onChange(of: proxy.size) {
                state.offset = clampedOffset(state.offset, in: proxy.size)
            }
        }
    }

    private func resetForNewImage(_ url: URL?) {
        state.currentImageURL = url
        image = nil
        imageSize = .zero
        isAnimatedGIF = false
        state.offset = .zero
        state.rotation = .zero
    }

    private func loadImageTask(url: URL?) async {
        guard let url else { return }

        let loadedImage = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            Self.loadSupportedImage(from: url)
        }.value

        guard !Task.isCancelled else { return }

        image = loadedImage
        imageSize = loadedImage?.size ?? .zero
        isAnimatedGIF = url.pathExtension.localizedCaseInsensitiveCompare("gif") == .orderedSame
    }

    @ViewBuilder
    private func displayView(for image: NSImage) -> some View {
        if isAnimatedGIF {
            AnimatedImageView(image: image)
        } else {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
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

                state.setScale(startScale * value)
                state.offset = clampedOffset(state.offset, in: containerSize)
            }
            .onEnded { value in
                let startScale = magnificationStartScale ?? state.scale
                magnificationStartScale = nil

                state.setScale(startScale * value)
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
                state.setScale(state.scale == 1.0 ? 2.0 : 1.0)
                state.offset = clampedOffset(state.offset, in: containerSize)
            }
    }

    private nonisolated static func loadSupportedImage(from url: URL) -> NSImage? {
        if let image = NSImage(contentsOf: url) {
            if url.pathExtension.localizedCaseInsensitiveCompare("gif") == .orderedSame {
                configureGIFLooping(for: image)
            }
            return image
        }

        guard url.pathExtension.localizedCaseInsensitiveCompare("heic") == .orderedSame else {
            return nil
        }

        return loadHEICWithImageSource(from: url)
    }

    private nonisolated static func loadHEICWithImageSource(from url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private nonisolated static func configureGIFLooping(for image: NSImage) {
        for case let bitmapRep as NSBitmapImageRep in image.representations {
            bitmapRep.setProperty(.loopCount, withValue: 0)
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

private struct AnimatedImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.canDrawSubviewsIntoLayer = true
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        imageView.image = image
        imageView.animates = true
    }
}

#Preview {
    @Previewable @State var state = ImageViewerState()

    ImageDisplayView(state: state, url: nil)
        .frame(width: 640, height: 480)
}
