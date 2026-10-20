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
    /// App Store の Discord のページ
    private static let discordAppStoreURL = URL(string: "https://apps.apple.com/app/id985746746")!
    /// Discord の Web 版。ログインするとそのままクライアントに入れる
    private static let discordWebURL = URL(string: "https://discord.com/app")!
    /// Discord の Webhook URL の形。`discordapp.com` や `ptb.` / `canary.`、API のバージョン付き、`?thread_id=` などのクエリ付きも受け付ける
    private static let webhookURLPattern = #"^https://((ptb|canary)\.)?discord(app)?\.com"#
        + #"/api(/v[0-9]+)?/webhooks/[0-9]+/[A-Za-z0-9_-]+/?(\?.*)?$"#

    /// 貼り付けた Webhook URL を受け取る。送信画面の URL 欄に入れてシートを閉じる
    var onPasteWebhookURL: (String) -> Void = { _ in }

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    // 判定するまでは nil にして、どちらの表示も出さない（インストール済みの人に未インストールの表示がちらつかないように）。
    // 撮影用の Simulator には Discord が入っていないので、撮影モードではインストール済みの表示に固定する
    @State private var canOpenDiscord: Bool? = ScreenshotDemo.scene == .webhookHelp ? true : nil
    @State private var isBrowserPresented = false
    // Discord（アプリ / App Store / ブラウザ）を開いたら、戻ってきたときに貼り付けの導線を出す
    @State private var hasOpenedDiscord = false
    @State private var isInvalidPaste = false

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

                    if hasOpenedDiscord {
                        pasteWebhookURLSection
                    }

                    switch canOpenDiscord {
                    case true?:
                        openDiscordButton
                    case false?:
                        discordNotInstalledLinks
                    case nil:
                        EmptyView()
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
        .fullScreenCover(isPresented: $isBrowserPresented) {
            SafariView(url: Self.discordWebURL)
                .ignoresSafeArea()
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
            hasOpenedDiscord = true
            openURL(Self.discordAppURL)
        }, label: {
            actionLabel("Discordアプリを開く", systemImage: "arrow.up.forward.app", isProminent: true)
        })
    }

    /// Discord アプリが入っていないときの代わりの導線。App Store で入れるか、Web 版をアプリ内ブラウザで開く。
    /// シートの medium の高さでもスクロールせずに見えるよう横に並べる。文言が長い言語では折り返し、2 つの高さはそろえる
    private var discordNotInstalledLinks: some View {
        VStack(alignment: .leading, spacing: 12.0) {
            Text("Discordアプリが見つかりません")
                .font(.system(size: 15))
                .foregroundStyle(Color.appTextSecondary)

            HStack(spacing: 12.0) {
                appStoreButton
                browserButton
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appStoreButton: some View {
        Button(action: {
            guard !ScreenshotDemo.isEnabled else { return }
            hasOpenedDiscord = true
            openURL(Self.discordAppStoreURL)
        }, label: {
            actionLabel("App Storeで入手", systemImage: "arrow.down.app", isProminent: true)
        })
    }

    private var browserButton: some View {
        Button(action: {
            guard !ScreenshotDemo.isEnabled else { return }
            hasOpenedDiscord = true
            isBrowserPresented = true
        }, label: {
            actionLabel("ブラウザで開く", systemImage: "safari", isProminent: false)
        })
    }

    /// コピーした Webhook URL を URL 欄に入れる導線。手順 4 を読んだ流れで押せるよう手順の直後に置く。
    /// PasteButton は押したときだけクリップボードを読むので、「ペーストを許可」の確認が出ない
    private var pasteWebhookURLSection: some View {
        VStack(alignment: .leading, spacing: 12.0) {
            Text("コピーしたWebhook URLをURL欄に入れられます")
                .font(.system(size: 15))
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            PasteButton(payloadType: String.self) { strings in
                guard let string = strings.first else { return }
                // 貼り付けの処理はメインスレッド以外から呼ばれることがある
                Task { @MainActor in
                    pasteWebhookURL(string)
                }
            }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.roundedRectangle(radius: 12.0))
            .controlSize(.large)
            .tint(Color.appAccent)

            if isInvalidPaste {
                Text("コピーされている内容はWebhook URLではありません")
                    .font(.system(size: 15))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Discord の Webhook URL だけを URL 欄に入れる。それ以外は入れずに知らせる
    private func pasteWebhookURL(_ string: String) {
        let url = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard url.range(of: Self.webhookURLPattern, options: .regularExpression) != nil else {
            isInvalidPaste = true
            return
        }
        isInvalidPaste = false
        onPasteWebhookURL(url)
    }

    /// シート内のボタンの見た目。isProminent なら塗り、そうでなければ枠線にする
    private func actionLabel(_ title: LocalizedStringKey, systemImage: String, isProminent: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isProminent ? Color.white : Color.appAccent)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8.0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 14.0)
            .background(
                RoundedRectangle(cornerRadius: 12.0)
                    .fill(isProminent ? Color.appAccent : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12.0)
                    .stroke(Color.appAccent, lineWidth: isProminent ? 0.0 : 1.5)
            )
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
