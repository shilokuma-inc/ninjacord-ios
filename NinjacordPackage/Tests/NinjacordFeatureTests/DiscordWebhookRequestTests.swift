//
//  DiscordWebhookRequestTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// Discord の Webhook に送る中身（`DiscordWebhookRequest`）の今の出力を固定する。
/// 送信の通信を URLSession に置き換えても（Discussion #459）、送る中身が変わらないことを確かめる
struct DiscordWebhookRequestTests {
    /// 2024-04-28T12:34:56Z
    private static let sentAt = Date(timeIntervalSince1970: 1_714_307_696)

    private func request(
        _ message: MessageEntity,
        attachment: ImageAttachment? = nil
    ) -> DiscordWebhookRequest {
        DiscordWebhookRequest(messageEntity: message, attachment: attachment, sentAt: Self.sentAt)
    }

    // MARK: - 名前・アイコン・本文

    @Test("名前・アイコン URL・本文はそのまま送る")
    func messageParameters() {
        let message = MessageEntity.make(
            username: "レイド告知Bot",
            avatarURL: "https://example.com/avatar.png",
            content: "今夜21:00 レイド開始"
        )
        #expect(request(message).parameters.dictionary == [
            "username": "レイド告知Bot",
            "avatar_url": "https://example.com/avatar.png",
            "content": "今夜21:00 レイド開始"
        ])
    }

    /// 既定の文言はローカライズされていない（今の挙動。Discussion #459 の Q4 の 1）
    @Test("名前が空なら「以下、名無しにかわりましてVIPがお送りします」、本文が空なら「なんか書いてね」を送る")
    func defaultUsernameAndContent() {
        #expect(request(.make()).parameters.dictionary == [
            "username": "以下、名無しにかわりましてVIPがお送りします",
            "avatar_url": "",
            "content": "なんか書いてね"
        ])
    }

    @Test("空白だけの名前・本文は空とみなさず、そのまま送る")
    func whitespaceUsernameAndContent() {
        let parameters = request(.make(username: " ", content: "\n")).parameters
        #expect(parameters["username"] as? String == " ")
        #expect(parameters["content"] as? String == "\n")
    }

    @Test("埋め込みだけを送るときも、本文には「なんか書いてね」が入る")
    func defaultContentWithEmbedOnly() {
        let parameters = request(.make(embed: MessageEmbedEntity(title: "お知らせ"))).parameters
        #expect(parameters["content"] as? String == "なんか書いてね")
        #expect(parameters.dictionary["embeds"] as? NSArray == [["title": "お知らせ"]])
    }

    // MARK: - 埋め込み

    @Test("埋め込みに内容が無ければ embeds を送らない")
    func noEmbedsWithoutContent() {
        #expect(request(.make(content: "本文")).parameters["embeds"] == nil)
        // 色と送信日時だけでは内容とみなさない
        let embed = MessageEmbedEntity(color: 0x5865F2, includesTimestamp: true)
        #expect(request(.make(content: "本文", embed: embed)).parameters["embeds"] == nil)
    }

    @Test("埋め込みの各項目を Discord の embed オブジェクトの形で送る")
    func embedParameters() {
        let embed = MessageEmbedEntity(
            title: "今夜のレイド",
            description: "参加者募集中",
            color: 0x5865F2,
            fields: [
                MessageEmbedField(name: "集合", value: "20:50", isInline: true),
                MessageEmbedField(name: "持ち物", value: "回復薬", isInline: false)
            ],
            footerText: "Ninjacord",
            imageURL: "https://example.com/image.png",
            thumbnailURL: "https://example.com/thumbnail.png",
            includesTimestamp: true
        )
        #expect(embedParameters(of: embed) == [
            "title": "今夜のレイド",
            "description": "参加者募集中",
            "color": 0x5865F2,
            "fields": [
                ["name": "集合", "value": "20:50", "inline": true],
                ["name": "持ち物", "value": "回復薬", "inline": false]
            ],
            "footer": ["text": "Ninjacord"],
            "image": ["url": "https://example.com/image.png"],
            "thumbnail": ["url": "https://example.com/thumbnail.png"],
            "timestamp": "2024-04-28T12:34:56Z"
        ])
    }

    @Test("埋め込みの空の項目は送らない")
    func emptyEmbedItemsAreNotSent() {
        #expect(embedParameters(of: MessageEmbedEntity(title: "お知らせ")) == ["title": "お知らせ"])
        #expect(embedParameters(of: MessageEmbedEntity(description: "本文")) == ["description": "本文"])
        #expect(
            embedParameters(of: MessageEmbedEntity(footerText: "フッター")) == ["footer": ["text": "フッター"]]
        )
    }

    @Test("色は 0 でも送る")
    func zeroColorIsSent() {
        #expect(embedParameters(of: MessageEmbedEntity(title: "お知らせ", color: 0)) == ["title": "お知らせ", "color": 0])
    }

    @Test("名前と値がどちらも空のフィールド行は送らない")
    func blankFieldRowsAreNotSent() {
        let embed = MessageEmbedEntity(
            fields: [
                MessageEmbedField(name: "", value: "", isInline: false),
                MessageEmbedField(name: "集合", value: "", isInline: true)
            ]
        )
        #expect(embedParameters(of: embed) == ["fields": [["name": "集合", "value": "", "inline": true]]])
    }

    /// 空のフィールド行だけでも embed を送る（今の挙動。#461）
    @Test("空のフィールド行だけなら、中身の無い embed を送る")
    func blankFieldRowOnly() {
        let embed = MessageEmbedEntity(fields: [MessageEmbedField(name: "", value: "", isInline: false)])
        #expect(embedParameters(of: embed) == [:])
    }

    @Test("送信日時は ISO 8601（UTC、秒まで）で送り、送らない設定なら timestamp を付けない")
    func timestamp() {
        let embed = MessageEmbedEntity(title: "お知らせ", includesTimestamp: true)
        #expect(embedParameters(of: embed)?["timestamp"] as? String == "2024-04-28T12:34:56Z")

        let withoutTimestamp = MessageEmbedEntity(title: "お知らせ", includesTimestamp: false)
        #expect(embedParameters(of: withoutTimestamp)?["timestamp"] == nil)
    }

    // MARK: - JSON の本文

    @Test("JSON の本文は、パラメータを prettyPrinted で書き出したもの")
    func jsonBody() throws {
        let message = MessageEntity.make(
            username: "レイド告知Bot",
            content: "今夜21:00 レイド開始",
            embed: MessageEmbedEntity(title: "お知らせ", includesTimestamp: true)
        )
        let webhookRequest = request(message)
        let body = webhookRequest.jsonBody

        let decoded = try #require(try JSONSerialization.jsonObject(with: body) as? NSDictionary)
        #expect(decoded == webhookRequest.parameters.dictionary)
        // prettyPrinted なので改行とインデントが入る
        let text = try #require(String(data: body, encoding: .utf8))
        #expect(text.hasPrefix("{\n  \""))
    }

    // MARK: - multipart/form-data

    @Test("添付する画像が無ければ multipart で送らない")
    func noMultipartWithoutAttachment() {
        #expect(request(.make(content: "本文")).multipartParts == nil)
    }

    @Test("画像を添付するときは、payload_json と files[0] の 2 パートで送る")
    func multipartParts() throws {
        let attachment = ImageAttachment(data: Data([0xFF, 0xD8, 0xFF]), fileName: "image.jpg", mimeType: "image/jpeg")
        let message = MessageEntity.make(content: "スクリーンショット", embed: MessageEmbedEntity(title: "お知らせ"))
        let webhookRequest = request(message, attachment: attachment)
        let parts = try #require(webhookRequest.multipartParts)
        try #require(parts.count == 2)

        let payload = parts[0]
        #expect(payload.name == "payload_json")
        #expect(payload.fileName == nil)
        #expect(payload.mimeType == "application/json")
        let decoded = try #require(try JSONSerialization.jsonObject(with: payload.data) as? NSDictionary)
        #expect(decoded == webhookRequest.parameters.dictionary)
        // payload_json は prettyPrinted にしない
        #expect(!payload.data.contains(UInt8(ascii: "\n")))

        #expect(parts[1] == DiscordWebhookRequest.MultipartPart(
            name: "files[0]",
            data: Data([0xFF, 0xD8, 0xFF]),
            fileName: "image.jpg",
            mimeType: "image/jpeg"
        ))
    }

    /// 埋め込みだけを送るメッセージを組み立て、embeds の 1 件目を返す。embeds が無ければ nil
    private func embedParameters(of embed: MessageEmbedEntity) -> NSDictionary? {
        let embeds = request(.make(content: "本文", embed: embed)).parameters["embeds"] as? [[String: Any]]
        return embeds?.first.map { NSDictionary(dictionary: $0) }
    }
}

private extension Dictionary where Key == String, Value == Any {
    /// 中身どうしを比べるための NSDictionary（[String: Any] は Equatable ではないため）
    var dictionary: NSDictionary {
        NSDictionary(dictionary: self)
    }
}

private extension MessageEntity {
    static func make(
        username: String = "",
        avatarURL: String = "",
        content: String = "",
        embed: MessageEmbedEntity = MessageEmbedEntity()
    ) -> MessageEntity {
        MessageEntity(username: username, avatarURL: avatarURL, content: content, messageEmbedEntity: embed)
    }
}
