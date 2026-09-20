//
//  SavedWebhookURLListView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2026/09/21.
//

import SwiftUI

/// 保存済み Webhook URL の一覧。
/// `onSelect` を渡すと行タップで選択できる（送信画面用）、nil なら閲覧・削除のみ（設定画面用）。
struct SavedWebhookURLListView: View {
    var onSelect: ((SavedWebhookURL) -> Void)?
    /// 追加フォームを開いたときに URL 欄へ初期表示する値
    var initialURL = ""

    @StateObject private var store = WebhookURLStore()
    @State private var isAddFormPresented = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea(edges: [.top])

            if store.items.isEmpty {
                Text("保存されたURLはありません")
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                List {
                    ForEach(store.items) { item in
                        row(item)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAddFormPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddFormPresented) {
            SavedWebhookURLFormView(initialURL: initialURL) { name, url in
                store.add(name: name, url: url)
            }
        }
        .onAppear {
            store.reload()
        }
    }

    @ViewBuilder
    private func row(_ item: SavedWebhookURL) -> some View {
        if let onSelect {
            Button {
                onSelect(item)
            } label: {
                rowContent(item)
            }
        } else {
            rowContent(item)
        }
    }

    private func rowContent(_ item: SavedWebhookURL) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            Text(item.name)
                .foregroundStyle(Color.appTextPrimary)

            Text(item.url)
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
                .lineLimit(1)
        }
    }
}

/// 名前と URL を入力して保存する簡易フォーム
private struct SavedWebhookURLFormView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State private var name = ""
    @State private var url: String
    private let onSave: (_ name: String, _ url: String) -> Void

    init(initialURL: String, onSave: @escaping (_ name: String, _ url: String) -> Void) {
        _url = State(initialValue: initialURL)
        self.onSave = onSave
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !trimmedURL.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                inputFields
            }
            .navigationTitle("URLを保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(trimmedName, trimmedURL)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var inputFields: some View {
        VStack(spacing: 8.0) {
            TextField(
                "",
                text: $name,
                prompt: Text("名前を入れてください")
                    .foregroundColor(Color.appPlaceholder)
            )
            .textFieldStyle(.capsule)

            TextField(
                "",
                text: $url,
                prompt: Text("URLを入れてください")
                    .foregroundColor(Color.appPlaceholder)
            )
            .textFieldStyle(.capsule)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Spacer()
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        SavedWebhookURLListView(onSelect: nil)
            .navigationTitle("URL設定")
    }
}
