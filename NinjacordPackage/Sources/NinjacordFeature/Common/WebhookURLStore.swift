//
//  WebhookURLStore.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2026/09/21.
//

import Foundation

/// 保存した宛先（Webhook URL）の永続化を担うストア（保存先は UserDefaults）
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

    /// 宛先を保存する。取得できた Webhook の名前・アイコンも一緒に覚える
    @discardableResult
    func add(name: String, url: String, profile: WebhookProfile? = nil) -> SavedWebhookURL {
        let item = SavedWebhookURL(
            id: UUID(),
            name: name,
            url: url,
            webhookName: profile?.name,
            avatarURL: profile?.avatarURL?.absoluteString
        )
        items.append(item)
        save()
        return item
    }

    /// 表示中の一覧の位置で消す。位置は表示中の一覧のものなので、先に消す宛先を決めてから読み直して消す
    /// （別の画面で覚えた Webhook の名前などを、表示中の古い一覧で上書きしないように）
    func remove(at offsets: IndexSet) {
        let ids = Set(offsets.map { items[$0].id })
        reload()
        items.removeAll { ids.contains($0.id) }
        save()
    }

    /// 別の画面のストアが書き換えた分（覚えた Webhook の名前など）を消さないよう、読み直してから消す
    func remove(id: SavedWebhookURL.ID) {
        reload()
        items.removeAll { $0.id == id }
        save()
    }

    /// 付けた名前を変える
    func rename(id: SavedWebhookURL.ID, to name: String) {
        update(id: id) { $0.name = name }
    }

    /// 一覧の並び順を変える（送信画面の宛先の一覧もこの順に並ぶ）。
    /// 位置は表示中の一覧のものなので、表示中の一覧で並べ替えた順番（ID）を求めてから読み直し、最新の内容をその順に並べる。
    /// 表示中の一覧に無い宛先（別の画面で足されたもの）は後ろに残す
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = items
        ordered.move(fromOffsets: source, toOffset: destination)
        let order = ordered.map(\.id)
        reload()
        let latest = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        items = order.compactMap { latest[$0] } + items.filter { !order.contains($0.id) }
        save()
    }

    /// 取得した Webhook の名前・アイコンを覚える。変わっていなければ保存しない
    func updateProfile(id: SavedWebhookURL.ID, profile: WebhookProfile) {
        let avatarURL = profile.avatarURL?.absoluteString
        guard let item = items.first(where: { $0.id == id }),
              item.webhookName != profile.name || item.avatarURL != avatarURL else {
            return
        }
        update(id: id) { item in
            item.webhookName = profile.name
            item.avatarURL = avatarURL
        }
    }

    /// 入力された URL と同じ宛先（Webhook とスレッドが同じ）の保存済みのもの。
    /// Webhook URL の形でなければ、前後の空白を除いた文字列が同じものを探す
    func item(matching url: String) -> SavedWebhookURL? {
        if let key = WebhookDestinationKey(urlString: url) {
            return items.first { $0.destinationKey == key }
        }
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return items.first { $0.url.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed }
    }

    /// 一覧などで宛先を示す名前。保存していれば付けた名前、していなければトークンを出さない短い表示
    func displayName(for url: String) -> String {
        if let item = item(matching: url) {
            return item.name
        }
        return DiscordWebhookURL(string: url)?.maskedDescription ?? String(localized: "不明な宛先")
    }

    /// 別の画面のストアが書き換えた分を読み直してから、その宛先を書き換えて保存する
    private func update(id: SavedWebhookURL.ID, _ change: (inout SavedWebhookURL) -> Void) {
        reload()
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        change(&items[index])
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
