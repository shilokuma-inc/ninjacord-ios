//
//  FirebaseAnalytics.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/05.
//

import FirebaseAnalytics

final class FirebaseAnalytics {
    func sendAnalyticsScreen(screenName: String) {
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: screenName
            ]
        )
    }

    /// メッセージ送信の完了（成功・失敗とも）を記録する。送信本文などの入力内容は送らない
    /// - Parameters:
    ///   - isSuccess: 送信に成功したか
    ///   - httpStatus: Discord が返した HTTP ステータスコード。レスポンスが無い通信エラーは nil
    func sendMessageSendEvent(isSuccess: Bool, httpStatus: Int?) {
        Analytics.logEvent(
            "message_send",
            parameters: [
                "result": isSuccess ? "success" : "failure",
                // レスポンスが無い場合も集計で区別できるよう 0 を入れる
                "http_status": httpStatus ?? 0
            ]
        )
    }

    /// インストール後、初めてメッセージ送信に成功したことを記録する
    func sendFirstSendCompletedEvent() {
        Analytics.logEvent("first_send_completed", parameters: nil)
    }

    /// ペイウォールを表示したことを記録する。価格の見直し（Discussion #386）の根拠にする
    /// - Parameter source: ペイウォールを開いた場所（`PaywallView.Source`）
    func sendPaywallViewEvent(source: String) {
        Analytics.logEvent("paywall_view", parameters: ["source": source])
    }

    /// ペイウォールでの購入の結果を記録する。
    /// 購入の成立は Firebase が `in_app_purchase` として自動で記録するため、二重計上にならないよう別の名前にする
    /// - Parameters:
    ///   - source: ペイウォールを開いた場所
    ///   - result: `success` / `cancelled` / `pending` / `failed`
    func sendPaywallPurchaseEvent(source: String, result: String) {
        Analytics.logEvent("paywall_purchase", parameters: ["source": source, "result": result])
    }

    /// ペイウォールでの購入の復元の結果を記録する
    /// - Parameters:
    ///   - source: ペイウォールを開いた場所
    ///   - result: `restored` / `not_found` / `failed`
    func sendPaywallRestoreEvent(source: String, result: String) {
        Analytics.logEvent("paywall_restore", parameters: ["source": source, "result": result])
    }
}
