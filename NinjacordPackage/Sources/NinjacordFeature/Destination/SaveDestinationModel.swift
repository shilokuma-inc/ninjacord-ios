//
//  SaveDestinationModel.swift
//  NinjacordApp
//

import Foundation

/// 宛先を保存する画面の状態。入力された Webhook URL をその場で取得して確かめ、
/// Webhook の名前を名前の欄に入れておく。同じ宛先を二重に保存させない（Issue #674）
@MainActor
final class SaveDestinationModel: ObservableObject {
    /// 入力された URL を確かめた結果
    enum Check: Equatable {
        /// まだ何も入れていない
        case empty
        /// Discord の Webhook URL の形ではない（通信していない）
        case invalidFormat
        /// Webhook を取得している
        case checking
        /// 取得できた。名前とアイコンを見せる
        case valid(WebhookProfile)
        /// Webhook が無い（Discord で削除された・URL の ID が違う）
        case notFound
        /// URL のトークンが正しくない
        case invalidToken
        /// 通信できず確かめられなかった。オフラインでも保存はできる
        case unreachable
    }

    /// 打ち込んでいる途中で取得しないよう、入力が止まってから取得するまでの待ち時間
    static let checkDelay: Duration = .milliseconds(400)

    @Published var url: String {
        didSet {
            // 確かめ直すまでの間に、前の URL の結果（確認できた・保存できる）が残らないようにする
            guard url != oldValue else { return }
            check = trimmedURL.isEmpty ? .empty : .checking
        }
    }
    @Published private(set) var name = ""
    @Published private(set) var check: Check = .empty

    /// 名前を自分で入れたか。入れていなければ、取得した Webhook の名前で置き換える
    private var isNameEdited = false
    private let store: WebhookURLStore
    private let client: WebhookProfileClient
    private let sleep: @MainActor (Duration) async throws -> Void

    /// - Parameters:
    ///   - initialURL: 最初に入れておく URL（送信画面で使っている、保存していない URL など）
    ///   - store: 保存先。二重に保存しないかの判定にも使う
    ///   - client: Webhook の取得。テストでは URLProtocol のスタブを入れたものを渡す
    ///   - sleep: 取得の前の待ち。テストでは待たない
    init(
        initialURL: String,
        store: WebhookURLStore,
        client: WebhookProfileClient = WebhookProfileClient(),
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.url = initialURL
        self.store = store
        self.client = client
        self.sleep = sleep
    }

    /// 名前の欄に入力したとき。以後は取得した Webhook の名前で上書きしない
    func setName(_ newValue: String) {
        name = newValue
        isNameEdited = true
    }

    var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 同じ宛先（Webhook とスレッドが同じ）を保存済みなら、そのもの
    var duplicate: SavedWebhookURL? {
        store.item(matching: trimmedURL)
    }

    /// 保存できるか。Webhook を確かめられた（オフラインで確かめられなかったときも含む）うえで、名前があり、二重でないこと
    var canSave: Bool {
        guard !trimmedName.isEmpty, duplicate == nil else {
            return false
        }
        switch check {
        case .valid, .unreachable:
            return true
        case .empty, .invalidFormat, .checking, .notFound, .invalidToken:
            return false
        }
    }

    /// 入力された URL を確かめる。URL が変わるたびに View の `.task(id:)` から呼ぶ（前の呼び出しはキャンセルされる）
    func checkURL() async {
        let current = trimmedURL
        guard !current.isEmpty else {
            check = .empty
            return
        }
        guard let webhookURL = DiscordWebhookURL(string: current) else {
            check = .invalidFormat
            return
        }
        check = .checking
        do {
            try await sleep(Self.checkDelay)
        } catch {
            return
        }
        let result = await client.fetch(webhookURL)
        // 取得している間に URL が書き換えられたら、古い結果は使わない
        guard !Task.isCancelled, trimmedURL == current else {
            return
        }
        switch result {
        case .success(let profile):
            check = .valid(profile)
            if !isNameEdited || trimmedName.isEmpty, !profile.name.isEmpty {
                name = profile.name
                isNameEdited = false
            }
        case .failure(.httpStatus(404)):
            check = .notFound
        case .failure(.httpStatus(400)), .failure(.httpStatus(401)), .failure(.httpStatus(403)):
            check = .invalidToken
        case .failure(.invalidURL):
            check = .invalidFormat
        case .failure:
            check = .unreachable
        }
    }

    /// 保存する。保存できない状態なら何もせず nil
    func save() -> SavedWebhookURL? {
        // 別の画面で保存された分も含めて、二重でないかを確かめ直す
        store.reload()
        guard canSave else {
            return nil
        }
        var profile: WebhookProfile?
        if case .valid(let fetched) = check {
            profile = fetched
        }
        return store.add(name: trimmedName, url: trimmedURL, profile: profile)
    }
}
