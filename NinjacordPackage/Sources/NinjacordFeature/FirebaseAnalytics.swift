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
}
