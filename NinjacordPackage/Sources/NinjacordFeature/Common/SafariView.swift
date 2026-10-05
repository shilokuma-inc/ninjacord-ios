//
//  SafariView.swift
//  NinjacordApp
//

import SafariServices
import SwiftUI

/// アプリ内ブラウザ（SFSafariViewController）。
/// パスワードの自動入力が使えるので、外部サービスにログインして操作するページはこちらで開く
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    // URL は生成時にしか渡せないため、更新時は何もしない
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
