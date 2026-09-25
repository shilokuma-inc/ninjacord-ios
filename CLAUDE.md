# Ninjacord iOS

Discord に Webhook 経由でメッセージを送信できる iOS アプリ。bot token による送信には現時点で対応していない（Discussion #260 で見送り、Issue #308 で先送り）。

## プロジェクト基本情報

| 項目 | 値 |
| --- | --- |
| リポジトリ | `shilokuma-inc/ninjacord-ios` |
| デフォルトブランチ | `develop` |
| UI フレームワーク | SwiftUI |
| 言語 / Xcode | Swift 5 / Xcode 26.3 |
| Deployment Target | iOS 16.0 |
| バージョン | `MARKETING_VERSION` 2.0.0 |
| Bundle ID (本番) | `ml.mrs1669.discord-bot-helper` |
| App Store | https://apps.apple.com/jp/app/ninja-cord/id6498937487 |

## ビルド構成

- **`.xcodeproj` 直**（`.xcworkspace` は無い）。ビルド対象は常に `-project NinjacordApp.xcodeproj`。
- アプリ本体のコードは **ローカル Swift Package `NinjacordPackage`**（`NinjacordPackage/Package.swift`）に置く。`NinjacordApp` ターゲットは `@main` と各種リソース（Assets / Info.plist / xcstrings 等）だけを持つ薄いシェル。
  - `.swift` ファイルの追加・削除は `NinjacordPackage/Sources/NinjacordFeature/` 配下で行う。**`.xcodeproj` に差分は出ない**（Issue #211）。
  - 外部依存（Firebase 等）も `Package.swift` の `dependencies` で管理する。バージョンのピンは従来どおり `NinjacordApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`。
  - `NinjacordApp` ターゲットから参照する型（`MainView` / `AppDelegate` / `AppTheme`）だけ `public`。それ以外は internal のまま。
- Scheme は3つ:
  - `NinjacordApp` … 本番
  - `NinjacordApp-STG` … STG（開発確認はこちらを優先）
  - `NinjacordApp-Screenshot` … App Store 掲載用スクリーンショット撮影用。広告を表示しない（`ADS_ENABLED = NO`）
- Configuration: `Debug` / `NinjacordApp-STG` / `NinjacordApp-Screenshot` / `Release`
- 広告の表示可否は Configuration の `ADS_ENABLED` → Info.plist の `AdsEnabled` → `AdConfiguration.isEnabled` で切り替える
- 依存は全て SPM（`NinjacordPackage/Package.swift` で宣言）: Firebase, Alamofire, Google Mobile Ads (AdMob), LicenseList
- SwiftLint 使用（CI で `brew install swiftlint`）

## ディレクトリ

- `NinjacordApp/` … アプリターゲット（`@main` の `NinjacordApp.swift` とリソース: Assets / Info.plist / Localizable.xcstrings / entitlements 等）
- `NinjacordPackage/` … ローカル Swift Package（アプリ本体のコード）
  - `Package.swift` … ターゲット定義と外部依存
  - `Sources/NinjacordFeature/` … SwiftUI View / ViewModel
    - `SettingMessage/` … メッセージ送信画面
    - `Setting/` … 設定・ライセンス・プライバシー
    - `AdMob/` … 広告
    - `Extension/`, `Common/` … 共通部品
- `ci_scripts/ci_post_clone.sh` … CI 前処理（SwiftLint 導入等）
- `.github/workflows/` … build / archive / upload（発火するブランチは「ブランチ運用」参照）

## ブランチ運用

- 作業は `develop` 起点でフィーチャーブランチを切る（例: `feat/xxx`, `fix/xxx`）。
- push で発火する GitHub Actions は以下のとおり。

  | push 先 | 発火するワークフロー |
  | --- | --- |
  | フィーチャーブランチ | Build / Archive |
  | `develop` | Build/develop / Upload/develop（App Store Connect へアップロード） |
  | `release/**` | Build / Upload/release（App Store Connect へアップロード） |
  | `master` | Build/master のみ（upload は走らない） |

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

### PR タイトル

- **`【TYPE】日本語の説明`**（`【】` は全角、TYPE は半角大文字。例: `【FEAT】メッセージ送信ボタンを追加`）
- TYPE はコミット type を大文字化したもの。原則、対応する Issue のタイトル（【FEAT】等）と同じ種別にする。
- PR 本文は `.github/pull_request_template.md` の雛形に従う。

### PR 本文のスクリーンショット

UI の見た目が変わる変更では、Before / After のスクリーンショットを PR 本文に添付する。

- 画像は PR の diff を汚さないよう、**`assets/issue-<Issue番号>` ブランチ**に置き、PR 本文からは raw URL で参照する。
  - 例: `https://raw.githubusercontent.com/shilokuma-inc/ninjacord-ios/assets/issue-335/335/before.png`
  - このブランチは `.github/workflows/cleanup-assets-branch.yml` が PR のマージ時に自動削除する。ブランチ名がこの規約から外れると削除されないので注意。
- Before / After は表で横に並べ、同一条件（同じ端末・OS・テーマ・データ状態）で撮影する。
- 影響する画面が複数ある場合は画面ごとに用意する。新規画面で Before が無い場合は「なし」と書く。
- プレースホルダーのコメント（`<!-- 修正前のスクリーンショットを添付 -->`）を残したまま PR を出さない。

## コーディング方針

- SwiftUI の作法は `ios-swiftui` スキルに従う（State 管理 / View 分割 / Swift Concurrency）。
- リリース・署名・TestFlight は `ios-release` スキルを参照する。
- 変更は最小限、周辺の既存コードのスタイル（命名・コメント密度）に合わせる。

## コードレビュー観点

Claude のセルフレビュー（`swiftui-reviewer`）と CodeRabbit の PR レビューは、どちらもこの観点に従う。`ios-swiftui` スキルの一般論と食い違う場合は、こちらを優先する。

1. **正しさ**: ロジックの誤り、境界条件、Optional の強制アンラップ、既存挙動のリグレッション。
2. **iOS 16 互換**: Deployment Target は iOS 16.0。`@Observable` / `@Bindable` / `@Entry` など iOS 17 以降の API を `#available` なしで使わない。
3. **State 管理**: 状態を持つクラスは `ObservableObject` にする。生成する側は `@StateObject`、受け取る側は `@ObservedObject` を使う。`@State` には値型だけを入れる。子 View で `@StateObject` を作り直さない。
4. **Concurrency**: UI を更新するクラスには `@MainActor` を付ける。View のライフサイクルに連動する非同期処理は `Task { }` より `.task { }` を優先する。
5. **SwiftUI の作法**: 画面遷移は `NavigationStack`（`NavigationView` は使わない）。Preview は `#Preview` マクロで書く。
6. **アクセス修飾子**: `NinjacordApp` ターゲットから参照する型（`MainView` / `AppDelegate` / `AppTheme`）以外は internal のままにする。
7. **スタイル**: 既存コードとの一貫性、SwiftLint 違反。
