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

    /// セクションどうしの間隔。セクションの中の入力欄どうしより広げて、まとまりを見分けやすくする
    private static let sectionSpacing: CGFloat = 12.0

    /// 広告を出さないときに、送信ボタンの下に必ず残す余白
    private static let minimumBottomSpacing: CGFloat = 16.0

    /// プレビューの上限を決めるときに入力欄のために必ず残す高さ。
    /// 見出し付きの入力欄 1 つ分（見出し約 16pt + 間隔 2pt + カプセル約 38pt）
    private static let minimumInputFieldHeight: CGFloat = 56.0
    /// 上端に固定したプレビューに出す添付画像の最大の幅・高さ。入力欄の場所を残すため、プレビュー単体の既定より小さくする
    private static let previewAttachmentMaxSize: CGFloat = 160.0

    /// 下端にバナー広告を出すか。Pro 購読中は広告を出さない。購入した瞬間に消え、解約・失効したら戻る
    private var showsBannerAd: Bool {
        AdConfiguration.isEnabled && !purchaseManager.isPro
    }

    /// 入力欄が画面に収まらなくても下端に残す高さ。広告を出すなら広告の高さ、出さないなら送信ボタンの下の余白
    private func minimumBottomHeight(width: CGFloat) -> CGFloat {
        showsBannerAd ? BannerView.adHeight(width: width) : Self.minimumBottomSpacing
    }

    /// 上端に固定したプレビューの中身に使える高さの上限。開いたプレビューは全体を出し、
    /// パネルの見出しと余白・下端の広告の領域・入力欄 1 つ分が残らないほど長いときだけ、超えた分をパネルの中でスクロールさせる。
    /// キーボードを出している間は画面の高さが減るので、上限も合わせて縮む。それでも名前の行は見えるよう、プレビューの最低の高さは残す
    private func previewMaxContentHeight(containerSize: CGSize) -> CGFloat {
        SendMessageLayoutMetrics.previewMaxContentHeight(
            containerHeight: containerSize.height,
            reservedHeight: MessagePreviewPanelMetrics.chromeHeight + Self.sectionSpacing
                + minimumBottomHeight(width: containerSize.width) + Self.minimumInputFieldHeight,
            minimum: MessagePreview.minimumHeight
        )
    }

    var body: some View {
        // プレビューの高さの上限を画面の大きさから決めるために測る（キーボードを出している間は、その分だけ低くなる）
        GeometryReader { proxy in
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismissKeyboard)
                // 入力欄から送信ボタンまではスクロールの中に入れ、下端の広告の領域は動かさない
                SendMessageScrollLayout(
                    onTapBackground: dismissKeyboard,
                    // 撮影する送信画面では、上端に固定したプレビューの下に埋め込み・添付（6.9 inch では送信ボタンまで）が写るよう、
                    // 埋め込みの上端までスクロールしておく。送信者と本文はプレビューに内容が出るのでパネルの裏に送る
                    scrollTargetOnAppear: ScreenshotDemo.scene == .send ? "embed" : nil,
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
                            .id("embed")
                        attachmentSection
                    }
                    .padding(.horizontal)
                    // iPad では入力欄が画面幅いっぱいに伸びて間延びするため、最大幅を設けて中央に寄せる
                    .frame(maxWidth: Self.contentMaxWidth)

                    Spacer()
                        .frame(height: 24.0)

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
                // プレビューは入力欄の上に固定して浮かせ、入力欄から送信ボタンまではその下をスクロールする（Issue #620）
                .safeAreaInset(edge: .top, spacing: .zero) {
                    messagePreviewPanel(maxContentHeight: previewMaxContentHeight(containerSize: proxy.size))
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
    /// Discord での見え方のプレビュー。入力しながら確かめられるよう、入力欄の上に固定して浮かせる（Issue #620）。
    /// 入力した内容がどこに出るか分かるよう、既定では開いておく（Discussion #586 の Q3）
    private func messagePreviewPanel(maxContentHeight: CGFloat) -> some View {
        MessagePreviewPanel(isExpanded: $isPreviewExpanded, maxContentHeight: maxContentHeight) {
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
                    : AvatarImageLoader(),
                attachmentMaxSize: Self.previewAttachmentMaxSize
            )
            // プレビューを開いている間は、URL の入力が止まったら Webhook の名前とアイコンを取得する
            .task(id: webhookProfileInput) {
                await webhookProfileStore.load(for: webhookProfileInput)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: Self.contentMaxWidth)
        .padding(.bottom, Self.sectionSpacing)
        // パネルの周りは背景を付けず、ナビゲーションバーのように裏を通る入力欄を透かす
        .frame(maxWidth: .infinity)
        // ただしステータスバーの裏は背景色で覆う。入力欄のスクロールはパネルの裏からステータスバーの裏まで伸びるので、
        // 覆わないとパネルより上（ステータスバーの位置）に入力欄が出る（Issue #623）
        .background(alignment: .top) {
            Color.clear
                .frame(height: 0)
                .background(Color.appBackground, ignoresSafeAreaEdges: .top)
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
                        icon: MessagePartIcon(part: .destination),
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
                icon: MessagePartIcon(part: .name),
                placeholder: "名前を入れてください",
                text: $viewModel.inputUsername,
                title: "名前",
                note: "Discordの送信者名を上書き。空ならWebhookの名前"
            )
            .onTapGesture {
                self.isEditing = true
            }

            ClearableIconTextField(
                icon: MessagePartIcon(part: .avatar),
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
                icon: MessagePartIcon(part: .content),
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
            // ほかのセクションの入力欄と同じく左にアイコンを置き、ボタンの頭は入力欄の文字（左から 44pt）にそろえる
            HStack(spacing: 44.0 - MessagePartIcon.gridSize) {
                MessagePartIcon(part: .attachment)
                ImageAttachmentButton(attachment: $viewModel.attachment) {
                    viewModel.toast = Toast(style: .failure, message: "画像を添付できませんでした。10MBまでの画像を選んでください")
                }
            }
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
