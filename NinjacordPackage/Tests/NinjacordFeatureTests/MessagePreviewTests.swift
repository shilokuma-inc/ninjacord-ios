//
//  MessagePreviewTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信画面のプレビュー（`MessagePreview`）に埋め込みを出すかが、
/// 要約（`EmbedSummary`）・送る中身（`DiscordWebhookRequest`）と食い違わないことを確かめる
@MainActor
struct MessagePreviewTests {
    // テストの引数（arguments）から参照するので、MainActor に縛らない
    private nonisolated static let blankField = MessageEmbedField(name: "", value: "", isInline: false)

    private func showsEmbed(_ embed: MessageEmbedEntity) -> Bool {
        MessagePreview(username: "", avatarURL: "", content: "", embed: embed, attachment: nil).showsEmbed
    }

    /// 本文が空のとき、既定の文言に置き換えて送るか
    private func defaultsContent(_ embed: MessageEmbedEntity) -> Bool {
        let message = MessageEntity(username: "", avatarURL: "", content: "", messageEmbedEntity: embed)
        return DiscordWebhookRequest(messageEntity: message).defaultedFields.contains(.content)
    }

    /// 空のフィールド行は送らないので、内容に数えない（Issue #637・#461）
    @Test("空のフィールド行と色・送信日時だけなら、埋め込みの枠を出さない", arguments: [
        MessageEmbedEntity(fields: [blankField]),
        MessageEmbedEntity(fields: [blankField, blankField]),
        MessageEmbedEntity(color: 0x5865F2, fields: [blankField], includesTimestamp: true),
        MessageEmbedEntity(title: " ", fields: [blankField])
    ])
    func hidesEmbedWithoutDisplayedContent(embed: MessageEmbedEntity) {
        #expect(!embed.hasContent)
        #expect(!showsEmbed(embed))
        // 本文は既定の文言に置き換えて送るので、プレビューには埋め込みの枠の代わりに本文の場所が出る
        #expect(defaultsContent(embed))
    }

    @Test("表示される中身があれば、埋め込みを出す", arguments: [
        MessageEmbedEntity(title: "お知らせ"),
        MessageEmbedEntity(description: "本日18時からメンテナンスです"),
        MessageEmbedEntity(fields: [MessageEmbedField(name: "", value: "18:00", isInline: true)]),
        MessageEmbedEntity(fields: [blankField, MessageEmbedField(name: "開始", value: "18:00", isInline: true)]),
        MessageEmbedEntity(footerText: "Ninja Cord"),
        MessageEmbedEntity(imageURL: "https://example.com/image.png")
    ])
    func showsEmbedWithDisplayedContent(embed: MessageEmbedEntity) {
        #expect(showsEmbed(embed))
        #expect(!defaultsContent(embed))
    }

    @Test("何も入力していないか、色・送信日時だけなら、埋め込みを出さない", arguments: [
        MessageEmbedEntity(),
        MessageEmbedEntity(color: 0x5865F2, includesTimestamp: true)
    ])
    func hidesEmbedWithoutContent(embed: MessageEmbedEntity) {
        #expect(!showsEmbed(embed))
        #expect(defaultsContent(embed))
    }
}
