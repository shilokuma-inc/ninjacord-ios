//
//  ComingSoonModifier.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/19.
//

import SwiftUI

struct ComingSoonModifier: ViewModifier {
    func body(content: Content) -> some View {
        HStack(spacing: .zero) {
            content
            Text(" (近日公開)")
        }
    }
}

extension View {
    func addComingSoon() -> some View {
        self.modifier(ComingSoonModifier())
    }
}
