//
//  MessageTemplateButtons.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面に置く、テンプレートの呼び出し・保存ボタン。一覧のシートと保存のアラートもここで持つ
struct MessageTemplateButtons: View {
    /// 保存するときの中身（送信画面の入力欄の内容）
    let message: MessageEntity
    /// 一覧でテンプレートを選んだとき
    let onApply: (MessageTemplate) -> Void
    /// 保存したとき（送信画面でトーストを出すため）
    let onSave: () -> Void

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @ObservedObject private var rewardedUnlock = RewardedUnlockState.shared
    @StateObject private var store = MessageTemplateStore()
    @State private var isListPresented = ScreenshotDemo.scene == .templates
    @State private var isSaveAlertPresented = false
    @State private var isLimitAlertPresented = false
    @State private var isPaywallPresented = false
    @State private var name = ""
    @ObservedObject private var rewardedAdManager = RewardedAdManager.shared

    var body: some View {
        HStack(spacing: 16.0) {
            Spacer()

            Button {
                isListPresented = true
            } label: {
                Label("テンプレート", systemImage: "doc.on.doc")
            }

            Button {
                // 一覧シートで削除された分を反映してから上限を判定する
                store.reload()
                // リワード広告の一時解放中も、Pro と同じく無制限に保存できる
                if store.canAdd(isPro: ProFeatureAccess.canUse(isPro: purchaseManager.isPro)) {
                    name = ""
                    isSaveAlertPresented = true
                } else {
                    isLimitAlertPresented = true
                }
            } label: {
                Label("保存", systemImage: "square.and.arrow.down")
            }
            // 何も入力していない状態を保存しても使い道が無いので押せなくする
            .disabled(!message.hasContent)
        }
        .font(.system(size: 15, weight: .semibold))
        .tint(Color.appAccent)
        .frame(minHeight: 44.0)
        .preloadsRewardedAd(when: !ProFeatureAccess.canUse(isPro: purchaseManager.isPro))
        .sheet(isPresented: $isListPresented) {
            listSheet
        }
        .alert("テンプレートとして保存", isPresented: $isSaveAlertPresented) {
            TextField("テンプレート名", text: $name)
            Button("保存") {
                save()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今の入力内容を保存します（送信先のURLは含みません）")
        }
        .alert("テンプレートは\(MessageTemplateStore.freeLimit)件までです", isPresented: $isLimitAlertPresented) {
            Button("Proを見る") {
                isPaywallPresented = true
            }
            if rewardedAdManager.isReady {
                Button(RewardedUnlock.watchAdTitle) {
                    Task {
                        if await rewardedAdManager.showForUnlock() {
                            // 解放されたら、そのまま保存に進む
                            name = ""
                            isSaveAlertPresented = true
                        }
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("Ninjacord Proなら、テンプレートを無制限に保存できます")
        }
        .sheet(isPresented: $isPaywallPresented) {
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
            .environmentObject(purchaseManager)
        }
    }

    private var listSheet: some View {
        NavigationStack {
            MessageTemplateListView { template in
                onApply(template)
                isListPresented = false
            }
            .navigationTitle("テンプレート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        isListPresented = false
                    }
                }
            }
        }
        // シートは別の View 階層になるため、Pro 状態を明示的に渡す
        .environmentObject(purchaseManager)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // 一覧シートで削除された分を反映してから追加する
        store.reload()
        store.add(name: trimmedName.isEmpty ? MessageTemplate.defaultName(for: message) : trimmedName, message: message)
        onSave()
    }
}
