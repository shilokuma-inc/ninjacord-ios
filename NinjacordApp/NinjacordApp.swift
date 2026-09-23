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
                .preferredColorScheme(AppTheme(rawValue: appTheme)?.colorScheme ?? .dark)
        }
    }
}
