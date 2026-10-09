//
//  SendMessageValidationTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信前の入力チェック（`SendMessageViewModel.validate`）の今の結果を固定する。
/// 送信まわりのリファクタ（Discussion #459）で、チェックの内容と順番が変わらないことを確かめる
@MainActor
struct SendMessageValidationTests {
    // 既定引数から参照するので、MainActor に縛らない
    private nonisolated static let webhookURL = "https://discord.com/api/webhooks/123/abc"

    private let viewModel = SendMessageViewModel()

    private func validate(
        url: String = Self.webhookURL,
        message: MessageEntity = .make(content: "こんにちは"),
        canUseProFeatures: Bool = false
    ) -> SendMessageValidationError? {
        viewModel.validate(url: url, messageEntity: message, canUseProFeatures: canUseProFeatures)
    }

    // MARK: - URL

    @Test("URL が空・空白だけなら emptyURL", arguments: ["", "   ", " \n\t "])
    func emptyURL(url: String) {
        #expect(validate(url: url) == .emptyURL)
    }

    @Test(
        "http / https のスキームとホストが無い URL は invalidURL",
        arguments: [
            "discord.com/api/webhooks/123/abc",
            "ftp://discord.com/api/webhooks/123/abc",
            "https://",
            "Webhook URL"
        ]
    )
    func invalidURL(url: String) {
        #expect(validate(url: url) == .invalidURL)
    }

    @Test(
        "前後の空白を除いた http / https の URL は通る",
        arguments: [
            " https://discord.com/api/webhooks/123/abc \n",
            "http://example.com/webhook",
            "HTTPS://discord.com/api/webhooks/123/abc"
        ]
    )
    func validURL(url: String) {
        #expect(validate(url: url) == nil)
    }

    @Test("URL のチェックはメッセージのチェックより先")
    func urlIsCheckedBeforeMessage() {
        #expect(validate(url: "", message: .make()) == .emptyURL)
        #expect(validate(url: "discord.com", message: .make()) == .invalidURL)
    }

    // MARK: - メッセージ

    @Test("名前・アイコン URL・本文・埋め込みがすべて空なら emptyMessage")
    func emptyMessage() {
        #expect(validate(message: .make()) == .emptyMessage)
    }

    @Test("空白だけの入力は空とみなす")
    func whitespaceOnlyMessage() {
        let message = MessageEntity.make(
            username: " ",
            avatarURL: "\n",
            content: " \t ",
            embed: MessageEmbedEntity(title: " ", description: "\n")
        )
        #expect(validate(message: message) == .emptyMessage)
    }

    @Test("名前・アイコン URL・本文・埋め込みのどれか 1 つがあれば通る")
    func messageWithAnyContent() {
        #expect(validate(message: .make(username: "忍者")) == nil)
        #expect(validate(message: .make(avatarURL: "https://example.com/avatar.png")) == nil)
        #expect(validate(message: .make(content: "こんにちは")) == nil)
        #expect(validate(message: .make(embed: MessageEmbedEntity(title: "お知らせ"))) == nil)
        #expect(validate(message: .make(embed: MessageEmbedEntity(description: "本文"))) == nil)
    }

    /// 名前と値がどちらも空のフィールド行は送らないが、行があるだけでメッセージは空とみなさない（今の挙動）
    @Test("空のフィールド行だけでも emptyMessage にならない")
    func blankFieldRowOnly() {
        let message = MessageEntity.make(embed: MessageEmbedEntity(fields: [.blank]))
        #expect(validate(message: message, canUseProFeatures: true) == nil)
        #expect(validate(message: message, canUseProFeatures: false) == nil)
    }

    @Test("埋め込みの色・送信日時だけでは、メッセージは空とみなす")
    func colorAndTimestampOnly() {
        let message = MessageEntity.make(embed: MessageEmbedEntity(color: 0x5865F2, includesTimestamp: true))
        #expect(validate(message: message, canUseProFeatures: true) == .emptyMessage)
        #expect(validate(message: message, canUseProFeatures: false) == .emptyMessage)
    }

    // MARK: - Pro 限定の埋め込み

    @Test("Pro でなければ、Pro 限定の項目が入った埋め込みは proEmbedFeatures", arguments: ProEmbedItem.allCases)
    func proEmbedFeaturesWithoutPro(item: ProEmbedItem) {
        #expect(validate(message: .make(embed: item.embed), canUseProFeatures: false) == .proEmbedFeatures)
    }

