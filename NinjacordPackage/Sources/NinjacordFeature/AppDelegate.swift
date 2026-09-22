//
//  AppDelegate.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/30.
//

import SwiftUI
import FirebaseCore

/// Firebase / AdMob の初期化を行う AppDelegate。`@UIApplicationDelegateAdaptor` から参照するため public。
/// GoogleMobileAds は広告の同意が取れてから `AdConsentManager` が初期化する
public class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    public func application(_ application: UIApplication,
                            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil)
    -> Bool {
        FirebaseApp.configure()

        // 前回までに同意済みなら、ここで GoogleMobileAds の初期化が始まる
        _ = AdConsentManager.shared
        // 起動中に届く購入の更新（自動更新・返金など）を取りこぼさないよう、最初に監視を始める
        _ = PurchaseManager.shared

        return true
    }
}

class MySceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
    var windowScene: UIWindowScene?
    var window: UIWindow? {
        windowScene?.keyWindow
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        windowScene = scene as? UIWindowScene
    }
}

extension AppDelegate {
    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = MySceneDelegate.self
        }
        return configuration
    }
}
