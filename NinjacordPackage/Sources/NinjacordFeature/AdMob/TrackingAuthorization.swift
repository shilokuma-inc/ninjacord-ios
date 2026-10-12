//
//  TrackingAuthorization.swift
//  NinjacordApp
//

import AppTrackingTransparency
import UIKit

/// App Tracking Transparency (ATT) の許可を求める。
/// トラッキングに使えるデータを集める前に尋ねるため、`AdConsentManager` が GoogleMobileAds を初期化する直前に表示する
enum TrackingAuthorization {
    /// まだ ATT の許可を尋ねていないか。広告を表示しないビルドでは常に false
    static var needsRequest: Bool {
        AdConfiguration.isEnabled && ATTrackingManager.trackingAuthorizationStatus == .notDetermined
    }

    /// まだ ATT の許可を尋ねていなければ、許可ダイアログを表示して回答を待つ。
    /// 一度答えた人（許可・拒否とも）や、広告を表示しないビルドでは何もしない
    @MainActor
    static func requestIfNeeded() async {
        guard needsRequest else { return }
        // アプリがアクティブでないとダイアログが出ずに `.notDetermined` のまま返るため、アクティブになるまで待つ
        if UIApplication.shared.applicationState != .active {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                break
            }
        }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }
}
