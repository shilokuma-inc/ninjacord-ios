//
//  SendMessageLayoutMetricsTests.swift
//  NinjacordFeatureTests
//

import CoreGraphics
@testable import NinjacordFeature
import Testing

/// 送信画面の下端の領域の高さ（`SendMessageLayoutMetrics.bottomHeight`）
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
}
