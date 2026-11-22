//
//  DestinationDisplayTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信画面の宛先カードに出す内容（`DestinationDisplay`）。URL（トークン）は出さず、名前で示す（Issue #674）
struct DestinationDisplayTests {
    private static let url = "https://discord.com/api/webhooks/1180000000000000011/secretTOKEN"
    private static let webhookName = "レイド告知Bot"
    private static let profile = WebhookProfile(name: webhookName, avatarURL: URL(string: "https://cdn.discordapp.com/a.png"))
    /// 実装と同じ、名前を差し込むローカライズのキーで期待値を作る
    private static let webhookSubtitle = String(localized: "Webhook「\(webhookName)」")

    @Test("宛先が空なら、選ぶよう案内する")
    func empty() {
        let display = DestinationDisplay.resolve(url: "  ", saved: nil, profile: nil)
        #expect(display.state == .empty)
        #expect(display.title == String(localized: "宛先を選んでください"))
    }

    @Test("保存した宛先なら付けた名前を出し、下に Webhook の名前を出す")
    func saved() {
        let saved = SavedWebhookURL(id: UUID(), name: "ゲーム部 #お知らせ", url: Self.url, webhookName: "レイド告知Bot")
        let display = DestinationDisplay.resolve(url: Self.url, saved: saved, profile: nil)
        #expect(display.state == .saved)
        #expect(display.title == "ゲーム部 #お知らせ")
        #expect(display.subtitle == Self.webhookSubtitle)
    }

    @Test("保存した宛先で Webhook の名前をまだ覚えていなければ、取得したものを使い、無ければ短い表示にする")
    func savedWithoutCachedProfile() {
        let saved = SavedWebhookURL(id: UUID(), name: "ゲーム部 #お知らせ", url: Self.url)
        let fetched = DestinationDisplay.resolve(url: Self.url, saved: saved, profile: Self.profile)
        #expect(fetched.subtitle == Self.webhookSubtitle)
        #expect(fetched.avatarURL == "https://cdn.discordapp.com/a.png")

        let notFetched = DestinationDisplay.resolve(url: Self.url, saved: saved, profile: nil)
        #expect(notFetched.subtitle == "Webhook …0011")
    }

    @Test("保存していない Webhook URL なら、取得した Webhook の名前と短い表示を出し、トークンは出さない")
    func unsaved() throws {
        let display = DestinationDisplay.resolve(url: Self.url, saved: nil, profile: Self.profile)
        #expect(display.state == .unsaved)
        #expect(display.title == "レイド告知Bot")
        #expect(display.subtitle == "Webhook …0011")
        #expect(!display.title.contains("secretTOKEN"))
        #expect(try #require(display.subtitle).contains("secretTOKEN") == false)
    }

    @Test("保存していない Webhook をまだ取得していなければ、「保存していない宛先」と出す")
    func unsavedNotFetched() {
        let display = DestinationDisplay.resolve(url: Self.url, saved: nil, profile: nil)
        #expect(display.title == String(localized: "保存していない宛先"))
    }

    @Test("スレッドに送る URL なら、スレッドの印を出す")
    func thread() {
        let display = DestinationDisplay.resolve(url: Self.url + "?thread_id=9", saved: nil, profile: nil)
        #expect(display.isThread)
    }

    @Test("Webhook URL の形でなければ、形式が違うと出す")
    func invalid() {
        let display = DestinationDisplay.resolve(url: "https://example.com/hook", saved: nil, profile: nil)
        #expect(display.state == .invalid)
        #expect(display.subtitle == String(localized: "Webhook URLの形式ではありません"))
    }
}
