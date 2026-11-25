//
//  WebhookProfileStoreTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// プレビューに出す Webhook の名前とアイコンの取得と使い回し（`WebhookProfileStore`）を、URLProtocol のスタブで確かめる
@MainActor
struct WebhookProfileStoreTests {
    private static let webhookBody = Data(#"{"id": "223704706495545344", "name": "レイド告知Bot", "avatar": null}"#.utf8)

    /// 待ちと今の日時を差し替えた Store 一式
    @MainActor
    private final class Fixture {
        /// 待った時間（待った順）
        var sleeps: [Duration] = []
        /// 今の日時。進めると失敗からの経過が進む
        var now = Date(timeIntervalSince1970: 0)
        /// 待っている間にキャンセルされたものとして投げる
        var cancelsWhileSleeping = false

        private(set) lazy var store = WebhookProfileStore(
            client: WebhookProfileClient(session: StubURLProtocol.session),
            sleep: { [unowned self] duration in
                sleeps.append(duration)
                if cancelsWhileSleeping {
                    throw CancellationError()
                }
            },
            now: { [unowned self] in now }
        )
    }

    // MARK: - 取得

    @Test("入力が止まるのを待ってから取得し、その URL の Webhook として出す")
    func loadsAfterDelay() async {
        let fixture = Fixture()
        let url = StubURLProtocol.makeSnowflakeURL(returning: .response(statusCode: 200, data: Self.webhookBody))
        #expect(fixture.store.profile(for: url.absoluteString) == nil)

        await fixture.store.load(for: url.absoluteString)

        #expect(fixture.sleeps == [WebhookProfileStore.delay])
        #expect(StubURLProtocol.requests(to: url).count == 1)
        #expect(fixture.store.profile(for: url.absoluteString) == WebhookProfile(name: "レイド告知Bot", avatarURL: nil))
    }

    @Test("同じ URL は 2 回目から待たず、通信もしない。クエリだけ違う入力も同じ Webhook として使い回す")
    func reusesLoadedProfile() async {
        let fixture = Fixture()
        let url = StubURLProtocol.makeSnowflakeURL(returning: .response(statusCode: 200, data: Self.webhookBody))
        await fixture.store.load(for: url.absoluteString)

        await fixture.store.load(for: url.absoluteString)
        await fixture.store.load(for: " \(url.absoluteString)?thread_id=1 ")

        #expect(fixture.sleeps.count == 1)
        #expect(StubURLProtocol.requests(to: url).count == 1)
        #expect(fixture.store.profile(for: "\(url.absoluteString)?thread_id=1")?.name == "レイド告知Bot")
    }

    @Test("同じ URL を同時に読みに来ても、通信は 1 回にする（送信画面のカード・プレビュー・送信者の要約が同じ URL を読む）")
    func concurrentLoadsFetchOnce() async {
        let fixture = Fixture()
        // 1 回目の取得が終わる前に 2 回目が来るよう、応答を遅らせる
        let url = StubURLProtocol.makeSnowflakeURL(
            returning: .delayed(0.3, .response(statusCode: 200, data: Self.webhookBody))
        )

        async let first: Void = fixture.store.load(for: url.absoluteString)
        async let second: Void = fixture.store.load(for: url.absoluteString)
        _ = await (first, second)

        #expect(StubURLProtocol.requests(to: url).count == 1)
        #expect(fixture.store.profile(for: url.absoluteString)?.name == "レイド告知Bot")
    }

    @Test("URL が変わったら、前の URL の Webhook は出さない")
    func doesNotShowOtherURLProfile() async {
        let fixture = Fixture()
        let loadedURL = StubURLProtocol.makeSnowflakeURL(returning: .response(statusCode: 200, data: Self.webhookBody))
        let otherURL = StubURLProtocol.makeSnowflakeURL(returning: .response(statusCode: 404, data: Data()))
        await fixture.store.load(for: loadedURL.absoluteString)

        #expect(fixture.store.profile(for: otherURL.absoluteString) == nil)
        await fixture.store.load(for: otherURL.absoluteString)
        #expect(fixture.store.profile(for: otherURL.absoluteString) == nil)
        #expect(fixture.store.profile(for: loadedURL.absoluteString) != nil)
    }

    @Test("Webhook URL の形でなければ、待たずに通信もしない", arguments: ["", "https://example.com/api/webhooks/1/token"])
    func invalidURLDoesNotLoad(input: String) async {
        let fixture = Fixture()
        await fixture.store.load(for: input)
        #expect(fixture.sleeps.isEmpty)
        #expect(fixture.store.profile(for: input) == nil)
    }

    @Test("待っている間にキャンセルされたら通信しない")
    func cancelledWhileWaiting() async {
        let fixture = Fixture()
        fixture.cancelsWhileSleeping = true
        let url = StubURLProtocol.makeSnowflakeURL(returning: .response(statusCode: 200, data: Self.webhookBody))

        await fixture.store.load(for: url.absoluteString)

        #expect(StubURLProtocol.requests(to: url).isEmpty)
        #expect(fixture.store.profile(for: url.absoluteString) == nil)
    }

    @Test("取得を始めた呼び出しがキャンセルされても通信は止めず、同じ URL を待っていた呼び出しの後に出す（プレビューを閉じたときなど）")
    func cancellingFirstLoadKeepsFetchForOthers() async {
        let fixture = Fixture()
        // 取得している間にキャンセルできるよう、応答を遅らせる
        let url = StubURLProtocol.makeSnowflakeURL(
            returning: .delayed(0.3, .response(statusCode: 200, data: Self.webhookBody))
        )
        let first = Task { await fixture.store.load(for: url.absoluteString) }
        await Self.waitUntil { !StubURLProtocol.requests(to: url).isEmpty }
        let second = Task { await fixture.store.load(for: url.absoluteString) }
        // もう一方が同じ URL の取得を待ち始めてから、取得を始めた呼び出しをキャンセルする
        await Task.yield()
        first.cancel()

        await second.value
        #expect(fixture.store.profile(for: url.absoluteString)?.name == "レイド告知Bot")
        await first.value
        #expect(StubURLProtocol.requests(to: url).count == 1)
    }

    @Test("待っている呼び出しがすべてキャンセルされても通信は最後まで行い、同じ URL に戻ったときは通信せずに出す")
    func keepsFetchAfterAllLoadsCancelled() async {
        let fixture = Fixture()
        let url = StubURLProtocol.makeSnowflakeURL(
            returning: .delayed(0.3, .response(statusCode: 200, data: Self.webhookBody))
        )
        let load = Task { await fixture.store.load(for: url.absoluteString) }
        await Self.waitUntil { !StubURLProtocol.requests(to: url).isEmpty }
        load.cancel()

        await Self.waitUntil { fixture.store.profile(for: url.absoluteString) != nil }
        #expect(fixture.store.profile(for: url.absoluteString)?.name == "レイド告知Bot")
        await fixture.store.load(for: url.absoluteString)
        #expect(fixture.sleeps.count == 1)
        #expect(StubURLProtocol.requests(to: url).count == 1)
    }

    // MARK: - 失敗

    @Test(
        "取得に失敗したら nil",
        arguments: [
            StubURLProtocol.Stub.response(statusCode: 404, data: Data()),
            .response(statusCode: 200, data: Data("<html></html>".utf8)),
            .error(URLError(.notConnectedToInternet))
        ]
    )
    func failureIsNil(stub: StubURLProtocol.Stub) async {
        let fixture = Fixture()
        let url = StubURLProtocol.makeSnowflakeURL(returning: stub)
        await fixture.store.load(for: url.absoluteString)
        #expect(StubURLProtocol.requests(to: url).count == 1)
        #expect(fixture.store.profile(for: url.absoluteString) == nil)
    }

    @Test("失敗した URL へは、しばらく取得し直さない。間隔が過ぎたら取得し直す")
    func retriesFailureAfterInterval() async {
        let fixture = Fixture()
        let url = StubURLProtocol.makeSnowflakeURL(returning: .error(URLError(.notConnectedToInternet)))
        await fixture.store.load(for: url.absoluteString)

        fixture.now += WebhookProfileStore.failureRetryInterval - 1
        await fixture.store.load(for: url.absoluteString)
        #expect(StubURLProtocol.requests(to: url).count == 1)

        fixture.now += 1
        await fixture.store.load(for: url.absoluteString)
        #expect(StubURLProtocol.requests(to: url).count == 2)
    }

    /// 条件を満たすまで少しずつ待つ（スタブにリクエストが届くのは通信のキューの上なので、すぐには分からない）。
    /// 3 秒ほど待っても満たさなければ諦め、後の `#expect` で落とす
    private static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 300 {
            guard !condition() else {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
