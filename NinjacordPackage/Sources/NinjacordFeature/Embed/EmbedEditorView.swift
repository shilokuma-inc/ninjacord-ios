//
//  EmbedEditorView.swift
//  NinjacordApp
//

import SwiftUI

/// 埋め込み（embed）の各項目を入力する画面。Discussion #259 の決定により、送信画面とは別の画面にしている
struct EmbedEditorView: View {
    @Binding var embed: MessageEmbedEntity

    var body: some View {
        Form {
            Section("プレビュー") {
                if embed.hasContent {
                    // 入力に合わせてその場で更新される
                    EmbedPreview(embed: embed)
                        .listRowInsets(EdgeInsets())
                } else {
                    Text("項目を入力すると、Discordでの見え方がここに表示されます")
                        .font(.footnote)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .listRowBackground(embed.hasContent ? Color.clear : Color.appSurface)

            Section {
                // 入力欄と文字数を 1 行にまとめる（別の行にすると区切り線が増えて読みにくい）
                VStack(spacing: 4.0) {
                    TextField("タイトル", text: $embed.title)
                    EmbedLengthCounter(text: embed.title, limit: EmbedLimit.title)
                }
                VStack(spacing: 4.0) {
                    TextField("説明", text: $embed.description, axis: .vertical)
                        .lineLimit(3...8)
                    EmbedLengthCounter(text: embed.description, limit: EmbedLimit.description)
                }
            } header: {
                Text("基本")
            } footer: {
                totalCounter
            }
            .listRowBackground(Color.appSurface)

            Section("色") {
                Toggle("色を指定する", isOn: isColorEnabled)
                    .tint(Color.appAccent)
                if embed.color != nil {
                    ColorPicker("左端の線の色", selection: color, supportsOpacity: false)
                }
            }
            .listRowBackground(Color.appSurface)

            fieldsSection

            Section("画像") {
                VStack(alignment: .leading, spacing: 4.0) {
                    TextField("画像のURL", text: $embed.imageURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    issueText(for: .invalidImageURL)
                }
                VStack(alignment: .leading, spacing: 4.0) {
                    TextField("サムネイルのURL", text: $embed.thumbnailURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    issueText(for: .invalidThumbnailURL)
                }
            }
            .listRowBackground(Color.appSurface)

            Section("フッター") {
                VStack(spacing: 4.0) {
                    TextField("フッターのテキスト", text: $embed.footerText)
                    EmbedLengthCounter(text: embed.footerText, limit: EmbedLimit.footerText)
                }
                Toggle("送信日時を表示する", isOn: $embed.includesTimestamp)
                    .tint(Color.appAccent)
            }
            .listRowBackground(Color.appSurface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("埋め込み")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var fieldsSection: some View {
        Section {
            ForEach($embed.fields) { $field in
                VStack(alignment: .leading, spacing: 8.0) {
                    TextField("名前", text: $field.name)
                    EmbedLengthCounter(text: field.name, limit: EmbedLimit.fieldName)
                    TextField("値", text: $field.value, axis: .vertical)
                        .lineLimit(1...4)
                    EmbedLengthCounter(text: field.value, limit: EmbedLimit.fieldValue)
                    Toggle("横に並べる", isOn: $field.isInline)
                        .tint(Color.appAccent)
                }
                .padding(.vertical, 4.0)
            }
            .onDelete { offsets in
                embed.fields.remove(atOffsets: offsets)
            }

            Button {
                embed.fields.append(MessageEmbedField(name: "", value: "", isInline: false))
            } label: {
                Label("フィールドを追加", systemImage: "plus.circle.fill")
            }
            .disabled(embed.fields.count >= EmbedLimit.fieldCount)
        } header: {
            Text("フィールド")
        } footer: {
            Text("\(embed.fields.count) / \(EmbedLimit.fieldCount)件・左にスワイプすると削除できます")
        }
        .listRowBackground(Color.appSurface)
    }

    /// 合計文字数（title・description・fields・footer）。Discord の上限は合計 6000 文字
    private var totalCounter: some View {
        let isOver = embed.totalLength > EmbedLimit.total
        return Text("合計 \(embed.totalLength) / \(EmbedLimit.total)文字")
            .foregroundStyle(isOver ? Color.red : Color.appTextSecondary)
    }

    /// 指定した誤りがあるときだけ、その内容を赤字で出す
    @ViewBuilder
    private func issueText(for issue: EmbedValidationIssue) -> some View {
        if embed.validationIssues().contains(issue) {
            Text(issue.message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    /// 色の指定の有無。オンにしたときは Discord のブランドカラー（Blurple）から始める
    private var isColorEnabled: Binding<Bool> {
        Binding(
            get: { embed.color != nil },
            set: { embed.color = $0 ? 0x5865F2 : nil }
        )
    }

    /// Int（0xRRGGBB）で持っている色を ColorPicker で編集するための変換
    private var color: Binding<Color> {
        Binding(
            get: {
                let rgb = embed.color ?? 0
                return Color(
                    red: Double((rgb >> 16) & 0xFF) / 255,
                    green: Double((rgb >> 8) & 0xFF) / 255,
                    blue: Double(rgb & 0xFF) / 255
                )
            },
            set: { newColor in
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                UIColor(newColor).getRed(&red, green: &green, blue: &blue, alpha: nil)
                let clamp: (CGFloat) -> Int = { Int((min(max($0, 0), 1) * 255).rounded()) }
                embed.color = (clamp(red) << 16) | (clamp(green) << 8) | clamp(blue)
            }
        )
    }
}

/// 入力中の文字数と上限。上限を超えたら赤くする（数え方は Discord と同じ UTF-16）
private struct EmbedLengthCounter: View {
    let text: String
    let limit: Int

    var body: some View {
        Text("\(text.discordLength) / \(limit)")
            .font(.caption)
            .foregroundStyle(text.discordLength > limit ? Color.red : Color.appTextSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

#Preview {
    NavigationStack {
        EmbedEditorView(embed: .constant(MessageEmbedEntity(title: "お知らせ")))
    }
}
