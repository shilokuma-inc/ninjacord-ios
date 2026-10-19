//
//  DiscordWebhookProfile.swift
//  NinjacordApp
//

import Foundation

/// Discord の Webhook URL。入力された文字列が Webhook URL の形のときだけ作れる。
/// URL にはトークンが含まれるので、ログ・Analytics・エラーの文言に出さない
struct DiscordWebhookURL: Equatable {
    /// Discord の Webhook URL の形。`discordapp.com` や `ptb.` / `canary.`、API のバージョン付き、`?thread_id=` などのクエリ付きも受け付ける
    static let pattern = #"^https://((ptb|canary)\.)?discord(app)?\.com"#
        + #"/api(/v[0-9]+)?/webhooks/[0-9]+/[A-Za-z0-9_-]+/?(\?.*)?$"#

    /// 入力された URL からクエリとフラグメントを除いたもの。Webhook の取得（GET）に使う
    let url: URL

    /// 前後の空白を除いて判定する。Webhook URL の形でなければ nil
    init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: Self.pattern, options: .regularExpression) != nil,
              var components = URLComponents(string: trimmed) else {
            return nil
        }
        // `?thread_id=` や `?wait=true` は送信のためのもので、取得には使わない
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            return nil
        }
        self.url = url
    }
}

/// Webhook に Discord 側で設定されている名前とアイコン。
/// 送信画面でプロフィール画像の URL が空のとき、プレビューにアイコンを出すために使う。
/// 名前は空でも送信時に決まった名前（`DiscordWebhookRequest.defaultUsername`）を送り、Discord 上に Webhook の名前は出ないので使わない
struct WebhookProfile: Equatable {
    /// Webhook の名前。Discord が名前を返さなかったときは空
    let name: String
    /// アイコンの URL。アイコンが設定されていなければ nil（既定のアイコンを出すかは呼び出し側で決める）
    let avatarURL: URL?
}

/// Webhook の名前とアイコンの取得に失敗した原因。
/// URL やトークンを含めないため、URLError そのものではなくコードだけを持つ
enum WebhookProfileError: Error, Equatable {
    /// Discord の Webhook URL の形でない（空・https でないなども含む）。通信はしていない
    case invalidURL
    /// Discord が 2xx 以外を返した
    case httpStatus(Int)
    /// 通信できなかった（オフライン・タイムアウト・キャンセルなど）
    case network(URLError.Code)
    /// レスポンスを Webhook として読めなかった
    case decoding
}

/// Webhook URL への GET で、Webhook の名前とアイコンを取得する通信
/// https://discord.com/developers/docs/resources/webhook#get-webhook-with-token
struct WebhookProfileClient {
    /// 既定で使う URLSession。レスポンスにトークンが含まれるので、キャッシュ・Cookie をディスクに残さない ephemeral にし、URLCache も持たない
    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    private let session: URLSession

    /// - Parameter session: 取得に使う URLSession。テストでは URLProtocol のスタブを入れたものを渡す
    init(session: URLSession = defaultSession) {
        self.session = session
    }

    /// 入力された文字列を Webhook URL として取得する。Webhook URL の形でなければ通信せずに invalidURL
    func fetch(from string: String) async -> Result<WebhookProfile, WebhookProfileError> {
        guard let webhookURL = DiscordWebhookURL(string: string) else {
            return .failure(.invalidURL)
        }
        return await fetch(webhookURL)
    }

    /// Webhook を取得する。ステータスコードが 2xx 以外なら失敗にする
    func fetch(_ webhookURL: DiscordWebhookURL) async -> Result<WebhookProfile, WebhookProfileError> {
        var request = URLRequest(url: webhookURL.url)
        request.httpMethod = "GET"
        // レスポンスにはトークンが含まれるので、URLCache から読まない（保存しないのは `defaultSession` で担保する）
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .failure(.network((error as? URLError)?.code ?? .unknown))
        }
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            return .failure(.network(.badServerResponse))
        }
        guard (200..<300).contains(statusCode) else {
            return .failure(.httpStatus(statusCode))
        }
        guard let body = try? JSONDecoder().decode(WebhookResponseBody.self, from: data) else {
            return .failure(.decoding)
        }
        return .success(WebhookProfile(
            name: body.name ?? "",
            // 空のハッシュでは CDN の URL にならないので、アイコンが無いものとして扱う
            avatarURL: body.avatar.flatMap { $0.isEmpty ? nil : Self.avatarURL(webhookID: body.id, avatarHash: $0) }
        ))
    }

    /// Webhook のアイコンの URL。アニメーションのアイコン（`a_` で始まるハッシュ）も png で 1 枚目を取る。
    /// プレビューのアイコンは 40pt なので、3 倍の画面でも足りる 128px を指定する
    /// https://discord.com/developers/docs/reference#image-formatting
    static func avatarURL(webhookID: String, avatarHash: String) -> URL? {
        URL(string: "https://cdn.discordapp.com/avatars/\(webhookID)/\(avatarHash).png?size=128")
    }
}

/// Get Webhook with Token のレスポンスのうち、使う項目だけ。`name` と `avatar` はどちらも null になり得る。
/// `id` は必ず返るので、無ければ Webhook のレスポンスではないとみなす
/// https://discord.com/developers/docs/resources/webhook#webhook-object
private struct WebhookResponseBody: Decodable {
    let id: String
    let name: String?
    let avatar: String?
}
