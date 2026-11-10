//
//  ImageAttachmentThumbnailTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing
import UIKit

/// メッセージのプレビューに出す添付画像の縮小（`ImageAttachment.thumbnail`）を確かめる
struct ImageAttachmentThumbnailTests {
    private func attachment(width: CGFloat, height: CGFloat) -> ImageAttachment {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: width, height: height)
        let data = UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return ImageAttachment(data: data, fileName: "image.png", mimeType: "image/png")
    }

    @Test("長辺を maxPixelSize に収め、縦横比は保つ")
    func shrinksLongSide() {
        let thumbnail = attachment(width: 400, height: 200).thumbnail(maxPixelSize: 100)
        #expect(thumbnail?.width == 100)
        #expect(thumbnail?.height == 50)
    }

    @Test("元より大きくはしない")
    func doesNotEnlarge() {
        let thumbnail = attachment(width: 40, height: 20).thumbnail(maxPixelSize: 100)
        #expect(thumbnail?.width == 40)
        #expect(thumbnail?.height == 20)
    }

    @Test("画像として読めなければ nil")
    func notImage() {
        let attachment = ImageAttachment(data: Data("not image".utf8), fileName: "image.png", mimeType: "image/png")
        #expect(attachment.thumbnail(maxPixelSize: 100) == nil)
    }
}
