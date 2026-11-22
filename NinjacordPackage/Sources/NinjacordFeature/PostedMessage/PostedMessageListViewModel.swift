//
//  PostedMessageListViewModel.swift
//  NinjacordApp
//

import Foundation

/// 「投稿済み」タブの状態と操作。送信履歴のうち送れたメッセージを並べ、削除（無料）と編集（Pro）を行う（Issue #666）。
/// Discord への通信は WebhookMessageEditor、編集・削除の結果の保存は SendHistoryStore に任せる
@MainActor
final class PostedMessageListViewModel: ObservableObject {
    /// 編集・削除できるメッセージ（新しい順）
    @Published private(set) var items: [SendHistoryEntry] = []
    /// 削除・編集の通信中のメッセージの ID。行にローディングを出し、二重に操作させない
    @Published private(set) var processingMessageIDs: Set<String> = []
    /// 削除・編集の結果を知らせるトースト
    @Published var toast: Toast?

    private let historyStore: SendHistoryStore
    private let messageEditor: WebhookMessageEditor
    private let haptics: HapticFeedbackPlaying

    convenience init() {
        self.init(
            historyStore: SendHistoryStore(),
            client: DiscordWebhookClient(),
            analytics: FirebaseAnalytics(),
            haptics: HapticFeedback()
        )
    }

    /// 引数なしの `init()` は今までと同じ実体を使う。テストではそれぞれ差し替えたものを渡す
    init(
        historyStore: SendHistoryStore,
        client: DiscordWebhookClient,
        analytics: PostedMessageAnalytics,
        haptics: HapticFeedbackPlaying
    ) {
        self.historyStore = historyStore
        self.messageEditor = WebhookMessageEditor(client: client, analytics: analytics)
        self.haptics = haptics
        reload()
    }

    /// 送信履歴を読み直す。送信画面で送った分・設定画面で消した分を反映する
    func reload() {
        historyStore.reload()
        items = historyStore.postedItems
    }

    /// 送ったメッセージを Discord から削除する（無料）。削除したら（Discord で先に消されていたときも）一覧から外す
    /// - Returns: 削除を始めたときは、その Task（テストで終わるのを待つため）。ID が無い・通信中なら nil
    @discardableResult
    func delete(_ entry: SendHistoryEntry) -> Task<Void, Never>? {
        guard let messageID = entry.messageID, !processingMessageIDs.contains(messageID) else {
            return nil
        }
        processingMessageIDs.insert(messageID)
        return Task {
            let result = await messageEditor.delete(webhookURL: entry.url, messageID: messageID, source: .postedList)
            processingMessageIDs.remove(messageID)
            switch result {
            case .success:
                historyStore.markDeleted(messageID: messageID)
                items = historyStore.postedItems
                toast = Toast(style: .success, message: "メッセージを削除しました")
                haptics.playNotification(isSuccess: true)
            case .failure(let error):
                toast = Toast(style: .failure, verbatimMessage: error.localizedDescription)
                haptics.playNotification(isSuccess: false)
            }
        }
    }
}
