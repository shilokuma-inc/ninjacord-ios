//
//  AppTheme.swift
//  NinjacordApp
//

import SwiftUI

/// 端末設定とは独立してアプリ全体へ適用する配色テーマ。
public enum AppTheme: String, CaseIterable, Identifiable {
    case dark
    case light

    public static let userDefaultsKey = "appTheme"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .dark:
            return "ダーク"
        case .light:
            return "ライト"
        }
    }
}
