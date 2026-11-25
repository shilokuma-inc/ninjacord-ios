//
//  ForumDestinationTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// フォーラム・メディアチャンネルの宛先の覚え方（`ForumDestinationStore`）と、送信画面でタイトルを付けて送る流れ（Issue #699）
@MainActor
final class ForumDestinationTests {
    private let fixture: SendMessageViewModelFixture
    private var viewModel: SendMessageViewModel { fixture.viewModel }
    private var forumDestinations: ForumDestinationStore { fixture.forumDestinations }
    private var historyStore: SendHistoryStore { fixture.historyStore }

    init() throws {
        fixture = try SendMessageViewModelFixture()
    }

    private static let webhookURL = "https://discord.com/api/webhooks/1180000000000000011/secretTOKEN"

    /// `wait=true` で送ったときのように、作ったメッセージを返す。新しい投稿なら channel_id は作られたスレッド
    private static func sentMessage(id: String, channelID: String) -> StubURLProtocol.Stub {
        .response(statusCode: 200, data: Data(#"{"id": "\#(id)", "channel_id": "\#(channelID)"}"#.utf8))
    }

    private static func discordError(code: Int) -> StubURLProtocol.Stub {
        .response(statusCode: 400, data: Data(#"{"message": "", "code": \#(code)}"#.utf8))
    }

    /// その URL に最初に送った JSON の本文
    private func sentParameters(to url: URL) throws -> [String: Any] {
        let body = try #require(StubURLProtocol.requests(to: url).first?.body)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    /// フォーラムとして覚えた、応答を決めた Webhook URL（ID は数字なので Webhook URL の形を確かめる処理も通る）
    private func forumURL(returning stub: StubURLProtocol.Stub) -> URL {
        let url = StubURLProtocol.makeSnowflakeURL(returning: stub)
        forumDestinations.setForum(true, for: url.absoluteString)
        return url
    }

    // MARK: - 覚え方

    @Test("フォーラムは Webhook の ID で覚え、URL の書き方が違っても同じ Webhook ならフォーラムとみなす")
    func remembersByWebhookID() throws {
        forumDestinations.setForum(true, for: Self.webhookURL)

        let otherForm = " https://discordapp.com/api/v10/webhooks/1180000000000000011/secretTOKEN/\n"
        #expect(forumDestinations.isForum(otherForm))
        #expect(!forumDestinations.isForum("https://discord.com/api/webhooks/1180000000000000012/otherTOKEN"))
        // URL のトークンは保存しない
        let stored = try #require(fixture.userDefaults.stringArray(forKey: "forumWebhookIDs"))
        #expect(stored == ["1180000000000000011"])
        // 別の画面のストアでも読める
        #expect(ForumDestinationStore(userDefaults: fixture.userDefaults).isForum(Self.webhookURL))

        forumDestinations.setForum(false, for: Self.webhookURL)
        #expect(!forumDestinations.isForum(Self.webhookURL))
    }

    @Test("?thread_id= が付いた宛先は既存のスレッドに送るので、フォーラムの Webhook でもタイトルを付けない")
    func threadDestinationIsNotForumPost() {
        let threadURL = Self.webhookURL + "?thread_id=456"
        forumDestinations.setForum(true, for: Self.webhookURL)

        #expect(!ForumDestinationStore.canBeForum(threadURL))
        #expect(!forumDestinations.isForum(threadURL))
        // スレッドの宛先から設定しようとしても覚えない
        forumDestinations.setForum(false, for: threadURL)
        #expect(forumDestinations.isForum(Self.webhookURL))
    }

    @Test("Webhook URL の形でなければ覚えない")
    func ignoresInvalidURL() {
        forumDestinations.setForum(true, for: "https://example.com/hooks/1")
        #expect(forumDestinations.webhookIDs.isEmpty)
        #expect(!ForumDestinationStore.canBeForum(""))
    }

    // MARK: - 送信画面

    @Test("フォーラムでない宛先にはタイトルの欄を出さず、タイトルが残っていても thread_name を送らない")
    func nonForumDestination() async throws {
        let url = StubURLProtocol.makeSnowflakeURL(returning: Self.sentMessage(id: "789", channelID: "42"))
        viewModel.inputURL = url.absoluteString
        viewModel.inputThreadName = "前に入れたタイトル"
        viewModel.inputContext = "こんにちは"

        #expect(!viewModel.isForumDestination)
        // 欄を出していないタイトルは、テンプレート・送信履歴にも残さない
        #expect(viewModel.currentMessage.threadName == "")
        #expect(await fixture.send())

        #expect(try sentParameters(to: url)["thread_name"] == nil)
        let entry = try #require(historyStore.items.first)
        #expect(entry.threadID == nil)
    }

    @Test("フォーラムの宛先でタイトルが空（空白だけも含む）なら、送る前に入力を促す")
    func emptyThreadNameIsRejected() async {
        let url = forumURL(returning: Self.sentMessage(id: "789", channelID: "456"))
        viewModel.inputURL = url.absoluteString
        viewModel.inputThreadName = " "
        viewModel.inputContext = "こんにちは"

        #expect(viewModel.isForumDestination)
        #expect(await fixture.send() == false)

        #expect(viewModel.validationError == .emptyThreadName)
        #expect(viewModel.isValidationAlertPresented)
        #expect(StubURLProtocol.requests(to: url).isEmpty)
    }

    @Test("フォーラムの宛先には thread_name を付けて送り、作られたスレッドの ID とタイトルを送信履歴に残す")
    func sendsForumPost() async throws {
        let url = forumURL(returning: Self.sentMessage(id: "789", channelID: "456"))
        viewModel.inputURL = url.absoluteString
        viewModel.inputThreadName = "週報 11/25"
        viewModel.inputContext = "今週の進捗です"

        #expect(await fixture.send())

        let parameters = try sentParameters(to: url)
        #expect(parameters["thread_name"] as? String == "週報 11/25")
        let entry = try #require(historyStore.items.first)
        #expect(entry.messageID == "789")
        #expect(entry.threadID == "456")
        #expect(entry.message.threadName == "週報 11/25")
    }

    @Test("フォーラムの Webhook でも、?thread_id= が付いた宛先にはタイトルの欄を出さず、thread_name を送らない")
    func threadDestinationOfForum() async throws {
        let url = forumURL(returning: Self.sentMessage(id: "789", channelID: "456"))
        viewModel.inputURL = url.absoluteString + "?thread_id=456"
        viewModel.inputThreadName = "週報"
        viewModel.inputContext = "こんにちは"

        #expect(!viewModel.isForumDestination)
        #expect(await fixture.send())

        #expect(try sentParameters(to: url)["thread_name"] == nil)
        // 送り先のスレッドの ID は URL に付いているので、作られたスレッドとしては覚えない
        #expect(try #require(historyStore.items.first).threadID == nil)
    }

    @Test("新しい投稿の「取り消す」は、作られたスレッドの thread_id を付けて削除し、投稿そのものは残ることを知らせる")
    func undoForumPost() async throws {
        let url = forumURL(returning: Self.sentMessage(id: "789", channelID: "456"))
        let messageURL = try #require(URL(string: url.absoluteString + "/messages/789"))
        StubURLProtocol.stub(messageURL, returning: .response(statusCode: 204, data: Data()))
        viewModel.inputURL = url.absoluteString
        viewModel.inputThreadName = "週報 11/25"
        viewModel.inputContext = "今週の進捗です"
        await fixture.send()

        let undo = try #require(viewModel.toast?.action)
        undo.handler()
        await waitForUndo()

        // Webhook では投稿の最初のメッセージしか消せず、投稿（スレッド）は Discord に残る
        #expect(viewModel.toast?.message.testString == "送信を取り消しました。フォーラムの投稿はDiscordに残ります")
        let received = try #require(StubURLProtocol.requests(to: messageURL).first)
        #expect(received.request.httpMethod == "DELETE")
        #expect(received.request.url?.query == "thread_id=456")
    }

    @Test("220001 が返ったら、その宛先をフォーラムとして覚えてタイトルの欄を出し、原因をトーストに出す")
    func forumTitleRequiredRemembersForum() async throws {
        let url = StubURLProtocol.makeSnowflakeURL(returning: Self.discordError(code: 220001))
        viewModel.inputURL = url.absoluteString
        viewModel.inputContext = "こんにちは"
        #expect(!viewModel.isForumDestination)

        await fixture.send()

        #expect(viewModel.isForumDestination)
        #expect(forumDestinations.isForum(url.absoluteString))
        let toast = try #require(viewModel.toast)
        #expect(toast.style == .failure)
        #expect(toast.message.testString == DiscordWebhookError.forumTitleRequired.localizedDescription)
    }

    @Test("220003 が返ったら、その宛先のフォーラムの設定を外す")
    func notForumChannelForgetsForum() async {
        let url = forumURL(returning: Self.discordError(code: 220003))
        viewModel.inputURL = url.absoluteString
        viewModel.inputThreadName = "週報"
        viewModel.inputContext = "こんにちは"

        await fixture.send()

        #expect(!viewModel.isForumDestination)
        #expect(!forumDestinations.isForum(url.absoluteString))
        #expect(viewModel.toast?.message.testString == DiscordWebhookError.notForumChannel.localizedDescription)
    }

    @Test("一斉送信では、宛先のどれかがフォーラムならタイトルの欄を出し、フォーラムの宛先にだけ thread_name を送る")
    func broadcastSendsThreadNameOnlyToForums() async throws {
        let forum = forumURL(returning: Self.sentMessage(id: "1", channelID: "456"))
        let text = StubURLProtocol.makeSnowflakeURL(returning: Self.sentMessage(id: "2", channelID: "42"))
        viewModel.broadcastTargets = [
            SavedWebhookURL(id: UUID(), name: "フォーラム", url: forum.absoluteString),
            SavedWebhookURL(id: UUID(), name: "お知らせ", url: text.absoluteString)
        ]
        viewModel.inputThreadName = "週報"
        viewModel.inputContext = "こんにちは"

        #expect(viewModel.isForumDestination)
        await fixture.send(isPro: true)

        #expect(try sentParameters(to: forum)["thread_name"] as? String == "週報")
        #expect(try sentParameters(to: text)["thread_name"] == nil)
        #expect(historyStore.items.first { $0.url == forum.absoluteString }?.threadID == "456")
        #expect(historyStore.items.first { $0.url == text.absoluteString }?.threadID == nil)
    }

    @Test("テンプレートのタイトルも入力欄に反映する")
    func applyTemplateThreadName() {
        let message = MessageEntity(
            username: "",
            avatarURL: "",
            content: "本文",
            messageEmbedEntity: MessageEmbedEntity(),
            threadName: "週報"
        )

        viewModel.applyTemplate(MessageTemplate(id: UUID(), name: "週報", message: message, createdAt: Date()))

        #expect(viewModel.inputThreadName == "週報")
    }

    // MARK: - 投稿済み

    @Test("「投稿済み」でも、新しい投稿のメッセージは作られたスレッドの thread_id を付け、覚えていない履歴には付けない")
    func postedListUsesCreatedThread() async throws {
        let forumBase = "https://discord.com/api/webhooks/\(UUID().uuidString)/token"
        let plainBase = "https://discord.com/api/webhooks/\(UUID().uuidString)/token"
        let forumMessageURL = try #require(URL(string: "\(forumBase)/messages/1"))
        let plainMessageURL = try #require(URL(string: "\(plainBase)/messages/2"))
        StubURLProtocol.stub(forumMessageURL, returning: .response(statusCode: 204, data: Data()))
        StubURLProtocol.stub(plainMessageURL, returning: .response(statusCode: 204, data: Data()))
        let message = MessageEntity(
            username: "",
            avatarURL: "",
            content: "本文",
            messageEmbedEntity: MessageEmbedEntity()
        )
        historyStore.record(url: forumBase, message: message, isSuccess: true, messageID: "1", threadID: "456")
        historyStore.record(url: plainBase, message: message, isSuccess: true, messageID: "2")
        let postedList = PostedMessageListViewModel(
            historyStore: historyStore,
            client: DiscordWebhookClient(session: StubURLProtocol.session),
            analytics: AnalyticsSpy(),
            rewardedUnlock: RewardedUnlockSpy(recorder: fixture.recorder),
            haptics: HapticFeedbackSpy()
        )

        for entry in postedList.items {
            await postedList.delete(entry)?.value
        }

        #expect(StubURLProtocol.requests(to: forumMessageURL).map(\.request.url?.query) == ["thread_id=456"])
        #expect(StubURLProtocol.requests(to: plainMessageURL).map(\.request.url?.query) == [nil])
        #expect(postedList.items.isEmpty)
    }

    // MARK: - 宛先の保存

    private func saveModel(url: String) -> SaveDestinationModel {
        SaveDestinationModel(
            initialURL: url,
            store: WebhookURLStore(userDefaults: fixture.userDefaults),
            forumDestinations: forumDestinations,
            client: WebhookProfileClient(session: StubURLProtocol.session),
            sleep: { _ in }
        )
    }

    @Test("宛先を保存するときにフォーラムに設定でき、フォーラムとして覚えた URL なら最初からオンにする")
    func saveDestinationAsForum() async throws {
        let url = StubURLProtocol.makeSnowflakeURL(
            returning: .response(statusCode: 200, data: Data(#"{"id": "1", "name": "掲示板", "avatar": null}"#.utf8))
        )
        let model = saveModel(url: url.absoluteString)
        #expect(model.canBeForum)
        #expect(!model.isForum)

        await model.checkURL()
        model.isForum = true
        #expect(model.save() != nil)

        #expect(forumDestinations.isForum(url.absoluteString))
        #expect(saveModel(url: url.absoluteString).isForum)
    }

    @Test("保存の画面で URL を別の Webhook に替えたら、フォーラムの設定をその Webhook で覚えているものにし直す")
    func saveModelFollowsURL() {
        forumDestinations.setForum(true, for: Self.webhookURL)
        let model = saveModel(url: "")

        model.url = Self.webhookURL
        #expect(model.isForum)
        model.url = "https://discord.com/api/webhooks/1180000000000000012/otherTOKEN"
        #expect(!model.isForum)
        // ?thread_id= が付いた宛先は既存のスレッドに送るので、フォーラムの設定を出さない
        model.url = Self.webhookURL + "?thread_id=456"
        #expect(!model.canBeForum)
    }

    /// 「取り消す」の削除が終わるまで待つ（トーストのボタンは Task を返さないので、トーストが替わるのを見る）
    private func waitForUndo() async {
        for _ in 0..<200 {
            if viewModel.toast?.message.testString == "送信を取り消しました" {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
