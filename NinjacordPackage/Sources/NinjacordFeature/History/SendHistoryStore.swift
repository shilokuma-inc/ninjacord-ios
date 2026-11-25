//
//  SendHistoryStore.swift
//  NinjacordApp
//

import Foundation

/// 送信履歴の永続化を担うストア（保存先は UserDefaults。WebhookURLStore と同じ方式）。
/// Discussion #258 の決定により、保存はデフォルト OFF・新しい順に最大 20 件。
/// 送ったメッセージの編集・削除に使うメッセージ ID も、ここにだけ残す（履歴とは別には保存しない。Issue #666）
@MainActor
final class SendHistoryStore: ObservableObject {
    /// 「送信履歴を保存する」の設定のキー。設定画面の @AppStorage と共有する
    static let isEnabledKey = "isSendHistoryEnabled"
    static let maxCount = 20

    private static let storageKey = "sendHistory"

    /// 新しい順
    @Published private(set) var items: [SendHistoryEntry] = []

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        reload()
    }

    /// 送信履歴を保存する設定か。未設定なら OFF
    var isEnabled: Bool {
        userDefaults.bool(forKey: Self.isEnabledKey)
    }

    /// 「投稿済み」に出す、編集・削除できるメッセージ（新しい順）
    var postedItems: [SendHistoryEntry] {
        items.filter(\.isPosted)
    }

    func reload() {
        guard let data = userDefaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SendHistoryEntry].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    /// 送信を記録する。設定が OFF なら何もしない。最大件数を超えた古いものは捨てる
    /// - Parameters:
    ///   - messageID: Discord が作ったメッセージの ID。編集・削除に使う。送れなかった・受け取れなかったときは nil
    ///   - threadID: フォーラムに新しい投稿として送ったときの、作られたスレッドの ID。編集・削除に使う
    ///   - hasAttachment: 画像を添付して送ったか
    func record(
        url: String,
        message: MessageEntity,
        isSuccess: Bool,
        messageID: String? = nil,
        threadID: String? = nil,
        hasAttachment: Bool = false,
        at date: Date = Date()
    ) {
        guard isEnabled else { return }
        reload()
        let entry = SendHistoryEntry(
            id: UUID(),
            sentAt: date,
            url: url,
            message: message,
            isSuccess: isSuccess,
            messageID: messageID,
            threadID: threadID,
            hasAttachment: hasAttachment
        )
        items = Array(([entry] + items).prefix(Self.maxCount))
        save()
    }

    /// アプリから編集したメッセージの中身を書き換える。履歴に無ければ何もしない。
    /// 保存の設定を OFF にした後でも、残っている履歴は編集後の中身にそろえる
    func markEdited(messageID: String, message: MessageEntity, at date: Date = Date()) {
        update(messageID: messageID) { entry in
            entry.message = message
            entry.editedAt = date
        }
    }

    /// アプリから削除した（Discord で先に消されていた）メッセージに印を付ける。履歴に無ければ何もしない。
    /// 送信履歴には「削除済み」として残し、「投稿済み」からは外す
    func markDeleted(messageID: String, at date: Date = Date()) {
        update(messageID: messageID) { entry in
            entry.deletedAt = date
        }
    }

    func removeAll() {
        items = []
        userDefaults.removeObject(forKey: Self.storageKey)
    }

    /// 別の画面のストアが書き換えた分を読み直してから、そのメッセージの履歴を書き換えて保存する
    private func update(messageID: String, _ change: (inout SendHistoryEntry) -> Void) {
        reload()
        guard items.contains(where: { $0.messageID == messageID }) else {
            return
        }
        for index in items.indices where items[index].messageID == messageID {
            change(&items[index])
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
