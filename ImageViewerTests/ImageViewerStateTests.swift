import Foundation
import SwiftUI
import Testing
@testable import ImageViewer

@MainActor
struct ImageViewerStateTests {
    private func assertCGSizeEqual(
        _ actual: CGSize,
        _ expected: CGSize,
        accuracy: CGFloat = 0.0001,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(actual.width - expected.width) <= accuracy, sourceLocation: sourceLocation)
        #expect(abs(actual.height - expected.height) <= accuracy, sourceLocation: sourceLocation)
    }

    @Test func test_setScale_normalScale_preservesOffset() {
        let state = ImageViewerState()
        state.offset = CGSize(width: 12, height: -8)

        state.setScale(2.5)

        #expect(state.scale == 2.5)
        assertCGSizeEqual(state.offset, CGSize(width: 12, height: -8))
    }

    @Test func test_setScale_belowMinimumScale_clampsToMinimum() {
        let state = ImageViewerState()

        state.setScale(0.01)

        #expect(state.scale == ImageViewerState.minimumScale)
    }

    @Test func test_setScale_aboveMaximumScale_clampsToMaximum() {
        let state = ImageViewerState()

        state.setScale(99)

        #expect(state.scale == ImageViewerState.maximumScale)
    }

    @Test func test_setScale_toOne_resetsOffset() {
        let state = ImageViewerState()
        state.offset = CGSize(width: 42, height: -17)

        state.setScale(1)

        #expect(state.scale == 1)
        assertCGSizeEqual(state.offset, .zero)
    }

    @Test func test_resetView_resetsScaleOffsetAndRotation() {
        let state = ImageViewerState()
        state.scale = 3
        state.offset = CGSize(width: 11, height: -9)
        state.rotation = .degrees(180)

        state.resetView()

        #expect(state.scale == 1)
        assertCGSizeEqual(state.offset, .zero)
        #expect(state.rotation == .zero)
    }

    @Test func test_zoomToFit_resetsScaleAndOffset() {
        let state = ImageViewerState()
        state.scale = 4
        state.offset = CGSize(width: 7, height: 9)

        state.zoomToFit()

        #expect(state.scale == 1)
        assertCGSizeEqual(state.offset, .zero)
    }

    @Test func test_zoomToActualSize_resetsScaleAndOffset() {
        let state = ImageViewerState()
        state.scale = 4
        state.offset = CGSize(width: -7, height: 9)

        state.zoomToActualSize()

        #expect(state.scale == 1)
        assertCGSizeEqual(state.offset, .zero)
    }

    @Test func test_rotateLeft_decrementsRotationByNinetyDegrees() {
        let state = ImageViewerState()

        state.rotateLeft()

        #expect(state.rotation == .degrees(-90))
    }

    @Test func test_rotateRight_incrementsRotationByNinetyDegrees() {
        let state = ImageViewerState()

        state.rotateRight()

        #expect(state.rotation == .degrees(90))
    }

    @Test func test_rotateSize_quarterTurn_rotatesVectorCounterClockwise() {
        let rotated = ImageViewerState.rotateSize(CGSize(width: 10, height: 0), by: .degrees(90))

        assertCGSizeEqual(rotated, CGSize(width: 0, height: 10))
    }

    @Test func test_rotateSize_halfTurn_flipsVector() {
        let rotated = ImageViewerState.rotateSize(CGSize(width: 3, height: -4), by: .degrees(180))

        assertCGSizeEqual(rotated, CGSize(width: -3, height: 4))
    }

    @Test func test_panWithFeedback_whenScaleIsOne_returnsNoAppliedMovement() {
        let state = ImageViewerState()
        let delta = CGSize(width: 40, height: -25)

        let feedback = state.panWithFeedback(by: delta, containerSize: CGSize(width: 200, height: 100))

        assertCGSizeEqual(feedback.applied, .zero)
        assertCGSizeEqual(feedback.remaining, delta)
        #expect(feedback.reachedHorizontalBoundary == false)
        #expect(feedback.reachedVerticalBoundary == false)
        assertCGSizeEqual(state.offset, .zero)
    }

    @Test func test_panWithFeedback_withinBounds_appliesFullDelta() {
        let state = ImageViewerState()
        state.scale = 2
        let delta = CGSize(width: 30, height: -20)

        let feedback = state.panWithFeedback(by: delta, containerSize: CGSize(width: 200, height: 100))

        assertCGSizeEqual(feedback.applied, delta)
        assertCGSizeEqual(feedback.remaining, .zero)
        #expect(feedback.reachedHorizontalBoundary == false)
        #expect(feedback.reachedVerticalBoundary == false)
        assertCGSizeEqual(state.offset, delta)
    }

    @Test func test_panWithFeedback_clampsHorizontalAndReportsRemainder() {
        let state = ImageViewerState()
        state.scale = 2
        state.offset = CGSize(width: 70, height: 0)

        let feedback = state.panWithFeedback(by: CGSize(width: 50, height: 0), containerSize: CGSize(width: 200, height: 100))

        assertCGSizeEqual(state.offset, CGSize(width: 100, height: 0))
        assertCGSizeEqual(feedback.applied, CGSize(width: 30, height: 0))
        assertCGSizeEqual(feedback.remaining, CGSize(width: 20, height: 0))
        #expect(feedback.reachedHorizontalBoundary)
        #expect(feedback.reachedVerticalBoundary == false)
    }

    @Test func test_panWithFeedback_clampsVerticalAndReportsRemainder() {
        let state = ImageViewerState()
        state.scale = 2
        state.offset = CGSize(width: 0, height: -30)

        let feedback = state.panWithFeedback(by: CGSize(width: 0, height: -40), containerSize: CGSize(width: 200, height: 100))

        assertCGSizeEqual(state.offset, CGSize(width: 0, height: -50))
        assertCGSizeEqual(feedback.applied, CGSize(width: 0, height: -20))
        assertCGSizeEqual(feedback.remaining, CGSize(width: 0, height: -20))
        #expect(feedback.reachedHorizontalBoundary == false)
        #expect(feedback.reachedVerticalBoundary)
    }

    @Test func test_zoomBy_appliesAnchorBasedZoom() {
        let state = ImageViewerState()
        let anchor = CGPoint(x: 100, y: 80)

        state.zoom(by: 0.5, anchor: anchor, containerSize: CGSize(width: 300, height: 200))

        #expect(state.scale == 1.5)
        assertCGSizeEqual(state.offset, CGSize(width: -50, height: -40))
    }

    @Test func test_zoomBy_clampsToMaximumScale() {
        let state = ImageViewerState()
        let anchor = CGPoint(x: 100, y: 80)

        state.zoom(by: 20, anchor: anchor, containerSize: CGSize(width: 300, height: 200))

        #expect(state.scale == ImageViewerState.maximumScale)
        assertCGSizeEqual(state.offset, CGSize(width: -900, height: -720))
    }

    @Test func test_zoomTo_appliesTargetScaleAroundAnchor() {
        let state = ImageViewerState()
        let anchor = CGPoint(x: 120, y: 60)

        state.zoom(to: 2, anchor: anchor, containerSize: CGSize(width: 300, height: 200))

        #expect(state.scale == 2)
        assertCGSizeEqual(state.offset, CGSize(width: -120, height: -60))
    }

    @Test func test_zoomTo_targetScaleOne_resetsOffset() {
        let state = ImageViewerState()
        state.scale = 3
        state.offset = CGSize(width: 22, height: -11)

        state.zoom(to: 1, anchor: CGPoint(x: 50, y: 50), containerSize: CGSize(width: 300, height: 200))

        #expect(state.scale == 1)
        assertCGSizeEqual(state.offset, .zero)
    }

    @Test func test_pan_clampsToBoundary() {
        let state = ImageViewerState()
        state.scale = 2

        state.pan(by: CGSize(width: 500, height: -500), containerSize: CGSize(width: 200, height: 100))

        assertCGSizeEqual(state.offset, CGSize(width: 100, height: -50))
    }

    @Test func test_pan_whenScaleIsOne_doesNotMove() {
        let state = ImageViewerState()
        state.offset = CGSize(width: 10, height: 10)

        state.pan(by: CGSize(width: 100, height: -100), containerSize: CGSize(width: 200, height: 100))

        assertCGSizeEqual(state.offset, CGSize(width: 10, height: 10))
    }
}
