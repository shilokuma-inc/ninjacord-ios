//
//  BroadcastButton.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面の「複数の宛先に送る」ボタン。Pro なら宛先の選択を、Pro でなければペイウォールを開く
struct BroadcastButton: View {
    @Binding var targets: [SavedWebhookURL]

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @ObservedObject private var rewardedUnlock = RewardedUnlockState.shared
    @State private var isPickerPresented = false
    @State private var isPaywallPresented = false

    var body: some View {
        Button {
            if canUseBroadcast {
                isPickerPresented = true
            } else {
                isPaywallPresented = true
            }
        } label: {
            HStack(spacing: 4.0) {
                Label("複数の宛先に送る", systemImage: "paperplane.circle")
                // 一斉送信は Pro 限定（Discussion #260 の決定）
                if !canUseBroadcast {
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6.0)
                        .padding(.vertical, 2.0)
                        .background(Capsule().fill(Color.appAccent))
                        .accessibilityLabel("Pro限定")
                }
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .tint(Color.appAccent)
        .frame(minHeight: 44.0)
        .sheet(isPresented: $isPickerPresented) {
            NavigationStack {
                BroadcastTargetPickerView(selection: $targets)
                    .navigationTitle("一斉送信の宛先")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完了") {
                                isPickerPresented = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $isPaywallPresented) {
            NavigationStack {
                PaywallView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") {
                                isPaywallPresented = false
                            }
                        }
                    }
            }
            .environmentObject(purchaseManager)
        }
    }

    /// リワード広告の一時解放中も一斉送信できる
    private var canUseBroadcast: Bool {
        ProFeatureAccess.canUse(isPro: purchaseManager.isPro)
    }
}
