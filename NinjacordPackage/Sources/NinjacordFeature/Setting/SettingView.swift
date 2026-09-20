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
    @State private var isURLSettingPresented = false
    @State private var isLicensePresented = false
    @State private var isPrivacyPolicyPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.discordDarkGray
                    .ignoresSafeArea(edges: [.top])
                List {
                    Section(content: {
                        Button {
                            isURLSettingPresented = true
                        } label: {
                            Text("URL設定")
                                .addComingSoon()
                                .foregroundStyle(.white)
                        }
                        .listRowBackground(Color.discordGray)
                        .navigationDestination(isPresented: $isURLSettingPresented) {
                            WebhookURLSettingView()
                        }
                        .disabled(true)
                    }, header: {
                        Text("送信先URL設定")
                            .foregroundStyle(.white)
                    })

                    Section(content: {
                        Text("このアプリについて")
                            .addComingSoon()
                            .foregroundStyle(.white)
                            .listRowBackground(Color.discordGray)

                        Button {
                            isPrivacyPolicyPresented = true
                        } label: {
                            HStack {
                                Text("プライバシーポリシー")
                                    .foregroundStyle(.white)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray)
                            }
                        }
                        .listRowBackground(Color.discordGray)
                        .navigationDestination(isPresented: $isPrivacyPolicyPresented) {
                            PrivacyPolicyView()
                        }

                        Button {
                            isLicensePresented = true
                        } label: {
                            HStack {
                                Text("ライセンス")
                                    .foregroundStyle(.white)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray)
                            }
                        }
                        .listRowBackground(Color.discordGray)
                        .navigationDestination(isPresented: $isLicensePresented) {
                            LicenseView()
                        }

                        HStack {
                            Text("アプリバージョン")
                                .foregroundStyle(.white)

                            Spacer()

                            Text(appInfo.getVersion())
                                .foregroundStyle(.gray)
                        }
                        .listRowBackground(Color.discordGray)
                    }, header: {
                        Text("アプリ情報")
                            .foregroundStyle(.white)
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
        model.load(
            windowScene: sceneDelegate.windowScene,
            rootViewController: sceneDelegate.window?.rootViewController
        )
    }
}
