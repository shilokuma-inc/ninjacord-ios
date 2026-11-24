//
//  SavedWebhookURL.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2026/09/21.
//

import Foundation

/// ユーザーが任意の名前を付けて保存した宛先（Webhook URL）。
/// 一覧では URL（トークンを含む）を出さず、付けた名前と、Discord 側の Webhook の名前・アイコンで見分ける（Issue #674）
struct SavedWebhookURL: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String
    /// 最後に取得した、Discord 側で Webhook に設定されている名前。まだ取得していなければ nil
    var webhookName: String?
    /// 最後に取得した Webhook のアイコンの URL。アイコンが無い・まだ取得していなければ nil
    var avatarURL: String?

    init(id: UUID, name: String, url: String, webhookName: String? = nil, avatarURL: String? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.webhookName = webhookName
        self.avatarURL = avatarURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        // Webhook の名前・アイコンを覚える前（2.4.0 まで）に保存したものには無いので、未取得として読み込む
        webhookName = try container.decodeIfPresent(String.self, forKey: .webhookName)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
    }
}

extension SavedWebhookURL {
    /// 宛先を見分けるキー。Webhook URL の形でなければ nil
    var destinationKey: WebhookDestinationKey? {
        WebhookDestinationKey(urlString: url)
    }

    /// スレッドに送る宛先か（URL に `?thread_id=` が付いている）
    var isThread: Bool {
        destinationKey?.threadID != nil
    }

    /// Webhook の名前とアイコンを、取得できていれば覚えておく
    var profile: WebhookProfile? {
        webhookName.map { WebhookProfile(name: $0, avatarURL: avatarURL.flatMap(URL.init(string:))) }
    }
}
