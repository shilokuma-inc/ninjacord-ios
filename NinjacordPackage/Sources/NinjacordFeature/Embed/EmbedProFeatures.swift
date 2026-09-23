//
//  EmbedProFeatures.swift
//  NinjacordApp
//

import Foundation

/// 埋め込みのうち Pro 限定の項目。Discussion #259 の決定により、無料は title + description まで
extension MessageEmbedEntity {
    /// color / fields / image / thumbnail / footer / timestamp のいずれかが入っているか
    var usesProFeatures: Bool {
        color != nil || !sendableFields.isEmpty || !imageURL.isEmpty || !thumbnailURL.isEmpty
            || !footerText.isEmpty || includesTimestamp
    }

    /// Pro 限定の項目を空にする（Pro を解約した人が、送れるように消すため）
    mutating func removeProFeatures() {
        color = nil
        fields = []
        imageURL = ""
        thumbnailURL = ""
        footerText = ""
        includesTimestamp = false
    }
}
