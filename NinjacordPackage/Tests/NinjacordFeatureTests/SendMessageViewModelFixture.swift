//
//  SendMessageViewModelFixture.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing
import UIKit

/// SendMessageViewModel のテストで使う、依存を差し替えた ViewModel 一式。テストごとに作る。
/// 通信は URL ごとのスタブ、保存先はテストごとの UserDefaults、Analytics と送信後の流れは記録するだけのものにする
@MainActor
final class SendMessageViewModelFixture {
    let userDefaults: UserDefaults
    let historyStore: SendHistoryStore
    let sendSuccessCounter: SendSuccessCounter
    let analytics: AnalyticsSpy
    /// 送信後の流れ（リワード解放の消費・ATT・レビュー依頼・待ち・全画面広告）で起きたこと
    let recorder: SendSucceededRecorder
    /// View から渡す、全画面広告の表示元
    let rootViewController: UIViewController
    let viewModel: SendMessageViewModel

    private let suiteName = "SendMessageViewModelTests.\(UUID().uuidString)"

    init() throws {
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
        // 送信履歴の保存は既定で OFF なので、記録を確かめるために ON にする
        userDefaults.set(true, forKey: SendHistoryStore.isEnabledKey)
        historyStore = SendHistoryStore(userDefaults: userDefaults)
        sendSuccessCounter = SendSuccessCounter(userDefaults: userDefaults)
        let analytics = AnalyticsSpy()
        self.analytics = analytics
        let recorder = SendSucceededRecorder()
        self.recorder = recorder
        rootViewController = UIViewController()
        viewModel = SendMessageViewModel(
            client: DiscordWebhookClient(session: StubURLProtocol.session),
            historyStore: historyStore,
            analytics: analytics,
            sendSuccessCounter: sendSuccessCounter,
            rewardedUnlock: RewardedUnlockSpy(recorder: recorder),
            interstitialAd: InterstitialAdSpy(recorder: recorder),
            requestTrackingAuthorization: {
                recorder.record(.requestTracking)
                return recorder.trackingDialogWillBeShown
            },
            sleep: { duration in
                recorder.record(.sleep(duration))
            }
        )
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    /// View から渡すもの。レビュー依頼は記録し、全画面広告の表示元はテストの UIViewController を返す
    var screenActions: SendMessageScreenActions {
        let recorder = recorder
        let rootViewController = rootViewController
        return SendMessageScreenActions(
            requestReview: { recorder.record(.requestReview) },
            rootViewController: { rootViewController }
        )
    }

    /// 送信ボタンを押したときと同じく sendMessage を呼び、送信を始めたら終わるまで待つ。始めたかどうかを返す
    @discardableResult
    func send(isPro: Bool = false) async -> Bool {
        let task = viewModel.sendMessage(isPro: isPro, screenActions: screenActions)
        await task?.value
        return task != nil
    }

    /// 応答を決めた宛先（一斉送信用）
    func savedURL(_ name: String, returning stub: StubURLProtocol.Stub) -> SavedWebhookURL {
        SavedWebhookURL(id: UUID(), name: name, url: StubURLProtocol.makeURL(returning: stub).absoluteString)
    }
}
