//
//  ShortcutMessageSenderTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// ショートカットからの送信（`ShortcutMessageSender`、Issue #700）。
/// 宛先・テンプレートを ID で探し、無料の制限と本文の置き換えを確かめてから送り、送信画面と同じく送信履歴に残す
@MainActor
final class ShortcutMessageSenderTests {
    private let suiteName = "ShortcutMessageSenderTests.\(UUID().uuidString)"
    private let userDefaults: UserDefaults
    private let urlStore: WebhookURLStore
    private let templateStore: MessageTemplateStore
    private let historyStore: SendHistoryStore
    private let analytics = ShortcutAnalyticsSpy()
    private let sender: ShortcutMessageSender

    /// `wait=true` で送ったときに Discord が返す、作られたメッセージ
    private nonisolated static let created = StubURLProtocol.Stub.response(
        statusCode: 200,
        data: Data(#"{"id": "1234567890"}"#.utf8)
    )

    init() throws {
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
        // 送信履歴の保存は既定で OFF なので、記録を確かめるために ON にする
        userDefaults.set(true, forKey: SendHistoryStore.isEnabledKey)
        urlStore = WebhookURLStore(userDefaults: userDefaults)
        templateStore = MessageTemplateStore(userDefaults: userDefaults)
        historyStore = SendHistoryStore(userDefaults: userDefaults)
        sender = ShortcutMessageSender(
            client: DiscordWebhookClient(session: StubURLProtocol.session),
            urlStore: urlStore,
            templateStore: templateStore,
            historyStore: historyStore,
            analytics: analytics
        )
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    /// 応答を決めた Webhook URL を、名前を付けて宛先に保存する
    private func saveDestination(
        _ name: String = "お知らせ",
        returning stub: StubURLProtocol.Stub = created
    ) -> (item: SavedWebhookURL, url: URL) {
        let url = StubURLProtocol.makeSnowflakeURL(returning: stub)
        return (urlStore.add(name: name, url: url.absoluteString), url)
    }

    @discardableResult
    private func addTemplate(
        _ name: String,
        content: String,
        username: String = "",
        embed: MessageEmbedEntity = MessageEmbedEntity()
    ) -> MessageTemplate {
        templateStore.add(
            name: name,
            message: MessageEntity(username: username, avatarURL: "", content: content, messageEmbedEntity: embed)
        )
    }

    private func send(
        to destinationID: SavedWebhookURL.ID,
        template templateID: MessageTemplate.ID? = nil,
        body: String? = nil,
        isPro: Bool = false
    ) async -> Result<ShortcutSendSuccess, ShortcutSendError> {
        let request = ShortcutMessageSender.Request(destinationID: destinationID, templateID: templateID, body: body)
        return await sender.send(request, isPro: isPro)
    }

    /// その宛先に最後に送った JSON のパラメータ
    private func sentParameters(to url: URL) throws -> [String: Any] {
        let body = try #require(StubURLProtocol.requests(to: url).last?.body)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    // MARK: - 宛先・テンプレートの解決

    @Test("宛先とテンプレートを ID で探し、テンプレートの中身を送る")
    func sendsTemplate() async throws {
        let destination = saveDestination()
        let template = addTemplate("朝の挨拶", content: "おはようございます", username: "当番Bot")

        let result = await send(to: destination.item.id, template: template.id)

        #expect(result.successValue == ShortcutSendSuccess(destinationName: "お知らせ"))
        let parameters = try sentParameters(to: destination.url)
        #expect(parameters["content"] as? String == "おはようございます")
        #expect(parameters["username"] as? String == "当番Bot")
    }

    @Test("アプリで消した宛先を選んでいたら、送らずにエラーにする")
    func destinationNotFound() async {
        let destination = saveDestination()
        urlStore.remove(id: destination.item.id)

        let result = await send(to: destination.item.id, body: "こんにちは")

        #expect(result.failureValue == .destinationNotFound)
        #expect(StubURLProtocol.requests(to: destination.url).isEmpty)
    }

    @Test("アプリで消したテンプレートを選んでいたら、送らずにエラーにする")
    func templateNotFound() async {
        let destination = saveDestination()
        let template = addTemplate("朝の挨拶", content: "おはようございます")
        templateStore.remove(id: template.id)

        let result = await send(to: destination.item.id, template: template.id, isPro: true)

        #expect(result.failureValue == .templateNotFound)
        #expect(StubURLProtocol.requests(to: destination.url).isEmpty)
    }

    // MARK: - 本文の置き換え

    @Test("本文を指定すると、テンプレートの本文だけを置き換える（名前・埋め込みはテンプレートのまま）")
    func bodyReplacesTemplateContent() async throws {
        let destination = saveDestination()
        let template = addTemplate(
            "定例会",
            content: "テンプレートの本文",
            username: "当番Bot",
            embed: MessageEmbedEntity(title: "定例会のお知らせ")
        )

        let result = await send(to: destination.item.id, template: template.id, body: "今日はお休みです")

        #expect(result.isSuccess)
        let parameters = try sentParameters(to: destination.url)
        #expect(parameters["content"] as? String == "今日はお休みです")
        #expect(parameters["username"] as? String == "当番Bot")
        let embeds = try #require(parameters["embeds"] as? [[String: Any]])
        #expect(embeds.first?["title"] as? String == "定例会のお知らせ")
    }

    @Test("空白・改行だけの本文は指定しなかったものとして、テンプレートの本文を送る")
    func blankBodyKeepsTemplateContent() async throws {
        let destination = saveDestination()
        let template = addTemplate("朝の挨拶", content: "おはようございます")

        let result = await send(to: destination.item.id, template: template.id, body: " \n ")

        #expect(result.isSuccess)
        #expect(try sentParameters(to: destination.url)["content"] as? String == "おはようございます")
    }

    @Test("テンプレートを使わず本文だけでも、無料で送れる")
    func sendsBodyWithoutTemplate() async throws {
        let destination = saveDestination()
        addTemplate("朝の挨拶", content: "おはようございます")

        let result = await send(to: destination.item.id, body: "クリップボードの内容", isPro: false)

        #expect(result.isSuccess)
        let parameters = try sentParameters(to: destination.url)
        #expect(parameters["content"] as? String == "クリップボードの内容")
        // 名前は空なので送らず、Discord 側で Webhook の名前で出す
        #expect(parameters["username"] == nil)
    }

    @Test("テンプレートも本文も無ければ、送らずにエラーにする", arguments: [nil, "", " \n "] as [String?])
    func emptyMessage(body: String?) async {
        let destination = saveDestination()

        let result = await send(to: destination.item.id, body: body)

        #expect(result.failureValue == .emptyMessage)
        #expect(StubURLProtocol.requests(to: destination.url).isEmpty)
        #expect(historyStore.items.isEmpty)
        #expect(analytics.events.isEmpty)
    }

    // MARK: - 無料の制限（Discussion #376 の C-2）

    @Test("無料では一覧の先頭のテンプレートだけ使え、ほかを選んだら送らずに Pro の案内を返す")
    func freePlanCanUseOnlyFirstTemplate() async {
        let destination = saveDestination()
        let first = addTemplate("1件目", content: "1件目の本文")
        let second = addTemplate("2件目", content: "2件目の本文")

        let firstResult = await send(to: destination.item.id, template: first.id)
        let secondResult = await send(to: destination.item.id, template: second.id)

        #expect(firstResult.isSuccess)
        #expect(secondResult.failureValue == .proTemplateRequired)
        #expect(StubURLProtocol.requests(to: destination.url).count == 1)
    }

    @Test("無料で使えるのは、ピン留め・並べ替えで一覧の先頭に来たテンプレート")
    func freeTemplateFollowsListOrder() async {
        let destination = saveDestination()
        let first = addTemplate("1件目", content: "1件目の本文")
        let second = addTemplate("2件目", content: "2件目の本文")
        templateStore.togglePin(id: second.id)

        let secondResult = await send(to: destination.item.id, template: second.id)
        let firstResult = await send(to: destination.item.id, template: first.id)

        #expect(secondResult.isSuccess)
        #expect(firstResult.failureValue == .proTemplateRequired)
    }

    @Test("Pro なら、どのテンプレートでも使える")
    func proCanUseAnyTemplate() async {
        let destination = saveDestination()
        addTemplate("1件目", content: "1件目の本文")
        let second = addTemplate("2件目", content: "2件目の本文")

        let result = await send(to: destination.item.id, template: second.id, isPro: true)

        #expect(result.isSuccess)
    }

    @Test("無料では、Pro 限定の項目が入ったテンプレートは送らない（Pro なら送る）")
    func proEmbedFeatures() async {
        let destination = saveDestination()
        let template = addTemplate(
            "お知らせ",
            content: "",
            embed: MessageEmbedEntity(title: "お知らせ", footerText: "Ninjacord")
        )

        let freeResult = await send(to: destination.item.id, template: template.id, isPro: false)
        let proResult = await send(to: destination.item.id, template: template.id, isPro: true)

        #expect(freeResult.failureValue == .proEmbedFeatures)
        #expect(proResult.isSuccess)
        #expect(StubURLProtocol.requests(to: destination.url).count == 1)
    }

    // MARK: - 送信の結果

    @Test("送れたら、受け取ったメッセージ ID と一緒に送信履歴に残し、「投稿済み」に出す")
    func recordsPostedMessage() async throws {
        let destination = saveDestination()

        let result = await send(to: destination.item.id, body: "こんにちは")

        #expect(result.isSuccess)
        let entry = try #require(SendHistoryStore(userDefaults: userDefaults).postedItems.first)
        #expect(entry.url == destination.url.absoluteString)
        #expect(entry.message.content == "こんにちは")
        #expect(entry.messageID == "1234567890")
        #expect(!entry.hasAttachment)
    }

    @Test("送信履歴を保存しない設定なら、残さない")
    func doesNotRecordWhenHistoryDisabled() async {
        userDefaults.set(false, forKey: SendHistoryStore.isEnabledKey)
        let destination = saveDestination()

        let result = await send(to: destination.item.id, body: "こんにちは")

        #expect(result.isSuccess)
        #expect(SendHistoryStore(userDefaults: userDefaults).items.isEmpty)
    }

    @Test("送れなかったら、原因の文言を返し、失敗として送信履歴に残す")
    func returnsDiscordError() async throws {
        let destination = saveDestination(returning: .response(statusCode: 404, data: Data()))

        let result = await send(to: destination.item.id, body: "こんにちは")

        #expect(result.failureValue == .discord(.unknownWebhook))
        #expect(result.failureValue?.message == DiscordWebhookError.unknownWebhook.errorDescription)
        let entry = try #require(historyStore.items.first)
        #expect(!entry.isSuccess)
        #expect(entry.messageID == nil)
    }

    @Test("Analytics には送信元をショートカットとして記録し、送信成功の回数には数えない")
    func recordsAnalyticsWithoutCountingSuccess() async {
        let destination = saveDestination()
        let failed = saveDestination("障害中", returning: .response(statusCode: 500, data: Data()))
        let countBefore = SendSuccessCounter().count

        _ = await send(to: destination.item.id, body: "こんにちは")
        _ = await send(to: failed.item.id, body: "こんにちは")

        #expect(analytics.events == [
            ShortcutAnalyticsSpy.Event(isSuccess: true, httpStatus: 200, source: "shortcut"),
            ShortcutAnalyticsSpy.Event(isSuccess: false, httpStatus: 500, source: "shortcut")
        ])
        // 送信成功の回数（ATT の要求・レビュー依頼に使う。保存先は UserDefaults.standard）は変えない
        #expect(SendSuccessCounter().count == countBefore)
        #expect(SendSuccessCounter(userDefaults: userDefaults).count == 0)
    }
}

// MARK: - Webhook URL を出さない

extension ShortcutMessageSenderTests {
    @Test("結果とエラーの文言に、Webhook URL（トークンを含む）を出さない")
    func messagesDoNotContainWebhookURL() {
        let destination = saveDestination()
        let errors: [ShortcutSendError] = [
            .destinationNotFound, .templateNotFound, .emptyMessage, .proTemplateRequired, .proEmbedFeatures,
            .invalidEmbed(.titleTooLong), .discord(.unknownWebhook), .discord(.invalidToken), .discord(.network)
        ]
        let messages = [ShortcutSendSuccess(destinationName: destination.item.name).message]
            + errors.map(\.message)

        for message in messages {
            #expect(!message.contains(destination.url.absoluteString))
            #expect(!message.contains("/token"))
        }
    }

