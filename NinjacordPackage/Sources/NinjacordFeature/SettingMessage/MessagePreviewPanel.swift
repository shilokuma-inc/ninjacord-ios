//
//  MessagePreviewPanel.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面の上端に固定して浮かせる「Discordでの見え方」のパネル（Issue #620）。
/// 入力欄をスクロールしても、キーボードを出していても隠れず、入力した内容がその場でプレビューに反映される。
/// ナビゲーションバーのように、裏を通る入力欄が透ける（iOS 26 以降は Liquid Glass、それより前は Material）。
/// 見出しで開閉でき、閉じている間は見出しだけを出す。
/// 開いたプレビューは全体を出す。入力欄に届かなくなるほど長いとき（キーボードを出した小さい画面など）だけ、
/// 高さを `maxContentHeight` までにして超えた分をパネルの中でスクロールする
struct MessagePreviewPanel<Content: View>: View {
    @Binding var isExpanded: Bool
    /// 開いたプレビューに使える高さの上限
    let maxContentHeight: CGFloat
    @ViewBuilder let content: Content

    /// プレビューの本来の高さ。上限より低いときは、その高さだけパネルに使う
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: .zero) {
            header
            if isExpanded {
                scrollableContent
                    .padding(.horizontal, MessagePreviewPanelMetrics.padding)
                    .padding(.bottom, MessagePreviewPanelMetrics.padding)
                    .transition(.opacity)
            }
        }
        .glassPanelBackground(cornerRadius: 16.0)
    }

    /// 開閉のボタンを兼ねた見出し。送信画面のセクション（`SendMessageSection`）と同じく、右端の矢印の向きで開閉を示す。
    /// 閉じている間は場所を取らないよう低くし、余白まで含めてタップ領域にして HIG の最小サイズ（44pt）を確保する
    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "eye")
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 24.0, height: 24.0)
                    .accessibilityHidden(true)
                Text("Discordでの見え方")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90.0 : 0.0))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: MessagePreviewPanelMetrics.headerHeight)
            .padding(.horizontal, MessagePreviewPanelMetrics.padding)
            .padding(.vertical, MessagePreviewPanelMetrics.headerPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(isExpanded ? Text("展開済み") : Text("折りたたみ済み"))
    }

    /// プレビュー。本来の高さが上限に収まるならその高さで出し、収まらなければ上限の高さで中をスクロールさせる
    private var scrollableContent: some View {
        ScrollView {
            content
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ContentHeightKey.self, value: proxy.size.height)
                    }
                }
        }
        .bouncesOnlyWhenScrollable()
        .frame(height: min(contentHeight, maxContentHeight))
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
    }
}

/// パネルの寸法。中身を除いた高さを送信画面がプレビューの上限の計算に使うので、generic な View の外に置く
enum MessagePreviewPanelMetrics {
    /// 見出しの行の高さ。アイコン（24pt）と 1 行の文字が収まる高さ
    static let headerHeight: CGFloat = 32.0
    /// 見出しの行の上下の余白。行と合わせて、閉じたパネルの高さが HIG の最小のタップ領域（44pt）になる
    static let headerPadding: CGFloat = 6.0
    /// パネルの左右と、中身の下の余白
    static let padding: CGFloat = 12.0
    /// 閉じたパネルの高さ（見出しの行と上下の余白）
    static var collapsedHeight: CGFloat {
        headerHeight + headerPadding * 2
    }
    /// 中身を除いたパネルの高さ（閉じたパネルの高さと、中身の下の余白）
    static var chromeHeight: CGFloat {
        collapsedHeight + padding
    }
}

private extension View {
    /// 裏のコンテンツが透ける角丸の背景。iOS 26 以降は Liquid Glass、それより前は Material（ぼかし）で代える
    @ViewBuilder
    func glassPanelBackground(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.25), radius: 8.0, y: 4.0)
        }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("開いた状態") {
    VStack {
        MessagePreviewPanel(isExpanded: .constant(true), maxContentHeight: 240.0) {
            MessagePreview(
                username: "レイド告知Bot",
                avatarURL: "",
                content: "今夜21:00 レイド開始！",
                embed: MessageEmbedEntity(title: "お知らせ", description: "本日18時からメンテナンスです"),
                attachment: nil
            )
        }
        Spacer()
    }
    .padding()
    .background(Color.appBackground)
}

#Preview("閉じた状態") {
    VStack {
        MessagePreviewPanel(isExpanded: .constant(false), maxContentHeight: 240.0) {
            MessagePreview(username: "", avatarURL: "", content: "", embed: MessageEmbedEntity(), attachment: nil)
        }
        Spacer()
    }
    .padding()
    .background(Color.appBackground)
}
