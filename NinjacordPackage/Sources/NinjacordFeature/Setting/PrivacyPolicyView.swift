//
//  PrivacyPolicyView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/05.
//

import SwiftUI

struct PrivacyPolicyView: View {
    let baseUrl: String = "https://shilokuma-inc.github.io"
    let path: String = "/iOS-Release-Sample/PrivacyPolicy/discord-bot-helper/PrivacyPolicy.html"
    var privacyPolicyUrlString: String {
        baseUrl + path
    }

    var body: some View {
        if let privacyPolicyUrl = URL(string: privacyPolicyUrlString) {
            WebView(url: privacyPolicyUrl)
                .navigationTitle("プライバシーポリシー")
        } else {
            EmptyView()
        }
    }
}
