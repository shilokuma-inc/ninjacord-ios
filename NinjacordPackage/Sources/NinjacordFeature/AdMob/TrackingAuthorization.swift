//
//  TrackingAuthorization.swift
//  NinjacordApp
//

import AppTrackingTransparency

/// App Tracking Transparency (ATT) の許可を求める。
/// 起動直後ではなく、アプリの価値を体験した初回送信の成功後に表示する方針
enum TrackingAuthorization {
    /// まだ ATT の許可を尋ねていなければ、許可ダイアログを表示する。
    /// 一度答えた人（許可・拒否とも）や、広告を表示しないビルドでは何もしない
    /// - Returns: 許可ダイアログを表示したか
    @MainActor
    @discardableResult
    static func requestIfNeeded() async -> Bool {
        guard AdConfiguration.isEnabled,
              ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return false }
        _ = await ATTrackingManager.requestTrackingAuthorization()
        return true
    }
}
