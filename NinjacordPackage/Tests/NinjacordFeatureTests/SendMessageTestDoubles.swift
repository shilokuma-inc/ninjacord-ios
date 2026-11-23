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
        case requestReview
        case sleep(Duration)
        case showInterstitial(from: UIViewController?)
    }

    private(set) var events: [Event] = []

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

/// 鳴らした振動を記録する（実際には鳴らさない）
@MainActor
final class HapticFeedbackSpy: HapticFeedbackPlaying {
    private(set) var impactCount = 0
    /// 結果を知らせる振動を鳴らした順に、成功だったかを記録する
    private(set) var notifications: [Bool] = []

    func playImpact() {
        impactCount += 1
    }

    func playNotification(isSuccess: Bool) {
        notifications.append(isSuccess)
    }
}

/// 送信と、送ったメッセージの編集・削除の Analytics に送った値を記録する（Firebase には送らない）
final class AnalyticsSpy: SendMessageAnalytics {
    struct SendEvent: Equatable {
        let isSuccess: Bool
        let httpStatus: Int?
    }

    /// 送ったメッセージの削除の Analytics
    struct DeleteEvent: Equatable {
        let isSuccess: Bool
        let httpStatus: Int?
        let source: String
    }

    private(set) var sendEvents: [SendEvent] = []
    private(set) var firstSendCompletedCount = 0
    /// 送ったメッセージの編集の Analytics（成否とステータスコード）
    fileprivate(set) var editEvents: [SendEvent] = []
    fileprivate(set) var deleteEvents: [DeleteEvent] = []

    func sendMessageSendEvent(isSuccess: Bool, httpStatus: Int?) {
        sendEvents.append(SendEvent(isSuccess: isSuccess, httpStatus: httpStatus))
    }

    func sendFirstSendCompletedEvent() {
        firstSendCompletedCount += 1
    }
}

extension AnalyticsSpy: PostedMessageAnalytics {
    func sendMessageEditEvent(isSuccess: Bool, httpStatus: Int?) {
        editEvents.append(SendEvent(isSuccess: isSuccess, httpStatus: httpStatus))
    }

    func sendMessageDeleteEvent(isSuccess: Bool, httpStatus: Int?, source: String) {
        deleteEvents.append(DeleteEvent(isSuccess: isSuccess, httpStatus: httpStatus, source: source))
    }
}
