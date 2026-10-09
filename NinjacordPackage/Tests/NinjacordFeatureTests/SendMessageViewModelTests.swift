//
//  SendMessageViewModelTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信画面の操作（`SendMessageViewModel.sendMessage` など）の今の挙動を固定する。
/// View から移したあとも、入力チェックの順番・送信履歴の記録・トーストの文言・送信後の流れの呼び出しが変わらないことを確かめる
@MainActor
final class SendMessageViewModelTests {
    private let suiteName = "SendMessageViewModelTests.\(UUID().uuidString)"
    private let userDefaults: UserDefaults
    private let historyStore: SendHistoryStore
    private let viewModel: SendMessageViewModel
    /// 送信後の流れ（View の handleSendSucceeded）が呼ばれた回数と、渡された「Pro 機能を使った送信か」
    private var succeededCalls: [Bool] = []

    init() throws {
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
        // 送信履歴の保存は既定で OFF なので、記録を確かめるために ON にする
        userDefaults.set(true, forKey: SendHistoryStore.isEnabledKey)
        historyStore = SendHistoryStore(userDefaults: userDefaults)
        viewModel = SendMessageViewModel(
            client: DiscordWebhookClient(session: StubURLProtocol.session),
            historyStore: historyStore
        )
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    /// 送信ボタンを押したときと同じく sendMessage を呼び、送信を始めたら終わるまで待つ。始めたかどうかを返す
    @discardableResult
    private func send(isPro: Bool = false) async -> Bool {
        let task = viewModel.sendMessage(isPro: isPro) { [weak self] usedProFeatures in
            self?.succeededCalls.append(usedProFeatures)
        }
        await task?.value
        return task != nil
    }

    /// その URL に最初に送ったリクエストの Content-Type
    private func contentType(of url: URL) -> String? {
        StubURLProtocol.requests(to: url).first?.request.value(forHTTPHeaderField: "Content-Type")
    }

    private func savedURL(_ name: String, returning stub: StubURLProtocol.Stub) -> SavedWebhookURL {
        SavedWebhookURL(id: UUID(), name: name, url: StubURLProtocol.makeURL(returning: stub).absoluteString)
    }

    private static let noContent = StubURLProtocol.Stub.response(statusCode: 204, data: Data())
    private static let notFound = StubURLProtocol.Stub.response(statusCode: 404, data: Data())
    private static let attachment = ImageAttachment(
        data: Data([0x89, 0x50, 0x4E, 0x47]),
        fileName: "image.png",
        mimeType: "image/png"
    )

    // MARK: - 入力欄

    @Test("入力欄の内容から、送信・テンプレート保存用のメッセージを組み立てる")
    func currentMessage() {
        viewModel.inputURL = "https://discord.com/api/webhooks/1/token"
        viewModel.inputUsername = "レイド告知Bot"
        viewModel.inputAvatarURL = "https://example.com/avatar.png"
        viewModel.inputContext = "今夜21:00 レイド開始"
        viewModel.inputEmbed = MessageEmbedEntity(title: "お知らせ", color: 0x5865F2)

        #expect(viewModel.currentMessage == MessageEntity(
            username: "レイド告知Bot",
            avatarURL: "https://example.com/avatar.png",
            content: "今夜21:00 レイド開始",
            messageEmbedEntity: MessageEmbedEntity(title: "お知らせ", color: 0x5865F2)
        ))
    }

    @Test("テンプレートを反映すると、宛先（URL）は残して中身だけを入れ替える")
    func applyTemplate() {
        viewModel.inputURL = "https://discord.com/api/webhooks/1/token"
        viewModel.inputUsername = "前の名前"
        viewModel.inputContext = "前の本文"
        let message = MessageEntity(
            username: "テンプレートの名前",
            avatarURL: "https://example.com/template.png",
            content: "テンプレートの本文",
            messageEmbedEntity: MessageEmbedEntity(description: "説明")
        )

        viewModel.applyTemplate(MessageTemplate(id: UUID(), name: "定型", message: message, createdAt: Date()))

        #expect(viewModel.inputURL == "https://discord.com/api/webhooks/1/token")
        #expect(viewModel.currentMessage == message)
    }

    // MARK: - 入力チェック

    @Test("入力チェックで止まったら、アラートを出して送らない（URL が空）")
    func emptyURL() async {
        viewModel.inputContext = "こんにちは"

        let didStart = await send()

        #expect(!didStart)
        #expect(viewModel.validationError == .emptyURL)
        #expect(viewModel.isValidationAlertPresented)
        #expect(!viewModel.isSending)
        #expect(viewModel.toast == nil)
        #expect(historyStore.items.isEmpty)
    }

    @Test("URL のチェックは、メッセージのチェックより先")
    func urlIsCheckedBeforeMessage() async {
        viewModel.inputURL = "discord.com/api/webhooks/1/token"

        await send()

        #expect(viewModel.validationError == .invalidURL)
    }

    @Test("Pro でなければ、Pro 限定の項目が入った埋め込みは送らない。Pro なら送る")
    func proEmbedFeatures() async {
        let url = StubURLProtocol.makeURL(returning: Self.noContent)
        viewModel.inputURL = url.absoluteString
        viewModel.inputEmbed = MessageEmbedEntity(title: "お知らせ", color: 0x5865F2)

        #expect(await send(isPro: false) == false)
        #expect(viewModel.validationError == .proEmbedFeatures)
        #expect(StubURLProtocol.requests(to: url).isEmpty)

        #expect(await send(isPro: true))
        #expect(StubURLProtocol.requests(to: url).count == 1)
    }

    @Test("Pro でなければ、一斉送信は宛先や中身より先に proBroadcast で止める")
    func broadcastWithoutPro() async {
        // 宛先の URL が壊れていて、中身も空でも、先に Pro かどうかで止める
        viewModel.broadcastTargets = [
            SavedWebhookURL(id: UUID(), name: "壊れた URL", url: "discord.com/api/webhooks/1/token")
        ]

        #expect(await send(isPro: false) == false)
        #expect(viewModel.validationError == .proBroadcast)
        #expect(viewModel.isValidationAlertPresented)
    }

    @Test("一斉送信の入力チェックは、URL 欄ではなく 1 件目の宛先で行う")
    func broadcastValidatesFirstTarget() async {
        viewModel.inputURL = ""
        viewModel.broadcastTargets = [
            SavedWebhookURL(id: UUID(), name: "壊れた URL", url: "discord.com/api/webhooks/1/token"),
            savedURL("作戦室", returning: Self.noContent)
        ]
        viewModel.inputContext = "こんにちは"

        #expect(await send(isPro: true) == false)
        #expect(viewModel.validationError == .invalidURL)

        viewModel.broadcastTargets = [savedURL("作戦室", returning: Self.noContent)]
        viewModel.inputContext = ""
        #expect(await send(isPro: true) == false)
        #expect(viewModel.validationError == .emptyMessage)
    }

    // MARK: - 単発の送信

    @Test("送信に成功したら「送信しました」のトーストを出し、送信履歴に残し、送信後の流れを呼ぶ")
    func sendSucceeded() async throws {
        let url = StubURLProtocol.makeURL(returning: Self.noContent)
        viewModel.inputURL = url.absoluteString
        viewModel.inputContext = "こんにちは"

        #expect(await send())

        let toast = try #require(viewModel.toast)
        #expect(toast.style == .success)
        #expect(toast.message.testString == "送信しました")
        #expect(historyStore.items.count == 1)
        let entry = try #require(historyStore.items.first)
        #expect(entry.url == url.absoluteString)
        #expect(entry.message == viewModel.currentMessage)
        #expect(entry.isSuccess)
        #expect(succeededCalls == [false])
        #expect(!viewModel.isSending)
        #expect(StubURLProtocol.requests(to: url).count == 1)
    }

    @Test("Pro 限定の項目を使った送信なら、送信後の流れに Pro 機能を使ったと渡す")
    func sendSucceededWithProFeatures() async {
        viewModel.inputURL = StubURLProtocol.makeURL(returning: Self.noContent).absoluteString
        viewModel.inputEmbed = MessageEmbedEntity(title: "お知らせ", footerText: "Ninjacord")

        await send(isPro: true)

        #expect(succeededCalls == [true])
    }

    @Test("送信に失敗したら原因をトーストに出し、失敗として送信履歴に残し、送信後の流れは呼ばない")
    func sendFailed() async throws {
        let url = StubURLProtocol.makeURL(returning: Self.notFound)
        viewModel.inputURL = url.absoluteString
        viewModel.inputContext = "こんにちは"

        await send()

        let toast = try #require(viewModel.toast)
        #expect(toast.style == .failure)
        #expect(toast.message.testString == DiscordWebhookError.unknownWebhook.localizedDescription)
        let entry = try #require(historyStore.items.first)
        #expect(entry.url == url.absoluteString)
        #expect(!entry.isSuccess)
        #expect(succeededCalls.isEmpty)
    }

    @Test("送信中は二重に送らず、送信中に URL 欄を書き換えても送った先を履歴に残す")
    func sending() async throws {
        let url = StubURLProtocol.makeURL(returning: Self.noContent)
        viewModel.inputURL = url.absoluteString
        viewModel.inputContext = "こんにちは"

        let task = viewModel.sendMessage(isPro: false) { _ in }
        #expect(viewModel.isSending)
        let secondTask = viewModel.sendMessage(isPro: false) { _ in }
        #expect(secondTask == nil)
        viewModel.inputURL = "https://discord.com/api/webhooks/2/changed"
        await task?.value

        #expect(!viewModel.isSending)
        #expect(StubURLProtocol.requests(to: url).count == 1)
        let historyURLs = historyStore.items.map(\.url)
        #expect(historyURLs == [url.absoluteString])
    }

    @Test("画像を添付していれば、multipart/form-data で送る")
    func sendWithAttachment() async throws {
        let url = StubURLProtocol.makeURL(returning: Self.noContent)
        viewModel.inputURL = url.absoluteString
        viewModel.inputContext = "スクリーンショット"
        viewModel.attachment = Self.attachment

        await send()

        let header = try #require(contentType(of: url))
        #expect(header.hasPrefix("multipart/form-data; boundary="))
    }

    // MARK: - 一斉送信

    @Test("一斉送信がすべて届いたら「N件の宛先に送信しました」を出し、宛先ごとに履歴に残す")
    func broadcastSucceeded() async throws {
        let first = savedURL("作戦室", returning: Self.noContent)
        let second = savedURL("雑談", returning: Self.noContent)
        viewModel.broadcastTargets = [first, second]
        viewModel.inputContext = "こんにちは"

        #expect(await send(isPro: true))

        let toast = try #require(viewModel.toast)
        #expect(toast.style == .success)
        #expect(toast.message.testString == "2件の宛先に送信しました")
        // 履歴は新しい順なので、後に送った宛先が先頭
        let historyURLs = historyStore.items.map(\.url)
        #expect(historyURLs == [second.url, first.url])
        let historyResults = historyStore.items.map(\.isSuccess)
        #expect(historyResults == [true, true])
        // 一斉送信そのものが Pro 機能
        #expect(succeededCalls == [true])
    }

    @Test("一斉送信でも、画像を添付していれば宛先ごとに multipart/form-data で送る")
    func broadcastWithAttachment() async throws {
        let first = savedURL("作戦室", returning: Self.noContent)
        let second = savedURL("雑談", returning: Self.noContent)
        viewModel.broadcastTargets = [first, second]
        viewModel.inputContext = "スクリーンショット"
        viewModel.attachment = Self.attachment

        await send(isPro: true)

        for target in [first, second] {
            let url = try #require(URL(string: target.url))
            let header = try #require(contentType(of: url))
            #expect(header.hasPrefix("multipart/form-data; boundary="))
        }
    }

    @Test("一斉送信の一部が失敗したら「N件中M件の送信に失敗しました」を出し、1 件でも届けば送信後の流れを呼ぶ")
    func broadcastPartiallyFailed() async throws {
        let first = savedURL("作戦室", returning: Self.noContent)
        let second = savedURL("消えた Webhook", returning: Self.notFound)
        viewModel.broadcastTargets = [first, second]
        viewModel.inputContext = "こんにちは"

        await send(isPro: true)

        let toast = try #require(viewModel.toast)
        #expect(toast.style == .failure)
        #expect(toast.message.testString == "2件中1件の送信に失敗しました")
        let historyResults = historyStore.items.map(\.isSuccess)
        #expect(historyResults == [false, true])
        #expect(succeededCalls == [true])
    }

    @Test("一斉送信がすべて失敗したら、送信後の流れは呼ばない")
    func broadcastFailed() async throws {
        viewModel.broadcastTargets = [
            savedURL("消えた Webhook", returning: Self.notFound),
            savedURL("通信できない", returning: .error(URLError(.notConnectedToInternet)))
        ]
        viewModel.inputContext = "こんにちは"

        await send(isPro: true)

        let toast = try #require(viewModel.toast)
        #expect(toast.style == .failure)
        #expect(toast.message.testString == "2件中2件の送信に失敗しました")
        let historyResults = historyStore.items.map(\.isSuccess)
        #expect(historyResults == [false, false])
        #expect(succeededCalls.isEmpty)
    }
}
