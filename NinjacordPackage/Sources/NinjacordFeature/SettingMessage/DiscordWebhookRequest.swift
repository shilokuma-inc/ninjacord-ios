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

    /// 本文が空で、埋め込みも画像も無いときに送る本文。端末の言語に合わせて送る（#469）。
    /// 名前は空なら送らず、Discord に Webhook の名前で出す（Discussion #586 の Q7）
    static var defaultContent: String {
        String(localized: "なんか書いてね")
    }

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
            && !messageEntity.messageEmbedEntity.hasContent
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
        // 送信オプション。オフなら flags・allowed_mentions のキーを送らず、今までと同じ送り方にする（Issue #698）
        if let flags = messageEntity.sendOptions.messageFlags {
            param["flags"] = flags
        }
        if let allowedMentions = messageEntity.sendOptions.allowedMentions {
            param["allowed_mentions"] = allowedMentions
        }
        return param
    }

    /// 画像を添付しないときに送る JSON の本文。パラメータを JSON にできなければ nil（#473）
    var jsonBody: Data? {
        Self.encodeJSON(parameters, options: .prettyPrinted)
    }

    /// 送ったメッセージを書き換える（Edit Webhook Message）ときの JSON パラメータ。
    /// 名前・アイコンは Discord の仕様で変えられないので送らない。添付した画像は `attachments` を送らなければそのまま残る。
    /// 消した本文・埋め込みが Discord でも消えるよう、空の本文は null、埋め込みが無ければ空の配列で送る。
    /// 送るときと違い、空の本文をアプリの初期文言に置き換えない（空にできるかは呼び出し側で確かめる）。
    /// 送信オプションは、送ったときと同じ扱いになるよう、リンクのプレビューと @everyone・@here の設定だけを送る
    /// （通知は送ったときに済んでいて、`flags` に立てられない）。オフなら今までの編集と同じくキーを送らない
    /// https://discord.com/developers/docs/resources/webhook#edit-webhook-message-jsonform-params
    var editParameters: [String: Any] {
        let content: Any = messageEntity.content.isEmpty ? NSNull() : messageEntity.content
        let embed = messageEntity.messageEmbedEntity
        let embeds: [[String: Any]] = embed.hasContent ? [embedParameters(embed)] : []
        var param: [String: Any] = ["content": content, "embeds": embeds]
        if let flags = messageEntity.sendOptions.editableMessageFlags {
            param["flags"] = flags
        }
        if let allowedMentions = messageEntity.sendOptions.allowedMentions {
            param["allowed_mentions"] = allowedMentions
        }
        return param
    }

    /// 送ったメッセージを書き換えるときの JSON の本文。パラメータを JSON にできなければ nil
    var editJSONBody: Data? {
        Self.encodeJSON(editParameters)
    }

    /// 画像を添付するときに送る multipart/form-data の各パート。メッセージは payload_json、画像は files[0] として送る。
    /// 添付する画像が無いか、パラメータを JSON にできなければ nil
    /// https://discord.com/developers/docs/reference#uploading-files
    var multipartParts: [MultipartPart]? {
        guard let attachment, let payload = Self.encodeJSON(parameters) else {
            return nil
        }
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

    /// JSON に書き出す。JSON にできない値が入っていれば nil。
    /// `JSONSerialization.data(withJSONObject:)` は JSON にできない値を渡すと Swift の error ではなく
    /// Objective-C の例外で落ち、`try?` では防げないので、先に `isValidJSONObject` で確かめる
    static func encodeJSON(_ object: [String: Any], options: JSONSerialization.WritingOptions = []) -> Data? {
        guard JSONSerialization.isValidJSONObject(object) else {
            return nil
        }
        return try? JSONSerialization.data(withJSONObject: object, options: options)
    }

    /// multipartParts を multipart/form-data の本文にする。添付する画像が無いか、パラメータを JSON にできなければ nil。
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
