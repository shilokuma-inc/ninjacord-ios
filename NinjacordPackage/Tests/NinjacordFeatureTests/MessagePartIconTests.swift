//
//  MessagePartIconTests.swift
//  NinjacordFeatureTests
//

import CoreGraphics
@testable import NinjacordFeature
import Testing

/// 送信画面の入力欄のアイコン（`MessagePartIcon`）の部品（Discussion #586 の Q2）
struct MessagePartIconTests {
    private static let messageParts: [MessagePartIcon.Part] = [.name, .avatar, .content, .embed, .attachment]
    private static let grid = CGRect(x: 0, y: 0, width: MessagePartIcon.gridSize, height: MessagePartIcon.gridSize)

    @Test("メッセージの部位のアイコンは、同じ部品を描き、その部位の 1 つだけを強調する", arguments: messageParts)
    func highlightsOnePart(part: MessagePartIcon.Part) {
        let shapes = MessagePartIconShape.shapes(for: part)
        #expect(shapes.count == 5)
        #expect(shapes.filter(\.isHighlighted).count == 1)
    }

    @Test("部位ごとに強調する部品が違う")
    func eachPartHighlightsDifferentShape() {
        let highlightedIndices = Self.messageParts.map { part in
            MessagePartIconShape.shapes(for: part).firstIndex(where: \.isHighlighted)
        }
        #expect(Set(highlightedIndices).count == Self.messageParts.count)
    }

    @Test("宛先のアイコンは、送り先を強調する")
    func destinationHighlightsTarget() {
        let shapes = MessagePartIconShape.shapes(for: .destination)
        #expect(shapes.contains { $0.isHighlighted })
        #expect(shapes.contains { !$0.isHighlighted })
    }

    @Test("どの部品も 24 × 24 の格子からはみ出さない", arguments: MessagePartIcon.Part.allCases)
    func shapesFitInGrid(part: MessagePartIcon.Part) {
        for shape in MessagePartIconShape.shapes(for: part) {
            #expect(Self.grid.contains(shape.path.boundingRect))
        }
    }
}
