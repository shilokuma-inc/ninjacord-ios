//
//  SendHistoryListView.swift
//  NinjacordApp
//

import SwiftUI

/// 送信履歴の一覧（新しい順・閲覧のみ）。送ったメッセージの編集・削除は「投稿済み」タブで行う
struct SendHistoryListView: View {
    @StateObject private var store = SendHistoryStore()
    @StateObject private var adModel = InlineBannerAdModel()
    /// 宛先に、保存した宛先の名前を出すため
    @StateObject private var urlStore = WebhookURLStore()

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea(edges: [.top])

            if store.items.isEmpty {
                Text("送信履歴はありません")
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                List {
                    Section {
                        InlineBannerAdRow(model: adModel)
                    }

                    Section {
                        ForEach(store.items) { entry in
                            row(entry)
                                .listRowBackground(Color.appSurface)
                        }
                    }
                }
                .loadsInlineBannerAd(adModel, when: !store.items.isEmpty)
                .scrollContentBackground(.hidden)
                .background(.clear)
            }
        }
        .navigationTitle("送信履歴")
        .onAppear {
            store.reload()
            urlStore.reload()
        }
    }

    private func row(_ entry: SendHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 12.0) {
            Image(systemName: entry.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(entry.isSuccess ? .green : .red)
                .accessibilityLabel(entry.isSuccess ? Text("送信成功") : Text("送信失敗"))

            VStack(alignment: .leading, spacing: 4.0) {
                HStack(spacing: 6.0) {
                    Text(entry.sentAt, format: .dateTime.year().month().day().hour().minute())
                    // 「投稿済み」で編集・削除したメッセージ（Issue #666）
                    if entry.deletedAt != nil {
                        Text("削除済み")
                    } else if entry.editedAt != nil {
                        Text("編集済み")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)

                if !entry.message.summary.isEmpty {
                    Text(entry.message.summary)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)
                }

                // URL にはトークンが含まれるので出さず、保存した宛先の名前（保存していなければ Webhook ID の末尾）を出す（Issue #674）
                Text(urlStore.displayName(for: entry.url))
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
        }
    }
}
