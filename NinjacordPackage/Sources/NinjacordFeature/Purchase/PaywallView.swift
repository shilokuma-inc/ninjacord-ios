//
//  PaywallView.swift
//  NinjacordApp
//

import StoreKit
import SwiftUI

/// Pro プラン（月額サブスクリプション）の購入画面。
/// App Store 審査ガイドライン 3.1.2 に従い、価格・期間・自動更新の説明・利用規約・プライバシーポリシー・復元を載せる
struct PaywallView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var loadState: LoadState = .loading
    @State private var isProcessing = false
    @State private var alertMessage: LocalizedStringKey?

    /// Apple 標準の利用規約（EULA）
    private static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private enum LoadState {
        case loading
        case loaded(Product)
        case failed
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24.0) {
                    header
                    benefits
                    purchaseSection
                    legalSection
                }
                .padding(24.0)
            }
        }
        .task {
            await loadProduct()
        }
        .alert(
            "Ninjacord Pro",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                if let alertMessage {
                    Text(alertMessage)
                }
            }
        )
    }

    private var header: some View {
        VStack(spacing: 12.0) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            Text("Ninjacord Pro")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.appTextPrimary)
        }
        .padding(.top, 16.0)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12.0) {
            Label {
                Text("広告を非表示")
                    .foregroundStyle(Color.appTextPrimary)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.appAccent)
            }
            .font(.system(size: 17, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16.0)
        .background(
            RoundedRectangle(cornerRadius: 16.0)
                .fill(Color.appSurface)
        )
    }

    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 12.0) {
            switch loadState {
            case .loading:
                ProgressView()
                    .frame(height: 56.0)
            case .loaded(let product):
                Text("\(product.displayPrice) / 月")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.appTextPrimary)
                subscribeButton(for: product)
            case .failed:
                Text("プランの情報を読み込めませんでした")
                    .foregroundStyle(Color.appTextSecondary)
                Button("再読み込み") {
                    Task {
                        await loadProduct()
                    }
                }
            }

            Button("購入を復元") {
                Task {
                    await restore()
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(Color.appAccent)
            .frame(minHeight: 44.0)
            .disabled(isProcessing)
        }
    }

    private func subscribeButton(for product: Product) -> some View {
        Button(action: {
            Task {
                await purchase(product)
            }
        }, label: {
            ZStack {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(purchaseManager.isPro ? "購読中" : "Proを購読する")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56.0)
            .background(
                RoundedRectangle(cornerRadius: 30.0)
                    .foregroundStyle(.indigo)
            )
        })
        .disabled(isProcessing || purchaseManager.isPro)
    }

    private var legalSection: some View {
        VStack(spacing: 12.0) {
            // swiftlint:disable:next line_length
            Text("お支払いは購入の確定時にApple IDに請求されます。サブスクリプションは、現在の期間が終了する24時間前までに自動更新をオフにしない限り、自動的に更新されます。自動更新はApp Storeのアカウント設定から管理・解約できます。")
                .font(.system(size: 12))
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 24.0) {
                Link("利用規約", destination: Self.termsOfUseURL)
                if let privacyPolicyURL = PrivacyPolicyView.url {
                    Link("プライバシーポリシー", destination: privacyPolicyURL)
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Color.appAccent)
        }
    }
}

extension PaywallView {
    private func loadProduct() async {
        loadState = .loading
        do {
            try await purchaseManager.loadProducts()
            if let product = purchaseManager.products.first(where: { $0.id == PurchaseManager.ProductID.proMonthly }) {
                loadState = .loaded(product)
            } else {
                loadState = .failed
            }
        } catch {
            print("Failed to load products: \(error)")
            loadState = .failed
        }
    }

    private func purchase(_ product: Product) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            switch try await purchaseManager.purchase(product) {
            case .purchased:
                dismiss()
            case .pending:
                alertMessage = "購入の承認待ちです。承認されると自動でProが有効になります"
            case .cancelled:
                break
            }
        } catch {
            print("Failed to purchase: \(error)")
            alertMessage = "購入できませんでした。時間をおいてもう一度お試しください"
        }
    }

    private func restore() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await purchaseManager.restore()
            alertMessage = purchaseManager.isPro ? "購入を復元しました" : "復元できる購入が見つかりませんでした"
        } catch {
            print("Failed to restore: \(error)")
            alertMessage = "購入を復元できませんでした。時間をおいてもう一度お試しください"
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(PurchaseManager.shared)
}
