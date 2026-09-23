//
//  MessageTemplate.swift
//  NinjacordApp
//

import Foundation

/// よく送るメッセージの中身を保存したもの。
/// 宛先（保存済み Webhook URL）とは別に管理する（URL = 宛先、テンプレート = 中身）
struct MessageTemplate: Codable, Identifiable, Equatable {
    let id: UUID
    /// 一覧に表示する名前
    var name: String
    var message: MessageEntity
    let createdAt: Date
    /// 一覧の先頭に固定するか
    var isPinned: Bool

    init(id: UUID, name: String, message: MessageEntity, createdAt: Date, isPinned: Bool = false) {
        self.id = id
        self.name = name
        self.message = message
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        message = try container.decode(MessageEntity.self, forKey: .message)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        // ピン留めを追加する前に保存されたテンプレートにはこの項目が無いので、ピン留めなしとして読み込む
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

extension MessageTemplate {
    /// 名前を空のまま保存したときの名前。見分けがつくよう、メッセージの冒頭 20 文字を使う
    static func defaultName(for message: MessageEntity) -> String {
        let prefix = String(message.summary.prefix(20))
        return prefix.isEmpty ? String(localized: "テンプレート") : prefix
    }
}
