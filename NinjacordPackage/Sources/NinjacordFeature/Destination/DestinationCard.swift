//
//  DestinationCard.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面の宛先カードに出す内容。入力された URL・保存した宛先・取得した Webhook から決める（Issue #674）。
/// URL（トークンを含む）は出さず、付けた名前か Webhook の名前で示す
struct DestinationDisplay: Equatable {
    enum State: Equatable {
        /// 宛先をまだ決めていない
        case empty
        /// 保存した宛先
        case saved
        /// 保存していない Webhook URL
        case unsaved
        /// Webhook URL の形ではない
        case invalid
    }

    let state: State
    let title: String
    let subtitle: String?
    let avatarURL: String?
    let isThread: Bool

    /// - Parameters:
    ///   - url: 送信画面の宛先（URL）
    ///   - saved: 同じ宛先の保存済みのもの
    ///   - profile: 送信画面で取得した、その URL の Webhook。まだなら nil
    static func resolve(url: String, saved: SavedWebhookURL?, profile: WebhookProfile?) -> DestinationDisplay {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return DestinationDisplay(
                state: .empty,
                title: String(localized: "宛先を選んでください"),
                subtitle: String(localized: "保存した宛先から選ぶか、Webhook URLを貼り付けます"),
                avatarURL: nil,
                isThread: false
            )
        }
        let webhookURL = DiscordWebhookURL(string: trimmed)
        let webhookName = saved?.webhookName ?? profile?.name
        if let saved {
            return DestinationDisplay(
                state: .saved,
                title: saved.name,
                subtitle: webhookName.flatMap { $0.isEmpty ? nil : String(localized: "Webhook「\($0)」") }
                    ?? webhookURL?.maskedDescription,
                avatarURL: saved.avatarURL ?? profile?.avatarURL?.absoluteString,
                isThread: saved.isThread
            )
        }
        guard let webhookURL else {
            return DestinationDisplay(
                state: .invalid,
                title: String(localized: "保存していない宛先"),
                subtitle: String(localized: "Webhook URLの形式ではありません"),
                avatarURL: nil,
                isThread: false
            )
        }
        let name = profile.flatMap { $0.name.isEmpty ? nil : $0.name }
        return DestinationDisplay(
            state: .unsaved,
            title: name ?? String(localized: "保存していない宛先"),
            subtitle: webhookURL.maskedDescription,
            avatarURL: profile?.avatarURL?.absoluteString,
            isThread: webhookURL.threadID != nil
        )
    }
}

/// 送信画面の宛先。URL の入力欄の代わりに、付けた名前と Webhook のアイコンで今の宛先を示す（Issue #674）。
/// タップで宛先を選ぶシートを開く。保存していない URL を使っているときは、保存のボタンを出す。
/// URL の取得方法は、送信画面の「宛先」の見出しの右に置く（`WebhookURLHelpButton`）
struct DestinationCard: View {
    @Binding var url: String
    /// 送信画面で取得した、今の宛先の Webhook。まだなら nil
    let profile: WebhookProfile?

    @StateObject private var store = WebhookURLStore()
    @State private var isPickerPresented = ScreenshotDemo.scene == .savedURLs
    @State private var isSavePresented = false

    private var display: DestinationDisplay {
        DestinationDisplay.resolve(url: url, saved: store.item(matching: url), profile: profile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            Button {
                isPickerPresented = true
            } label: {
                cardContent
            }
            .buttonStyle(.plain)
            .accessibilityHint("宛先を選ぶ画面を開きます")

            if display.state == .unsaved {
                Button {
                    isSavePresented = true
                } label: {
                    Label("この宛先を保存", systemImage: "bookmark")
                }
                // 送信画面のほかの補助ボタン（複数の宛先に送る・埋め込みを編集）とそろえる
                .font(.system(size: 15, weight: .semibold))
                .tint(Color.appAccent)
                .frame(minHeight: 44.0)
                .padding(.leading, 44.0)
            }
        }
        .sheet(isPresented: $isPickerPresented, onDismiss: store.reload) {
            NavigationStack {
                SavedDestinationListView(mode: .select(currentURL: url) { selectedURL in
                    url = selectedURL
                    isPickerPresented = false
                })
                .navigationTitle("宛先を選ぶ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            isPickerPresented = false
                        }
                    }
                }
            }
            .limitedDynamicTypeSize()
        }
        .sheet(isPresented: $isSavePresented, onDismiss: store.reload) {
            SaveDestinationView(initialURL: url)
                .limitedDynamicTypeSize()
        }
        .onAppear {
            store.reload()
        }
        .onChange(of: profile) { newProfile in
            // 保存した宛先なら、取得し直した Webhook の名前・アイコンを覚えておく（変わっていなければ何もしない）
            guard let newProfile, let item = store.item(matching: url) else { return }
            store.updateProfile(id: item.id, profile: newProfile)
        }
    }

    private var cardContent: some View {
        HStack(spacing: 12.0) {
            if display.state == .empty {
                MessagePartIcon(part: .destination)
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 40.0, height: 40.0)
            } else {
                WebhookAvatarView(url: display.avatarURL, size: 40.0)
            }

            VStack(alignment: .leading, spacing: 2.0) {
                HStack(spacing: 6.0) {
                    Text(display.title)
                        .foregroundStyle(display.state == .empty ? Color.appPlaceholder : Color.appTextPrimary)
                        .lineLimit(1)
                    if display.isThread {
                        ThreadBadge()
                    }
                }
                if let subtitle = display.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(display.state == .invalid ? Color.red : Color.appTextSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(.horizontal, 12.0)
        .padding(.vertical, 10.0)
        // 送信画面の入力欄（CapsuleTextFieldStyle）と同じ色にする。2 行になるので角丸の四角形にする
        .background(Color.appSurfaceSecondary, in: RoundedRectangle(cornerRadius: 16.0, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16.0, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("宛先") + Text(verbatim: ", ") + Text(display.title))
    }
}
