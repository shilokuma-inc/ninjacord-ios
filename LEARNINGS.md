# LEARNINGS（ninjacord-ios 固有）

このリポジトリで作業して分かった、ツールや環境の癖と回避策。全リポジトリ共通の知見は `~/.agents/LEARNINGS.md` に書く。

## App Store Connect への反映ワークフロー

- GitHub Actions の macOS ランナーの bash 3.2 は UTF-8 でないロケールで動くため、`$VAR（` のように変数名の直後に全角文字が続くと変数名の一部と見なされ、`set -u` で `unbound variable` になる。手元の Mac（UTF-8 ロケール）では再現しないので、シェルスクリプトやワークフローの `run` で全角文字を扱うときは必ず `${VAR}` で閉じる（Issue #400）。
- `Metadata/App Store` の dry-run は数十秒で終わり、App Store Connect の現在値と `AppStore/metadata/*.json` の差分を Job Summary に出す。反映先は `PREPARE_FOR_SUBMISSION` のバージョンだけなので、配信中の掲載文は変わらない。
- `Screenshots/App Store` は撮影に 30〜60 分かかる。ログは失敗したジョブ以外は完了まで取れない（`gh run view --log` は実行中のジョブでは空）。
