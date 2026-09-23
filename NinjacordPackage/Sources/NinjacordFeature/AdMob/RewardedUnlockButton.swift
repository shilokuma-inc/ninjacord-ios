//
//  RewardedUnlockButton.swift
//  NinjacordApp
//

import SwiftUI

/// 「広告を見て24時間使う」ボタン。リワード広告を読み込めたときだけ表示する。
/// 読み込み前は中身が空になり onAppear が呼ばれないため、先読みは置き場所の画面で `preloadsRewardedAd` を使って行う
struct RewardedUnlockButton: View {
    /// 最後まで視聴して一時解放されたとき
    var onUnlocked: () -> Void = {}

    @ObservedObject private var rewardedAdManager = RewardedAdManager.shared
    @State private var isShowing = false

    var body: some View {
        if rewardedAdManager.isReady {
            Button {
                Task {
                    isShowing = true
                    let earned = await rewardedAdManager.showForUnlock()
                    isShowing = false
                    if earned {
                        onUnlocked()
                    }
                }
            } label: {
                Label(RewardedUnlock.watchAdTitle, systemImage: "play.rectangle.fill")
            }
            .disabled(isShowing)
        }
    }
}

extension RewardedUnlock {
    /// 「広告を見て24時間使う」の文言。時間は RewardedUnlock.duration から出す
    static var watchAdTitle: String {
        String(localized: "広告を見て\(Int(duration / 3600))時間使う")
    }
}

extension RewardedAdManager {
    /// Pro 機能の一時解放のために表示する。シートの上からでも表示できるよう、表示元は GMA に任せる
    /// （nil を渡すとアプリのメインウィンドウの最前面の画面から表示される）
    func showForUnlock() async -> Bool {
        await show(from: nil)
    }
}

extension View {
    /// Pro 機能の一時解放に使うリワード広告を先読みする。
    /// 起動直後は広告の同意が取れておらず読み込めないため、表示時に加えて同意が取れたときにも読み込む
    func preloadsRewardedAd(when isNeeded: Bool) -> some View {
        modifier(RewardedAdPreloadModifier(isNeeded: isNeeded))
    }
}

private struct RewardedAdPreloadModifier: ViewModifier {
    let isNeeded: Bool

    @ObservedObject private var adConsent = AdConsentManager.shared

    func body(content: Content) -> some View {
        content
            .onAppear(perform: preload)
            .onChange(of: adConsent.canRequestAds) { _ in
                preload()
            }
    }

    private func preload() {
        guard isNeeded else { return }
        RewardedAdManager.shared.preload()
    }
}
