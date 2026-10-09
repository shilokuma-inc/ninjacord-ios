//
//  SendMessageView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/17.
//

import SwiftUI
import StoreKit

struct SendMessageView: View {

    @State private var isEditing: Bool = false
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var sceneDelegate: MySceneDelegate
    @ObservedObject private var adConsent = AdConsentManager.shared
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @StateObject private var viewModel = SendMessageViewModel()

    /// 何回目の送信成功でレビューを依頼するか
    private static let reviewRequestSendCount = 3

    /// 入力欄の最大幅（左右の余白を含む）。iPhone では画面幅のほうが狭いので効かない
    private static let contentMaxWidth: CGFloat = 600.0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
                .onTapGesture {
                    if self.isEditing {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                        )
                        self.isEditing = false
                    }
                }
            VStack(spacing: .zero) {
                VStack(spacing: 8.0) {
                    Spacer()

                    if viewModel.broadcastTargets.isEmpty {
                        HStack {
                            ClearableIconTextField(
                                icon: Image(systemName: "link.icloud.fill"),
                                placeholder: "URLを入れてください",
                                text: $viewModel.inputURL
                            )
                            .onTapGesture {
                                self.isEditing = true
                            }

                            WebhookURLHelpButton(url: $viewModel.inputURL)

                            SavedWebhookURLButton(url: $viewModel.inputURL)
                        }
                    } else {
                        broadcastTargetsRow
                    }

                    // 宛先を選ぶボタンなので、宛先（URL）の直下に置く
                    HStack {
                        BroadcastButton(targets: $viewModel.broadcastTargets)
                        Spacer()
                        ImageAttachmentButton(attachment: $viewModel.attachment) {
                            viewModel.toast = Toast(style: .failure, message: "画像を添付できませんでした。10MBまでの画像を選んでください")
                        }
                    }
                    .padding(.leading, 44.0)

                    // 宛先（URL）ではなく中身の入力欄の上に置く
                    MessageTemplateButtons(message: viewModel.currentMessage, onApply: viewModel.applyTemplate) {
                        viewModel.toast = Toast(style: .success, message: "テンプレートを保存しました")
                    }
                    .padding(.leading, 44.0)

                    ClearableIconTextField(
                        icon: Image(systemName: "rectangle.and.pencil.and.ellipsis"),
                        placeholder: "名前を入れてください",
                        text: $viewModel.inputUsername
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }

                    ClearableIconTextField(
                        icon: Image(systemName: "person.crop.square"),
                        placeholder: "プロフィール画像のURLを入れてください",
                        text: $viewModel.inputAvatarURL
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }

                    ClearableIconTextField(
                        icon: Image(systemName: "square.and.pencil"),
                        placeholder: "メッセージを入れてください",
                        text: $viewModel.inputContext
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }
                }
                .padding(.horizontal)
                // iPad では入力欄が画面幅いっぱいに伸びて間延びするため、最大幅を設けて中央に寄せる。
                // 縦の余白の配分が変わらないよう、入力欄をまとめて包まずにブロックごとに付ける
                .frame(maxWidth: Self.contentMaxWidth)

                Spacer()
                    .frame(height: 24.0)

                HStack {
                    ClearableIconTextField(
                        icon: Image(systemName: "list.clipboard"),
                        placeholder: "埋め込みタイトルを入れてください",
                        text: $viewModel.inputEmbed.title
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }

                    EmbedEditorButton(embed: $viewModel.inputEmbed)
                }
                .padding(.horizontal)
                .frame(maxWidth: Self.contentMaxWidth)

                Spacer()
                    .frame(height: 48.0)

                sendButton

                // Pro 購読中は広告を出さない。購入した瞬間に消え、解約・失効したら戻る
                if AdConfiguration.isEnabled && !purchaseManager.isPro {
                    BannerView()
                } else {
                    // バナーが占めていた下端の可変領域を、空の View で同じように確保する。
                    // Spacer だと入力欄の上にある Spacer に高さを奪われ、画面全体が下に寄ってしまう
                    Color.clear
                        .frame(maxHeight: .infinity)
                }
            }
        }
        // iOS 26 のアラートはボタン文字に周囲の tint を使う。画面には AppAccent を付け直し、アラートだけシステム標準の青にする
        .tint(Color.appAccent)
        .alert(isPresented: $viewModel.isValidationAlertPresented, error: viewModel.validationError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
            }
        }
        .tint(Color(uiColor: .systemBlue))
        .toast($viewModel.toast)
        .onAppear {
            InterstitialAdManager.shared.preload()
        }
        .onChange(of: adConsent.canRequestAds) { _ in
            // 起動直後は同意の取得を待ってから読み込む
            InterstitialAdManager.shared.preload()
        }
    }
}

