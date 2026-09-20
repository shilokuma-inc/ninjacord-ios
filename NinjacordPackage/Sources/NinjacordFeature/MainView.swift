//
//  MainView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/30.
//

import SwiftUI

/// アプリのルート View（送信 / 設定のタブ構成）。アプリターゲットから参照するため public。
public struct MainView: View {
    let analytics = FirebaseAnalytics()
    @State var selection = 1

    public init() {}

    public var body: some View {
        TabView(selection: $selection) {
            SendMessageView()
                .tabItem {
                    Label("送信", systemImage: "paperplane.fill")
                }
                .tag(1)
                .onAppear {
                    analytics.sendAnalyticsScreen(screenName: "SendMessageView")
                }

            SettingView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
                .tag(2)
                .onAppear {
                    analytics.sendAnalyticsScreen(screenName: "SettingView")
                }
        }
        .tint(Color.appAccent)
        .toolbarBackground(Color.appSurface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
