//
//  SendMessageSucceededTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信に成功したあとの流れ（リワード解放の消費・ATT・レビュー依頼・全画面広告）と、
/// 送信の Analytics・送信成功回数の今の挙動を固定する。View から ViewModel に移したあとも、順番と条件が変わらないことを確かめる
@MainActor
final class SendMessageSucceededTests {
    private let fixture: SendMessageViewModelFixture
    private var viewModel: SendMessageViewModel { fixture.viewModel }
    private var recorder: SendSucceededRecorder { fixture.recorder }
    private var analytics: AnalyticsSpy { fixture.analytics }

    // 既定引数から参照するので、MainActor に縛らない
    private nonisolated static let noContent = StubURLProtocol.Stub.response(statusCode: 204, data: Data())
    private static let notFound = StubURLProtocol.Stub.response(statusCode: 404, data: Data())
    /// Pro 限定の項目（フッター）が入った埋め込み
    private static let proEmbed = MessageEmbedEntity(title: "お知らせ", footerText: "Ninjacord")

    init() throws {
        fixture = try SendMessageViewModelFixture()
    }

    /// これまでの送信成功回数を決めてから、URL 欄の宛先に 1 件送る
    private func send(
        afterSuccessCount successCount: Int = 0,
        returning stub: StubURLProtocol.Stub = noContent,
        embed: MessageEmbedEntity = MessageEmbedEntity(),
        isPro: Bool = false
    ) async {
        for _ in 0..<successCount {
            fixture.sendSuccessCounter.increment()
        }
        viewModel.inputURL = StubURLProtocol.makeURL(returning: stub).absoluteString
        viewModel.inputContext = "こんにちは"
        viewModel.inputEmbed = embed
        await fixture.send(isPro: isPro)
    }

    /// これまでの送信成功回数を決めてから、宛先ごとに応答を決めて一斉送信する
    private func broadcast(afterSuccessCount successCount: Int = 0, returning stubs: [StubURLProtocol.Stub]) async {
        for _ in 0..<successCount {
            fixture.sendSuccessCounter.increment()
        }
        viewModel.broadcastTargets = stubs.enumerated().map { index, stub in
            fixture.savedURL("宛先\(index + 1)", returning: stub)
        }
        viewModel.inputContext = "こんにちは"
        await fixture.send(isPro: true)
    }

    // MARK: - リワード広告の一時解放

    @Test("Pro 機能を使っていない送信では、リワード広告の一時解放を消費しない")
    func doesNotConsumeRewardedUnlockWithoutProFeatures() async {
        await send()

        #expect(!recorder.events.contains(.consumeRewardedUnlock))
    }

    @Test("Pro 限定の項目を使った送信に成功したら、最初にリワード広告の一時解放を消費する")
    func consumesRewardedUnlockWithProFeatures() async {
        await send(embed: Self.proEmbed, isPro: true)

        #expect(recorder.events.first == .consumeRewardedUnlock)
        let consumeCount = recorder.events.filter { $0 == .consumeRewardedUnlock }.count
        #expect(consumeCount == 1)
    }

    // MARK: - レビュー依頼

    @Test("ちょうど 3 回目の送信に成功したときだけ、レビューを依頼する", arguments: [0, 1, 2, 3, 4])
    func requestsReviewOnThirdSend(previousSuccessCount: Int) async {
        await send(afterSuccessCount: previousSuccessCount)

        #expect(recorder.events.contains(.requestReview) == (previousSuccessCount + 1 == 3))
    }

    @Test("リワード解放の消費 → ATT → レビュー依頼の順で行い、3 回目では全画面広告を出さない")
    func orderOnThirdSend() async {
        await send(afterSuccessCount: 2, embed: Self.proEmbed, isPro: true)

        #expect(recorder.events == [.consumeRewardedUnlock, .requestTracking, .requestReview])
    }

    // MARK: - 全画面広告

