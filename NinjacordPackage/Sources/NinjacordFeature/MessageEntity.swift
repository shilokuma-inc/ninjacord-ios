//
//  MessageEntity.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/28.
//

import Foundation

/// 送信するメッセージの中身。テンプレートとして保存するため Codable にしている
struct MessageEntity: Codable, Equatable {
    var username: String
    var avatarURL: String
    var content: String
    var messageEmbedEntity: MessageEmbedEntity
}

/// Discord の埋め込み（embed）。空の項目は送らない
struct MessageEmbedEntity: Codable, Equatable {
    var title: String
    var description: String
    /// 左端の縦線の色（RGB）。nil なら Discord の既定色
    var color: Int?
    var fields: [MessageEmbedField]
    var footerText: String
    var imageURL: String
    var thumbnailURL: String
    /// 送信した日時を埋め込みに表示するか
    var includesTimestamp: Bool

    init(
        title: String = "",
        description: String = "",
        color: Int? = nil,
        fields: [MessageEmbedField] = [],
        footerText: String = "",
        imageURL: String = "",
        thumbnailURL: String = "",
        includesTimestamp: Bool = false
    ) {
        self.title = title
        self.description = description
        self.color = color
        self.fields = fields
        self.footerText = footerText
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.includesTimestamp = includesTimestamp
    }

    /// title 以外を追加する前に保存したテンプレートにはこれらの項目が無いので、既定値で読み込む
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        color = try container.decodeIfPresent(Int.self, forKey: .color)
        fields = try container.decodeIfPresent([MessageEmbedField].self, forKey: .fields) ?? []
        footerText = try container.decodeIfPresent(String.self, forKey: .footerText) ?? ""
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL) ?? ""
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL) ?? ""
        includesTimestamp = try container.decodeIfPresent(Bool.self, forKey: .includesTimestamp) ?? false
    }

    /// 送る内容が 1 つでもあるか。無ければ embed 自体を送らない
    var hasContent: Bool {
        let texts = [title, description, footerText, imageURL, thumbnailURL]
        return texts.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || !fields.isEmpty
    }
}

/// 埋め込みの fields の 1 件
struct MessageEmbedField: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var value: String
    /// 横に並べて表示するか
    var isInline: Bool
}

extension MessageEntity {
    /// 名前・アイコン URL・本文・埋め込みのいずれかが入力されているか
    var hasContent: Bool {
        [username, avatarURL, content]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || messageEmbedEntity.hasContent
    }

    /// 一覧などで中身を見分けるための要約。本文があれば本文、無ければ埋め込みタイトル
    var summary: String {
        content.isEmpty ? messageEmbedEntity.title : content
    }
}
