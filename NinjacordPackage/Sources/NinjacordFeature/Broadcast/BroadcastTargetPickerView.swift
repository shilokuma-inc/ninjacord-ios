//
//  BroadcastTargetPickerView.swift
//  NinjacordApp
//

import SwiftUI

/// 一斉送信の宛先を、保存済み Webhook URL から複数選ぶ画面
struct BroadcastTargetPickerView: View {
    @Binding var selection: [SavedWebhookURL]

    @StateObject private var store = WebhookURLStore()

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea(edges: [.top])

            if store.items.isEmpty {
                Text("保存されたURLはありません。設定の「URL設定」か、送信画面のブックマークから保存してください")
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                List {
                    Section {
                        ForEach(store.items) { item in
                            Button {
                                toggle(item)
                            } label: {
                                row(item)
                            }
                            .listRowBackground(Color.appSurface)
                        }
                    } footer: {
                        Text("選んだ宛先に、同じメッセージを1件ずつ順に送ります")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(.clear)
            }
        }
        .onAppear {
            store.reload()
            // 保存済み URL が削除・編集されていたら、今の一覧に合わせる
            selection = store.items.filter { item in selection.contains { $0.id == item.id } }
        }
    }

    private func row(_ item: SavedWebhookURL) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4.0) {
                Text(item.name)
                    .foregroundStyle(Color.appTextPrimary)
                Text(item.url)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: isSelected(item) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected(item) ? Color.appAccent : Color.appTextSecondary)
                .font(.title3)
        }
        .accessibilityAddTraits(isSelected(item) ? .isSelected : [])
    }

    private func isSelected(_ item: SavedWebhookURL) -> Bool {
        selection.contains { $0.id == item.id }
    }

    /// 選んだ順ではなく、保存済み URL の並び順で送る
    private func toggle(_ item: SavedWebhookURL) {
        if isSelected(item) {
            selection.removeAll { $0.id == item.id }
        } else {
            selection = store.items.filter { isSelected($0) || $0.id == item.id }
        }
    }
}
