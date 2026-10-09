# LEARNINGS（ninjacord-ios 固有）

このリポジトリで作業して分かった、ツールや環境の癖と回避策。全リポジトリ共通の知見は `~/.agents/LEARNINGS.md` に書く。

## App Store Connect への反映ワークフロー

- macOS の bash 3.2 は、`$VAR（` のように変数名の直後に全角文字が続くと、ロケール依存の文字判定で全角文字の先頭バイトを変数名の一部と見なすことがあり、`set -u` で `unbound variable` になる。GitHub Actions の macOS ランナーで再現し、手元の Mac では再現しないことがあるため、ローカルで通っても安心できない。シェルスクリプトやワークフローの `run` で全角文字を扱うときは必ず `${VAR}` で閉じる（Issue #400）。
- `Metadata/App Store` の dry-run は数十秒で終わり、App Store Connect の現在値と `AppStore/metadata/*.json` の差分を Job Summary に出す。反映先は `PREPARE_FOR_SUBMISSION` のバージョンだけなので、配信中の掲載文は変わらない。
- `Screenshots/App Store` は撮影に 30〜60 分かかる。ログは失敗したジョブ以外は完了まで取れない（`gh run view --log` は実行中のジョブでは空）。

## ビルド・依存（Swift Package Manager）

- firebase-ios-sdk のプロダクト（`FirebaseFirestore` など）を `Package.swift` から外しても、`Package.resolved` は変わらない。SwiftPM は使うプロダクトに関係なく firebase-ios-sdk が宣言しているパッケージ依存（abseil・gRPC・leveldb・app-check など）をすべてピンするため。ピンを手で消しても `xcodebuild -resolvePackageDependencies` が同じバージョンで戻し、書式を v2（`originHash` なし）に書き換えてしまうので、手で消さない。外したプロダクトがアプリに入らなくなったことは、ビルドした `.app` の `Frameworks/` とリソースバンドルで確かめる（Issue #466）。
- LicenseList のビルドツールプラグイン（`PrepareLicenseList`）は、既定では DerivedData の中の `SourcePackages` を探す。`-clonedSourcePackagesDirPath` で依存の置き場所を DerivedData の外にするときは、`xcodebuild` に環境変数 `PLL_SOURCE_PACKAGES_PATH` でその絶対パスを渡す。渡さないと `SourcePackages not found` でビルドが落ちる。依存を DerivedData ごとに取り直しても避けられる（Issue #460）。
- 依存を外したあとに `xcodebuild -resolvePackageDependencies` が解決し直すと、`Package.resolved` を v2（`originHash` なし）で書き直すことがある（Xcode 26.6）。`Package.swift` から直接の依存を外したときは、そのピンだけを手で消した v3 のファイルにしておけば、解決し直しても書き換えられない。消したあとのピンが Xcode の解決結果と同じかは、v2 で書かせたファイルとピンを比べて確かめる（Issue #471）。
- LicenseList の一覧は `SourcePackages/workspace-state.json` に載っているパッケージから作るので、依存を外しても、前から使っている DerivedData では外した依存が一覧に残ることがある。一覧から消えたかは、新しい DerivedData で依存を取り直して確かめる（CI は `Package.resolved` が変わるとキャッシュのキーが変わり、取り直すので消える）（Issue #471）。
