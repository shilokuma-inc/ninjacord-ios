//
//  SavedWebhookURLButton.swift
//  NinjacordApp
//

import SwiftUI

/// 保存済み URL 一覧を開き、選んだ URL を `url` に反映するボタン。
/// アイコンだけだとタップ領域がグリフの大きさ（約 11x18pt）しかなく指で押しても反応しないため、
/// 44pt 角の当たり判定を明示する
struct SavedWebhookURLButton: View {
    @Binding var url: String

    @State private var isPresented = ScreenshotDemo.scene == .savedURLs

    var body: some View {
        Button(action: {
            isPresented = true
        }, label: {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(Color.appAccent)
                .frame(width: 44.0, height: 44.0)
                .contentShape(Rectangle())
        })
        .accessibilityLabel("保存済みURL")
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                SavedDestinationListView(mode: .select(currentURL: url) { selectedURL in
                    url = selectedURL
                    isPresented = false
                })
                .navigationTitle("宛先を選ぶ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            isPresented = false
                        }
                    }
                }
            }
            .limitedDynamicTypeSize()
        }
    }
}
