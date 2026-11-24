//
//  SendMessageValidation.swift
//  NinjacordApp
//

import Foundation

// MARK: - 入力バリデーション

/// 送信前の入力チェックで検出したエラー。アラートのタイトル・本文として表示する
enum SendMessageValidationError: LocalizedError, Equatable {
    /// 送信先 URL が未入力
    case emptyURL
    /// 送信先 URL が URL の形式になっていない
    case invalidURL
    /// フォーラム・メディアチャンネルの宛先なのに、投稿のタイトルが空（空白だけも含む）
    case emptyThreadName
    /// URL 以外の項目がすべて未入力で、画像も添付していない
    case emptyMessage
    /// 埋め込みが Discord の上限を超えているなど
    case invalidEmbed(EmbedValidationIssue)
    /// Pro でないのに、埋め込みに Pro 限定の項目が入っている
    case proEmbedFeatures
    /// Pro でないのに、一斉送信の宛先が選ばれている
    case proBroadcast

    var errorDescription: String? {
        switch self {
        case .emptyURL:
            return String(localized: "宛先が選ばれていません")
        case .invalidURL:
            return String(localized: "URLの形式が正しくありません")
        case .emptyThreadName:
            return String(localized: "投稿のタイトルが入力されていません")
        case .emptyMessage:
            return String(localized: "メッセージが入力されていません")
        case .invalidEmbed:
            return String(localized: "埋め込みの内容を確認してください")
        case .proEmbedFeatures:
            return String(localized: "Pro限定の項目が入っています")
        case .proBroadcast:
            return String(localized: "一斉送信はNinjacord Pro限定です")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyURL:
            // 送信画面に URL の入力欄は無く、宛先のカードから選ぶ（Issue #674）
            return String(localized: "「宛先」をタップして、保存した宛先から選ぶか、Webhook URLを貼り付けてください")
        case .invalidURL:
            return String(localized: "「宛先」をタップして、Discordで「ウェブフックURLをコピー」したURLを貼り付け直してください")
        case .emptyThreadName:
            return String(localized: "フォーラム・メディアチャンネルには、タイトルを付けて新しい投稿として送ります。「本文」の「投稿のタイトル」を入れてください")
        case .emptyMessage:
            return String(localized: "名前・メッセージなど、いずれかの項目を入力してください")
        case .invalidEmbed(let issue):
            return issue.message
        case .proEmbedFeatures:
            return String(localized: "埋め込みの色・フィールド・画像・サムネイル・フッター・送信日時はNinjacord Pro限定です。埋め込みの編集から消すか、Proにしてください")
        case .proBroadcast:
            return String(localized: "宛先の選択を解除して1件ずつ送るか、Proにしてください")
        }
    }
}

extension SendMessageViewModel {
    /// 送信前に入力内容を検証する。問題がなければ nil を返す
    /// - Parameters:
    ///   - hasAttachment: 画像を添付しているか。画像だけでも送れる
    ///   - canUseProFeatures: Pro 限定の項目を使えるか（Pro 購読中など）
    ///   - requiresThreadName: 投稿のタイトルが要るか（宛先がフォーラム・メディアチャンネル）
    func validate(
        url: String,
        messageEntity: MessageEntity,
        hasAttachment: Bool,
        canUseProFeatures: Bool,
        requiresThreadName: Bool = false
    ) -> SendMessageValidationError? {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedURL.isEmpty {
            return .emptyURL
        }
        if !isValidURL(trimmedURL) {
            return .invalidURL
        }
        // 空のままフォーラムに送ると Discord が 220001 で受け付けないので、送る前に止める。
        // タイトルの欄は本文の上に出すので、本文などより先に知らせる
        if requiresThreadName && messageEntity.threadName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyThreadName
        }
        if !messageEntity.hasContent && !hasAttachment {
            return .emptyMessage
        }
        if !canUseProFeatures && messageEntity.messageEmbedEntity.usesProFeatures {
            return .proEmbedFeatures
        }
        // 最初の 1 件だけを示す（直して送り直せば次の誤りが分かる）
        if let issue = messageEntity.messageEmbedEntity.validationIssues().first {
            return .invalidEmbed(issue)
        }
        return nil
    }

    /// http / https のスキームとホストを持ち、送信先の URL にできるかどうか
    private func isValidURL(_ string: String) -> Bool {
        guard let components = URLComponents(string: string),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty else {
            return false
        }
        // URLComponents では読めても URL(string:) では読めない文字列は、送れないのでここで止める（#472）
        return Self.webhookEndpoint(from: string) != nil
    }
}
