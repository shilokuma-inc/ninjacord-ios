//
//  Extension+View.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/06.
//

import SwiftUI

extension View {
    @ViewBuilder func onChange<V: Equatable>(
        of value: V,
        initial: Bool,
        perform action: @escaping (_ newValue: V) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            onChange(of: value, initial: initial) {
                action($1)
            }
        } else if initial {
            onAppear { action(value) }
                .onChange(of: value, perform: action)
        } else {
            onChange(of: value, perform: action)
        }
    }
}

extension View {
    /// 文字サイズ（Dynamic Type）を通常サイズの上限（xxxLarge）までに抑える。
    /// 送信画面などスクロールしない固定レイアウトの画面が、アクセシビリティ用の文字サイズで崩れるのを防ぐ。
    /// シートや全画面表示は別の階層になり上限が引き継がれないため、その中身にも付ける
    func limitedDynamicTypeSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
