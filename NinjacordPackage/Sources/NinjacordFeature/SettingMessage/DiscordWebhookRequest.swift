//
//  DiscordWebhookRequest.swift
//  NinjacordApp
//

import Foundation

/// Discord の Webhook に送る中身（JSON の本文・multipart/form-data の各パート）を組み立てる。
/// 通信からは切り離してあり、送信日時も `sentAt` で受け取るので、同じ入力からは同じ中身になる
/// https://discord.com/developers/docs/resources/webhook#execute-webhook
struct DiscordWebhookRequest {
    /// multipart/form-data の 1 パート
    struct MultipartPart: Equatable {
        let name: String
        let data: Data
        let fileName: String?
        let mimeType: String
    }

    let messageEntity: MessageEntity
    /// 添付する画像。あれば multipart/form-data で送る
    let attachment: ImageAttachment?
    /// 埋め込みの送信日時（timestamp）として送る日時
    let sentAt: Date

    init(messageEntity: MessageEntity, attachment: ImageAttachment? = nil, sentAt: Date = Date()) {
        self.messageEntity = messageEntity
        self.attachment = attachment
        self.sentAt = sentAt
    }

    /// Execute Webhook の JSON パラメータ
    var parameters: [String: Any] {
        var param: [String: Any] = [
            "username": messageEntity.username.isEmpty ? "以下、名無しにかわりましてVIPがお送りします" : messageEntity.username,
            "avatar_url": messageEntity.avatarURL,
            "content": messageEntity.content.isEmpty ? "なんか書いてね" : messageEntity.content
        ]
        if messageEntity.messageEmbedEntity.hasContent {
            param["embeds"] = [embedParameters(messageEntity.messageEmbedEntity)]
        }
        return param
    }

    /// 画像を添付しないときに送る JSON の本文
    var jsonBody: Data {
        // swiftlint:disable:next force_try
        try! JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
    }

    /// 画像を添付するときに送る multipart/form-data の各パート。メッセージは payload_json、画像は files[0] として送る。
    /// 添付する画像が無ければ nil
    /// https://discord.com/developers/docs/reference#uploading-files
    var multipartParts: [MultipartPart]? {
        guard let attachment else {
            return nil
        }
        let payload = (try? JSONSerialization.data(withJSONObject: parameters)) ?? Data()
        return [
            MultipartPart(name: "payload_json", data: payload, fileName: nil, mimeType: "application/json"),
            MultipartPart(
                name: "files[0]",
                data: attachment.data,
                fileName: attachment.fileName,
                mimeType: attachment.mimeType
            )
        ]
    }

    /// Discord の embed オブジェクトを組み立てる。空の項目は送らない
    /// https://discord.com/developers/docs/resources/message#embed-object
    private func embedParameters(_ embed: MessageEmbedEntity) -> [String: Any] {
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
