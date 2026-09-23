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

    @StateObject private var store = MessageTemplateStore()
    @State private var isListPresented = false
    @State private var isSaveAlertPresented = false
    @State private var name = ""

    var body: some View {
        HStack(spacing: 16.0) {
            Spacer()

            Button {
                isListPresented = true
            } label: {
                Label("テンプレート", systemImage: "doc.on.doc")
            }

            Button {
                name = ""
                isSaveAlertPresented = true
            } label: {
                Label("保存", systemImage: "square.and.arrow.down")
            }
            // 何も入力していない状態を保存しても使い道が無いので押せなくする
            .disabled(!message.hasContent)
        }
        .font(.system(size: 15, weight: .semibold))
        .tint(Color.appAccent)
        .frame(minHeight: 44.0)
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
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // 一覧シートで削除された分を反映してから追加する
        store.reload()
        store.add(name: trimmedName.isEmpty ? MessageTemplate.defaultName(for: message) : trimmedName, message: message)
        onSave()
    }
}
