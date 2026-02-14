//
//  NativeAdView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/09.
//

import SwiftUI
import GoogleMobileAds

struct NativeAdView: UIViewRepresentable {
    let nativeAd: GADNativeAd
    func makeUIView(context: Context) -> GADNativeAdView {
        // swiftlint:disable force_cast
        let nativeAdView: GADNativeAdView = Bundle.main.loadNibNamed(
            "NativeAdView", owner: nil, options: nil
        )?.first as! GADNativeAdView
        // swiftlint:enable force_cast

        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
        nativeAdView.bodyView?.isHidden = nativeAd.body == nil

        (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        nativeAdView.iconView?.isHidden = nativeAd.icon == nil

        (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
        nativeAdView.storeView?.isHidden = nativeAd.store == nil

        (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
        nativeAdView.priceView?.isHidden = nativeAd.price == nil

        (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

        nativeAdView.callToActionView?.isUserInteractionEnabled = false

        nativeAdView.nativeAd = nativeAd

        return nativeAdView
    }

    func updateUIView(_ uiView: GADNativeAdView, context: Context) {

    }
}
