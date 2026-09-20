//
//  SendMessageViewModel.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/28.
//

import Foundation
import Alamofire

struct SendMessageViewModel {
    public func postDiscordWebhook(url: String, messageEntity: MessageEntity) {
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
        AF.request(request)
        .responseData { response in
            switch response.result {
            case .success:
                print("success")
            case .failure:
                print("error")
            }
        }
    }
}

extension SendMessageViewModel {
    private func makeParameter(messageEntity: MessageEntity) -> Parameters {
        var param: Parameters
        if messageEntity.messageEmbedEntity.title.isEmpty {
            param = [
                "username": messageEntity.username.isEmpty ? "以下、名無しにかわりましてVIPがお送りします" : messageEntity.username,
                "avatar_url": messageEntity.avatarURL,
                "content": messageEntity.content.isEmpty ? "なんか書いてね" : messageEntity.content
            ]
        } else {
            param = [
                "username": messageEntity.username.isEmpty ? "以下、名無しにかわりましてVIPがお送りします" : messageEntity.username,
                "avatar_url": messageEntity.avatarURL,
                "content": messageEntity.content.isEmpty ? "なんか書いてね" : messageEntity.content,
                "embeds": [
                    [
                        "title": messageEntity.messageEmbedEntity.title
                    ]
                ]
            ]
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

    var errorDescription: String? {
        switch self {
        case .emptyURL:
            return String(localized: "URLが入力されていません")
        case .invalidURL:
            return String(localized: "URLの形式が正しくありません")
        case .emptyMessage:
            return String(localized: "メッセージが入力されていません")
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
        let messageFields = [
            messageEntity.username,
            messageEntity.avatarURL,
            messageEntity.content,
            messageEntity.messageEmbedEntity.title
        ]
        if messageFields.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return .emptyMessage
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
