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

    let style: Style
    let message: LocalizedStringKey

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }

    /// 同じ内容のトーストを続けて出したときも表示し直せるよう、表示ごとに別の値として扱う
    private let id = UUID()

    init(style: Style, message: LocalizedStringKey) {
        self.style = style
        self.message = message
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    /// トーストを表示しておく時間
    private let duration: Duration = .seconds(2.5)

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    ToastView(toast: toast)
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
                guard toast != nil else { return }
                try? await Task.sleep(for: duration)
                // 待機中に別のトーストへ差し替わった場合は task(id:) ごとキャンセルされるので、ここには来ない
                guard !Task.isCancelled else { return }
                toast = nil
            }
    }
}

private struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 8.0) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            Text(toast.message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16.0)
        .padding(.vertical, 12.0)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .shadow(radius: 4.0)
        )
        .accessibilityElement(children: .combine)
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
