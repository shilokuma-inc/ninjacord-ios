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
