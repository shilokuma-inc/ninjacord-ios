//
//  WebhookMessageEditor.swift
//  NinjacordApp
//

import Foundation

/// 送ったメッセージの編集・削除の Analytics。テストでは呼ばれ方を記録するものに差し替える
protocol PostedMessageAnalytics {
    func sendMessageEditEvent(isSuccess: Bool, httpStatus: Int?)
    func sendMessageDeleteEvent(isSuccess: Bool, httpStatus: Int?, source: String)
}

extension FirebaseAnalytics: PostedMessageAnalytics {}

/// Webhook で送ったメッセージの編集・削除（Issue #666）。
/// 送信履歴に残した Webhook URL とメッセージ ID から URL を作って通信し、結果を Analytics に記録する
struct WebhookMessageEditor {
    /// 削除した場所。Analytics で区別する
    enum DeleteSource: String {
        /// 送信直後のトーストの「取り消す」
        case toast
        /// 「投稿済み」の一覧
        case postedList = "posted_list"
    }

    private let client: DiscordWebhookClient
    private let analytics: PostedMessageAnalytics

    init(client: DiscordWebhookClient, analytics: PostedMessageAnalytics) {
        self.client = client
        self.analytics = analytics
    }

    /// 送ったメッセージを削除する。Discord で先に消されていたときも、消すという目的は果たせているので成功にする
    func delete(webhookURL: String, messageID: String, source: DeleteSource) async -> Result<Void, DiscordWebhookError> {
        guard let url = WebhookMessageEndpoint.messageURL(webhookURL: webhookURL, messageID: messageID) else {
            // 送れた URL と受け取った ID から作るので通常は通らない
            return .failure(.invalidToken)
        }
        let response = await client.delete(messageURL: url)
        analytics.sendMessageDeleteEvent(
            isSuccess: response.result.isSuccess,
            httpStatus: response.statusCode,
            source: source.rawValue
        )
        if case .failure(.unknownMessage) = response.result {
            return .success(())
        }
        return response.result
    }

    /// 送ったメッセージの本文と埋め込みを書き換える
    /// - Parameter sentAt: 最初に送った日時。埋め込みの送信日時（timestamp）を送ったときのままにする
    func edit(
        webhookURL: String,
        messageID: String,
        message: MessageEntity,
        sentAt: Date
    ) async -> Result<Void, DiscordWebhookError> {
        guard let url = WebhookMessageEndpoint.messageURL(webhookURL: webhookURL, messageID: messageID) else {
            return .failure(.invalidToken)
        }
        let response = await client.edit(DiscordWebhookRequest(messageEntity: message, sentAt: sentAt), messageURL: url)
        analytics.sendMessageEditEvent(isSuccess: response.result.isSuccess, httpStatus: response.statusCode)
        return response.result
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}
