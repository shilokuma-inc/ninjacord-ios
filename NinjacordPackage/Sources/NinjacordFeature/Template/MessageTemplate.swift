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