    @Test("Pro なら、Pro 限定の項目が入った埋め込みも通る", arguments: ProEmbedItem.allCases)
    func proEmbedFeaturesWithPro(item: ProEmbedItem) {
        #expect(validate(message: .make(embed: item.embed), canUseProFeatures: true) == nil)
    }

    @Test("Pro でなくても、タイトルと説明だけの埋め込みは通る")
    func freeEmbedWithoutPro() {
        let embed = MessageEmbedEntity(title: "お知らせ", description: "本文")
        #expect(validate(message: .make(embed: embed), canUseProFeatures: false) == nil)
    }

    @Test("Pro 限定の項目のチェックは、埋め込みの上限のチェックより先")
    func proFeaturesAreCheckedBeforeLimits() {
        let embed = MessageEmbedEntity(title: .repeating(count: EmbedLimit.title + 1), color: 0xFF0000)
        #expect(validate(message: .make(embed: embed), canUseProFeatures: false) == .proEmbedFeatures)
    }

    @Test("Pro でなくても、タイトルの上限は invalidEmbed で返す")
    func freeEmbedLimitWithoutPro() {
        let embed = MessageEmbedEntity(title: .repeating(count: EmbedLimit.title + 1))
        #expect(validate(message: .make(embed: embed), canUseProFeatures: false) == .invalidEmbed(.titleTooLong))
    }

    // MARK: - 埋め込みの上限

    @Test("タイトルは 256 文字まで")
    func titleLimit() {
        #expect(validateEmbed(MessageEmbedEntity(title: .repeating(count: EmbedLimit.title))) == nil)
        #expect(
            validateEmbed(MessageEmbedEntity(title: .repeating(count: EmbedLimit.title + 1)))
                == .invalidEmbed(.titleTooLong)
        )
    }

    @Test("文字数は Discord と同じく UTF-16 で数える")
    func lengthIsCountedInUTF16() {
        // 絵文字は UTF-16 で 2 文字
        #expect(validateEmbed(MessageEmbedEntity(title: .repeating("😀", count: 128))) == nil)
        #expect(
            validateEmbed(MessageEmbedEntity(title: .repeating("😀", count: 129))) == .invalidEmbed(.titleTooLong)
        )
    }

    @Test("説明は 4096 文字まで")
    func descriptionLimit() {
        #expect(validateEmbed(MessageEmbedEntity(description: .repeating(count: EmbedLimit.description))) == nil)
        #expect(
            validateEmbed(MessageEmbedEntity(description: .repeating(count: EmbedLimit.description + 1)))
                == .invalidEmbed(.descriptionTooLong)
        )
    }

    @Test("フィールドは 25 件まで")
    func fieldCountLimit() {
        let fields = (0..<EmbedLimit.fieldCount).map { _ in MessageEmbedField.filled }
        #expect(validateEmbed(MessageEmbedEntity(fields: fields)) == nil)
        #expect(validateEmbed(MessageEmbedEntity(fields: fields + [.filled])) == .invalidEmbed(.tooManyFields))
    }

    @Test("空のフィールド行は 25 件に数えない")
    func blankFieldRowsAreNotCounted() {
        let fields = (0..<EmbedLimit.fieldCount).map { _ in MessageEmbedField.filled } + [.blank]
        #expect(validateEmbed(MessageEmbedEntity(fields: fields)) == nil)
    }

    @Test("フィールドの名前は 256 文字、値は 1024 文字まで")
    func fieldLengthLimits() {
        let longName = MessageEmbedField(name: .repeating(count: EmbedLimit.fieldName + 1), value: "値", isInline: false)
        let longValue = MessageEmbedField(
            name: "名前",
            value: .repeating(count: EmbedLimit.fieldValue + 1),
            isInline: false
        )
        #expect(validateEmbed(MessageEmbedEntity(fields: [longName])) == .invalidEmbed(.fieldNameTooLong(index: 0)))
        #expect(validateEmbed(MessageEmbedEntity(fields: [longValue])) == .invalidEmbed(.fieldValueTooLong(index: 0)))
    }

    @Test("名前と値の片方だけのフィールドは fieldIncomplete。番号は空の行も含めた画面上の位置")
    func fieldIncomplete() {
        let nameOnly = MessageEmbedField(name: "名前", value: "", isInline: false)
        let valueOnly = MessageEmbedField(name: "", value: "値", isInline: false)
        #expect(
            validateEmbed(MessageEmbedEntity(fields: [.blank, nameOnly])) == .invalidEmbed(.fieldIncomplete(index: 1))
        )
        #expect(validateEmbed(MessageEmbedEntity(fields: [valueOnly])) == .invalidEmbed(.fieldIncomplete(index: 0)))
    }

    @Test("フッターは 2048 文字まで")
    func footerLimit() {
        #expect(validateEmbed(MessageEmbedEntity(footerText: .repeating(count: EmbedLimit.footerText))) == nil)
        #expect(
            validateEmbed(MessageEmbedEntity(footerText: .repeating(count: EmbedLimit.footerText + 1)))
                == .invalidEmbed(.footerTooLong)
        )
    }

    @Test("タイトル・説明・フィールド・フッターの合計は 6000 文字まで")
    func totalLimit() {
        // それぞれは上限以内で、合計がちょうど 6000 文字（256 + 4096 + 2 + 1646）
        let field = MessageEmbedField(name: "a", value: "b", isInline: false)
        let atTotal = MessageEmbedEntity(
            title: .repeating(count: EmbedLimit.title),
            description: .repeating(count: EmbedLimit.description),
            fields: [field],
            footerText: .repeating(count: 1646)
        )
        #expect(validateEmbed(atTotal) == nil)

        var overTotal = atTotal
        overTotal.footerText += "a"
        #expect(validateEmbed(overTotal) == .invalidEmbed(.totalTooLong))
    }

    @Test("画像とサムネイルの URL は http / https のみ")
    func imageURLs() {
        #expect(validateEmbed(MessageEmbedEntity(imageURL: "https://example.com/image.png")) == nil)
        #expect(validateEmbed(MessageEmbedEntity(imageURL: "example.com/image.png")) == .invalidEmbed(.invalidImageURL))
        #expect(validateEmbed(MessageEmbedEntity(thumbnailURL: "http://example.com/thumbnail.png")) == nil)
        #expect(
            validateEmbed(MessageEmbedEntity(thumbnailURL: "ftp://example.com/thumbnail.png"))
                == .invalidEmbed(.invalidThumbnailURL)
        )
    }

    @Test("誤りが複数あっても、画面の上から最初の 1 件だけを返す")
    func onlyFirstIssueIsReturned() {
        let embed = MessageEmbedEntity(
            title: .repeating(count: EmbedLimit.title + 1),
            description: .repeating(count: EmbedLimit.description + 1),
            imageURL: "example.com/image.png"
        )
        #expect(validateEmbed(embed) == .invalidEmbed(.titleTooLong))
    }

    /// Pro 限定の項目のチェックを通した状態で、埋め込みの上限を確かめる
    private func validateEmbed(_ embed: MessageEmbedEntity) -> SendMessageValidationError? {
        validate(message: .make(embed: embed), canUseProFeatures: true)
    }
}

