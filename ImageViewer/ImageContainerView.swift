import AppKit
import SwiftUI

/// 容器视图，统一处理所有输入事件（触控板手势、鼠标滚轮、点击等）
struct ImageContainerView: NSViewRepresentable {
    @Bindable var state: ImageViewerState
    let image: NSImage?
    let isAnimatedGIF: Bool
    
    func makeNSView(context: Context) -> ImageContainerNSView {
        let view = ImageContainerNSView()
        view.state = state
        view.setupImageView(with: image, isAnimatedGIF: isAnimatedGIF)
        return view
    }
    
    func updateNSView(_ nsView: ImageContainerNSView, context: Context) {
        nsView.state = state
        nsView.updateImage(image, isAnimatedGIF: isAnimatedGIF)
    }
}

// MARK: - NSView Implementation

class ImageContainerNSView: NSView {
    var state: ImageViewerState?
    
    private let imageView: NSImageView = {
        let iv = NSImageView()
        iv.imageAlignment = .alignCenter
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.animates = true
        return iv
    }()
    
    private var isAnimatedGIF: Bool = false
    private var lastMagnification: CGFloat = 1.0
    private var lastPanLocation: CGPoint = .zero
    
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
        
        // 启用触控板手势
        allowedTouchTypes = [.direct, .indirect]
    }
    
    func setupImageView(with image: NSImage?, isAnimatedGIF: Bool) {
        self.isAnimatedGIF = isAnimatedGIF
        imageView.image = image
        imageView.animates = isAnimatedGIF
        updateTransform()
    }
    
    func updateImage(_ image: NSImage?, isAnimatedGIF: Bool) {
        self.isAnimatedGIF = isAnimatedGIF
        imageView.image = image
        imageView.animates = isAnimatedGIF
        updateTransform()
    }
    
    // MARK: - Transform
    
    private func updateTransform() {
        guard let state = state else { return }
        
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: state.offset.width, y: state.offset.height)
        transform = transform.scaledBy(x: state.scale, y: state.scale)
        transform = transform.rotated(by: state.rotation.radians)
        
        imageView.layer?.setAffineTransform(transform)
    }
    
    // MARK: - Event Handling
    
    override func scrollWheel(with event: NSEvent) {
        guard let state = state else {
            super.scrollWheel(with: event)
            return
        }
        
        let isCommandHeld = event.modifierFlags.contains(.command)
        
        if isCommandHeld {
            // Command + 滚轮 = 缩放
            handleZoomScroll(event: event, state: state)
        } else {
            // 普通滚动 = 平移
            handlePanScroll(event: event, state: state)
        }
    }
    
    private func handleZoomScroll(event: NSEvent, state: ImageViewerState) {
        // 获取鼠标位置作为锚点
        let anchor = convert(event.locationInWindow, from: nil)
        let containerSize = bounds.size
        
        // 计算缩放增量
        let zoomDelta: CGFloat
        if event.hasPreciseScrollingDeltas {
            // 触控板：使用精确增量
            zoomDelta = -event.scrollingDeltaY * 0.001
        } else {
            // 鼠标滚轮：使用传统增量
            zoomDelta = -event.scrollingDeltaY * 0.01
        }
        
        state.zoom(by: zoomDelta, anchor: anchor, containerSize: containerSize)
        updateTransform()
    }
    
    private func handlePanScroll(event: NSEvent, state: ImageViewerState) {
        let containerSize = bounds.size
        
        // 触控板双指滑动：平滑平移
        let deltaX = event.scrollingDeltaX
        let deltaY = -event.scrollingDeltaY
        
        // 如果是触控板且没有精确增量，说明是鼠标滚轮，不处理平移
        if !event.hasPreciseScrollingDeltas && (deltaX == 0 || abs(deltaY) > abs(deltaX)) {
            super.scrollWheel(with: event)
            return
        }
        
        state.pan(by: CGSize(width: -deltaX, height: -deltaY), containerSize: containerSize)
        updateTransform()
    }
    
    // MARK: - Magnification Gesture (Pinch to Zoom)
    
    override func magnify(with event: NSEvent) {
        guard let state = state else {
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
        
        // 直接使用 event.magnification 作为增量
        state.zoom(by: delta, anchor: anchor, containerSize: containerSize)
        updateTransform()
        
        if event.phase == .ended {
            lastMagnification = 1.0
        }
    }
    
    // MARK: - Pan Gesture (Two-finger Pan on Trackpad)
    // Note: NSView doesn't have a dedicated pan gesture. 
    // Trackpad two-finger pan is handled via scrollWheel with precise deltas.
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        lastPanLocation = convert(event.locationInWindow, from: nil)
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let state = state, state.scale > 1.0 else {
            super.mouseDragged(with: event)
            return
        }
        
        let containerSize = bounds.size
        let currentLocation = convert(event.locationInWindow, from: nil)
        let delta = CGSize(
            width: currentLocation.x - lastPanLocation.x,
            height: currentLocation.y - lastPanLocation.y
        )
        
        state.pan(by: delta, containerSize: containerSize)
        updateTransform()
        
        lastPanLocation = currentLocation
    }
    
    override func mouseUp(with event: NSEvent) {
        lastPanLocation = .zero
        super.mouseUp(with: event)
    }
    
    // MARK: - Double Click
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
    }
    
    // MARK: - Rotation Gesture
    
    override func rotate(with event: NSEvent) {
        guard let state = state else {
            super.rotate(with: event)
            return
        }
        
        state.rotation += .radians(Double(event.rotation))
        updateTransform()
    }
    
    // MARK: - Smart Zoom (Double tap on trackpad)
    
    override func smartMagnify(with event: NSEvent) {
        guard let state = state else {
            super.smartMagnify(with: event)
            return
        }
        
        // 双击切换 1x / 2x
        let anchor = convert(event.locationInWindow, from: nil)
        let containerSize = bounds.size
        let targetScale: CGFloat = state.scale == 1.0 ? 2.0 : 1.0
        
        state.zoom(to: targetScale, anchor: anchor, containerSize: containerSize)
        updateTransform()
    }
    
    // MARK: - Accepts First Mouse
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    // MARK: - Hit Test
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // 接收所有事件
        return self
    }
}
