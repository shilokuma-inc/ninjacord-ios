//
//  NativeAdModel.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/09.
//

import GoogleMobileAds

enum AdUnitIdProvider {
    static var native: String {
        Bundle.main.object(forInfoDictionaryKey: "AdMobNativeAdUnitID") as? String ?? ""
    }
    
    static var banner: String {
        // Info.plist の AdMobBannerAdUnitID を参照（Scheme/Build Configurationごとに値を差し替える）
        Bundle.main.object(forInfoDictionaryKey: "AdMobBannerAdUnitID") as? String ?? ""
    }
}

class NativeAdModel: NSObject, ObservableObject, GADNativeAdLoaderDelegate {
    @Published var nativeAd: GADNativeAd?
    private var adLoader: GADAdLoader?

    func load(windowScene: UIWindowScene?,
              rootViewController: UIViewController?) {
        let adLoader = GADAdLoader(
            adUnitID: AdUnitIdProvider.native,
            rootViewController: rootViewController,
            adTypes: [.native],
            options: nil
        )
        self.adLoader = adLoader
        adLoader.delegate = self
        let request = GADRequest()
        request.scene = windowScene
        adLoader.load(request)
    }

    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        self.nativeAd = nativeAd
    }

    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        print("AdMob native ad failed: \(error)")
    }
}
