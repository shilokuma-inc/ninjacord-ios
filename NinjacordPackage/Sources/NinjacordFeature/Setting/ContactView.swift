//
//  ContactView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2026/09/21.
//

import SwiftUI

struct ContactView: View {
    let contactUrlString: String = "https://docs.google.com/forms/d/e/"
        + "1FAIpQLSc4DiUAcjKlrchuefXxehD-BgCEhGVomX6NOwtijWiE0yJAlQ/viewform?usp=dialog"

    var body: some View {
        if let contactUrl = URL(string: contactUrlString) {
            WebView(url: contactUrl)
                .navigationTitle("お問い合わせ")
        } else {
            EmptyView()
        }
    }
}
