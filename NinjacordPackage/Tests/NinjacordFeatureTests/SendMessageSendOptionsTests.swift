//
//  SendMessageSendOptionsTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信画面の送信オプション（`SendMessageViewModel.inputSendOptions`）が、送る中身・テンプレートに入ること（Issue #698）
@MainActor
final class SendMessageSendOptionsTests {
    private let fixture: SendMessageViewModelFixture
    private var viewModel: SendMessageViewModel { fixture.viewModel }

    init() throws {
        fixture = try SendMessageViewModelFixture()
    }

    private static let noContent = StubURLProtocol.Stub.response(statusCode: 204, data: Data())
    private static let options = MessageSendOptions(
        suppressesNotifications: true,
        suppressesEmbeds: true,
        suppressesEveryoneMentions: true
    )

    /// その URL に最初に送った JSON の本文
    private func sentJSON(to url: URL) throws -> NSDictionary {
        let body = try #require(StubURLProtocol.requests(to: url).first?.body)
        return try #require(try JSONSerialization.jsonObject(with: body) as? NSDictionary)
    }

    @Test("送信・テンプレート保存用のメッセージに、送信オプションも入れる")
    func currentMessageIncludesOptions() {
        viewModel.inputSendOptions = Self.options

        #expect(viewModel.currentMessage.sendOptions == Self.options)
    }

    @Test("テンプレートを反映すると、送信オプションもテンプレートのものにする")
    func applyTemplateOptions() {
        let message = MessageEntity(
            username: "",
            avatarURL: "",
            content: "テンプレートの本文",
            messageEmbedEntity: MessageEmbedEntity(),
            sendOptions: Self.options
        )
        viewModel.applyTemplate(MessageTemplate(id: UUID(), name: "定型", message: message, createdAt: Date()))
        #expect(viewModel.inputSendOptions == Self.options)

        // オプションを追加する前に保存したテンプレート（すべてオフ）を反映すると、オフに戻す
        let legacy = MessageEntity(
            username: "",
            avatarURL: "",
            content: "前の本文",
            messageEmbedEntity: MessageEmbedEntity()
        )
        viewModel.applyTemplate(MessageTemplate(id: UUID(), name: "古い定型", message: legacy, createdAt: Date()))
        #expect(viewModel.inputSendOptions == MessageSendOptions())
    }

    @Test("送信オプションを付けて送り、送信履歴にも残す")
    func sendWithOptions() async throws {
        let url = StubURLProtocol.makeURL(returning: Self.noContent)
        viewModel.inputURL = url.absoluteString
        viewModel.inputContext = "こんにちは"
        viewModel.inputSendOptions = Self.options

        #expect(await fixture.send())

        let json = try sentJSON(to: url)
        #expect(json["flags"] as? Int == (1 << 12) | (1 << 2))
        #expect(json["allowed_mentions"] as? NSDictionary == ["parse": ["users", "roles"]])
        #expect(fixture.historyStore.items.first?.message.sendOptions == Self.options)
    }

    @Test("一斉送信でも、すべての宛先に同じ送信オプションで送る")
    func broadcastWithOptions() async throws {
        let first = fixture.savedURL("作戦室", returning: Self.noContent)
        let second = fixture.savedURL("雑談", returning: Self.noContent)
        viewModel.broadcastTargets = [first, second]
        viewModel.inputContext = "こんにちは"
        viewModel.inputSendOptions = MessageSendOptions(suppressesNotifications: true)

        #expect(await fixture.send(isPro: true))

        for target in [first, second] {
            let json = try sentJSON(to: try #require(URL(string: target.url)))
            #expect(json["flags"] as? Int == 1 << 12)
            #expect(json["allowed_mentions"] == nil)
        }
    }
}
