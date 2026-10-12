//
//  SendHistoryEntry.swift
//  NinjacordApp
//

import Foundation

/// 送信履歴の 1 件。端末内にだけ保存し、外部には送らない
struct SendHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let sentAt: Date
    /// 送信先の Webhook URL
    let url: String
    let message: MessageEntity
    let isSuccess: Bool
}
