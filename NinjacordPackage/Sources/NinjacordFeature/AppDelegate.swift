//
//  AppDelegate.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/30.
//

import SwiftUI
import FirebaseCore
import GoogleMobileAds

/// Firebase / AdMob の初期化を行う AppDelegate。`@UIApplicationDelegateAdaptor` から参照するため public。
public class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    public func application(_ application: UIApplication,
                            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil)
    -> Bool {
        FirebaseApp.configure()

        if AdConfiguration.isEnabled {
            GADMobileAds.sharedInstance().start(completionHandler: nil)
        }

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
