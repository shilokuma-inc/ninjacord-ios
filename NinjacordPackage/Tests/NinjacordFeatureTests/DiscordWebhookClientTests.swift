//
//  DiscordWebhookClientTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// Discord への送信の通信（`DiscordWebhookClient`）を、URLProtocol のスタブで確かめる。
/// Alamofire で送っていたときと同じく、2xx 以外は失敗、通信できなければステータスコードもレスポンスも無いものとして扱う
struct DiscordWebhookClientTests {
    private static let message = MessageEntity(
        username: "レイド告知Bot",
        avatarURL: "",
        content: "今夜21:00 レイド開始",
        messageEmbedEntity: MessageEmbedEntity(title: "お知らせ")
    )
    private static let attachment = ImageAttachment(
        data: Data([0xFF, 0xD8, 0xFF, 0xE0]),
        fileName: "image.jpg",
        mimeType: "image/jpeg"
    )

    /// テストごとに別の URL に送る。送った先の URL も返す（受け取ったリクエストを見るため）
    private func send(
        returning stub: StubURLProtocol.Stub,
        attachment: ImageAttachment? = nil
    ) async -> (response: DiscordWebhookClient.Response, url: URL) {
        let url = StubURLProtocol.makeURL(returning: stub)
        let client = DiscordWebhookClient(session: StubURLProtocol.session)
        let webhookRequest = DiscordWebhookRequest(messageEntity: Self.message, attachment: attachment)
        return (await client.send(webhookRequest, to: url), url)
    }

    // MARK: - 結果

    @Test("204 No Content なら成功")
    func noContent() async {
        let (response, _) = await send(returning: .response(statusCode: 204, data: Data()))
        #expect(response.statusCode == 204)
        #expect(response.result.isSuccess)
    }

    @Test("URL に ?wait=true を付けたときのように、200 と本文が返っても成功")
    func okWithBody() async {
        let (response, _) = await send(returning: .response(statusCode: 200, data: Data(#"{"id": "1"}"#.utf8)))
        #expect(response.statusCode == 200)
        #expect(response.result.isSuccess)
    }

    @Test(
        "2xx 以外は失敗。原因はステータスコードとレスポンスの本文から判定する",
        arguments: [
            (400, DiscordWebhookError.invalidMessage),
            (401, .invalidToken),
            (403, .invalidToken),
            (404, .unknownWebhook),
            (413, .invalidMessage),
            (418, .unknown(statusCode: 418)),
            (429, .rateLimited),
            (500, .serverError),
            (503, .serverError)
        ]
    )
    func failureStatusCode(statusCode: Int, expected: DiscordWebhookError) async {
        let (response, _) = await send(returning: .response(statusCode: statusCode, data: Data()))
        #expect(response.statusCode == statusCode)
        #expect(response.result.failureValue == expected)
    }

    @Test("失敗したときはレスポンスの本文も原因の判定に使う")
    func failureBody() async {
        let body = Data(#"{"message": "Unknown Webhook", "code": 10015}"#.utf8)
        let (response, _) = await send(returning: .response(statusCode: 400, data: body))
        #expect(response.statusCode == 400)
        #expect(response.result.failureValue == .unknownWebhook)
    }

    @Test("通信できなければ、ステータスコードは nil で network")
    func networkError() async {
        let (response, _) = await send(returning: .error(URLError(.notConnectedToInternet)))
        #expect(response.statusCode == nil)
        #expect(response.result.failureValue == .network)
    }

    // MARK: - リクエストの形

    @Test("画像を添付しなければ、JSON の本文を application/json で POST する")
    func jsonRequest() async throws {
        let (_, url) = await send(returning: .response(statusCode: 204, data: Data()))
        let requests = StubURLProtocol.requests(to: url)
        #expect(requests.count == 1)
        let received = try #require(requests.first)
        #expect(received.request.url == url)
        #expect(received.request.httpMethod == "POST")
        #expect(received.request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(received.body)
        let decoded = try #require(try JSONSerialization.jsonObject(with: body) as? NSDictionary)
        let expected = DiscordWebhookRequest(messageEntity: Self.message).parameters
        #expect(decoded == NSDictionary(dictionary: expected))
        // prettyPrinted のまま送る
        #expect(body.contains(UInt8(ascii: "\n")))
    }

    @Test("画像を添付するなら、payload_json と files[0] を multipart/form-data で POST する")
    func multipartRequest() async throws {
        let (_, url) = await send(returning: .response(statusCode: 204, data: Data()), attachment: Self.attachment)
        let received = try #require(StubURLProtocol.requests(to: url).first)
        #expect(received.request.url == url)
        #expect(received.request.httpMethod == "POST")

        let contentType = try #require(received.request.value(forHTTPHeaderField: "Content-Type"))
        let prefix = "multipart/form-data; boundary="
        try #require(contentType.hasPrefix(prefix))
        let boundary = String(contentType.dropFirst(prefix.count))
        #expect(boundary.hasPrefix("ninjacord.boundary."))

        let body = try #require(received.body)
        let parts = try #require(
            MultipartFormDataParser.parse(body, boundary: boundary, fileName: "image.jpg", mimeType: "image/jpeg")
        )
        let payload = try #require(try JSONSerialization.jsonObject(with: parts.payloadJSON) as? NSDictionary)
        let expected = DiscordWebhookRequest(messageEntity: Self.message).parameters
        #expect(payload == NSDictionary(dictionary: expected))
        #expect(parts.file == Self.attachment.data)
    }

    @Test("multipart の境界は送るたびに作り直す")
    func boundaryChangesEverySend() async throws {
        let stub = StubURLProtocol.Stub.response(statusCode: 204, data: Data())
        let (_, firstURL) = await send(returning: stub, attachment: Self.attachment)
        let (_, secondURL) = await send(returning: stub, attachment: Self.attachment)
        let first = try #require(contentType(of: firstURL))
        let second = try #require(contentType(of: secondURL))
        #expect(first != second)
    }
}

private func contentType(of url: URL) -> String? {
    StubURLProtocol.requests(to: url).first?.request.value(forHTTPHeaderField: "Content-Type")
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var failureValue: Failure? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
