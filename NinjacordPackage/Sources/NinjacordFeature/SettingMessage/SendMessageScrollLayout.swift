//
//  SendMessageScrollLayout.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面の縦の配置。`content`（入力欄〜送信ボタン）をスクロールできるようにし、その下に `bottom`（広告など）を置く。
/// 縦が余るときは、スクロール化する前の Spacer での配置と同じく、`content` の上の余白と `bottom` で残りの高さを等分する。
/// 縦が足りないときは `content` をスクロールさせる。`bottom` には `minimumBottomHeight` の高さを必ず残す（広告が隠れないように）
struct SendMessageScrollLayout<Content: View, Bottom: View>: View {
    let onTapBackground: () -> Void
    /// 表示したときに、`content` の中のこの ID（`.id(_:)`）の View の上端までスクロールしておく。nil なら動かさない。
    /// 収まっているときは動かない
    var scrollTargetOnAppear: String?
    /// `bottom` に必ず残す高さ。引数は画面の幅（バナー広告の高さは幅で決まるため）
    var minimumBottomHeight: (CGFloat) -> CGFloat = { _ in 0 }
    @ViewBuilder let content: Content
    @ViewBuilder let bottom: Bottom

    /// `content` の本来の高さ（余白を足す前）
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let bottomHeight = SendMessageLayoutMetrics.bottomHeight(
                containerHeight: proxy.size.height,
                contentHeight: contentHeight,
                minimum: minimumBottomHeight(proxy.size.width)
            )
            VStack(spacing: .zero) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: .zero) {
                            content
                        }
                        .background {
                            GeometryReader { contentProxy in
                                Color.clear
                                    .preference(key: ContentHeightKey.self, value: contentProxy.size.height)
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
                    }
                    .bouncesOnlyWhenScrollable()
                    .scrollDismissesKeyboard(.interactively)
                    .task {
                        await scrollToTarget(scrollProxy)
                    }
                }

                bottom
                    .frame(height: bottomHeight)
            }
        }
        .onPreferenceChange(ContentHeightKey.self) { contentHeight in
            self.contentHeight = contentHeight
        }
    }

    /// `scrollTargetOnAppear` があれば、その View の上端までスクロールする。
    /// 添付画像やアイコンの読み込みで `content` の高さが決まるのを待ってから動かす
    private func scrollToTarget(_ scrollProxy: ScrollViewProxy) async {
        guard let scrollTargetOnAppear else { return }
        do {
            try await Task.sleep(for: .milliseconds(500))
        } catch {
            return
        }
        scrollProxy.scrollTo(scrollTargetOnAppear, anchor: .top)
    }
}

/// `SendMessageScrollLayout` の高さの計算。View から切り離してテストする
enum SendMessageLayoutMetrics {
    /// `bottom` の高さ。`content` が収まって余った高さを、`content` の上の余白と等分する。
    /// 余りが少ない・収まらないときも `minimum` は残す
    static func bottomHeight(containerHeight: CGFloat, contentHeight: CGFloat, minimum: CGFloat) -> CGFloat {
        max(minimum, (containerHeight - contentHeight) / 2)
    }

    /// 上端に固定したプレビューの中身に使える高さの上限。
    /// `containerHeight` の `ratio` までにしつつ、`reservedHeight`（パネルの見出しと余白・下端の広告の領域・入力欄 1 つ分）を
    /// 除いた高さも超えないようにして、小さい画面でキーボードを出していても入力欄が見えるようにする。
    /// それでもプレビューの `minimum`（名前の行）は残す
    static func previewMaxContentHeight(
        containerHeight: CGFloat,
        ratio: CGFloat,
        reservedHeight: CGFloat,
        minimum: CGFloat
    ) -> CGFloat {
        max(minimum, min(containerHeight * ratio, containerHeight - reservedHeight))
    }
}

/// `SendMessageScrollLayout` が測る `content` の高さ
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}
