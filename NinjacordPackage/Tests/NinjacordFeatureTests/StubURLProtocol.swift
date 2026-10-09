//
//  StubURLProtocol.swift
//  NinjacordFeatureTests
//

import Foundation

/// 通信せずに、決めておいたレスポンスかエラーを返す URLProtocol。受け取ったリクエストと本文を記録する。
/// 状態を static に持つので、使うテストのスイートは `.serialized` にする
final class StubURLProtocol: URLProtocol {
    enum Stub {
        case response(statusCode: Int, data: Data)
        case error(URLError)
    }

    struct ReceivedRequest {
        let request: URLRequest
        let body: Data?
    }

    private static let lock = NSLock()
    private static var stub = Stub.response(statusCode: 204, data: Data())
    private static var receivedRequests: [ReceivedRequest] = []

    /// このプロトコルだけを通す URLSession
    static func makeSession(returning stub: Stub) -> URLSession {
        lock.withLock {
            self.stub = stub
            receivedRequests = []
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static var requests: [ReceivedRequest] {
        lock.withLock { receivedRequests }
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        // URLProtocol には httpBody ではなく httpBodyStream として渡ってくることがある
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        let stub = Self.lock.withLock {
            Self.receivedRequests.append(ReceivedRequest(request: request, body: body))
            return Self.stub
        }
        switch stub {
        case let .response(statusCode, data):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                  ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
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
