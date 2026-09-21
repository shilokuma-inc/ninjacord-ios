//
//  WebhookURLStore.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2026/09/21.
//

import Foundation

/// 保存済み Webhook URL の永続化を担うストア（保存先は UserDefaults）
@MainActor
final class WebhookURLStore: ObservableObject {
    private static let storageKey = "savedWebhookURLs"

    @Published private(set) var items: [SavedWebhookURL] = []

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        reload()
    }

    /// UserDefaults から一覧を再読込する（別画面で追加・削除された内容を反映するため）
    func reload() {
        guard let data = userDefaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SavedWebhookURL].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    func add(name: String, url: String) {
        items.append(SavedWebhookURL(id: UUID(), name: name, url: url))
        save()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    func remove(id: SavedWebhookURL.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
