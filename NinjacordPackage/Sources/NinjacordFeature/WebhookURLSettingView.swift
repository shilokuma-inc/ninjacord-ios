//
//  WebhookURLSettingView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/01.
//

import SwiftUI

/// 設定タブから開く、保存した宛先の管理画面（追加・名前の変更・削除・並び替え）
struct WebhookURLSettingView: View {
    var body: some View {
        SavedDestinationListView(mode: .manage)
            .navigationTitle("保存した宛先")
    }
}

#Preview {
    NavigationStack {
        WebhookURLSettingView()
    }
}
