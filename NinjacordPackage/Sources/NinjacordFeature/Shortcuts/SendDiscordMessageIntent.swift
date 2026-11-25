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

    @Parameter(title: "使うテンプレート", description: "無料プランでは、テンプレートの一覧の先頭の1件だけ使えます")
    var template: ShortcutTemplateEntity?

    // 入力の設定（inputOptions）は付けない。キーボードの種類の既定が ASCII のみで、
    // システムの既定のキーボード（`.default`）は iOS 16.1 以降のため、日本語を入力しにくくなる
    @Parameter(title: "本文", description: "入れると、テンプレートの本文の代わりに送ります")
    var body: String?

    @Parameter(
        title: "投稿のタイトル",
        description: "フォーラム・メディアチャンネルの宛先に送るときに使います。入れると、テンプレートのタイトルの代わりに使います"
    )
    var threadName: String?

    public static var parameterSummary: some ParameterSummary {
        Summary("\(\.$template)を\(\.$destination)に送信") {
            \.$body
            \.$threadName
        }
    }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let request = ShortcutMessageSender.Request(
            destinationID: destination.id,
            templateID: template?.id,
            body: body,
            threadName: threadName
        )
        let isPro = await Self.isPro()
        switch await ShortcutMessageSender().send(request, isPro: isPro) {
        case .success(let success):
            return .result(dialog: IntentDialog("\(success.message)"))
        case .failure(let error):
            throw error
        }
    }

    /// Pro を購読中か。アプリを開かずに動き、前回アプリを開いたあとに購読が切れた・別の端末で購入したこともあるので、
    /// 保存しておいた前回の値ではなく、端末にある App Store の購入情報（`Transaction.currentEntitlements`）から集計し直す
    @MainActor
    private static func isPro() async -> Bool {
        await PurchaseManager.shared.refreshPurchasedProducts()
        return PurchaseManager.shared.isPro
    }
}

/// ショートカットのアプリに、原因の分かる文言でエラーを出す。文言はアプリの言語で作ったものをそのまま渡す
extension ShortcutSendError: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        "\(message)"
    }
}
