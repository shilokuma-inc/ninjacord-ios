//
//  MessagePreviewProfileTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// プレビューに出す名前・アイコン（`MessagePreviewProfile`）が、送る中身（`DiscordWebhookRequest`）と食い違わないことを確かめる
struct MessagePreviewProfileTests {
    private static let webhookURL = "https://discord.com/api/webhooks/123/token"
    private static let webhookProfile = WebhookProfile(
        name: "Captain Hook",
        avatarURL: URL(string: "https://cdn.discordapp.com/avatars/123/abc.png")
    )

    /// 同じ名前で送ったときに Discord へ送る名前
    private func sentUsername(_ username: String) -> String? {
        let message = MessageEntity(
            username: username,
            avatarURL: "",
            content: "",
            messageEmbedEntity: MessageEmbedEntity()
        )
        return DiscordWebhookRequest(messageEntity: message).parameters["username"] as? String
    }

    // MARK: - 名前

    @Test("出す名前は送る名前と同じ（空なら決まった名前、空白だけならそのまま）", arguments: ["", "レイド告知Bot", " "])
    func displayNameMatchesSentUsername(username: String) {
        #expect(MessagePreviewProfile.displayName(username: username) == sentUsername(username))
    }

    @Test("名前が空なら、Webhook の名前ではなく送信と同じ決まった名前を出す")
    func displayNameIgnoresWebhookName() {
        #expect(MessagePreviewProfile.displayName(username: "") == "以下、名無しにかわりましてVIPがお送りします")
    }

    // MARK: - アイコン

    @Test("プロフィール画像の URL が入力済みなら、Webhook のアイコンがあっても入力した URL を読む")
    func displayAvatarURLPrefersInput() {
        let url = MessagePreviewProfile.displayAvatarURL(
            avatarURL: "https://example.com/avatar.png",
            webhookProfile: Self.webhookProfile
        )
        #expect(url == "https://example.com/avatar.png")
    }

    @Test("プロフィール画像の URL が空なら Webhook のアイコンを読む")
    func displayAvatarURLFallsBackToWebhook() {
        let url = MessagePreviewProfile.displayAvatarURL(avatarURL: "", webhookProfile: Self.webhookProfile)
        #expect(url == "https://cdn.discordapp.com/avatars/123/abc.png")
    }

    @Test("プロフィール画像の URL が空で、Webhook のアイコンも無い・未取得なら空（既定のアイコンを出す）")
    func displayAvatarURLEmpty() {
        #expect(MessagePreviewProfile.displayAvatarURL(avatarURL: "", webhookProfile: nil).isEmpty)
        let profile = WebhookProfile(name: "Captain Hook", avatarURL: nil)
        #expect(MessagePreviewProfile.displayAvatarURL(avatarURL: "", webhookProfile: profile).isEmpty)
    }

    // MARK: - Webhook の情報を取得するか

    private func webhookProfileInput(
        avatarURL: String = "",
        isBroadcasting: Bool = false,
        isScreenshotDemo: Bool = false
    ) -> String {
        MessagePreviewProfile.webhookProfileInput(
            webhookURL: Self.webhookURL,
            avatarURL: avatarURL,
            isBroadcasting: isBroadcasting,
            isScreenshotDemo: isScreenshotDemo
        )
    }

    @Test("プロフィール画像の URL が空なら、入力された Webhook の URL から取得する")
    func webhookProfileInputWhenAvatarEmpty() {
        #expect(webhookProfileInput() == Self.webhookURL)
    }

    @Test("プロフィール画像の URL が入力済みなら取得しない")
    func webhookProfileInputWhenAvatarFilled() {
        #expect(webhookProfileInput(avatarURL: "https://example.com/avatar.png").isEmpty)
    }

    @Test("一斉送信中は取得しない")
    func webhookProfileInputWhileBroadcasting() {
        #expect(webhookProfileInput(isBroadcasting: true).isEmpty)
    }

    @Test("撮影モードでは取得しない")
    func webhookProfileInputInScreenshotDemo() {
        #expect(webhookProfileInput(isScreenshotDemo: true).isEmpty)
    }
}
