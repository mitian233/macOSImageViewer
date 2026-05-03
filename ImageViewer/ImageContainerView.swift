import AppKit
import ImageIO
import SwiftUI

struct ImageContainerView: NSViewRepresentable {
    @Bindable var state: ImageViewerState
    let url: URL?

    func makeNSView(context: Context) -> ImageContainerNSView {
        let view = ImageContainerNSView()
        view.state = state
        view.loadImage(from: url)
        return view
    }

    func updateNSView(_ nsView: ImageContainerNSView, context: Context) {
        nsView.state = state
        if nsView.currentURL != url {
            nsView.loadImage(from: url)
        }
    }
}

// MARK: - NSView Implementation

class ImageContainerNSView: NSView {
    var state: ImageViewerState?
    var currentURL: URL?

    private let imageView: NSImageView = {
        let iv = NSImageView()
        iv.imageAlignment = .alignCenter
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.animates = true
        return iv
    }()

    private var isAnimatedGIF = false
    private var lastMagnification: CGFloat = 1.0
    private var lastPanLocation: CGPoint = .zero
    private var accumulatedRotation: CGFloat = 0
    private var boundarySwipeAccumulator: CGFloat = 0

    // MARK: - Setup

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        allowedTouchTypes = [.direct, .indirect]
    }

    // MARK: - Image Loading

    func loadImage(from url: URL?) {
        currentURL = url
        guard let url else {
            imageView.image = nil
            return
        }

        let loadedImage = Self.loadSupportedImage(from: url)
        let isGIF = url.pathExtension.localizedCaseInsensitiveCompare("gif") == .orderedSame
        isAnimatedGIF = isGIF
        imageView.image = loadedImage
        imageView.animates = isGIF
        updateTransform()
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
        else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private nonisolated static func configureGIFLooping(for image: NSImage) {
        for case let bitmapRep as NSBitmapImageRep in image.representations {
            bitmapRep.setProperty(.loopCount, withValue: 0)
        }
    }

    // MARK: - Transform

    private func updateTransform() {
        guard let state else { return }
        let containerSize = bounds.size
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: centerX + state.offset.width, y: centerY + state.offset.height)
        transform = transform.scaledBy(x: state.scale, y: state.scale)
        transform = transform.rotated(by: state.rotation.radians)
        transform = transform.translatedBy(x: -centerX, y: -centerY)

        imageView.layer?.setAffineTransform(transform)
    }

    // MARK: - Scroll Wheel (Zoom / Pan)

    override func scrollWheel(with event: NSEvent) {
        guard let state else {
            super.scrollWheel(with: event)
            return
        }
        if event.modifierFlags.contains(.command) {
            handleZoomScroll(event: event, state: state)
        } else {
            handlePanScroll(event: event, state: state)
        }
    }

    private func handleZoomScroll(event: NSEvent, state: ImageViewerState) {
        let anchor = convert(event.locationInWindow, from: nil)
        let containerSize = bounds.size
        let zoomDelta: CGFloat = event.hasPreciseScrollingDeltas
            ? -event.scrollingDeltaY * 0.001
            : -event.scrollingDeltaY * 0.01
        state.zoom(by: zoomDelta, anchor: anchor, containerSize: containerSize)
        updateTransform()
    }

    private func handlePanScroll(event: NSEvent, state: ImageViewerState) {
        let containerSize = bounds.size
        let deltaX = event.scrollingDeltaX
        let deltaY = -event.scrollingDeltaY

        if !event.hasPreciseScrollingDeltas && (deltaX == 0 || abs(deltaY) > abs(deltaX)) {
            super.scrollWheel(with: event)
            return
        }

        let rawDelta = CGSize(width: -deltaX, height: -deltaY)
        let rotatedDelta = ImageViewerState.rotateSize(rawDelta, by: -state.rotation)
        let feedback = state.panWithFeedback(by: rotatedDelta, containerSize: containerSize)

        if feedback.reachedHorizontalBoundary {
            boundarySwipeAccumulator += feedback.remaining.width
        } else {
            boundarySwipeAccumulator = 0
        }

        let threshold: CGFloat = 50
        if abs(boundarySwipeAccumulator) >= threshold {
            if boundarySwipeAccumulator > 0 {
                NotificationCenter.default.post(name: .navigateToNext, object: nil)
            } else {
                NotificationCenter.default.post(name: .navigateToPrevious, object: nil)
            }
            boundarySwipeAccumulator = 0
        }

        updateTransform()
    }

    // MARK: - Magnification (Pinch to Zoom)

    override func magnify(with event: NSEvent) {
        guard let state else {
            super.magnify(with: event)
            return
        }
        let containerSize = bounds.size
        let anchor = convert(event.locationInWindow, from: nil)

        if event.phase == .began {
            lastMagnification = 1.0
        }
        let delta = event.magnification
        lastMagnification += delta
        state.zoom(by: delta, anchor: anchor, containerSize: containerSize)
        updateTransform()

        if event.phase == .ended {
            lastMagnification = 1.0
        }
    }

    // MARK: - Mouse Drag (with reverse rotation)

    override func mouseDown(with event: NSEvent) {
        lastPanLocation = convert(event.locationInWindow, from: nil)
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let state, state.scale > 1.0 else {
            super.mouseDragged(with: event)
            return
        }
        let containerSize = bounds.size
        let currentLocation = convert(event.locationInWindow, from: nil)
        let rawDelta = CGSize(
            width: currentLocation.x - lastPanLocation.x,
            height: currentLocation.y - lastPanLocation.y
        )
        let rotatedDelta = ImageViewerState.rotateSize(rawDelta, by: -state.rotation)
        state.pan(by: rotatedDelta, containerSize: containerSize)
        updateTransform()
        lastPanLocation = currentLocation
    }

    override func mouseUp(with event: NSEvent) {
        lastPanLocation = .zero
        super.mouseUp(with: event)
    }

    // MARK: - Rotation (90° increments)

    override func rotate(with event: NSEvent) {
        guard let state else {
            super.rotate(with: event)
            return
        }
        accumulatedRotation += CGFloat(event.rotation)

        if abs(accumulatedRotation) >= 45 {
            if accumulatedRotation > 0 {
                state.rotateRight()
            } else {
                state.rotateLeft()
            }
            accumulatedRotation = 0
        }
        updateTransform()
    }

    // MARK: - Smart Zoom (Double tap)

    override func smartMagnify(with event: NSEvent) {
        guard let state else {
            super.smartMagnify(with: event)
            return
        }
        let anchor = convert(event.locationInWindow, from: nil)
        let containerSize = bounds.size
        let targetScale: CGFloat = state.scale == 1.0 ? 2.0 : 1.0
        state.zoom(to: targetScale, anchor: anchor, containerSize: containerSize)
        updateTransform()
    }

    // MARK: - Event Acceptance

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { self }
}
