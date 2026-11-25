//
//  SendDiscordMessageIntent.swift
//  NinjacordApp
//

import AppIntents

/// ショートカットのアクション「Discordに送信」（Issue #700）。保存した宛先に、テンプレートか本文のメッセージを送る。
/// アプリを開かずにバックグラウンドで送り、広告は出さない。オートメーションと組み合わせれば、決まった時刻に送れる。
/// アクションの定義はパッケージに置いてもアプリの `Metadata.appintents` に入るが、`AppShortcutsProvider` は
/// アプリのターゲットに置かないと入らない。そこ（`NinjacordShortcuts`）から参照するため、この型だけ public にする
public struct SendDiscordMessageIntent: AppIntent {
    public static var title: LocalizedStringResource = "Discordに送信"
    public static var description = IntentDescription("保存した宛先に、テンプレートか本文のメッセージを送ります。アプリは開きません")
    public static var openAppWhenRun = false

    @Parameter(title: "宛先", requestValueDialog: "どの宛先に送りますか？")
    var destination: ShortcutDestinationEntity

    @Parameter(title: "使うテンプレート")
    var template: ShortcutTemplateEntity?

    // 入力の設定（inputOptions）は付けない。キーボードの種類の既定が ASCII のみで、
    // システムの既定のキーボード（`.default`）は iOS 16.1 以降のため、日本語を入力しにくくなる
    @Parameter(title: "本文", description: "入れると、テンプレートの本文の代わりに送ります")
    var body: String?

    public static var parameterSummary: some ParameterSummary {
        Summary("\(\.$template)を\(\.$destination)に送信") {
            \.$body
        }
    }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let request = ShortcutMessageSender.Request(
            destinationID: destination.id,
            templateID: template?.id,
            body: body
        )
        switch await ShortcutMessageSender().send(request) {
        case .success(let success):
            return .result(dialog: IntentDialog("\(success.message)"))
        case .failure(let error):
            throw error
        }
    }
}

/// ショートカットのアプリに、原因の分かる文言でエラーを出す。文言はアプリの言語で作ったものをそのまま渡す
extension ShortcutSendError: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        "\(message)"
    }
}
