//
//  ClearableIconTextField.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2026/09/21.
//

import SwiftUI

/// 左にアイコン、右端に入力クリア用のバツボタンを持つカプセル型 TextField
struct ClearableIconTextField: View {
    let icon: Image
    let placeholder: LocalizedStringResource
    @Binding var text: String
    /// 入力欄の上に出す見出し。プレースホルダーは入力すると消えるため、入力後も何の欄か分かるように残す
    var title: LocalizedStringResource?
    /// 見出しに続けて出す補足。見出しが無いときは出さない
    var note: LocalizedStringResource?

    /// クリアボタンのタップ領域。HIG の最小サイズ（44pt 角）に合わせる。
    /// 同じ値を TextField 右側の余白にも使い、入力文字がタップ領域の下に潜り込まないようにする
    private let clearButtonHitSize: CGFloat = 44.0

    /// 見出しの左の余白。カプセル内の入力文字（`CapsuleTextFieldStyle` の左余白）と頭をそろえる
    private let titleLeadingPadding: CGFloat = 12.0

    var body: some View {
        // 見出しが付いても、アイコンは見出しを含めた全体ではなく入力欄の中央にそろえる
        HStack(alignment: .textFieldCenter) {
            icon
                .foregroundStyle(Color.appAccent)
                .frame(width: 24.0, height: 24.0)

            VStack(alignment: .leading, spacing: 2.0) {
                if let titleText {
                    titleText
                        .padding(.leading, titleLeadingPadding)
                }

                TextField(
                    "",
                    text: $text,
                    prompt: Text(String(localized: placeholder))
                        .foregroundColor(Color.appPlaceholder)
                )
                .textFieldStyle(.capsule(trailingPadding: clearButtonHitSize))
                .overlay(alignment: .trailing) {
                    if !text.isEmpty {
                        clearButton
                    }
                }
                .alignmentGuide(.textFieldCenter) { $0[VerticalAlignment.center] }
            }
        }
    }

    /// 見出しと補足。行を増やさないよう、補足は別の行にせず見出しに続けて出す（収まらないときだけ折り返す）
    private var titleText: Text? {
        guard let title else { return nil }
        let heading = Text(String(localized: title))
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(Color.appTextSecondary)
        guard let note else { return heading }
        return heading
            + Text(verbatim: "  ")
            + Text(String(localized: note))
                .font(.caption2)
                .foregroundColor(Color.appTextSecondary)
    }

    private var clearButton: some View {
        Button {
            text = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: clearButtonHitSize, height: clearButtonHitSize)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("入力をクリア")
    }
}

extension VerticalAlignment {
    private enum TextFieldCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    /// 見出し付きの `ClearableIconTextField` と横に並べるボタンを、見出しを除いた入力欄の中央にそろえる
    static let textFieldCenter = VerticalAlignment(TextFieldCenter.self)
}

#Preview {
    VStack(spacing: 8.0) {
        ClearableIconTextField(
            icon: Image(systemName: "link.icloud.fill"),
            placeholder: "URLを入れてください",
            text: .constant("")
        )
        ClearableIconTextField(
            icon: Image(systemName: "square.and.pencil"),
            placeholder: "メッセージを入れてください",
            text: .constant("Hello, Discord!")
        )
        ClearableIconTextField(
            icon: Image(systemName: "rectangle.and.pencil.and.ellipsis"),
            placeholder: "名前を入れてください",
            text: .constant("Ninja"),
            title: "名前",
            note: "Discordの送信者名を上書き。空ならWebhookの名前"
        )
    }
    .padding()
    .background(Color.appBackground)
}
