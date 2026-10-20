//
//  SendMessageDependencies.swift
//  NinjacordApp
//

import UIKit

/// 送信の Analytics。SendMessageViewModel が受け取り、テストでは呼ばれ方を記録するものに差し替える
protocol SendMessageAnalytics {
    func sendMessageSendEvent(isSuccess: Bool, httpStatus: Int?)
    func sendFirstSendCompletedEvent()
}

extension FirebaseAnalytics: SendMessageAnalytics {}

/// リワード広告の一時解放。Pro 機能を使った送信に成功したら使い切る
@MainActor
protocol RewardedUnlockConsuming: AnyObject {
    func consumeIfUnlocked()
}

extension RewardedUnlockState: RewardedUnlockConsuming {}

/// 送信のあとに出す全画面広告
@MainActor
protocol InterstitialAdPresenting: AnyObject {
    func showIfAllowed(from viewController: UIViewController?)
}

extension InterstitialAdManager: InterstitialAdPresenting {}

/// 送信後の流れで使う、View の環境から来るもの。送信ボタンを押したときに View から渡す
struct SendMessageScreenActions {
    /// App Store のレビュー依頼（`@Environment(\.requestReview)`）
    let requestReview: @MainActor () -> Void
    /// 全画面広告を表示する元の画面。表示する直前に読む
    let rootViewController: @MainActor () -> UIViewController?
}
