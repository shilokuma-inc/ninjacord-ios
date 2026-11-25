//
//  WebhookMessageEndpoint.swift
//  NinjacordApp
//

import Foundation

/// 入力された Webhook URL から、送信と、送ったメッセージの編集・削除に使う URL を作る。
/// URL にはトークンが含まれるので、ログ・Analytics・エラーの文言に出さない
enum WebhookMessageEndpoint {
    /// 送信に使う URL。Discord が保存したことを確かめてから成功にし、作られたメッセージ（ID）を受け取るため `wait=true` を付ける。
    /// `wait` を付けないと、保存されなかったメッセージも成功（204）で返る。入力された URL の `thread_id` などのクエリは残す
    /// https://discord.com/developers/docs/resources/webhook#execute-webhook-query-string-params
    static func executeURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        // 入力された URL に `wait=false` などが付いていても、付け直す
        var queryItems = (components.queryItems ?? []).filter { $0.name != "wait" }
        queryItems.append(URLQueryItem(name: "wait", value: "true"))
        components.queryItems = queryItems
        return components.url ?? url
    }

    /// 送ったメッセージの編集・削除に使う URL（`/webhooks/{id}/{token}/messages/{message.id}`）。
    /// スレッドに送ったメッセージは、同じ `thread_id` を付けないと見つからない（404）ので、クエリはそれだけ残す。
    /// フォーラムに新しい投稿として送ったメッセージは、作られたスレッドの ID（`threadID`）を `thread_id` として付ける（Issue #699）。
    /// 送信のときと同じく前後の空白・改行は除く。URL にできないか、メッセージ・スレッドの ID が数字でなければ nil
    /// https://discord.com/developers/docs/resources/webhook#edit-webhook-message
    static func messageURL(webhookURL: String, messageID: String, threadID: String? = nil) -> URL? {
        guard isSnowflake(messageID),
              threadID.map(isSnowflake) ?? true,
              let url = URL(string: webhookURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path + "/messages/" + messageID
        let threadItem = threadID.map { URLQueryItem(name: "thread_id", value: $0) }
            ?? components.queryItems?.first { $0.name == "thread_id" }
        components.queryItems = threadItem.map { [$0] }
        components.fragment = nil
        return components.url
    }

    /// Discord の ID（数字だけ）か。URL のパス・クエリに入れても、ほかの部分を書き換えられない
    private static func isSnowflake(_ id: String) -> Bool {
        !id.isEmpty && id.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
