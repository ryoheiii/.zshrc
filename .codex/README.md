# Codex 向け案内

共通ルールは [AGENTS.md](../AGENTS.md) が正本である。
Codex 固有の規約のコピーは作らず、本書はスキルと設定の所在と扱いだけを記す。

## スキルの利用と編集

`.codex/skills` は `../.claude/skills` への symlink である。
このリポジトリの Codex スキルの変更依頼は、リンク先の共通スキルの編集として扱う。
Claude Code も使うため、特定モデルだけを前提にした指示にしない。

| スキル | 用途 |
|---|---|
| `x-preflight` | 実装前の作業環境と worktree の準備 |
| `x-deep-plan` | 設計上の未決事項を調査し、実装計画を作成 |
| `x-codex-review-plan` | 具体的な計画の外部レビュー |
| `x-codex-review-impl` | 差分の外部レビュー。`final` は ship の承認記録を作成 |
| `x-ship` | コミットから最終レビューゲート・`master` への fast-forward マージ・push・後片付けまで |

- Codex では `.codex/skills/<name>/SKILL.md` を読んで手順に従う
  （`~/.codex/prompts/` に汎用シムがあればそれ経由でも呼べる）。
- `SKILL.md` の適用条件でスキルを選び、用途に対応する参照だけを必要な時点で読む。
- 外部レビューは [.claude/scripts/codex-review.sh](../.claude/scripts/codex-review.sh) が
  `codex exec` を read-only サンドボックスで実行する。モデルと reasoning effort は
  `~/.codex/config.toml` の既定に従い、`CODEX_REVIEW_MODEL` / `CODEX_REVIEW_EFFORT` で上書きできる。
- レビューの成果物（prompt・reply・session）は `/tmp` に、final の承認記録と ship の状態は
  タスク worktree の Git 管理ディレクトリに置き、リポジトリへコミットしない。

## 設定

| ファイル | 用途 |
|---|---|
| [.codex/config.toml](config.toml) | 信頼済みチェックアウト向けの共有デフォルト（Git 管理） |
| `~/.codex/config.toml` | マシン固有の trust 判断、writable roots、モデル設定（リポジトリ外） |

[.codex/config.toml](config.toml) は、ユーザーの明示依頼により `alpha-autopilot-ai` と同じ
`approval_policy = "never"` / `sandbox_mode = "danger-full-access"` を設定している。
コマンドごとの承認プロンプトとファイル・ネットワークのサンドボックス制限を無効化するため、
`.codex/` 自身への書き込みも許可される。権限設定にかかわらず
[AGENTS.md](../AGENTS.md) の安全規約と、依頼範囲内の調査・編集・検証を確認待ちで止めない方針を守る。

設定はこのチェックアウトで次に開始する Codex セッションから反映される。
起動済みセッションには自動反映されない。CLI の起動オプションや管理ポリシーがある場合は、
そちらが優先される。承認付きの運用へ戻す場合は、このファイルの 2 値を
`approval_policy = "on-request"` / `sandbox_mode = "workspace-write"` に変更し、新しいセッションを開始する。
この 2 値の変更はユーザーが明示的に依頼した場合だけ行う。

設定の意味と優先順位は OpenAI 公式ドキュメントの
[Sandbox](https://learn.chatgpt.com/docs/sandboxing) と
[Config basics](https://learn.chatgpt.com/docs/config-file/config-basic) を参照する。

このディレクトリを初めて開くと Codex が trust を尋ねる。
trust したチェックアウトでだけ [.codex/config.toml](config.toml) の共有設定が有効になる。
