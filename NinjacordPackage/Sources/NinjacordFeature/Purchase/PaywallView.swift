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

    /// 無料 / Pro の対比表。1 行を「項目・無料・Pro」の 3 列で並べる
    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12.0) {
            BenefitComparisonHeader()
            ForEach(Self.comparisonItems) { item in
                Divider()
                BenefitComparisonRow(item: item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16.0)
        .background(
            RoundedRectangle(cornerRadius: 16.0)
                .fill(Color.appSurface)
        )
    }

    private static let comparisonItems: [BenefitComparisonItem] = [
        BenefitComparisonItem(id: "ads", title: "広告の表示", free: "表示あり", pro: "非表示"),
        BenefitComparisonItem(
            id: "templates",
            title: "テンプレート",
            free: "\(MessageTemplateStore.freeLimit)件まで",
            pro: "無制限"
        ),
        BenefitComparisonItem(
            id: "embed",
            title: "埋め込み",
            free: "タイトル・説明のみ",
            pro: "色・フィールド・画像・フッターなども"
        ),
        BenefitComparisonItem(id: "broadcast", title: "一斉送信", free: nil, pro: "複数のWebhookへ")
    ]

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

/// 対比表の 1 行分。`free` が nil の項目は無料プランでは使えない
private struct BenefitComparisonItem: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let free: LocalizedStringKey?
    let pro: LocalizedStringKey
}

/// 対比表の列見出し（無料・Pro）
private struct BenefitComparisonHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12.0) {
            Text("無料")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4.0) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text("Pro")
                    .foregroundStyle(Color.appAccent)
            }
            .font(.system(size: 13, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // 列名は各行の読み上げに含めるので、見出し行は読ませない
        .accessibilityHidden(true)
    }
}

/// 対比表の 1 行。項目名の下に無料 / Pro を 2 列で並べる
private struct BenefitComparisonRow: View {
    let item: BenefitComparisonItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6.0) {
            Text(item.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 12.0) {
                freeCell
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .firstTextBaseline, spacing: 4.0) {
                    Image(systemName: "checkmark.circle.fill")
                        .accessibilityHidden(true)
                    Text(item.pro)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// 見出し行を読まなくても列が分かるよう「項目、無料 ○○、Pro ○○」の形で読み上げる
    private var accessibilityText: Text {
        Text(item.title) + Text(verbatim: ", ")
            + Text("無料") + Text(verbatim: " ") + Text(item.free ?? "なし") + Text(verbatim: ", ")
            + Text("Pro") + Text(verbatim: " ") + Text(item.pro)
    }

    @ViewBuilder private var freeCell: some View {
        if let free = item.free {
            Text(free)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Image(systemName: "minus")
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
