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
    @ObservedObject private var adConsent = AdConsentManager.shared
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppTheme.userDefaultsKey) private var appTheme = AppTheme.dark.rawValue
    @State private var isURLSettingPresented = false
    @State private var isLicensePresented = false
    @State private var isPrivacyPolicyPresented = false
    @State private var isContactPresented = false
    @State private var isOnboardingPresented = false
    @State private var isPaywallPresented = false
    @State private var isRestoring = false
    @State private var restoreResultMessage: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                List {
                    Section {
                        Button {
                            isPaywallPresented = true
                        } label: {
                            HStack {
                                Label {
                                    Text("Ninjacord Pro")
                                        .foregroundStyle(Color.appTextPrimary)
                                } icon: {
                                    Image(systemName: "crown.fill")
                                        .foregroundStyle(.yellow)
                                }

                                Spacer()

                                if purchaseManager.isPro {
                                    Text("購読中")
                                        .foregroundStyle(Color.appTextSecondary)
                                }

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .listRowBackground(Color.appSurface)
                        .sheet(isPresented: $isPaywallPresented) {
                            paywallSheet
                        }

                        restorePurchasesRow
                    }

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

                    SendHistorySettingsSection()

                    Section(content: {
                        Button {
                            isOnboardingPresented = true
                        } label: {
                            HStack {
                                Text("アプリの使い方")
                                    .foregroundStyle(Color.appTextPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .listRowBackground(Color.appSurface)
                        .fullScreenCover(isPresented: $isOnboardingPresented) {
                            OnboardingView {
                                isOnboardingPresented = false
                            }
                        }

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

                    // ペイウォールの特典「広告を非表示」に合わせ、Pro 購読中はネイティブ広告も出さない
                    if let nativeAd = model.nativeAd, !purchaseManager.isPro {
                        // 広告内側の余白と合わせて、他の行と同じ 16pt の余白になるようにする
                        NativeAdView(nativeAd: nativeAd)
                            .listRowInsets(EdgeInsets(
                                top: 16 - NativeAdView.contentInset,
                                leading: 16 - NativeAdView.contentInset,
                                bottom: 16 - NativeAdView.contentInset,
                                trailing: 16 - NativeAdView.contentInset
                            ))
                            .listRowBackground(Color.appSurface)
                    }
                }
                .onAppear(perform: loadAd)
                .onChange(of: adConsent.canRequestAds) { _ in
                    // 設定画面を開いている間に同意が得られた場合も広告を読み込む
                    loadAd()
                }
                .scrollContentBackground(.hidden)
                .background(.clear)
            }
        }
    }

    /// 機種変更・再インストール後に、ペイウォールを開かなくても購入を復元できるようにする
    private var restorePurchasesRow: some View {
        Button {
            Task {
                await restorePurchases()
            }
        } label: {
            HStack {
                Text("購入を復元")
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                if isRestoring {
                    ProgressView()
                }
            }
        }
        .disabled(isRestoring)
        .listRowBackground(Color.appSurface)
        .alert(
            "購入を復元",
            isPresented: Binding(
                get: { restoreResultMessage != nil },
                set: { if !$0 { restoreResultMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                if let restoreResultMessage {
                    Text(restoreResultMessage)
                }
            }
        )
    }

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await purchaseManager.restore()
            restoreResultMessage = purchaseManager.isPro ? "購入を復元しました" : "復元できる購入が見つかりませんでした"
        } catch {
            print("Failed to restore: \(error)")
            restoreResultMessage = "購入を復元できませんでした。時間をおいてもう一度お試しください"
        }
    }

    private var paywallSheet: some View {
        NavigationStack {
            PaywallView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            isPaywallPresented = false
                        }
                    }
                }
        }
        // シートは別の View 階層になるため、Pro 状態を明示的に渡す
        .environmentObject(purchaseManager)
    }

    private func loadAd() {
        guard AdConfiguration.isEnabled, adConsent.canRequestAds, !purchaseManager.isPro else { return }

        model.load(
            windowScene: sceneDelegate.windowScene,
            rootViewController: sceneDelegate.window?.rootViewController
        )
    }
}
