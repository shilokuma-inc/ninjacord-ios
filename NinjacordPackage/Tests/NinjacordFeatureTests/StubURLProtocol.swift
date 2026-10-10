//
//  StubURLProtocol.swift
//  NinjacordFeatureTests
//

import Foundation

/// 通信せずに、送信先の URL ごとに決めておいたレスポンスかエラーを返す URLProtocol。受け取ったリクエストと本文を URL ごとに記録する。
/// テストごとに `makeURL(returning:)` で別の URL を作って使えば、並べて走るテストどうしで応答と記録が混ざらない
final class StubURLProtocol: URLProtocol {
    enum Stub {
        case response(statusCode: Int, data: Data)
        case error(URLError)
    }

    struct ReceivedRequest {
        let request: URLRequest
        let body: Data?
    }

    /// このプロトコルだけを通す URLSession
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }()

    private static let lock = NSLock()
    private static var stubs: [URL: Stub] = [:]
    private static var receivedRequests: [URL: [ReceivedRequest]] = [:]

    /// まだ使っていない Webhook URL を作り、その URL に送ったときの応答を決める
    static func makeURL(returning stub: Stub) -> URL {
        let url = URL(string: "https://discord.com/api/webhooks/\(UUID().uuidString)/token")!
        lock.withLock {
            stubs[url] = stub
        }
        return url
    }

    /// その URL に送られたリクエスト（送った順）
    static func requests(to url: URL) -> [ReceivedRequest] {
        lock.withLock { receivedRequests[url] ?? [] }
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        // URLProtocol には httpBody ではなく httpBodyStream として渡ってくることがある
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        let stub = Self.lock.withLock {
            Self.receivedRequests[url, default: []].append(ReceivedRequest(request: request, body: body))
            // 応答を決めていない URL（apple.com へのフォールバックなど）には、通信できなかったものとして返す
            return Self.stubs[url] ?? .error(URLError(.cannotConnectToHost))
        }
        switch stub {
        case let .response(statusCode, data):
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .error(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}
