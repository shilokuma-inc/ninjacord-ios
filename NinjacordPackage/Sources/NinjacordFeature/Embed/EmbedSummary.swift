//
//  EmbedSummary.swift
//  NinjacordApp
//

import Foundation

/// 送信画面の「埋め込み」セクションに出す、入力済みの内容の要約（Discussion #586 の Q5）。
/// 送るかどうかは送る中身（`DiscordWebhookRequest`）と同じく `hasContent`、項目は `sendableFields` などで判定する
struct EmbedSummary: Equatable {
    /// 入力済みの項目（タイトルを除く）。エディタの上から順に並べる
    enum Item: Equatable {
        case description
        case color
        /// 送られるフィールドの件数（名前も値も空の行は数えない）
        case fields(Int)
        case image
        case thumbnail
        case footer
        case timestamp

        /// 画面に出す名前
        var label: String {
            switch self {
            case .description:
                return String(localized: "説明")
            case .color:
                return String(localized: "色")
            case .fields(let count):
                return String(localized: "フィールド\(count)件")
            case .image:
                return String(localized: "画像")
            case .thumbnail:
                return String(localized: "サムネイル")
            case .footer:
                return String(localized: "フッター")
            case .timestamp:
                return String(localized: "送信日時")
            }
        }
    }

    enum State: Equatable {
        /// 何も入力していない
        case empty
        /// 色・送信日時だけで、埋め込みとして送られない
        case notSent
        /// 埋め込みを送る。タイトルが空なら title は nil
        case filled(title: String?, items: [Item])
    }

    let state: State

    init(embed: MessageEmbedEntity) {
        let items = Self.items(of: embed)
        if embed.hasContent {
            let title = embed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : embed.title
            state = .filled(title: title, items: items)
        } else if items.isEmpty {
            state = .empty
        } else {
            state = .notSent
        }
    }

    /// 1 行目。タイトルが無ければ nil（呼び出し側で仮の文言を出す）
    var title: String? {
        guard case .filled(let title, _) = state else {
            return nil
        }
        return title
    }

    /// 2 行目。入力済みの項目を並べる
    var detail: String {
        switch state {
        case .empty:
            return String(localized: "未設定")
        case .notSent:
            return String(localized: "色と送信日時だけでは送られません")
        case .filled(let title, let items):
            guard !items.isEmpty else {
                // 名前も値も空のフィールド行だけのときは、中身の無い埋め込みを送る（`hasDisplayedContent` が false）
                return title == nil ? String(localized: "表示される内容がありません") : String(localized: "タイトルのみ")
            }
            return ListFormatter.localizedString(byJoining: items.map(\.label))
        }
    }

    private static func items(of embed: MessageEmbedEntity) -> [Item] {
        var items: [Item] = []
        if !embed.description.isBlank {
            items.append(.description)
        }
        if embed.color != nil {
            items.append(.color)
        }
        let fieldCount = embed.sendableFields.count
        if fieldCount > 0 {
            items.append(.fields(fieldCount))
        }
        if !embed.imageURL.isBlank {
            items.append(.image)
        }
        if !embed.thumbnailURL.isBlank {
            items.append(.thumbnail)
        }
        if !embed.footerText.isBlank {
            items.append(.footer)
        }
        if embed.includesTimestamp {
            items.append(.timestamp)
        }
        return items
    }
}

private extension String {
    /// 空白と改行だけなら true（`hasContent` と同じ判定）
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
