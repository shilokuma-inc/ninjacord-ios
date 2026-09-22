//
//  InterstitialAdManager.swift
//  NinjacordApp
//

import GoogleMobileAds

/// 送信完了直後に表示するインタースティシャル広告の読み込みと表示を担う。
/// 表示までの待ち時間をなくすため、表示できる状態になったら次の 1 件を先に読み込んでおく
@MainActor
final class InterstitialAdManager: NSObject {
    static let shared = InterstitialAdManager()

    private var interstitialAd: GADInterstitialAd?
    private var isLoading = false
    private let frequencyCap = InterstitialFrequencyCap()

    private override init() {
        super.init()
    }

    /// 広告を読み込んでおく。読み込み済み・読み込み中、または広告を出せない状態なら何もしない
    func preload() {
        let adUnitID = AdUnitIdProvider.interstitial
        guard AdConfiguration.isEnabled,
              AdConsentManager.shared.canRequestAds,
              !adUnitID.isEmpty,
              interstitialAd == nil,
              !isLoading else { return }
        isLoading = true

        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] loadedAd, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("AdMob interstitial ad failed: \(error)")
                    return
                }
                loadedAd?.fullScreenContentDelegate = self
                self.interstitialAd = loadedAd
            }
        }
    }

    /// 頻度上限の範囲内で、読み込み済みの広告を表示する。表示しなかった場合も次の広告の読み込みを試みる
    func showIfAllowed(from viewController: UIViewController?) {
        guard let interstitialAd, frequencyCap.canShow() else {
            preload()
            return
        }
        frequencyCap.recordShown()
        interstitialAd.present(fromRootViewController: viewController)
    }
}

extension InterstitialAdManager: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ presentingAd: GADFullScreenPresentingAd) {
        Task { @MainActor in
            // 一度表示した広告は使い回せないので、閉じたら次を読み込む
            self.interstitialAd = nil
            self.preload()
        }
    }

    nonisolated func ad(
        _ presentingAd: GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("AdMob interstitial ad failed to present: \(error)")
        Task { @MainActor in
            self.interstitialAd = nil
            self.preload()
        }
    }
}
