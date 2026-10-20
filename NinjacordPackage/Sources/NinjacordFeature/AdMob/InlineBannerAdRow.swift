//
//  InlineBannerAdRow.swift
//  NinjacordApp
//

import SwiftUI
import GoogleMobileAds

/// 一覧画面の List の先頭に置くインラインのアダプティブバナー。読み込めたときだけ表示する。
/// 送信画面の下端に固定するアンカーバナー（`BannerView`）とは別物。
/// 読み込み前は中身が空になり onAppear が呼ばれないため、読み込みは置き場所の List で `loadsInlineBannerAd` を使って行う
struct InlineBannerAdRow: View {
    @ObservedObject var model: InlineBannerAdModel

    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        // ペイウォールの特典「広告を非表示」に合わせ、Pro 購読中は出さない
        if let adSize = model.loadedAdSize, !purchaseManager.isPro {
            VStack(alignment: .leading, spacing: 8) {
                InlineBannerAdBadge()

                InlineBannerAdContainer(bannerView: model.bannerView)
                    .frame(width: adSize.width, height: adSize.height)
                    .frame(maxWidth: .infinity)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            .listRowBackground(Color.appSurface)
        }
    }
}

/// 広告であることを示すバッジ。ネイティブ広告（`NativeAdView`）のバッジと同じ見た目にする
private struct InlineBannerAdBadge: View {
    var body: some View {
        Text("広告")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 4))
    }
}

/// 読み込み済みの `GADBannerView` を行に載せる。
/// 行はスクロールで作り直されるため、`GADBannerView` はモデル側で保持し、ここでは毎回載せ替える
private struct InlineBannerAdContainer: UIViewRepresentable {
    let bannerView: GADBannerView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        bannerView.removeFromSuperview()
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// インラインのアダプティブバナーの読み込みと、読み込み後に決まるサイズを持つ。
/// 置いた行ごとに 1 つ持たせ、同じ広告を 2 か所に載せない
@MainActor
final class InlineBannerAdModel: NSObject, ObservableObject, GADBannerViewDelegate {
    let bannerView = GADBannerView()
    /// 読み込みに成功したときの広告のサイズ。読み込み前・失敗時は nil で、行ごと出さない
    @Published private(set) var loadedAdSize: CGSize?
    /// 同じ幅で再描画のたびに読み込み直さないよう、最後に読み込んだ幅を記録する
    private var loadedWidth: CGFloat?

    func load(width: CGFloat, rootViewController: UIViewController?) {
        guard width > 0, loadedWidth != width else { return }

        loadedWidth = width
        bannerView.adUnitID = AdUnitIdProvider.banner
        bannerView.rootViewController = rootViewController
        bannerView.delegate = self
        bannerView.adSize = GADCurrentOrientationInlineAdaptiveBannerAdSizeWithWidth(width)
        bannerView.load(GADRequest())
    }

    // MARK: - GADBannerViewDelegate

    nonisolated func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        // インラインのアダプティブバナーは、読み込み後に adSize が実際の高さに更新される
        let size = bannerView.adSize.size
        Task { @MainActor in
            loadedAdSize = size
        }
    }

    nonisolated func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        print("AdMob inline banner ad failed: \(error)")
        Task { @MainActor in
            loadedAdSize = nil
            // 次に画面を開いたときに同じ幅で読み込み直せるよう、記録した幅を消す
            loadedWidth = nil
        }
    }
}

extension View {
    /// `InlineBannerAdRow` に出すバナーを、この View（List）の幅に合わせて読み込む。
    /// `isEnabled` には一覧に項目があるか（空の状態では広告を出さない）を渡す。
    /// 起動直後は広告の同意が取れておらず読み込めないため、表示時に加えて同意が取れたときにも読み込む
    func loadsInlineBannerAd(_ model: InlineBannerAdModel, when isEnabled: Bool) -> some View {
        modifier(InlineBannerAdLoadModifier(model: model, isEnabled: isEnabled))
    }
}

private struct InlineBannerAdLoadModifier: ViewModifier {
    /// List の左右の余白（iPhone の insetGrouped で最大 20pt）と行の左右の余白（8pt）。
    /// バナーが行からはみ出さないよう、List の幅からこの分を引いた幅で読み込む
    private static let horizontalMargin: CGFloat = (20 + 8) * 2

    let model: InlineBannerAdModel
    let isEnabled: Bool

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @ObservedObject private var adConsent = AdConsentManager.shared
    @State private var listWidth: CGFloat = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            listWidth = proxy.size.width
                        }
                        .onChange(of: proxy.size.width) { width in
                            listWidth = width
                        }
                }
            )
            .onAppear(perform: loadAd)
            .onChange(of: listWidth) { _ in
                loadAd()
            }
            .onChange(of: isEnabled) { _ in
                loadAd()
            }
            .onChange(of: adConsent.canRequestAds) { _ in
                // 画面を開いている間に同意が得られた場合も広告を読み込む
                loadAd()
            }
            .onChange(of: purchaseManager.isPro) { _ in
                // 画面を開いている間に Pro が解除された場合も広告を読み込む
                loadAd()
            }
    }

    private func loadAd() {
        guard AdConfiguration.isEnabled, adConsent.canRequestAds, !purchaseManager.isPro, isEnabled else { return }

        model.load(width: listWidth - Self.horizontalMargin, rootViewController: Self.topViewController())
    }

    /// 広告をタップしたときの遷移元。シートの上に置いた一覧でも表示できるよう、最前面の画面を返す
    private static func topViewController() -> UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var viewController = windowScene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = viewController?.presentedViewController {
            viewController = presented
        }
        return viewController
    }
}
