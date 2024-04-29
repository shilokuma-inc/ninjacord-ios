//
//  Extension+TextFieldStyle.swift
//  discord-bot-helper
//
//  Created by 村石 拓海 on 2024/04/29.
//

import SwiftUI

struct CapsuleTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 8.0)
            .padding(.horizontal, 12.0)
            .background(.gray.opacity(0.3), in: Capsule())
    }
}

extension TextFieldStyle where Self == CapsuleTextFieldStyle {
    static var capsule: CapsuleTextFieldStyle {
        .init()
    }
}
