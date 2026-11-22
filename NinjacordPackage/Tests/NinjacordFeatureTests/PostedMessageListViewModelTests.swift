//
//  PostedMessageListViewModelTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 「投稿済み」タブの操作（`PostedMessageListViewModel`）。送信履歴のうち送れたメッセージを出し、削除・編集する（Issue #666）
@MainActor
final class PostedMessageListViewModelTests {
    private let suiteName = "PostedMessageListViewModelTests.\(UUID().uuidString)"
    private let userDefaults: UserDefaults
    private let historyStore: SendHistoryStore
    private let analytics = AnalyticsSpy()
    private let haptics = HapticFeedbackSpy()
    private let viewModel: PostedMessageListViewModel

    private static let message = MessageEntity(
        username: "レイド告知Bot",
        avatarURL: "",
        content: "今夜21:00 レイド開始",
        messageEmbedEntity: MessageEmbedEntity()
    )

    init() throws {
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.set(true, forKey: SendHistoryStore.isEnabledKey)
        historyStore = SendHistoryStore(userDefaults: userDefaults)
        viewModel = PostedMessageListViewModel(
            historyStore: historyStore,
            client: DiscordWebhookClient(session: StubURLProtocol.session),
            analytics: analytics,
            haptics: haptics
        )
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    /// 送れたメッセージを送信履歴に残し、そのメッセージの URL（編集・削除の宛先）への応答を決める
    @discardableResult
    private func recordPosted(
        id messageID: String = "789",
        returning stub: StubURLProtocol.Stub = .response(statusCode: 204, data: Data()),
        hasAttachment: Bool = false
    ) -> (entry: SendHistoryEntry, messageURL: URL) {
        let base = "https://discord.com/api/webhooks/\(UUID().uuidString)/token"
        let messageURL = URL(string: "\(base)/messages/\(messageID)")!
        StubURLProtocol.stub(messageURL, returning: stub)
        historyStore.record(
            url: base,
            message: Self.message,
            isSuccess: true,
            messageID: messageID,
            hasAttachment: hasAttachment
        )
        viewModel.reload()
        return (viewModel.items.first { $0.messageID == messageID }!, messageURL)
    }

    // MARK: - 一覧

    @Test("送信履歴のうち、送れて ID があり、削除していないものだけを新しい順に出す")
    func items() {
        recordPosted(id: "1")
        historyStore.record(url: "https://discord.com/api/webhooks/1/token", message: Self.message, isSuccess: false)
        recordPosted(id: "2")

        #expect(viewModel.items.map(\.messageID) == ["2", "1"])
    }

    @Test("別の画面で送った分は、読み直すと出る")
    func reload() {
        SendHistoryStore(userDefaults: userDefaults)
            .record(url: "https://discord.com/api/webhooks/1/token", message: Self.message, isSuccess: true, messageID: "1")
        #expect(viewModel.items.isEmpty)

        viewModel.reload()

        #expect(viewModel.items.map(\.messageID) == ["1"])
    }

    // MARK: - 削除

    @Test("削除したら一覧から外し、送信履歴に削除済みの印を付けてトーストで知らせる")
    func deleteSucceeded() async throws {
        let (entry, messageURL) = recordPosted()

        let task = try #require(viewModel.delete(entry))
        #expect(viewModel.processingMessageIDs == ["789"])
        await task.value

        #expect(viewModel.processingMessageIDs.isEmpty)
        #expect(StubURLProtocol.requests(to: messageURL).map(\.request.httpMethod) == ["DELETE"])
        #expect(viewModel.items.isEmpty)
        #expect(try #require(SendHistoryStore(userDefaults: userDefaults).items.first).deletedAt != nil)
        let toast = try #require(viewModel.toast)
        #expect(toast.style == .success)
        #expect(toast.message.testString == "メッセージを削除しました")
        #expect(haptics.notifications == [true])
        #expect(analytics.deleteEvents.map(\.source) == ["posted_list"])
    }

    @Test("Discord で先に消されていたときも、一覧から外す")
    func deleteAlreadyDeleted() async throws {
        let body = Data(#"{"message": "Unknown Message", "code": 10008}"#.utf8)
        let (entry, _) = recordPosted(returning: .response(statusCode: 404, data: body))

        await viewModel.delete(entry)?.value

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.toast?.style == .success)
    }

    @Test("削除できなければ原因をトーストに出し、一覧に残す")
    func deleteFailed() async throws {
        let (entry, _) = recordPosted(returning: .error(URLError(.notConnectedToInternet)))

        await viewModel.delete(entry)?.value

        #expect(viewModel.items.map(\.messageID) == ["789"])
        let toast = try #require(viewModel.toast)
        #expect(toast.style == .failure)
        #expect(toast.message.testString == DiscordWebhookError.network.localizedDescription)
        #expect(haptics.notifications == [false])
    }

    @Test("削除の通信中は、同じメッセージをもう一度削除しない")
    func deleteTwice() async {
        let (entry, messageURL) = recordPosted()

        let first = viewModel.delete(entry)
        let second = viewModel.delete(entry)
        await first?.value

        #expect(second == nil)
        #expect(StubURLProtocol.requests(to: messageURL).count == 1)
    }
}
