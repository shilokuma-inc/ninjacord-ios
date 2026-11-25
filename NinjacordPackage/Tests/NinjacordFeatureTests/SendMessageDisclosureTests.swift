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

    @Test("未設定なら既定の状態", arguments: SendMessageDisclosure.Item.allCases)
    func defaultState(item: SendMessageDisclosure.Item) {
        #expect(disclosure().isExpanded(item) == item.isExpandedByDefault)
    }

    /// 送信オプションは既定ですべてオフで、使う人も限られるので閉じておく（Issue #698）
    @Test("未設定なら、送信者とプレビューは開き、送信オプションは閉じる")
    func expandedByDefault() {
        #expect(disclosure().isExpanded(.sender))
        #expect(disclosure().isExpanded(.preview))
        #expect(!disclosure().isExpanded(.sendOptions))
    }

    @Test("閉じたら覚え、作り直しても閉じたまま。開けば開いた状態に戻る", arguments: SendMessageDisclosure.Item.allCases)
    func remembersState(item: SendMessageDisclosure.Item) {
        disclosure().setExpanded(false, for: item)
        #expect(!disclosure().isExpanded(item))
        #expect(userDefaults.object(forKey: item.userDefaultsKey) as? Bool == false)

        disclosure().setExpanded(true, for: item)
        #expect(disclosure().isExpanded(item))
    }

    @Test("開閉できるものは別々に覚える")
    func itemsAreIndependent() {
        disclosure().setExpanded(false, for: .sender)
        #expect(!disclosure().isExpanded(.sender))
        #expect(disclosure().isExpanded(.preview))

        disclosure().setExpanded(true, for: .sendOptions)
        #expect(disclosure().isExpanded(.sendOptions))
        #expect(!disclosure().isExpanded(.sender))

        let keys = Set(SendMessageDisclosure.Item.allCases.map(\.userDefaultsKey))
        #expect(keys.count == SendMessageDisclosure.Item.allCases.count)
    }

    @Test("撮影モードでは保存値を読まずに既定の状態にし、開閉しても保存しない", arguments: SendMessageDisclosure.Item.allCases)
    func screenshotDemoIgnoresStoredState(item: SendMessageDisclosure.Item) {
        disclosure().setExpanded(!item.isExpandedByDefault, for: item)
        #expect(disclosure(isScreenshotDemo: true).isExpanded(item) == item.isExpandedByDefault)

        disclosure(isScreenshotDemo: true).setExpanded(item.isExpandedByDefault, for: item)
        #expect(disclosure().isExpanded(item) == !item.isExpandedByDefault)
    }

    /// App Store 用の送信画面に、セクションの並びとプレビューを 1 枚に収めるため
    @Test("撮影モードの送信画面では、送信者を閉じ、プレビューは開く。送信オプションは既定どおり閉じる")
    func sendSceneCollapsesSender() {
        #expect(!disclosure(isScreenshotDemo: true, isSendScene: true).isExpanded(.sender))
        #expect(disclosure(isScreenshotDemo: true, isSendScene: true).isExpanded(.preview))
        #expect(!disclosure(isScreenshotDemo: true, isSendScene: true).isExpanded(.sendOptions))
    }
}
