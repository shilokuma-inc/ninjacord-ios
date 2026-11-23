//
//  WebhookMessageEndpointTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信と、送ったメッセージの編集・削除に使う URL（`WebhookMessageEndpoint`）
struct WebhookMessageEndpointTests {
    // MARK: - 送信

    @Test("送信の URL には wait=true を付ける")
    func executeURLAddsWait() throws {
        let url = try #require(URL(string: "https://discord.com/api/webhooks/123/abc"))
        #expect(
            WebhookMessageEndpoint.executeURL(from: url)
                == URL(string: "https://discord.com/api/webhooks/123/abc?wait=true")
        )
    }

    @Test("入力された URL の thread_id は残し、wait は付け直す")
    func executeURLKeepsThreadID() throws {
        let url = try #require(URL(string: "https://discord.com/api/webhooks/123/abc?thread_id=456&wait=false"))
        #expect(
            WebhookMessageEndpoint.executeURL(from: url)
                == URL(string: "https://discord.com/api/webhooks/123/abc?thread_id=456&wait=true")
        )
    }

    // MARK: - 編集・削除

    @Test("編集・削除の URL は、Webhook URL の後ろに /messages/{ID} を付ける")
    func messageURL() {
        #expect(
            WebhookMessageEndpoint.messageURL(
                webhookURL: "https://discord.com/api/webhooks/123/abc",
                messageID: "789"
            ) == URL(string: "https://discord.com/api/webhooks/123/abc/messages/789")
        )
    }

    @Test("前後の空白と末尾のスラッシュは除く")
    func messageURLTrimsSlashAndSpaces() {
        #expect(
            WebhookMessageEndpoint.messageURL(
                webhookURL: " https://discord.com/api/webhooks/123/abc/\n",
                messageID: "789"
            ) == URL(string: "https://discord.com/api/webhooks/123/abc/messages/789")
        )
    }

    @Test("スレッドに送ったメッセージは thread_id だけを残し、ほかのクエリは除く")
    func messageURLKeepsOnlyThreadID() {
        #expect(
            WebhookMessageEndpoint.messageURL(
                webhookURL: "https://discord.com/api/webhooks/123/abc?wait=true&thread_id=456",
                messageID: "789"
            ) == URL(string: "https://discord.com/api/webhooks/123/abc/messages/789?thread_id=456")
        )
    }

    @Test("メッセージ ID が数字でなければ作らない", arguments: ["", "abc", "12/34", "１２３"])
    func messageURLRejectsInvalidID(messageID: String) {
        let url = WebhookMessageEndpoint.messageURL(
            webhookURL: "https://discord.com/api/webhooks/123/abc",
            messageID: messageID
        )
        #expect(url == nil)
    }

    @Test("URL にできなければ作らない")
    func messageURLRejectsInvalidURL() {
        #expect(WebhookMessageEndpoint.messageURL(webhookURL: "", messageID: "789") == nil)
    }
}
