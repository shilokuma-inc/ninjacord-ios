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
        let param: [String: Any] = makeParameter(messageEntity: messageEntity)

        guard let url = URL(string: baseUrlString) else {
          print("Invalid URL: \(baseUrlString)")
          return
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // JSON シリアライズ
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: param, options: [])
            request.httpBody = jsonData
        } catch {
            print("Failed to serialize JSON: \(error)")
            return
        }

        // デバッグ: リクエスト内容を確認
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Request Body: \(bodyString)")
        }
        AF.request(request).responseData { response in
            switch response.result {
            case .success(let data):
                print("Success: \(String(data: data, encoding: .utf8) ?? "No response body")")
            case .failure(let error):
                print("Request failed: \(error)")
                if let httpResponse = response.response {
                    print("HTTP Status Code: \(httpResponse.statusCode)")
                }
            }
        }
    }
}

extension SendMessageViewModel {
    private func makeParameter(messageEntity: MessageEntity) -> Parameters {
        // avatarURL のバリデーション
        let isValidAvatarURL = messageEntity.avatarURL.hasPrefix("http://") || messageEntity.avatarURL.hasPrefix("https://")

        // 基本パラメータを構築
        var param: Parameters = [
            "username": messageEntity.username.isEmpty ? "以下、名無しにかわりましてVIPがお送りします" : messageEntity.username,
            "content": messageEntity.content.isEmpty ? "なんか書いてね" : messageEntity.content
        ]

        // embeds の追加
        if !messageEntity.messageEmbedEntity.title.isEmpty {
            param["embeds"] = [
                [
                    "title": messageEntity.messageEmbedEntity.title
                ]
            ]
        }

        // avatar_url の追加（有効な場合のみ）
        if isValidAvatarURL {
            param["avatar_url"] = messageEntity.avatarURL
        }

        return param
    }
}
