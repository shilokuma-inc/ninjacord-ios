//
//  SendMessageSection.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面のひとまとまり（宛先・送信者・本文・埋め込み・添付）。見出しと中身を 1 枚の面にまとめる（Discussion #586 の Q1）。
/// 入力欄（`appSurfaceSecondary`）と見分けられるよう、面は一段明るい `appSurface` で塗る
struct SendMessageSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: Content

    /// 見出しと中身、中身どうしの間隔。送信画面の入力欄どうしの間隔と同じ値
    private static var spacing: CGFloat { 8.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            Text(String(localized: title))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
                .accessibilityAddTraits(.isHeader)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12.0)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16.0))
    }
}

#Preview {
    VStack(spacing: 12.0) {
        SendMessageSection(title: "宛先") {
            ClearableIconTextField(
                icon: Image(systemName: "link.icloud.fill"),
                placeholder: "URLを入れてください",
                text: .constant(""),
                title: "Webhook URL"
            )
        }
        SendMessageSection(title: "本文") {
            ClearableIconTextField(
                icon: Image(systemName: "square.and.pencil"),
                placeholder: "メッセージを入れてください",
                text: .constant("こんにちは"),
                title: "メッセージ"
            )
        }
    }
    .padding()
    .background(Color.appBackground)
}
