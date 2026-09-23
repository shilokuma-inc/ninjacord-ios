//
//  SendHistoryListView.swift
//  NinjacordApp
//

import SwiftUI

/// 送信履歴の一覧（新しい順・閲覧のみ）
struct SendHistoryListView: View {
    @StateObject private var store = SendHistoryStore()

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea(edges: [.top])

            if store.items.isEmpty {
                Text("送信履歴はありません")
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                List(store.items) { entry in
                    row(entry)
                        .listRowBackground(Color.appSurface)
                }
                .scrollContentBackground(.hidden)
                .background(.clear)
            }
        }
        .navigationTitle("送信履歴")
        .onAppear {
            store.reload()
        }
    }

    private func row(_ entry: SendHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 12.0) {
            Image(systemName: entry.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(entry.isSuccess ? .green : .red)
                .accessibilityLabel(entry.isSuccess ? Text("送信成功") : Text("送信失敗"))

            VStack(alignment: .leading, spacing: 4.0) {
                Text(entry.sentAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)

                if !entry.message.summary.isEmpty {
                    Text(entry.message.summary)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)
                }

                // URL の末尾はトークンなので、先頭（どの Webhook か）が見えるよう末尾を省略する
                Text(entry.url)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}
