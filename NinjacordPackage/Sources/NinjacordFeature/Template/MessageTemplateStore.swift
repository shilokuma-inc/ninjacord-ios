//
//  MessageTemplateStore.swift
//  NinjacordApp
//

import Foundation

/// テンプレートの永続化を担うストア（保存先は UserDefaults。WebhookURLStore と同じ方式）。
/// `items` は表示する順番のまま保存し、ピン留めしたものが常に先頭に来るよう保つ
@MainActor
final class MessageTemplateStore: ObservableObject {
    private static let storageKey = "messageTemplates"
    /// 無料で保存できるテンプレートの数（Discussion #258 の決定）。Pro は無制限
    static let freeLimit = 3

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

    /// もう 1 件追加できるか。上限を超えて保存済みの分（Pro を解約した場合など）は消さず、追加だけを止める
    func canAdd(isPro: Bool) -> Bool {
        isPro || items.count < Self.freeLimit
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

    /// ピン留めを切り替える。ピン留めしたものはピン留めの最後に、解除したものはピン留めなしの先頭に移す
    func togglePin(id: MessageTemplate.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var template = items.remove(at: index)
        template.isPinned.toggle()
        let pinnedCount = items.filter(\.isPinned).count
        items.insert(template, at: pinnedCount)
        save()
    }

    /// 並び替える。ピン留めの区切りをまたいで動かした場合も、ピン留めしたものが先頭に来るよう整える
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        items = items.filter(\.isPinned) + items.filter { !$0.isPinned }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
