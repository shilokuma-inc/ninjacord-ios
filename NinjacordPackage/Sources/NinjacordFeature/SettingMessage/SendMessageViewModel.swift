//
//  SendMessageViewModel.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/28.
//

import Foundation
import Alamofire

struct SendMessageViewModel {
    private let analytics = FirebaseAnalytics()
    private let sendSuccessCounter = SendSuccessCounter()

    /// Webhook にメッセージを送信する。通信が完了（成功・失敗とも）するまで待機し、送信結果を返す。
    /// 失敗時は Discord のレスポンスから判定した原因を返す
    @discardableResult
    public func postDiscordWebhook(
        url: String,
        messageEntity: MessageEntity
    ) async -> Result<Void, DiscordWebhookError> {
        let baseUrlString = url
        let param: Parameters = {
            makeParameter(messageEntity: messageEntity)
        }()

        var request = URLRequest(url: (URL(string: baseUrlString) ?? URL(string: "https://www.apple.com/")!))
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = NSString(
            // swiftlint:disable:next force_try
            data: try! JSONSerialization.data(withJSONObject: param as Any,
                                              options: JSONSerialization.WritingOptions.prettyPrinted
                                             ),
            encoding: String.Encoding.utf8.rawValue
        )!
            .data(using: String.Encoding.utf8.rawValue)
        print(request)
        // validate() を付けないと Discord が 4xx / 5xx を返しても success 扱いになるため、
        // ステータスコードが 2xx 以外なら failure にする
        let response = await AF.request(request).validate().serializingData().response
        analytics.sendMessageSendEvent(
            isSuccess: response.error == nil,
            httpStatus: response.response?.statusCode
        )
        switch response.result {
        case .success:
            print("success")
            if sendSuccessCounter.increment() == 1 {
                analytics.sendFirstSendCompletedEvent()
            }
            return .success(())
        case .failure(let error):
            print("error: \(error)")
            return .failure(DiscordWebhookError(statusCode: response.response?.statusCode, data: response.data))
        }
    }
}

extension SendMessageViewModel {
    private func makeParameter(messageEntity: MessageEntity) -> Parameters {
        var param: Parameters = [
            "username": messageEntity.username.isEmpty ? "以下、名無しにかわりましてVIPがお送りします" : messageEntity.username,
            "avatar_url": messageEntity.avatarURL,
            "content": messageEntity.content.isEmpty ? "なんか書いてね" : messageEntity.content
        ]
        if messageEntity.messageEmbedEntity.hasContent {
            param["embeds"] = [makeEmbedParameter(messageEntity.messageEmbedEntity)]
        }
        return param
    }

    /// Discord の embed オブジェクトを組み立てる。空の項目は送らない
    /// https://discord.com/developers/docs/resources/message#embed-object
    private func makeEmbedParameter(_ embed: MessageEmbedEntity, sentAt: Date = Date()) -> [String: Any] {
        var param: [String: Any] = [:]
        if !embed.title.isEmpty {
            param["title"] = embed.title
        }
        if !embed.description.isEmpty {
            param["description"] = embed.description
        }
        if let color = embed.color {
            param["color"] = color
        }
        let fields = embed.sendableFields
        if !fields.isEmpty {
            param["fields"] = fields.map { ["name": $0.name, "value": $0.value, "inline": $0.isInline] }
        }
        if !embed.footerText.isEmpty {
            param["footer"] = ["text": embed.footerText]
        }
        if !embed.imageURL.isEmpty {
            param["image"] = ["url": embed.imageURL]
        }
        if !embed.thumbnailURL.isEmpty {
            param["thumbnail"] = ["url": embed.thumbnailURL]
        }
        if embed.includesTimestamp {
            param["timestamp"] = ISO8601DateFormatter().string(from: sentAt)
        }
        return param
    }
}

// MARK: - 入力バリデーション

/// 送信前の入力チェックで検出したエラー。アラートのタイトル・本文として表示する
enum SendMessageValidationError: LocalizedError {
    /// 送信先 URL が未入力
    case emptyURL
    /// 送信先 URL が URL の形式になっていない
    case invalidURL
    /// URL 以外の項目がすべて未入力
    case emptyMessage
    /// 埋め込みが Discord の上限を超えているなど
    case invalidEmbed(EmbedValidationIssue)

    var errorDescription: String? {
        switch self {
        case .emptyURL:
            return String(localized: "URLが入力されていません")
        case .invalidURL:
            return String(localized: "URLの形式が正しくありません")
        case .emptyMessage:
            return String(localized: "メッセージが入力されていません")
        case .invalidEmbed:
            return String(localized: "埋め込みの内容を確認してください")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyURL:
            return String(localized: "送信先のWebhook URLを入力してください")
        case .invalidURL:
            return String(localized: "https:// から始まるWebhook URLを入力してください")
        case .emptyMessage:
            return String(localized: "名前・メッセージなど、いずれかの項目を入力してください")
        case .invalidEmbed(let issue):
            return issue.message
        }
    }
}

extension SendMessageViewModel {
    /// 送信前に入力内容を検証する。問題がなければ nil を返す
    func validate(url: String, messageEntity: MessageEntity) -> SendMessageValidationError? {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedURL.isEmpty {
            return .emptyURL
        }
        if !isValidURL(trimmedURL) {
            return .invalidURL
        }
        if !messageEntity.hasContent {
            return .emptyMessage
        }
        // 最初の 1 件だけを示す（直して送り直せば次の誤りが分かる）
        if let issue = messageEntity.messageEmbedEntity.validationIssues().first {
            return .invalidEmbed(issue)
        }
        return nil
    }

    /// http / https のスキームとホストを持つ URL かどうか
    private func isValidURL(_ string: String) -> Bool {
        guard let components = URLComponents(string: string),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty else {
            return false
        }
        return true
    }
}
