//
//  WebhookURLSettingView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/01.
//

import SwiftUI

struct WebhookURLSettingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.pink
                .opacity(0.2)
                .ignoresSafeArea(edges: [.top])

            VStack(spacing: 32.0) {
                Text("URL設定")

                Button(action: {
                    dismiss()
                }, label: {
                    Text("設定完了")
                        .font(.system(size: 24, weight: .semibold, design: .default))
                        .foregroundStyle(.gray)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 30.0)
                                .foregroundStyle(.ultraThickMaterial)
                                .shadow(radius: 5.0)
                        )
                })
            }
        }
        .navigationBarHidden(true)
    }
}