    @Test("ショートカットに出す宛先は、付けた名前とトークンを出さない短い表示だけを持つ")
    func destinationEntityDoesNotContainWebhookURL() throws {
        let destination = saveDestination()
        let webhookID = try #require(DiscordWebhookURL(string: destination.url.absoluteString)?.webhookID)

        let entity = ShortcutDestinationEntity(destination.item)
        let title = String(localized: entity.displayRepresentation.title)
        let subtitle = try #require(entity.displayRepresentation.subtitle.map { String(localized: $0) })

        #expect(entity.id == destination.item.id)
        #expect(title == "お知らせ")
        #expect(subtitle == "Webhook …\(webhookID.suffix(4))")
        for text in [entity.name, entity.subtitle, title, subtitle] {
            #expect(!text.contains(destination.url.absoluteString))
            #expect(!text.contains("token"))
        }
    }
}

/// ショートカットからの送信の Analytics に送った値を記録する（Firebase には送らない）
private final class ShortcutAnalyticsSpy: ShortcutSendAnalytics {
    struct Event: Equatable {
        let isSuccess: Bool
        let httpStatus: Int?
        let source: String
    }

    private(set) var events: [Event] = []

    func sendMessageSendEvent(isSuccess: Bool, httpStatus: Int?, source: String) {
        events.append(Event(isSuccess: isSuccess, httpStatus: httpStatus, source: source))
    }
}
