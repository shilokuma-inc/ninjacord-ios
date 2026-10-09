//
//  SendMessageViewModel.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/28.
//

import Foundation
import SwiftUI

/// 送信画面の状態と操作。Discord への通信は DiscordWebhookClient、送信履歴の保存は SendHistoryStore に任せる
@MainActor
final class SendMessageViewModel: ObservableObject {
    @Published var inputURL = ""
    @Published var inputUsername = ""
    @Published var inputAvatarURL = ""
    @Published var inputContext = ""

    /// 埋め込み。タイトルは送信画面で、それ以外の項目は embed エディタで入力する
    @Published var inputEmbed = MessageEmbedEntity()

    @Published private(set) var validationError: SendMessageValidationError?
    @Published var isValidationAlertPresented: Bool = false
    /// 添付する画像（1 枚）。テンプレート・送信履歴には保存しない
    @Published var attachment: ImageAttachment?
    /// 一斉送信（Pro 限定）の宛先。空なら URL 欄の宛先に送る
    @Published var broadcastTargets: [SavedWebhookURL] = []
    /// Webhook への送信中かどうか。送信中はボタンにローディングを出し、二重送信を防ぐ
    @Published private(set) var isSending = false
    /// 送信結果を知らせるトースト
    @Published var toast: Toast?

    private let analytics = FirebaseAnalytics()
    private let sendSuccessCounter = SendSuccessCounter()
    private let client: DiscordWebhookClient
    private let historyStore: SendHistoryStore

    convenience init() {
        self.init(client: DiscordWebhookClient(), historyStore: SendHistoryStore())
    }

    /// - Parameters:
    ///   - client: Discord への通信。テストでは URLProtocol のスタブを入れたものを渡す
    ///   - historyStore: 送信履歴の保存先
    init(client: DiscordWebhookClient, historyStore: SendHistoryStore) {
        self.client = client
        self.historyStore = historyStore

        // App Store 用スクリーンショットの撮影モードでは、デモの内容を入力しておく
        guard ScreenshotDemo.isEnabled else { return }
        let content = ScreenshotDemo.content
        inputURL = content.url
        inputUsername = content.message.username
        inputAvatarURL = content.message.avatarURL
        inputContext = content.message.content
        inputEmbed = content.message.messageEmbedEntity
        attachment = ScreenshotDemo.attachment
        if ScreenshotDemo.scene == .broadcast {
            broadcastTargets = ScreenshotDemo.broadcastTargets
        }
    }

    /// Webhook にメッセージを送信する。通信が完了（成功・失敗とも）するまで待機し、送信結果を返す。
    /// 失敗時は Discord のレスポンスから判定した原因を返す
    @discardableResult
    /// - Parameter countsAsSend: 送信成功回数（初回送信の計測・ATT・レビュー依頼の判定に使う）に数えるか。
    ///   一斉送信では宛先ごとではなく 1 回の操作で 1 回と数えるため、呼び出し元でまとめて数える
    /// - Parameter attachment: 添付する画像。あれば multipart/form-data で送る
    public func postDiscordWebhook(
        url: String,
        messageEntity: MessageEntity,
        attachment: ImageAttachment? = nil,
        countsAsSend: Bool = true
    ) async -> Result<Void, DiscordWebhookError> {
        let webhookRequest = DiscordWebhookRequest(messageEntity: messageEntity, attachment: attachment)
        // URL にできないときは apple.com に送る（今の挙動のまま。#472）
        let endpoint = URL(string: url) ?? URL(string: "https://www.apple.com/")!
        let response = await client.send(webhookRequest, to: endpoint)
        analytics.sendMessageSendEvent(
            isSuccess: (try? response.result.get()) != nil,
            httpStatus: response.statusCode
        )
        if case .success = response.result, countsAsSend {
            recordSendSuccess()
        }
        return response.result
    }
}

extension SendMessageViewModel {
    /// 一斉送信の宛先 1 件ごとの結果
    struct BroadcastResult {
        let url: String
        let result: Result<Void, DiscordWebhookError>
    }

