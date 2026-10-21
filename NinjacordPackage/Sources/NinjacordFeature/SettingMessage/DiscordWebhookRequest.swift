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

    /// 本文が空で、埋め込みも画像も無いときに送る本文。ローカライズしない（Discussion #459 の Q4 の 1）。
    /// 名前は空なら送らず、Discord に Webhook の名前で出す（Discussion #586 の Q7）
    static let defaultContent = "なんか書いてね"

    /// 未入力のため、アプリの初期文言に置き換えて送る項目
    enum DefaultedField: Equatable {
        case content

        /// 置き換えて送る値
        var value: String {
            switch self {
            case .content:
                return DiscordWebhookRequest.defaultContent
            }
        }
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

    /// アプリの初期文言に置き換えて送る項目。送る中身（`parameters`）はこれに従って組み立てる。
    /// 本文は、空でも埋め込みに表示する中身があるか画像を添付するなら、置き換えずに送らない
    var defaultedFields: [DefaultedField] {
        var fields: [DefaultedField] = []
        if messageEntity.content.isEmpty
            && !messageEntity.messageEmbedEntity.hasDisplayedContent
            && attachment == nil {
            fields.append(.content)
        }
        return fields
    }

    /// 本文の場所を送るか。本文が空で、初期文言にも置き換えないときは content のキーを送らない
    var sendsContent: Bool {
        !messageEntity.content.isEmpty || defaultedFields.contains(.content)
    }

    /// Execute Webhook の JSON パラメータ
    var parameters: [String: Any] {
        let defaulted = defaultedFields
        var param: [String: Any] = [
            "avatar_url": messageEntity.avatarURL
        ]
        // 名前が空なら username のキーを送らず、Discord 側で Webhook に設定した名前で出す
        if !messageEntity.username.isEmpty {
            param["username"] = messageEntity.username
        }
        if defaulted.contains(.content) {
            param["content"] = Self.defaultContent
        } else if !messageEntity.content.isEmpty {
            param["content"] = messageEntity.content
        }
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

    /// multipartParts を multipart/form-data の本文にする。添付する画像が無ければ nil。
    /// 書式は Alamofire の MultipartFormData と同じ（パートごとに境界・Content-Disposition・Content-Type・中身）
    func multipartBody(boundary: String) -> Data? {
        guard let parts = multipartParts else {
            return nil
        }
        var body = Data()
        for part in parts {
            var disposition = "form-data; name=\"\(part.name)\""
            if let fileName = part.fileName {
                disposition += "; filename=\"\(fileName)\""
            }
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: \(disposition)\r\n")
            body.append("Content-Type: \(part.mimeType)\r\n\r\n")
            body.append(part.data)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")
        return body
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

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
