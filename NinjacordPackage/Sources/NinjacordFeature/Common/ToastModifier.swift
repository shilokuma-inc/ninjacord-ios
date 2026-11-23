//
//  ToastModifier.swift
//  NinjacordApp
//

import SwiftUI

/// 画面上部に一時的に表示する通知
struct Toast: Equatable {
    enum Style {
        case success
        case failure
    }

    /// トーストの右端に出すボタン（送信の取り消しなど）。押すとトーストを閉じてから `handler` を呼ぶ
    struct Action {
        let title: Text
        let handler: @MainActor () -> Void

        init(title: LocalizedStringKey, handler: @escaping @MainActor () -> Void) {
            self.title = Text(title)
            self.handler = handler
        }
    }

    /// ボタンのあるトーストを表示しておく時間。読んでから押せるよう、ボタンの無いトーストより長くする
    static let actionDuration: Duration = .seconds(5)

    let style: Style
    let message: Text
    let action: Action?

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }

    /// 同じ内容のトーストを続けて出したときも表示し直せるよう、表示ごとに別の値として扱う
    private let id = UUID()

    init(style: Style, message: LocalizedStringKey, action: Action? = nil) {
        self.style = style
        self.message = Text(message)
        self.action = action
    }

    /// 翻訳済みの文言（`LocalizedError.errorDescription` など）をそのまま表示する
    init(style: Style, verbatimMessage: String) {
        self.style = style
        self.message = Text(verbatim: verbatimMessage)
        self.action = nil
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    /// トーストを表示しておく時間。失敗時は原因の説明文を読めるよう長めにする。ボタンがあれば押せるようさらに長くする
    private func duration(for toast: Toast) -> Duration {
        if toast.action != nil {
            return Toast.actionDuration
        }
        switch toast.style {
        case .success:
            return .seconds(2.5)
        case .failure:
            return .seconds(4)
        }
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    ToastView(toast: toast) {
                        // 先に閉じる。ボタンの処理が次のトーストを出したときに、それを消さないように
                        self.toast = nil
                        toast.action?.handler()
                    }
                        .padding(.horizontal)
                        .padding(.top, 8.0)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture {
                            self.toast = nil
                        }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: toast)
            .task(id: toast) {
                guard let toast else { return }
                try? await Task.sleep(for: duration(for: toast))
                // 待機中に別のトーストへ差し替わった場合は task(id:) ごとキャンセルされるので、ここには来ない
                guard !Task.isCancelled else { return }
                self.toast = nil
            }
    }
}

private struct ToastView: View {
    let toast: Toast
    /// ボタンを押したとき
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 8.0) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            toast.message
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            if let action = toast.action {
                Button(action: onAction) {
                    action.title
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.leading, 8.0)
                        // トーストの高さのまま、押せる範囲を HIG の最小サイズ（44pt）まで広げる
                        .frame(minHeight: 44.0)
                        .contentShape(Rectangle())
                }
                .padding(.vertical, -12.0)
            }
        }
        .padding(.horizontal, 16.0)
        .padding(.vertical, 12.0)
        .background(
            // 失敗時の説明文は複数行になるため、Capsule ではなく角丸の四角形にする
            RoundedRectangle(cornerRadius: 20.0, style: .continuous)
                .fill(.regularMaterial)
                .shadow(radius: 4.0)
        )
        // ボタンがあれば VoiceOver で押せるよう、まとめずに読ませる
        .accessibilityElement(children: toast.action == nil ? .combine : .contain)
    }

    private var iconName: String {
        switch toast.style {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch toast.style {
        case .success:
            return .green
        case .failure:
            return .red
        }
    }
}

extension View {
    /// `toast` に値を入れると画面上部にトーストを表示し、一定時間後に自動で nil に戻す
    func toast(_ toast: Binding<Toast?>) -> some View {
        self.modifier(ToastModifier(toast: toast))
    }
}