    /// 複数の Webhook に同じメッセージを 1 件ずつ順に送る（Pro 限定の一斉送信）。
    /// Discord の送信制限は Webhook ごとなので、宛先が違えば続けて送ってよい
    func broadcast(
        to urls: [String],
        messageEntity: MessageEntity,
        attachment: ImageAttachment? = nil
    ) async -> [BroadcastResult] {
        var results: [BroadcastResult] = []
        for url in urls {
            let result = await postDiscordWebhook(
                url: url,
                messageEntity: messageEntity,
                attachment: attachment,
                countsAsSend: false
            )
            results.append(BroadcastResult(url: url, result: result))
        }
        // 送信成功回数は、1 件でも届いていれば一斉送信 1 回につき 1 回と数える
        if results.contains(where: { (try? $0.result.get()) != nil }) {
            recordSendSuccess()
        }
        return results
    }

    private func recordSendSuccess() {
        if sendSuccessCounter.increment() == 1 {
            analytics.sendFirstSendCompletedEvent()
        }
    }
}

// MARK: - 送信画面の操作

extension SendMessageViewModel {
    /// 入力欄の内容から組み立てた、送信・テンプレート保存用のメッセージ
    var currentMessage: MessageEntity {
        MessageEntity(
            username: inputUsername,
            avatarURL: inputAvatarURL,
            content: inputContext,
            messageEmbedEntity: inputEmbed
        )
    }

    /// テンプレートの中身を入力欄に反映する。宛先（URL）はそのまま残す
    func applyTemplate(_ template: MessageTemplate) {
        inputUsername = template.message.username
        inputAvatarURL = template.message.avatarURL
        inputContext = template.message.content
        inputEmbed = template.message.messageEmbedEntity
    }

    /// 入力内容を検証し、問題があればダイアログを表示、なければ Webhook に送信する
    /// - Parameters:
    ///   - isPro: Pro 購読中か。Pro 限定の項目・一斉送信を使えるかの判定に使う
    ///   - onSucceeded: 送信に成功したあとの流れ（レビュー依頼・広告など、View の環境を使うもの）。
    ///     Pro 機能を使った送信かを受け取る
    /// - Returns: 送信を始めたときは、その Task（テストで送信が終わるのを待つため）。始めなかったときは nil
    @discardableResult
    func sendMessage(
        isPro: Bool,
        onSucceeded: @escaping @MainActor (_ usedProFeatures: Bool) async -> Void
    ) -> Task<Void, Never>? {
        guard !isSending else { return nil }

        let messageEntity = currentMessage

        if !broadcastTargets.isEmpty {
            return sendBroadcast(messageEntity, isPro: isPro, onSucceeded: onSucceeded)
        }

        if let error = validate(
            url: inputURL,
            messageEntity: messageEntity,
            canUseProFeatures: ProFeatureAccess.canUse(isPro: isPro)
        ) {
            validationError = error
            isValidationAlertPresented = true
            return nil
        }

        isSending = true
        // 送信中に URL 欄が書き換えられても、実際に送った先を履歴に残す
        let url = inputURL
        return Task {
            let result = await postDiscordWebhook(
                url: url,
                messageEntity: messageEntity,
                attachment: attachment
            )
            isSending = false
            // 設定で「送信履歴を保存する」が ON のときだけ記録される
            historyStore.record(url: url, message: messageEntity, isSuccess: (try? result.get()) != nil)
            switch result {
            case .success:
                toast = Toast(style: .success, message: "送信しました")
                await onSucceeded(messageEntity.messageEmbedEntity.usesProFeatures)
            case .failure(let error):
                toast = Toast(style: .failure, verbatimMessage: error.localizedDescription)
            }
        }
    }

