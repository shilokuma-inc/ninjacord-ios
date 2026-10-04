//
//  RewardedUnlock.swift
//  NinjacordApp
//

import Foundation

/// リワード広告の視聴で得られる、広告以外の Pro 機能の一時解放。
/// Pro 購読（`PurchaseManager.isPro`）とは別に持ち、広告の非表示には使わない（視聴後もバナー等は残す）。
/// 1 回の視聴で使えるのは次の 1 回の送信だけ（Discussion #386 で 24 時間から変更）。送るまで期限は無い
struct RewardedUnlock {
    private static let isUnlockedKey = "rewardedUnlockAvailable"
    /// 24 時間で解放していたときの期限。未公開の機能だったので移行せず、読まずに削除する
    private static let legacyUnlockedUntilKey = "rewardedUnlockedUntil"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// 今、一時解放中か（次の送信 1 回分の解放が残っているか）
    var isUnlocked: Bool {
        userDefaults.bool(forKey: Self.isUnlockedKey)
    }

    /// 視聴の報酬として解放する。解放中にもう一度視聴しても積み増さない（1 回分のまま）
    func grant() {
        userDefaults.set(true, forKey: Self.isUnlockedKey)
    }

    /// 送信に成功したときに、解放を使い切る
    func consume() {
        userDefaults.removeObject(forKey: Self.isUnlockedKey)
    }

    /// 24 時間で解放していたときの保存値を消す
    func removeLegacyData() {
        userDefaults.removeObject(forKey: Self.legacyUnlockedUntilKey)
    }
}
