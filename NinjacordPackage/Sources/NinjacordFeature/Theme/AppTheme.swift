//
//  AppTheme.swift
//  NinjacordApp
//

import SwiftUI
import UIKit

/// アプリ全体へ適用する配色テーマ。`system` は端末の外観設定（ライト / ダーク）に従う。
/// 並び順は設定画面・オンボーディングの選択肢の順（ライト / ダーク / 自動）
public enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    public static let userDefaultsKey = "appTheme"

    public var id: String { rawValue }

    /// 保存値から読んだテーマ。保存値が不正なときは既定のダークにする
    public init(storedValue: String) {
        self = AppTheme(rawValue: storedValue) ?? .dark
    }

    /// `preferredColorScheme` に渡す値。`system` は `nil`（端末に従う）
    public var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return .unspecified
        }
    }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .light:
            return "ライト"
        case .dark:
            return "ダーク"
        case .system:
            return "自動"
        }
    }

    /// 表示中のすべてのウィンドウにテーマを適用する。
    /// `preferredColorScheme(nil)` は、一度ライト / ダークを指定した後に渡しても端末の外観に戻らないことがあるため、
    /// ウィンドウの `overrideUserInterfaceStyle` も合わせて切り替える（表示中の `fullScreenCover` やシートにも反映される）
    @MainActor
    public func applyToWindows() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = userInterfaceStyle
            }
        }
    }
}
