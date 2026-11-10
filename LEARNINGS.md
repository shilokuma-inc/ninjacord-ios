# LEARNINGS（ninjacord-ios 固有）

このリポジトリで作業して分かった、ツールや環境の癖と回避策。全リポジトリ共通の知見は `~/.agents/LEARNINGS.md` に書く。

## App Store Connect への反映ワークフロー

- macOS の bash 3.2 は、`$VAR（` のように変数名の直後に全角文字が続くと、ロケール依存の文字判定で全角文字の先頭バイトを変数名の一部と見なすことがあり、`set -u` で `unbound variable` になる。GitHub Actions の macOS ランナーで再現し、手元の Mac では再現しないことがあるため、ローカルで通っても安心できない。シェルスクリプトやワークフローの `run` で全角文字を扱うときは必ず `${VAR}` で閉じる（Issue #400）。
- `Metadata/App Store` の dry-run は数十秒で終わり、App Store Connect の現在値と `AppStore/metadata/*.json` の差分を Job Summary に出す。反映先は `PREPARE_FOR_SUBMISSION` のバージョンだけなので、配信中の掲載文は変わらない。
- GitHub Actions は Secrets の値を、どこに出てもログで `***` に伏せる。審査の連絡先の Secrets（`APP_REVIEW_CONTACT_FIRST_NAME` / `_LAST_NAME`）を渡す `Metadata/App Store` では、同じ名前を含む著作権（`2024 Takumi Muraishi`）の差分が `2024 *** ***` と出る。値の食い違いを確かめるときは、伏せ字の前後（年や `©` の有無）で見る（Issue #628）。
- `Screenshots/App Store` は撮影に 30〜60 分かかる。ログは失敗したジョブ以外は完了まで取れない（`gh run view --log` は実行中のジョブでは空）。
- クリエイティブアセットの書き出し（`Tools/render_creative_assets.sh`）に使う 6.9 inch の画面は、`Screenshots/App Store` の成果物 `screenshots-APP_IPHONE_67` を `gh run download` で取れば、手元で撮り直さずに済む。最新の成功した実行が一部の画面サイズだけの撮り直しで 6.9 inch を含まないことがある（2026-11-07 は 6.3 inch だけ）。その前の実行が失敗でも、6.9 inch のジョブが成功していれば成果物は使える（`gh run view <id> --json jobs` で確かめる）。CI で撮った画面には Dynamic Island が写っていて、2026-11-06 に手元の `Tools/capture_screenshots.sh` で撮った画面には写っていなかったので、どちらで書き出したかで端末の上部の見た目が変わる（Issue #641）。

## ビルド・依存（Swift Package Manager）

- firebase-ios-sdk のプロダクト（`FirebaseFirestore` など）を `Package.swift` から外しても、`Package.resolved` は変わらない。SwiftPM は使うプロダクトに関係なく firebase-ios-sdk が宣言しているパッケージ依存（abseil・gRPC・leveldb・app-check など）をすべてピンするため。ピンを手で消しても `xcodebuild -resolvePackageDependencies` が同じバージョンで戻し、書式を v2（`originHash` なし）に書き換えてしまうので、手で消さない。外したプロダクトがアプリに入らなくなったことは、ビルドした `.app` の `Frameworks/` とリソースバンドルで確かめる（Issue #466）。
- LicenseList のビルドツールプラグイン（`PrepareLicenseList`）は、既定では DerivedData の中の `SourcePackages` を探す。`-clonedSourcePackagesDirPath` で依存の置き場所を DerivedData の外にするときは、`xcodebuild` に環境変数 `PLL_SOURCE_PACKAGES_PATH` でその絶対パスを渡す。渡さないと `SourcePackages not found` でビルドが落ちる。依存を DerivedData ごとに取り直しても避けられる（Issue #460）。
- 依存を外したあとに `xcodebuild -resolvePackageDependencies` が解決し直すと、`Package.resolved` を v2（`originHash` なし）で書き直すことがある（Xcode 26.6）。`Package.swift` から直接の依存を外したときは、そのピンだけを手で消した v3 のファイルにしておけば、解決し直しても書き換えられない。消したあとのピンが Xcode の解決結果と同じかは、v2 で書かせたファイルとピンを比べて確かめる（Issue #471）。
- LicenseList の一覧は `SourcePackages/workspace-state.json` に載っているパッケージから作るので、依存を外しても、前から使っている DerivedData では外した依存が一覧に残ることがある。一覧から消えたかは、新しい DerivedData で依存を取り直して確かめる（CI は `Package.resolved` が変わるとキャッシュのキーが変わり、取り直すので消える）（Issue #471）。

## SwiftUI

