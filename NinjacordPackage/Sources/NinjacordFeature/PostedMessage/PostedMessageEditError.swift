//
//  PostedMessageEditError.swift
//  NinjacordApp
//

import Foundation

/// 送ったメッセージの編集で起きたエラー。編集画面のアラートのタイトル・本文として表示する
enum PostedMessageEditError: LocalizedError, Equatable {
    /// 本文も埋め込みも空で、画像も添付していない（Discord は空のメッセージを受け付けない）
    case emptyMessage
    /// 埋め込みが Discord の上限を超えているなど
    case invalidEmbed(EmbedValidationIssue)
    /// Pro でない。編集は Pro 限定（リワード広告の一時解放でも 1 回使える）
    case proRequired
    /// Discord への通信に失敗した
    case discord(DiscordWebhookError)

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return String(localized: "本文か埋め込みを入れてください")
        case .invalidEmbed:
            return String(localized: "埋め込みの内容を確認してください")
        case .proRequired:
            return String(localized: "メッセージの編集はNinjacord Pro限定です")
        case .discord:
            return String(localized: "編集できませんでした")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyMessage:
            return String(localized: "画像を添付していないメッセージは、本文と埋め込みを両方とも空にはできません。消したいときは一覧から削除してください")
        case .invalidEmbed(let issue):
            return issue.message
        case .proRequired:
            return String(localized: "Ninjacord Proにするか、広告を見ると編集できます")
        case .discord(let error):
            return error.localizedDescription
        }
    }
}

extension PostedMessageEditError {
    /// 編集を保存する前に、送れる中身かを確かめる。問題がなければ nil
    /// - Parameters:
    ///   - hasAttachment: 画像を添付して送ったメッセージか。画像は残るので、本文と埋め込みを空にしても送れる
    ///   - canUseProFeatures: 編集（Pro 限定）を使えるか
    static func validate(
        _ message: MessageEntity,
        hasAttachment: Bool,
        canUseProFeatures: Bool
    ) -> PostedMessageEditError? {
        guard canUseProFeatures else {
            return .proRequired
        }
        let hasContent = !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasContent && !message.messageEmbedEntity.hasContent && !hasAttachment {
            return .emptyMessage
        }
        // 最初の 1 件だけを示す（直して保存し直せば次の誤りが分かる）
        if let issue = message.messageEmbedEntity.validationIssues().first {
            return .invalidEmbed(issue)
        }
        return nil
    }
}

extension SendHistoryEntry {
    /// 編集画面に最初に入れておく中身。本文を空のまま送って Discord に初期文言（「なんか書いてね」）が出ているときは、
    /// 保存すると初期文言が消えてしまわないよう、初期文言を本文に入れておく
    var editableMessage: MessageEntity {
        var message = message
        if message.content.isEmpty && !message.messageEmbedEntity.hasContent && !hasAttachment {
            message.content = DiscordWebhookRequest.defaultContent
        }
        return message
    }
}
