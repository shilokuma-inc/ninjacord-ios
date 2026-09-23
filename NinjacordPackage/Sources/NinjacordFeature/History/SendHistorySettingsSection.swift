//
//  SendHistorySettingsSection.swift
//  NinjacordApp
//

import SwiftUI

/// 設定画面の「送信履歴」セクション。保存の ON/OFF（デフォルト OFF）、一覧、すべて削除を提供する
struct SendHistorySettingsSection: View {
    @AppStorage(SendHistoryStore.isEnabledKey) private var isEnabled = false
    @StateObject private var store = SendHistoryStore()
    @State private var isListPresented = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        Section {
            Toggle("送信履歴を保存する", isOn: $isEnabled)
                .foregroundStyle(Color.appTextPrimary)
                .tint(Color.appAccent)
                .listRowBackground(Color.appSurface)

            Button {
                isListPresented = true
            } label: {
                HStack {
                    Text("送信履歴")
                        .foregroundStyle(Color.appTextPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .listRowBackground(Color.appSurface)
            .navigationDestination(isPresented: $isListPresented) {
                SendHistoryListView()
            }

            Button("送信履歴をすべて削除", role: .destructive) {
                isDeleteConfirmationPresented = true
            }
            .disabled(store.items.isEmpty)
            .listRowBackground(Color.appSurface)
            .confirmationDialog(
                "送信履歴をすべて削除しますか？",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("すべて削除", role: .destructive) {
                    store.removeAll()
                }
            }
        } header: {
            Text("送信履歴")
                .foregroundStyle(Color.appTextSecondary)
        } footer: {
            Text("ONにすると、直近\(SendHistoryStore.maxCount)件の送信内容をこの端末の中にだけ保存します")
                .foregroundStyle(Color.appTextSecondary)
        }
        .onAppear {
            // 送信画面で追加された履歴を反映して「すべて削除」を押せるか判定する
            store.reload()
        }
    }
}
