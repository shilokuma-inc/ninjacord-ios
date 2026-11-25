//
//  SendHistoryEntry.swift
//  NinjacordApp
//

import Foundation

/// 送信履歴の 1 件。端末内にだけ保存し、外部には送らない。
/// 送れたメッセージは、メッセージ ID を残して「投稿済み」から編集・削除できるようにする（Issue #666）
struct SendHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let sentAt: Date
    /// 送信先の Webhook URL
    let url: String
    /// 送った中身。アプリから編集したら、編集後の中身に書き換える
    var message: MessageEntity
    let isSuccess: Bool
    /// Discord が作ったメッセージの ID。編集・削除に使う。
    /// 送れなかった・ID を受け取れなかった・ID を残す前の版で送ったときは nil
    let messageID: String?
    /// フォーラムに新しい投稿として送ったときの、作られたスレッド（投稿）の ID。
    /// 編集・削除のときに `thread_id` として付ける。新しい投稿でない・覚える前の版で送ったときは nil（Issue #699）
    let threadID: String?
    /// 画像を添付して送ったか。編集で本文と埋め込みを空にしても、画像が残るので送れる
    let hasAttachment: Bool
    /// 最後にアプリから編集した日時。編集していなければ nil
    var editedAt: Date?
    /// アプリから削除した日時（Discord で先に消されていたときも含む）。削除していなければ nil
    var deletedAt: Date?

    init(
        id: UUID,
        sentAt: Date,
        url: String,
        message: MessageEntity,
        isSuccess: Bool,
        messageID: String? = nil,
        threadID: String? = nil,
        hasAttachment: Bool = false,
        editedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.sentAt = sentAt
        self.url = url
        self.message = message
        self.isSuccess = isSuccess
        self.messageID = messageID
        self.threadID = threadID
        self.hasAttachment = hasAttachment
        self.editedAt = editedAt
        self.deletedAt = deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sentAt = try container.decode(Date.self, forKey: .sentAt)
        url = try container.decode(String.self, forKey: .url)
        message = try container.decode(MessageEntity.self, forKey: .message)
        isSuccess = try container.decode(Bool.self, forKey: .isSuccess)
        // メッセージ ID などを残す前（2.3.0 まで）に保存した履歴にはこれらの項目が無いので、編集・削除できないものとして読み込む
        messageID = try container.decodeIfPresent(String.self, forKey: .messageID)
        // 作られたスレッドの ID を覚える前（2.5.0 まで）の履歴には無いので、今までどおり thread_id を付けずに編集・削除する
        threadID = try container.decodeIfPresent(String.self, forKey: .threadID)
        hasAttachment = try container.decodeIfPresent(Bool.self, forKey: .hasAttachment) ?? false
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

extension SendHistoryEntry {
    /// 「投稿済み」に出して、編集・削除できるか（送れて、ID があり、まだ削除していない）
    var isPosted: Bool {
        isSuccess && messageID != nil && deletedAt == nil
    }
}
