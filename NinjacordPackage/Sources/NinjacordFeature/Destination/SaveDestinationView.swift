//
//  SaveDestinationView.swift
//  NinjacordApp
//

import SwiftUI

/// 宛先を保存する画面。貼り付けた Webhook URL をその場で確かめ、Webhook のアイコンと名前を見せる（Issue #674）
struct SaveDestinationView: View {
    /// 保存したとき（呼び出し元で、保存した宛先を選んだ状態にするなど）
    let onSaved: (SavedWebhookURL) -> Void

    @StateObject private var model: SaveDestinationModel
    @Environment(\.dismiss) private var dismiss

    /// - Parameter initialURL: 最初に入れておく URL（送信画面で使っている、保存していない URL など）
    init(initialURL: String = "", onSaved: @escaping (SavedWebhookURL) -> Void = { _ in }) {
        self.onSaved = onSaved
        _model = StateObject(wrappedValue: SaveDestinationModel(initialURL: initialURL, store: WebhookURLStore()))
    }

    var body: some View {
        NavigationStack {
            Form {
                urlSection

                if case .valid(let profile) = model.check {
                    Section {
                        preview(profile)
                    } header: {
                        Text("送り先")
                    }
                    .listRowBackground(Color.appSurface)
                }

                Section {
                    TextField(
                        "",
                        text: Binding(get: { model.name }, set: { model.setName($0) }),
                        prompt: Text("宛先の名前を入れてください").foregroundColor(Color.appPlaceholder)
                    )
                } header: {
                    Text("名前")
                } footer: {
                    Text("一覧に出す名前です。例: ゲーム部 #お知らせ")
                }
                .listRowBackground(Color.appSurface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("宛先を保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let saved = model.save() {
                            onSaved(saved)
                            dismiss()
                        }
                    }
                    .disabled(!model.canSave)
                }
            }
            .task(id: model.url) {
                await model.checkURL()
            }
        }
        .tint(Color.appAccent)
    }

    private var urlSection: some View {
        Section {
            // 長い URL も全体が見えるよう、折り返して表示する
            TextField(
                "",
                text: $model.url,
                prompt: Text(verbatim: "https://discord.com/api/webhooks/…").foregroundColor(Color.appPlaceholder),
                axis: .vertical
            )
            .lineLimit(2...5)
            .font(.system(.footnote, design: .monospaced))
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            // 押したときだけクリップボードを読むので、「ペーストを許可」の確認が出ない
            PasteButton(payloadType: String.self) { strings in
                guard let string = strings.first else { return }
                // 貼り付けの処理はメインスレッド以外から呼ばれることがある
                Task { @MainActor in
                    model.url = string.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
        } header: {
            Text(verbatim: "Webhook URL")
        } footer: {
            status
        }
        .listRowBackground(Color.appSurface)
    }

    /// 入力された URL を確かめた結果。二重に保存しようとしているときは、それを先に出す
    @ViewBuilder
    private var status: some View {
        if let duplicate = model.duplicate {
            Label("「\(duplicate.name)」として保存済みです", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        } else {
            switch model.check {
            case .empty:
                Text("DiscordでコピーしたWebhook URLを貼り付けてください")
            case .invalidFormat:
                Label("Webhook URLの形式ではありません", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            case .checking:
                HStack(spacing: 6.0) {
                    ProgressView()
                    Text("Webhookを確認しています…")
                }
            case .valid:
                Label("Webhookを確認できました", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .notFound:
                Label(
                    "Webhookが見つかりません。Discordで削除されていないか確認してください",
                    systemImage: "exclamationmark.circle.fill"
                )
                .foregroundStyle(.red)
            case .invalidToken:
                Label(
                    "Webhook URLが正しくありません。Discordでコピーし直してください",
                    systemImage: "exclamationmark.circle.fill"
                )
                .foregroundStyle(.red)
            case .unreachable:
                Label(
                    "通信できず、Webhookを確認できませんでした。このまま保存することもできます",
                    systemImage: "wifi.exclamationmark"
                )
                .foregroundStyle(.orange)
            }
        }
    }

    /// 確かめられた Webhook。Discord に出るアイコンと名前、スレッドに送るかを見せる
    private func preview(_ profile: WebhookProfile) -> some View {
        HStack(spacing: 12.0) {
            WebhookAvatarView(url: profile.avatarURL?.absoluteString, size: 40.0)
            VStack(alignment: .leading, spacing: 2.0) {
                HStack(spacing: 6.0) {
                    Text(profile.name.isEmpty ? String(localized: "名前のないWebhook") : profile.name)
                        .foregroundStyle(Color.appTextPrimary)
                    if WebhookDestinationKey(urlString: model.trimmedURL)?.threadID != nil {
                        ThreadBadge()
                    }
                }
                if let masked = DiscordWebhookURL(string: model.trimmedURL)?.maskedDescription {
                    Text(verbatim: masked)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SaveDestinationView(initialURL: "https://discord.com/api/webhooks/123/abc")
}
