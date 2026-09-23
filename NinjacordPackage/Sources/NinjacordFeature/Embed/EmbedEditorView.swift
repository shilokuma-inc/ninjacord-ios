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
            Section("基本") {
                TextField("タイトル", text: $embed.title)
                TextField("説明", text: $embed.description, axis: .vertical)
                    .lineLimit(3...8)
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
                TextField("画像のURL", text: $embed.imageURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("サムネイルのURL", text: $embed.thumbnailURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .listRowBackground(Color.appSurface)

            Section("フッター") {
                TextField("フッターのテキスト", text: $embed.footerText)
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
                    TextField("値", text: $field.value, axis: .vertical)
                        .lineLimit(1...4)
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
        } header: {
            Text("フィールド")
        } footer: {
            Text("左にスワイプすると削除できます")
        }
        .listRowBackground(Color.appSurface)
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

#Preview {
    NavigationStack {
        EmbedEditorView(embed: .constant(MessageEmbedEntity(title: "お知らせ")))
    }
}
