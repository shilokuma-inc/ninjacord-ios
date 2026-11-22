//
//  SendHistoryStoreTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信履歴（`SendHistoryStore`）。送ったメッセージの編集・削除に使う ID を残し、編集・削除の結果を書き戻す（Issue #666）
@MainActor
final class SendHistoryStoreTests {
    private let suiteName = "SendHistoryStoreTests.\(UUID().uuidString)"
    private let userDefaults: UserDefaults
    private let store: SendHistoryStore

    private static let message = MessageEntity(
        username: "レイド告知Bot",
        avatarURL: "",
        content: "今夜21:00 レイド開始",
        messageEmbedEntity: MessageEmbedEntity()
    )
    private static let url = "https://discord.com/api/webhooks/123/abc"

    init() throws {
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.set(true, forKey: SendHistoryStore.isEnabledKey)
        store = SendHistoryStore(userDefaults: userDefaults)
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    @Test("メッセージ ID と画像の添付の有無も残す")
    func recordMessageID() throws {
        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: "789", hasAttachment: true)

        let entry = try #require(SendHistoryStore(userDefaults: userDefaults).items.first)
        #expect(entry.messageID == "789")
        #expect(entry.hasAttachment)
        #expect(entry.editedAt == nil)
        #expect(entry.deletedAt == nil)
    }

    @Test("送信履歴を保存しない設定なら、ID も残さない")
    func recordWhenDisabled() {
        userDefaults.set(false, forKey: SendHistoryStore.isEnabledKey)

        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: "789")

        #expect(store.items.isEmpty)
    }

    @Test("ID を残す前（2.3.0 まで）に保存した履歴も読め、編集・削除はできないものとして扱う")
    func decodeLegacyEntry() throws {
        let legacy = """
        [{
          "id": "8D3C5E2A-1B4F-4C6D-9E7A-2F1B3C4D5E6F",
          "sentAt": 780000000,
          "url": "https://discord.com/api/webhooks/123/abc",
          "message": {
            "username": "", "avatarURL": "", "content": "こんにちは",
            "messageEmbedEntity": {"title": "", "description": "", "fields": [], "footerText": "",
                                   "imageURL": "", "thumbnailURL": "", "includesTimestamp": false}
          },
          "isSuccess": true
        }]
        """
        userDefaults.set(Data(legacy.utf8), forKey: "sendHistory")

        store.reload()

        let entry = try #require(store.items.first)
        #expect(entry.message.content == "こんにちは")
        #expect(entry.messageID == nil)
        #expect(!entry.hasAttachment)
        #expect(store.postedItems.isEmpty)
    }

    @Test("「投稿済み」には、送れて ID があり、削除していないものだけを新しい順に出す")
    func postedItems() {
        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: "1")
        store.record(url: Self.url, message: Self.message, isSuccess: false)
        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: nil)
        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: "2")
        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: "3")
        store.markDeleted(messageID: "2")

        #expect(store.postedItems.map(\.messageID) == ["3", "1"])
    }

    @Test("編集したら、中身を編集後に書き換えて編集日時を残す")
    func markEdited() throws {
        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: "789")
        var edited = Self.message
        edited.content = "今夜21:30 レイド開始（変更）"
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        store.markEdited(messageID: "789", message: edited, at: date)

        let entry = try #require(SendHistoryStore(userDefaults: userDefaults).items.first)
        #expect(entry.message == edited)
        #expect(entry.editedAt == date)
        #expect(entry.isPosted)
    }

    @Test("削除したら削除日時を残し、送信履歴には残したまま「投稿済み」から外す")
    func markDeleted() throws {
        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: "789")

        store.markDeleted(messageID: "789")

        let reloaded = SendHistoryStore(userDefaults: userDefaults)
        let entry = try #require(reloaded.items.first)
        #expect(entry.deletedAt != nil)
        #expect(reloaded.postedItems.isEmpty)
    }

    @Test("保存しない設定にした後でも、残っている履歴には編集・削除を書き戻す")
    func markAfterDisabled() throws {
        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: "789")
        userDefaults.set(false, forKey: SendHistoryStore.isEnabledKey)

        store.markDeleted(messageID: "789")

        #expect(try #require(store.items.first).deletedAt != nil)
    }

    @Test("別の画面のストアで書き換えた分を消さずに書き戻す")
    func markKeepsOtherStoreChanges() {
        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: "1")
        // 送信画面の別のストアが、あとから 1 件記録した
        SendHistoryStore(userDefaults: userDefaults)
            .record(url: Self.url, message: Self.message, isSuccess: true, messageID: "2")

        store.markDeleted(messageID: "1")

        #expect(SendHistoryStore(userDefaults: userDefaults).postedItems.map(\.messageID) == ["2"])
    }

    @Test("履歴に無い ID なら何もしない")
    func markUnknownMessage() {
        store.record(url: Self.url, message: Self.message, isSuccess: true, messageID: "1")

        store.markDeleted(messageID: "999")

        #expect(store.postedItems.map(\.messageID) == ["1"])
    }
}
