//
//  MessagePartIcon.swift
//  NinjacordApp
//

import SwiftUI

/// 送信画面の入力欄の左に出すアイコン。Discord のメッセージの縮図（丸いアイコン・名前の行・本文の行・
/// 左に色の線がある埋め込みの箱・画像の四角）を描き、その欄が出る部位だけを `appAccent` で強調する（Discussion #586 の Q2）。
/// 宛先（Webhook URL）は出る部位が無いので、同じ部品で「メッセージを送り先へ送る」図にする。
/// 意味は欄の見出しの文字で伝えるので、VoiceOver からは隠す
struct MessagePartIcon: View {
    enum Part: CaseIterable {
        /// 宛先（Webhook URL）
        case destination
        /// 名前
        case name
        /// プロフィール画像
        case avatar
        /// 本文
        case content
        /// 埋め込み
        case embed
        /// 添付の画像
        case attachment
    }

    let part: Part
    /// 一辺の長さ。既定は送信画面のほかの SF Symbols のアイコンと同じ 24pt
    var size: CGFloat = MessagePartIcon.gridSize

    /// 部品の座標の格子の一辺
    static let gridSize: CGFloat = 24.0
    /// 強調しない部品の不透明度。ダークのテーマの面（`appSurface`）の上でも形が見える濃さにする
    private static let mutedOpacity: Double = 0.6

    var body: some View {
        Canvas { context, canvasSize in
            // 24 × 24 の格子で描き、渡された大きさに合わせて伸ばす
            context.scaleBy(x: canvasSize.width / Self.gridSize, y: canvasSize.height / Self.gridSize)
            let muted = Color.appTextSecondary.opacity(Self.mutedOpacity)
            for shape in MessagePartIconShape.shapes(for: part) {
                context.fill(shape.path, with: .color(shape.isHighlighted ? Color.appAccent : muted))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// アイコンを形づくる部品 1 つ。座標は 24 × 24 の格子
struct MessagePartIconShape {
    let path: Path
    let isHighlighted: Bool

    /// 部品どうしで角の丸みをそろえる
    private static let cornerRadius: CGFloat = 1.0

    /// `part` のアイコンの部品。強調する部品を含む
    static func shapes(for part: MessagePartIcon.Part) -> [MessagePartIconShape] {
        guard part != .destination else {
            return destinationShapes
        }
        return [
            // 丸いアイコン
            MessagePartIconShape(
                path: Path(ellipseIn: CGRect(x: 1, y: 1, width: 6, height: 6)),
                isHighlighted: part == .avatar
            ),
            // 名前の行
            MessagePartIconShape(path: bar(CGRect(x: 9, y: 2, width: 9, height: 3)), isHighlighted: part == .name),
            // 本文の行
            MessagePartIconShape(path: bar(CGRect(x: 9, y: 7, width: 14, height: 2)), isHighlighted: part == .content),
            // 埋め込みの箱と、左の色の線
            MessagePartIconShape(path: embedBox, isHighlighted: part == .embed),
            // 添付の画像
            MessagePartIconShape(
                path: bar(CGRect(x: 9, y: 17, width: 8, height: 6)),
                isHighlighted: part == .attachment
            )
        ]
    }

    /// 宛先: 左のメッセージ（丸いアイコンと行）から、右の送り先の箱へ向かう矢印
    private static var destinationShapes: [MessagePartIconShape] {
        var arrow = bar(CGRect(x: 1, y: 11, width: 9, height: 2))
        arrow.move(to: CGPoint(x: 9, y: 7.5))
        arrow.addLine(to: CGPoint(x: 14, y: 12))
        arrow.addLine(to: CGPoint(x: 9, y: 16.5))
        arrow.closeSubpath()

        var destination = Path()
        destination.addRoundedRect(
            in: CGRect(x: 15, y: 3, width: 8, height: 18),
            cornerSize: CGSize(width: cornerRadius * 2, height: cornerRadius * 2)
        )
        return [
            MessagePartIconShape(path: Path(ellipseIn: CGRect(x: 1, y: 3, width: 5, height: 5)), isHighlighted: false),
            MessagePartIconShape(path: bar(CGRect(x: 1, y: 17, width: 6, height: 2)), isHighlighted: false),
            MessagePartIconShape(path: arrow, isHighlighted: true),
            MessagePartIconShape(path: destination, isHighlighted: true)
        ]
    }

    /// 埋め込みの箱。左の色の線を太くし、中に 1 行分の隙間を空けて「箱」に見せる
    private static var embedBox: Path {
        var path = bar(CGRect(x: 9, y: 11, width: 2, height: 4))
        path.addPath(bar(CGRect(x: 12, y: 11, width: 11, height: 1.5)))
        path.addPath(bar(CGRect(x: 12, y: 13.5, width: 8, height: 1.5)))
        return path
    }

    /// 角を丸めた棒。細い棒は丸みを高さの半分までにする
    private static func bar(_ rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.height / 2)
        return Path(roundedRect: rect, cornerSize: CGSize(width: radius, height: radius))
    }
}

#Preview("6 つのアイコン") {
    VStack(spacing: 24.0) {
        ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
            HStack(spacing: 16.0) {
                ForEach(MessagePartIcon.Part.allCases, id: \.self) { part in
                    MessagePartIcon(part: part, size: 48.0)
                }
            }
            .padding()
            .background(Color.appSurface)
            .environment(\.colorScheme, scheme)
        }
    }
    .padding()
}