    @Test("3 回目より後で ATT を尋ねなかった送信では、1 秒待ってから View から渡した画面に全画面広告を出す")
    func showsInterstitialAfterThirdSend() async {
        await send(afterSuccessCount: 3)

        #expect(recorder.events == [
            .requestTracking,
            .sleep(.seconds(1)),
            .showInterstitial(from: fixture.rootViewController)
        ])
    }

    @Test("ATT のダイアログを出した送信では、全画面広告を出さない")
    func doesNotShowInterstitialAfterTrackingDialog() async {
        recorder.trackingDialogWillBeShown = true

        await send(afterSuccessCount: 5)

        #expect(recorder.events == [.requestTracking])
    }

    @Test("3 回目までの送信では、全画面広告を出さない", arguments: [0, 1, 2])
    func doesNotShowInterstitialUntilThirdSend(previousSuccessCount: Int) async {
        await send(afterSuccessCount: previousSuccessCount)

        #expect(!recorder.events.contains(.showInterstitial(from: fixture.rootViewController)))
        #expect(!recorder.events.contains(.sleep(.seconds(1))))
    }

    @Test("一斉送信は 1 回の操作で 1 回と数え、3 回目ならレビューを依頼する")
    func broadcastCountsAsOneSend() async {
        await broadcast(afterSuccessCount: 2, returning: [Self.noContent, Self.notFound, Self.noContent])

        #expect(fixture.sendSuccessCounter.count == 3)
        #expect(recorder.events == [.consumeRewardedUnlock, .requestTracking, .requestReview])
    }

    // MARK: - 送信成功回数と Analytics

    @Test("送信のたびに結果と HTTP ステータスを Analytics に送り、初めての成功だけ first_send_completed を送る")
    func analyticsOnSuccess() async {
        await send()
        await send()

        #expect(analytics.sendEvents == [
            AnalyticsSpy.SendEvent(isSuccess: true, httpStatus: 204),
            AnalyticsSpy.SendEvent(isSuccess: true, httpStatus: 204)
        ])
        #expect(analytics.firstSendCompletedCount == 1)
        #expect(fixture.sendSuccessCounter.count == 2)
    }

    @Test("失敗した送信は Analytics に失敗として送り、送信成功回数に数えない")
    func analyticsOnFailure() async {
        await send(returning: Self.notFound)
        await send(returning: .error(URLError(.notConnectedToInternet)))

        // 通信できずレスポンスが無いときの HTTP ステータスは nil（Analytics の側で 0 にする）
        #expect(analytics.sendEvents == [
            AnalyticsSpy.SendEvent(isSuccess: false, httpStatus: 404),
            AnalyticsSpy.SendEvent(isSuccess: false, httpStatus: nil)
        ])
        #expect(analytics.firstSendCompletedCount == 0)
        #expect(fixture.sendSuccessCounter.count == 0)
        #expect(recorder.events.isEmpty)
    }

    @Test("一斉送信は宛先ごとに Analytics に送り、1 件でも届けば送信成功回数を 1 回増やす")
    func analyticsOnBroadcast() async {
        await broadcast(returning: [Self.noContent, Self.notFound])

        #expect(analytics.sendEvents == [
            AnalyticsSpy.SendEvent(isSuccess: true, httpStatus: 204),
            AnalyticsSpy.SendEvent(isSuccess: false, httpStatus: 404)
        ])
        #expect(analytics.firstSendCompletedCount == 1)
        #expect(fixture.sendSuccessCounter.count == 1)
    }

    @Test("一斉送信がすべて失敗したら、送信成功回数は増やさない")
    func broadcastAllFailed() async {
        await broadcast(returning: [Self.notFound, Self.notFound])

        #expect(fixture.sendSuccessCounter.count == 0)
        #expect(analytics.firstSendCompletedCount == 0)
        #expect(recorder.events.isEmpty)
    }
}
