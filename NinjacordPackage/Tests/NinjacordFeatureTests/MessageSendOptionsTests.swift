//
//  MessageSendOptionsTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信オプション（`MessageSendOptions`）を Discord に送るパラメータと、テンプレート・送信履歴での保存（Issue #698）
struct MessageSendOptionsTests {
    /// 2024-04-28T12:34:56Z
    private static let sentAt = Date(timeIntervalSince1970: 1_714_307_696)
    private static let attachment = ImageAttachment(
        data: Data([0xFF, 0xD8, 0xFF]),
        fileName: "image.jpg",
        mimeType: "image/jpeg"
    )

    private func request(
        _ options: MessageSendOptions,
        content: String = "今夜21:00 レイド開始",
        attachment: ImageAttachment? = nil
    ) -> DiscordWebhookRequest {
        let message = MessageEntity(
            username: "レイド告知Bot",
            avatarURL: "https://example.com/avatar.png",
            content: content,
            messageEmbedEntity: MessageEmbedEntity(),
            sendOptions: options
        )
        return DiscordWebhookRequest(messageEntity: message, attachment: attachment, sentAt: Self.sentAt)
    }

    // MARK: - 送るパラメータ

    @Test("フラグの値は Discord の SUPPRESS_EMBEDS（1 << 2）と SUPPRESS_NOTIFICATIONS（1 << 12）")
    func messageFlagValues() {
        #expect(MessageSendOptions.MessageFlag.suppressEmbeds == 4)
        #expect(MessageSendOptions.MessageFlag.suppressNotifications == 4096)
    }

