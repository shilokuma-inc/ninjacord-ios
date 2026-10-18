//
//  AvatarImageLoader.swift
//  NinjacordApp
//

import ImageIO
import UIKit

/// メッセージのプレビュー（`MessagePreview`）に出すプロフィール画像を、入力された URL から読み込む。
/// 入力のたびに通信しないよう、入力が止まるのを待ってから読む
struct AvatarImageLoader {
    /// 入力が止まったとみなすまでの待ち時間
    static let defaultDelay: Duration = .milliseconds(500)
    /// 読み込んだ画像を縮める長辺の上限。プレビューのアイコンは 40pt なので、3 倍の画面でも足りる大きさにする
    static let maxPixelSize = 128

    private let session: URLSession
    private let delay: Duration

    /// - Parameters:
    ///   - session: 読み込みに使う URLSession。テストでは URLProtocol のスタブを入れたものを渡す
    ///   - delay: 読み込む前に待つ時間
    init(session: URLSession = .shared, delay: Duration = defaultDelay) {
        self.session = session
        self.delay = delay
    }

    /// 読み込む URL。https でホストを持つものだけ（http は ATS で読めない）。読まないなら nil
    static func url(from string: String) -> URL? {
        guard let components = URLComponents(string: string),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty else {
            return nil
        }
        return components.url
    }

    /// 待ち時間の後に読み込む。待っている間にキャンセルされたら読まない。
    /// 読まない URL・読み込みの失敗・画像として読めないときは nil（既定のアイコンを出す）
    func image(from string: String) async -> UIImage? {
        guard let url = Self.url(from: string) else {
            return nil
        }
        do {
            try await Task.sleep(for: delay)
        } catch {
            return nil
        }
        return await load(url)
    }

    private func load(_ url: URL) async -> UIImage? {
        guard let (data, response) = try? await session.data(from: url),
              let statusCode = (response as? HTTPURLResponse)?.statusCode,
              (200..<300).contains(statusCode) else {
            return nil
        }
        return Self.downsampledImage(from: data)
    }

    /// 大きな画像をそのまま展開してメモリを使い切らないよう、長辺を `maxPixelSize` 以下に縮めて読む（元より大きくはしない）
    static func downsampledImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
