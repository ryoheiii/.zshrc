---
name: x-preflight
description: 実装前にタスク専用 worktree と検証環境を準備する。worktree で作業する依頼や、x-ship で ship する予定のタスクの開始時に使う。
allowed-tools: Bash, Read, Grep, Glob
---

実装を安全に開始できる環境を準備し、READY / BLOCKED と根拠を報告する。
[AGENTS.md](../../../AGENTS.md) の「安全と作業の継続」「Git 運用」に従い、既存のタスク環境は作り直さない。

## 作業場所

- `git status --porcelain`、`git worktree list`、`git branch -vv` で現在の作業場所と差分を確認する。
  自分の継続タスクの差分は保持して続行する。出所不明の差分や他セッションとの競合は
  上書き・stash・破棄せず BLOCKED として報告する。メインチェックアウトの未コミット変更
  （作業中の `_zshrc` など）はユーザーのものとして触れない。
- 新規タスクでは `git fetch origin` 後、`origin/master` から専用 worktree とブランチを作る。
  メインチェックアウトを切り替えず、他セッションのブランチを更新しない。
  Claude Code は EnterWorktree（`.claude/worktrees/<name>` に作成）を使う。そのセッション内では
  `git -C` や `$(git …)` を含む複合コマンドが拒否されるため、Git の確認は単純なコマンドを並べて行う。
  Codex は `git worktree add .claude/worktrees/<name> -b <type>/<name> origin/master`
  （`<type>` は `feat` / `fix` / `docs` / `chore` など）で作る。
- 既に今回のタスク用 worktree にいる場合は、ブランチとベースを確認して再利用する。
  fetch 失敗やベース不明は報告し、未確認の状態を最新扱いしない。
- worktree の `_zshrc` は `~/.zshrc` の symlink 先ではないため、マージするまで実環境に反映されない。
  `bats test` と手動の起動検査は worktree のルートで実行し、worktree 側のファイルを対象にする。
- x-ship で master へマージするタスクはこの worktree で進める。master への直接コミットが
  許されている小さな変更に worktree を強制しない。

## 変更に必要な環境とベースライン

- 文書・指示だけの変更では、参照先と検証に使うツールの確認で足りる。
- `_zshrc` または `test/zshrc.bats` の変更では `zsh --version` と `bats --version`（1.5 以上）を確認し、
  worktree のルートで `bats test` を実行して変更前のベースラインを取得する。`bats` が無ければ
  「検証と完了条件」の手動の構文検査・起動検査で代える。起動検査は `fnm`・`nvm`・`compinit` など
  実環境のツールを呼ぶため、変更前から出る警告は記録しておき、変更後の切り分けに使う。
- Codex レビューを使う予定なら `codex --version` と `timeout` の有無を確認する。
  同じ状態で取得済みの結果を再取得する必要はない。
- 必要なツールがない場合やベースラインが失敗した場合は、原因と影響範囲を報告する。

必要条件がそろえば READY。実装に必要な条件が満たせなければ BLOCKED とし、
不足情報と解消方法を示す。対象外の検査は省略理由を添える。
