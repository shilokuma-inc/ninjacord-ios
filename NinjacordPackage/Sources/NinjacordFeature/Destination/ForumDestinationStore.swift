//
//  ForumDestinationStore.swift
//  NinjacordApp
//

import Foundation

/// フォーラム・メディアチャンネルの宛先として覚えた Webhook（Issue #699）。
/// Webhook URL からはフォーラムかどうかを判別できないので、宛先の一覧・保存の画面で設定したときと、
/// 送信して Discord が 220001（タイトルが要る）・220003（フォーラムではない）を返したときに覚え直す。
/// Webhook はチャンネルごとに作られるので、Webhook の ID で覚える（URL のトークンは保存しない）。
/// 保存した宛先と保存していない URL を同じように扱い、宛先を保存し直したり消したりしても覚えたままにする。
/// 送信画面・宛先の一覧・保存の画面で同じもの（`shared`）を使い、どこで変えてもすぐに反映する（保存先は UserDefaults）
@MainActor
final class ForumDestinationStore: ObservableObject {
    static let shared = ForumDestinationStore()

    private static let storageKey = "forumWebhookIDs"

    /// フォーラムとして覚えた Webhook の ID
    @Published private(set) var webhookIDs: Set<String>

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        webhookIDs = Set(userDefaults.stringArray(forKey: Self.storageKey) ?? [])
    }

    /// フォーラムとして設定できる宛先か。`?thread_id=` が付いた宛先は既存のスレッド（投稿）に送るので、
    /// フォーラムの Webhook でもタイトルを付けない（thread_id と thread_name を一緒に送ると 220002 になる）
    static func canBeForum(_ url: String) -> Bool {
        forumKey(for: url) != nil
    }

    /// タイトル（thread_name）を付けて新しい投稿として送る宛先か。
    /// フォーラムとして覚えた Webhook で、`?thread_id=` が付いていないこと
    func isForum(_ url: String) -> Bool {
        Self.forumKey(for: url).map { webhookIDs.contains($0.webhookID) } ?? false
    }

    /// フォーラムの宛先として覚える・忘れる。フォーラムとして設定できない宛先（`canBeForum`）なら何もしない
    func setForum(_ isForum: Bool, for url: String) {
        guard let key = Self.forumKey(for: url), webhookIDs.contains(key.webhookID) != isForum else {
            return
        }
        if isForum {
            webhookIDs.insert(key.webhookID)
        } else {
            webhookIDs.remove(key.webhookID)
        }
        userDefaults.set(webhookIDs.sorted(), forKey: Self.storageKey)
    }

    /// フォーラムとして覚える単位。Webhook URL の形で、`?thread_id=` が付いていないときだけ
    private static func forumKey(for url: String) -> WebhookDestinationKey? {
        guard let key = WebhookDestinationKey(urlString: url), key.threadID == nil else {
            return nil
        }
        return key
    }
}
