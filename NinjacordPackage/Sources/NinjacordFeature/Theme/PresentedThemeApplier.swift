//
//  PresentedThemeApplier.swift
//  NinjacordApp
//

import SwiftUI
import UIKit

/// 表示中のモーダル（`fullScreenCover` など）の画面そのものにテーマを当てる。
/// 表示中のモーダルは、後からウィンドウの外観（`AppTheme.applyToWindows()`）やルートの `preferredColorScheme` を変えても
/// 配色が切り替わらないため、モーダルの中に置いて表示中の画面の `overrideUserInterfaceStyle` を直接書き換える
struct PresentedThemeApplier: UIViewRepresentable {
    let theme: AppTheme

    func makeUIView(context: Context) -> ApplierView {
        ApplierView()
    }

    func updateUIView(_ uiView: ApplierView, context: Context) {
        uiView.style = theme.userInterfaceStyle
    }

    final class ApplierView: UIView {
        var style: UIUserInterfaceStyle = .unspecified {
            didSet { apply() }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        /// 自分を含む画面のうち、モーダルとして表示されているいちばん外側の View Controller に当てる。
        /// モーダルの中に無いとき（Preview など）は何もしない
        private func apply() {
            guard window != nil else { return }
            var responder: UIResponder? = self
            while let current = responder, !(current is UIViewController) {
                responder = current.next
            }
            guard var controller = responder as? UIViewController else { return }
            while let parent = controller.parent {
                controller = parent
            }
            guard controller.presentingViewController != nil else { return }
            controller.overrideUserInterfaceStyle = style
        }
    }
}
