//
//  OnboardingView.swift
//  NinjacordApp
//

import SwiftUI

/// 初回起動時に表示する、Webhook URL の用意から送信までの流れの説明と、最後のテーマの選択。
/// 説明のページでは右上の「スキップ」で閉じられる（テーマのページは出さず、テーマは今のまま）
struct OnboardingView: View {
    /// スキップ・完了のどちらで閉じたときも呼ばれる
    let onFinish: () -> Void

    @State private var selection = 0

    private let pages = OnboardingPage.all

    /// 説明のページの後ろに置くテーマのページを含めたページ数。決定事項により 5 ページ以内に収める
    static let pageCount = OnboardingPage.all.count + 1

    /// テーマのページの位置（最後のページ）
    private var themePageIndex: Int { pages.count }

    private var pageCount: Int { Self.pageCount }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: .zero) {
                HStack {
                    Spacer()
                    // 離脱を防ぐため、スキップはどのページでも同じ位置に目立つ色で表示する。
                    // 最後のページ（テーマ）は「はじめる」と同じ動作になるので、位置だけ残して隠す
                    Button("スキップ", action: onFinish)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                        .frame(minWidth: 44.0, minHeight: 44.0)
                        .opacity(isLastPage ? 0 : 1)
                        .disabled(isLastPage)
                }
                .padding(.horizontal)

                TabView(selection: $selection) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }

                    OnboardingThemePageView()
                        .tag(themePageIndex)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                PageIndicator(count: pageCount, selection: selection)
                    .padding(.bottom, 24.0)

                primaryButton
                    .padding(.horizontal, 24.0)
                    .padding(.bottom, 16.0)
            }
        }
    }

    private var isLastPage: Bool {
        selection == pageCount - 1
    }

    private var primaryButton: some View {
        Button(action: {
            if isLastPage {
                onFinish()
            } else {
                withAnimation {
                    selection += 1
                }
            }
        }, label: {
            Text(isLastPage ? "はじめる" : "次へ")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16.0)
        })
        .buttonStyle(.raised)
    }
}

/// オンボーディング 1 ページ分の内容
struct OnboardingPage {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    /// 決定事項により、後ろに置くテーマのページを含めて 5 ページ以内に収める
    static let all: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "paperplane.fill",
            title: "Discordへかんたん送信",
            message: "Webhookを使って、好きな名前・アイコンでDiscordのチャンネルにメッセージを送れます"
        ),
        OnboardingPage(
            systemImage: "link",
            title: "Webhook URLをコピー",
            message: "Discordのチャンネル設定から「連携サービス」→「ウェブフック」を開き、URLをコピーします"
        ),
        OnboardingPage(
            systemImage: "square.and.pencil",
            title: "貼り付けて送信",
            message: "コピーしたURLを貼り付けて、メッセージを入力したら「メッセージを送信！」を押すだけです"
        ),
        OnboardingPage(
            systemImage: "bookmark.fill",
            title: "よく使うURLは保存",
            message: "URL欄の横のブックマークから、保存したURLをすぐに呼び出せます"
        )
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24.0) {
            Spacer()

            Image(systemName: page.systemImage)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 128.0, height: 128.0)
                .background(
                    Circle()
                        .fill(Color.appSurface)
                )
                .accessibilityHidden(true)

            Text(page.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)

            Text(page.message)
                .font(.system(size: 17))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 32.0)
    }
}

/// オンボーディングの最後のページ。設定画面と同じテーマを選べ、選んだ瞬間にアプリ全体の配色が切り替わる。
/// 最初は今のテーマ（未設定ならダーク）を選んだ状態で、何も触らずに進めればそのまま
private struct OnboardingThemePageView: View {
    @AppStorage(AppTheme.userDefaultsKey) private var appTheme = AppTheme.dark.rawValue

    var body: some View {
        VStack(spacing: 24.0) {
            Spacer()

            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 128.0, height: 128.0)
                .background(
                    Circle()
                        .fill(Color.appSurface)
                )
                .accessibilityHidden(true)

            Text("テーマを選ぶ")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)

            Text("アプリの配色を選べます。「自動」は端末の外観設定に合わせて切り替わります。あとから設定でも変えられます")
                .font(.system(size: 17))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Picker("テーマ", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.localizedTitle)
                        .tag(theme.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("アプリのテーマ")

            Spacer()
        }
        .padding(.horizontal, 32.0)
    }
}

/// 今どのページにいるかを示すドット。TabView 標準のインジケーターは背景色によって見えにくいため自前で描く
private struct PageIndicator: View {
    let count: Int
    let selection: Int

    var body: some View {
        HStack(spacing: 8.0) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == selection ? Color.appAccent : Color.appTextSecondary.opacity(0.4))
                    .frame(width: index == selection ? 20.0 : 8.0, height: 8.0)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selection)
        .accessibilityElement()
        .accessibilityLabel(Text("\(selection + 1) / \(count)"))
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
