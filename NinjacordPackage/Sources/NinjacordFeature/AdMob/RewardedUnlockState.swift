//
//  RewardedUnlockState.swift
//  NinjacordApp
//

import Foundation

/// リワード広告の一時解放（`RewardedUnlock`）を画面から監視するための状態。
/// 視聴した直後と、期限が切れたときに `isUnlocked` が変わる
@MainActor
final class RewardedUnlockState: ObservableObject {
    static let shared = RewardedUnlockState()

    @Published private(set) var isUnlocked = false

    private let unlock = RewardedUnlock()
    private var expirationTask: Task<Void, Never>?

    private init() {
        refresh()
    }

    /// 保存されている期限から状態を読み直し、期限が来たら自動で解除されるようにする
    func refresh() {
        isUnlocked = unlock.isUnlocked()
        expirationTask?.cancel()
        guard isUnlocked, let unlockedUntil = unlock.unlockedUntil else { return }
        expirationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(unlockedUntil.timeIntervalSinceNow, 0)))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}

/// 広告以外の Pro 機能（テンプレート無制限・embed の Pro 項目・一斉送信）を使えるか。
/// Discussion #261 の決定により、リワード広告の一時解放でも使える（広告の非表示は Pro 購読のみ）
enum ProFeatureAccess {
    @MainActor
    static func canUse(isPro: Bool) -> Bool {
        isPro || RewardedUnlockState.shared.isUnlocked
    }
}
