//
//  WebhookProfileStore.swift
//  NinjacordApp
//

import Foundation

/// メッセージのプレビュー（`MessagePreview`）に出す Webhook の名前とアイコンを、Webhook URL ごとに取得して覚えておく。
/// 入力のたびに通信しないよう、入力が止まるのを待ってから取得し、同じ URL へは繰り返し通信しない。
/// 覚えておくキーはトークンを含む URL なので、メモリにだけ持ち、ログなどに出さない
@MainActor
final class WebhookProfileStore: ObservableObject {
    /// 入力が止まったとみなすまでの待ち時間。URL は貼り付けることが多いので、打ち込んでいる途中で取得しない程度にする
    static let delay: Duration = .milliseconds(800)
    /// 取得に失敗した URL へ取得し直すまでの間隔。オフラインから戻ったときなどに、いつまでも仮の表示のままにしない
    static let failureRetryInterval: TimeInterval = 30

    /// 取得できた Webhook。キーはクエリとフラグメントを除いた Webhook URL（`DiscordWebhookURL.url`）
    @Published private(set) var profiles: [URL: WebhookProfile] = [:]
    /// 取得に失敗した日時。`failureRetryInterval` の間は同じ URL へ取得し直さない
    private var failedDates: [URL: Date] = [:]
    /// 取得している URL と、その通信。送信画面のカード・プレビュー・送信者の要約が同じ URL を同時に読みに来ても、通信は 1 回にする
    private var inFlightTasks: [URL: Task<Void, Never>] = [:]

    private let client: WebhookProfileClient
    /// 指定した時間だけ待つ。キャンセルされたら投げる。テストでは待たずに済ませる
    private let sleep: @MainActor (Duration) async throws -> Void
    /// 今の日時。テストでは失敗してからの経過を進める
    private let now: () -> Date

    /// - Parameters:
    ///   - client: Webhook の取得に使う通信。テストでは URLProtocol のスタブを入れた URLSession を持たせる
    ///   - sleep: 取得の前に待つ処理
    ///   - now: 今の日時
    init(
        client: WebhookProfileClient = WebhookProfileClient(),
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.sleep = sleep
        self.now = now
    }

    /// 入力された Webhook URL について、取得できている Webhook。Webhook URL の形でない・未取得・失敗なら nil
    func profile(for input: String) -> WebhookProfile? {
        DiscordWebhookURL(string: input).flatMap { profiles[$0.url] }
    }

    /// 入力された Webhook URL の Webhook を、待ち時間の後に取得する。ほかの呼び出しが同じ URL を取得していれば、その通信が終わるのを待つ。
    /// Webhook URL の形でない・取得済み・少し前に失敗した URL なら通信しない。待っている間にキャンセルされたら通信しない
    func load(for input: String) async {
        guard let webhookURL = DiscordWebhookURL(string: input), needsFetch(webhookURL.url) else {
            return
        }
        do {
            try await sleep(Self.delay)
        } catch {
            return
        }
        // 待っている間に、ほかの呼び出しが取得し終えたなら通信しない
        guard !Task.isCancelled, needsFetch(webhookURL.url) else {
            return
        }
        await fetchTask(for: webhookURL).value
    }

    /// その URL を取得する通信。取得中ならその通信を返し、無ければ始める。
    /// 取得を始めた画面が閉じても（呼び出し元の `.task` がキャンセルされても）、同じ URL を待つほかの画面のために通信を止めない（Issue #697）
    private func fetchTask(for webhookURL: DiscordWebhookURL) -> Task<Void, Never> {
        if let task = inFlightTasks[webhookURL.url] {
            return task
        }
        // 呼び出し元から切り離した Task で通信する。待っている呼び出し元がすべてキャンセルされても最後まで取得して覚えておく。
        // GET 1 回で軽く、同じ URL に戻ったときにそのまま出せるため
        let task = Task {
            defer { inFlightTasks[webhookURL.url] = nil }
            switch await client.fetch(webhookURL) {
            case .success(let profile):
                // 取得中に入力が変わっても、取れた結果は同じ URL に戻ったときのために覚えておく
                profiles[webhookURL.url] = profile
                failedDates[webhookURL.url] = nil
            case .failure:
                // 呼び出し元のキャンセルでは通信を止めないので、ここに来るのは取得そのものに失敗したときだけ
                failedDates[webhookURL.url] = now()
            }
        }
        inFlightTasks[webhookURL.url] = task
        return task
    }

    private func needsFetch(_ url: URL) -> Bool {
        guard profiles[url] == nil else {
            return false
        }
        guard let failedDate = failedDates[url] else {
            return true
        }
        return now().timeIntervalSince(failedDate) >= Self.failureRetryInterval
    }
}
