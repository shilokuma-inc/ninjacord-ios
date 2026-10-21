//
//  EmbedSummaryRow.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面の「埋め込み」セクションに出す、入力済みの内容の要約（タイトルと入力済みの項目）
struct EmbedSummaryRow: View {
    let summary: EmbedSummary

    var body: some View {
        // 入力欄の行と同じく、左にアイコン・右に中身を並べる
        HStack(alignment: .top) {
            Image(systemName: "list.clipboard")
                .foregroundStyle(Color.appAccent)
                .frame(width: 24.0, height: 24.0)

            VStack(alignment: .leading, spacing: 2.0) {
                // 何も入力していないときは、タイトルの行を出さず 2 行目の「未設定」だけにする
                if summary.state != .empty {
                    Text(summary.title ?? String(localized: "タイトルなし"))
                        .foregroundStyle(summary.title == nil ? Color.appPlaceholder : Color.appTextPrimary)
                        .lineLimit(2)
                }
                Text(summary.detail)
                    .font(.footnote)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // アイコンの左余白をそろえ、文字の頭を入力欄の文字（見出しの位置）と合わせる
            .padding(.leading, 12.0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16.0) {
        EmbedSummaryRow(summary: EmbedSummary(embed: MessageEmbedEntity()))
        EmbedSummaryRow(summary: EmbedSummary(embed: MessageEmbedEntity(color: 0x5865F2)))
        EmbedSummaryRow(summary: EmbedSummary(embed: MessageEmbedEntity(title: "お知らせ")))
        EmbedSummaryRow(summary: EmbedSummary(embed: MessageEmbedEntity(
            title: "今夜21:00 レイド開始",
            description: "初参加も大歓迎です",
            color: 0x57F287,
            fields: [MessageEmbedField(name: "集合", value: "20:50", isInline: true)],
            imageURL: "https://example.com/image.png"
        )))
        EmbedSummaryRow(summary: EmbedSummary(embed: MessageEmbedEntity(description: "タイトルの無い埋め込み")))
    }
    .padding()
    .background(Color.appBackground)
}
