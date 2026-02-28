//
//  ClearableIconTextField.swift
//  NinjacordApp
//

import SwiftUI

struct ClearableIconTextField: View {
    let systemIconName: String
    let placeholder: LocalizedStringResource
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: systemIconName)
                .foregroundStyle(Color.discordPurple)
                .frame(width: 24.0, height: 24.0)

            TextField(
                "",
                text: $text,
                prompt: Text(String(localized: placeholder))
                    .foregroundColor(Color.discordSuperLightGray)
            )
            .textFieldStyle(.capsule)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}
