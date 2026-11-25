//
//  NinjacordShortcuts.swift
//  NinjacordApp
//

import AppIntents
import NinjacordFeature

/// ショートカットのアプリ・Spotlight・Siri に出す、おすすめのショートカット（Issue #700）。
/// アクション（`SendDiscordMessageIntent`）はパッケージにあるが、`AppShortcutsProvider` はパッケージに置くと
/// アプリの `Metadata.appintents` に入らないので、ここ（アプリのターゲット）に置く。
/// フレーズの言語ごとの文言は `en.lproj` / `ja.lproj` の `AppShortcuts.strings`（iOS 16 では String Catalog を使えない）
struct NinjacordShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendDiscordMessageIntent(),
            phrases: [
                "\(.applicationName)でDiscordに送信",
                "\(.applicationName)でメッセージを送信"
            ]
        )
    }
}
