//
//  SendMessageHapticsTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信画面の操作で鳴らす振動（`SendMessageViewModel` に渡した `HapticFeedbackPlaying`）を確かめる
@MainActor
final class SendMessageHapticsTests {
    private let fixture: SendMessageViewModelFixture
    private var viewModel: SendMessageViewModel { fixture.viewModel }
    private var haptics: HapticFeedbackSpy { fixture.haptics }

    init() throws {
        fixture = try SendMessageViewModelFixture()
    }

    private static let noContent = StubURLProtocol.Stub.response(statusCode: 204, data: Data())
    private static let notFound = StubURLProtocol.Stub.response(statusCode: 404, data: Data())

    @Test("送信ボタンを押したら、送る前に 1 回だけ軽く振動させる")
    func impactOnSend() async {
        viewModel.inputURL = StubURLProtocol.makeURL(returning: Self.noContent).absoluteString
        viewModel.inputContext = "こんにちは"

        let task = viewModel.sendMessage(isPro: false, screenActions: fixture.screenActions)
        #expect(haptics.impactCount == 1)
        // 送信中に呼ばれても（ボタンは無効になっている）振動させない
        viewModel.sendMessage(isPro: false, screenActions: fixture.screenActions)
        await task?.value

        #expect(haptics.impactCount == 1)
    }

    @Test("入力チェックで止まっても、押したことが分かるよう振動させる")
    func impactOnValidationError() async {
        let didStart = await fixture.send()

        #expect(!didStart)
        #expect(haptics.impactCount == 1)
    }

    @Test("一斉送信でも、押したときに 1 回だけ振動させる")
    func impactOnBroadcast() async {
        viewModel.broadcastTargets = [
            fixture.savedURL("雑談", returning: Self.noContent),
            fixture.savedURL("お知らせ", returning: Self.noContent)
        ]
        viewModel.inputContext = "こんにちは"

        await fixture.send(isPro: true)

        #expect(haptics.impactCount == 1)
    }

    // MARK: - 送信結果

    @Test("送信に成功したら、成功の振動を 1 回鳴らす")
    func notificationOnSuccess() async {
        viewModel.inputURL = StubURLProtocol.makeURL(returning: Self.noContent).absoluteString
        viewModel.inputContext = "こんにちは"

        await fixture.send()

        #expect(haptics.notifications == [true])
    }

    @Test("送信に失敗したら、失敗の振動を 1 回鳴らす")
    func notificationOnFailure() async {
        viewModel.inputURL = StubURLProtocol.makeURL(returning: Self.notFound).absoluteString
        viewModel.inputContext = "こんにちは"

        await fixture.send()

        #expect(haptics.notifications == [false])
    }

    @Test("入力チェックで止まったら、結果の振動は鳴らさない（アラートで知らせる）")
    func noNotificationOnValidationError() async {
        await fixture.send()

        #expect(haptics.notifications.isEmpty)
    }

    @Test("一斉送信は、宛先の数によらず全件が終わったときに 1 回だけ鳴らす")
    func notificationOnBroadcast() async {
        viewModel.broadcastTargets = [
            fixture.savedURL("雑談", returning: Self.noContent),
            fixture.savedURL("お知らせ", returning: Self.noContent),
            fixture.savedURL("告知", returning: Self.noContent)
        ]
        viewModel.inputContext = "こんにちは"

        await fixture.send(isPro: true)

        #expect(haptics.notifications == [true])
    }

    @Test("一斉送信の一部が失敗したら、失敗の振動を 1 回だけ鳴らす")
    func notificationOnBroadcastPartialFailure() async {
        viewModel.broadcastTargets = [
            fixture.savedURL("消えた Webhook", returning: Self.notFound),
            fixture.savedURL("雑談", returning: Self.noContent)
        ]
        viewModel.inputContext = "こんにちは"

        await fixture.send(isPro: true)

        #expect(haptics.notifications == [false])
    }
}
