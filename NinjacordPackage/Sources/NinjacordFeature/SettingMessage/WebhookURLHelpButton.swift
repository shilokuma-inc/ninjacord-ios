//
//  WebhookURLHelpButton.swift
//  NinjacordApp
//

import SwiftUI

/// Webhook URL の取得方法を表示する「?」ボタン。保存済み URL ボタンと同じく 44pt 角の当たり判定にする
struct WebhookURLHelpButton: View {
    @State private var isPresented = ScreenshotDemo.scene == .webhookHelp

    var body: some View {
        Button(action: {
            isPresented = true
        }, label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(Color.appAccent)
                .frame(width: 44.0, height: 44.0)
                .contentShape(Rectangle())
        })
        .accessibilityLabel("Webhook URLの取得方法")
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                WebhookURLHelpView()
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
        }
    }
}