/// 埋め込みのうち Pro 限定の項目（Discussion #259）
enum ProEmbedItem: CaseIterable {
    case color
    case fields
    case imageURL
    case thumbnailURL
    case footerText
    case timestamp

    /// タイトルに加えて、その項目だけが入った埋め込み。
    /// 色と送信日時は、それだけでは埋め込みの内容とみなされない（emptyMessage になる）ため、タイトルを入れておく
    var embed: MessageEmbedEntity {
        var embed = MessageEmbedEntity(title: "お知らせ")
        switch self {
        case .color:
            embed.color = 0x5865F2
        case .fields:
            embed.fields = [.filled]
        case .imageURL:
            embed.imageURL = "https://example.com/image.png"
        case .thumbnailURL:
            embed.thumbnailURL = "https://example.com/thumbnail.png"
        case .footerText:
            embed.footerText = "フッター"
        case .timestamp:
            embed.includesTimestamp = true
        }
        return embed
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

private extension MessageEmbedField {
    /// 名前と値が入ったフィールド
    static var filled: MessageEmbedField {
        MessageEmbedField(name: "名前", value: "値", isInline: false)
    }

    /// 「フィールドを追加」を押した直後の、名前も値も空の行
    static var blank: MessageEmbedField {
        MessageEmbedField(name: "", value: "", isInline: false)
    }
}

private extension String {
    static func repeating(_ character: String = "a", count: Int) -> String {
        String(repeating: character, count: count)
    }
}
