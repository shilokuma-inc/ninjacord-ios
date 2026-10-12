//
//  DiscordWebhookError.swift
//  NinjacordApp
//

import Foundation

/// Webhook への送信に失敗した原因。トーストの文言として表示する
enum DiscordWebhookError: LocalizedError, Equatable {
    /// Webhook が存在しない（削除された・URL が間違っている）
    case unknownWebhook
    /// Webhook URL のトークン部分が正しくない
    case invalidToken
    /// 送信内容が Discord に受け付けられなかった（画像 URL の形式・文字数など）
    case invalidMessage
    /// 短時間に送信しすぎて制限された
    case rateLimited
    /// Discord 側の障害
    case serverError
    /// 通信できなかった（オフライン・タイムアウトなど）
    case network
    /// 上記以外。ステータスコードがあれば表示する
    case unknown(statusCode: Int?)

    /// Discord の JSON エラーコード
    /// https://discord.com/developers/docs/topics/opcodes-and-status-codes#json
    private enum JSONErrorCode {
        static let unknownWebhook = 10015
        static let invalidWebhookToken = 50027
    }

    /// HTTP ステータスコードとレスポンス本文から原因を判定する。
    /// ステータスコードが nil の場合はレスポンスが返っていない（通信エラー）とみなす
    init(statusCode: Int?, data: Data?) {
        guard let statusCode else {
            self = .network
            return
        }

        let body = data.flatMap { try? JSONDecoder().decode(DiscordErrorResponseBody.self, from: $0) }
        if body?.isInvalidWebhookURL == true {
            self = .invalidToken
            return
        }

        switch (statusCode, body?.code) {
        case (_, JSONErrorCode.unknownWebhook), (404, _):
            self = .unknownWebhook
        case (_, JSONErrorCode.invalidWebhookToken), (401, _), (403, _):
            self = .invalidToken
        case (400, _), (413, _):
            self = .invalidMessage
        case (429, _):
            self = .rateLimited
        case (500...599, _):
            self = .serverError
        default:
            self = .unknown(statusCode: statusCode)
        }
    }

    var errorDescription: String? {
        switch self {
        case .unknownWebhook:
            return String(localized: "Webhookが見つかりません。URLが正しいか、Webhookが削除されていないか確認してください")
        case .invalidToken:
            return String(localized: "Webhook URLが正しくありません。Discordでコピーし直してください")
        case .invalidMessage:
            return String(localized: "送信内容に誤りがあります。プロフィール画像のURLや文字数を確認してください")
        case .rateLimited:
            return String(localized: "送信回数が多すぎます。しばらく待ってから送信してください")
        case .serverError:
            return String(localized: "Discordで障害が発生しています。しばらく待ってから送信してください")
        case .network:
            return String(localized: "通信に失敗しました。ネットワーク接続を確認してください")
        case .unknown(let statusCode?):
            return String(localized: "送信に失敗しました（エラーコード: \(statusCode)）")
        case .unknown(.none):
            return String(localized: "送信に失敗しました")
        }
    }
}

/// Discord のエラーレスポンス本文。
/// 通常は `{"message": "...", "code": 10015}` だが、URL の ID・トークン部分が形式違いのときは
/// `{"webhook_id": ["Value \"abc\" is not snowflake."]}` のように項目名をキーにして返る
private struct DiscordErrorResponseBody: Decodable {
    let code: Int?
    let webhookID: [String]?
    let webhookToken: [String]?

    enum CodingKeys: String, CodingKey {
        case code
        case webhookID = "webhook_id"
        case webhookToken = "webhook_token"
    }

    /// URL の ID・トークン部分の形式が正しくないというエラーか
    var isInvalidWebhookURL: Bool {
        webhookID != nil || webhookToken != nil
    }
}
