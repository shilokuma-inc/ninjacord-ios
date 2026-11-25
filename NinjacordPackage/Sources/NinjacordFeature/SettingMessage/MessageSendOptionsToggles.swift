//
//  MessageSendOptionsToggles.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面の「送信オプション」セクションの中身。オプションごとにトグルを並べる（Issue #698）
struct MessageSendOptionsToggles: View {
    @Binding var options: MessageSendOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            MessageSendOptionToggle(
                systemImage: "bell.slash.fill",
                title: "通知を鳴らさない",
                note: "Discordの@silentと同じ",
                isOn: $options.suppressesNotifications
            )
            MessageSendOptionToggle(
                systemImage: "eye.slash.fill",
                title: "リンクのプレビューを出さない",
                note: "Discordの仕様で埋め込みも出ない",
                isOn: $options.suppressesEmbeds
            )
            MessageSendOptionToggle(
                systemImage: "at.badge.minus",
                title: "@everyone・@hereで通知しない",
                note: "ユーザーとロールへのメンションは通知する",
                isOn: $options.suppressesEveryoneMentions
            )
        }
    }
}

/// 送信オプションのトグル 1 つ。ほかのセクションの入力欄と同じく左にアイコンを置き、文字の頭を入力欄の文字（左から 44pt）にそろえる
private struct MessageSendOptionToggle: View {
    let systemImage: String
    let title: LocalizedStringResource
    /// 見出しの下に出す補足
    let note: LocalizedStringResource
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 44.0 - MessagePartIcon.gridSize) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.appAccent)
                    .frame(width: MessagePartIcon.gridSize, height: MessagePartIcon.gridSize)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(String(localized: title))
                        .foregroundStyle(Color.appTextPrimary)
                    Text(String(localized: note))
                        .font(.footnote)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .tint(Color.appAccent)
        // HIG の最小サイズ（44pt）を確保する
        .frame(minHeight: 44.0)
    }
}

#Preview {
    SendMessageSection(title: "送信オプション") {
        MessageSendOptionsToggles(options: .constant(MessageSendOptions(suppressesNotifications: true)))
    }
    .padding()
    .background(Color.appBackground)
}
