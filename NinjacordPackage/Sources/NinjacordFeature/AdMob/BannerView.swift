//
//  BannerView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/06.
//

import SwiftUI
import GoogleMobileAds

struct BannerView: UIViewControllerRepresentable {
    @EnvironmentObject private var sceneDelegate: MySceneDelegate
    /// 同意が得られたときに updateUIViewController を呼び直して読み込ませるため監視する
    @ObservedObject private var adConsent = AdConsentManager.shared
    private let adUnitID = AdUnitIdProvider.banner

    func makeUIViewController(context: Context) -> some UIViewController {
        let bannerViewController = BannerViewController()
        // struct は親の再描画のたびに作り直されるため、画面に載せる GADBannerView は Coordinator で保持する
        let bannerView = context.coordinator.bannerView
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = bannerViewController
        bannerView.delegate = context.coordinator
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerViewController.view.addSubview(bannerView)

        NSLayoutConstraint.activate(
            [
                bannerView.bottomAnchor.constraint(
                    equalTo: bannerViewController.view.safeAreaLayoutGuide.bottomAnchor),
                bannerView.centerXAnchor.constraint(equalTo: bannerViewController.view.centerXAnchor)
            ]
        )

        bannerViewController.delegate = context.coordinator

        return bannerViewController
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        context.coordinator.canRequestAds = adConsent.canRequestAds
        context.coordinator.loadAdIfNeeded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, BannerViewControllerWidthDelegate, GADBannerViewDelegate {
        let bannerView = GADBannerView()
        /// parent の struct は作り直されると古くなるため、幅と同意状態は Coordinator 側で保持する
        private var viewWidth: CGFloat = .zero
        var canRequestAds = false
        /// 同じ幅で再描画のたびに読み込み直さないよう、最後に読み込んだ幅を記録する
        private var loadedWidth: CGFloat?

        /// 幅と同意状態が揃っていて、まだその幅で読み込んでいないときだけ読み込む
        func loadAdIfNeeded() {
            guard viewWidth != .zero, canRequestAds, loadedWidth != viewWidth else { return }

            loadedWidth = viewWidth
            // Request a banner ad with the updated viewWidth.
            bannerView.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
            bannerView.load(GADRequest())
        }

        // MARK: - BannerViewControllerWidthDelegate methods
        func bannerViewController(_ bannerViewController: BannerViewController, didUpdate width: CGFloat) {
            viewWidth = width
            loadAdIfNeeded()
        }

        // MARK: - GADBannerViewDelegate methods

        func bannerViewDidReceiveAd(_: GADBannerView) {
            print("\(#function) called")
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("AdMob banner ad failed: \(error)")
        }

        func bannerViewDidRecordImpression(_: GADBannerView) {
            print("\(#function) called")
        }

        func bannerViewWillPresentScreen(_: GADBannerView) {
            print("\(#function) called")
        }

        func bannerViewWillDismissScreen(_: GADBannerView) {
            print("\(#function) called")
        }

        func bannerViewDidDismissScreen(_: GADBannerView) {
            print("\(#function) called")
        }
    }
}
