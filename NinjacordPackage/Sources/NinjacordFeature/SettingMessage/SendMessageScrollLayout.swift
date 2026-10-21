//
//  SendMessageScrollLayout.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面の縦の配置。`content`（入力欄〜送信ボタン）をスクロールできるようにし、その下に `bottom`（広告など）を置く。
/// 縦が余るときは、スクロール化する前の Spacer での配置と同じく、`content` の上の余白と `bottom` で残りの高さを等分する。
/// 縦が足りないときは `content` をスクロールさせる。`bottom` には `minimumBottomHeight` の高さを必ず残す（広告が隠れないように）。
/// `sendMessageLayoutExcludesHeight()` を付けた部分の高さは、等分の計算に入れない（開いたプレビューなど）
struct SendMessageScrollLayout<Content: View, Bottom: View>: View {
    let onTapBackground: () -> Void
    /// 表示したときに `content` の下端までスクロールしておくか。収まっているときは動かない
    var scrollsToBottomOnAppear = false
    /// `bottom` に必ず残す高さ。引数は画面の幅（バナー広告の高さは幅で決まるため）
    var minimumBottomHeight: (CGFloat) -> CGFloat = { _ in 0 }
    @ViewBuilder let content: Content
    @ViewBuilder let bottom: Bottom

    @State private var heights = Heights()

    /// `content` の下端へスクロールするための ID
    private static var contentID: String { "content" }

    var body: some View {
        GeometryReader { proxy in
            let bottomHeight = SendMessageLayoutMetrics.bottomHeight(
                containerHeight: proxy.size.height,
                contentHeight: heights.content,
                excludedHeight: heights.excluded,
                minimum: minimumBottomHeight(proxy.size.width)
            )
            VStack(spacing: .zero) {
                ScrollViewReader { scrollProxy in
                    bouncesOnlyWhenScrollable(ScrollView {
                        VStack(spacing: .zero) {
                            content
                        }
                        .id(Self.contentID)
                        .background {
                            GeometryReader { contentProxy in
                                Color.clear
                                    .preference(key: HeightsKey.self, value: Heights(content: contentProxy.size.height))
                            }
                        }
                        // 余った高さは上の余白にして、送信ボタンを下に寄せる
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height - bottomHeight, alignment: .bottom)
                        // ScrollView が背景のタップを受け取るので、中の余白のタップでもキーボードを閉じられるようにする
                        .background {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture(perform: onTapBackground)
                        }
                    })
                    .scrollDismissesKeyboard(.interactively)
                    .task {
                        await scrollToBottom(scrollProxy)
                    }
                }

                bottom
                    .frame(height: bottomHeight)
            }
        }
        .onPreferenceChange(HeightsKey.self) { heights in
            self.heights = heights
        }
    }

    /// `scrollsToBottomOnAppear` のとき、`content` の下端までスクロールする。
    /// 添付画像やアイコンの読み込みで `content` の高さが決まるのを待ってから動かす
    private func scrollToBottom(_ scrollProxy: ScrollViewProxy) async {
        guard scrollsToBottomOnAppear else { return }
        do {
            try await Task.sleep(for: .milliseconds(500))
        } catch {
            return
        }
        scrollProxy.scrollTo(Self.contentID, anchor: .bottom)
    }

    /// 内容が収まっているときは、引っ張っても動かないようにする（スクロール化する前と同じ操作感にする）
    @ViewBuilder
    private func bouncesOnlyWhenScrollable(_ scrollView: some View) -> some View {
        if #available(iOS 16.4, *) {
            scrollView.scrollBounceBehavior(.basedOnSize)
        } else {
            scrollView
        }
    }

}

/// `SendMessageScrollLayout` の高さの計算。View から切り離してテストする
enum SendMessageLayoutMetrics {
    /// `bottom` の高さ。`content`（等分の計算に入れない `excludedHeight` を除く）が収まって余った高さを、
    /// `content` の上の余白と等分する。余りが少ない・収まらないときも `minimum` は残す
    static func bottomHeight(
        containerHeight: CGFloat,
        contentHeight: CGFloat,
        excludedHeight: CGFloat,
        minimum: CGFloat
    ) -> CGFloat {
        max(minimum, (containerHeight - (contentHeight - excludedHeight)) / 2)
    }
}

/// `SendMessageScrollLayout` が測る高さ。両方を同じ更新で受け取り、下端の領域が一瞬だけ縮むのを防ぐ
private struct Heights: Equatable {
    /// `content` の本来の高さ（余白を足す前）
    var content: CGFloat = 0
    /// そのうち、等分の計算に入れない高さ
    var excluded: CGFloat = 0
}

private struct HeightsKey: PreferenceKey {
    static let defaultValue = Heights()

    static func reduce(value: inout Heights, nextValue: () -> Heights) {
        let next = nextValue()
        value.content += next.content
        value.excluded += next.excluded
    }
}

extension View {
    /// この View の高さを、`SendMessageScrollLayout` の余白の等分の計算から外す
    func sendMessageLayoutExcludesHeight() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: HeightsKey.self, value: Heights(excluded: proxy.size.height))
            }
        }
    }
}
