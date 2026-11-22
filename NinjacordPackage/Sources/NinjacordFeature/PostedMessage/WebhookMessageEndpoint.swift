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
    /// URL にできないか、メッセージ ID が数字でなければ nil
    /// https://discord.com/developers/docs/resources/webhook#edit-webhook-message
    static func messageURL(webhookURL: String, messageID: String) -> URL? {
        guard !messageID.isEmpty,
              messageID.allSatisfy({ $0.isASCII && $0.isNumber }),
              let url = SendMessageViewModel.webhookEndpoint(from: webhookURL),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path + "/messages/" + messageID
        let threadID = components.queryItems?.first { $0.name == "thread_id" }
        components.queryItems = threadID.map { [$0] }
        components.fragment = nil
        return components.url
    }
}
