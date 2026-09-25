//
//  SendMessageView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/17.
//

import SwiftUI
import StoreKit

struct SendMessageView: View {

    @State var inputURL = ""
    @State var inputUsername = ""
    @State var inputAvatarURL = ""
    @State var inputContext = ""

    /// 埋め込み。タイトルは送信画面で、それ以外の項目は embed エディタで入力する
    @State var inputEmbed = MessageEmbedEntity()

    @State private var isEditing: Bool = false
    @State private var validationError: SendMessageValidationError?
    @State private var isValidationAlertPresented: Bool = false
    /// 添付する画像（1 枚）。テンプレート・送信履歴には保存しない
    @State private var attachment: ImageAttachment?
    /// 一斉送信（Pro 限定）の宛先。空なら URL 欄の宛先に送る
    @State private var broadcastTargets: [SavedWebhookURL] = []
    /// Webhook への送信中かどうか。送信中はボタンにローディングを出し、二重送信を防ぐ
    @State private var isSending = false
    /// 送信結果を知らせるトースト
    @State private var toast: Toast?
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var sceneDelegate: MySceneDelegate
    @ObservedObject private var adConsent = AdConsentManager.shared
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @StateObject private var historyStore = SendHistoryStore()
    private var viewModel = SendMessageViewModel()

    /// 何回目の送信成功でレビューを依頼するか
    private static let reviewRequestSendCount = 3

    init() {
        guard ScreenshotDemo.isEnabled else { return }
        let content = ScreenshotDemo.content
        _inputURL = State(initialValue: content.url)
        _inputUsername = State(initialValue: content.message.username)
        _inputAvatarURL = State(initialValue: content.message.avatarURL)
        _inputContext = State(initialValue: content.message.content)
        _inputEmbed = State(initialValue: content.message.messageEmbedEntity)
        _attachment = State(initialValue: ScreenshotDemo.attachment)
        if ScreenshotDemo.scene == .broadcast {
            _broadcastTargets = State(initialValue: ScreenshotDemo.broadcastTargets)
        }
    }

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

                    if broadcastTargets.isEmpty {
                        HStack {
                            ClearableIconTextField(
                                icon: Image(systemName: "link.icloud.fill"),
                                placeholder: "URLを入れてください",
                                text: $inputURL
                            )
                            .onTapGesture {
                                self.isEditing = true
                            }

                            WebhookURLHelpButton()

                            SavedWebhookURLButton(url: $inputURL)
                        }
                    } else {
                        broadcastTargetsRow
                    }

                    // 宛先を選ぶボタンなので、宛先（URL）の直下に置く
                    HStack {
                        BroadcastButton(targets: $broadcastTargets)
                        Spacer()
                        ImageAttachmentButton(attachment: $attachment) {
                            toast = Toast(style: .failure, message: "画像を添付できませんでした。10MBまでの画像を選んでください")
                        }
                    }
                    .padding(.leading, 44.0)

                    // 宛先（URL）ではなく中身の入力欄の上に置く
                    MessageTemplateButtons(message: currentMessage, onApply: applyTemplate) {
                        toast = Toast(style: .success, message: "テンプレートを保存しました")
                    }
                    .padding(.leading, 44.0)

                    ClearableIconTextField(
                        icon: Image(systemName: "rectangle.and.pencil.and.ellipsis"),
                        placeholder: "名前を入れてください",
                        text: $inputUsername
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }

                    ClearableIconTextField(
                        icon: Image(systemName: "person.crop.square"),
                        placeholder: "プロフィール画像のURLを入れてください",
                        text: $inputAvatarURL
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }

