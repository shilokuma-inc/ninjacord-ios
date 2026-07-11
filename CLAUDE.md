# Ninjacord iOS

Discord に Webhook / bot 経由でメッセージを送信できる iOS アプリ。

## プロジェクト基本情報

| 項目 | 値 |
| --- | --- |
| リポジトリ | `shilokuma-inc/ninjacord-ios` |
| デフォルトブランチ | `develop` |
| UI フレームワーク | SwiftUI |
| 言語 / Xcode | Swift 5 / Xcode 26.3 |
| Deployment Target | iOS 16.0 |
| バージョン | `MARKETING_VERSION` 1.5.0 |
| Bundle ID (本番) | `ml.mrs1669.discord-bot-helper` |
| App Store | https://apps.apple.com/jp/app/ninja-cord/id6498937487 |

## ビルド構成

- **`.xcodeproj` 直**（`.xcworkspace` は無い）。ビルド対象は常に `-project NinjacordApp.xcodeproj`。
- Scheme は2つ:
  - `NinjacordApp` … 本番
  - `NinjacordApp-STG` … STG（開発確認はこちらを優先）
- Configuration: `Debug` / `NinjacordApp-STG` / `Release`
- 依存は全て SPM: Firebase, Alamofire, Google Mobile Ads (AdMob), LicenseList
- SwiftLint 使用（CI で `brew install swiftlint`）

## ディレクトリ

- `NinjacordApp/` … アプリ本体（SwiftUI View / ViewModel）
  - `SettingMessage/` … メッセージ送信画面
  - `Setting/` … 設定・ライセンス・プライバシー
  - `AdMob/` … 広告
  - `Extension/`, `Common/` … 共通部品
- `ci_scripts/ci_post_clone.sh` … CI 前処理（SwiftLint 導入等）
- `.github/workflows/` … build / archive / upload（`develop`・`master` への push で発火）

## ブランチ運用

- 作業は `develop` 起点でフィーチャーブランチを切る（例: `feat/xxx`, `fix/xxx`）。
- `develop` / `master` への push で GitHub Actions（build → archive → upload）が発火する。
- PR のマージ先は原則 `develop`。

## 開発ワークフロー（Claude Code）

1. `/dev-issue <番号>` … Issue を取得 → 実装 → Simulator ビルド&起動 → 手元で確認
2. 手元確認で問題なければ `/ship <番号>` … PR 作成 → レビュー → マージ
3. `develop` マージ後は Actions が自動で App Store Connect アップロードまで実施

## コーディング方針

- SwiftUI の作法は `ios-swiftui` スキルに従う（State 管理 / View 分割 / Swift Concurrency）。
- リリース・署名・TestFlight は `ios-release` スキルを参照する。
- 変更は最小限、周辺の既存コードのスタイル（命名・コメント密度）に合わせる。
