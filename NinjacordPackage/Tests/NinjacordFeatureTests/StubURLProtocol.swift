//
//  StubURLProtocol.swift
//  NinjacordFeatureTests
//

import Foundation

/// 通信せずに、送信先の URL ごとに決めておいたレスポンスかエラーを返す URLProtocol。受け取ったリクエストと本文を URL ごとに記録する。
/// テストごとに `makeURL(returning:)` で別の URL を作って使えば、並べて走るテストどうしで応答と記録が混ざらない。
/// 送信では `?wait=true` などのクエリを付けて送るので、応答と記録はクエリを除いた URL で引く（受け取った URL はクエリ付きのまま残す）
final class StubURLProtocol: URLProtocol {
    indirect enum Stub {
        case response(statusCode: Int, data: Data)
        case error(URLError)
        /// 指定した秒数だけ待ってから応答する（ほかの処理より後に返したいとき）
        case delayed(TimeInterval, Stub)
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

    /// `makeURL(returning:)` と同じく、まだ使っていない Webhook URL を作って応答を決める。
    /// ID を Discord と同じ数字にするので、Webhook URL の形を確かめる処理（`DiscordWebhookURL`）も通る
    static func makeSnowflakeURL(returning stub: Stub) -> URL {
        let id = UInt64.random(in: 1 ... .max)
        let url = URL(string: "https://discord.com/api/webhooks/\(id)/token")!
        lock.withLock {
            stubs[url] = stub
        }
        return url
    }

    /// その URL（送った編集・削除の URL など）に送ったときの応答を決める
    static func stub(_ url: URL, returning stub: Stub) {
        lock.withLock {
            stubs[key(for: url)] = stub
        }
    }

    /// その URL に送られたリクエスト（送った順）。クエリは見ない
    static func requests(to url: URL) -> [ReceivedRequest] {
        lock.withLock { receivedRequests[key(for: url)] ?? [] }
    }

    /// 応答と記録を引くための、クエリとフラグメントを除いた URL
    private static func key(for url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.query = nil
        components.fragment = nil
        return components.url ?? url
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
        let key = Self.key(for: url)
        let stub = Self.lock.withLock {
            Self.receivedRequests[key, default: []].append(ReceivedRequest(request: request, body: body))
            // 応答を決めていない URL には、通信できなかったものとして返す
            return Self.stubs[key] ?? .error(URLError(.cannotConnectToHost))
        }
        respond(with: stub, to: url)
    }

    private func respond(with stub: Stub, to url: URL) {
        switch stub {
        case let .delayed(seconds, stub):
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { [self] in
                respond(with: stub, to: url)
            }
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
