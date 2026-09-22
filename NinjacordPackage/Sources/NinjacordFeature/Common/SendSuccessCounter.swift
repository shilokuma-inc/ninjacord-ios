//
//  SendSuccessCounter.swift
//  NinjacordApp
//

import Foundation

/// メッセージ送信に成功した回数の永続化を担う（保存先は UserDefaults）。
/// 初回送信の計測や、ATT 要求・レビュー依頼を出すタイミングの判定に使う
struct SendSuccessCounter {
    private static let storageKey = "sendSuccessCount"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// これまでに送信に成功した回数
    var count: Int {
        userDefaults.integer(forKey: Self.storageKey)
    }

    /// 送信成功を 1 回記録し、記録後の回数を返す
    @discardableResult
    func increment() -> Int {
        let newCount = count + 1
        userDefaults.set(newCount, forKey: Self.storageKey)
        return newCount
    }
}
