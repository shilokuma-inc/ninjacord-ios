//
//  WebhookURLHelpView.swift
//  NinjacordApp
//

import SwiftUI

/// Discord で Webhook URL を取得する手順の説明。送信画面の「?」ボタンからシートで表示する
struct WebhookURLHelpView: View {
    private let steps: [LocalizedStringKey] = [
        "Discordで、メッセージを送りたいチャンネルの「チャンネルの編集」（歯車アイコン）を開きます",
        "「連携サービス」→「ウェブフック」を開きます",
        "「新しいウェブフック」を作り、「ウェブフックURLをコピー」を押します",
        "このアプリのURL欄に貼り付けます"
    ]

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20.0) {
                    ForEach(steps.indices, id: \.self) { index in
                        HStack(alignment: .firstTextBaseline, spacing: 12.0) {
                            Text(String(index + 1))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28.0, height: 28.0)
                                .background(Circle().fill(Color.appAccent))
                                .accessibilityHidden(true)

                            Text(steps[index])
                                .font(.system(size: 17))
                                .foregroundStyle(Color.appTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("ウェブフックを作るには、そのサーバーで「ウェブフックの管理」の権限が必要です")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8.0)
                }
                .padding(24.0)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WebhookURLHelpView()
    }
}
