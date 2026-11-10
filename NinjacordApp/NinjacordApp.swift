//
//  NinjacordApp.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/17.
//

import SwiftUI
import NinjacordFeature

@main
struct NinjacordApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage(AppTheme.userDefaultsKey) private var appTheme = AppTheme.dark.rawValue

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(AppTheme(storedValue: appTheme).colorScheme)
                // 「自動」に戻したときに端末の外観へ戻すため、ウィンドウにも同じテーマを当てる
                .task(id: appTheme) {
                    AppTheme(storedValue: appTheme).applyToWindows()
                }
        }
    }
}
