//
//  MessageTemplateListView.swift
//  NinjacordApp
//

import SwiftUI

/// テンプレートの一覧。行をタップすると `onSelect` で選んだテンプレートを返す。スワイプで削除できる
struct MessageTemplateListView: View {
    let onSelect: (MessageTemplate) -> Void

    @StateObject private var store = MessageTemplateStore()

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea(edges: [.top])

            if store.items.isEmpty {
                Text("保存されたテンプレートはありません")
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                List {
                    ForEach(store.items) { template in
                        Button {
                            onSelect(template)
                        } label: {
                            row(template)
                        }
                        .listRowBackground(Color.appSurface)
                    }
                    .onDelete { offsets in
                        store.remove(at: offsets)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(.clear)
            }
        }
        .onAppear {
            store.reload()
        }
    }

    private func row(_ template: MessageTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            Text(template.name)
                .foregroundStyle(Color.appTextPrimary)

            // 中身をひと目で見分けられるよう、メッセージの要約を 1 行だけ添える
            if !template.message.summary.isEmpty {
                Text(template.message.summary)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
        }
    }
}
