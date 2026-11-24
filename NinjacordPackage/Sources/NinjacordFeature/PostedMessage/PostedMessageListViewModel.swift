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
    private let rewardedUnlock: RewardedUnlockConsuming
    private let haptics: HapticFeedbackPlaying

    convenience init() {
        self.init(
            historyStore: SendHistoryStore(),
            client: DiscordWebhookClient(),
            analytics: FirebaseAnalytics(),
            rewardedUnlock: RewardedUnlockState.shared,
            haptics: HapticFeedback()
        )
    }

    /// 引数なしの `init()` は今までと同じ実体を使う。テストではそれぞれ差し替えたものを渡す
    /// - Parameter rewardedUnlock: リワード広告の一時解放。編集（Pro 機能）に成功したら使い切る
    init(
        historyStore: SendHistoryStore,
        client: DiscordWebhookClient,
        analytics: PostedMessageAnalytics,
        rewardedUnlock: RewardedUnlockConsuming,
        haptics: HapticFeedbackPlaying
    ) {
        self.historyStore = historyStore
        self.messageEditor = WebhookMessageEditor(client: client, analytics: analytics)
        self.rewardedUnlock = rewardedUnlock
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
            let result = await messageEditor.delete(
                webhookURL: entry.url,
                messageID: messageID,
                threadID: entry.threadID,
                source: .postedList
            )
            processingMessageIDs.remove(messageID)
            switch result {
            case .success:
                historyStore.markDeleted(messageID: messageID)
                items = historyStore.postedItems
                toast = Toast(style: .success, message: "メッセージを削除しました")
                haptics.playNotification(isSuccess: true)
            case .failure(let error):
                // 原因の文言は送信のときと同じものなので、削除に失敗したことを先に書く
                toast = Toast(
                    style: .failure,
                    verbatimMessage: String(localized: "削除できませんでした。\(error.localizedDescription)")
                )
                haptics.playNotification(isSuccess: false)
            }
        }
    }

    /// 編集を保存する（Pro 限定）。本文と埋め込みを Discord で書き換え、成功したら送信履歴の中身も書き換える
    /// - Parameters:
    ///   - message: 編集後の中身。名前・アイコンは Discord の仕様で変えられないので使わない
    ///   - canUseProFeatures: 編集を使えるか（Pro 購読中か、リワード広告の一時解放中）
    /// - Returns: 保存できなかったときの原因。保存できたら nil
    func edit(
        _ entry: SendHistoryEntry,
        message: MessageEntity,
        canUseProFeatures: Bool
    ) async -> PostedMessageEditError? {
        guard let messageID = entry.messageID else {
            return .discord(.unknownMessage)
        }
        if let error = PostedMessageEditError.validate(
            message,
            hasAttachment: entry.hasAttachment,
            canUseProFeatures: canUseProFeatures
        ) {
            return error
        }
        processingMessageIDs.insert(messageID)
        let result = await messageEditor.edit(
            webhookURL: entry.url,
            messageID: messageID,
            threadID: entry.threadID,
            message: message,
            sentAt: entry.sentAt
        )
        processingMessageIDs.remove(messageID)
        switch result {
        case .success:
            historyStore.markEdited(messageID: messageID, message: message)
            items = historyStore.postedItems
            // 編集は Pro 機能。リワード広告の一時解放は、送信と同じく 1 回の編集で使い切る（Discussion #386）
            rewardedUnlock.consumeIfUnlocked()
            toast = Toast(style: .success, message: "メッセージを編集しました")
            haptics.playNotification(isSuccess: true)
            return nil
        case .failure(let error):
            if error == .unknownMessage {
                // Discord で消されていたら、もう編集も削除もできないので一覧から外す
                historyStore.markDeleted(messageID: messageID)
                items = historyStore.postedItems
            }
            haptics.playNotification(isSuccess: false)
            return .discord(error)
        }
    }
}
