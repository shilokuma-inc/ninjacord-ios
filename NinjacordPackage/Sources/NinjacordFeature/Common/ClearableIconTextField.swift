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

    /// クリアボタン分だけ TextField 右側の余白を広げ、入力文字がボタンの下に隠れないようにする
    private let clearButtonSize: CGFloat = 20.0
    private let clearButtonTrailingPadding: CGFloat = 12.0

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
            .textFieldStyle(.capsule(trailingPadding: clearButtonTrailingPadding + clearButtonSize + 4.0))
            .overlay(alignment: .trailing) {
                if !text.isEmpty {
                    clearButton
                        .padding(.trailing, clearButtonTrailingPadding)
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
                .frame(width: clearButtonSize, height: clearButtonSize)
        }
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
