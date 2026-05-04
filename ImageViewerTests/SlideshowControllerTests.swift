import XCTest
@testable import ImageViewer

@MainActor
final class SlideshowControllerTests: XCTestCase {
    func test_start_whenStopped_setsIsRunningTrue() {
        let controller = SlideshowController()

        controller.start()

        XCTAssertTrue(controller.isRunning)
    }

    func test_stop_whenRunning_setsIsRunningFalse() {
        let controller = SlideshowController()
        controller.start()

        controller.stop()

        XCTAssertFalse(controller.isRunning)
    }

    func test_toggle_whenStopped_startsRunning() {
        let controller = SlideshowController()

        controller.toggle()

        XCTAssertTrue(controller.isRunning)
    }

    func test_toggle_whenRunning_stopsRunning() {
        let controller = SlideshowController()
        controller.start()

        controller.toggle()

        XCTAssertFalse(controller.isRunning)
    }

    func test_interval_whenSetBelowMinimum_clampsToMinimumInterval() {
        let controller = SlideshowController()

        controller.interval = 0.5

        XCTAssertEqual(controller.interval, 1.0)
    }

    func test_start_whenIntervalBelowMinimum_clampsIntervalToMinimum() {
        let controller = SlideshowController()
        controller.interval = 0.25

        controller.start()

        XCTAssertEqual(controller.interval, 1.0)
        XCTAssertTrue(controller.isRunning)
    }

    func test_start_whenRunning_keepsRunningAfterReschedule() {
        let controller = SlideshowController()
        controller.start()

        controller.start()

        XCTAssertTrue(controller.isRunning)
    }

    func test_interval_whenChangedWhileRunning_remainsRunning() {
        let controller = SlideshowController()
        controller.start()

        controller.interval = 2.0

        XCTAssertTrue(controller.isRunning)
        XCTAssertEqual(controller.interval, 2.0)
    }

    func test_onAdvance_whenTimerTicks_invokesCallback() async throws {
        let controller = SlideshowController()
        controller.interval = 1.0

        let expectation = expectation(description: "onAdvance called")
        var advanceCount = 0
        controller.onAdvance = {
            advanceCount += 1
            expectation.fulfill()
        }

        controller.start()
        await waitForExpectations(timeout: 2.0)

        XCTAssertEqual(advanceCount, 1)
        XCTAssertTrue(controller.isRunning)
    }

    func test_onCanContinue_whenReturnsFalse_stopsAfterAdvance() async throws {
        let controller = SlideshowController()
        controller.interval = 1.0

        let expectation = expectation(description: "onAdvance called before stop")
        var advanceCount = 0
        controller.onAdvance = {
            advanceCount += 1
            expectation.fulfill()
        }
        controller.onCanContinue = { false }

        controller.start()
        await waitForExpectations(timeout: 2.0)

        XCTAssertEqual(advanceCount, 1)
        XCTAssertFalse(controller.isRunning)
    }
}
