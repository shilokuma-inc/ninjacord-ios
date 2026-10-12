//
//  EmbedPreview.swift
//  NinjacordApp
//

import SwiftUI

/// 埋め込みが Discord 上でどう見えるかの簡易プレビュー。
/// Discussion #259 の決定により、色つき縦線 + title / description / fields / footer 程度に留め、完全には再現しない。
/// Discord 上での見え方を示すため、アプリのテーマに関係なく Discord のダークテーマ風の配色で描く
struct EmbedPreview: View {
    let embed: MessageEmbedEntity

    /// Discord のダークテーマの配色
    private enum Palette {
        static let background = Color(red: 0x2B / 255, green: 0x2D / 255, blue: 0x31 / 255)
        static let defaultAccent = Color(red: 0x1E / 255, green: 0x1F / 255, blue: 0x22 / 255)
        static let title = Color(red: 0xF2 / 255, green: 0xF3 / 255, blue: 0xF5 / 255)
        static let text = Color(red: 0xDB / 255, green: 0xDE / 255, blue: 0xE1 / 255)
        static let secondary = Color(red: 0xB5 / 255, green: 0xBA / 255, blue: 0xC1 / 255)
    }

    /// Discord は inline の fields を 1 行に最大 3 件まで並べる
    private static let maxInlineFieldsPerRow = 3

    var body: some View {
        HStack(spacing: .zero) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4.0)

            VStack(alignment: .leading, spacing: 8.0) {
                if !embed.title.isEmpty {
                    Text(embed.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.title)
                }
                if !embed.description.isEmpty {
                    Text(embed.description)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.text)
                }
                ForEach(Array(fieldRows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 12.0) {
                        ForEach(row) { field in
                            fieldView(field)
                        }
                    }
                }
                if !embed.footerText.isEmpty {
                    Text(embed.footerText)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.secondary)
                }
            }
            .padding(12.0)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 4.0))
        .accessibilityElement(children: .combine)
    }

    private var accentColor: Color {
        guard let rgb = embed.color else { return Palette.defaultAccent }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    /// inline の fields は続いている分を最大 3 件ずつ 1 行に、inline でない field は 1 件で 1 行にまとめる
    private var fieldRows: [[MessageEmbedField]] {
        var rows: [[MessageEmbedField]] = []
        for field in embed.sendableFields {
            if field.isInline,
               let last = rows.last,
               last.allSatisfy(\.isInline),
               last.count < Self.maxInlineFieldsPerRow {
                rows[rows.count - 1].append(field)
            } else {
                rows.append([field])
            }
        }
        return rows
    }

    private func fieldView(_ field: MessageEmbedField) -> some View {
        VStack(alignment: .leading, spacing: 2.0) {
            Text(field.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.title)
            Text(field.value)
                .font(.system(size: 14))
                .foregroundStyle(Palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    EmbedPreview(embed: MessageEmbedEntity(
        title: "お知らせ",
        description: "本日18時からメンテナンスです",
        color: 0x5865F2,
        fields: [
            MessageEmbedField(name: "開始", value: "18:00", isInline: true),
            MessageEmbedField(name: "終了", value: "19:00", isInline: true),
            MessageEmbedField(name: "影響", value: "送信ができなくなります", isInline: false)
        ],
        footerText: "Ninja Cord"
    ))
    .padding()
}
