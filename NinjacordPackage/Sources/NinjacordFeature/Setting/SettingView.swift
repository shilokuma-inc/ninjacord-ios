//
//  SettingView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/30.
//

import SwiftUI

struct SettingView: View {
    let appInfo = AppInfo()

    @EnvironmentObject private var sceneDelegate: MySceneDelegate
    @StateObject private var model = NativeAdModel()
    @AppStorage(AppTheme.userDefaultsKey) private var appTheme = AppTheme.dark.rawValue
    @State private var isURLSettingPresented = false
    @State private var isLicensePresented = false
    @State private var isPrivacyPolicyPresented = false
    @State private var isContactPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea(edges: [.top])
                List {
                    Section {
                        Picker("テーマ", selection: $appTheme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.localizedTitle)
                                    .tag(theme.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("アプリのテーマ")
                        .listRowBackground(Color.appSurface)
                    } header: {
                        Text("テーマ")
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    Section(content: {
                        Button {
                            isURLSettingPresented = true
                        } label: {
                            HStack {
                                Text("URL設定")
                                    .foregroundStyle(Color.appTextPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .listRowBackground(Color.appSurface)
                        .navigationDestination(isPresented: $isURLSettingPresented) {
                            WebhookURLSettingView()
                        }
                    }, header: {
                        Text("送信先URL設定")
                            .foregroundStyle(Color.appTextSecondary)
                    })

                    Section(content: {
                        Text("このアプリについて")
                            .addComingSoon()
                            .foregroundStyle(Color.appTextPrimary)
                            .listRowBackground(Color.appSurface)

                        Button {
                            isPrivacyPolicyPresented = true
                        } label: {
                            HStack {
                                Text("プライバシーポリシー")
                                    .foregroundStyle(Color.appTextPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .listRowBackground(Color.appSurface)
                        .navigationDestination(isPresented: $isPrivacyPolicyPresented) {
                            PrivacyPolicyView()
                        }

                        Button {
                            isContactPresented = true
                        } label: {
                            HStack {
                                Text("お問い合わせ")
                                    .foregroundStyle(Color.appTextPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .listRowBackground(Color.appSurface)
                        .navigationDestination(isPresented: $isContactPresented) {
                            ContactView()
                        }

                        Button {
                            isLicensePresented = true
                        } label: {
                            HStack {
                                Text("ライセンス")
                                    .foregroundStyle(Color.appTextPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .listRowBackground(Color.appSurface)
                        .navigationDestination(isPresented: $isLicensePresented) {
                            LicenseView()
                        }

                        HStack {
                            Text("アプリバージョン")
                                .foregroundStyle(Color.appTextPrimary)

                            Spacer()

                            Text(appInfo.getVersion())
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .listRowBackground(Color.appSurface)
                    }, header: {
                        Text("アプリ情報")
                            .foregroundStyle(Color.appTextSecondary)
                    })

                    if let nativeAd = model.nativeAd {
                        NativeAdView(nativeAd: nativeAd)
                            .aspectRatio(4 / 3, contentMode: .fit)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .onAppear(perform: loadAd)
                .scrollContentBackground(.hidden)
                .background(.clear)
            }
        }
    }

    private func loadAd() {
        guard AdConfiguration.isEnabled else { return }

        model.load(
            windowScene: sceneDelegate.windowScene,
            rootViewController: sceneDelegate.window?.rootViewController
        )
    }
}
