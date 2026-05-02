import Foundation
import Observation
import SwiftUI

@Observable
final class ImageViewerState {
    static let minimumScale: CGFloat = 0.1
    static let maximumScale: CGFloat = 10.0

    var scale: CGFloat = 1.0 {
        didSet {
            scale = Self.clampScale(scale)

            if scale == 1.0 {
                offset = .zero
            }
        }
    }

    var offset: CGSize = .zero
    var rotation: Angle = .zero
    var currentImageURL: URL?

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

    static func clampScale(_ scale: CGFloat) -> CGFloat {
        min(maximumScale, max(minimumScale, scale))
    }
}
