//
//  SlideshowController.swift
//  ImageViewer
//
//  Created by OpenCode on 2026/05/02.
//

import Foundation
import Combine
import Observation

@Observable
final class SlideshowController {
    var isRunning: Bool = false {
        didSet {
            if isRunning {
                scheduleTimer()
            } else {
                cancelTimer()
            }
        }
    }

    var interval: TimeInterval = 3.0 {
        didSet {
            if interval < minimumInterval {
                interval = minimumInterval
                return
            }

            if isRunning {
                scheduleTimer()
            }
        }
    }

    var onAdvance: (() -> Void)?
    var onCanContinue: (() -> Bool)?

    private let minimumInterval: TimeInterval = 1.0
    private var timerCancellable: AnyCancellable?

    func start() {
        if interval < minimumInterval {
            interval = minimumInterval
        }

        guard !isRunning else {
            scheduleTimer()
            return
        }

        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    private func scheduleTimer() {
        cancelTimer()

        guard isRunning else {
            return
        }

        timerCancellable = Timer.publish(every: max(interval, minimumInterval), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.handleTick()
            }
    }

    private func cancelTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func handleTick() {
        guard isRunning else {
            return
        }

        onAdvance?()

        if onCanContinue?() == false {
            stop()
        }
    }
}
