//
//  EmbedEditorButton.swift
//  NinjacordApp
//

import SwiftUI

/// 埋め込みのタイトル以外の項目を入力する embed エディタを開くボタン
struct EmbedEditorButton: View {
    @Binding var embed: MessageEmbedEntity

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var isPresented = false

    var body: some View {
        Button(action: {
            isPresented = true
        }, label: {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(Color.appAccent)
                .frame(width: 44.0, height: 44.0)
                .contentShape(Rectangle())
        })
        .accessibilityLabel("埋め込みを編集")
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                EmbedEditorView(embed: $embed)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完了") {
                                isPresented = false
                            }
                        }
                    }
            }
            // シートは別の View 階層になるため、Pro 状態を明示的に渡す
            .environmentObject(purchaseManager)
        }
    }
}
