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

    /// 本文の既定の文言はローカライズされていない（Discussion #459 の Q4 の 1）。
    /// 名前は空なら送らず、Discord 側で Webhook の名前で出す（Discussion #586 の Q7）
    @Test("名前が空なら username を送らず、本文が空なら「なんか書いてね」を送る")
    func omittedUsernameAndDefaultContent() {
        #expect(request(.make()).parameters.dictionary == [
            "avatar_url": "",
            "content": "なんか書いてね"
        ])
        #expect(request(.make(content: "こんにちは")).parameters["username"] == nil)
    }

    @Test("空白だけの名前・本文は空とみなさず、そのまま送る")
    func whitespaceUsernameAndContent() {
        let parameters = request(.make(username: " ", content: "\n")).parameters
        #expect(parameters["username"] as? String == " ")
        #expect(parameters["content"] as? String == "\n")
    }

    @Test("本文が空でも、埋め込みがあれば本文を送らない")
    func noContentWithEmbedOnly() {
        let parameters = request(.make(embed: MessageEmbedEntity(title: "お知らせ"))).parameters
        #expect(parameters["content"] == nil)
        #expect(parameters.dictionary["embeds"] as? NSArray == [["title": "お知らせ"]])
    }

    @Test(
        "本文が空でも、埋め込みに表示される中身があれば本文を送らない",
        arguments: [
            MessageEmbedEntity(description: "説明"),
            MessageEmbedEntity(fields: [MessageEmbedField(name: "集合", value: "", isInline: false)]),
            MessageEmbedEntity(footerText: "フッター"),
            MessageEmbedEntity(imageURL: "https://example.com/image.png"),
            MessageEmbedEntity(thumbnailURL: "https://example.com/thumbnail.png")
        ]
    )
    func noContentWithDisplayedEmbed(embed: MessageEmbedEntity) {
        #expect(request(.make(embed: embed)).parameters["content"] == nil)
    }

    @Test(
        "埋め込みに表示される中身が無ければ、本文には「なんか書いてね」が入る",
        arguments: [
            MessageEmbedEntity(title: " "),
            MessageEmbedEntity(color: 0x5865F2),
            MessageEmbedEntity(includesTimestamp: true)
        ]
    )
    func defaultContentWithoutDisplayedEmbed(embed: MessageEmbedEntity) {
        #expect(request(.make(embed: embed)).parameters["content"] as? String == "なんか書いてね")
    }

    @Test("本文が空でも、画像を添付すれば本文を送らない")
    func noContentWithAttachmentOnly() {
        #expect(request(.make(), attachment: .sample).parameters["content"] == nil)
    }

    /// 中身の無い embed だけでは Discord に何も表示されないので、本文を省かない
    @Test("空のフィールド行だけの埋め込みなら、本文には「なんか書いてね」が入る")
    func defaultContentWithBlankFieldRowOnly() {
        let embed = MessageEmbedEntity(fields: [MessageEmbedField(name: "", value: "", isInline: false)])
        #expect(request(.make(embed: embed)).parameters["content"] as? String == "なんか書いてね")
    }

    // MARK: - 初期文言に置き換える項目

    @Test("名前・本文が空なら、本文だけを初期文言に置き換える")
    func defaultedContentOnly() {
        #expect(request(.make()).defaultedFields == [.content])
        #expect(DiscordWebhookRequest.DefaultedField.content.value == "なんか書いてね")
    }

    @Test("名前・本文が入っていれば、初期文言に置き換えない")
    func noDefaultedFields() {
        #expect(request(.make(username: "忍者", content: "こんにちは")).defaultedFields.isEmpty)
        // 名前が空でも置き換えない
        #expect(request(.make(content: "こんにちは")).defaultedFields.isEmpty)
        // 空白だけでも入力とみなす
        #expect(request(.make(username: " ", content: "\n")).defaultedFields.isEmpty)
        // プロフィール画像の URL が空でも置き換えない
        #expect(request(.make(username: "忍者", avatarURL: "", content: "こんにちは")).defaultedFields.isEmpty)
    }

    @Test("本文が空でも、埋め込みか画像があれば本文は置き換えない")
    func contentIsNotDefaultedWithEmbedOrAttachment() {
        let embed = MessageEmbedEntity(title: "お知らせ")
        #expect(request(.make(embed: embed)).defaultedFields.isEmpty)
        #expect(request(.make(username: "忍者", embed: embed)).defaultedFields.isEmpty)
        #expect(request(.make(username: "忍者"), attachment: .sample).defaultedFields.isEmpty)
        #expect(request(.make(), attachment: .sample).defaultedFields.isEmpty)
    }

    /// プレビューは、これで本文の場所を出すかを決める
    @Test("本文の場所を送るかは、本文があるか初期文言に置き換えるときだけ")
    func sendsContent() {
        #expect(request(.make(content: "こんにちは")).sendsContent)
        #expect(request(.make()).sendsContent)
        #expect(!request(.make(embed: MessageEmbedEntity(title: "お知らせ"))).sendsContent)
        #expect(!request(.make(), attachment: .sample).sendsContent)
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

    @Test("添付する画像が無ければ multipart の本文を作らない")
    func noMultipartBodyWithoutAttachment() {
        #expect(request(.make(content: "本文")).multipartBody(boundary: "BOUNDARY") == nil)
    }

    @Test("multipart の本文は Alamofire の MultipartFormData と同じ書式で、payload_json と files[0] を並べる")
    func multipartBody() throws {
        let attachment = ImageAttachment(
            data: Data([0x89, 0x50, 0x4E, 0x47]),
            fileName: "image.png",
            mimeType: "image/png"
        )
        let webhookRequest = request(.make(content: "スクリーンショット"), attachment: attachment)
        let body = try #require(webhookRequest.multipartBody(boundary: "BOUNDARY"))

        let parts = try #require(
            MultipartFormDataParser.parse(body, boundary: "BOUNDARY", fileName: "image.png", mimeType: "image/png")
        )
        let payload = try #require(try JSONSerialization.jsonObject(with: parts.payloadJSON) as? NSDictionary)
        #expect(payload == webhookRequest.parameters.dictionary)
        #expect(!parts.payloadJSON.contains(UInt8(ascii: "\n")))
        #expect(parts.file == attachment.data)
    }

    @Test("画像だけを添付するときは、payload_json にも本文を入れない")
    func multipartPayloadWithoutContent() throws {
        let parts = try #require(request(.make(username: "忍者"), attachment: .sample).multipartParts)
        let payload = try #require(try JSONSerialization.jsonObject(with: parts[0].data) as? NSDictionary)
        #expect(payload == ["username": "忍者", "avatar_url": ""])
    }

    @Test("名前が空なら、payload_json にも username を入れない")
    func multipartPayloadWithoutUsername() throws {
        let parts = try #require(request(.make(content: "スクリーンショット"), attachment: .sample).multipartParts)
        let payload = try #require(try JSONSerialization.jsonObject(with: parts[0].data) as? NSDictionary)
        #expect(payload == ["avatar_url": "", "content": "スクリーンショット"])
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

private extension ImageAttachment {
    static let sample = ImageAttachment(data: Data([0xFF, 0xD8, 0xFF]), fileName: "image.jpg", mimeType: "image/jpeg")
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
