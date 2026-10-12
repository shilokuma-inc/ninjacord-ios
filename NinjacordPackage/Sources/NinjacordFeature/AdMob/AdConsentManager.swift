//
//  AdConsentManager.swift
//  NinjacordApp
//

import GoogleMobileAds
import UserMessagingPlatform

/// UMP（User Messaging Platform）で広告の同意を取得し、ATT の許可を尋ねてから GoogleMobileAds を初期化する。
/// 同意が必要ない地域では、同意情報の更新と ATT の回答のあとすぐに `canRequestAds` が true になる
@MainActor
final class AdConsentManager: ObservableObject {
    static let shared = AdConsentManager()

    /// 広告をリクエストしてよいか。false の間はバナー・ネイティブ広告を読み込まない
    @Published private(set) var canRequestAds = false

    private var isMobileAdsStarted = false
    private var hasGatheredConsent = false

    private init() {
        // 前回までの起動で同意済みで ATT にも回答済みなら、同意情報の更新を待たずに広告を出せる。
        // ATT をまだ尋ねていなければ、トラッキングに使えるデータを集める前に尋ねるため `gatherConsent` まで待つ
        if UMPConsentInformation.sharedInstance.canRequestAds && !TrackingAuthorization.needsRequest {
            startMobileAdsIfNeeded()
        }
    }

    /// 同意情報を更新し、必要なら同意フォームと ATT の許可ダイアログを表示する。起動ごとに 1 回だけ実行され、2 回目以降は何もしない
    func gatherConsent(from viewController: UIViewController?) async {
        guard AdConfiguration.isEnabled, !hasGatheredConsent else { return }
        hasGatheredConsent = true

        let parameters = UMPRequestParameters()
        parameters.debugSettings = Self.debugSettings
        var isMisconfigured = false

        do {
            try await UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters)
            if let viewController {
                try await UMPConsentForm.loadAndPresentIfRequired(from: viewController)
            }
        } catch {
            // 取得・表示に失敗しても、前回までの同意状況で広告を出せる場合があるので続行する
            print("UMP consent failed: \(error)")
            // AdMob コンソールに同意メッセージが未設定だと、地域を問わず必ずこのエラーになり
            // canRequestAds が false のままになる。広告が一切出なくなるのを防ぐため、
            // 未設定の間は従来どおり初期化する（メッセージを設定すれば通常の同意フローになる）
            isMisconfigured = Self.isMisconfiguration(error)
        }

        // ATT は UMP の結果にかかわらず尋ねる。通信の失敗などで canRequestAds が false のままでも
        // ダイアログまで辿り着けるようにするため（Guideline 2.1 で ATT が見つからないと 2 回指摘された）。
        // GoogleMobileAds は ATT の回答を待ってから初期化する（ATT より先に広告を読み込まないため）
        await TrackingAuthorization.requestIfNeeded()
        if isMisconfigured || UMPConsentInformation.sharedInstance.canRequestAds {
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
