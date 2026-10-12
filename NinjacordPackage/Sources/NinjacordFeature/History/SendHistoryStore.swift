//
//  SendHistoryStore.swift
//  NinjacordApp
//

import Foundation

/// 送信履歴の永続化を担うストア（保存先は UserDefaults。WebhookURLStore と同じ方式）。
/// Discussion #258 の決定により、保存はデフォルト OFF・新しい順に最大 20 件
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

    func reload() {
        guard let data = userDefaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SendHistoryEntry].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    /// 送信を記録する。設定が OFF なら何もしない。最大件数を超えた古いものは捨てる
    func record(url: String, message: MessageEntity, isSuccess: Bool, at date: Date = Date()) {
        guard isEnabled else { return }
        reload()
        let entry = SendHistoryEntry(id: UUID(), sentAt: date, url: url, message: message, isSuccess: isSuccess)
        items = Array(([entry] + items).prefix(Self.maxCount))
        save()
    }

    func removeAll() {
        items = []
        userDefaults.removeObject(forKey: Self.storageKey)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
