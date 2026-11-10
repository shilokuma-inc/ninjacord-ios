//
//  DefaultValueConfirmation.swift
//  NinjacordApp
//

import Foundation

/// 「初期値で送る前に確認する」の設定（Discussion #559 の Q4）。保存先は UserDefaults で、未設定ならオン
struct DefaultValueConfirmationSetting {
    /// 設定のキー。設定画面の @AppStorage と共有する
    static let isEnabledKey = "isDefaultValueConfirmationEnabled"

    let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var isEnabled: Bool {
        get { userDefaults.object(forKey: Self.isEnabledKey) as? Bool ?? true }
        nonmutating set { userDefaults.set(newValue, forKey: Self.isEnabledKey) }
    }
}

/// 送信ボタンを押した時点の、送る予定の中身。確認ダイアログを開いたまま入力が変わっても、これを送る
struct PendingSend {
    enum Destination {
        /// URL 欄の宛先
        case single(url: String)
        /// 一斉送信（Pro 限定）の宛先
        case broadcast(urls: [String])
    }

    let destination: Destination
    let messageEntity: MessageEntity
    let attachment: ImageAttachment?

    /// アプリの初期文言に置き換えて送る項目。送る中身と同じ判定（`DiscordWebhookRequest`）を使う
    var defaultedFields: [DiscordWebhookRequest.DefaultedField] {
        DiscordWebhookRequest(messageEntity: messageEntity, attachment: attachment).defaultedFields
    }
}

/// 初期文言で送る前の確認ダイアログの中身（Discussion #559 の Q3）
struct DefaultValueConfirmation {
    let pendingSend: PendingSend
    /// 初期文言に置き換えて送る項目（空ではない）
    let defaultedFields: [DiscordWebhookRequest.DefaultedField]

    /// ダイアログの本文。未入力の項目と、実際に送られる値を並べる。
    /// 名前は空なら送らず Webhook の名前で出るので、確認しない（Discussion #586 の Q7）
    var message: String {
        let lines = defaultedFields.map { field in
            switch field {
            case .content:
                return String(localized: "本文: \(field.value)")
            }
        }
        return ([String(localized: "本文が未入力のため、次の内容で送られます。")] + lines).joined(separator: "\n")
    }
}
