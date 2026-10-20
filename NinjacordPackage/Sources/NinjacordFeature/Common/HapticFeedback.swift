//
//  HapticFeedback.swift
//  NinjacordApp
//

import UIKit

/// 振動（ハプティクス）を鳴らす。使う側は init で受け取り、テストやプレビューでは鳴らさないものに差し替える
@MainActor
protocol HapticFeedbackPlaying: AnyObject {
    /// ボタンを押した瞬間の軽い振動
    func playImpact()
    /// 処理の結果を知らせる振動。成功と失敗で違う振動にする
    func playNotification(isSuccess: Bool)
}

/// UIKit の FeedbackGenerator で振動を鳴らす（iOS 16 で使える API）
@MainActor
final class HapticFeedback: HapticFeedbackPlaying {
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    func playImpact() {
        impactGenerator.impactOccurred()
    }

    func playNotification(isSuccess: Bool) {
        notificationGenerator.notificationOccurred(isSuccess ? .success : .error)
    }
}
