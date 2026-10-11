//
//  RaisedButtonStyle.swift
//  NinjacordApp
//

import SwiftUI

/// 押し込み型の立体的なボタン。上の面の下に濃い色の「厚み」を描き、押すと面が厚みの分だけ下がる。
/// 色は `Color.appAccent` から作る。余白と文言の見た目はラベル側で決める
struct RaisedButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 30.0
    /// 厚み。ボタンの高さはこの分だけ増える
    var depth: CGFloat = 6.0
    /// 処理中（送信中など）。押し込んだままの見た目にする
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        RaisedButton(
            configuration: configuration,
            cornerRadius: cornerRadius,
            depth: depth,
            isLoading: isLoading
        )
    }
}

private struct RaisedButton: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    let depth: CGFloat
    let isLoading: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 押下中・処理中・無効のときは面を下げて平らにする
    private var isPressedDown: Bool {
        configuration.isPressed || isLoading || !isEnabled
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        configuration.label
            .background {
                shape
                    .fill(Color.appAccent)
                    .overlay {
                        // 上を少し明るくして面に丸みを出す
                        shape.fill(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .overlay {
                        // 視差効果を減らす設定では面を動かさず、色を濃くして押したことを示す
                        if reduceMotion && isPressedDown {
                            shape.fill(Color.black.opacity(0.2))
                        }
                    }
            }
            .offset(y: isPressedDown && !reduceMotion ? depth : 0)
            // 面が下がっても全体の大きさが変わらないよう、厚みの分を常に確保しておく
            .padding(.bottom, depth)
            .background {
                shape
                    .fill(Color.appAccent)
                    .overlay(shape.fill(Color.black.opacity(0.35)))
                    .padding(.top, depth)
                    .shadow(color: .black.opacity(isPressedDown ? 0.1 : 0.25), radius: 3.0, y: 2.0)
            }
            .opacity(isEnabled || isLoading ? 1 : 0.5)
            .animation(.easeOut(duration: 0.08), value: isPressedDown)
    }
}

extension ButtonStyle where Self == RaisedButtonStyle {
    static var raised: RaisedButtonStyle {
        .init()
    }

    static func raised(
        cornerRadius: CGFloat = 30.0,
        depth: CGFloat = 6.0,
        isLoading: Bool = false
    ) -> RaisedButtonStyle {
        .init(cornerRadius: cornerRadius, depth: depth, isLoading: isLoading)
    }
}

#Preview {
    VStack(spacing: 24.0) {
        Button {} label: {
            Text("メッセージを送信！")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .padding()
        }
        .buttonStyle(.raised)

        Button {} label: {
            Text("メッセージを送信！")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .padding()
        }
        .buttonStyle(.raised(isLoading: true))
        .disabled(true)

        Button {} label: {
            Text("メッセージを送信！")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .padding()
        }
        .buttonStyle(.raised)
        .disabled(true)
    }
}
