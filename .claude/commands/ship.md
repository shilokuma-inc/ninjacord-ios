---
description: 手元確認済みの変更を PR 作成→レビュー→マージする（マージ後は Actions が upload まで自動実行）
argument-hint: <issue番号>
allowed-tools: Bash, Read, Grep, Glob, Task
---

Issue #$ARGUMENTS の変更を PR にしてマージまで進める。**手元での動作確認が済んでいることが前提**。

手順:

1. **事前チェック**: `git status` と `git diff origin/develop...HEAD` で変更内容を確認。未コミットがあればコミットする（message 末尾に `Co-Authored-By: Claude <noreply@anthropic.com>`）。

2. **レビュー**: `swiftui-reviewer` サブエージェントで diff をレビュー。🔴要修正があれば直してから進む。

3. **push & PR 作成**:
   ```sh
   git push -u origin HEAD
   gh pr create --base develop --fill --body "Closes #$ARGUMENTS

   <変更概要 / 手元確認結果 / スクリーンショット言及>

   🤖 Generated with [Claude Code](https://claude.com/claude-code)"
   ```
   PR の URL をユーザーに提示する。

4. **CI 確認**: `gh pr checks --watch` で Actions（build 等）の結果を待つ。失敗したら原因を報告して止まる。

5. **マージ確認**: マージは外向きの不可逆操作。**ユーザーに最終承認を得てから**実行する:
   ```sh
   gh pr merge --squash --delete-branch
   ```

6. **マージ後**: `develop` への push で archive/upload の Actions が発火する旨を伝える。TestFlight 外部配信まで行う場合は `ios-release` スキルに従う（ビルド番号採番・外部テスターグループ割り当て）。

注意:
- `git push`・PR 作成・マージはいずれも外向き操作。push と PR 作成は本コマンドの範囲だが、**マージ前には必ずユーザー確認を挟む**。
- ベースブランチは常に `develop`。
