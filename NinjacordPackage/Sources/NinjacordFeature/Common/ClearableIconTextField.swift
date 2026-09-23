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

    /// クリアボタンのタップ領域。HIG の最小サイズ（44pt 角）に合わせる。
    /// 同じ値を TextField 右側の余白にも使い、入力文字がタップ領域の下に潜り込まないようにする
    private let clearButtonHitSize: CGFloat = 44.0

    var body: some View {
        HStack {
            icon
                .foregroundStyle(Color.appAccent)
                .frame(width: 24.0, height: 24.0)

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
        }
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
    }
    .padding()
    .background(Color.appBackground)
}
