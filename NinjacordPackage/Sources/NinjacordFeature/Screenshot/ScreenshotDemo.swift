//
//  ScreenshotDemo.swift
//  NinjacordApp
//

import UIKit

/// App Store 用スクリーンショットの撮影モード（Discussion #355）。
/// 起動引数 `-screenshot-demo` で有効になり、`-screenshot-scene <名前>` で最初に開く画面を選ぶ。
/// 撮影は `Tools/capture_screenshots.sh` が言語・画面ごとにアプリを起動し直して行う
enum ScreenshotDemo {
    /// 撮影する画面。並び順は `AppStore/screenshots.json` で決める
    enum Scene: String {
        /// 送信画面（入力済み・画像添付あり）
        case send
        /// 埋め込みエディタのライブプレビュー
        case embed
        /// 保存済み URL の選択シート
        case savedURLs = "saved-urls"
        /// テンプレート一覧
        case templates
        /// 一斉送信の宛先選択
        case broadcast
        /// Webhook URL の取得方法
        case webhookHelp = "webhook-help"
    }

    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-screenshot-demo")

    /// 起動引数は UserDefaults の引数ドメインに入るので、`-screenshot-scene embed` をここで読める
    static let scene: Scene? = isEnabled
        ? UserDefaults.standard.string(forKey: "screenshot-scene").flatMap(Scene.init(rawValue:))
        : nil

    @MainActor
    private static var hasPrepared = false

    /// 各画面より先に、保存済み URL・テンプレート・テーマをデモ用の内容で上書きする。
    /// 撮影専用の Simulator で使う前提なので、手元のデータは残さない。
    /// テーマの書き込みで App の body が評価し直され MainView.init が再び呼ばれても、
    /// 作り直したデータと各画面が持つ ID がずれないよう、起動ごとに 1 回だけ行う
    @MainActor
    static func prepare() {
        guard isEnabled, !hasPrepared else { return }
        hasPrepared = true
        let userDefaults = UserDefaults.standard
        userDefaults.set(AppTheme.dark.rawValue, forKey: AppTheme.userDefaultsKey)

        let urlStore = WebhookURLStore(userDefaults: userDefaults)
        urlStore.remove(at: IndexSet(urlStore.items.indices))
        for item in content.savedURLs {
            urlStore.add(name: item.name, url: item.url)
        }

        let templateStore = MessageTemplateStore(userDefaults: userDefaults)
        templateStore.remove(at: IndexSet(templateStore.items.indices))
        for template in content.templates {
            let added = templateStore.add(name: template.name, message: template.message)
            if template.isPinned {
                templateStore.togglePin(id: added.id)
            }
        }
    }

    /// 一斉送信の画面で選んだ状態にしておく宛先
    @MainActor
    static var broadcastTargets: [SavedWebhookURL] {
        let items = WebhookURLStore().items
        return content.broadcastTargetIndices.compactMap { items.indices.contains($0) ? items[$0] : nil }
    }

    /// 送信画面に添付しておく画像。実在の写真を写さないよう、その場で描く
    static var attachment: ImageAttachment? {
        let size = CGSize(width: 640, height: 640)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [
                UIColor(red: 0x58 / 255, green: 0x65 / 255, blue: 0xF2 / 255, alpha: 1).cgColor,
                UIColor(red: 0xEB / 255, green: 0x45 / 255, blue: 0x9F / 255, alpha: 1).cgColor
            ]
            if let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            let configuration = UIImage.SymbolConfiguration(pointSize: 280, weight: .bold)
            if let symbol = UIImage(systemName: "gamecontroller.fill", withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                symbol.draw(at: CGPoint(
                    x: (size.width - symbol.size.width) / 2,
                    y: (size.height - symbol.size.height) / 2
                ))
            }
        }
        guard let data = image.pngData() else { return nil }
        return ImageAttachment(data: data, fileName: "image.png", mimeType: "image/png")
    }

    /// 撮影する言語のデモ内容。`-AppleLanguages` で切り替えた言語に合わせる
    static var content: ScreenshotDemoContent {
        let language = Locale.preferredLanguages.first ?? "en"
        return language.hasPrefix("ja") ? .japanese : .english
    }
}

/// スクリーンショットに写すデモの内容。
/// 利用シーンが想像できる例にし、Webhook URL は実在しない値にする（トークンを写さないため）
struct ScreenshotDemoContent {
    struct Template {
        let name: String
        let message: MessageEntity
        let isPinned: Bool
    }

    let url: String
    let message: MessageEntity
    let savedURLs: [SavedWebhookURL]
    let templates: [Template]
    /// `savedURLs` のうち、一斉送信で選んでおくもの
    let broadcastTargetIndices: [Int]

