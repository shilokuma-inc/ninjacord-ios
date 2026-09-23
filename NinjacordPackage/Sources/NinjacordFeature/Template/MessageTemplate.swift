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
}

extension MessageTemplate {
    /// 名前を空のまま保存したときの名前。見分けがつくよう、メッセージの冒頭 20 文字を使う
    static func defaultName(for message: MessageEntity) -> String {
        let prefix = String(message.summary.prefix(20))
        return prefix.isEmpty ? String(localized: "テンプレート") : prefix
    }
}
