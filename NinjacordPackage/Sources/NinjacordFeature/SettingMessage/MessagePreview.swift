//
//  MessagePreview.swift
//  NinjacordApp
//

import SwiftUI

/// 送るメッセージが Discord 上でどう見えるかの簡易プレビュー。
/// アイコン・名前・本文・埋め込み・添付画像を並べる。`EmbedPreview` と同じく Discussion #259 の方針で完全には再現せず、
/// アプリのテーマに関係なく Discord のダークテーマ風の配色で描く
struct MessagePreview: View {
    let username: String
    let avatarURL: String
    let content: String
    let embed: MessageEmbedEntity
    let attachment: ImageAttachment?
    /// Discord 側で Webhook に設定されているアイコン。プロフィール画像の URL が空のときに代わりに出す。未取得なら nil
    var webhookProfile: WebhookProfile?
    var avatarLoader = AvatarImageLoader()

    /// `displayAvatarURL` から読み込んだプロフィール画像。無ければ既定のアイコンを出す
    @State private var avatarImage: Image?
    @State private var attachmentThumbnail: AttachmentThumbnail?
    @Environment(\.displayScale) private var displayScale

    private static let avatarSize: CGFloat = 40.0
    /// 添付画像を表示する最大の幅・高さ
    private static let attachmentMaxSize: CGFloat = 280.0

    /// 縮小した添付画像と、その表示サイズ（元より大きくは表示しない）
    private struct AttachmentThumbnail {
        let image: Image
        let size: CGSize
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12.0) {
            avatar

            VStack(alignment: .leading, spacing: 4.0) {
                header
                // Discord 上では本文が空でも何かしらの本文が送られるので、本文の場所は常に示す
                Text(content.isEmpty ? String(localized: "メッセージの本文") : content)
                    .font(.system(size: 16))
                    .foregroundStyle(content.isEmpty ? DiscordPalette.placeholder : DiscordPalette.text)
                if embed.hasContent {
                    EmbedPreview(embed: embed)
                        .padding(.top, 4.0)
                }
                if let attachmentThumbnail {
                    attachmentThumbnail.image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: attachmentThumbnail.size.width, maxHeight: attachmentThumbnail.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 8.0))
                        .padding(.top, 4.0)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12.0)
        .background(DiscordPalette.messageBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        .task(id: displayAvatarURL) {
            let image = await avatarLoader.image(from: displayAvatarURL)
            // 読み込み中に URL が変わったら、古い URL の画像は出さない
            guard !Task.isCancelled else {
                return
            }
            avatarImage = image.map { Image(uiImage: $0) }
        }
        .task(id: attachment) {
            attachmentThumbnail = makeAttachmentThumbnail()
        }
    }

    private var displayName: String {
        MessagePreviewProfile.displayName(username: username)
    }

    private var displayAvatarURL: String {
        MessagePreviewProfile.displayAvatarURL(avatarURL: avatarURL, webhookProfile: webhookProfile)
    }

    private var avatar: some View {
        Group {
            if let avatarImage {
                avatarImage
                    .resizable()
                    .scaledToFill()
            } else {
                // Discord の既定のアバター風
                ZStack {
                    DiscordPalette.blurple
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    /// 名前と、Webhook から送ったメッセージに付くバッジ
    private var header: some View {
        HStack(spacing: 6.0) {
            // 名前が空のときに送る決まった名前も Discord 上では入力した名前と同じ見え方なので、色は分けない
            Text(displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DiscordPalette.title)
                .lineLimit(1)
            Text("アプリ")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4.0)
                .padding(.vertical, 1.0)
                .background(DiscordPalette.blurple)
                .clipShape(RoundedRectangle(cornerRadius: 3.0))
        }
    }

    private func makeAttachmentThumbnail() -> AttachmentThumbnail? {
        let maxPixelSize = Int(Self.attachmentMaxSize * displayScale)
        guard let cgImage = attachment?.thumbnail(maxPixelSize: maxPixelSize) else {
            return nil
        }
        let size = CGSize(
            width: CGFloat(cgImage.width) / displayScale,
            height: CGFloat(cgImage.height) / displayScale
        )
        return AttachmentThumbnail(image: Image(decorative: cgImage, scale: displayScale), size: size)
    }
}

extension DiscordPalette {
    /// メッセージ一覧の背景
    static let messageBackground = Color(red: 0x31 / 255, green: 0x33 / 255, blue: 0x38 / 255)
    /// 未入力の項目に出す仮の文言
    static let placeholder = Color(red: 0x94 / 255, green: 0x9B / 255, blue: 0xA4 / 255)
    /// 既定のアバター・バッジの色
    static let blurple = Color(red: 0x58 / 255, green: 0x65 / 255, blue: 0xF2 / 255)
}

private extension ImageAttachment {
    /// プレビュー用の単色の画像
    static func previewSample(width: CGFloat, height: CGFloat) -> ImageAttachment {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let data = renderer.pngData { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return ImageAttachment(data: data, fileName: "image.png", mimeType: "image/png")
    }
}

#Preview("すべて入力") {
    MessagePreview(
        username: "レイド告知Bot",
        avatarURL: "https://cdn.discordapp.com/embed/avatars/0.png",
        content: "今夜21:00 レイド開始！",
        embed: MessageEmbedEntity(
            title: "お知らせ",
            description: "本日18時からメンテナンスです",
            color: 0x5865F2,
            fields: [
                MessageEmbedField(name: "開始", value: "18:00", isInline: true),
                MessageEmbedField(name: "終了", value: "19:00", isInline: true)
            ],
            footerText: "Ninja Cord"
        ),
        attachment: .previewSample(width: 1200, height: 800)
    )
    .padding()
}

#Preview("未入力") {
    MessagePreview(username: "", avatarURL: "", content: "", embed: MessageEmbedEntity(), attachment: nil)
        .padding()
}

#Preview("Webhook のアイコン") {
    MessagePreview(
        username: "",
        avatarURL: "",
        content: "今夜21:00 レイド開始！",
        embed: MessageEmbedEntity(),
        attachment: nil,
        webhookProfile: WebhookProfile(
            name: "Captain Hook",
            avatarURL: URL(string: "https://cdn.discordapp.com/embed/avatars/0.png")
        )
    )
    .padding()
}

#Preview("http の URL・縦長の画像") {
    MessagePreview(
        username: "とても長い名前のWebhookからのお知らせを送るためのボット",
        avatarURL: "http://example.com/avatar.png",
        content: "長い本文です。Discord では本文が折り返して表示されます。プレビューでも同じように折り返します。",
        embed: MessageEmbedEntity(),
        attachment: .previewSample(width: 300, height: 900)
    )
    .padding()
}
