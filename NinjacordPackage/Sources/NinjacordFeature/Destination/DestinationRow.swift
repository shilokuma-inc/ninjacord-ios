//
//  DestinationRow.swift
//  NinjacordApp
//

import SwiftUI

/// Webhook のアイコン。無いとき・読み込めないときは既定のアイコン（人の形）を出す
struct WebhookAvatarView: View {
    let url: String?
    var size: CGFloat = 36.0

    @State private var image: UIImage?
    /// 読み込んだ画像の URL。表示し直したときに同じ URL なら読み直さない（既定のアイコンに戻ってちらつかないように）
    @State private var loadedURL: String?

    /// 一覧の行ごとに読むので、入力が止まるのを待つ遅延は入れない
    private static let loader = AvatarImageLoader(delay: .zero)

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(Color.appAccent)
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.45, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
        .task(id: url) {
            guard url != loadedURL else { return }
            image = nil
            loadedURL = nil
            // 撮影モードではデモの URL（読めない値）を読みに行かない
            guard let url, !url.isEmpty, !ScreenshotDemo.isEnabled else { return }
            image = await Self.loader.image(from: url)
            loadedURL = url
        }
    }
}

/// スレッドに送る宛先に付ける印
struct ThreadBadge: View {
    var body: some View {
        Text("スレッド")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.appTextSecondary)
            .padding(.horizontal, 6.0)
            .padding(.vertical, 2.0)
            .background(Capsule().stroke(Color.appTextSecondary, lineWidth: 1.0))
    }
}

/// 保存した宛先の 1 行。URL（トークンを含む）は出さず、アイコン・付けた名前・Webhook の名前で見分ける（Issue #674）
struct DestinationRow: View {
    let item: SavedWebhookURL
    /// 今の宛先として選んでいるか
    var isSelected = false

    var body: some View {
        HStack(spacing: 12.0) {
            WebhookAvatarView(url: item.avatarURL)

            VStack(alignment: .leading, spacing: 2.0) {
                HStack(spacing: 6.0) {
                    Text(item.name)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                    if item.isThread {
                        ThreadBadge()
                    }
                }
                Text(Self.subtitle(for: item))
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
                    .accessibilityLabel("選択中")
            }
        }
        .padding(.vertical, 2.0)
        .accessibilityElement(children: .combine)
    }

    /// 名前の下に出す補足。Webhook の名前を取得できていればそれ、まだならトークンを出さない短い表示
    static func subtitle(for item: SavedWebhookURL) -> String {
        if let webhookName = item.webhookName, !webhookName.isEmpty {
            return String(localized: "Webhook「\(webhookName)」")
        }
        return DiscordWebhookURL(string: item.url)?.maskedDescription
            ?? String(localized: "Webhook URLの形式ではありません")
    }
}
