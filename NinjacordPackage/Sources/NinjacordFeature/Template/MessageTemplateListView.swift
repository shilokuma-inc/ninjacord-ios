//
//  MessageTemplateListView.swift
//  NinjacordApp
//

import SwiftUI

/// テンプレートの一覧。行をタップすると `onSelect` で選んだテンプレートを返す。
/// 右スワイプで削除、左スワイプでピン留め、「編集」で並び替えができる
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
                        .swipeActions(edge: .leading) {
                            Button {
                                store.togglePin(id: template.id)
                            } label: {
                                if template.isPinned {
                                    Label("ピン留めを外す", systemImage: "pin.slash")
                                } else {
                                    Label("ピン留め", systemImage: "pin")
                                }
                            }
                            .tint(.orange)
                        }
                    }
                    .onDelete { offsets in
                        store.remove(at: offsets)
                    }
                    .onMove { source, destination in
                        store.move(fromOffsets: source, toOffset: destination)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(.clear)
            }
        }
        .toolbar {
            if !store.items.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
        .onAppear {
            store.reload()
        }
    }

    private func row(_ template: MessageTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            HStack(spacing: 6.0) {
                if template.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("ピン留め中")
                }
                Text(template.name)
                    .foregroundStyle(Color.appTextPrimary)
            }

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
