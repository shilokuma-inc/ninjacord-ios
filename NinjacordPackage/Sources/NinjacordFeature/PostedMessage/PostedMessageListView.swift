//
//  PostedMessageListView.swift
//  NinjacordApp
//

import SwiftUI

/// 「投稿済み」タブ。この端末から送ったメッセージを新しい順に並べ、削除（無料）・編集（Pro）する（Issue #666）。
/// 一覧の元は送信履歴（履歴とは別には保存しない）なので、送信履歴を保存する設定が OFF のときは、ON にすると使えることを案内する
struct PostedMessageListView: View {
    @AppStorage(SendHistoryStore.isEnabledKey) private var isHistoryEnabled = false
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @StateObject private var viewModel = PostedMessageListViewModel()
    @StateObject private var adModel = InlineBannerAdModel()
    /// 宛先に、保存した Webhook URL の名前を出すため
    @StateObject private var urlStore = WebhookURLStore()
    @ObservedObject private var rewardedAdManager = RewardedAdManager.shared
    /// リワード広告での一時解放や、それを使い切ったときに描き直すために監視する
    @ObservedObject private var rewardedUnlock = RewardedUnlockState.shared
    /// 削除の確認ダイアログを出しているメッセージ
    @State private var deletingEntry: SendHistoryEntry?
    /// 編集画面を開いているメッセージ
    @State private var editingEntry: SendHistoryEntry?
    /// Pro でない人が編集しようとしたときの案内（Pro にするか広告を見るか）を出しているメッセージ
    @State private var upsellEntry: SendHistoryEntry?
    @State private var isPaywallPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("投稿済み")
        }
        // iOS 26 のアラートはボタン文字に周囲の tint を使う。画面には AppAccent を付け直し、アラートだけシステム標準の青にする
        .tint(Color.appAccent)
        .confirmationDialog(
            "このメッセージを削除しますか？",
            isPresented: Binding(
                get: { deletingEntry != nil },
                set: { if !$0 { deletingEntry = nil } }
            ),
            titleVisibility: .visible,
            presenting: deletingEntry
        ) { entry in
            Button("削除", role: .destructive) {
                viewModel.delete(entry)
            }
        } message: { _ in
            Text("Discordのチャンネルからも削除されます。元に戻せません")
        }
        .alert(
            "メッセージの編集はNinjacord Pro限定です",
            isPresented: Binding(
                get: { upsellEntry != nil },
                set: { if !$0 { upsellEntry = nil } }
            ),
            presenting: upsellEntry
        ) { entry in
            Button("Proを見る") {
                isPaywallPresented = true
            }
            Button("広告を見て1回編集する") {
                Task {
                    if await rewardedAdManager.showForUnlock() {
                        editingEntry = entry
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .tint(Color(uiColor: .systemBlue))
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                PostedMessageEditView(entry: entry, viewModel: viewModel)
            }
            // シートは別の View 階層になるため、Pro 状態を明示的に渡す
            .environmentObject(purchaseManager)
            .limitedDynamicTypeSize()
        }
        .sheet(isPresented: $isPaywallPresented) {
            NavigationStack {
                PaywallView(source: .edit)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") {
                                isPaywallPresented = false
                            }
                        }
                    }
            }
            .environmentObject(purchaseManager)
            .limitedDynamicTypeSize()
        }
        // Pro でない人に「広告を見て1回編集する」を出せるよう、リワード広告を読み込んでおく
        .preloadsRewardedAd(when: !canEdit)
        .toast($viewModel.toast)
        .onAppear {
            // 送信画面で送った分・設定画面で消した分を反映する
            viewModel.reload()
            urlStore.reload()
        }
        .onChange(of: isHistoryEnabled) { _ in
            viewModel.reload()
        }
        // 開いている間に送信画面の送信が終わって送信履歴が保存されたときも、一覧に反映する。
        // 送信履歴は画面ごとの別のストアが UserDefaults に書くので、UserDefaults の変更を見る
        .onReceive(
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            viewModel.reload()
        }
    }

    private var list: some View {
        List {
            Section {
                InlineBannerAdRow(model: adModel)
            }

            if !isHistoryEnabled {
                Section {
                    historyDisabledNotice
                }
            }

            Section {
                ForEach(viewModel.items) { entry in
                    row(entry)
                        .listRowBackground(Color.appSurface)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 4.0) {
                    Text("直近\(SendHistoryStore.maxCount)件の送信履歴のうち、送れたメッセージを表示しています")
                    // 削除は無料、編集は Pro 限定（Issue #666）
                    if !canEdit {
                        Text("削除は無料です。編集はNinjacord Pro限定で、広告を見ると1回編集できます")
                    }
                }
                .foregroundStyle(Color.appTextSecondary)
            }
        }
        .loadsInlineBannerAd(adModel, when: !viewModel.items.isEmpty)
        .scrollContentBackground(.hidden)
        .background(.clear)
    }

    private func row(_ entry: SendHistoryEntry) -> some View {
        let isProcessing = entry.messageID.map(viewModel.processingMessageIDs.contains) ?? false
        return Button {
            startEditing(entry)
        } label: {
            PostedMessageRow(
                entry: entry,
                destination: destinationName(of: entry),
                isProcessing: isProcessing,
                // App Store 用スクリーンショットでも、編集が Pro 限定だと分かるよう出す（審査ガイドライン 2.3.2、Discussion #355）
                showsProBadge: !canEdit || ScreenshotDemo.isEnabled
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // destructive にすると、確認ダイアログで決める前に行を消すアニメーションが始まるので、赤い色だけを付ける
            Button {
                deletingEntry = entry
            } label: {
                Label("削除", systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                startEditing(entry)
            } label: {
                Label("編集", systemImage: "pencil")
            }
            .tint(Color.appAccent)
        }
        .contextMenu {
            Button {
                startEditing(entry)
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deletingEntry = entry
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .disabled(isProcessing)
    }

    /// 編集（Pro 限定）は、リワード広告の一時解放中も使える。App Store 用スクリーンショットでも解放する
    private var canEdit: Bool {
        ProFeatureAccess.canUse(isPro: purchaseManager.isPro)
    }

    /// 編集を始める。Pro でなければ、リワード広告を読み込めていれば Pro にするか広告を見るかを選ばせ、読み込めていなければペイウォールを開く
    private func startEditing(_ entry: SendHistoryEntry) {
        if canEdit {
            editingEntry = entry
        } else if rewardedAdManager.isReady {
            upsellEntry = entry
        } else {
            isPaywallPresented = true
        }
    }

    /// 送信履歴の保存を OFF にしたあとも残っている一覧の上に出す案内
    private var historyDisabledNotice: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Text("送信履歴の保存がOFFのため、これから送るメッセージはここに追加されません")
                .font(.footnote)
                .foregroundStyle(Color.appTextSecondary)
            Button("送信履歴を保存する") {
                isHistoryEnabled = true
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(.vertical, 4.0)
        .listRowBackground(Color.appSurface)
    }

    /// 一覧が空のとき。送信履歴を保存していなければ、ON にすると使えることを案内してその場で ON にできるようにする
    private var emptyState: some View {
        VStack(spacing: 16.0) {
            Image(systemName: "tray")
                .font(.system(size: 44.0))
                .foregroundStyle(Color.appTextSecondary)
                .accessibilityHidden(true)

            if isHistoryEnabled {
                Text("まだ送ったメッセージはありません")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text("送信画面から送ったメッセージがここに表示され、あとから編集・削除できます")
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                Text("送ったメッセージをあとから編集・削除")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text("送信履歴を保存すると、この端末から送ったメッセージを、ここから編集・削除できます")
                    .foregroundStyle(Color.appTextSecondary)
                Button {
                    isHistoryEnabled = true
                } label: {
                    Text("送信履歴を保存する")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 12.0)
                        .padding(.horizontal, 24.0)
                }
                .buttonStyle(.raised(cornerRadius: 12.0, depth: 4.0))
                Text("ONにする前に送ったメッセージは表示されません。設定の「送信履歴」からいつでもOFFにできます")
                    .font(.footnote)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(32.0)
        .frame(maxWidth: 480.0)
    }

    /// 宛先の表示名。保存した宛先なら付けた名前、そうでなければトークンを出さない短い表示（Issue #674）
    private func destinationName(of entry: SendHistoryEntry) -> String {
        urlStore.displayName(for: entry.url)
    }
}

/// 「投稿済み」の 1 行。送った日時・中身の要約・宛先を並べ、タップで編集を開く
private struct PostedMessageRow: View {
    let entry: SendHistoryEntry
    let destination: String
    let isProcessing: Bool
    /// 編集が Pro 限定だと分かるよう、Pro でない人には PRO の印を出す
    let showsProBadge: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12.0) {
            VStack(alignment: .leading, spacing: 4.0) {
                HStack(spacing: 6.0) {
                    Text(entry.sentAt, format: .dateTime.year().month().day().hour().minute())
                    if entry.editedAt != nil {
                        Text("編集済み")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)

                Text(summary)
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)

                // Label だと List の中でアイコンと文字の間が広く空くので、HStack で詰める
                HStack(spacing: 4.0) {
                    Image(systemName: "number")
                        .accessibilityHidden(true)
                    Text(destination)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isProcessing {
                ProgressView()
            } else {
                if showsProBadge {
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6.0)
                        .padding(.vertical, 2.0)
                        .background(Capsule().fill(Color.appAccent))
                        .accessibilityLabel("Pro限定")
                }
                Image(systemName: "pencil")
                    .foregroundStyle(Color.appTextSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2.0)
        .accessibilityElement(children: .combine)
    }

    /// 中身の要約。本文も埋め込みのタイトルも無ければ（画像だけなど）、何が入っているかを出す
    private var summary: String {
        let summary = entry.message.summary
        if !summary.isEmpty {
            return summary
        }
        if entry.message.messageEmbedEntity.hasContent {
            return String(localized: "埋め込み")
        }
        return entry.hasAttachment ? String(localized: "画像だけのメッセージ") : DiscordWebhookRequest.defaultContent
    }
}
