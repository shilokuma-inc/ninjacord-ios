//
//  MessageEntity.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/28.
//

import Foundation

/// 送信するメッセージの中身。テンプレートとして保存するため Codable にしている
struct MessageEntity: Codable, Equatable {
    var username: String
    var avatarURL: String
    var content: String
    var messageEmbedEntity: MessageEmbedEntity
}

struct MessageEmbedEntity: Codable, Equatable {
    var title: String
}

extension MessageEntity {
    /// 名前・アイコン URL・本文・埋め込みタイトルのいずれかが入力されているか
    var hasContent: Bool {
        [username, avatarURL, content, messageEmbedEntity.title]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// 一覧などで中身を見分けるための要約。本文があれば本文、無ければ埋め込みタイトル
    var summary: String {
        content.isEmpty ? messageEmbedEntity.title : content
    }
}
