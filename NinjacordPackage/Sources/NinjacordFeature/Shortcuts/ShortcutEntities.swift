//
//  ShortcutEntities.swift
//  NinjacordApp
//

import AppIntents

/// ショートカットで選ぶ、保存した宛先（Issue #700）。アプリ内の ID で参照し、Webhook URL（トークンを含む）は持たない。
/// ショートカットは共有できるので、URL を引数・表示に出すとトークンまで渡ってしまうため
struct ShortcutDestinationEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "宛先"
    static var defaultQuery = ShortcutDestinationQuery()

    let id: SavedWebhookURL.ID
    /// 宛先に付けた名前
    let name: String
    /// 名前の下に出す補足。Webhook の名前か、トークンを出さない短い表示（宛先の一覧と同じ）
    let subtitle: String

    @MainActor
    init(_ item: SavedWebhookURL) {
        id = item.id
        name = item.name
        subtitle = DestinationRow.subtitle(for: item)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
}

/// 保存した宛先を、アプリと同じ並び順で出す
struct ShortcutDestinationQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [ShortcutDestinationEntity.ID]) async throws -> [ShortcutDestinationEntity] {
        let items = WebhookURLStore().items
        return identifiers.compactMap { id in
            items.first { $0.id == id }.map(ShortcutDestinationEntity.init)
        }
    }

    @MainActor
    func entities(matching string: String) async throws -> [ShortcutDestinationEntity] {
        WebhookURLStore().items
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(ShortcutDestinationEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [ShortcutDestinationEntity] {
        WebhookURLStore().items.map(ShortcutDestinationEntity.init)
    }
}

/// ショートカットで選ぶテンプレート（Issue #700）。アプリ内の ID で参照し、送るときに最新の中身を読む
struct ShortcutTemplateEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "メッセージのテンプレート"
    static var defaultQuery = ShortcutTemplateQuery()

    let id: MessageTemplate.ID
    /// テンプレートの名前
    let name: String
    /// 名前の下に出す、中身の要約（本文か埋め込みのタイトル）
    let summary: String

    init(_ template: MessageTemplate) {
        id = template.id
        name = template.name
        summary = template.message.summary
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: summary.isEmpty ? nil : "\(summary)")
    }
}

/// テンプレートを、アプリと同じ並び順（ピン留めが先頭）で出す
struct ShortcutTemplateQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [ShortcutTemplateEntity.ID]) async throws -> [ShortcutTemplateEntity] {
        let items = MessageTemplateStore().items
        return identifiers.compactMap { id in
            items.first { $0.id == id }.map(ShortcutTemplateEntity.init)
        }
    }

    @MainActor
    func entities(matching string: String) async throws -> [ShortcutTemplateEntity] {
        MessageTemplateStore().items
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(ShortcutTemplateEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [ShortcutTemplateEntity] {
        MessageTemplateStore().items.map(ShortcutTemplateEntity.init)
    }
}
