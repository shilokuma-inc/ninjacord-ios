//
//  SendMessageDefaultValueConfirmationTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// アプリの初期文言で送る前の確認ダイアログ（Discussion #559 の Q3・Q4）
@MainActor
final class SendMessageDefaultValueConfirmationTests {
    private let fixture: SendMessageViewModelFixture
    private var viewModel: SendMessageViewModel { fixture.viewModel }
    private var setting: DefaultValueConfirmationSetting {
        DefaultValueConfirmationSetting(userDefaults: fixture.userDefaults)
    }

    private static let noContent = StubURLProtocol.Stub.response(statusCode: 204, data: Data())
    private static let attachment = ImageAttachment(
        data: Data([0x89, 0x50, 0x4E, 0x47]),
        fileName: "image.png",
        mimeType: "image/png"
    )

    init() throws {
        fixture = try SendMessageViewModelFixture()
        // Fixture は確認を切っているので、既定（オン）に戻す
        fixture.userDefaults.removeObject(forKey: DefaultValueConfirmationSetting.isEnabledKey)
    }

    /// 送信先を決めた URL を URL 欄に入れ、その URL を返す
    @discardableResult
    private func inputURL() -> URL {
        let url = StubURLProtocol.makeURL(returning: Self.noContent)
        viewModel.inputURL = url.absoluteString
        return url
    }

    private func requests(to url: URL) -> Int {
        StubURLProtocol.requests(to: url).count
    }

    private func confirm(disablesConfirmation: Bool = false) async -> Bool {
        let task = viewModel.confirmDefaultValueSend(
            disablesConfirmation: disablesConfirmation,
            screenActions: fixture.screenActions
        )
        await task?.value
        return task != nil
    }

    // MARK: - 設定

    @Test("確認の設定は、未設定ならオン")
    func settingIsEnabledByDefault() {
        #expect(setting.isEnabled)
        setting.isEnabled = false
        #expect(!setting.isEnabled)
        #expect(fixture.userDefaults.bool(forKey: DefaultValueConfirmationSetting.isEnabledKey) == false)
    }

    // MARK: - 確認を出すか

    @Test("名前が空なら、確認ダイアログを出して送らない")
    func emptyUsernameShowsConfirmation() async throws {
        let url = inputURL()
        viewModel.inputContext = "こんにちは"

        #expect(await fixture.send() == false)

        #expect(viewModel.isDefaultValueConfirmationPresented)
        let confirmation = try #require(viewModel.defaultValueConfirmation)
        #expect(confirmation.defaultedFields == [.username])
        #expect(confirmation.message.contains("以下、名無しにかわりましてVIPがお送りします"))
        #expect(requests(to: url) == 0)
        #expect(!viewModel.isSending)
    }

    @Test("名前・本文が空なら、本文に送られる値を両方出す")
    func emptyUsernameAndContentShowsBothValues() async throws {
        inputURL()
        viewModel.inputAvatarURL = "https://example.com/avatar.png"

        await fixture.send()

        let confirmation = try #require(viewModel.defaultValueConfirmation)
        #expect(confirmation.defaultedFields == [.username, .content])
        #expect(confirmation.message.contains("以下、名無しにかわりましてVIPがお送りします"))
        #expect(confirmation.message.contains("なんか書いてね"))
    }

    @Test("名前・本文が入っていれば、確認を出さずに送る。プロフィール画像が空でも出さない")
    func filledMessageIsSentWithoutConfirmation() async {
        let url = inputURL()
        viewModel.inputUsername = "忍者"
        viewModel.inputContext = "こんにちは"

        #expect(await fixture.send())

        #expect(!viewModel.isDefaultValueConfirmationPresented)
        #expect(viewModel.defaultValueConfirmation == nil)
        #expect(requests(to: url) == 1)
    }

    @Test("本文が空でも、名前と埋め込みがあれば確認を出さずに送る")
    func embedOnlyWithUsernameIsSentWithoutConfirmation() async {
        let url = inputURL()
        viewModel.inputUsername = "忍者"
        viewModel.inputEmbed = MessageEmbedEntity(title: "お知らせ")

        #expect(await fixture.send())
        #expect(requests(to: url) == 1)
    }

    @Test("本文が空でも、名前と画像があれば確認を出さずに送る")
    func attachmentOnlyWithUsernameIsSentWithoutConfirmation() async {
        let url = inputURL()
        viewModel.inputUsername = "忍者"
        viewModel.attachment = Self.attachment

        #expect(await fixture.send())
        #expect(requests(to: url) == 1)
    }

