//
//  Extension+TextFieldStyle.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/29.
//

import SwiftUI

struct CapsuleTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused

    /// 右側の余白。カプセル内にクリアボタン等を重ねる場合に広げる
    var trailingPadding: CGFloat = 12.0

    // swiftlint:disable:next identifier_name
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 8.0)
            .padding(.leading, 12.0)
            .padding(.trailing, trailingPadding)
            .foregroundStyle(Color.appTextPrimary)
            .accentColor(Color.appAccent)
            .background(Color.appSurfaceSecondary, in: Capsule())
    }
}

extension TextFieldStyle where Self == CapsuleTextFieldStyle {
    static var capsule: CapsuleTextFieldStyle {
        .init()
    }

    static func capsule(trailingPadding: CGFloat) -> CapsuleTextFieldStyle {
        .init(trailingPadding: trailingPadding)
    }
}
