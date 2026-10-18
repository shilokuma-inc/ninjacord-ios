//
//  WebhookProfileClientTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// Webhook の名前とアイコンの取得（`WebhookProfileClient`）を、URLProtocol のスタブで確かめる
struct WebhookProfileClientTests {
    private static let webhookBody = Data(#"""
    {"type": 1, "id": "223704706495545344", "name": "レイド告知Bot",
     "avatar": "0123456789abcdef0123456789abcdef", "channel_id": "199737254929760256",
     "guild_id": "199737254929760256", "application_id": null, "token": "token"}
    """#.utf8)

    /// テストごとに別の URL から取得する。取得した先の URL も返す（受け取ったリクエストを見るため）
    private func fetch(
        returning stub: StubURLProtocol.Stub,
        input: (URL) -> String = { $0.absoluteString }
    ) async -> (result: Result<WebhookProfile, WebhookProfileError>, url: URL) {
        let url = StubURLProtocol.makeSnowflakeURL(returning: stub)
        let client = WebhookProfileClient(session: StubURLProtocol.session)
        return (await client.fetch(from: input(url)), url)
    }

    // MARK: - 結果

    @Test("200 なら名前と、ID とアイコンのハッシュから組み立てたアイコンの URL を返す")
    func success() async {
        let (result, _) = await fetch(returning: .response(statusCode: 200, data: Self.webhookBody))
        let expected = WebhookProfile(
            name: "レイド告知Bot",
            avatarURL: URL(
                string: "https://cdn.discordapp.com/avatars/223704706495545344/"
                    + "0123456789abcdef0123456789abcdef.png?size=128"
            )
        )
        #expect(result.successValue == expected)
    }

    @Test("アイコンが設定されていなければ、アイコンの URL は nil")
    func nullAvatar() async {
        let body = Data(#"{"id": "223704706495545344", "name": "レイド告知Bot", "avatar": null}"#.utf8)
        let (result, _) = await fetch(returning: .response(statusCode: 200, data: body))
        #expect(result.successValue == WebhookProfile(name: "レイド告知Bot", avatarURL: nil))
    }

    @Test("アイコンのハッシュが空文字なら、アイコンの URL は nil")
    func emptyAvatar() async {
        let body = Data(#"{"id": "223704706495545344", "name": "レイド告知Bot", "avatar": ""}"#.utf8)
        let (result, _) = await fetch(returning: .response(statusCode: 200, data: body))
        #expect(result.successValue == WebhookProfile(name: "レイド告知Bot", avatarURL: nil))
    }

    @Test("名前が null なら空にする")
    func nullName() async {
        let body = Data(#"{"id": "223704706495545344", "name": null, "avatar": null}"#.utf8)
        let (result, _) = await fetch(returning: .response(statusCode: 200, data: body))
        #expect(result.successValue == WebhookProfile(name: "", avatarURL: nil))
    }

    @Test("2xx 以外はステータスコードを持った httpStatus", arguments: [401, 404, 429, 500])
    func failureStatusCode(statusCode: Int) async {
        let body = Data(#"{"message": "Unknown Webhook", "code": 10015}"#.utf8)
        let (result, _) = await fetch(returning: .response(statusCode: statusCode, data: body))
        #expect(result.failureValue == .httpStatus(statusCode))
    }

    @Test("通信できなければ、URLError のコードを持った network")
    func networkError() async {
        let (result, _) = await fetch(returning: .error(URLError(.notConnectedToInternet)))
        #expect(result.failureValue == .network(.notConnectedToInternet))
    }

    @Test(
        "Webhook として読めない本文なら decoding",
        arguments: ["", "<html></html>", "{}", "[]", #"{"id": 1, "name": "Bot"}"#]
    )
    func decodingError(body: String) async {
        let (result, _) = await fetch(returning: .response(statusCode: 200, data: Data(body.utf8)))
        #expect(result.failureValue == .decoding)
    }

    // MARK: - リクエストの形

    @Test("Webhook URL に GET する。本文は付けない")
    func getRequest() async throws {
        let (_, url) = await fetch(returning: .response(statusCode: 200, data: Self.webhookBody))
        let requests = StubURLProtocol.requests(to: url)
        #expect(requests.count == 1)
        let received = try #require(requests.first)
        #expect(received.request.url == url)
        #expect(received.request.httpMethod == "GET")
        #expect(received.body == nil)
    }

    @Test("前後の空白とクエリを除いた URL に GET する")
    func trimmedInputWithQuery() async throws {
        let (result, url) = await fetch(
            returning: .response(statusCode: 200, data: Self.webhookBody),
            input: { " \($0.absoluteString)?thread_id=1 \n" }
        )
        #expect(result.successValue?.name == "レイド告知Bot")
        let received = try #require(StubURLProtocol.requests(to: url).first)
        #expect(received.request.url == url)
    }

    @Test("Webhook URL の形でなければ通信せずに invalidURL")
    func invalidURLDoesNotRequest() async {
        // 応答は決めてあるが、ID が数字でないので Webhook URL の形ではない
        let url = StubURLProtocol.makeURL(returning: .response(statusCode: 200, data: Self.webhookBody))
        let client = WebhookProfileClient(session: StubURLProtocol.session)
        let result = await client.fetch(from: url.absoluteString)
        #expect(result.failureValue == .invalidURL)
        #expect(StubURLProtocol.requests(to: url).isEmpty)
    }
}

/// 入力された文字列を Webhook URL とみなすか（`DiscordWebhookURL`）
struct DiscordWebhookURLTests {
    @Test(
        "Discord の Webhook URL の形なら作れる",
        arguments: [
            "https://discord.com/api/webhooks/123/abc_DEF-9",
            "https://discordapp.com/api/webhooks/123/abc",
            "https://ptb.discord.com/api/webhooks/123/abc",
            "https://canary.discord.com/api/webhooks/123/abc",
            "https://discord.com/api/v10/webhooks/123/abc",
            "https://discord.com/api/webhooks/123/abc/",
            " https://discord.com/api/webhooks/123/abc \n"
        ]
    )
    func valid(string: String) {
        #expect(DiscordWebhookURL(string: string) != nil)
    }

    @Test(
        "空・https でない・Discord でない・パスの形が違うものは作れない",
        arguments: [
            "",
            "   ",
            "http://discord.com/api/webhooks/123/abc",
            "discord.com/api/webhooks/123/abc",
            "https://example.com/api/webhooks/123/abc",
            "https://discord.com.example.com/api/webhooks/123/abc",
            "https://discord.com/api/webhooks/abc/abc",
            "https://discord.com/api/webhooks/123",
            "https://discord.com/api/webhooks/123/abc/extra",
            "https://discord.com/channels/123/456"
        ]
    )
    func invalid(string: String) {
        #expect(DiscordWebhookURL(string: string) == nil)
    }

    @Test("取得に使う URL からはクエリを除く")
    func dropsQuery() {
        let webhookURL = DiscordWebhookURL(string: "https://discord.com/api/webhooks/123/abc?thread_id=456&wait=true")
        #expect(webhookURL?.url == URL(string: "https://discord.com/api/webhooks/123/abc"))
    }

    @Test("アイコンの URL は CDN の avatars に png で組み立てる。アニメーションのハッシュも png")
    func avatarURL() {
        #expect(
            WebhookProfileClient.avatarURL(webhookID: "123", avatarHash: "abc")
                == URL(string: "https://cdn.discordapp.com/avatars/123/abc.png?size=128")
        )
        #expect(
            WebhookProfileClient.avatarURL(webhookID: "123", avatarHash: "a_abc")
                == URL(string: "https://cdn.discordapp.com/avatars/123/a_abc.png?size=128")
        )
    }
}

private extension Result {
    var successValue: Success? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    var failureValue: Failure? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
