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
    /// 送信者セクションと Discordでの見え方の開閉。前回の状態で始め、開閉したら覚える（撮影モードでは常に開いて始める）
    @State private var isSenderExpanded = SendMessageDisclosure().isExpanded(.sender)
    @State private var isPreviewExpanded = SendMessageDisclosure().isExpanded(.preview)
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var sceneDelegate: MySceneDelegate
    @ObservedObject private var adConsent = AdConsentManager.shared
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @StateObject private var viewModel = SendMessageViewModel()
    @StateObject private var webhookProfileStore = WebhookProfileStore()

    /// 入力欄の最大幅（左右の余白を含む）。iPhone では画面幅のほうが狭いので効かない
    private static let contentMaxWidth: CGFloat = 600.0

    /// 入力欄どうしの間隔（Discussion #525）
    private static let fieldSpacing: CGFloat = 8.0

    /// セクションどうしの間隔。セクションの中の入力欄どうしより広げて、まとまりを見分けやすくする
    private static let sectionSpacing: CGFloat = 12.0

    /// 広告を出さないときに、送信ボタンの下に必ず残す余白
    private static let minimumBottomSpacing: CGFloat = 16.0

    /// 下端にバナー広告を出すか。Pro 購読中は広告を出さない。購入した瞬間に消え、解約・失効したら戻る
    private var showsBannerAd: Bool {
        AdConfiguration.isEnabled && !purchaseManager.isPro
    }

    /// 入力欄が画面に収まらなくても下端に残す高さ。広告を出すなら広告の高さ、出さないなら送信ボタンの下の余白
    private func minimumBottomHeight(width: CGFloat) -> CGFloat {
        showsBannerAd ? BannerView.adHeight(width: width) : Self.minimumBottomSpacing
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
                .onTapGesture(perform: dismissKeyboard)
            // 入力欄から送信ボタンまではスクロールの中に入れ、下端の広告の領域は動かさない
            SendMessageScrollLayout(
                onTapBackground: dismissKeyboard,
                // 撮影する送信画面では、開いたプレビューと送信ボタンが写るよう下端までスクロールしておく
                scrollsToBottomOnAppear: ScreenshotDemo.scene == .send,
                minimumBottomHeight: minimumBottomHeight(width:)
            ) {
                VStack(spacing: Self.sectionSpacing) {
                    // 宛先にも中身にも属さないので、セクションの外の先頭にまとめる（Discussion #586 の Q4）
                    MessageTemplateButtons(message: viewModel.currentMessage, onApply: viewModel.applyTemplate) {
                        viewModel.toast = Toast(style: .success, message: "テンプレートを保存しました")
                    }

                    destinationSection
                    senderSection
                    contentSection
                    embedSection
                    attachmentSection
                }
                .padding(.horizontal)
                // iPad では入力欄が画面幅いっぱいに伸びて間延びするため、最大幅を設けて中央に寄せる
                .frame(maxWidth: Self.contentMaxWidth)

                Spacer()
                    .frame(height: Self.sectionSpacing)

                // 入力した内容を確かめてから送れるよう、入力欄と送信ボタンの間に置く
                messagePreviewSection
                    .padding(.horizontal)
                    .frame(maxWidth: Self.contentMaxWidth)

                Spacer()
                    .frame(height: 16.0)

                sendButton
            } bottom: {
                if showsBannerAd {
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
        .alert(
            "本文が未入力です",
            isPresented: $viewModel.isDefaultValueConfirmationPresented,
            presenting: viewModel.defaultValueConfirmation
        ) { _ in
            Button("このまま送信") {
                viewModel.confirmDefaultValueSend(disablesConfirmation: false, screenActions: screenActions)
            }
            Button("送信して今後は表示しない") {
                viewModel.confirmDefaultValueSend(disablesConfirmation: true, screenActions: screenActions)
            }
            Button("キャンセル", role: .cancel) {
                viewModel.cancelDefaultValueSend()
            }
        } message: { confirmation in
            Text(confirmation.message)
        }
        .tint(Color(uiColor: .systemBlue))
        .toast($viewModel.toast)
        .onAppear {
            InterstitialAdManager.shared.preload()
        }
        .onChange(of: isSenderExpanded) { isExpanded in
            SendMessageDisclosure().setExpanded(isExpanded, for: .sender)
        }
        .onChange(of: isPreviewExpanded) { isExpanded in
            SendMessageDisclosure().setExpanded(isExpanded, for: .preview)
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
    /// 送信に成功したあとの流れで使う、View の環境から来るもの（レビュー依頼・全画面広告の表示元）
    private var screenActions: SendMessageScreenActions {
        SendMessageScreenActions(
            requestReview: { requestReview() },
            rootViewController: { sceneDelegate.window?.rootViewController }
        )
    }

    private var sendButton: some View {
        Button(action: {
            viewModel.sendMessage(isPro: purchaseManager.isPro, screenActions: screenActions)
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
    /// Discord での見え方のプレビュー。入力した内容がどこに出るか分かるよう、既定では開いておく（Discussion #586 の Q3）
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
                // プレビューを開いている間は、URL の入力が止まったら Webhook の名前とアイコンを取得する
                .task(id: webhookProfileInput) {
                    await webhookProfileStore.load(for: webhookProfileInput)
                }
            }
        }
    }

    private var webhookProfileInput: String {
        MessagePreviewProfile.webhookProfileInput(
            webhookURL: viewModel.inputURL,
            username: viewModel.inputUsername,
            avatarURL: viewModel.inputAvatarURL,
            isBroadcasting: !viewModel.broadcastTargets.isEmpty,
            isScreenshotDemo: ScreenshotDemo.isEnabled
        )
    }
}

extension SendMessageView {
    /// 宛先: Webhook URL と、URL を選ぶ・調べるボタン、一斉送信
    private var destinationSection: some View {
        SendMessageSection(title: "宛先") {
            if viewModel.broadcastTargets.isEmpty {
                // 見出しの分だけ高くなるので、横のボタンは入力欄の中央にそろえる
                HStack(alignment: .textFieldCenter) {
                    ClearableIconTextField(
                        icon: Image(systemName: "link.icloud.fill"),
                        placeholder: "URLを入れてください",
                        text: $viewModel.inputURL,
                        title: "Webhook URL"
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

            BroadcastButton(targets: $viewModel.broadcastTargets)
                .padding(.leading, 44.0)
        }
    }

    /// 送信者: Discord のメッセージの名前とアイコン。閉じている間は要約だけを出す（Discussion #586 の Q6）
    private var senderSection: some View {
        SendMessageSection(title: "送信者", isExpanded: $isSenderExpanded, collapsedSummary: senderSummary) {
            ClearableIconTextField(
                icon: Image(systemName: "rectangle.and.pencil.and.ellipsis"),
                placeholder: "名前を入れてください",
                text: $viewModel.inputUsername,
                title: "名前",
                note: "Discordの送信者名を上書き。空ならWebhookの名前"
            )
            .onTapGesture {
                self.isEditing = true
            }

            ClearableIconTextField(
                icon: Image(systemName: "person.crop.square"),
                placeholder: "プロフィール画像のURLを入れてください",
                text: $viewModel.inputAvatarURL,
                title: "プロフィール画像のURL",
                note: "Discordのアイコンを上書き。空ならWebhookのアイコン"
            )
            .onTapGesture {
                self.isEditing = true
            }
        }
        // 閉じている間は、要約に出す Webhook の名前を取得する（プレビューを開いていなくても出せるように）
        .task(id: isSenderExpanded ? "" : webhookProfileInput) {
            guard !isSenderExpanded else {
                return
            }
            await webhookProfileStore.load(for: webhookProfileInput)
        }
    }

    /// 送信者セクションを閉じているときの要約
    private var senderSummary: String {
        MessagePreviewProfile.senderSummary(
            username: viewModel.inputUsername,
            avatarURL: viewModel.inputAvatarURL,
            webhookProfile: webhookProfileStore.profile(for: webhookProfileInput)
        )
    }

    /// 本文: Discord のメッセージの本文
    private var contentSection: some View {
        SendMessageSection(title: "本文") {
            ClearableIconTextField(
                icon: Image(systemName: "square.and.pencil"),
                placeholder: "メッセージを入れてください",
                text: $viewModel.inputContext,
                title: "メッセージ"
            )
            .onTapGesture {
                self.isEditing = true
            }
        }
    }

    /// 埋め込み: 入力済みの内容の要約と、すべての項目を編集するシートを開くボタン（Discussion #586 の Q5）
    private var embedSection: some View {
        SendMessageSection(title: "埋め込み") {
            EmbedSummaryRow(summary: EmbedSummary(embed: viewModel.inputEmbed))

            EmbedEditorButton(embed: $viewModel.inputEmbed)
                .padding(.leading, 44.0)
        }
    }

    /// 添付: 本文と一緒に送る画像
    private var attachmentSection: some View {
        SendMessageSection(title: "添付") {
            ImageAttachmentButton(attachment: $viewModel.attachment) {
                viewModel.toast = Toast(style: .failure, message: "画像を添付できませんでした。10MBまでの画像を選んでください")
            }
            .padding(.leading, 44.0)
        }
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
