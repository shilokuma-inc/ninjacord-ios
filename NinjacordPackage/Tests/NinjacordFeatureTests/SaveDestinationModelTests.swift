//
//  SaveDestinationModelTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 宛先を保存する画面の状態（`SaveDestinationModel`）。貼り付けた URL を取得して確かめ、名前を入れておき、二重に保存させない（Issue #674）
@MainActor
final class SaveDestinationModelTests {
    private let suiteName = "SaveDestinationModelTests.\(UUID().uuidString)"
    private let userDefaults: UserDefaults
    private let store: WebhookURLStore

    init() throws {
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
        store = WebhookURLStore(userDefaults: userDefaults)
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    private func makeModel(url: String = "") -> SaveDestinationModel {
        SaveDestinationModel(
            initialURL: url,
            store: store,
            client: WebhookProfileClient(session: StubURLProtocol.session),
            sleep: { _ in }
        )
    }

    /// 取得すると Webhook を返す URL
    private func webhookURL(name: String = "レイド告知Bot") -> URL {
        StubURLProtocol.makeSnowflakeURL(
            returning: .response(statusCode: 200, data: Data(#"{"id": "1", "name": "\#(name)", "avatar": null}"#.utf8))
        )
    }

    @Test("何も入れていなければ確かめず、保存もできない")
    func empty() async {
        let model = makeModel()

        await model.checkURL()

        #expect(model.check == .empty)
        #expect(!model.canSave)
    }

    @Test("Webhook URL の形でなければ通信せずに知らせる")
    func invalidFormat() async {
        let model = makeModel(url: "https://example.com/hooks/1")

        await model.checkURL()

        #expect(model.check == .invalidFormat)
        #expect(!model.canSave)
    }

    @Test("取得できたら Webhook の名前を名前の欄に入れ、保存できる")
    func validFillsName() async throws {
        let model = makeModel(url: webhookURL().absoluteString)

        await model.checkURL()

        #expect(model.check == .valid(WebhookProfile(name: "レイド告知Bot", avatarURL: nil)))
        #expect(model.name == "レイド告知Bot")
        #expect(model.canSave)
    }

    @Test("名前を自分で入れていたら、取得した Webhook の名前で上書きしない")
    func keepsEditedName() async {
        let model = makeModel(url: webhookURL().absoluteString)
        model.setName("ゲーム部 #お知らせ")

        await model.checkURL()

        #expect(model.name == "ゲーム部 #お知らせ")
    }

    @Test(
        "Webhook が無い・トークンが違うときは理由を出し、保存できない",
        arguments: [(404, SaveDestinationModel.Check.notFound), (401, .invalidToken), (400, .invalidToken)]
    )
    func failure(statusCode: Int, expected: SaveDestinationModel.Check) async {
        let url = StubURLProtocol.makeSnowflakeURL(returning: .response(statusCode: statusCode, data: Data()))
        let model = makeModel(url: url.absoluteString)
        model.setName("作戦室")

        await model.checkURL()

        #expect(model.check == expected)
        #expect(!model.canSave)
    }

    @Test("通信できず確かめられなかったときは、名前があれば保存できる（オフラインでも保存できるように）")
    func unreachable() async {
        let url = StubURLProtocol.makeSnowflakeURL(returning: .error(URLError(.notConnectedToInternet)))
        let model = makeModel(url: url.absoluteString)

        await model.checkURL()
        #expect(model.check == .unreachable)
        #expect(!model.canSave)

        model.setName("作戦室")
        #expect(model.canSave)
    }

    @Test("同じ宛先を保存済みなら、保存できない")
    func duplicate() async throws {
        let url = webhookURL()
        let saved = store.add(name: "作戦室", url: url.absoluteString)
        let model = makeModel(url: url.absoluteString + "  ")

        await model.checkURL()

        #expect(model.duplicate == saved)
        #expect(!model.canSave)
        #expect(model.save() == nil)
    }

    @Test("保存すると、取得した Webhook の名前とアイコンも一緒に覚える")
    func save() async throws {
        let url = webhookURL()
        let model = makeModel(url: "  " + url.absoluteString)
        await model.checkURL()
        model.setName("ゲーム部 #お知らせ")

        let saved = try #require(model.save())

        #expect(saved.name == "ゲーム部 #お知らせ")
        #expect(saved.url == url.absoluteString)
        #expect(saved.webhookName == "レイド告知Bot")
        #expect(WebhookURLStore(userDefaults: userDefaults).items == [saved])
    }

    @Test("URL を書き換えたら、確かめ直すまでは前の URL の結果を使わず、保存もできない")
    func resetsCheckWhenURLChanges() async {
        let model = makeModel(url: webhookURL().absoluteString)
        await model.checkURL()
        #expect(model.canSave)

        model.url = webhookURL(name: "別のWebhook").absoluteString

        #expect(model.check == .checking)
        #expect(!model.canSave)

        model.url = ""
        #expect(model.check == .empty)
    }

    @Test("取得している間に URL が書き換えられたら、古い結果は使わない")
    func ignoresStaleResult() async {
        let first = webhookURL(name: "古いWebhook")
        var model: SaveDestinationModel?
        // 取得の前の待ちの間に、別の URL に書き換えられたことにする
        model = SaveDestinationModel(
            initialURL: first.absoluteString,
            store: store,
            client: WebhookProfileClient(session: StubURLProtocol.session),
            sleep: { _ in model?.url = "https://discord.com/api/webhooks/2/other" }
        )

        await model?.checkURL()

        #expect(model?.check == .checking)
        #expect(model?.name.isEmpty == true)
    }
}
