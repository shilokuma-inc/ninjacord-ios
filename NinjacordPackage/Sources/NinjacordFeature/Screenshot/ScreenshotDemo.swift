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
        /// 送信画面（入力済み・画像添付あり・送信者を閉じてプレビューを開き、埋め込みの上端までスクロールした状態）
        case send
        /// 「投稿済み」タブ（送ったメッセージの一覧。先頭は編集済み）
        case posted
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

    /// 各画面より先に、保存済み URL・テンプレート・送信履歴・テーマをデモ用の内容で上書きする。
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

        // 「投稿済み」の一覧は送信履歴から作るので、送信履歴を保存する設定にしてデモの送信を記録する（古い順に記録する）
        userDefaults.set(true, forKey: SendHistoryStore.isEnabledKey)
        let historyStore = SendHistoryStore(userDefaults: userDefaults)
        historyStore.removeAll()
        let today = Calendar.current.startOfDay(for: Date())
        for (index, posted) in content.postedMessages.enumerated().reversed() {
            let messageID = "13000000000000000\(index)"
            // 撮影した時刻によって不自然な時刻（深夜など）にならないよう、日付だけ撮影日からずらして時刻は固定にする
            let day = Calendar.current.date(byAdding: .day, value: -posted.daysAgo, to: today) ?? today
            let sentAt = Calendar.current.date(bySettingHour: posted.hour, minute: posted.minute, second: 0, of: day) ?? day
            historyStore.record(url: posted.url, message: posted.message, isSuccess: true, messageID: messageID, at: sentAt)
            if posted.isEdited {
                historyStore.markEdited(messageID: messageID, message: posted.message, at: sentAt.addingTimeInterval(120))
            }
        }
    }

    /// 一斉送信の画面で選んだ状態にしておく宛先
    @MainActor
    static var broadcastTargets: [SavedWebhookURL] {
        let items = WebhookURLStore().items
        return content.broadcastTargetIndices.compactMap { items.indices.contains($0) ? items[$0] : nil }
    }

    /// 送信画面に添付しておく画像。CC0 の写真を加工したもの（出典は Resources/CREDITS.md）。
    /// 開いたプレビューで縦に場所を取りすぎないよう、横長（16:9）にしてある
    static var attachment: ImageAttachment? {
        guard let data = resourceData("screenshot-attachment") else { return nil }
        return ImageAttachment(data: data, fileName: "image.jpg", mimeType: "image/jpeg")
    }

    /// プレビューに出すデモのプロフィール画像。デモの URL（example.com）を読みに行かないよう、同梱の画像を使う。
    /// CC0 の写真を加工したもの（出典は Resources/CREDITS.md）。丸く切り抜くのはプレビュー側
    static let avatarImage: UIImage = {
        guard let image = resourceData("screenshot-bot-avatar").flatMap(UIImage.init(data:)) else {
            assertionFailure("screenshot-bot-avatar.jpg を読めません")
            return UIImage()
        }
        return image
    }()

    /// 撮影用に同梱した JPEG を読む
    private static func resourceData(_ name: String) -> Data? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "jpg") else { return nil }
        return try? Data(contentsOf: url)
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

    /// 「投稿済み」に出す、送ったメッセージ
    struct PostedMessage {
        let url: String
        let message: MessageEntity
        /// 送った日（撮影日の何日前か）と時刻
        let daysAgo: Int
        let hour: Int
        let minute: Int
        /// アプリから編集したか
        let isEdited: Bool
    }

    let url: String
    let message: MessageEntity
    let savedURLs: [SavedWebhookURL]
    let templates: [Template]
    /// `savedURLs` のうち、一斉送信で選んでおくもの
    let broadcastTargetIndices: [Int]
    /// 「投稿済み」に出す送信（新しい順）。宛先は `savedURLs` の URL にして、保存した名前を出す
    let postedMessages: [PostedMessage]

    private static func dummyURL(_ number: Int) -> String {
        "https://discord.com/api/webhooks/11800000000000000\(number)/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    }

    private static func savedURL(_ number: Int, _ name: String) -> SavedWebhookURL {
        SavedWebhookURL(id: UUID(), name: name, url: dummyURL(number))
    }

    private static func posted(
        _ number: Int,
        username: String = "",
        content: String,
        embedTitle: String = "",
        at time: (daysAgo: Int, hour: Int, minute: Int),
        isEdited: Bool = false
    ) -> PostedMessage {
        PostedMessage(
            url: dummyURL(number),
            message: MessageEntity(
                username: username,
                avatarURL: "",
                content: content,
                messageEmbedEntity: MessageEmbedEntity(title: embedTitle)
            ),
            daysAgo: time.daysAgo,
            hour: time.hour,
            minute: time.minute,
            isEdited: isEdited
        )
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
        broadcastTargetIndices: [0, 1, 2],
        postedMessages: [
            posted(
                11, username: "レイド告知Bot", content: "@everyone 今夜のレイドは21:30開始に変更しました！",
                at: (0, 9, 28), isEdited: true
            ),
            posted(
                12, username: "レイド告知Bot", content: "", embedTitle: "今夜21:00 レイド開始",
                at: (0, 8, 15)
            ),
            posted(
                13, username: "Release Bot", content: "v2.1.0 を本番環境にリリースしました",
                at: (1, 22, 40)
            ),
            posted(
                11, username: "サーバー管理", content: "本日18:00〜19:00はサーバーのメンテナンスを行います",
                at: (1, 17, 5), isEdited: true
            ),
            posted(
                14, content: "晩ごはんは19時です。遅れる人は連絡してね",
                at: (1, 12, 10)
            )
        ]
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
        broadcastTargetIndices: [0, 1, 2],
        postedMessages: [
            posted(
                11, username: "Raid Bot", content: "@everyone Tonight's raid now starts at 9:30 PM!",
                at: (0, 9, 28), isEdited: true
            ),
            posted(
                12, username: "Raid Bot", content: "", embedTitle: "Raid starts tonight at 9 PM",
                at: (0, 8, 15)
            ),
            posted(
                13, username: "Release Bot", content: "v2.1.0 is now live in production",
                at: (1, 22, 40)
            ),
            posted(
                11, username: "Server Admin", content: "Scheduled maintenance today from 6 PM to 7 PM",
                at: (1, 17, 5), isEdited: true
            ),
            posted(
                14, content: "Dinner's at 7. Let us know if you'll be late!",
                at: (1, 12, 10)
            )
        ]
    )
}
