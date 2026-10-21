//
//  SendMessageSection.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面のひとまとまり（宛先・送信者・本文・埋め込み・添付）。見出しと中身を 1 枚の面にまとめる（Discussion #586 の Q1）。
/// 入力欄（`appSurfaceSecondary`）と見分けられるよう、面は一段明るい `appSurface` で塗る。
/// `isExpanded` を渡すと見出しで開閉でき、閉じている間は中身の代わりに `collapsedSummary` を出す（Q6）
struct SendMessageSection<Content: View>: View {
    let title: LocalizedStringResource
    /// 開閉の状態。nil なら開閉できない（常に中身を出す）
    var isExpanded: Binding<Bool>?
    /// 閉じているときに、中身の代わりに出す 1 行の要約
    var collapsedSummary: String?
    @ViewBuilder let content: Content

    /// 見出しと中身、中身どうしの間隔。送信画面の入力欄どうしの間隔と同じ値
    private static var spacing: CGFloat { 8.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            if let isExpanded {
                disclosureHeader(isExpanded: isExpanded)
            } else {
                titleText
                    .accessibilityAddTraits(.isHeader)
            }

            if isExpanded?.wrappedValue ?? true {
                content
            } else if let collapsedSummary {
                Text(collapsedSummary)
                    .font(.footnote)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12.0)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16.0))
    }

    private var titleText: some View {
        Text(String(localized: title))
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.appTextPrimary)
    }

    /// 開閉のボタンを兼ねた見出し。「Discordでの見え方」と同じく、右端の矢印の向きで開閉を示す
    private func disclosureHeader(isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack {
                titleText
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 90.0 : 0.0))
                    .accessibilityHidden(true)
            }
            // 見出しの行全体をタップ領域にし、HIG の最小サイズ（44pt）を確保する
            .frame(minHeight: 44.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(isExpanded.wrappedValue ? Text("展開済み") : Text("折りたたみ済み"))
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
        SendMessageSection(
            title: "送信者",
            isExpanded: .constant(false),
            collapsedSummary: "名前: レイド告知Bot・アイコン: 指定済み"
        ) {
            EmptyView()
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
