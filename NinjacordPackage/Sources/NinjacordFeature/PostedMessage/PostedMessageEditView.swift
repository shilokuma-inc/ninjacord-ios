//
//  PostedMessageEditView.swift
//  NinjacordApp
//

import SwiftUI

/// 送ったメッセージの本文と埋め込みを書き換える画面（Pro 限定・Issue #666）。
/// 名前・アイコンは Discord の仕様で変えられず、添付した画像はそのまま残すので、編集できるのは本文と埋め込みだけ
struct PostedMessageEditView: View {
    let entry: SendHistoryEntry
    @ObservedObject var viewModel: PostedMessageListViewModel

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    /// プレビューに Webhook の名前とアイコンを出すため（名前・アイコンを空で送ったとき）
    @StateObject private var webhookProfileStore = WebhookProfileStore()
    @State private var content: String
    @State private var embed: MessageEmbedEntity
    @State private var isSaving = false
    @State private var error: PostedMessageEditError?
    @State private var isErrorPresented = false

    /// 編集を始めたときの中身。変えていなければ保存を押せなくする
    private let initialMessage: MessageEntity

    init(entry: SendHistoryEntry, viewModel: PostedMessageListViewModel) {
        self.entry = entry
        self.viewModel = viewModel
        let initialMessage = entry.editableMessage
        self.initialMessage = initialMessage
        _content = State(initialValue: initialMessage.content)
        _embed = State(initialValue: initialMessage.messageEmbedEntity)
    }

    var body: some View {
        Form {
            Section {
                MessagePreview(
                    username: entry.message.username,
                    avatarURL: entry.message.avatarURL,
                    content: content,
                    embed: embed,
                    attachment: nil,
                    webhookProfile: webhookProfileStore.profile(for: webhookProfileInput)
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("Discordでの見え方")
            } footer: {
                if entry.hasAttachment {
                    Text("添付した画像はそのまま残ります")
                }
            }

            Section("本文") {
                TextField("メッセージを入れてください", text: $content, axis: .vertical)
                    .lineLimit(3...10)
                    .listRowBackground(Color.appSurface)
            }

            Section {
                EmbedSummaryRow(summary: EmbedSummary(embed: embed))
                EmbedEditorButton(embed: $embed)
            } header: {
                Text("埋め込み")
            } footer: {
                Text("名前・アイコン・添付した画像は、Discordの仕様で変更できません")
            }
            .listRowBackground(Color.appSurface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .disabled(isSaving)
        .navigationTitle("メッセージを編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
                .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("保存") {
                        save()
                    }
                    .disabled(!hasChanges)
                }
            }
        }
        // 書き換えた中身を、下にスワイプしただけで失わないようにする（やめるときは「キャンセル」）
        .interactiveDismissDisabled(isSaving || hasChanges)
        // iOS 26 のアラートはボタン文字に周囲の tint を使う。画面には AppAccent を付け直し、アラートだけシステム標準の青にする
        .tint(Color.appAccent)
        .alert(isPresented: $isErrorPresented, error: error) { error in
            Button("OK", role: .cancel) {
                // Discord で消されていたメッセージは一覧から外したので、編集画面も閉じる
                if error == .discord(.unknownMessage) {
                    dismiss()
                }
            }
        } message: { error in
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
            }
        }
        .tint(Color(uiColor: .systemBlue))
        .task(id: webhookProfileInput) {
            await webhookProfileStore.load(for: webhookProfileInput)
        }
    }

    /// 編集後の中身。名前・アイコンは変えられないので、送ったときのまま
    private var editedMessage: MessageEntity {
        MessageEntity(
            username: entry.message.username,
            avatarURL: entry.message.avatarURL,
            content: content,
            messageEmbedEntity: embed
        )
    }

    private var hasChanges: Bool {
        editedMessage != initialMessage
    }

    /// 名前・アイコンをプレビューに出す Webhook の URL。名前とアイコンをどちらも指定して送ったなら取得しない
    private var webhookProfileInput: String {
        MessagePreviewProfile.webhookProfileInput(
            webhookURL: entry.url,
            username: entry.message.username,
            avatarURL: entry.message.avatarURL,
            isBroadcasting: false,
            isScreenshotDemo: ScreenshotDemo.isEnabled
        )
    }

    private func save() {
        isSaving = true
        Task {
            let error = await viewModel.edit(
                entry,
                message: editedMessage,
                canUseProFeatures: ProFeatureAccess.canUse(isPro: purchaseManager.isPro)
            )
            isSaving = false
            if let error {
                self.error = error
                isErrorPresented = true
            } else {
                dismiss()
            }
        }
    }
}
