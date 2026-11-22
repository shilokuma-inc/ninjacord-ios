//
//  WebhookMessageEditorTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送ったメッセージの編集・削除（`WebhookMessageEditor`）。送信履歴の URL と ID から URL を作り、結果を Analytics に残す
struct WebhookMessageEditorTests {
    private let analytics = AnalyticsSpy()

    private var editor: WebhookMessageEditor {
        WebhookMessageEditor(client: DiscordWebhookClient(session: StubURLProtocol.session), analytics: analytics)
    }

    private static let message = MessageEntity(
        username: "",
        avatarURL: "",
        content: "今夜21:30 レイド開始（変更）",
        messageEmbedEntity: MessageEmbedEntity()
    )

    /// テストごとに別の Webhook URL と、その URL で送ったメッセージ（ID は 789）の URL を作り、メッセージの URL への応答を決める
    private func webhook(returning stub: StubURLProtocol.Stub, query: String = "") -> (url: String, messageURL: URL) {
        let base = "https://discord.com/api/webhooks/\(UUID().uuidString)/token"
        let messageURL = URL(string: "\(base)/messages/789")!
        StubURLProtocol.stub(messageURL, returning: stub)
        return (base + query, messageURL)
    }

    // MARK: - 削除

    @Test("削除に成功したら成功を返し、削除した場所と一緒に Analytics に残す")
    func deleteSucceeded() async {
        let (url, messageURL) = webhook(returning: .response(statusCode: 204, data: Data()))

        let result = await editor.delete(webhookURL: url, messageID: "789", source: .postedList)

        #expect(result.isSuccess)
        #expect(StubURLProtocol.requests(to: messageURL).map(\.request.httpMethod) == ["DELETE"])
        #expect(analytics.deleteEvents == [.init(isSuccess: true, httpStatus: 204, source: "posted_list")])
    }

    @Test("Discord で先に消されていた（10008）ときも成功にする。Analytics には失敗のまま残す")
    func deleteAlreadyDeleted() async {
        let body = Data(#"{"message": "Unknown Message", "code": 10008}"#.utf8)
        let (url, _) = webhook(returning: .response(statusCode: 404, data: body))

        let result = await editor.delete(webhookURL: url, messageID: "789", source: .toast)

        #expect(result.isSuccess)
        #expect(analytics.deleteEvents == [.init(isSuccess: false, httpStatus: 404, source: "toast")])
    }

    @Test("Webhook が消されていたら失敗を返す")
    func deleteUnknownWebhook() async {
        let body = Data(#"{"message": "Unknown Webhook", "code": 10015}"#.utf8)
        let (url, _) = webhook(returning: .response(statusCode: 404, data: body))

        let result = await editor.delete(webhookURL: url, messageID: "789", source: .postedList)

        #expect(result.failureValue == .unknownWebhook)
    }

    @Test("スレッドに送ったメッセージは、同じ thread_id を付けて削除する")
    func deleteInThread() async throws {
        let (url, messageURL) = webhook(returning: .response(statusCode: 204, data: Data()), query: "?thread_id=456")

        _ = await editor.delete(webhookURL: url, messageID: "789", source: .postedList)

        let received = try #require(StubURLProtocol.requests(to: messageURL).first)
        #expect(received.request.url?.query == "thread_id=456")
    }

    // MARK: - 編集

    @Test("編集に成功したら成功を返し、Analytics に残す")
    func editSucceeded() async throws {
        let (url, messageURL) = webhook(returning: .response(statusCode: 200, data: Data(#"{"id": "789"}"#.utf8)))

        let result = await editor.edit(webhookURL: url, messageID: "789", message: Self.message, sentAt: Date())

        #expect(result.isSuccess)
        let received = try #require(StubURLProtocol.requests(to: messageURL).first)
        #expect(received.request.httpMethod == "PATCH")
        #expect(analytics.editEvents == [.init(isSuccess: true, httpStatus: 200)])
    }

    @Test("編集で、メッセージが Discord で消されていたら unknownMessage を返す")
    func editAlreadyDeleted() async {
        let body = Data(#"{"message": "Unknown Message", "code": 10008}"#.utf8)
        let (url, _) = webhook(returning: .response(statusCode: 404, data: body))

        let result = await editor.edit(webhookURL: url, messageID: "789", message: Self.message, sentAt: Date())

        #expect(result.failureValue == .unknownMessage)
        #expect(analytics.editEvents == [.init(isSuccess: false, httpStatus: 404)])
    }

    @Test("URL を作れなければ通信せずに失敗にする")
    func invalidMessageID() async {
        let result = await editor.delete(
            webhookURL: "https://discord.com/api/webhooks/1/token",
            messageID: "not-a-snowflake",
            source: .postedList
        )

        #expect(result.failureValue == .invalidToken)
        #expect(analytics.deleteEvents.isEmpty)
    }
}
