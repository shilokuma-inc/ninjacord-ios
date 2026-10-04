//
//  RewardedUnlockState.swift
//  NinjacordApp
//

import Foundation

/// リワード広告の一時解放（`RewardedUnlock`）を画面から監視するための状態。
/// 視聴した直後と、送信に成功して解放を使い切ったときに `isUnlocked` が変わる
@MainActor
final class RewardedUnlockState: ObservableObject {
    static let shared = RewardedUnlockState()

    @Published private(set) var isUnlocked = false

    private let unlock = RewardedUnlock()

    private init() {
        unlock.removeLegacyData()
        refresh()
    }

    /// 保存されている解放の有無から状態を読み直す
    func refresh() {
        isUnlocked = unlock.isUnlocked
    }

    /// 送信に成功したら呼ぶ。解放中なら使い切り、Pro 機能の画面をすぐロック表示に戻す
    func consumeIfUnlocked() {
        guard unlock.isUnlocked else { return }
        unlock.consume()
        refresh()
    }
}

/// 広告以外の Pro 機能（テンプレート無制限・embed の Pro 項目・一斉送信）を使えるか。
/// Discussion #261 の決定により、リワード広告の一時解放でも使える（広告の非表示は Pro 購読のみ）。
/// 一時解放で使えるのは次の 1 回の送信まで（Discussion #386）。
/// App Store 用スクリーンショットでは、Pro 機能を使っている画面を撮るため解放する（Discussion #355）
enum ProFeatureAccess {
    @MainActor
    static func canUse(isPro: Bool) -> Bool {
        isPro || RewardedUnlockState.shared.isUnlocked || ScreenshotDemo.isEnabled
    }
}
