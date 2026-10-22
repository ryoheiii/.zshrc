# Codex 向け案内

共通ルールは [AGENTS.md](../AGENTS.md) が正本である。
Codex 固有の規約のコピーは作らず、本書は設定の所在と扱いだけを記す。
`.codex/skills/<name>/SKILL.md` を前提とする `/x-*` のスラッシュコマンドは、
スキルを置かないこのリポジトリでは対象外である。

## 設定

| ファイル | 用途 |
|---|---|
| [.codex/config.toml](config.toml) | 信頼済みチェックアウト向けの共有デフォルト（Git 管理） |
| `~/.codex/config.toml` | マシン固有の trust 判断、writable roots、モデル設定（リポジトリ外） |

[.codex/config.toml](config.toml) は現在コメントだけで、承認ポリシーとサンドボックスは
`~/.codex/config.toml` と Codex の既定に従う。`.emacs.d` と `alpha-autopilot-ai` で有効な
`approval_policy = "never"` / `sandbox_mode = "danger-full-access"` は、承認プロンプトと
サンドボックス保護を無効化し、`.codex/` 自身への書き込みも防げない。
この 2 値を有効化するかどうかと、その後の変更は、ユーザーが明示的に依頼した場合だけ行う。
権限設定にかかわらず [AGENTS.md](../AGENTS.md) の安全規約を守る。

このディレクトリを初めて開くと Codex が trust を尋ねる。
trust したチェックアウトでだけ [.codex/config.toml](config.toml) の共有設定が有効になる。
