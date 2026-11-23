//
//  DiscordWebhookClient.swift
//  NinjacordApp
//

import Foundation

/// Discord の Webhook に送信する通信。URLSession の async API で送り、レスポンスを待って結果を返す
struct DiscordWebhookClient {
    /// 送信の結果。Analytics にステータスコードも記録するため、成否と一緒に返す
    struct Response {
        /// Discord が返した HTTP ステータスコード。通信できずレスポンスが無いときは nil
        let statusCode: Int?
        let result: Result<Void, DiscordWebhookError>
    }

    private let session: URLSession

    /// - Parameter session: 送信に使う URLSession。テストでは URLProtocol のスタブを入れたものを渡す
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Webhook に送る。ステータスコードが 2xx 以外なら失敗にする（Alamofire の validate() と同じ）
    func send(_ webhookRequest: DiscordWebhookRequest, to url: URL) async -> Response {
        guard let request = makeURLRequest(webhookRequest, url: url, boundary: Self.makeBoundary()) else {
            // 送る中身を作れなければ、通信せずに失敗にする（#473）
            return Response(statusCode: nil, result: .failure(.unknown(statusCode: nil)))
        }
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
        return Response(statusCode: statusCode, result: .success(()))
    }

    /// 送る URLRequest を組み立てる。画像を添付するなら multipart/form-data、しなければ JSON で送る。
    /// 送る中身（パラメータの JSON）を作れなければ nil
    func makeURLRequest(_ webhookRequest: DiscordWebhookRequest, url: URL, boundary: String) -> URLRequest? {
        var request = URLRequest(url: url)
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

    /// multipart/form-data の境界。Alamofire と同じく、送るたびに乱数で作る
    private static func makeBoundary() -> String {
        String(
            format: "ninjacord.boundary.%08x%08x",
            UInt32.random(in: .min ... .max),
            UInt32.random(in: .min ... .max)
        )
    }
}
