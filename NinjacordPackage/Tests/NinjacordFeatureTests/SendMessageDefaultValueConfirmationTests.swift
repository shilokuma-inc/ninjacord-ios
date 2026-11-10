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

    @discardableResult
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

    @Test("本文・埋め込み・画像が無ければ、確認ダイアログに本文の初期文言を出して送らない")
    func emptyContentShowsConfirmation() async throws {
        let url = inputURL()
        viewModel.inputUsername = "忍者"

        #expect(await fixture.send() == false)

        #expect(viewModel.isDefaultValueConfirmationPresented)
        let confirmation = try #require(viewModel.defaultValueConfirmation)
        #expect(confirmation.defaultedFields == [.content])
        #expect(confirmation.message.contains("なんか書いてね"))
        #expect(requests(to: url) == 0)
        #expect(!viewModel.isSending)
    }

    /// 名前は空なら送らず Webhook の名前で出るので、初期文言に置き換えない（Discussion #586 の Q7）
    @Test("名前・本文が空なら、本文の初期文言だけを出す")
    func emptyUsernameAndContentShowsContentValueOnly() async throws {
        inputURL()
        viewModel.inputAvatarURL = "https://example.com/avatar.png"

        await fixture.send()

        let confirmation = try #require(viewModel.defaultValueConfirmation)
        #expect(confirmation.defaultedFields == [.content])
        #expect(confirmation.message.contains("なんか書いてね"))
        #expect(!confirmation.message.contains("以下、名無しにかわりましてVIPがお送りします"))
    }

    @Test("名前が空なだけなら、確認を出さずに送る")
    func emptyUsernameIsSentWithoutConfirmation() async {
        let url = inputURL()
        viewModel.inputContext = "こんにちは"

        #expect(await fixture.send())

        #expect(!viewModel.isDefaultValueConfirmationPresented)
        #expect(viewModel.defaultValueConfirmation == nil)
        #expect(requests(to: url) == 1)
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

    @Test("本文が空でも、埋め込みがあれば確認を出さずに送る。名前が空でも出さない")
    func embedOnlyIsSentWithoutConfirmation() async {
        let url = inputURL()
        viewModel.inputEmbed = MessageEmbedEntity(title: "お知らせ")

        #expect(await fixture.send())
        #expect(requests(to: url) == 1)
    }

    @Test("本文が空でも、画像があれば確認を出さずに送る。名前が空でも出さない")
    func attachmentOnlyIsSentWithoutConfirmation() async {
        let url = inputURL()
        viewModel.attachment = Self.attachment

        #expect(await fixture.send())
        #expect(requests(to: url) == 1)
    }

    @Test("確認の設定がオフなら、本文が空でも確認を出さずに送る")
    func settingOffSendsWithoutConfirmation() async {
        setting.isEnabled = false
        let url = inputURL()
        viewModel.inputUsername = "忍者"

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
        viewModel.inputUsername = "忍者"

        await fixture.send()
        await confirm()

        #expect(fixture.haptics.impactCount == 1)
    }

    // MARK: - ダイアログのボタン

    @Test("「このまま送信」で、ボタンを押した時点の中身を送る。設定はオンのまま")
    func confirmSendsPendingMessage() async throws {
        let url = inputURL()
        // すべて空だと入力チェックで止まるので、名前は空のままプロフィール画像の URL を入れる
        viewModel.inputAvatarURL = "https://example.com/avatar.png"
        await fixture.send()
        // ダイアログを開いたまま入力が変わっても、押した時点の中身を送る
        viewModel.inputUsername = "書き換えた名前"
        viewModel.inputContext = "書き換えた本文"
        viewModel.inputURL = "https://discord.com/api/webhooks/999/other"

        #expect(await confirm())

        #expect(viewModel.defaultValueConfirmation == nil)
        #expect(requests(to: url) == 1)
        let body = try #require(StubURLProtocol.requests(to: url).first?.body)
        let parameters = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(parameters["content"] as? String == "なんか書いてね")
        // 名前が空なら username を送らず、Webhook の名前で出す
        #expect(parameters["username"] == nil)
        #expect(setting.isEnabled)
        // 送信履歴には入力したそのままの値（空の名前・本文）を残す
        #expect(fixture.historyStore.items.first?.message.username == "")
        #expect(fixture.historyStore.items.first?.message.content == "")
    }

    @Test("「キャンセル」では送らず、入力も消さない")
    func cancelDoesNotSend() async {
        let url = inputURL()
        viewModel.inputUsername = "忍者"
        await fixture.send()

        viewModel.cancelDefaultValueSend()

        #expect(viewModel.defaultValueConfirmation == nil)
        #expect(await confirm() == false)
        #expect(requests(to: url) == 0)
        #expect(viewModel.inputUsername == "忍者")
        #expect(setting.isEnabled)
    }

    @Test("「送信して今後は表示しない」で設定をオフにして送り、次からは確認を出さない")
    func confirmAndDisable() async {
        let url = inputURL()
        viewModel.inputUsername = "忍者"
        await fixture.send()

        #expect(await confirm(disablesConfirmation: true))

        #expect(!setting.isEnabled)
        #expect(requests(to: url) == 1)

        // 画面では、ボタンを押すと SwiftUI のアラートが閉じてこの値を戻す。ViewModel は戻さないので、ここで閉じる
        viewModel.isDefaultValueConfirmationPresented = false
        #expect(await fixture.send())
        #expect(!viewModel.isDefaultValueConfirmationPresented)
        #expect(requests(to: url) == 2)
    }

    /// 画像を添付していれば確認を出さないので、確認を出すのは画像が無いときだけ
    @Test("ダイアログを開いたまま画像を付けても、押した時点の中身（画像なし）で送る")
    func confirmSendsPendingAttachment() async throws {
        let url = inputURL()
        viewModel.inputUsername = "忍者"
        await fixture.send()

        viewModel.attachment = Self.attachment
        #expect(await confirm())

        let request = try #require(StubURLProtocol.requests(to: url).first?.request)
        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType == "application/json")
    }

    /// 設定画面の @AppStorage は同じキーに Bool を書く
    @Test("「今後は表示しない」の後に設定画面と同じキーでオンに戻せば、次の送信で再び確認を出す")
    func reEnabledFromSettingViewKey() async {
        let url = inputURL()
        viewModel.inputUsername = "忍者"
        await fixture.send()
        await confirm(disablesConfirmation: true)
        #expect(requests(to: url) == 1)

        fixture.userDefaults.set(true, forKey: DefaultValueConfirmationSetting.isEnabledKey)
        viewModel.isDefaultValueConfirmationPresented = false
        #expect(await fixture.send() == false)
        #expect(viewModel.isDefaultValueConfirmationPresented)
        #expect(requests(to: url) == 1)
    }

    @Test("設定をオンに戻せば、次の送信で再び確認を出す")
    func reEnabledSettingShowsConfirmationAgain() async {
        setting.isEnabled = false
        let url = inputURL()
        viewModel.inputUsername = "忍者"
        await fixture.send()
        #expect(requests(to: url) == 1)

        setting.isEnabled = true
        #expect(await fixture.send() == false)
        #expect(viewModel.isDefaultValueConfirmationPresented)
        #expect(requests(to: url) == 1)
    }

    // MARK: - 一斉送信

    @Test("一斉送信でも、本文が空なら確認を出し、「このまま送信」で全宛先に送る")
    func broadcastShowsConfirmation() async {
        let first = fixture.savedURL("作戦室", returning: Self.noContent)
        let second = fixture.savedURL("雑談", returning: Self.noContent)
        viewModel.broadcastTargets = [first, second]
        viewModel.inputUsername = "忍者"

        #expect(await fixture.send(isPro: true) == false)
        #expect(viewModel.isDefaultValueConfirmationPresented)
        #expect(viewModel.defaultValueConfirmation?.defaultedFields == [.content])

        #expect(await confirm())
        #expect(fixture.historyStore.items.map(\.isSuccess) == [true, true])
    }

    @Test("一斉送信でダイアログを開いたまま宛先を変えても、押した時点の宛先に送る")
    func broadcastConfirmSendsPendingTargets() async {
        let first = fixture.savedURL("作戦室", returning: Self.noContent)
        let second = fixture.savedURL("雑談", returning: Self.noContent)
        viewModel.broadcastTargets = [first, second]
        viewModel.inputUsername = "忍者"
        await fixture.send(isPro: true)

        viewModel.broadcastTargets = [first]
        #expect(await confirm())

        #expect(fixture.historyStore.items.map(\.url) == [second.url, first.url])
    }

    @Test("一斉送信で「送信して今後は表示しない」を押すと、設定をオフにして全宛先に送る")
    func broadcastConfirmAndDisable() async {
        let first = fixture.savedURL("作戦室", returning: Self.noContent)
        let second = fixture.savedURL("雑談", returning: Self.noContent)
        viewModel.broadcastTargets = [first, second]
        viewModel.inputUsername = "忍者"
        await fixture.send(isPro: true)

        #expect(await confirm(disablesConfirmation: true))

        #expect(!setting.isEnabled)
        #expect(fixture.historyStore.items.map(\.isSuccess) == [true, true])
    }

    @Test("一斉送信でも、本文が入っていれば名前が空でも確認を出さずに送る")
    func broadcastWithoutConfirmation() async {
        viewModel.broadcastTargets = [fixture.savedURL("作戦室", returning: Self.noContent)]
        viewModel.inputContext = "こんにちは"

        #expect(await fixture.send(isPro: true))
        #expect(!viewModel.isDefaultValueConfirmationPresented)
    }
}
