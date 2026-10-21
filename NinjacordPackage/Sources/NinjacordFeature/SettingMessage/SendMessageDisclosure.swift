//
//  SendMessageDisclosure.swift
//  NinjacordApp
//

import Foundation

/// 送信画面で開閉できるもの（送信者セクション・Discordでの見え方）の開閉の状態（Discussion #586 の Q3・Q6）。
/// 保存先は UserDefaults で、未設定なら開いた状態。
/// 撮影モードでは撮るたびに同じ画面になるよう、保存値を読まずに開いた状態にし、開閉しても保存しない。
/// ただし撮影する送信画面では、セクションの並びとプレビューを 1 枚に収めるため送信者を閉じる
struct SendMessageDisclosure {
    enum Item: CaseIterable {
        /// 送信者セクション（名前・プロフィール画像の URL）
        case sender
        /// Discordでの見え方（プレビュー）
        case preview

        /// 開いているかを保存するキー
        var userDefaultsKey: String {
            switch self {
            case .sender:
                return "isSendMessageSenderExpanded"
            case .preview:
                return "isSendMessagePreviewExpanded"
            }
        }
    }

    let userDefaults: UserDefaults
    let isScreenshotDemo: Bool
    /// 撮影モードで送信画面（`ScreenshotDemo.Scene.send`）を撮るか
    let isSendSceneScreenshot: Bool

    init(
        userDefaults: UserDefaults = .standard,
        isScreenshotDemo: Bool = ScreenshotDemo.isEnabled,
        isSendSceneScreenshot: Bool = ScreenshotDemo.scene == .send
    ) {
        self.userDefaults = userDefaults
        self.isScreenshotDemo = isScreenshotDemo
        self.isSendSceneScreenshot = isSendSceneScreenshot
    }

    /// 開いているか。未設定なら開いた状態。撮影モードでは、送信画面の送信者だけ閉じ、ほかは開いた状態
    func isExpanded(_ item: Item) -> Bool {
        guard !isScreenshotDemo else {
            return !(item == .sender && isSendSceneScreenshot)
        }
        return userDefaults.object(forKey: item.userDefaultsKey) as? Bool ?? true
    }

    /// 開閉の状態を保存する。撮影モードでは保存しない
    func setExpanded(_ isExpanded: Bool, for item: Item) {
        guard !isScreenshotDemo else {
            return
        }
        userDefaults.set(isExpanded, forKey: item.userDefaultsKey)
    }
}
