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
| バージョン | `MARKETING_VERSION` 1.5.1 |
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

## コミット / PR 規約

人間・Claude いずれの手作業でも本規約に従うこと。

### type 一覧

既存の Issue テンプレート（`.github/ISSUE_TEMPLATE/`）の分類に揃える。基本はこの5種。

| type | 用途 | 対応 Issue タイトル |
| --- | --- | --- |
| `feat` | 新機能・機能追加 | 【FEAT】 |
| `fix` | バグ修正 | 【FIX】 |
| `refactor` | 挙動を変えない内部改善 | 【REFACTOR】 |
| `chore` | 雑務（依存更新・設定・CI 等） | 【CHORE】 |
| `update` | バージョンアップ | 【UPDATE】 |

補助的に `docs` / `test` / `ci` / `perf` / `style` を使ってもよい（明確に該当する場合のみ）。

### コミットメッセージ

- 件名: **`[type] 日本語の説明`**（type は半角小文字。例: `[feat] メッセージ送信ボタンを追加`）
- 説明は「何をしたか」を簡潔に。必要なら空行の後に本文で「なぜ」を書く。
- **粒度**: 1コミット＝1つの論理的変更。人間がコミット単位でレビューして意味が追える単位に分け、無関係な変更を同じコミットに混ぜない（例: 「機能追加」と「既存のリネーム」は別コミット）。
- Claude が作成したコミットは末尾に `Co-Authored-By: Claude <noreply@anthropic.com>` を付ける。

### PR タイトル

- **`【TYPE】日本語の説明`**（`【】` は全角、TYPE は半角大文字。例: `【FEAT】メッセージ送信ボタンを追加`）
- TYPE はコミット type を大文字化したもの。原則、対応する Issue のタイトル（【FEAT】等）と同じ種別にする。
- PR 本文は `.github/pull_request_template.md` の雛形に従う。

## コーディング方針

- SwiftUI の作法は `ios-swiftui` スキルに従う（State 管理 / View 分割 / Swift Concurrency）。
- リリース・署名・TestFlight は `ios-release` スキルを参照する。
- 変更は最小限、周辺の既存コードのスタイル（命名・コメント密度）に合わせる。