- `List` の行（`Button` など）に付けた `fullScreenCover` の中身は、テーマ（`@AppStorage` の変更で親の body が評価し直される）や端末の外観が変わると作り直され、中の `@State` が初期値に戻る（iOS 26.5 の Simulator で確認）。ルートの `TabView` に付けた `fullScreenCover`（`MainView`）では作り直されなかった。表示中に保ちたい状態は、出す側の `@State` で持って `Binding` で渡す（2026-10-29、Issue #608）。
- 表示中の `fullScreenCover` の中は、後からウィンドウの `overrideUserInterfaceStyle` やルートの `preferredColorScheme` を変えても配色が切り替わらない（iOS 26.5 の Simulator で確認）。中の View に `preferredColorScheme` を付けるだけでは「自動」（`nil`）で端末の外観に戻らないので、表示中の画面（presented な hosting controller）の `overrideUserInterfaceStyle` も書き換える（`PresentedThemeApplier`、Issue #615）。
- `safeAreaInset(edge: .top)` を付けた View の中の `GeometryReader` は、inset の分を除いた高さを受け取る。その中の `ScrollView` は inset の裏まで伸び、中身は inset の View の下を通ってスクロールする（iOS 26.5 の Simulator で確認）。inset の View の背景に `Color.appBackground.ignoresSafeArea(edges: .top)` を付ければステータスバーの裏まで覆えるが、Issue #620 の送信画面のプレビューのパネルは透かす設計（Liquid Glass / Material）にした。
- その `ScrollView` はステータスバーの裏まで伸びるので、中身が inset の View より上まで来ると、ステータスバーの位置に出る。中身が画面より低いと、下端までスクロールしたときに中身の先頭がそこに残る（先頭の位置 ≒ 画面の高さ − 下端の inset − 中身の高さ。送信画面で送信者を閉じると 6.3 inch で起きた）。inset の View を透かしたままステータスバーの裏だけを覆うには、inset の View の `.background(alignment: .top)` に、高さ 0 の View に `.background(Color.appBackground, ignoresSafeAreaEdges: .top)` を付けたものを置く。高さ 0 の `Color.appBackground` に `.ignoresSafeArea(edges: .top)` を付けるだけでは、ステータスバーの裏まで伸びなかった（iOS 26.5 の Simulator、Issue #623）。
- `.xcodeproj` の `INFOPLIST_KEY_UIUserInterfaceStyle = Light` があると、`overrideUserInterfaceStyle = .unspecified` でも端末の外観に関係なくライトになる。テーマの「自動」を確かめるときは、ビルドした `.app` の `Info.plist` にこのキーが無いことも見る（Issue #615）。

## ローカライズチェック（Tools/check_localizations.py）

- Xcode 既定の DerivedData（`~/Library/Developer/Xcode/DerivedData/NinjacordApp-*`）を `--derived-data` に渡すと、別の Configuration の古いビルドや、コードがまだ `NinjacordApp` ターゲットにあった頃の `.stringsdata` まで拾い、今は無い文言（`埋め込みタイトルを入れてください` など）を未登録と報告する。手元で確かめるときは、そのビルドで書き出された `Debug-iphonesimulator` の `.stringsdata`（`NinjacordFeature.build` のものと、アプリターゲットは `NinjacordApp.stringsdata` だけ）を別のディレクトリに同じ階層で集めて渡す。CI は毎回新しい DerivedData なので起きない（Issue #620）。

## Simulator での確認

- Debug ビルドの広告（AdMob のテスト広告）は、起動のたびに出る中身も高さも変わる。撮影モードで変更前と変更後のスクリーンショットを見比べるときは、広告の位置と、広告の高さが変わったぶんずれる部分（テンプレート一覧のネイティブ広告の下など）は差とみなさない。広告を写さずに比べたいなら `NinjacordApp-Screenshot` の scheme でビルドする（Issue #476）。
- 埋め込みのフィールドなど Pro 限定の項目は、Xcode から実行しないと StoreKit の設定ファイル（`NinjacordPro.storekit`）が効かず Pro にできないので、`xcodebuild` でビルドして `simctl` で起動したアプリでは画面から入力できない。その状態の画面を確かめるときは、テンプレートを UserDefaults に書いてから送信画面の「テンプレート」で呼び出す。インストールのあと、起動する前に `xcrun simctl spawn <端末> defaults write ml.mrs1669.discord-bot-helper messageTemplates -data <JSON の 16 進>`（JSON は `MessageTemplate` の配列）で書けば読み込まれた。`hasCompletedOnboarding -bool YES` も書けばチュートリアルを飛ばせる（Issue #637）。

## リリース

- 審査対応などで `release/vX.Y.Z` に直接マージした修正は、`develop` に自動では戻らない（v2.0.0 の ATT の修正 #437・#453 が抜けていた）。リリース後に `master` へ反映するときは、`git fetch origin` で remote-tracking の参照を最新にしてから `git log origin/develop..origin/release/vX.Y.Z` で release にだけあるコミットを確かめ、あれば release を `develop` にもマージする（#505）。
- そのバージョンが承認されたあとに同じ `MARKETING_VERSION` のビルドを上げると、アップロード自体は成功するが、App Store Connect の取り込みで ITMS-90186（Invalid Pre-Release Train）/ ITMS-90062（承認済みより高い CFBundleShortVersionString が必要）のメールが来て弾かれる。v2.2.0 では、release を切ったあとも develop が 2.2.0 のままで、承認後の develop へのマージで起きた。承認の前に develop の `MARKETING_VERSION` を次のバージョンに上げておき、release を develop に戻すのはそのあとにする（#634）。
