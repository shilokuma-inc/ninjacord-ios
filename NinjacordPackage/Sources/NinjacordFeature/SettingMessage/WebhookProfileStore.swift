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

    /// 入力された Webhook URL の Webhook を、待ち時間の後に取得する。
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
        guard !Task.isCancelled else {
            return
        }
        switch await client.fetch(webhookURL) {
        case .success(let profile):
            // 取得中に入力が変わっても、取れた結果は同じ URL に戻ったときのために覚えておく
            profiles[webhookURL.url] = profile
            failedDates[webhookURL.url] = nil
        case .failure:
            // 入力が変わって取得をやめた（通信がキャンセルされた）ときは、失敗として覚えない
            guard !Task.isCancelled else {
                return
            }
            failedDates[webhookURL.url] = now()
        }
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
