//
//  SendMessageDisclosure.swift
//  NinjacordApp
//

import Foundation

/// 送信画面で開閉できるもの（送信者セクション・Discordでの見え方）の開閉の状態（Discussion #586 の Q3・Q6）。
/// 保存先は UserDefaults で、未設定なら開いた状態。
/// 撮影モードでは撮るたびに同じ画面になるよう、保存値を読まずに開いた状態にし、開閉しても保存しない
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

    init(userDefaults: UserDefaults = .standard, isScreenshotDemo: Bool = ScreenshotDemo.isEnabled) {
        self.userDefaults = userDefaults
        self.isScreenshotDemo = isScreenshotDemo
    }

    /// 開いているか。未設定・撮影モードなら開いた状態
    func isExpanded(_ item: Item) -> Bool {
        guard !isScreenshotDemo else {
            return true
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
