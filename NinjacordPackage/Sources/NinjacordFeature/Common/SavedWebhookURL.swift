//
//  SavedWebhookURL.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2026/09/21.
//

import Foundation

/// ユーザーが任意の名前を付けて保存した Webhook URL
struct SavedWebhookURL: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String
}
