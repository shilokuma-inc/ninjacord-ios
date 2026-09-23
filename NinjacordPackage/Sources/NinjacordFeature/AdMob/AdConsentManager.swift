//
//  AdConsentManager.swift
//  NinjacordApp
//

import GoogleMobileAds
import UserMessagingPlatform

/// UMP（User Messaging Platform）で広告の同意を取得し、許可されてから GoogleMobileAds を初期化する。
/// 同意が必要ない地域では、同意情報の更新後すぐに `canRequestAds` が true になる
@MainActor
final class AdConsentManager: ObservableObject {
    static let shared = AdConsentManager()

    /// 広告をリクエストしてよいか。false の間はバナー・ネイティブ広告を読み込まない
    @Published private(set) var canRequestAds = false

    private var isMobileAdsStarted = false
    private var hasGatheredConsent = false

    private init() {
        // 前回までの起動で同意済みなら、同意情報の更新を待たずに広告を出せる
        if UMPConsentInformation.sharedInstance.canRequestAds {
            startMobileAdsIfNeeded()
        }
    }

    /// 同意情報を更新し、必要なら同意フォームを表示する。起動ごとに 1 回だけ実行され、2 回目以降は何もしない
    func gatherConsent(from viewController: UIViewController?) async {
        guard AdConfiguration.isEnabled, !hasGatheredConsent else { return }
        hasGatheredConsent = true

        let parameters = UMPRequestParameters()
        parameters.debugSettings = Self.debugSettings

        do {
            try await UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters)
            if let viewController {
                try await UMPConsentForm.loadAndPresentIfRequired(from: viewController)
            }
        } catch {
            // 取得・表示に失敗しても、前回までの同意状況で広告を出せる場合があるので続行する
            print("UMP consent failed: \(error)")
            if Self.isMisconfiguration(error) {
                // AdMob コンソールに同意メッセージが未設定だと、地域を問わず必ずこのエラーになり
                // canRequestAds が false のままになる。広告が一切出なくなるのを防ぐため、
                // 未設定の間は従来どおり初期化する（メッセージを設定すれば通常の同意フローになる）
                startMobileAdsIfNeeded()
                return
            }
        }

        if UMPConsentInformation.sharedInstance.canRequestAds {
            startMobileAdsIfNeeded()
        }
    }

    private static func isMisconfiguration(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == UMPErrorDomain
            && nsError.code == UMPRequestErrorCode.misconfiguration.rawValue
    }

    private func startMobileAdsIfNeeded() {
        guard AdConfiguration.isEnabled, !isMobileAdsStarted else { return }
        isMobileAdsStarted = true
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        canRequestAds = true
    }

    /// 起動引数 `-ump-debug-eea` を付けると EEA 内として同意フォームを確認できる（テスト端末でのみ有効）
    private static var debugSettings: UMPDebugSettings? {
        guard ProcessInfo.processInfo.arguments.contains("-ump-debug-eea") else { return nil }
        let debugSettings = UMPDebugSettings()
        debugSettings.geography = .EEA
        return debugSettings
    }
}
