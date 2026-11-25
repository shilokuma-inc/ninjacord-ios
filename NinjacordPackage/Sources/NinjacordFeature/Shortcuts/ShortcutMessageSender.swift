//
//  ShortcutMessageSender.swift
//  NinjacordApp
//

import Foundation

/// ショートカットからの送信の Analytics。テストでは呼ばれ方を記録するものに差し替える
protocol ShortcutSendAnalytics {
    func sendMessageSendEvent(isSuccess: Bool, httpStatus: Int?, source: String)
}

extension FirebaseAnalytics: ShortcutSendAnalytics {}

/// ショートカット（App Intents）から、保存した宛先にメッセージを送る（Issue #700）。
/// アプリを開かずにバックグラウンドで送るので、送信画面の流れ（初期文言の確認・トースト・レビュー依頼・広告）は通らない。
/// 送信履歴と「投稿済み」には送信画面と同じく残し、送信成功の回数（ATT の要求・レビュー依頼）には数えない
@MainActor
struct ShortcutMessageSender {
    /// 送る内容。宛先・テンプレートはアプリ内の ID で受け取り、Webhook URL（トークンを含む）はショートカットに持たせない
    struct Request {
        let destinationID: SavedWebhookURL.ID
        let templateID: MessageTemplate.ID?
        /// 指定すればテンプレートの本文を置き換える。空白・改行だけなら指定しなかったものとして扱う
        let body: String?
    }

    private let client: DiscordWebhookClient
    private let urlStore: WebhookURLStore
    private let templateStore: MessageTemplateStore
    private let historyStore: SendHistoryStore
    private let analytics: ShortcutSendAnalytics

    init() {
        self.init(
            client: DiscordWebhookClient(),
            urlStore: WebhookURLStore(),
            templateStore: MessageTemplateStore(),
            historyStore: SendHistoryStore(),
            analytics: FirebaseAnalytics()
        )
    }

    /// 引数なしの `init()` は今までと同じ実体を使う。テストではそれぞれ差し替えたものを渡す
    init(
        client: DiscordWebhookClient,
        urlStore: WebhookURLStore,
        templateStore: MessageTemplateStore,
        historyStore: SendHistoryStore,
        analytics: ShortcutSendAnalytics
    ) {
        self.client = client
        self.urlStore = urlStore
        self.templateStore = templateStore
        self.historyStore = historyStore
        self.analytics = analytics
    }

    /// 宛先・テンプレートを ID から探し、無料の制限と中身を確かめてから送る。
    /// 確かめた時点で送れないと分かったときは、通信せず、送信履歴にも残さない
    /// - Parameter isPro: Pro を購読中か。無料では、ショートカットで使えるテンプレートは一覧の先頭の 1 件だけ
    func send(_ request: Request, isPro: Bool) async -> Result<ShortcutSendSuccess, ShortcutSendError> {
        // アプリで宛先・テンプレートを変えたあとでも、最新の内容で送る
        urlStore.reload()
        templateStore.reload()
        guard let destination = urlStore.items.first(where: { $0.id == request.destinationID }) else {
            return .failure(.destinationNotFound)
        }
        var template: MessageTemplate?
        if let templateID = request.templateID {
            guard let found = templateStore.items.first(where: { $0.id == templateID }) else {
                return .failure(.templateNotFound)
            }
            guard isPro || found.id == templateStore.shortcutFreeTemplateID else {
                return .failure(.proTemplateRequired)
            }
            template = found
        }
        guard let message = Self.makeMessage(template: template, body: request.body) else {
            return .failure(.emptyMessage)
        }
        if let error = Self.validate(message, isPro: isPro) {
            return .failure(error)
        }
        let result = await post(message, to: destination.url)
        // 送信画面と同じく、設定で「送信履歴を保存する」が ON のときだけ記録される。ID も残し、「投稿済み」から編集・削除できるようにする
        historyStore.record(
            url: destination.url,
            message: message,
            isSuccess: (try? result.get()) != nil,
            messageID: (try? result.get())?.id
        )
        switch result {
        case .success:
            return .success(ShortcutSendSuccess(destinationName: destination.name))
        case .failure(let error):
            return .failure(.discord(error))
        }
    }

    /// 送るメッセージを組み立てる。テンプレートがあればその中身（名前・アイコン・埋め込みなど）を使い、
    /// 本文が指定されていればテンプレートの本文だけを置き換える。テンプレートも本文も無ければ nil
    static func makeMessage(template: MessageTemplate?, body: String?) -> MessageEntity? {
        let replacement = body.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        guard template != nil || replacement != nil else {
            return nil
        }
        var message = template?.message ?? MessageEntity(
            username: "",
            avatarURL: "",
            content: "",
            messageEmbedEntity: MessageEmbedEntity()
        )
        if let replacement {
            message.content = replacement
        }
        return message
    }

