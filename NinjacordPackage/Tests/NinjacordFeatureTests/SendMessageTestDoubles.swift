//
//  SendMessageTestDoubles.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import UIKit

/// 送信に成功したあとの流れで起きたことを、起きた順に記録する
@MainActor
final class SendSucceededRecorder {
    enum Event: Equatable {
        case consumeRewardedUnlock
        case requestTracking
        case requestReview
        case sleep(Duration)
        case showInterstitial(from: UIViewController?)
    }

    private(set) var events: [Event] = []
    /// ATT の許可を尋ねたとき、ダイアログを出した（尋ねた）ものとして返すか
    var trackingDialogWillBeShown = false

    func record(_ event: Event) {
        events.append(event)
    }
}

@MainActor
final class RewardedUnlockSpy: RewardedUnlockConsuming {
    private let recorder: SendSucceededRecorder

    init(recorder: SendSucceededRecorder) {
        self.recorder = recorder
    }

    func consumeIfUnlocked() {
        recorder.record(.consumeRewardedUnlock)
    }
}

@MainActor
final class InterstitialAdSpy: InterstitialAdPresenting {
    private let recorder: SendSucceededRecorder

    init(recorder: SendSucceededRecorder) {
        self.recorder = recorder
    }

    func showIfAllowed(from viewController: UIViewController?) {
        recorder.record(.showInterstitial(from: viewController))
    }
}

/// 送信の Analytics に送った値を記録する（Firebase には送らない）
final class AnalyticsSpy: SendMessageAnalytics {
    struct SendEvent: Equatable {
        let isSuccess: Bool
        let httpStatus: Int?
    }

    private(set) var sendEvents: [SendEvent] = []
    private(set) var firstSendCompletedCount = 0

    func sendMessageSendEvent(isSuccess: Bool, httpStatus: Int?) {
        sendEvents.append(SendEvent(isSuccess: isSuccess, httpStatus: httpStatus))
    }

    func sendFirstSendCompletedEvent() {
        firstSendCompletedCount += 1
    }
}
