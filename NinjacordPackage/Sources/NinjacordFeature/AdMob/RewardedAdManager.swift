//
//  RewardedAdManager.swift
//  NinjacordApp
//

import GoogleMobileAds

/// リワード広告の読み込みと表示を担う。視聴を最後まで終えて報酬を得たら `RewardedUnlock` で一時解放する。
/// 利用者が自分の意思で見る広告なので頻度上限は設けない。表示の導線は Phase 2 で解放対象の機能と一緒に追加する
@MainActor
final class RewardedAdManager: NSObject, ObservableObject {
    static let shared = RewardedAdManager()

    /// 表示できる広告を読み込み済みか。導線のボタンを出し分けるのに使う
    @Published private(set) var isReady = false

    private var rewardedAd: GADRewardedAd?
    private var isLoading = false
    private let unlock = RewardedUnlock()
    /// 表示中の広告が閉じられるまで `show` の呼び出し元を待たせる
    private var dismissContinuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
    }

    /// 広告を読み込んでおく。読み込み済み・読み込み中、または広告を出せない状態なら何もしない
    func preload() {
        let adUnitID = AdUnitIdProvider.rewarded
        guard AdConfiguration.isEnabled,
              AdConsentManager.shared.canRequestAds,
              !adUnitID.isEmpty,
              rewardedAd == nil,
              !isLoading else { return }
        isLoading = true

        GADRewardedAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] loadedAd, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("AdMob rewarded ad failed: \(error)")
                    return
                }
                loadedAd?.fullScreenContentDelegate = self
                self.rewardedAd = loadedAd
                self.isReady = loadedAd != nil
            }
        }
    }

    /// 広告を表示し、閉じられるまで待つ。報酬を得た（最後まで視聴した）場合は一時解放して true を返す
    func show(from viewController: UIViewController?) async -> Bool {
        guard let rewardedAd else {
            preload()
            return false
        }
        var didEarnReward = false
        let unlock = unlock
        await withCheckedContinuation { continuation in
            dismissContinuation = continuation
            rewardedAd.present(fromRootViewController: viewController) {
                didEarnReward = true
                // 閉じる前にアプリが終了しても報酬を失わないよう、閉じるのを待たずにその場で解放する
                unlock.grant()
            }
        }
        return didEarnReward
    }

    private func finishPresentation() {
        rewardedAd = nil
        isReady = false
        dismissContinuation?.resume()
        dismissContinuation = nil
        // 一度表示した広告は使い回せないので、次を読み込む
        preload()
    }
}

extension RewardedAdManager: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ presentingAd: GADFullScreenPresentingAd) {
        Task { @MainActor in
            self.finishPresentation()
        }
    }

    nonisolated func ad(
        _ presentingAd: GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("AdMob rewarded ad failed to present: \(error)")
        Task { @MainActor in
            self.finishPresentation()
        }
    }
}
