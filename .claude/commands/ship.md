---
description: 手元確認済みの変更を PR 作成→レビュー→マージする（マージ後は Actions が upload まで自動実行）
argument-hint: <issue番号>
allowed-tools: Bash, Read, Grep, Glob, Task
---

Issue #$ARGUMENTS の変更を PR にしてマージまで進める。**手元での動作確認が済んでいることが前提**。

手順:

1. **事前チェック**: `git status` と `git diff origin/develop...HEAD` で変更内容を確認。未コミットがあれば **`[type] 日本語の説明`** 形式でコミットする（粒度は CLAUDE.md「コミット / PR 規約」に従い論理単位で分ける）。

2. **レビュー**: `swiftui-reviewer` サブエージェントで diff をレビュー。🔴要修正があれば直してから進む。

3. **push & PR 作成**: タイトルは **`【TYPE】日本語の説明`**（TYPE は Issue の種別に対応: FEAT/FIX/REFACTOR/CHORE/UPDATE 等）。本文は `.github/pull_request_template.md` の雛形（概要 / 関連するISSUE / 詳細 / 動作確認）に沿って埋める。
   ```sh
   git push -u origin HEAD
   gh pr create --base develop --title "【TYPE】<日本語の説明>" --body "## 概要 (Abstract)
   <何を・なぜ>

   ## 関連するISSUE
   - resolved #$ARGUMENTS

   ## 詳細 (Detail)
   <主な変更点>

   ## 動作確認 (Verification)
   - [x] Simulator でビルド・起動を確認した
   - [x] 想定通りの挙動を目視確認した
   <UI 変更はスクリーンショットを添付>

   🤖 Generated with [Claude Code](https://claude.com/claude-code)"
   ```
   PR の URL をユーザーに提示する。

4. **CI 確認**: `gh pr checks --watch` で Actions（build 等）と `CodeRabbit` チェックの結果を待つ。`CodeRabbit` は「Review completed」になればレビュー完了。Actions が失敗したら原因を報告して止まる。

5. **CodeRabbit の指摘対応**: 指摘を取得し、1件ずつ対応を決める。
   ```sh
   # 行コメント（id / path / line / body）
   gh api repos/shilokuma-inc/ninjacord-ios/pulls/<PR番号>/comments \
     -q '.[] | select(.user.login=="coderabbitai[bot]") | {id, path, line, body}'
   # レビュー本文（Nitpick など、行コメントにならない指摘が折りたたまれている）
   gh api repos/shilokuma-inc/ninjacord-ios/pulls/<PR番号>/reviews \
     -q '.[] | select(.user.login=="coderabbitai[bot]") | .body'
   ```
   - 妥当な指摘は修正し、論理単位でコミットして push する（push 後は CodeRabbit が差分を自動で再レビューする）。
   - 対応したら、そのコメントに**返信**する（新規コメントは立てない）。返信には修正コミットへのリンクを `[短縮ハッシュ](https://github.com/shilokuma-inc/ninjacord-ios/commit/<フルハッシュ>)` の形式で付ける。
     ```sh
     gh api repos/shilokuma-inc/ninjacord-ios/pulls/<PR番号>/comments/<コメントid>/replies -f body="..."
     ```
   - 対応しない・別 PR に回す場合も、その理由を返信する。意図的な実装への誤指摘なら、理由を書いて返信すると CodeRabbit が Learnings として学習し、次回以降は同じ指摘をしなくなる。
   - 判断に迷う指摘（仕様に関わる、影響範囲が大きい等）は自分で決めず、ユーザーに確認する。
   - 修正を push したら 4. に戻り、CI と再レビューの結果を確認する。
   - 対応結果（修正した指摘 / 対応しなかった指摘と理由）を一覧にしてユーザーに報告する。
   - 無料プランのレビュー回数は 1 時間に 10 回まで。細かい修正は 1 回の push にまとめる。

6. **マージ確認**: マージは外向きの不可逆操作。**ユーザーに最終承認を得てから**実行する:
   ```sh
   gh pr merge --squash --delete-branch
   ```

7. **マージ後**: `develop` への push で archive/upload の Actions が発火する旨を伝える。TestFlight 外部配信まで行う場合は `ios-release` スキルに従う（ビルド番号採番・外部テスターグループ割り当て）。

注意:
- `git push`・PR 作成・マージはいずれも外向き操作。push と PR 作成は本コマンドの範囲だが、**マージ前には必ずユーザー確認を挟む**。
- ベースブランチは常に `develop`。
