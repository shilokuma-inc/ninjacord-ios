//
//  DiscordWebhookClient.swift
//  NinjacordApp
//

import Foundation

/// Discord の Webhook に送信する通信。URLSession の async API で送り、レスポンスを待って結果を返す
struct DiscordWebhookClient {
    /// 通信の結果。Analytics にステータスコードも記録するため、成否と一緒に返す
    struct Response<Success> {
        /// Discord が返した HTTP ステータスコード。通信できずレスポンスが無いときは nil
        let statusCode: Int?
        let result: Result<Success, DiscordWebhookError>
    }

    private let session: URLSession

    /// - Parameter session: 送信に使う URLSession。テストでは URLProtocol のスタブを入れたものを渡す
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Webhook に送る。ステータスコードが 2xx 以外なら失敗にする（Alamofire の validate() と同じ）。
    /// `wait=true` を付けて送り、Discord が作ったメッセージの ID を受け取る
    func send(_ webhookRequest: DiscordWebhookRequest, to url: URL) async -> Response<SentWebhookMessage> {
        guard let request = makeURLRequest(webhookRequest, url: url, boundary: Self.makeBoundary()) else {
            // 送る中身を作れなければ、通信せずに失敗にする（#473）
            return Response(statusCode: nil, result: .failure(.unknown(statusCode: nil)))
        }
        return await perform(request) { data in
            // 2xx なら送れている。本文を読めなくても成功にし、ID が無いので編集・削除だけできなくする
            let body = try? JSONDecoder().decode(MessageResponseBody.self, from: data)
            // 新しい投稿として送ったときだけ、channel_id が作られたスレッド（投稿）の ID になる。
            // それ以外は宛先のチャンネルの ID で、thread_id に付けると見つからないので受け取らない（Issue #699）
            return SentWebhookMessage(id: body?.id, threadID: webhookRequest.threadName == nil ? nil : body?.channelID)
        }
    }

    /// 送ったメッセージの本文と埋め込みを書き換える（PATCH）。URL は `WebhookMessageEndpoint.messageURL` で作る。
    /// 送れるのは同じ Webhook で送ったメッセージだけ
    /// https://discord.com/developers/docs/resources/webhook#edit-webhook-message
    func edit(_ webhookRequest: DiscordWebhookRequest, messageURL: URL) async -> Response<Void> {
        guard let body = webhookRequest.editJSONBody else {
            return Response(statusCode: nil, result: .failure(.unknown(statusCode: nil)))
        }
        var request = URLRequest(url: messageURL)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return await perform(request) { _ in () }
    }

    /// 送ったメッセージを削除する（DELETE）。成功すると 204 が返る。URL は `WebhookMessageEndpoint.messageURL` で作る
    /// https://discord.com/developers/docs/resources/webhook#delete-webhook-message
    func delete(messageURL: URL) async -> Response<Void> {
        var request = URLRequest(url: messageURL)
        request.httpMethod = "DELETE"
        return await perform(request) { _ in () }
    }

    /// 送る URLRequest を組み立てる。画像を添付するなら multipart/form-data、しなければ JSON で送る。
    /// 送る中身（パラメータの JSON）を作れなければ nil
    func makeURLRequest(_ webhookRequest: DiscordWebhookRequest, url: URL, boundary: String) -> URLRequest? {
        var request = URLRequest(url: WebhookMessageEndpoint.executeURL(from: url))
        request.httpMethod = "POST"
        if webhookRequest.attachment != nil {
            guard let multipartBody = webhookRequest.multipartBody(boundary: boundary) else {
                return nil
            }
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = multipartBody
        } else {
            guard let jsonBody = webhookRequest.jsonBody else {
                return nil
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonBody
        }
        return request
    }

    /// 通信して、2xx なら本文から成功の値を作る。2xx 以外はステータスコードと本文から原因を判定する
    private func perform<Success>(
        _ request: URLRequest,
        success: (Data) -> Success
    ) async -> Response<Success> {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return Response(statusCode: nil, result: .failure(DiscordWebhookError(statusCode: nil, data: nil)))
        }
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            return Response(statusCode: nil, result: .failure(DiscordWebhookError(statusCode: nil, data: nil)))
        }
        guard (200..<300).contains(statusCode) else {
            let error = DiscordWebhookError(statusCode: statusCode, data: data)
            return Response(statusCode: statusCode, result: .failure(error))
        }
        return Response(statusCode: statusCode, result: .success(success(data)))
    }

    /// multipart/form-data の境界。Alamofire と同じく、送るたびに乱数で作る
    private static func makeBoundary() -> String {
        String(
            format: "ninjacord.boundary.%08x%08x",
            UInt32.random(in: .min ... .max),
            UInt32.random(in: .min ... .max)
        )
    }
}

/// Webhook で送ったメッセージ。`wait=true` で送ると、Discord が作ったメッセージが返る
struct SentWebhookMessage: Equatable {
    /// メッセージの ID。編集・削除に使う。レスポンスを読めなかったときは nil（送れてはいる）
    let id: String?
    /// フォーラム・メディアチャンネルに新しい投稿として送ったときの、作られたスレッド（投稿）の ID。
    /// 編集・削除のときに `thread_id` として付けないと、メッセージが見つからない。新しい投稿でなければ nil
    let threadID: String?

    init(id: String?, threadID: String? = nil) {
        self.id = id
        self.threadID = threadID
    }
}

/// Execute Webhook（`wait=true`）のレスポンスのうち、使う項目だけ
/// https://discord.com/developers/docs/resources/message#message-object
private struct MessageResponseBody: Decodable {
    let id: String
    /// メッセージを送ったチャンネル。新しい投稿として送ったときは、作られたスレッド
    let channelID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case channelID = "channel_id"
    }
}
