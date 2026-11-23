//
//  SendMessageInvalidURLTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信先の Webhook URL を URL にできないときの送信（#472）。
/// 以前は代わりに apple.com に送っていたので、送らずに失敗にすること、入力チェックと同じく前後の空白を除いて送ることを確かめる
@MainActor
final class SendMessageInvalidURLTests {
    private let fixture: SendMessageViewModelFixture
    private var viewModel: SendMessageViewModel { fixture.viewModel }

    private static let noContent = StubURLProtocol.Stub.response(statusCode: 204, data: Data())
    /// 以前、URL にできない宛先の代わりに送っていた先
    private static let appleURL = URL(string: "https://www.apple.com/")

    init() throws {
        fixture = try SendMessageViewModelFixture()
    }

    /// apple.com に送っていないか
    private func expectNoRequestToApple() throws {
        let appleURL = try #require(Self.appleURL)
        #expect(StubURLProtocol.requests(to: appleURL).isEmpty)
    }

    @Test("URL の前後に空白・改行があっても、入力チェックと同じく除いた URL に送る")
    func sendTrimsURL() async throws {
        let url = StubURLProtocol.makeURL(returning: Self.noContent)
        viewModel.inputURL = " \(url.absoluteString) \n"
        viewModel.inputContext = "こんにちは"

        await fixture.send()

        #expect(StubURLProtocol.requests(to: url).count == 1)
        let toast = try #require(viewModel.toast)
        #expect(toast.style == .success)
        try expectNoRequestToApple()
    }

    @Test("URL にできない宛先には送らず、invalidToken で失敗にする。Analytics には失敗として残す")
    func postToInvalidURL() async throws {
        let message = MessageEntity(
            username: "",
            avatarURL: "",
            content: "こんにちは",
            messageEmbedEntity: MessageEmbedEntity()
        )
        let result = await viewModel.postDiscordWebhook(url: "", messageEntity: message)

        guard case .failure(let error) = result else {
            Issue.record("送信が成功した")
            return
        }
        #expect(error == .invalidToken)
        #expect(fixture.analytics.sendEvents == [AnalyticsSpy.SendEvent(isSuccess: false, httpStatus: nil)])
        try expectNoRequestToApple()
    }

    @Test("一斉送信で URL にできない宛先は、入力チェックを通らなくても送らずに失敗にする")
    func broadcastInvalidTarget() async throws {
        let first = fixture.savedURL("作戦室", returning: Self.noContent)
        let broken = SavedWebhookURL(id: UUID(), name: "壊れた URL", url: "")
        viewModel.broadcastTargets = [first, broken]
        viewModel.inputContext = "こんにちは"

        await fixture.send(isPro: true)

        let toast = try #require(viewModel.toast)
        #expect(toast.style == .failure)
        #expect(toast.message.testString == "2件中1件の送信に失敗しました")
        #expect(fixture.historyStore.items.map(\.isSuccess) == [false, true])
        try expectNoRequestToApple()
    }
}
