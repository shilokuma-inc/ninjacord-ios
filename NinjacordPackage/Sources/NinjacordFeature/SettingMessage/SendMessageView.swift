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
    /// App Store 用スクリーンショットの送信画面では、Discord での見え方まで写すため開いておく
    @State private var isPreviewExpanded = ScreenshotDemo.scene == .send
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var sceneDelegate: MySceneDelegate
    @ObservedObject private var adConsent = AdConsentManager.shared
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @StateObject private var viewModel = SendMessageViewModel()
    @StateObject private var webhookProfileStore = WebhookProfileStore()

    /// 入力欄の最大幅（左右の余白を含む）。iPhone では画面幅のほうが狭いので効かない
    private static let contentMaxWidth: CGFloat = 600.0

    /// 入力欄どうしの間隔。メッセージと埋め込みタイトルの間も同じ値にして、縦の並びをそろえる（Discussion #525）
    private static let fieldSpacing: CGFloat = 8.0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
                .onTapGesture(perform: dismissKeyboard)
            // 入力欄から送信ボタンまではスクロールの中に入れ、下端の広告の領域は動かさない
            SendMessageScrollLayout(
                onTapBackground: dismissKeyboard,
                // 撮影する送信画面では、開いたプレビューと送信ボタンが写るよう下端までスクロールしておく
                scrollsToBottomOnAppear: ScreenshotDemo.scene == .send
            ) {
                VStack(spacing: Self.fieldSpacing) {
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

                // メッセージと埋め込みタイトルの間隔も、ほかの入力欄と同じ値にする
                Spacer()
                    .frame(height: Self.fieldSpacing)

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
                    .frame(height: Self.fieldSpacing)

                // 入力した内容を確かめてから送れるよう、入力欄と送信ボタンの間に置く
                messagePreviewSection
                    .padding(.horizontal)
                    .frame(maxWidth: Self.contentMaxWidth)

                Spacer()
                    .frame(height: 16.0)

                sendButton
            } bottom: {
                // Pro 購読中は広告を出さない。購入した瞬間に消え、解約・失効したら戻る
                if AdConfiguration.isEnabled && !purchaseManager.isPro {
                    BannerView()
                } else {
                    // バナーが占めていた下端の領域を、空の View で同じように確保する。
                    // 確保しないと入力欄の上の余白に高さを奪われ、画面全体が下に寄ってしまう
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
    /// 背景をタップしたら、入力中のキーボードを閉じる
    private func dismissKeyboard() {
        if self.isEditing {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
            )
            self.isEditing = false
        }
    }
}

extension SendMessageView {
    private var sendButton: some View {
        Button(action: {
            viewModel.sendMessage(
                isPro: purchaseManager.isPro,
                screenActions: SendMessageScreenActions(
                    requestReview: { requestReview() },
                    rootViewController: { sceneDelegate.window?.rootViewController }
                )
            )
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
        })
        .buttonStyle(.raised(isLoading: viewModel.isSending))
        .disabled(viewModel.isSending)
    }
}

extension SendMessageView {
    /// Discord での見え方のプレビュー。入力欄と送信ボタンを画面に収めるため、既定では閉じておく
    private var messagePreviewSection: some View {
        VStack(spacing: .zero) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPreviewExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "eye")
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 24.0, height: 24.0)
                        .accessibilityHidden(true)
                    Text("Discordでの見え方")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                        .rotationEffect(.degrees(isPreviewExpanded ? 90.0 : 0.0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44.0)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isPreviewExpanded ? Text("展開済み") : Text("折りたたみ済み"))

            if isPreviewExpanded {
                MessagePreview(
                    username: viewModel.inputUsername,
                    avatarURL: viewModel.inputAvatarURL,
                    content: viewModel.inputContext,
                    embed: viewModel.inputEmbed,
                    attachment: viewModel.attachment,
                    webhookProfile: webhookProfileStore.profile(for: webhookProfileInput),
                    // 撮影モードではデモのプロフィール画像の URL を読みに行かず、その場で描いたアイコンを出す
                    avatarLoader: ScreenshotDemo.isEnabled
                        ? AvatarImageLoader(fixedImage: ScreenshotDemo.avatarImage)
                        : AvatarImageLoader()
                )
                .padding(.top, Self.fieldSpacing)
                // 開いても下端の広告の領域は縮めず、入力欄側をスクロールさせる
                .sendMessageLayoutExcludesHeight()
                .transition(.opacity)
                // プレビューを開いている間だけ、URL の入力が止まったら Webhook の名前とアイコンを取得する
                .task(id: webhookProfileInput) {
                    await webhookProfileStore.load(for: webhookProfileInput)
                }
            }
        }
    }

    private var webhookProfileInput: String {
        MessagePreviewProfile.webhookProfileInput(
            webhookURL: viewModel.inputURL,
            avatarURL: viewModel.inputAvatarURL,
            isBroadcasting: !viewModel.broadcastTargets.isEmpty,
            isScreenshotDemo: ScreenshotDemo.isEnabled
        )
    }
}

extension SendMessageView {
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
