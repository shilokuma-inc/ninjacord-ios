//
//  WebhookURLHelpView.swift
//  NinjacordApp
//

import SwiftUI
import UIKit

/// Discord で Webhook URL を取得する手順の説明。送信画面の「?」ボタンからシートで表示する
struct WebhookURLHelpView: View {
    /// Discord アプリのトップを開く URL。チャンネルの設定を直接開く公開のディープリンクは無い
    private static let discordAppURL = URL(string: "discord://")!

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    // 撮影用の Simulator には Discord が入っていないので、撮影モードではインストール済みの表示に固定する
    @State private var canOpenDiscord = ScreenshotDemo.scene == .webhookHelp

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

                    if canOpenDiscord {
                        openDiscordButton
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
        .onAppear {
            updateCanOpenDiscord()
        }
        .onChange(of: scenePhase) { phase in
            // App Store で入れて戻ってきた人にも出せるよう、アプリに戻るたびに取り直す
            if phase == .active {
                updateCanOpenDiscord()
            }
        }
    }
}

extension WebhookURLHelpView {
    private var openDiscordButton: some View {
        Button(action: {
            guard !ScreenshotDemo.isEnabled else { return }
            openURL(Self.discordAppURL)
        }, label: {
            Label("Discordアプリを開く", systemImage: "arrow.up.forward.app")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14.0)
                .background(
                    RoundedRectangle(cornerRadius: 12.0)
                        .fill(Color.appAccent)
                )
        })
    }

    /// Discord アプリが入っているかを取り直す。撮影モードでは固定した表示のまま変えない
    private func updateCanOpenDiscord() {
        guard !ScreenshotDemo.isEnabled else { return }
        canOpenDiscord = UIApplication.shared.canOpenURL(Self.discordAppURL)
    }
}

#Preview {
    NavigationStack {
        WebhookURLHelpView()
    }
}
