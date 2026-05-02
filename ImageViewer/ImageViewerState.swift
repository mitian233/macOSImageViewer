import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ImageViewerState {
    static let minimumScale: CGFloat = 0.1
    static let maximumScale: CGFloat = 10.0

    var scale: CGFloat = 1.0
    var offset: CGSize = .zero
    var rotation: Angle = .zero
    var currentImageURL: URL?

    func setScale(_ value: CGFloat) {
        scale = clamp(value)
        if scale == 1.0 {
            offset = .zero
        }
    }

    func resetView() {
        scale = 1.0
        offset = .zero
        rotation = .zero
    }

    func zoomToFit() {
        scale = 1.0
        offset = .zero
    }

    func zoomToActualSize() {
        scale = 1.0
        offset = .zero
    }

    func rotateLeft() {
        rotation -= .degrees(90)
    }

    func rotateRight() {
        rotation += .degrees(90)
    }
    
    // MARK: - Zoom & Pan
    
    func zoom(by delta: CGFloat, anchor: CGPoint, containerSize: CGSize) {
        let newScale = clamp(scale * (1 + delta))
        guard newScale != scale else { return }
        let ratio = newScale / scale
        offset = CGSize(
            width: anchor.x - ratio * (anchor.x - offset.width),
            height: anchor.y - ratio * (anchor.y - offset.height)
        )
        scale = newScale
    }
    
    func zoom(to targetScale: CGFloat, anchor: CGPoint, containerSize: CGSize) {
        let newScale = clamp(targetScale)
        guard newScale != scale else { return }
        if newScale == 1.0 {
            offset = .zero
            scale = 1.0
            return
        }
        let ratio = newScale / scale
        offset = CGSize(
            width: anchor.x - ratio * (anchor.x - offset.width),
            height: anchor.y - ratio * (anchor.y - offset.height)
        )
        scale = newScale
    }
    
    func pan(by delta: CGSize, containerSize: CGSize) {
        guard scale > 1.0 else { return }
        let newWidth = offset.width + delta.width
        let newHeight = offset.height + delta.height
        let maxX = containerSize.width * (scale - 1) / 2
        let maxY = containerSize.height * (scale - 1) / 2
        offset = CGSize(
            width: min(max(newWidth, -maxX), maxX),
            height: min(max(newHeight, -maxY), maxY)
        )
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(Self.maximumScale, max(Self.minimumScale, value))
    }
}
