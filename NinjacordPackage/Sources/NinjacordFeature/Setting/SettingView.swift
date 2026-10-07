//
//  SettingView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/30.
//

import StoreKit
import SwiftUI

struct SettingView: View {
    let appInfo = AppInfo()

    @StateObject private var model = NativeAdModel()
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppTheme.userDefaultsKey) private var appTheme = AppTheme.dark.rawValue
    @State private var isURLSettingPresented = false
    @State private var isLicensePresented = false
    @State private var isPrivacyPolicyPresented = false
    @State private var isContactPresented = false
    @State private var isOnboardingPresented = false
    @State private var isPaywallPresented = false
    @State private var isManageSubscriptionsPresented = false
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
                        // 返金・失効で isPro が false になると「サブスクリプションを管理」行は消えるため、常にある行に付ける（解約しても期間中は isPro のまま）
                        .manageSubscriptionsSheet(isPresented: $isManageSubscriptionsPresented)
                        .onChange(of: isManageSubscriptionsPresented) { isPresented in
                            // 返金・プラン変更などで変わった状態を、シートを閉じた時点で反映する
                            guard !isPresented else { return }
                            Task {
                                await purchaseManager.refreshPurchasedProducts()
                            }
                        }

                        if purchaseManager.isPro {
                            manageSubscriptionsRow
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
                            .limitedDynamicTypeSize()
                        }

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

                    NativeAdRow(model: model)
                }
                .loadsNativeAd(model)
                .scrollContentBackground(.hidden)
                .background(.clear)
            }
        }
    }
}

// MARK: - Pro プラン

extension SettingView {
    /// Pro 購読中の人が、App Store の設定を探さなくてもアプリ内から解約・プラン変更できるようにする
    private var manageSubscriptionsRow: some View {
        Button {
            isManageSubscriptionsPresented = true
        } label: {
            HStack {
                Text("サブスクリプションを管理")
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .listRowBackground(Color.appSurface)
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
        // iOS 26 のアラートはボタン文字に周囲の tint を使う。行には AppAccent を付け直し、アラートだけシステム標準の青にする
        .tint(Color.appAccent)
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
        .tint(Color(uiColor: .systemBlue))
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
            PaywallView(source: .settings)
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
        .limitedDynamicTypeSize()
    }
}
