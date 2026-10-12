//
//  EmbedValidation.swift
//  NinjacordApp
//

import Foundation

/// Discord の embed の上限。超えると Discord が 400 で拒否する
/// https://discord.com/developers/docs/resources/message#embed-object-embed-limits
enum EmbedLimit {
    static let title = 256
    static let description = 4096
    static let fieldCount = 25
    static let fieldName = 256
    static let fieldValue = 1024
    static let footerText = 2048
    /// title・description・fields の name と value・footer の合計
    static let total = 6000
}

/// embed の上限違反など、送る前に分かる誤り
enum EmbedValidationIssue: Equatable {
    case titleTooLong
    case descriptionTooLong
    case tooManyFields
    case fieldNameTooLong(index: Int)
    case fieldValueTooLong(index: Int)
    /// name と value の片方だけが入力されている（Discord はどちらも必須）
    case fieldIncomplete(index: Int)
    case footerTooLong
    case totalTooLong
    case invalidImageURL
    case invalidThumbnailURL

    var message: String {
        switch self {
        case .titleTooLong:
            return String(localized: "埋め込みのタイトルは\(EmbedLimit.title)文字までです")
        case .descriptionTooLong:
            return String(localized: "埋め込みの説明は\(EmbedLimit.description)文字までです")
        case .tooManyFields:
            return String(localized: "フィールドは\(EmbedLimit.fieldCount)件までです")
        case .fieldNameTooLong(let index):
            return String(localized: "\(index + 1)番目のフィールドの名前は\(EmbedLimit.fieldName)文字までです")
        case .fieldValueTooLong(let index):
            return String(localized: "\(index + 1)番目のフィールドの値は\(EmbedLimit.fieldValue)文字までです")
        case .fieldIncomplete(let index):
            return String(localized: "\(index + 1)番目のフィールドは名前と値の両方を入力してください")
        case .footerTooLong:
            return String(localized: "フッターは\(EmbedLimit.footerText)文字までです")
        case .totalTooLong:
            return String(localized: "埋め込みの文字数が合計\(EmbedLimit.total)文字を超えています")
        case .invalidImageURL:
            return String(localized: "画像のURLは https:// から始めてください")
        case .invalidThumbnailURL:
            return String(localized: "サムネイルのURLは https:// から始めてください")
        }
    }
}

extension String {
    /// Discord と同じ数え方（JavaScript の文字列の長さ = UTF-16）での文字数
    var discordLength: Int {
        utf16.count
    }
}

extension MessageEmbedEntity {
    /// 送る対象の fields。name と value が両方とも空の行は入力途中とみなして送らない
    var sendableFields: [MessageEmbedField] {
        fields.filter { !$0.name.isEmpty || !$0.value.isEmpty }
    }

    /// 上限違反などの誤りを、画面の上から順に返す。問題が無ければ空
    func validationIssues() -> [EmbedValidationIssue] {
        var issues: [EmbedValidationIssue] = []
        if title.discordLength > EmbedLimit.title {
            issues.append(.titleTooLong)
        }
        if description.discordLength > EmbedLimit.description {
            issues.append(.descriptionTooLong)
        }
        issues += fieldIssues()
        if footerText.discordLength > EmbedLimit.footerText {
            issues.append(.footerTooLong)
        }
        if totalLength > EmbedLimit.total {
            issues.append(.totalTooLong)
        }
        if !imageURL.isEmpty && !Self.isHTTPURL(imageURL) {
            issues.append(.invalidImageURL)
        }
        if !thumbnailURL.isEmpty && !Self.isHTTPURL(thumbnailURL) {
            issues.append(.invalidThumbnailURL)
        }
        return issues
    }

    /// fields の件数と各行の誤り。行番号は画面に表示している順（送らない空行も含めた位置）
    private func fieldIssues() -> [EmbedValidationIssue] {
        var issues: [EmbedValidationIssue] = []
        let sendable = sendableFields
        if sendable.count > EmbedLimit.fieldCount {
            issues.append(.tooManyFields)
        }
        for (index, field) in fields.enumerated() where sendable.contains(field) {
            if field.name.isEmpty || field.value.isEmpty {
                issues.append(.fieldIncomplete(index: index))
            }
            if field.name.discordLength > EmbedLimit.fieldName {
                issues.append(.fieldNameTooLong(index: index))
            }
            if field.value.discordLength > EmbedLimit.fieldValue {
                issues.append(.fieldValueTooLong(index: index))
            }
        }
        return issues
    }

    /// Discord が合計 6000 文字の上限で数える項目の文字数
    var totalLength: Int {
        let fieldsLength = sendableFields.reduce(0) { $0 + $1.name.discordLength + $1.value.discordLength }
        return title.discordLength + description.discordLength + footerText.discordLength + fieldsLength
    }

    private static func isHTTPURL(_ string: String) -> Bool {
        guard let components = URLComponents(string: string),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty else {
            return false
        }
        return true
    }
}
