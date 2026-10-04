//
//  RewardedUnlock.swift
//  NinjacordApp
//

import Foundation

/// リワード広告の視聴で得られる、広告の非表示とテンプレート無制限以外の Pro 機能（embed の Pro 項目・一斉送信）の一時解放。
/// Pro 購読（`PurchaseManager.isPro`）とは別に持ち、広告の非表示には使わない（視聴後もバナー等は残す）。
/// 1 回の視聴で使えるのは、Pro 機能を使った 1 回の送信だけ（Discussion #386 で 24 時間から変更、判断ログ #389）。
/// Pro 機能を使わない送信では消費しない。送るまで期限は無い
struct RewardedUnlock {
    private static let isUnlockedKey = "rewardedUnlockAvailable"
    /// 24 時間で解放していたときの期限。未公開の機能だったので移行せず、読まずに削除する
    private static let legacyUnlockedUntilKey = "rewardedUnlockedUntil"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// 今、一時解放中か（Pro 機能を使った送信 1 回分の解放が残っているか）
    var isUnlocked: Bool {
        userDefaults.bool(forKey: Self.isUnlockedKey)
    }

    /// 視聴の報酬として解放する。解放中にもう一度視聴しても積み増さない（1 回分のまま）
    func grant() {
        userDefaults.set(true, forKey: Self.isUnlockedKey)
    }

    /// Pro 機能を使った送信に成功したときに、解放を使い切る
    func consume() {
        userDefaults.removeObject(forKey: Self.isUnlockedKey)
    }

    /// 24 時間で解放していたときの保存値を消す
    func removeLegacyData() {
        userDefaults.removeObject(forKey: Self.legacyUnlockedUntilKey)
    }
}
