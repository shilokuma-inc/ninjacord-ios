//
//  WebView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2026/09/21.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    // 生成時に読み込むため、更新時は何もしない（同じURLの再読み込みを防ぐ）
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
