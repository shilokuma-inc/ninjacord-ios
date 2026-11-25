//
//  ForumPostRequestTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// フォーラム・メディアチャンネルへの新しい投稿（Issue #699）のうち、送る中身・エラーの見分け・
/// 作られたスレッドの ID を使った編集・削除の URL・保存したデータの読み込み
struct ForumPostRequestTests {
    private static let message = MessageEntity(
        username: "",
        avatarURL: "",
        content: "今週の進捗です",
        messageEmbedEntity: MessageEmbedEntity(),
        threadName: "週報 11/25"
    )

    // MARK: - thread_name

    @Test("フォーラムに新しい投稿として送るときは、タイトルを thread_name で送る")
    func sendsThreadNameToForum() {
        let request = DiscordWebhookRequest(messageEntity: Self.message, createsForumPost: true)
        #expect(request.parameters["thread_name"] as? String == "週報 11/25")
        #expect(request.parameters["content"] as? String == "今週の進捗です")
    }

    @Test("フォーラムでない宛先には、タイトルが入っていても thread_name を送らない")
    func omitsThreadNameForNonForum() {
        let request = DiscordWebhookRequest(messageEntity: Self.message)
        #expect(request.threadName == nil)
        #expect(request.parameters["thread_name"] == nil)
    }

    @Test("タイトルは前後の空白を除いて送り、空白だけなら送らない")
    func trimsThreadName() {
        var message = Self.message
        message.threadName = "  週報\n"
        #expect(DiscordWebhookRequest(messageEntity: message, createsForumPost: true).threadName == "週報")

        message.threadName = " \n "
        let blank = DiscordWebhookRequest(messageEntity: message, createsForumPost: true)
        #expect(blank.threadName == nil)
        #expect(blank.parameters["thread_name"] == nil)
    }

    @Test("画像を添付するときも、payload_json に thread_name を入れる")
    func multipartIncludesThreadName() throws {
        let attachment = ImageAttachment(data: Data([0xFF, 0xD8, 0xFF]), fileName: "image.jpg", mimeType: "image/jpeg")
        let request = DiscordWebhookRequest(messageEntity: Self.message, attachment: attachment, createsForumPost: true)
        let payload = try #require(request.multipartParts?.first { $0.name == "payload_json" })
        let decoded = try #require(try JSONSerialization.jsonObject(with: payload.data) as? [String: Any])
        #expect(decoded["thread_name"] as? String == "週報 11/25")
    }

    @Test("送ったメッセージの編集では、タイトル（投稿の名前）は変えられないので送らない")
    func editOmitsThreadName() {
        let request = DiscordWebhookRequest(messageEntity: Self.message, createsForumPost: true)
        #expect(request.editParameters["thread_name"] == nil)
    }

    // MARK: - エラーの見分け

    @Test(
        "フォーラムにタイトルを付けずに送った（220001）・フォーラムでない宛先にタイトルを付けた（220003）を見分ける",
        arguments: [
            (#"{"message": "Webhooks posted to forum channels must have a thread_name or thread_id", "code": 220001}"#,
             DiscordWebhookError.forumTitleRequired),
            (#"{"message": "Webhooks can only create threads in forum channels", "code": 220003}"#, .notForumChannel),
            (#"{"message": "Invalid Form Body", "code": 50035}"#, .invalidMessage)
        ]
    )
    func forumErrors(body: String, expected: DiscordWebhookError) {
        #expect(DiscordWebhookError(statusCode: 400, data: Data(body.utf8)) == expected)
    }

    @Test("フォーラムのエラーは、原因と次にすることが分かる文言にする")
    func forumErrorDescriptions() throws {
        let required = try #require(DiscordWebhookError.forumTitleRequired.errorDescription)
        let notForum = try #require(DiscordWebhookError.notForumChannel.errorDescription)
        #expect(required != DiscordWebhookError.invalidMessage.errorDescription)
        #expect(notForum != DiscordWebhookError.invalidMessage.errorDescription)
        #expect(required != notForum)
    }

    // MARK: - 作られたスレッドの ID

    /// テストごとに別の URL に送り、受け取ったメッセージを返す
    private func send(_ request: DiscordWebhookRequest, returning body: String) async -> SentWebhookMessage? {
        let url = StubURLProtocol.makeURL(returning: .response(statusCode: 200, data: Data(body.utf8)))
        let client = DiscordWebhookClient(session: StubURLProtocol.session)
        return await client.send(request, to: url).result.successValue
    }

    @Test("新しい投稿として送ったら、レスポンスの channel_id（作られたスレッド）を受け取る")
    func receivesCreatedThreadID() async {
        let sent = await send(
            DiscordWebhookRequest(messageEntity: Self.message, createsForumPost: true),
            returning: #"{"id": "789", "channel_id": "456"}"#
        )
        #expect(sent == SentWebhookMessage(id: "789", threadID: "456"))
    }

    @Test("新しい投稿でなければ、channel_id は宛先のチャンネルなので受け取らない")
    func ignoresChannelIDForNonForum() async {
        let sent = await send(
            DiscordWebhookRequest(messageEntity: Self.message),
            returning: #"{"id": "789", "channel_id": "42"}"#
        )
        #expect(sent == SentWebhookMessage(id: "789", threadID: nil))
    }

    @Test("作られたスレッドの ID があれば、編集・削除の URL に thread_id として付ける")
    func messageURLWithCreatedThread() {
        #expect(
            WebhookMessageEndpoint.messageURL(
                webhookURL: "https://discord.com/api/webhooks/123/abc?wait=true",
                messageID: "789",
                threadID: "456"
            ) == URL(string: "https://discord.com/api/webhooks/123/abc/messages/789?thread_id=456")
        )
        // 覚えていない（今までに送った）メッセージは今までどおり
        #expect(
            WebhookMessageEndpoint.messageURL(webhookURL: "https://discord.com/api/webhooks/123/abc", messageID: "789")
                == URL(string: "https://discord.com/api/webhooks/123/abc/messages/789")
        )
    }

