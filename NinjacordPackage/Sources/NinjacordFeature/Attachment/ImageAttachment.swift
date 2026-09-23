//
//  ImageAttachment.swift
//  NinjacordApp
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

/// メッセージに添付する画像（1 枚）。テンプレート・送信履歴には保存しない
struct ImageAttachment: Equatable {
    let data: Data
    let fileName: String
    let mimeType: String

    /// Discord のファイルサイズ上限（ブーストなしのサーバー）
    static let maxFileSize = 10 * 1024 * 1024

    /// Discord でそのまま表示できる形式。HEIC などはクライアントによって表示されないため JPEG に変換する
    private static let passthroughTypes: [UTType] = [.jpeg, .png, .gif, .webP]

    /// 写真から読み込んだデータを添付用にする。
    /// Discord で表示できる形式で上限内ならそのまま、それ以外は JPEG に変換し、上限を超えるなら画質・大きさを下げて収める。
    /// 収まらない・画像として読めない場合は nil
    static func make(from data: Data, maxFileSize: Int = maxFileSize) -> ImageAttachment? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeIdentifier = CGImageSourceGetType(source) as String?,
              let type = UTType(typeIdentifier) else {
            return nil
        }
        if data.count <= maxFileSize,
           passthroughTypes.contains(type),
           let fileExtension = type.preferredFilenameExtension,
           let mimeType = type.preferredMIMEType {
            return ImageAttachment(data: data, fileName: "image.\(fileExtension)", mimeType: mimeType)
        }
        guard let jpeg = jpegData(from: source, maxFileSize: maxFileSize) else { return nil }
        return ImageAttachment(data: jpeg, fileName: "image.jpg", mimeType: "image/jpeg")
    }

    /// 画質を下げても上限を超えるときは、長辺を 3/4 ずつ縮めてやり直す
    private static func jpegData(from source: CGImageSource, maxFileSize: Int) -> Data? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        var maxPixelSize = max(width, height)
        for _ in 0..<6 {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            for quality in [0.9, 0.75, 0.6] {
                if let data = encodeJPEG(image, quality: quality), data.count <= maxFileSize {
                    return data
                }
            }
            maxPixelSize = maxPixelSize * 3 / 4
        }
        return nil
    }

    private static func encodeJPEG(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        let jpeg = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(data, jpeg, 1, nil) else {
            return nil
        }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