    @Test("すべてオフなら flags・allowed_mentions を送らず、今までと同じ JSON にする")
    func allOffSendsSameJSON() throws {
        let webhookRequest = request(MessageSendOptions())
        #expect(webhookRequest.parameters.dictionary == [
            "username": "レイド告知Bot",
            "avatar_url": "https://example.com/avatar.png",
            "content": "今夜21:00 レイド開始"
        ])
        let body = try #require(webhookRequest.jsonBody)
        let text = try #require(String(data: body, encoding: .utf8))
        #expect(!text.contains("flags"))
        #expect(!text.contains("allowed_mentions"))
    }

    @Test("通知を鳴らさないなら、flags に SUPPRESS_NOTIFICATIONS だけを立てる")
    func suppressNotifications() {
        let parameters = request(MessageSendOptions(suppressesNotifications: true)).parameters
        #expect(parameters["flags"] as? Int == 1 << 12)
        #expect(parameters["allowed_mentions"] == nil)
    }

    @Test("リンクのプレビューを出さないなら、flags に SUPPRESS_EMBEDS だけを立てる")
    func suppressEmbeds() {
        let parameters = request(MessageSendOptions(suppressesEmbeds: true)).parameters
        #expect(parameters["flags"] as? Int == 1 << 2)
        #expect(parameters["allowed_mentions"] == nil)
    }

    @Test("@everyone・@here で通知しないなら、allowed_mentions でユーザーとロールだけを通知し、flags は送らない")
    func suppressEveryoneMentions() {
        let parameters = request(MessageSendOptions(suppressesEveryoneMentions: true)).parameters
        #expect(parameters["flags"] == nil)
        #expect(parameters.dictionary["allowed_mentions"] as? NSDictionary == ["parse": ["users", "roles"]])
    }

    @Test("すべてオンなら、2 つのフラグを合わせて立て、allowed_mentions も送る")
    func allOn() {
        let options = MessageSendOptions(
            suppressesNotifications: true,
            suppressesEmbeds: true,
            suppressesEveryoneMentions: true
        )
        #expect(request(options).parameters.dictionary == [
            "username": "レイド告知Bot",
            "avatar_url": "https://example.com/avatar.png",
            "content": "今夜21:00 レイド開始",
            "flags": (1 << 12) | (1 << 2),
            "allowed_mentions": ["parse": ["users", "roles"]]
        ])
    }

    @Test("画像を添付するときは、payload_json に flags・allowed_mentions を入れる")
    func multipartPayloadIncludesOptions() throws {
        let options = MessageSendOptions(suppressesNotifications: true, suppressesEveryoneMentions: true)
        let parts = try #require(request(options, attachment: Self.attachment).multipartParts)
        let payload = try #require(try JSONSerialization.jsonObject(with: parts[0].data) as? NSDictionary)
        #expect(payload["flags"] as? Int == 1 << 12)
        #expect(payload["allowed_mentions"] as? NSDictionary == ["parse": ["users", "roles"]])
    }

    @Test("画像を添付するときも、すべてオフなら payload_json は今までと同じ")
    func multipartPayloadWithoutOptions() throws {
        let parts = try #require(request(MessageSendOptions(), attachment: Self.attachment).multipartParts)
        let payload = try #require(try JSONSerialization.jsonObject(with: parts[0].data) as? NSDictionary)
        #expect(payload == [
            "username": "レイド告知Bot",
            "avatar_url": "https://example.com/avatar.png",
            "content": "今夜21:00 レイド開始"
        ])
    }

    // MARK: - 送ったメッセージの編集

    @Test("編集では、リンクのプレビューを出さないときだけ flags に SUPPRESS_EMBEDS を送る（通知のフラグは送らない）")
    func editFlags() {
        let suppressed = request(MessageSendOptions(suppressesNotifications: true, suppressesEmbeds: true))
        #expect(suppressed.editParameters["flags"] as? Int == 1 << 2)

        let silentOnly = request(MessageSendOptions(suppressesNotifications: true))
        #expect(silentOnly.editParameters["flags"] == nil)
    }

    @Test("編集でも、@everyone・@here で通知しないなら allowed_mentions を送る")
    func editAllowedMentions() {
        let parameters = request(MessageSendOptions(suppressesEveryoneMentions: true)).editParameters
        #expect(parameters.dictionary["allowed_mentions"] as? NSDictionary == ["parse": ["users", "roles"]])
        #expect(parameters["flags"] == nil)
    }

    @Test("編集でも、すべてオフなら本文と埋め込みだけを送る（今までの編集と同じ）")
    func editWithoutOptions() {
        #expect(request(MessageSendOptions(), content: "本文").editParameters.dictionary == [
            "content": "本文",
            "embeds": [Any]()
        ])
    }

    // MARK: - テンプレート・送信履歴での保存

    @Test("送信オプションを追加する前に保存したメッセージは、すべてオフで読み込む")
    func decodeLegacyMessage() throws {
        let legacy = """
        {
          "username": "忍者", "avatarURL": "", "content": "こんにちは",
          "messageEmbedEntity": {"title": "お知らせ"}
        }
        """
        let message = try JSONDecoder().decode(MessageEntity.self, from: Data(legacy.utf8))
        #expect(message.content == "こんにちは")
        #expect(message.messageEmbedEntity.title == "お知らせ")
        #expect(message.sendOptions == MessageSendOptions())
    }

    @Test("送信オプションを追加する前に保存したテンプレートも、すべてオフで読み込む")
    func decodeLegacyTemplate() throws {
        let legacy = """
        [{
          "id": "8D3C5E2A-1B4F-4C6D-9E7A-2F1B3C4D5E6F",
          "name": "定型",
          "createdAt": 780000000,
          "message": {
            "username": "", "avatarURL": "", "content": "こんにちは",
            "messageEmbedEntity": {"title": "", "description": "", "fields": [], "footerText": "",
                                   "imageURL": "", "thumbnailURL": "", "includesTimestamp": false}
          }
        }]
        """
        let templates = try JSONDecoder().decode([MessageTemplate].self, from: Data(legacy.utf8))
        let template = try #require(templates.first)
        #expect(template.message.content == "こんにちは")
        #expect(template.message.sendOptions == MessageSendOptions())
    }

    @Test("オンにした送信オプションは、保存して読み直しても残る")
    func roundTrip() throws {
        let message = MessageEntity(
            username: "忍者",
            avatarURL: "",
            content: "こんにちは",
            messageEmbedEntity: MessageEmbedEntity(),
            sendOptions: MessageSendOptions(suppressesNotifications: true, suppressesEveryoneMentions: true)
        )
        let template = MessageTemplate(id: UUID(), name: "定型", message: message, createdAt: Self.sentAt)

        let data = try JSONEncoder().encode([template])
        let decoded = try JSONDecoder().decode([MessageTemplate].self, from: data)

        #expect(decoded == [template])
    }

    @Test("項目が足りない送信オプションは、無い項目をオフで読み込む")
    func decodePartialOptions() throws {
        let options = try JSONDecoder().decode(MessageSendOptions.self, from: Data(#"{"suppressesEmbeds": true}"#.utf8))
        #expect(options == MessageSendOptions(suppressesEmbeds: true))
    }

    // MARK: - 閉じているときの要約

    /// テストでは `String(localized:)` が常にキーを返すので、文言は直書きせずに `String(localized:)` と比べる
    @Test("すべてオフなら、そのことを要約に出す")
    func summaryAllOff() {
        #expect(MessageSendOptions().summary == String(localized: "すべてオフ"))
    }

    @Test("オンにしたものだけを要約に並べる")
    func summaryLists() {
        #expect(MessageSendOptions(suppressesEmbeds: true).summary == String(localized: "リンクのプレビューを出さない"))

        let summary = MessageSendOptions(suppressesNotifications: true, suppressesEveryoneMentions: true).summary
        #expect(summary.contains(String(localized: "通知を鳴らさない")))
        #expect(summary.contains(String(localized: "@everyone・@hereで通知しない")))
        #expect(!summary.contains(String(localized: "リンクのプレビューを出さない")))
    }
}

private extension Dictionary where Key == String, Value == Any {
    /// 中身どうしを比べるための NSDictionary（[String: Any] は Equatable ではないため）
    var dictionary: NSDictionary {
        NSDictionary(dictionary: self)
    }
}
