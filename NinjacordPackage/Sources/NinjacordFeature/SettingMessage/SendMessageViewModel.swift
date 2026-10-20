//
//  SendMessageViewModel.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/28.
//

import Foundation
import SwiftUI

/// 送信画面の状態と操作。Discord への通信は DiscordWebhookClient、送信履歴の保存は SendHistoryStore に任せる。
/// 送信に成功したあとの流れ（リワード解放の消費・レビュー依頼・全画面広告）もここで行う
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
    /// 初期文言で送る前の確認ダイアログの中身。出していないときは nil
    @Published private(set) var defaultValueConfirmation: DefaultValueConfirmation?
    @Published var isDefaultValueConfirmationPresented = false

    private let client: DiscordWebhookClient
    private let historyStore: SendHistoryStore
    private let analytics: SendMessageAnalytics
    private let sendSuccessCounter: SendSuccessCounter
    private let rewardedUnlock: RewardedUnlockConsuming
    private let interstitialAd: InterstitialAdPresenting
    private let haptics: HapticFeedbackPlaying
    private let defaultValueConfirmationSetting: DefaultValueConfirmationSetting
    /// 指定した時間だけ待つ。テストでは待たずに、待った時間を記録する
    private let sleep: @MainActor (Duration) async -> Void

    /// 何回目の送信成功でレビューを依頼するか
    private static let reviewRequestSendCount = 3

    convenience init() {
        self.init(
            client: DiscordWebhookClient(),
            historyStore: SendHistoryStore(),
            analytics: FirebaseAnalytics(),
            sendSuccessCounter: SendSuccessCounter(),
            rewardedUnlock: RewardedUnlockState.shared,
            interstitialAd: InterstitialAdManager.shared,
            haptics: HapticFeedback(),
            defaultValueConfirmationSetting: DefaultValueConfirmationSetting(),
            sleep: { duration in try? await Task.sleep(for: duration) }
        )
    }

    /// 引数なしの `init()` は今までと同じ実体（`.shared` など）を使う。テストではそれぞれ差し替えたものを渡す
    /// - Parameters:
    ///   - client: Discord への通信
    ///   - historyStore: 送信履歴の保存先
    ///   - analytics: 送信の Analytics
    ///   - sendSuccessCounter: 送信成功回数（初回送信の計測・レビュー依頼・全画面広告の判定に使う）
    ///   - rewardedUnlock: リワード広告の一時解放
    ///   - interstitialAd: 送信のあとに出す全画面広告
    ///   - haptics: 送信ボタンを押したとき・送信が終わったときの振動
    ///   - defaultValueConfirmationSetting: 初期文言で送る前に確認するかの設定
    ///   - sleep: 全画面広告の前にトーストを見せるための待ち
    init(
        client: DiscordWebhookClient,
        historyStore: SendHistoryStore,
        analytics: SendMessageAnalytics,
        sendSuccessCounter: SendSuccessCounter,
        rewardedUnlock: RewardedUnlockConsuming,
        interstitialAd: InterstitialAdPresenting,
        haptics: HapticFeedbackPlaying,
        defaultValueConfirmationSetting: DefaultValueConfirmationSetting,
        sleep: @escaping @MainActor (Duration) async -> Void
    ) {
        self.client = client
        self.historyStore = historyStore
        self.analytics = analytics
        self.sendSuccessCounter = sendSuccessCounter
        self.rewardedUnlock = rewardedUnlock
        self.interstitialAd = interstitialAd
        self.haptics = haptics
        self.defaultValueConfirmationSetting = defaultValueConfirmationSetting
        self.sleep = sleep

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
    /// - Parameter countsAsSend: 送信成功回数（初回送信の計測・レビュー依頼・全画面広告の判定に使う）に数えるか。
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

    /// 入力内容を検証し、問題があればダイアログを表示、なければ Webhook に送信する。
    /// アプリの初期文言に置き換わる項目があり、確認の設定がオンなら、送らずに確認ダイアログを出す
    /// - Parameters:
    ///   - isPro: Pro 購読中か。Pro 限定の項目・一斉送信を使えるかの判定に使う
    ///   - screenActions: 送信に成功したあとの流れで使う、View の環境から来るもの（レビュー依頼・全画面広告の表示元）
    /// - Returns: 送信を始めたときは、その Task（テストで送信が終わるのを待つため）。始めなかったときは nil
    @discardableResult
    func sendMessage(isPro: Bool, screenActions: SendMessageScreenActions) -> Task<Void, Never>? {
        guard !isSending else { return nil }
        // 押したことが手に伝わるよう、入力チェックで止まる場合も含めてタップのたびに振動させる
        haptics.playImpact()

        let messageEntity = currentMessage
        let hasAttachment = attachment != nil
        let destination: PendingSend.Destination
        let error: SendMessageValidationError?
        if !broadcastTargets.isEmpty {
            let urls = broadcastTargets.map(\.url)
            destination = .broadcast(urls: urls)
            // 宛先を選んだあとに Pro でなくなった場合は送らない
            error = ProFeatureAccess.canUse(isPro: isPro)
                ? validate(
                    url: urls[0], messageEntity: messageEntity, hasAttachment: hasAttachment, canUseProFeatures: true
                )
                : .proBroadcast
        } else {
            // 送信中に URL 欄が書き換えられても、実際に送った先を履歴に残す
            destination = .single(url: inputURL)
            error = validate(
                url: inputURL,
                messageEntity: messageEntity,
                hasAttachment: hasAttachment,
                canUseProFeatures: ProFeatureAccess.canUse(isPro: isPro)
            )
        }
        if let error {
            validationError = error
            isValidationAlertPresented = true
            return nil
        }

        let pendingSend = PendingSend(destination: destination, messageEntity: messageEntity, attachment: attachment)
        let defaultedFields = pendingSend.defaultedFields
        if !defaultedFields.isEmpty && defaultValueConfirmationSetting.isEnabled {
            defaultValueConfirmation = DefaultValueConfirmation(
                pendingSend: pendingSend,
                defaultedFields: defaultedFields
            )
            isDefaultValueConfirmationPresented = true
            return nil
        }
        return send(pendingSend, screenActions: screenActions)
    }

    /// 確認ダイアログで「このまま送信」「送信して今後は表示しない」を押したとき。ボタンを押した時点の中身を送る
    /// - Parameter disablesConfirmation: 確認の設定をオフにしてから送るか
    /// - Returns: 送信を始めたときは、その Task。始めなかったときは nil
    @discardableResult
    func confirmDefaultValueSend(
        disablesConfirmation: Bool,
        screenActions: SendMessageScreenActions
    ) -> Task<Void, Never>? {
        guard let confirmation = defaultValueConfirmation else { return nil }
        defaultValueConfirmation = nil
        // ダイアログ中は送信を始めないので通常は通らない。送らないときは設定も変えない
        guard !isSending else { return nil }
        if disablesConfirmation {
            defaultValueConfirmationSetting.isEnabled = false
        }
        return send(confirmation.pendingSend, screenActions: screenActions)
    }

    /// 確認ダイアログで「キャンセル」を押したとき。何も送らず、入力も消さない
    func cancelDefaultValueSend() {
        defaultValueConfirmation = nil
    }

    private func send(_ pendingSend: PendingSend, screenActions: SendMessageScreenActions) -> Task<Void, Never> {
        switch pendingSend.destination {
        case .single(let url):
            return sendSingle(pendingSend, to: url, screenActions: screenActions)
        case .broadcast(let urls):
            return sendBroadcast(pendingSend, to: urls, screenActions: screenActions)
        }
    }

    private func sendSingle(
        _ pendingSend: PendingSend,
        to url: String,
        screenActions: SendMessageScreenActions
    ) -> Task<Void, Never> {
        let messageEntity = pendingSend.messageEntity
        isSending = true
        return Task {
            let result = await postDiscordWebhook(
                url: url,
                messageEntity: messageEntity,
                attachment: pendingSend.attachment
            )
            isSending = false
            // 設定で「送信履歴を保存する」が ON のときだけ記録される
            historyStore.record(url: url, message: messageEntity, isSuccess: (try? result.get()) != nil)
            switch result {
            case .success:
                toast = Toast(style: .success, message: "送信しました")
                haptics.playNotification(isSuccess: true)
                await handleSendSucceeded(
                    usedProFeatures: messageEntity.messageEmbedEntity.usesProFeatures,
                    screenActions: screenActions
                )
            case .failure(let error):
                toast = Toast(style: .failure, verbatimMessage: error.localizedDescription)
                haptics.playNotification(isSuccess: false)
            }
        }
    }

    /// 選んだ宛先に一斉送信する（Pro 限定）
    private func sendBroadcast(
        _ pendingSend: PendingSend,
        to urls: [String],
        screenActions: SendMessageScreenActions
    ) -> Task<Void, Never> {
        let messageEntity = pendingSend.messageEntity
        isSending = true
        return Task {
            let results = await broadcast(to: urls, messageEntity: messageEntity, attachment: pendingSend.attachment)
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
            // 宛先ごとではなく、全件が終わったときに 1 回だけ。1 件でも失敗したらトーストと同じく失敗にする
            haptics.playNotification(isSuccess: failureCount == 0)
            if failureCount < results.count {
                // 一斉送信そのものが Pro 機能
                await handleSendSucceeded(usedProFeatures: true, screenActions: screenActions)
            }
        }
    }

    /// 送信に成功したあとのリワード広告の解放の消費・レビュー依頼・インタースティシャル広告
    /// - Parameter usedProFeatures: 埋め込みの Pro 限定の項目や一斉送信など、Pro 機能を使った送信か
    private func handleSendSucceeded(usedProFeatures: Bool, screenActions: SendMessageScreenActions) async {
        // リワード広告の一時解放は、Pro 機能を使った 1 回の送信で使い切る（Discussion #386・判断ログ #389）。
        // 一斉送信は宛先の数ではなく 1 回の操作で 1 回と数え、1 件でも成功していれば使い切る
        if usedProFeatures {
            rewardedUnlock.consumeIfUnlocked()
        }
        // 成功回数は postDiscordWebhook / broadcast で記録済み。ちょうど 3 回目の送信のときだけ依頼する
        let sendSuccessCount = sendSuccessCounter.count
        if sendSuccessCount == Self.reviewRequestSendCount {
            screenActions.requestReview()
        }
        // 広告の印象が付いたままレビューを依頼しないよう、全画面広告はレビュー依頼の次の送信から出す
        if sendSuccessCount > Self.reviewRequestSendCount {
            // 成功のトーストを見てもらってから表示する
            await sleep(.seconds(1))
            interstitialAd.showIfAllowed(from: screenActions.rootViewController())
        }
    }
}