    /// 選んだ宛先に一斉送信する（Pro 限定）
    private func sendBroadcast(
        _ messageEntity: MessageEntity,
        isPro: Bool,
        onSucceeded: @escaping @MainActor (_ usedProFeatures: Bool) async -> Void
    ) -> Task<Void, Never>? {
        let urls = broadcastTargets.map(\.url)
        // 宛先を選んだあとに Pro でなくなった場合は送らない
        let error: SendMessageValidationError? = ProFeatureAccess.canUse(isPro: isPro)
            ? validate(url: urls[0], messageEntity: messageEntity, canUseProFeatures: true)
            : .proBroadcast
        if let error {
            validationError = error
            isValidationAlertPresented = true
            return nil
        }

        isSending = true
        return Task {
            let results = await broadcast(to: urls, messageEntity: messageEntity, attachment: attachment)
            isSending = false
            let failureCount = results.filter { (try? $0.result.get()) == nil }.count
            for result in results {
                let isSuccess = (try? result.result.get()) != nil
                historyStore.record(url: result.url, message: messageEntity, isSuccess: isSuccess)
            }
            if failureCount == 0 {
                toast = Toast(style: .success, message: "\(results.count)件の宛先に送信しました")
            } else {
                toast = Toast(style: .failure, message: "\(results.count)件中\(failureCount)件の送信に失敗しました")
            }
            if failureCount < results.count {
                // 一斉送信そのものが Pro 機能
                await onSucceeded(true)
            }
        }
    }
}

// MARK: - 入力バリデーション

/// 送信前の入力チェックで検出したエラー。アラートのタイトル・本文として表示する
enum SendMessageValidationError: LocalizedError, Equatable {
    /// 送信先 URL が未入力
    case emptyURL
    /// 送信先 URL が URL の形式になっていない
    case invalidURL
    /// URL 以外の項目がすべて未入力
    case emptyMessage
    /// 埋め込みが Discord の上限を超えているなど
    case invalidEmbed(EmbedValidationIssue)
    /// Pro でないのに、埋め込みに Pro 限定の項目が入っている
    case proEmbedFeatures
    /// Pro でないのに、一斉送信の宛先が選ばれている
    case proBroadcast

    var errorDescription: String? {
        switch self {
        case .emptyURL:
            return String(localized: "URLが入力されていません")
        case .invalidURL:
            return String(localized: "URLの形式が正しくありません")
        case .emptyMessage:
            return String(localized: "メッセージが入力されていません")
        case .invalidEmbed:
            return String(localized: "埋め込みの内容を確認してください")
        case .proEmbedFeatures:
            return String(localized: "Pro限定の項目が入っています")
        case .proBroadcast:
            return String(localized: "一斉送信はNinjacord Pro限定です")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyURL:
            return String(localized: "送信先のWebhook URLを入力してください")
        case .invalidURL:
            return String(localized: "https:// から始まるWebhook URLを入力してください")
        case .emptyMessage:
            return String(localized: "名前・メッセージなど、いずれかの項目を入力してください")
        case .invalidEmbed(let issue):
            return issue.message
        case .proEmbedFeatures:
            return String(localized: "埋め込みの色・フィールド・画像・サムネイル・フッター・送信日時はNinjacord Pro限定です。埋め込みの編集から消すか、Proにしてください")
        case .proBroadcast:
            return String(localized: "宛先の選択を解除して1件ずつ送るか、Proにしてください")
        }
    }
}

extension SendMessageViewModel {
    /// 送信前に入力内容を検証する。問題がなければ nil を返す
    /// - Parameter canUseProFeatures: Pro 限定の項目を使えるか（Pro 購読中など）
    func validate(url: String, messageEntity: MessageEntity, canUseProFeatures: Bool) -> SendMessageValidationError? {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedURL.isEmpty {
            return .emptyURL
        }
        if !isValidURL(trimmedURL) {
            return .invalidURL
        }
        if !messageEntity.hasContent {
            return .emptyMessage
        }
        if !canUseProFeatures && messageEntity.messageEmbedEntity.usesProFeatures {
            return .proEmbedFeatures
        }
        // 最初の 1 件だけを示す（直して送り直せば次の誤りが分かる）
        if let issue = messageEntity.messageEmbedEntity.validationIssues().first {
            return .invalidEmbed(issue)
        }
        return nil
    }

    /// http / https のスキームとホストを持つ URL かどうか
    private func isValidURL(_ string: String) -> Bool {
        guard let components = URLComponents(string: string),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty else {
            return false
        }
        return true
    }
}
