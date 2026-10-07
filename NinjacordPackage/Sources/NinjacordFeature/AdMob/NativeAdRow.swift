//
//  NativeAdRow.swift
//  NinjacordApp
//

import SwiftUI

/// List の行として置くネイティブ広告。読み込めたときだけ表示する。
/// 読み込み前は中身が空になり onAppear が呼ばれないため、読み込みは置き場所の List で `loadsNativeAd` を使って行う
struct NativeAdRow: View {
    @ObservedObject var model: NativeAdModel

    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        // ペイウォールの特典「広告を非表示」に合わせ、Pro 購読中はネイティブ広告も出さない
        if let nativeAd = model.nativeAd, !purchaseManager.isPro {
            // 広告内側の余白と合わせて、他の行と同じ 16pt の余白になるようにする
            NativeAdView(nativeAd: nativeAd)
                .listRowInsets(EdgeInsets(
                    top: 16 - NativeAdView.contentInset,
                    leading: 16 - NativeAdView.contentInset,
                    bottom: 16 - NativeAdView.contentInset,
                    trailing: 16 - NativeAdView.contentInset
                ))
                .listRowBackground(Color.appSurface)
        }
    }
}

extension View {
    /// `NativeAdRow` に出すネイティブ広告を読み込む。
    /// 起動直後は広告の同意が取れておらず読み込めないため、表示時に加えて同意が取れたときにも読み込む
    func loadsNativeAd(_ model: NativeAdModel) -> some View {
        modifier(NativeAdLoadModifier(model: model))
    }
}

private struct NativeAdLoadModifier: ViewModifier {
    let model: NativeAdModel

    @EnvironmentObject private var sceneDelegate: MySceneDelegate
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @ObservedObject private var adConsent = AdConsentManager.shared

    func body(content: Content) -> some View {
        content
            .onAppear(perform: loadAd)
            .onChange(of: adConsent.canRequestAds) { _ in
                // 画面を開いている間に同意が得られた場合も広告を読み込む
                loadAd()
            }
    }

    private func loadAd() {
        guard AdConfiguration.isEnabled, adConsent.canRequestAds, !purchaseManager.isPro else { return }

        model.load(
            windowScene: sceneDelegate.windowScene,
            rootViewController: sceneDelegate.window?.rootViewController
        )
    }
}