extension SendMessageView {
    private var sendButton: some View {
        Button(action: {
            viewModel.sendMessage(isPro: purchaseManager.isPro) { usedProFeatures in
                await handleSendSucceeded(usedProFeatures: usedProFeatures)
            }
        }, label: {
            // ローディング中もボタンの大きさが変わらないよう、文言は透明にして残し上に重ねる
            Text("メッセージを送信！")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .opacity(viewModel.isSending ? 0 : 1)
                .overlay {
                    if viewModel.isSending {
                        HStack(spacing: 8.0) {
                            ProgressView()
                                .tint(.white)
                            Text("送信中…")
                                .font(.system(size: 20, weight: .semibold, design: .default))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 30.0)
                        .foregroundStyle(.indigo)
                        .foregroundStyle(.ultraThickMaterial)
                        .shadow(radius: 5.0)
                )
        })
        .disabled(viewModel.isSending)
    }
}

extension SendMessageView {
    /// 送信に成功したあとのリワード広告の解放の消費・ATT の許可・レビュー依頼・インタースティシャル広告
    /// - Parameter usedProFeatures: 埋め込みの Pro 限定の項目や一斉送信など、Pro 機能を使った送信か
    private func handleSendSucceeded(usedProFeatures: Bool) async {
        // リワード広告の一時解放は、Pro 機能を使った 1 回の送信で使い切る（Discussion #386・判断ログ #389）。
        // 一斉送信は宛先の数ではなく 1 回の操作で 1 回と数え、1 件でも成功していれば使い切る
        if usedProFeatures {
            RewardedUnlockState.shared.consumeIfUnlocked()
        }
        let didRequestTracking = await TrackingAuthorization.requestIfNeeded()
        // 成功回数は ViewModel で記録済み。ちょうど 3 回目の送信のときだけ依頼する
        let sendSuccessCount = SendSuccessCounter().count
        if sendSuccessCount == Self.reviewRequestSendCount {
            requestReview()
        }
        // 広告の印象が付いたままレビューを依頼しないよう、全画面広告はレビュー依頼の次の送信から出す。
        // ATT のダイアログに続けて出すと体験を損なうため、ATT を尋ねた送信でも出さない
        if !didRequestTracking && sendSuccessCount > Self.reviewRequestSendCount {
            // 成功のトーストを見てもらってから表示する
            try? await Task.sleep(for: .seconds(1))
            InterstitialAdManager.shared.showIfAllowed(from: sceneDelegate.window?.rootViewController)
        }
    }

    /// 一斉送信の宛先を選んでいる間、URL 欄の代わりに出す
    private var broadcastTargetsRow: some View {
        HStack {
            Image(systemName: "paperplane.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.appAccent)
                .frame(width: 44.0)
            VStack(alignment: .leading, spacing: 2.0) {
                Text("\(viewModel.broadcastTargets.count)件の宛先に一斉送信")
                    .foregroundStyle(Color.appTextPrimary)
                Text(viewModel.broadcastTargets.map(\.name).joined(separator: "、"))
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                viewModel.broadcastTargets = []
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 44.0, height: 44.0)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("一斉送信をやめる")
        }
        .frame(minHeight: 56.0)
    }
}

#Preview {
    SendMessageView()
}
