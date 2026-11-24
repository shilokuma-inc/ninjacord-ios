//
//  MessageSendOptions.swift
//  NinjacordApp
//

import Foundation

/// 送信オプション。メッセージの中身ではなく、Discord での届き方を変える（Issue #698）。
/// 既定はすべてオフで、オフのときは `flags`・`allowed_mentions` を送らず、今までと同じ送り方になる
struct MessageSendOptions: Codable, Equatable {
    /// 通知を鳴らさない（Discord の `@silent` と同じ）。`flags` に `SUPPRESS_NOTIFICATIONS` を立てる
    var suppressesNotifications: Bool
    /// リンクのプレビューを出さない。`flags` に `SUPPRESS_EMBEDS` を立てる。
    /// Discord はこのフラグでメッセージの埋め込みをすべて出さなくなるので、送った埋め込みも表示されない
    var suppressesEmbeds: Bool
    /// @everyone・@here で通知しない。ユーザーとロールへのメンションは今までどおり通知する
    var suppressesEveryoneMentions: Bool

    init(
        suppressesNotifications: Bool = false,
        suppressesEmbeds: Bool = false,
        suppressesEveryoneMentions: Bool = false
    ) {
        self.suppressesNotifications = suppressesNotifications
        self.suppressesEmbeds = suppressesEmbeds
        self.suppressesEveryoneMentions = suppressesEveryoneMentions
    }

    /// オプションを足したあとも、足す前に保存したテンプレート・送信履歴を読めるよう、無い項目はオフで読み込む
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        suppressesNotifications = try container.decodeIfPresent(Bool.self, forKey: .suppressesNotifications) ?? false
        suppressesEmbeds = try container.decodeIfPresent(Bool.self, forKey: .suppressesEmbeds) ?? false
        suppressesEveryoneMentions = try container.decodeIfPresent(
            Bool.self,
            forKey: .suppressesEveryoneMentions
        ) ?? false
    }
}

extension MessageSendOptions {
    /// Discord のメッセージのフラグ
    /// https://discord.com/developers/docs/resources/message#message-object-message-flags
    enum MessageFlag {
        static let suppressEmbeds = 1 << 2
        static let suppressNotifications = 1 << 12
    }

    /// メッセージを送る（Execute Webhook）ときの `flags`。立てるフラグが無ければ nil（キーを送らない）
    var messageFlags: Int? {
        var flags = 0
        if suppressesNotifications {
            flags |= MessageFlag.suppressNotifications
        }
        if suppressesEmbeds {
            flags |= MessageFlag.suppressEmbeds
        }
        return flags == 0 ? nil : flags
    }

    /// 送ったメッセージを書き換える（Edit Webhook Message）ときの `flags`。
    /// 編集では Discord の仕様で `SUPPRESS_EMBEDS` しか送れない（通知は送ったときに済んでいる）。
    /// オフなら nil にしてキーを送らず、Discord で付いているフラグに触れない（今までの編集と同じ）
    var editableMessageFlags: Int? {
        suppressesEmbeds ? MessageFlag.suppressEmbeds : nil
    }

    /// `allowed_mentions`。@everyone・@here で通知しないときは、メンションのうちユーザーとロールだけを通知する。
    /// オフなら nil（キーを送らず、Discord の既定どおりすべてのメンションを通知する）
    /// https://discord.com/developers/docs/resources/message#allowed-mentions-object
    var allowedMentions: [String: Any]? {
        suppressesEveryoneMentions ? ["parse": ["users", "roles"]] : nil
    }

    /// 送信画面で送信オプションを閉じているときの要約。オンにしたものを並べる
    var summary: String {
        var labels: [String] = []
        if suppressesNotifications {
            labels.append(String(localized: "通知を鳴らさない"))
        }
        if suppressesEmbeds {
            labels.append(String(localized: "リンクのプレビューを出さない"))
        }
        if suppressesEveryoneMentions {
            labels.append(String(localized: "@everyone・@hereで通知しない"))
        }
        guard !labels.isEmpty else {
            return String(localized: "すべてオフ")
        }
        return ListFormatter.localizedString(byJoining: labels)
    }
}