    private static func dummyURL(_ number: Int) -> String {
        "https://discord.com/api/webhooks/11800000000000000\(number)/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    }

    private static func savedURL(_ number: Int, _ name: String) -> SavedWebhookURL {
        SavedWebhookURL(id: UUID(), name: name, url: dummyURL(number))
    }

    static let japanese = ScreenshotDemoContent(
        url: dummyURL(11),
        message: MessageEntity(
            username: "レイド告知Bot",
            avatarURL: "https://example.com/raid-bot.png",
            content: "@everyone 今夜のレイド、参加者募集中です！",
            messageEmbedEntity: MessageEmbedEntity(
                title: "今夜21:00 レイド開始",
                description: "初参加も大歓迎です。開始10分前にはボイスチャンネルに集まってください。",
                color: 0x57F287,
                fields: [
                    MessageEmbedField(name: "集合", value: "20:50", isInline: true),
                    MessageEmbedField(name: "場所", value: "#作戦室", isInline: true),
                    MessageEmbedField(name: "募集", value: "残り3枠", isInline: true),
                    MessageEmbedField(name: "持ち物", value: "回復薬を多めに / 耐火装備推奨", isInline: false)
                ],
                footerText: "ゲーム部 運営チーム",
                includesTimestamp: true
            )
        ),
        savedURLs: [
            savedURL(11, "ゲーム部 #お知らせ"),
            savedURL(12, "ゲーム部 #レイド募集"),
            savedURL(13, "開発チーム #デプロイ通知"),
            savedURL(14, "家族 #連絡")
        ],
        templates: [
            Template(
                name: "レイド告知",
                message: MessageEntity(
                    username: "レイド告知Bot",
                    avatarURL: "",
                    content: "@everyone 今夜のレイド、参加者募集中です！",
                    messageEmbedEntity: MessageEmbedEntity()
                ),
                isPinned: true
            ),
            Template(
                name: "メンテナンスのお知らせ",
                message: MessageEntity(
                    username: "サーバー管理",
                    avatarURL: "",
                    content: "本日18:00〜19:00はサーバーのメンテナンスを行います",
                    messageEmbedEntity: MessageEmbedEntity()
                ),
                isPinned: true
            ),
            Template(
                name: "デプロイ完了",
                message: MessageEntity(
                    username: "Release Bot",
                    avatarURL: "",
                    content: "v2.1.0 を本番環境にリリースしました",
                    messageEmbedEntity: MessageEmbedEntity()
                ),
                isPinned: false
            ),
            Template(
                name: "週末の予定",
                message: MessageEntity(
                    username: "",
                    avatarURL: "",
                    content: "土曜の夜はみんなで対戦会をやります！",
                    messageEmbedEntity: MessageEmbedEntity()
                ),
                isPinned: false
            )
        ],
        broadcastTargetIndices: [0, 1, 2]
    )

    static let english = ScreenshotDemoContent(
        url: dummyURL(11),
        message: MessageEntity(
            username: "Raid Bot",
            avatarURL: "https://example.com/raid-bot.png",
            content: "@everyone Sign-ups for tonight's raid are open!",
            messageEmbedEntity: MessageEmbedEntity(
                title: "Raid starts tonight at 9 PM",
                description: "First-timers welcome. Please join the voice channel 10 minutes early.",
                color: 0x57F287,
                fields: [
                    MessageEmbedField(name: "Meet-up", value: "8:50 PM", isInline: true),
                    MessageEmbedField(name: "Where", value: "#war-room", isInline: true),
                    MessageEmbedField(name: "Slots", value: "3 left", isInline: true),
                    MessageEmbedField(name: "Bring", value: "Extra potions / fire-resistant gear", isInline: false)
                ],
                footerText: "Gaming Club Staff",
                includesTimestamp: true
            )
        ),
        savedURLs: [
            savedURL(11, "Gaming Club #announcements"),
            savedURL(12, "Gaming Club #raids"),
            savedURL(13, "Dev Team #deploys"),
            savedURL(14, "Family #general")
        ],
        templates: [
            Template(
                name: "Raid call",
                message: MessageEntity(
                    username: "Raid Bot",
                    avatarURL: "",
                    content: "@everyone Sign-ups for tonight's raid are open!",
                    messageEmbedEntity: MessageEmbedEntity()
                ),
                isPinned: true
            ),
            Template(
                name: "Maintenance notice",
                message: MessageEntity(
                    username: "Server Admin",
                    avatarURL: "",
                    content: "Scheduled maintenance today from 6 PM to 7 PM",
                    messageEmbedEntity: MessageEmbedEntity()
                ),
                isPinned: true
            ),
            Template(
                name: "Deploy finished",
                message: MessageEntity(
                    username: "Release Bot",
                    avatarURL: "",
                    content: "v2.1.0 is now live in production",
                    messageEmbedEntity: MessageEmbedEntity()
                ),
                isPinned: false
            ),
            Template(
                name: "Weekend plans",
                message: MessageEntity(
                    username: "",
                    avatarURL: "",
                    content: "Game night this Saturday — everyone's invited!",
                    messageEmbedEntity: MessageEmbedEntity()
                ),
                isPinned: false
            )
        ],
        broadcastTargetIndices: [0, 1, 2]
    )
}
