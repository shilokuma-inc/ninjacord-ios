//
//  Extension+TextFieldStyle.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/29.
//

import SwiftUI

struct CapsuleTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused

    // swiftlint:disable:next identifier_name
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 8.0)
            .padding(.horizontal, 12.0)
            .foregroundStyle(.white)
            .accentColor(.white)
            .background((Color.discordLightGray), in: Capsule())
    }
}

extension TextFieldStyle where Self == CapsuleTextFieldStyle {
    static var capsule: CapsuleTextFieldStyle {
        .init()
    }
}
