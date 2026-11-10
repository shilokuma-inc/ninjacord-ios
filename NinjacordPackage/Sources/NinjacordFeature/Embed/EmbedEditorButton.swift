//
//  EmbedEditorButton.swift
//  NinjacordApp
//

import SwiftUI

/// 埋め込みの項目（タイトルを含む）を入力する embed エディタを開くボタン
struct EmbedEditorButton: View {
    @Binding var embed: MessageEmbedEntity

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var isPresented = ScreenshotDemo.scene == .embed

    var body: some View {
        Button(action: {
            isPresented = true
        }, label: {
            Label("埋め込みを編集", systemImage: "slider.horizontal.3")
        })
        // 送信画面のほかの補助ボタン（複数の宛先に送る・画像を添付）とそろえる
        .font(.system(size: 15, weight: .semibold))
        .tint(Color.appAccent)
        .frame(minHeight: 44.0)
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
            .limitedDynamicTypeSize()
        }
    }
}
