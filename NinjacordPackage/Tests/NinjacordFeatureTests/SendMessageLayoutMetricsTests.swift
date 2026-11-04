//
//  SendMessageLayoutMetricsTests.swift
//  NinjacordFeatureTests
//

import CoreGraphics
@testable import NinjacordFeature
import Testing

/// 送信画面の下端の領域の高さ（`SendMessageLayoutMetrics.bottomHeight`）と、
/// 上端に固定したプレビューの中身の高さの上限（`previewMaxContentHeight`）
struct SendMessageLayoutMetricsTests {
    private func bottomHeight(content: CGFloat, minimum: CGFloat = 50) -> CGFloat {
        SendMessageLayoutMetrics.bottomHeight(containerHeight: 800, contentHeight: content, minimum: minimum)
    }

    @Test("入力欄が収まって余りが多いときは、上の余白と等分する")
    func splitsRemainingHeight() {
        #expect(bottomHeight(content: 500) == 150)
    }

    @Test("余りの半分が最小の高さより低いときは、最小の高さを残す")
    func keepsMinimumWhenRemainingIsSmall() {
        #expect(bottomHeight(content: 750) == 50)
    }

    @Test("入力欄が画面に収まらないときも、最小の高さを残す")
    func keepsMinimumWhenContentOverflows() {
        #expect(bottomHeight(content: 1_200) == 50)
        #expect(bottomHeight(content: 1_200, minimum: 0) == 0)
    }

    // MARK: - previewMaxContentHeight

    /// 割合は 0.5、見出しと余白・下端の領域・入力欄 1 つ分の合計は 200、プレビューの最低の高さは 64 として計算する
    private func previewMaxContentHeight(container: CGFloat) -> CGFloat {
        SendMessageLayoutMetrics.previewMaxContentHeight(
            containerHeight: container,
            ratio: 0.5,
            reservedHeight: 200,
            minimum: 64
        )
    }

    @Test("縦に余裕があるときは、画面の高さの割合で上限を決める")
    func previewCapFollowsRatio() {
        #expect(previewMaxContentHeight(container: 800) == 400)
    }

    @Test("キーボードを出した小さい画面では、見出し・広告・入力欄 1 つ分を残した高さまでにする")
    func previewCapKeepsRoomForInput() {
        #expect(previewMaxContentHeight(container: 300) == 100)
    }

    @Test("それでもプレビューの最低の高さ（名前の行）は残す")
    func previewCapKeepsMinimum() {
        #expect(previewMaxContentHeight(container: 220) == 64)
    }
}