    @Test("スレッドの ID が数字でなければ URL を作らない")
    func messageURLRejectsInvalidThreadID() {
        #expect(
            WebhookMessageEndpoint.messageURL(
                webhookURL: "https://discord.com/api/webhooks/123/abc",
                messageID: "789",
                threadID: "456&wait=false"
            ) == nil
        )
    }

    @Test("新しい投稿のメッセージは、作られたスレッドの thread_id を付けて削除・編集する")
    func editorUsesCreatedThread() async throws {
        let base = "https://discord.com/api/webhooks/\(UUID().uuidString)/token"
        let messageURL = try #require(URL(string: "\(base)/messages/789"))
        StubURLProtocol.stub(messageURL, returning: .response(statusCode: 204, data: Data()))
        let client = DiscordWebhookClient(session: StubURLProtocol.session)
        let editor = WebhookMessageEditor(client: client, analytics: AnalyticsSpy())

        _ = await editor.delete(webhookURL: base, messageID: "789", threadID: "456", source: .postedList)
        _ = await editor.edit(
            webhookURL: base,
            messageID: "789",
            threadID: "456",
            message: Self.message,
            sentAt: Date()
        )

        let requests = StubURLProtocol.requests(to: messageURL)
        #expect(requests.map(\.request.httpMethod) == ["DELETE", "PATCH"])
        #expect(requests.map(\.request.url?.query) == ["thread_id=456", "thread_id=456"])
    }

    // MARK: - 保存したデータの読み込み

    @Test("タイトルを足す前（2.5.0 まで）に保存したメッセージは、タイトルを空として読む")
    func decodeLegacyMessage() throws {
        let legacy = """
        {"username": "", "avatarURL": "", "content": "こんにちは",
         "messageEmbedEntity": {"title": "", "description": "", "fields": [], "footerText": "",
                                "imageURL": "", "thumbnailURL": "", "includesTimestamp": false}}
        """
        let message = try JSONDecoder().decode(MessageEntity.self, from: Data(legacy.utf8))
        #expect(message.content == "こんにちは")
        #expect(message.threadName == "")
    }

    @Test("作られたスレッドの ID を覚える前（2.5.0 まで）の送信履歴は、今までどおり thread_id を付けずに編集・削除する")
    func decodeLegacyHistoryEntry() throws {
        let legacy = """
        {"id": "8D3C5E2A-1B4F-4C6D-9E7A-2F1B3C4D5E6F", "sentAt": 780000000,
         "url": "https://discord.com/api/webhooks/123/abc", "isSuccess": true, "messageID": "789",
         "message": {"username": "", "avatarURL": "", "content": "こんにちは",
                     "messageEmbedEntity": {"title": "", "description": "", "fields": [], "footerText": "",
                                            "imageURL": "", "thumbnailURL": "", "includesTimestamp": false}}}
        """
        let entry = try JSONDecoder().decode(SendHistoryEntry.self, from: Data(legacy.utf8))
        #expect(entry.messageID == "789")
        #expect(entry.threadID == nil)
        #expect(entry.message.threadName == "")
        #expect(entry.isPosted)
    }

    @Test("タイトルも書き出して、読み直せる")
    func roundTripThreadName() throws {
        let data = try JSONEncoder().encode(Self.message)
        #expect(try JSONDecoder().decode(MessageEntity.self, from: data) == Self.message)
    }
}
