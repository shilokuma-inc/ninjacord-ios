//
//  SavedDestinationTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 保存した宛先の見分け方（Webhook の ID・スレッド・トークンを出さない表示）と、保存・名前の変更・並び替え（Issue #674）
@MainActor
final class SavedDestinationTests {
    private let suiteName = "SavedDestinationTests.\(UUID().uuidString)"
    private let userDefaults: UserDefaults
    private let store: WebhookURLStore

    init() throws {
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
        store = WebhookURLStore(userDefaults: userDefaults)
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Webhook URL から読む

    @Test("Webhook URL から、Webhook の ID とスレッドの ID を読む")
    func webhookIDAndThreadID() throws {
        let plain = try #require(DiscordWebhookURL(string: "https://discord.com/api/webhooks/1180000000000000011/abcTOKEN"))
        #expect(plain.webhookID == "1180000000000000011")
        #expect(plain.threadID == nil)

        let thread = try #require(
            DiscordWebhookURL(string: "https://discord.com/api/v10/webhooks/123/abc?wait=true&thread_id=456")
        )
        #expect(thread.webhookID == "123")
        #expect(thread.threadID == "456")
    }

    @Test("トークンを出さない短い表示は、Webhook の ID の末尾 4 桁だけ")
    func maskedDescription() throws {
        let url = try #require(DiscordWebhookURL(string: "https://discord.com/api/webhooks/1180000000000000011/abcTOKEN"))
        #expect(url.maskedDescription == "Webhook …0011")
        #expect(!url.maskedDescription.contains("abcTOKEN"))
    }

    @Test("書き方が違っても同じ Webhook・同じスレッドなら同じ宛先、スレッドが違えば別の宛先")
    func destinationKey() {
        let key = WebhookDestinationKey(urlString: "https://discord.com/api/webhooks/123/abc")
        #expect(key == WebhookDestinationKey(urlString: "  https://discordapp.com/api/webhooks/123/abc/\n"))
        #expect(key == WebhookDestinationKey(urlString: "https://discord.com/api/webhooks/123/abc?wait=true"))
        #expect(key != WebhookDestinationKey(urlString: "https://discord.com/api/webhooks/123/abc?thread_id=9"))
        #expect(WebhookDestinationKey(urlString: "https://example.com/api/webhooks/123/abc") == nil)
    }

    // MARK: - 保存した宛先

    @Test("Webhook の名前・アイコンを覚える前（2.4.0 まで）に保存した宛先も読める")
    func decodeLegacyItem() throws {
        let legacy = #"[{"id": "8D3C5E2A-1B4F-4C6D-9E7A-2F1B3C4D5E6F", "name": "作戦室", "url": "https://discord.com/api/webhooks/1/a"}]"#
        userDefaults.set(Data(legacy.utf8), forKey: "savedWebhookURLs")

        store.reload()

        let item = try #require(store.items.first)
        #expect(item.name == "作戦室")
        #expect(item.webhookName == nil)
        #expect(item.profile == nil)
    }

    @Test("保存するときに、取得した Webhook の名前とアイコンも覚える")
    func addWithProfile() throws {
        let profile = WebhookProfile(name: "レイド告知Bot", avatarURL: URL(string: "https://cdn.discordapp.com/avatars/1/a.png"))

        let added = store.add(name: "ゲーム部 #お知らせ", url: "https://discord.com/api/webhooks/1/a", profile: profile)

        let item = try #require(WebhookURLStore(userDefaults: userDefaults).items.first)
        #expect(item == added)
        #expect(item.profile == profile)
    }

    @Test("名前を変えられる")
    func rename() throws {
        let added = store.add(name: "作戦室", url: "https://discord.com/api/webhooks/1/a")

        store.rename(id: added.id, to: "ゲーム部 #作戦室")

        #expect(try #require(WebhookURLStore(userDefaults: userDefaults).items.first).name == "ゲーム部 #作戦室")
    }

    @Test("並び順を変えられる")
    func move() {
        store.add(name: "A", url: "https://discord.com/api/webhooks/1/a")
        store.add(name: "B", url: "https://discord.com/api/webhooks/2/b")
        store.add(name: "C", url: "https://discord.com/api/webhooks/3/c")

        store.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(WebhookURLStore(userDefaults: userDefaults).items.map(\.name) == ["C", "A", "B"])
    }

    @Test("取得し直した Webhook の名前・アイコンで、覚えている値を書き換える")
    func updateProfile() throws {
        let added = store.add(name: "作戦室", url: "https://discord.com/api/webhooks/1/a")
        let profile = WebhookProfile(name: "作戦Bot", avatarURL: nil)

        store.updateProfile(id: added.id, profile: profile)

        #expect(try #require(WebhookURLStore(userDefaults: userDefaults).items.first).profile == profile)
    }

    @Test("書き方が違っても、同じ宛先の保存済みのものを見つける")
    func itemMatching() {
        let added = store.add(name: "作戦室", url: "https://discord.com/api/webhooks/1/a")
        store.add(name: "スレッド", url: "https://discord.com/api/webhooks/1/a?thread_id=9")

        #expect(store.item(matching: " https://discordapp.com/api/webhooks/1/a ") == added)
        #expect(store.item(matching: "https://discord.com/api/webhooks/1/a?thread_id=9")?.name == "スレッド")
        #expect(store.item(matching: "https://discord.com/api/webhooks/2/b") == nil)
        #expect(store.item(matching: "") == nil)
    }

    @Test("宛先を示す名前は、保存していれば付けた名前、していなければトークンを出さない短い表示")
    func displayName() {
        store.add(name: "作戦室", url: "https://discord.com/api/webhooks/1/a")

        #expect(store.displayName(for: "https://discord.com/api/webhooks/1/a") == "作戦室")
        #expect(store.displayName(for: "https://discord.com/api/webhooks/1180000000000000099/secret") == "Webhook …0099")
        #expect(store.displayName(for: "not a url") == String(localized: "不明な宛先"))
    }
}
