//
//  MessagePreviewProfile.swift
//  NinjacordApp
//

import Foundation

/// プレビューに出す名前・アイコンと、そのために Webhook の情報を取得するかを、入力から決める。
/// Discord 上の見え方は送る中身（`DiscordWebhookRequest`）で決まるので、それと食い違わないようにする
enum MessagePreviewProfile {
    /// 出す名前。入力が空なら、送信と同じく Webhook の名前（名前が空なら username を送らないため）。
    /// Webhook の名前が未取得・空なら nil（呼び出し側で仮の文言を出す）
    static func displayName(username: String, webhookProfile: WebhookProfile?) -> String? {
        guard username.isEmpty else {
            return username
        }
        guard let name = webhookProfile?.name, !name.isEmpty else {
            return nil
        }
        return name
    }

    /// 読み込むプロフィール画像の URL。入力が空なら Webhook のアイコン。
    /// 入力された URL が読めないときは、Discord 上と同じく Webhook のアイコンには戻さず既定のアイコンを出す
    static func displayAvatarURL(avatarURL: String, webhookProfile: WebhookProfile?) -> String {
        avatarURL.isEmpty ? (webhookProfile?.avatarURL?.absoluteString ?? "") : avatarURL
    }

    /// 名前・アイコンをプレビューに出す Webhook の URL。出さない（取得しない）なら空。
    /// 一斉送信中は宛先が 1 つに決まらないので出さない。名前とプロフィール画像の URL がどちらも入力済みなら使わないので取得しない。
    /// 撮影モードでは通信しないよう、デモの内容に関係なく取得しない
    static func webhookProfileInput(
        webhookURL: String,
        username: String,
        avatarURL: String,
        isBroadcasting: Bool,
        isScreenshotDemo: Bool
    ) -> String {
        guard !isScreenshotDemo, !isBroadcasting, username.isEmpty || avatarURL.isEmpty else {
            return ""
        }
        return webhookURL
    }
}
