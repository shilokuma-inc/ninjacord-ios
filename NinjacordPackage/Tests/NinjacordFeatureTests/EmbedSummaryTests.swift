//
//  EmbedSummaryTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信画面の埋め込みの要約（`EmbedSummary`）が、送る中身（`DiscordWebhookRequest`）と食い違わないことを確かめる
struct EmbedSummaryTests {
    private func summary(_ embed: MessageEmbedEntity) -> EmbedSummary {
        EmbedSummary(embed: embed)
    }

    /// 埋め込みを送るか。送る中身と同じく、embeds のキーがあるかで見る
    private func sendsEmbed(_ embed: MessageEmbedEntity) -> Bool {
        let message = MessageEntity(username: "忍者", avatarURL: "", content: "本文", messageEmbedEntity: embed)
        return DiscordWebhookRequest(messageEntity: message).parameters["embeds"] != nil
    }

    @Test("何も入力していなければ未設定")
    func empty() {
        #expect(summary(MessageEmbedEntity()).state == .empty)
        // 空白だけのタイトルも入力とみなさない（送らない）
        #expect(summary(MessageEmbedEntity(title: " ", description: "\n")).state == .empty)
        #expect(summary(MessageEmbedEntity()).title == nil)
    }

    @Test("色・送信日時だけなら、送られないことを示す", arguments: [
        MessageEmbedEntity(color: 0x5865F2),
        MessageEmbedEntity(includesTimestamp: true),
        MessageEmbedEntity(color: 0x5865F2, includesTimestamp: true)
    ])
    func notSent(embed: MessageEmbedEntity) {
        #expect(summary(embed).state == .notSent)
        #expect(!sendsEmbed(embed))
    }

    @Test("タイトルだけなら、タイトルを出して項目は無し")
    func titleOnly() {
        let embed = MessageEmbedEntity(title: "お知らせ")
        #expect(summary(embed).state == .filled(title: "お知らせ", items: []))
        #expect(summary(embed).title == "お知らせ")
        #expect(sendsEmbed(embed))
    }

    @Test("入力済みの項目を、エディタの上から順に並べる")
    func allItems() {
        let embed = MessageEmbedEntity(
            title: "お知らせ",
            description: "説明",
            color: 0x57F287,
            fields: [
                MessageEmbedField(name: "集合", value: "20:50", isInline: true),
                MessageEmbedField(name: "場所", value: "", isInline: true)
            ],
            footerText: "フッター",
            imageURL: "https://example.com/image.png",
            thumbnailURL: "https://example.com/thumbnail.png",
            includesTimestamp: true
        )
        #expect(summary(embed).state == .filled(
            title: "お知らせ",
            items: [.description, .color, .fields(2), .image, .thumbnail, .footer, .timestamp]
        ))
    }

    @Test("タイトルが空でも、ほかの中身があれば送る。タイトルは nil")
    func withoutTitle() {
        let embed = MessageEmbedEntity(description: "本日18時からメンテナンスです")
        #expect(summary(embed).state == .filled(title: nil, items: [.description]))
        #expect(summary(embed).title == nil)
        #expect(sendsEmbed(embed))
    }

    /// 送るフィールドは `sendableFields` と同じ（名前か値のどちらかがある行）
    @Test("フィールドは、名前も値も空の行を数えない")
    func blankFieldRowsAreNotCounted() {
        let blank = MessageEmbedField(name: "", value: "", isInline: false)
        let filled = MessageEmbedField(name: "", value: "値", isInline: false)
        let embed = MessageEmbedEntity(title: "お知らせ", fields: [blank, filled, blank])
        #expect(summary(embed).state == .filled(title: "お知らせ", items: [.fields(1)]))
    }

    /// `hasContent` は true で `hasDisplayedContent` は false のとき
    @Test("空のフィールド行と色・送信日時だけなら、表示される中身の無い埋め込みを送ることを示す", arguments: [
        MessageEmbedEntity(fields: [MessageEmbedField(name: "", value: "", isInline: false)]),
        MessageEmbedEntity(color: 0x5865F2, fields: [MessageEmbedField(name: "", value: "", isInline: false)]),
        MessageEmbedEntity(
            title: " ",
            fields: [MessageEmbedField(name: "", value: "", isInline: false)],
            includesTimestamp: true
        )
    ])
    func nothingDisplayed(embed: MessageEmbedEntity) {
        #expect(summary(embed).state == .nothingDisplayed)
        #expect(summary(embed).title == nil)
        #expect(sendsEmbed(embed))
        #expect(!embed.hasDisplayedContent)
    }

    @Test("タイトルの前後の空白と改行は、要約では除く")
    func trimmedTitle() {
        #expect(summary(MessageEmbedEntity(title: "  お知らせ\n")).title == "お知らせ")
    }

    @Test("2 行目の文言は状態ごとに違う")
    func detailsDiffer() {
        let details = [
            summary(MessageEmbedEntity()).detail,
            summary(MessageEmbedEntity(color: 0x5865F2)).detail,
            summary(MessageEmbedEntity(title: "お知らせ")).detail,
            summary(MessageEmbedEntity(fields: [MessageEmbedField(name: "", value: "", isInline: false)])).detail,
            summary(MessageEmbedEntity(description: "説明")).detail
        ]
        #expect(Set(details).count == details.count)
        #expect(details.allSatisfy { !$0.isEmpty })
    }
}
