//
//  AppThemeTests.swift
//  NinjacordFeatureTests
//

import SwiftUI
@testable import NinjacordFeature
import Testing

/// テーマの並び・保存値・適用する配色を確かめる
struct AppThemeTests {
    @Test("選択肢はライト / ダーク / 自動の順に並ぶ")
    func allCasesOrder() {
        #expect(AppTheme.allCases == [.light, .dark, .system])
    }

    @Test("保存値は今までと同じ（既存ユーザーの設定を引き継ぐ）")
    func rawValues() {
        #expect(AppTheme.userDefaultsKey == "appTheme")
        #expect(AppTheme.light.rawValue == "light")
        #expect(AppTheme.dark.rawValue == "dark")
        #expect(AppTheme.system.rawValue == "system")
    }

    @Test("ライト / ダークはその配色、自動は端末に従う（nil）")
    func colorScheme() {
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
        #expect(AppTheme.system.colorScheme == nil)
    }

    @Test("ウィンドウに当てる外観は、自動のとき端末に従う（unspecified）")
    func userInterfaceStyle() {
        #expect(AppTheme.light.userInterfaceStyle == .light)
        #expect(AppTheme.dark.userInterfaceStyle == .dark)
        #expect(AppTheme.system.userInterfaceStyle == .unspecified)
    }

    @Test("保存値から読むと、不正な値は既定のダークになり、自動は自動のまま", arguments: [
        ("light", AppTheme.light),
        ("dark", AppTheme.dark),
        ("system", AppTheme.system),
        ("", AppTheme.dark),
        ("unknown", AppTheme.dark)
    ])
    func storedValue(value: String, expected: AppTheme) {
        #expect(AppTheme(storedValue: value) == expected)
    }
}
