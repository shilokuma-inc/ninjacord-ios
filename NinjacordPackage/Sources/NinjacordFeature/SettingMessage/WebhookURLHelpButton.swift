//
//  WebhookURLHelpButton.swift
//  NinjacordApp
//

import SwiftUI

/// Webhook URL の取得方法を表示するボタン。「?」のアイコンだけでは気づきにくいので、文言も出す（Issue #674）。
/// 送信画面の「宛先」の見出しの右に置く
struct WebhookURLHelpButton: View {
    /// シートで貼り付けた Webhook URL を入れる先（送信画面の宛先）
    @Binding var url: String
    @State private var isPresented = ScreenshotDemo.scene == .webhookHelp

    var body: some View {
        Button(action: {
            isPresented = true
        }, label: {
            Label("Webhook URLの取得方法", systemImage: "questionmark.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appAccent)
                // 見出しの行の高さは変えずに、押せる範囲だけを HIG の最小サイズ（44pt）まで広げる
                .padding(.vertical, 12.0)
                .contentShape(Rectangle())
                .padding(.vertical, -12.0)
        })
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                WebhookURLHelpView(onPasteWebhookURL: { pastedURL in
                    // ユーザーが自分で押した操作なので、今の宛先は上書きする
                    url = pastedURL
                    isPresented = false
                })
                    .navigationTitle("Webhook URLの取得方法")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") {
                                isPresented = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .limitedDynamicTypeSize()
        }
    }
}
