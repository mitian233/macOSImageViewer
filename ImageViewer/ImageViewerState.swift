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

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(Self.maximumScale, max(Self.minimumScale, value))
    }
}