    @Test("確認の設定がオフなら、名前が空でも確認を出さずに送る")
    func settingOffSendsWithoutConfirmation() async {
        setting.isEnabled = false
        let url = inputURL()
        viewModel.inputContext = "こんにちは"

        #expect(await fixture.send())

        #expect(!viewModel.isDefaultValueConfirmationPresented)
        #expect(requests(to: url) == 1)
    }

    @Test("入力チェックで止まるときは、確認ダイアログより入力エラーを出す")
    func validationErrorComesFirst() async {
        viewModel.inputURL = ""

        #expect(await fixture.send() == false)

        #expect(viewModel.validationError == .emptyURL)
        #expect(!viewModel.isDefaultValueConfirmationPresented)
    }

    @Test("確認を出すときも、送信ボタンを押したときに 1 回だけ振動させる")
    func hapticsOnceWhenConfirming() async {
        inputURL()
        viewModel.inputContext = "こんにちは"

        await fixture.send()
        await confirm()

        #expect(fixture.haptics.impactCount == 1)
    }

    // MARK: - ダイアログのボタン

    @Test("「このまま送信」で、ボタンを押した時点の中身を送る。設定はオンのまま")
    func confirmSendsPendingMessage() async throws {
        let url = inputURL()
        viewModel.inputContext = "こんにちは"
        await fixture.send()
        // ダイアログを開いたまま入力が変わっても、押した時点の中身を送る
        viewModel.inputContext = "書き換えた本文"
        viewModel.inputURL = "https://discord.com/api/webhooks/999/other"

        #expect(await confirm())

        #expect(viewModel.defaultValueConfirmation == nil)
        #expect(requests(to: url) == 1)
        let body = try #require(StubURLProtocol.requests(to: url).first?.body)
        let parameters = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(parameters["content"] as? String == "こんにちは")
        #expect(parameters["username"] as? String == "以下、名無しにかわりましてVIPがお送りします")
        #expect(setting.isEnabled)
        // 送信履歴には入力したそのままの値（空の名前）を残す
        #expect(fixture.historyStore.items.first?.message.username == "")
    }

    @Test("「キャンセル」では送らず、入力も消さない")
    func cancelDoesNotSend() async {
        let url = inputURL()
        viewModel.inputContext = "こんにちは"
        await fixture.send()

        viewModel.cancelDefaultValueSend()

        #expect(viewModel.defaultValueConfirmation == nil)
        #expect(await confirm() == false)
        #expect(requests(to: url) == 0)
        #expect(viewModel.inputContext == "こんにちは")
        #expect(setting.isEnabled)
    }

    @Test("「送信して今後は表示しない」で設定をオフにして送り、次からは確認を出さない")
    func confirmAndDisable() async {
        let url = inputURL()
        viewModel.inputContext = "こんにちは"
        await fixture.send()

        #expect(await confirm(disablesConfirmation: true))

        #expect(!setting.isEnabled)
        #expect(requests(to: url) == 1)

        viewModel.isDefaultValueConfirmationPresented = false
        #expect(await fixture.send())
        #expect(!viewModel.isDefaultValueConfirmationPresented)
        #expect(requests(to: url) == 2)
    }

    @Test("設定をオンに戻せば、次の送信で再び確認を出す")
    func reEnabledSettingShowsConfirmationAgain() async {
        setting.isEnabled = false
        let url = inputURL()
        viewModel.inputContext = "こんにちは"
        await fixture.send()
        #expect(requests(to: url) == 1)

        setting.isEnabled = true
        #expect(await fixture.send() == false)
        #expect(viewModel.isDefaultValueConfirmationPresented)
        #expect(requests(to: url) == 1)
    }

    // MARK: - 一斉送信

    @Test("一斉送信でも、名前が空なら確認を出し、「このまま送信」で全宛先に送る")
    func broadcastShowsConfirmation() async {
        let first = fixture.savedURL("作戦室", returning: Self.noContent)
        let second = fixture.savedURL("雑談", returning: Self.noContent)
        viewModel.broadcastTargets = [first, second]
        viewModel.inputContext = "こんにちは"

        #expect(await fixture.send(isPro: true) == false)
        #expect(viewModel.isDefaultValueConfirmationPresented)
        #expect(viewModel.defaultValueConfirmation?.defaultedFields == [.username])

        #expect(await confirm())
        #expect(fixture.historyStore.items.map(\.isSuccess) == [true, true])
    }

    @Test("一斉送信でも、名前・本文が入っていれば確認を出さずに送る")
    func broadcastWithoutConfirmation() async {
        viewModel.broadcastTargets = [fixture.savedURL("作戦室", returning: Self.noContent)]
        viewModel.inputUsername = "忍者"
        viewModel.inputContext = "こんにちは"

        #expect(await fixture.send(isPro: true))
        #expect(!viewModel.isDefaultValueConfirmationPresented)
    }
}
