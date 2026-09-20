//
//  BannerView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/06.
//

import SwiftUI
import GoogleMobileAds

struct BannerView: UIViewControllerRepresentable {
    @State private var viewWidth: CGFloat = .zero
    @EnvironmentObject private var sceneDelegate: MySceneDelegate
    private let bannerView = GADBannerView()
    private let adUnitID = AdUnitIdProvider.banner

    func makeUIViewController(context: Context) -> some UIViewController {
        let bannerViewController = BannerViewController()
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
        guard viewWidth != .zero else { return }

        // Request a banner ad with the updated viewWidth.
        bannerView.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
        bannerView.load(GADRequest())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, BannerViewControllerWidthDelegate, GADBannerViewDelegate {
        let parent: BannerView

        init(_ parent: BannerView) {
            self.parent = parent
        }

        // MARK: - BannerViewControllerWidthDelegate methods
        func bannerViewController(_ bannerViewController: BannerViewController, didUpdate width: CGFloat) {

            parent.viewWidth = width
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
