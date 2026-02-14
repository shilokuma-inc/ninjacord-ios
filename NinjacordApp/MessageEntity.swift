//
//  MessageEntity.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/28.
//

import Foundation

struct MessageEntity {
    var username: String
    var avatarURL: String
    var content: String
    var messageEmbedEntity: MessageEmbedEntity
}

struct MessageEmbedEntity {
    var title: String
}
