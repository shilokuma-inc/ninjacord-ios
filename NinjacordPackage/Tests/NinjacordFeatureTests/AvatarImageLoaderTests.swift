//
//  AvatarImageLoaderTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing
import UIKit

/// メッセージのプレビューに出すプロフィール画像の読み込み（`AvatarImageLoader`）を、URLProtocol のスタブで確かめる
struct AvatarImageLoaderTests {
    private static let pngData = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }

    /// 指定したピクセル数の単色の PNG
    private static func png(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func loader(delay: Duration = .zero) -> AvatarImageLoader {
        AvatarImageLoader(session: StubURLProtocol.session, delay: delay)
    }

    // MARK: - 読む URL

    @Test(
        "https でホストを持つ URL だけ読む",
        arguments: [
            "https://cdn.discordapp.com/avatars/1/a.png",
            "HTTPS://example.com/a.png"
        ]
    )
    func validURL(string: String) {
        #expect(AvatarImageLoader.url(from: string) != nil)
    }

    @Test(
        "空・http・https 以外・ホストが無い URL は読まない",
        arguments: [
            "",
            "   ",
            "http://example.com/a.png",
            "ftp://example.com/a.png",
            "example.com/a.png",
            "https://",
            "プロフィール画像"
        ]
    )
    func invalidURL(string: String) {
        #expect(AvatarImageLoader.url(from: string) == nil)
    }

    // MARK: - 読み込み

    @Test("200 で画像が返れば画像になる")
    func loadsImage() async {
        let url = StubURLProtocol.makeURL(returning: .response(statusCode: 200, data: Self.pngData))
        let image = await loader().image(from: url.absoluteString)
        #expect(image != nil)
        #expect(StubURLProtocol.requests(to: url).count == 1)
    }

    @Test("大きな画像は長辺を maxPixelSize に縮めて読む")
    func downsamplesLargeImage() async throws {
        let largePNG = Self.png(width: 1000, height: 500)
        let url = StubURLProtocol.makeURL(returning: .response(statusCode: 200, data: largePNG))
        let cgImage = try #require(await loader().image(from: url.absoluteString)?.cgImage)
        #expect(cgImage.width == AvatarImageLoader.maxPixelSize)
        #expect(cgImage.height == AvatarImageLoader.maxPixelSize / 2)
    }

    @Test("小さな画像は大きくしない")
    func doesNotUpscaleSmallImage() throws {
        let cgImage = try #require(AvatarImageLoader.downsampledImage(from: Self.png(width: 20, height: 10))?.cgImage)
        #expect(cgImage.width == 20)
        #expect(cgImage.height == 10)
    }

    @Test("2xx 以外なら画像が返っても nil")
    func notFound() async {
        let url = StubURLProtocol.makeURL(returning: .response(statusCode: 404, data: Self.pngData))
        #expect(await loader().image(from: url.absoluteString) == nil)
    }

    @Test("画像として読めなければ nil")
    func notImage() async {
        let url = StubURLProtocol.makeURL(returning: .response(statusCode: 200, data: Data("<html></html>".utf8)))
        #expect(await loader().image(from: url.absoluteString) == nil)
    }

    @Test("通信できなければ nil")
    func connectionError() async {
        let url = StubURLProtocol.makeURL(returning: .error(URLError(.notConnectedToInternet)))
        #expect(await loader().image(from: url.absoluteString) == nil)
    }

    @Test("http の URL は通信せずに nil")
    func httpIsNotLoaded() async {
        let url = StubURLProtocol.makeURL(returning: .response(statusCode: 200, data: Self.pngData))
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "http"
        let httpURL = components?.url
        #expect(await loader().image(from: httpURL?.absoluteString ?? "") == nil)
        if let httpURL {
            #expect(StubURLProtocol.requests(to: httpURL).isEmpty)
        }
    }

    @Test("待っている間にキャンセルされたら通信しない")
    func cancelledWhileWaiting() async {
        let url = StubURLProtocol.makeURL(returning: .response(statusCode: 200, data: Self.pngData))
        let loader = loader(delay: .seconds(60))
        let task = Task {
            await loader.image(from: url.absoluteString)
        }
        task.cancel()
        #expect(await task.value == nil)
        #expect(StubURLProtocol.requests(to: url).isEmpty)
    }
}
