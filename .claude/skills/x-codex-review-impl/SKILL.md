---
name: x-codex-review-impl
description: 未コミット変更とブランチ差分を Codex CLI で敵対的にレビューする。実装レビューの依頼、または x-ship の final ゲートで使う。
allowed-tools: Bash, Read, Write, Grep, Glob
---

作業中のタスク worktree のルートで、未コミット変更とベースブランチとの差分を合わせて
レビューする。master 上では実行しない。
レビューだけの依頼では差分・指摘の報告で完了し、実装や index を変更しない。
修正ループは、修正までの依頼や x-ship など、既に実装の修正が承認されている場合に使う。

## モード

- `step`（既定）: dirty tree でも実行できる。承認記録は作らない。
- `final`: x-ship 用のブランチ全体のレビュー。
  この場合だけ [最終承認の契約](references/final-approval.md) を先に読み、既存の承認記録を
  失効させてから、clean tree とレビューした HEAD に結びつく承認記録を扱う。
  step はこのゲートの代わりにならない。Claude Code で EnterWorktree の worktree にいる場合は、
  final を始める前に ExitWorktree（`keep`）で戻り、以降の手順を `cd <worktree> &&` 付きで実行する。

## レビュー材料

一意な `REVIEW_ID` を使い、以下を `/tmp/x-impl-<REVIEW_ID>/` に保存する。

- `git status --porcelain` と `git diff HEAD`（未コミット変更）。
- ベースは `origin/master` があればそれ、なければ `master`。
  `git diff --name-status "$BASE_BRANCH"...HEAD` と `git diff "$BASE_BRANCH"...HEAD`。
- ベースと HEAD の SHA、`git rev-list --left-right --count "$BASE_BRANCH"...HEAD` による
  ahead/behind、`git merge-base --is-ancestor "$BASE_BRANCH" HEAD` の結果。
  ベース未統合なら step の報告に明記し、final は統合・関連検証が済むまで承認しない。
- ユーザーの要求・制約と直近の検証結果。未収集ならその旨を明記する。

未追跡の新規ファイルは `git diff HEAD` に出ないため、その内容を別途渡す。
新規ファイルを含め両スコープとも空ならレビュー対象なしと報告する。

## 外部レビュー

プロンプトに上記の材料（内容または絶対パス）を渡し、承認を前提にせず欠陥を探す立場で、
要件漏れ・不具合・退行・検証不足・両差分間の不整合を根拠付きで指摘させる。
指摘が属する範囲を UNCOMMITTED / BRANCH / BOTH で示し、最終行を
`VERDICT: APPROVED` または `VERDICT: REVISE` と指定する。

対象に関係する規約を参照させる。`_zshrc` の変更では [AGENTS.md](../../../AGENTS.md) の
「zsh 設定の規約」（節の配置、日本語コメント、非対話ガードの前後、`__zshrc_has` と
`if … fi` によるガード、`$HOME` 表記、依存する定義、README.md の追従）と、
「検証と完了条件」の回帰テスト（`bats test`）の結果を確認させる。
エージェント設定・文書の変更では参照先の実在と文書間の整合性を確認させる。

```bash
bash .claude/scripts/codex-review.sh /tmp/x-impl-<REVIEW_ID>/prompt.txt /tmp/x-impl-<REVIEW_ID>/reply.md /tmp/x-impl-<REVIEW_ID>/session.txt
```

プレースホルダーは実際の値へ置換する。ラッパーは read-only で実行し、モデル・effort は
`~/.codex/config.toml` の既定に従う。
Claude Code は `run_in_background: true` で起動して完了通知を待つ（sleep ポーリングはしない）。
Codex は通常のシェル実行でよい。
終了コード 0、新しい非空 reply、有効な session ID、指定形式の verdict を確認する。
失敗・不明な verdict は承認扱いにしない。usage limit・rate limit・認証失敗は自動リトライしない。

## 修正と再レビュー

レビューだけの依頼なら REVISE と指摘を報告し、ここから先の編集・コミットは行わない。

1. REVISE の指摘に対して実質的な修正を行う。
2. [AGENTS.md](../../../AGENTS.md) の「検証と完了条件」に従い修正範囲を検証し、結果を保存する。
   文書だけなら参照・整合性検査でよく、`bats test` を要求しない。
3. final は最終承認の契約に従って修正をコミットし、clean tree に戻してから材料を取り直す。
4. 更新した材料と検証結果を渡し、同じラッパーの第 3 引数以降を `--resume <SESSION_ID>` とする。
   既出指摘を先に解決・処置し、新たな広域探索を始めないよう依頼する。
   新規指摘は具体的根拠のある High/Critical に限る。
   すべて解決し、新たな重大問題がなければ `VERDICT: APPROVED` を返させる。

初回を含め最大 3 ラウンド。未解決なら指摘を報告して停止する。
完了時は範囲・ベース、主要指摘と修正、検証結果、verdict、session ID、残るリスクを報告する。
final では承認記録のパスも示す。
