@AGENTS.md

# Claude Code 固有指示

この文書は Claude Code にだけ適用する。
共通ルールは冒頭で import した `AGENTS.md` を正本として扱う。

## 方針

判断が競合する場合は、安全 → 正しさ → 変更最小 → 可読性 → 速度 の順に従う。
zsh 設定ファイル 1 つの小さなリポジトリに過剰な仕組みを導入しない。

## 計画モード

仕様の解釈や設計判断が必要な場合、または影響範囲が不明な場合は、実装前に計画モードを開始する。
1 ファイル内の局所的な追加・修正では不要である。

## 設定ファイル

| ファイル | 用途 | Git 管理 |
|---|---|---|
| `.claude/settings.json` | 共有するプロジェクト設定（権限、コミット属性） | コミット対象 |
| `.claude/settings.local.json` | 絶対パスなどローカル環境固有の設定 | gitignored |
| `CLAUDE.local.md` | 個人用の追加指示 | gitignored |
| `.claude/skills/`・`.claude/scripts/` | Codex と共有するワークフロースキルと、Codex レビューのラッパー | コミット対象 |
| `.claude/worktrees/` | EnterWorktree が作るタスク worktree | gitignored |

Claude Code が共有設定へ権限を自動追加した場合は、コミット前に内容を確認し、
マシン固有のものは `.claude/settings.local.json` へ移す。ローカル設定をコミットしない。

## ワークフロースキル

一覧と用途は [.codex/README.md](.codex/README.md) にある。worktree で進めるタスクは
`/x-preflight` →（設計判断があれば `/x-deep-plan` → `/x-codex-review-plan`）→ 実装 →
`/x-codex-review-impl final` → `/x-ship` の順で使う。明示されたとき、または依頼に必要なときだけ使い、
すべての編集へ自動適用しない。Codex レビューのラッパーは `run_in_background: true` で起動して
完了通知を待つ。EnterWorktree のセッション内では `git -C` や `$(git …)` を含む複合コマンドが
拒否されるため、承認記録の作成と x-ship の Step 5 以降は、x-ship の「前提とルール」のとおり
ExitWorktree（`keep`）後にメインチェックアウトのセッションから実行する。

## レビューコマンド

| コマンド | 用途 |
|---|---|
| `/code-review` | 現在の変更差分を品質、回帰、検証の観点からレビューする |
| `/security-review` | `origin/HEAD` より先行するコミット済みの差分をセキュリティ観点でレビューする。未コミットの変更は対象外なので、コミット後・push 前に使う |
| `/x-codex-review-plan` | 実装計画を Codex CLI で敵対的にレビューする |
| `/x-codex-review-impl` | 未コミット変更とブランチ差分を Codex CLI で敵対的にレビューする。`final` は `/x-ship` の承認記録を作る |
