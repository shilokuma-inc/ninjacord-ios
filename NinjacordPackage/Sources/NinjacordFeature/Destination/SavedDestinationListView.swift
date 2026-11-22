//
//  SavedDestinationListView.swift
//  NinjacordApp
//

import SwiftUI

/// 保存した宛先の一覧。URL（トークンを含む）は出さず、アイコン・付けた名前・Webhook の名前で見分ける（Issue #674）。
/// 設定の管理画面（`.manage`）と、送信画面の宛先を選ぶシート（`.select`）で使う
struct SavedDestinationListView: View {
    enum Mode {
        /// 設定から開いたとき。追加・名前の変更・削除・並び替えだけ
        case manage
        /// 送信画面から開いたとき。行を選ぶか、保存していない URL を入れて使う
        /// - currentURL: 今の宛先（選んでいる行にチェックを付ける）
        /// - onSelect: 選んだ宛先の URL
        case select(currentURL: String, onSelect: (String) -> Void)
    }

    let mode: Mode

    @StateObject private var store = WebhookURLStore()
    @StateObject private var adModel = InlineBannerAdModel()
    @State private var isSavePresented = false
    /// 名前を変えている宛先
    @State private var renamingItem: SavedWebhookURL?
    @State private var renameText = ""
    /// 保存していない URL を使う欄の入力
    @State private var directURL = ""

    init(mode: Mode) {
        self.mode = mode
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            List {
                if !store.items.isEmpty {
                    // 広告の行はスワイプでの操作の対象にしないよう、ForEach の外の別 Section に置く
                    Section {
                        InlineBannerAdRow(model: adModel)
                    }
                }

                savedSection

                if case .select = mode {
                    directURLSection
                }
            }
            .loadsInlineBannerAd(adModel, when: !store.items.isEmpty)
            .scrollContentBackground(.hidden)
            .background(.clear)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if case .manage = mode, !store.items.isEmpty {
                    EditButton()
                }
                Button {
                    isSavePresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("宛先を保存")
            }
        }
        .sheet(isPresented: $isSavePresented) {
            SaveDestinationView(initialURL: saveInitialURL) { saved in
                store.reload()
                if case .select(_, let onSelect) = mode {
                    onSelect(saved.url)
                }
            }
            .limitedDynamicTypeSize()
        }
        .alert(
            "名前を変更",
            isPresented: Binding(get: { renamingItem != nil }, set: { if !$0 { renamingItem = nil } }),
            presenting: renamingItem
        ) { item in
            TextField("宛先の名前を入れてください", text: $renameText)
            Button("保存") {
                let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    store.rename(id: item.id, to: name)
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .onAppear {
            store.reload()
            // 今の宛先が保存していない URL なら、その URL を入れておく。保存した宛先なら入れない（URL のトークンを見せない）
            if case .select(let currentURL, _) = mode, directURL.isEmpty, store.item(matching: currentURL) == nil {
                directURL = currentURL.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        .task {
            await refreshProfiles()
        }
    }

    private var savedSection: some View {
        Section {
            if store.items.isEmpty {
                VStack(alignment: .leading, spacing: 8.0) {
                    Text("保存した宛先はありません")
                        .foregroundStyle(Color.appTextPrimary)
                    Text("よく送るWebhook URLを名前を付けて保存すると、次からは名前で選べます")
                        .font(.footnote)
                        .foregroundStyle(Color.appTextSecondary)
                    Button {
                        isSavePresented = true
                    } label: {
                        Label("宛先を保存", systemImage: "plus.circle.fill")
                    }
                    .font(.body.weight(.semibold))
                    .padding(.top, 4.0)
                }
                .padding(.vertical, 4.0)
                .listRowBackground(Color.appSurface)
            } else {
                ForEach(store.items) { item in
                    row(item)
                        .listRowBackground(Color.appSurface)
                }
                .onMove { source, destination in
                    store.move(fromOffsets: source, toOffset: destination)
                }

                // 右上の「＋」だけでは気づきにくいので、一覧のすぐ下にも保存の行を置く（並び替え・スワイプの対象にしないよう ForEach の外）
                Button {
                    isSavePresented = true
                } label: {
                    Label("宛先を保存", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            Text("保存した宛先")
        } footer: {
            if !store.items.isEmpty {
                Text("左にスワイプすると、名前の変更と削除ができます")
            }
        }
    }

    @ViewBuilder
    private func row(_ item: SavedWebhookURL) -> some View {
        Group {
            if case .select(let currentURL, let onSelect) = mode {
                Button {
                    onSelect(item.url)
                } label: {
                    DestinationRow(item: item, isSelected: store.item(matching: currentURL)?.id == item.id)
                }
            } else {
                DestinationRow(item: item)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                store.remove(id: item.id)
            } label: {
                Label("削除", systemImage: "trash")
            }
            Button {
                startRenaming(item)
            } label: {
                Label("名前を変更", systemImage: "pencil")
            }
            .tint(Color.appAccent)
        }
        .contextMenu {
            Button {
                startRenaming(item)
            } label: {
                Label("名前を変更", systemImage: "pencil")
            }
            Button(role: .destructive) {
                store.remove(id: item.id)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    /// 送信画面から開いたときの、保存していない URL を入れて使う欄。長い URL も全体が見えるよう折り返す
    private var directURLSection: some View {
        Section {
            TextField(
                "",
                text: $directURL,
                prompt: Text(verbatim: "https://discord.com/api/webhooks/…").foregroundColor(Color.appPlaceholder),
                axis: .vertical
            )
            .lineLimit(2...4)
            .font(.system(.footnote, design: .monospaced))
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            HStack {
                // 押したときだけクリップボードを読むので、「ペーストを許可」の確認が出ない
                PasteButton(payloadType: String.self) { strings in
                    guard let string = strings.first else { return }
                    // 貼り付けの処理はメインスレッド以外から呼ばれることがある
                    Task { @MainActor in
                        directURL = string.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)

                Spacer()

                Button("このURLを使う") {
                    if case .select(_, let onSelect) = mode {
                        onSelect(directURL.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                .font(.body.weight(.semibold))
                .disabled(directURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            // 行の中の 2 つのボタンを、それぞれ押せるようにする（行全体を 1 つのボタンにしない）
            .buttonStyle(.borderless)
        } header: {
            Text("保存していないURLを使う")
        } footer: {
            Text("Discordで「ウェブフックURLをコピー」したURLを貼り付けます。使ったあとで保存することもできます")
        }
        .listRowBackground(Color.appSurface)
    }

    /// 保存の画面に最初に入れておく URL。送信画面から開いたときは、今使っている保存していない URL
    private var saveInitialURL: String {
        guard case .select(let currentURL, _) = mode, store.item(matching: currentURL) == nil else {
            return ""
        }
        return currentURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func startRenaming(_ item: SavedWebhookURL) {
        renameText = item.name
        renamingItem = item
    }

    /// Webhook の名前とアイコンをまだ覚えていない宛先（2.4.0 までに保存したものなど）について取得して覚える
    private func refreshProfiles() async {
        // 撮影モードではデモの URL（実在しない値）を取得しに行かない
        guard !ScreenshotDemo.isEnabled else { return }
        let client = WebhookProfileClient()
        for item in store.items where item.webhookName == nil {
            guard !Task.isCancelled else { return }
            if case .success(let profile) = await client.fetch(from: item.url) {
                store.updateProfile(id: item.id, profile: profile)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SavedDestinationListView(mode: .manage)
            .navigationTitle("保存した宛先")
    }
}
