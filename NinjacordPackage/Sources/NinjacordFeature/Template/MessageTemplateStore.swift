//
//  MessageTemplateStore.swift
//  NinjacordApp
//

import Foundation

/// テンプレートの永続化を担うストア（保存先は UserDefaults。WebhookURLStore と同じ方式）
@MainActor
final class MessageTemplateStore: ObservableObject {
    private static let storageKey = "messageTemplates"

    @Published private(set) var items: [MessageTemplate] = []

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        reload()
    }

    /// UserDefaults から一覧を再読込する（別画面で追加・削除された内容を反映するため）
    func reload() {
        guard let data = userDefaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([MessageTemplate].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    @discardableResult
    func add(name: String, message: MessageEntity) -> MessageTemplate {
        let template = MessageTemplate(id: UUID(), name: name, message: message, createdAt: Date())
        items.append(template)
        save()
        return template
    }

    /// 同じ ID のテンプレートを置き換える。見つからなければ何もしない
    func update(_ template: MessageTemplate) {
        guard let index = items.firstIndex(where: { $0.id == template.id }) else { return }
        items[index] = template
        save()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    func remove(id: MessageTemplate.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
