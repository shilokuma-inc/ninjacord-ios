---
description: GitHub Issue を実装して Simulator で手元確認できる状態にする（実装→ビルド→起動→目視）
argument-hint: <issue番号>
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Task
---

Issue #$ARGUMENTS を実装し、Simulator で手元確認できる状態にする。

手順:

1. **Issue 取得**: `gh issue view $ARGUMENTS` で本文・受け入れ条件を確認し、要約をユーザーに提示する。要件が不明瞭なら実装前に確認する。

2. **作業ブランチ**: `develop` を最新化し、`feat/issue-$ARGUMENTS`（fix 系なら `fix/issue-$ARGUMENTS`）を切る。
   ```sh
   git fetch origin && git switch develop && git pull && git switch -c feat/issue-$ARGUMENTS
   ```

3. **実装**: `swiftui-implementer` サブエージェントに Issue 内容を渡して実装させる。

4. **ビルド検証**: `ios-build-verifier` サブエージェントに Simulator ビルド・起動・スクショ確認をさせる。ビルドが失敗したら error 内容を implementer に戻して修正 → 再検証をループする（最大数回）。

5. **報告**: ユーザーに以下を提示して**ここで止まる**（PR 作成・マージはしない）:
   - 実装した変更の要約（ファイル一覧）
   - ビルド/起動の結果とスクリーンショット
   - 手元で確認してほしい操作
   - 問題なければ `/ship $ARGUMENTS` で PR 作成に進める旨

コミットは実装が固まった段階で1つにまとめる。commit message 末尾に必ず:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```
push はこの段階では任意（`/ship` 側で行う）。
