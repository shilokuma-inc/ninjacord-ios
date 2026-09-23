//
//  PrivacyPolicyView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/05.
//

import SwiftUI

struct PrivacyPolicyView: View {
    private static let baseUrl: String = "https://shilokuma-inc.github.io"
    private static let path: String = "/iOS-Release-Sample/PrivacyPolicy/discord-bot-helper/PrivacyPolicy.html"
    /// プライバシーポリシーの URL。ペイウォールなど他の画面からもリンクするため static にしている
    static var url: URL? {
        URL(string: baseUrl + path)
    }

    var body: some View {
        if let privacyPolicyUrl = Self.url {
            WebView(url: privacyPolicyUrl)
                .navigationTitle("プライバシーポリシー")
        } else {
            EmptyView()
        }
    }
}
