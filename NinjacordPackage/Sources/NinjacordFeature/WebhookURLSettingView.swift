//
//  WebhookURLSettingView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/01.
//

import SwiftUI

/// 設定タブから開く、保存済み Webhook URL の管理画面（閲覧・追加・削除）
struct WebhookURLSettingView: View {
    var body: some View {
        SavedWebhookURLListView(onSelect: nil)
            .navigationTitle("URL設定")
    }
}

#Preview {
    NavigationStack {
        WebhookURLSettingView()
    }
}
