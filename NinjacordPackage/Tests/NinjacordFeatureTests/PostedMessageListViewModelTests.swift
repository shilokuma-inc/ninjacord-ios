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
    /// リワード広告の一時解放の消費を記録する
    private let recorder = SendSucceededRecorder()
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
            rewardedUnlock: RewardedUnlockSpy(recorder: recorder),
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
        #expect(
            toast.message.testString
                == String(localized: "削除できませんでした。\(DiscordWebhookError.network.localizedDescription)")
        )
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

    // MARK: - 編集

    private static let edited = MessageEntity(
        username: "レイド告知Bot",
        avatarURL: "",
        content: "今夜21:30 レイド開始（変更）",
        messageEmbedEntity: MessageEmbedEntity(title: "お知らせ")
    )

    @Test("編集を保存したら Discord で書き換え、送信履歴の中身を書き換えてトーストで知らせる")
    func editSucceeded() async throws {
        let (entry, messageURL) = recordPosted(returning: .response(statusCode: 200, data: Data(#"{"id": "789"}"#.utf8)))

        let error = await viewModel.edit(entry, message: Self.edited, canUseProFeatures: true)

        #expect(error == nil)
        let received = try #require(StubURLProtocol.requests(to: messageURL).first)
        #expect(received.request.httpMethod == "PATCH")
        let item = try #require(viewModel.items.first)
        #expect(item.message == Self.edited)
        #expect(item.editedAt != nil)
        #expect(try #require(SendHistoryStore(userDefaults: userDefaults).items.first).message == Self.edited)
        #expect(viewModel.toast?.message.testString == "メッセージを編集しました")
        #expect(viewModel.processingMessageIDs.isEmpty)
        #expect(haptics.notifications == [true])
        // 編集は Pro 機能なので、リワード広告の一時解放を使い切る
        #expect(recorder.events == [.consumeRewardedUnlock])
        #expect(analytics.editEvents == [.init(isSuccess: true, httpStatus: 200)])
    }

    @Test("Pro でなければ（一時解放もなければ）、通信せずに Pro 限定だと返す")
    func editRequiresPro() async {
        let (entry, messageURL) = recordPosted()

        let error = await viewModel.edit(entry, message: Self.edited, canUseProFeatures: false)

        #expect(error == .proRequired)
        #expect(StubURLProtocol.requests(to: messageURL).isEmpty)
        #expect(recorder.events.isEmpty)
    }

    @Test("画像の無いメッセージは、本文（空白だけも含む）と埋め込みを両方とも空にできない")
    func editEmptyMessage() async {
        let (entry, messageURL) = recordPosted()
        var empty = Self.edited
        empty.content = "  \n"
        empty.messageEmbedEntity = MessageEmbedEntity()

        let error = await viewModel.edit(entry, message: empty, canUseProFeatures: true)

        #expect(error == .emptyMessage)
        #expect(StubURLProtocol.requests(to: messageURL).isEmpty)
    }

    @Test("画像を添付して送ったメッセージは、画像が残るので本文と埋め込みを空にできる")
    func editEmptyMessageWithAttachment() async {
        let (entry, _) = recordPosted(
            returning: .response(statusCode: 200, data: Data(#"{"id": "789"}"#.utf8)),
            hasAttachment: true
        )
        var empty = Self.edited
        empty.content = ""
        empty.messageEmbedEntity = MessageEmbedEntity()

        let error = await viewModel.edit(entry, message: empty, canUseProFeatures: true)

        #expect(error == nil)
    }

    @Test("埋め込みが Discord の上限を超えていたら、通信せずに理由を返す")
    func editInvalidEmbed() async throws {
        let (entry, messageURL) = recordPosted()
        var invalid = Self.edited
        invalid.messageEmbedEntity = MessageEmbedEntity(title: String(repeating: "あ", count: EmbedLimit.title + 1))

        let error = await viewModel.edit(entry, message: invalid, canUseProFeatures: true)

        let issue = try #require(invalid.messageEmbedEntity.validationIssues().first)
        #expect(error == .invalidEmbed(issue))
        #expect(StubURLProtocol.requests(to: messageURL).isEmpty)
    }

    @Test("Discord で消されていたら、編集できないと返して一覧から外す")
    func editAlreadyDeleted() async {
        let body = Data(#"{"message": "Unknown Message", "code": 10008}"#.utf8)
        let (entry, _) = recordPosted(returning: .response(statusCode: 404, data: body))

        let error = await viewModel.edit(entry, message: Self.edited, canUseProFeatures: true)

        #expect(error == .discord(.unknownMessage))
        #expect(viewModel.items.isEmpty)
        #expect(haptics.notifications == [false])
        #expect(recorder.events.isEmpty)
    }

    @Test("通信に失敗したら原因を返し、送信履歴の中身は変えない")
    func editFailed() async throws {
        let (entry, _) = recordPosted(returning: .error(URLError(.notConnectedToInternet)))

        let error = await viewModel.edit(entry, message: Self.edited, canUseProFeatures: true)

        #expect(error == .discord(.network))
        #expect(try #require(viewModel.items.first).message == Self.message)
        #expect(viewModel.toast == nil)
    }

    @Test("本文を空のまま初期文言で送ったメッセージは、編集画面に初期文言を入れておく")
    func editableMessage() {
        var message = Self.message
        message.content = ""
        let defaulted = SendHistoryEntry(id: UUID(), sentAt: Date(), url: "", message: message, isSuccess: true)
        #expect(defaulted.editableMessage.content == DiscordWebhookRequest.defaultContent)

        let withAttachment = SendHistoryEntry(
            id: UUID(), sentAt: Date(), url: "", message: message, isSuccess: true, hasAttachment: true
        )
        #expect(withAttachment.editableMessage.content.isEmpty)

        let normal = SendHistoryEntry(id: UUID(), sentAt: Date(), url: "", message: Self.message, isSuccess: true)
        #expect(normal.editableMessage == Self.message)
    }
}
