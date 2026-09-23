//
//  RewardedUnlock.swift
//  NinjacordApp
//

import Foundation

/// リワード広告の視聴で得られる、広告以外の Pro 機能の一時解放。
/// Pro 購読（`PurchaseManager.isPro`）とは別に持ち、広告の非表示には使わない（視聴後もバナー等は残す）。
/// 解放する機能との紐付けは Phase 2 で行う
struct RewardedUnlock {
    /// 1 回の視聴で解放する時間（Discussion #261 の案に従い 24 時間）
    static let duration: TimeInterval = 24 * 60 * 60

    private static let unlockedUntilKey = "rewardedUnlockedUntil"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// 解放の期限。解放されたことが無ければ nil
    var unlockedUntil: Date? {
        userDefaults.object(forKey: Self.unlockedUntilKey) as? Date
    }

    /// 今、一時解放中か
    func isUnlocked(now: Date = Date()) -> Bool {
        guard let unlockedUntil else { return false }
        return now < unlockedUntil
    }

    /// 視聴の報酬として解放する。解放中にもう一度視聴した場合は、その時点から改めて 24 時間にする
    func grant(now: Date = Date()) {
        userDefaults.set(now.addingTimeInterval(Self.duration), forKey: Self.unlockedUntilKey)
    }
}