    /// 送る前に分かる誤り。送信画面の入力チェック（`SendMessageViewModel.validate`）と同じ順で確かめる。
    /// Pro 限定の項目は、リワード広告の一時解放では使えない（画面の無い送信で、解放を使い切る場面が無いため）
    static func validate(_ message: MessageEntity, isPro: Bool) -> ShortcutSendError? {
        // 名前・アイコンだけのテンプレートなど、本文がアプリの初期文言に置き換わるものは送らない。
        // 送信画面なら送る前に確認が出るが、ショートカットでは誰も見ていないところで初期文言が投稿されるため
        if !message.hasContent || !DiscordWebhookRequest(messageEntity: message).defaultedFields.isEmpty {
            return .emptyMessage
        }
        if !isPro && message.messageEmbedEntity.usesProFeatures {
            return .proEmbedFeatures
        }
        if let issue = message.messageEmbedEntity.validationIssues().first {
            return .invalidEmbed(issue)
        }
        return nil
    }

    /// Webhook に送り、送信元をショートカットとして Analytics に記録する。
    /// URL にできなければ、送信画面と同じく通信せずに invalidToken にする
    private func post(
        _ message: MessageEntity,
        to url: String
    ) async -> Result<SentWebhookMessage, DiscordWebhookError> {
        let response: DiscordWebhookClient.Response<SentWebhookMessage>
        if let endpoint = SendMessageViewModel.webhookEndpoint(from: url) {
            response = await client.send(DiscordWebhookRequest(messageEntity: message), to: endpoint)
        } else {
            response = DiscordWebhookClient.Response(statusCode: nil, result: .failure(.invalidToken))
        }
        analytics.sendMessageSendEvent(
            isSuccess: (try? response.result.get()) != nil,
            httpStatus: response.statusCode,
            source: MessageSendSource.shortcut.rawValue
        )
        return response.result
    }
}

extension MessageTemplateStore {
    /// 無料のときにショートカットで使えるテンプレート（Discussion #376 の C-2）。一覧の先頭の 1 件。
    /// 一覧は利用者が並べ替え・ピン留めできるので、どれを使うかを利用者が選べる。テンプレートが無ければ nil
    var shortcutFreeTemplateID: MessageTemplate.ID? {
        items.first?.id
    }
}

/// ショートカットからの送信に成功したときの結果。ショートカットのアプリに短い文言で返す
struct ShortcutSendSuccess: Equatable {
    /// 送った宛先に付けた名前。Webhook URL は出さない
    let destinationName: String

    var message: String {
        String(localized: "「\(destinationName)」に送信しました")
    }
}

/// ショートカットからの送信に失敗した原因。ショートカットのアプリにエラーの文言として返す。
/// 文言には Webhook URL（トークンを含む）を出さない
enum ShortcutSendError: LocalizedError, Equatable {
    /// 選んだ宛先がアプリに無い（削除された）
    case destinationNotFound
    /// 選んだテンプレートがアプリに無い（削除された）
    case templateNotFound
    /// テンプレートも本文も無い・送る中身が無い
    case emptyMessage
    /// 無料では使えないテンプレート（一覧の先頭以外）を選んだ
    case proTemplateRequired
    /// Pro でないのに、テンプレートの埋め込みに Pro 限定の項目が入っている
    case proEmbedFeatures
    /// 埋め込みが Discord の上限を超えているなど
    case invalidEmbed(EmbedValidationIssue)
    /// Discord への送信に失敗した
    case discord(DiscordWebhookError)

    var message: String {
        switch self {
        case .destinationNotFound:
            return String(localized: "宛先が見つかりません。アプリで削除されていないか確かめて、ショートカットで宛先を選び直してください")
        case .templateNotFound:
            return String(localized: "テンプレートが見つかりません。アプリで削除されていないか確かめて、ショートカットでテンプレートを選び直してください")
        case .emptyMessage:
            return String(localized: "送る内容がありません。テンプレートを選ぶか、本文を入れてください")
        case .proTemplateRequired:
            return String(localized: "無料プランでショートカットに使えるテンプレートは、一覧の先頭の1件だけです。ほかのテンプレートを使うには、Ninjacord Proにしてください")
        case .proEmbedFeatures:
            return String(localized: "テンプレートの埋め込みにPro限定の項目が入っています。アプリでテンプレートから消すか、Ninjacord Proにしてください")
        case .invalidEmbed(let issue):
            return issue.message
        case .discord(let error):
            return error.errorDescription ?? String(localized: "送信に失敗しました")
        }
    }

    var errorDescription: String? {
        message
    }
}
