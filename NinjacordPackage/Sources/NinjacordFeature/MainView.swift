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
    @EnvironmentObject private var sceneDelegate: MySceneDelegate
    /// Pro 状態を配下のすべての画面から `@EnvironmentObject` で参照できるよう、ルートで配る
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @AppStorage(Self.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @State private var isOnboardingPresented = false

    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    public init() {
        // 各画面がストアを読み込む前に、撮影用のデモデータを入れておく
        ScreenshotDemo.prepare()
        // App Store 用スクリーンショットにオンボーディングを写り込ませない
        let hasCompleted = UserDefaults.standard.bool(forKey: Self.hasCompletedOnboardingKey)
        _isOnboardingPresented = State(initialValue: !hasCompleted && !ScreenshotDemo.isEnabled)
    }

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
        .fullScreenCover(isPresented: $isOnboardingPresented, onDismiss: {
            // オンボーディングを閉じ終わってから同意フォームを出す（表示中はルートから重ねて表示できないため）
            Task {
                await gatherAdConsent()
            }
        }, content: {
            OnboardingView {
                hasCompletedOnboarding = true
                isOnboardingPresented = false
            }
        })
        .environmentObject(purchaseManager)
        .task {
            guard !isOnboardingPresented else { return }
            await gatherAdConsent()
        }
    }

    /// 同意フォームは画面の上に表示するため、ルート View の表示後に同意情報を取得する
    private func gatherAdConsent() async {
        await AdConsentManager.shared.gatherConsent(from: sceneDelegate.window?.rootViewController)
    }
}
