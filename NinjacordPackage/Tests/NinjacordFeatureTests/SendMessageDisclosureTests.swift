//
//  SendMessageDisclosureTests.swift
//  NinjacordFeatureTests
//

import Foundation
@testable import NinjacordFeature
import Testing

/// 送信画面の開閉の状態（`SendMessageDisclosure`）の読み書き（Discussion #586 の Q3・Q6）
final class SendMessageDisclosureTests {
    private let suiteName = "SendMessageDisclosureTests.\(UUID().uuidString)"
    private let userDefaults: UserDefaults

    init() throws {
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    private func disclosure(isScreenshotDemo: Bool = false, isSendScene: Bool = false) -> SendMessageDisclosure {
        SendMessageDisclosure(
            userDefaults: userDefaults,
            isScreenshotDemo: isScreenshotDemo,
            isSendSceneScreenshot: isScreenshotDemo && isSendScene
        )
    }

    @Test("未設定なら開いた状態", arguments: SendMessageDisclosure.Item.allCases)
    func expandedByDefault(item: SendMessageDisclosure.Item) {
        #expect(disclosure().isExpanded(item))
    }

    @Test("閉じたら覚え、作り直しても閉じたまま。開けば開いた状態に戻る", arguments: SendMessageDisclosure.Item.allCases)
    func remembersState(item: SendMessageDisclosure.Item) {
        disclosure().setExpanded(false, for: item)
        #expect(!disclosure().isExpanded(item))
        #expect(userDefaults.object(forKey: item.userDefaultsKey) as? Bool == false)

        disclosure().setExpanded(true, for: item)
        #expect(disclosure().isExpanded(item))
    }

    @Test("送信者とプレビューは別々に覚える")
    func itemsAreIndependent() {
        disclosure().setExpanded(false, for: .sender)
        #expect(!disclosure().isExpanded(.sender))
        #expect(disclosure().isExpanded(.preview))
        #expect(SendMessageDisclosure.Item.sender.userDefaultsKey != SendMessageDisclosure.Item.preview.userDefaultsKey)
    }

    @Test("撮影モードでは保存値を読まずに開いた状態にし、開閉しても保存しない", arguments: SendMessageDisclosure.Item.allCases)
    func screenshotDemoIgnoresStoredState(item: SendMessageDisclosure.Item) {
        disclosure().setExpanded(false, for: item)
        #expect(disclosure(isScreenshotDemo: true).isExpanded(item))

        disclosure(isScreenshotDemo: true).setExpanded(true, for: item)
        #expect(!disclosure().isExpanded(item))
    }

    /// App Store 用の送信画面に、セクションの並びとプレビューを 1 枚に収めるため
    @Test("撮影モードの送信画面では、送信者だけを閉じ、プレビューは開く")
    func sendSceneCollapsesSender() {
        #expect(!disclosure(isScreenshotDemo: true, isSendScene: true).isExpanded(.sender))
        #expect(disclosure(isScreenshotDemo: true, isSendScene: true).isExpanded(.preview))
    }
}