                    ClearableIconTextField(
                        icon: Image(systemName: "square.and.pencil"),
                        placeholder: "メッセージを入れてください",
                        text: $inputContext
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }
                }
                .padding(.horizontal)

                Spacer()
                    .frame(height: 24.0)

                HStack {
                    ClearableIconTextField(
                        icon: Image(systemName: "list.clipboard"),
                        placeholder: "埋め込みタイトルを入れてください",
                        text: $inputEmbed.title
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }

                    EmbedEditorButton(embed: $inputEmbed)
                }
                .padding(.horizontal)

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
        .alert(isPresented: $isValidationAlertPresented, error: validationError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
            }
        }
        .toast($toast)
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
            sendMessage()
        }, label: {
            // ローディング中もボタンの大きさが変わらないよう、文言は透明にして残し上に重ねる
            Text("メッセージを送信！")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .opacity(isSending ? 0 : 1)
                .overlay {
                    if isSending {
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
        .disabled(isSending)
    }
}

extension SendMessageView {
    /// 入力内容を検証し、問題があればダイアログを表示、なければ Webhook に送信する
    private func sendMessage() {
        guard !isSending else { return }

        let messageEntity = currentMessage

        if !broadcastTargets.isEmpty {
            sendBroadcast(messageEntity)
            return
        }

        if let error = viewModel.validate(
            url: inputURL,
            messageEntity: messageEntity,
            canUseProFeatures: ProFeatureAccess.canUse(isPro: purchaseManager.isPro)
        ) {
            validationError = error
            isValidationAlertPresented = true
            return
        }

        isSending = true
        // 送信中に URL 欄が書き換えられても、実際に送った先を履歴に残す
        let url = inputURL
        Task {
            let result = await viewModel.postDiscordWebhook(
                url: url,
                messageEntity: messageEntity,
                attachment: attachment
            )
            isSending = false
            // 設定で「送信履歴を保存する」が ON のときだけ記録される
            historyStore.record(url: url, message: messageEntity, isSuccess: (try? result.get()) != nil)
            switch result {
            case .success:
                toast = Toast(style: .success, message: "送信しました")
                await handleSendSucceeded()
            case .failure(let error):
                toast = Toast(style: .failure, verbatimMessage: error.localizedDescription)
            }
        }
    }

    /// 選んだ宛先に一斉送信する（Pro 限定）
    private func sendBroadcast(_ messageEntity: MessageEntity) {
        let urls = broadcastTargets.map(\.url)
        // 宛先を選んだあとに Pro でなくなった場合は送らない
        let error: SendMessageValidationError? = ProFeatureAccess.canUse(isPro: purchaseManager.isPro)
            ? viewModel.validate(url: urls[0], messageEntity: messageEntity, canUseProFeatures: true)
            : .proBroadcast
        if let error {
            validationError = error
            isValidationAlertPresented = true
            return
        }

        isSending = true
        Task {
            let results = await viewModel.broadcast(to: urls, messageEntity: messageEntity, attachment: attachment)
            isSending = false
            let failureCount = results.filter { (try? $0.result.get()) == nil }.count
            for result in results {
                let isSuccess = (try? result.result.get()) != nil
                historyStore.record(url: result.url, message: messageEntity, isSuccess: isSuccess)
            }
            if failureCount == 0 {
                toast = Toast(style: .success, message: "\(results.count)件の宛先に送信しました")
            } else {
                toast = Toast(style: .failure, message: "\(results.count)件中\(failureCount)件の送信に失敗しました")
            }
            if failureCount < results.count {
                await handleSendSucceeded()
            }
        }
    }

    /// 送信に成功したあとの ATT の許可・レビュー依頼・インタースティシャル広告
    private func handleSendSucceeded() async {
        let didRequestTracking = await TrackingAuthorization.requestIfNeeded()
        // 成功回数は ViewModel で記録済み。ちょうど 3 回目の送信のときだけ依頼する
        let shouldRequestReview = SendSuccessCounter().count == Self.reviewRequestSendCount
        if shouldRequestReview {
            requestReview()
        }
        // ATT やレビュー依頼のダイアログに続けて全画面広告を出すと体験を損なうため、その送信では出さない
        if !didRequestTracking && !shouldRequestReview {
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
                Text("\(broadcastTargets.count)件の宛先に一斉送信")
                    .foregroundStyle(Color.appTextPrimary)
                Text(broadcastTargets.map(\.name).joined(separator: "、"))
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                broadcastTargets = []
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

extension SendMessageView {
    /// 入力欄の内容から組み立てた、送信・テンプレート保存用のメッセージ
    private var currentMessage: MessageEntity {
        MessageEntity(
            username: inputUsername,
            avatarURL: inputAvatarURL,
            content: inputContext,
            messageEmbedEntity: inputEmbed
        )
    }

    /// テンプレートの中身を入力欄に反映する。宛先（URL）はそのまま残す
    private func applyTemplate(_ template: MessageTemplate) {
        inputUsername = template.message.username
        inputAvatarURL = template.message.avatarURL
        inputContext = template.message.content
        inputEmbed = template.message.messageEmbedEntity
    }
}

#Preview {
    SendMessageView()
}
