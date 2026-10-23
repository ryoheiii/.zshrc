---
name: x-ship
description: タスクブランチを検証・最終レビュー後に master へ fast-forward マージし、push・後片付けまで行う。ship またはマージ完了までの依頼で使う。
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Skill, ExitWorktree
disable-model-invocation: true
---

現在のブランチの変更をコミットし、検証 → 最終レビューゲート → `master` への fast-forward マージ →
push → 後片付けまでを一気通貫で行う。

## 引数

- `$ARGUMENTS`: コミットメッセージや変更概要の補足（任意）。
  `--no-push` を含む場合はローカルマージまでで終了する。

## 前提とルール

- [AGENTS.md](../../../AGENTS.md) の「Git 運用」「検証と完了条件」に従う。
- タスク worktree のブランチから実行する。master 上では実行しない。
  master へのマージは `--ff-only` とし、マージコミットを作らない。force push をしない。
- fixup / squash などの履歴改変は **ユーザーの明示指示がある場合のみ** 行う。
- コミットメッセージは Conventional Commits の日本語形式。`Co-Authored-By` トレーラーを付けない。
- メインチェックアウト（`~/.zshrc` の symlink 先）にあるユーザーの未コミット変更は保持する。
  マージはそれらのファイルに触れない場合だけ進める。
- 各ステップは独立したシェルで実行されるため、変数はステップ内で解決する。
- このリポジトリに CI はない。push 後はリモートの `master` がマージコミットと一致することで確認する。

## 手順

### 1. 開始判定

```bash
BRANCH="$(git branch --show-current)"
case "$BRANCH" in master|'') echo "停止: タスク worktree のブランチで実行する"; exit 2;; esac
git status --porcelain
git rev-list master..HEAD --oneline
```

- master 上なら停止する。
- dirty（未コミット変更あり）→ Step 2 へ。
- clean かつ master から ahead のコミットあり → Step 2 をスキップして Step 4 へ（resume）。
- clean かつ ahead なし → 「ship 対象がありません」と報告して停止する。

### 2. 論理単位コミット

- 変更を小さな論理単位に分け、ファイル名を指定してステージしてコミットする
  （`git add -A`・`git add .`・`git commit -a` は使わない）。整形とロジック変更を混在させない。
- `$ARGUMENTS` があればメッセージの参考にする。
- 検証中に生成された意図しないファイル（`.zcompdump*`、`*.zwc` など）を
  コミット対象に含めない（`git status --porcelain --ignored` で確認）。

### 3. 履歴確認

`git log --oneline master..HEAD` で履歴を確認する。整理（fixup/squash）が望ましい場合は
**提案のみ** 行い、ユーザーの明示指示があった場合に実施する。

### 4. 検証

「検証と完了条件」に従い、変更範囲に対応する検査を実行する:

- `_zshrc` を含む変更: 構文検査 `zsh -n _zshrc` と、一時ディレクトリを `ZDOTDIR` にした起動検査
  （どちらも worktree のファイルに対して実行する）。README.md の該当箇所が追従しているかも確認する。
- 文書・エージェント設定だけの変更: 参照先とコマンドの実在、記述どうしの整合性。
  `.claude/settings.json` は `jq .`、`.codex/config.toml` は `tomllib` で読み込めることも確認する。

失敗したら修正 → コミット → 再検証。**通るまで先へ進まない**。

### 5. 最終レビューゲート（fail-closed）

clean tree で、Codex final レビューの承認記録が現在の HEAD と一致することを確認する:

```bash
set -eu
CURRENT_BRANCH="$(git branch --show-current)"
CURRENT_HEAD="$(git rev-parse HEAD)"
CURRENT_STATUS="$(git status --porcelain)"
case "$CURRENT_BRANCH" in master|'') exit 2;; esac
test -z "$CURRENT_STATUS"
BRANCH_SAFE="$(printf '%s' "$CURRENT_BRANCH" | tr '/' '-')"
RECORD="$(git rev-parse --path-format=absolute --git-path "review-state/final-approval-${BRANCH_SAFE}")"
if [ -f "$RECORD" ] && [ "$(cat "$RECORD")" = "$CURRENT_HEAD" ]; then
  echo "final review gate: APPROVED"
else
  echo "final review gate: MISSING_OR_STALE"
  exit 1
fi
```

- `MISSING_OR_STALE` の場合は `/x-codex-review-impl final` を実行して APPROVED を得てから
  このステップを再実行する。**APPROVED なしでマージへ進まない**。
- ドキュメントのみの軽微な変更でゲートを省略したい場合は、ユーザーの明示同意を得て
  省略した旨を最終報告に残す。

### 6. master へ fast-forward マージ

タスク worktree から実行する。メインチェックアウトへの操作は `git -C` で行い、
次の独立シェルへ渡す状態はタスク専用の Git 管理ディレクトリへ保存する。
`--no-push` を指定された場合は `SHIP_PUSH=no` を渡す（既定は `yes`）:

```bash
set -eu
SHIP_PUSH="${SHIP_PUSH:-yes}"
case "$SHIP_PUSH" in yes|no) ;; *) exit 2;; esac
MAIN_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
TASK_BRANCH="$(git branch --show-current)"
TASK_WORKTREE="$(git rev-parse --show-toplevel)"
case "$TASK_BRANCH" in master|'') echo "停止: タスク worktree が必要です" >&2; exit 2;; esac
test "$TASK_WORKTREE" != "$MAIN_ROOT"
SHIP_STATE="$(git rev-parse --absolute-git-dir)/ship-state"
test "$(git -C "$MAIN_ROOT" branch --show-current)" = master
# メインチェックアウトの未コミット変更（ユーザーの作業中の _zshrc など）は保持する。
DIRTY_BEFORE="$(git -C "$MAIN_ROOT" status --porcelain)"
git -C "$MAIN_ROOT" pull --ff-only origin master
MAIN_HEAD="$(git -C "$MAIN_ROOT" rev-parse HEAD)"
# このステップより前に master が更新されていた場合も検出する。
git merge-base --is-ancestor "$MAIN_HEAD" "$TASK_BRANCH"
# マージが書き換えるファイルに未コミット変更があれば、git が拒否する前に止める。
if [ -n "$DIRTY_BEFORE" ] && git diff --name-only "$MAIN_HEAD" "$TASK_BRANCH" |
   grep -Fx -f <(printf '%s\n' "$DIRTY_BEFORE" | cut -c4- | sed 's/^.* -> //'); then
  echo "停止: 上記のファイルはメインチェックアウトに未コミット変更があります" >&2
  exit 1
fi
git -C "$MAIN_ROOT" merge --ff-only "$TASK_BRANCH"
MERGE_SHA="$(git -C "$MAIN_ROOT" rev-parse HEAD)"
test "$(git -C "$MAIN_ROOT" status --porcelain)" = "$DIRTY_BEFORE"
umask 077
printf 'MAIN_ROOT=%q\nTASK_BRANCH=%q\nTASK_WORKTREE=%q\nMERGE_SHA=%q\nSHIP_PUSH=%q\n' \
  "$MAIN_ROOT" "$TASK_BRANCH" "$TASK_WORKTREE" "$MERGE_SHA" "$SHIP_PUSH" > "$SHIP_STATE.tmp"
mv -f "$SHIP_STATE.tmp" "$SHIP_STATE"
echo "merged: $MERGE_SHA"
```

- 更新後の master がタスクブランチに含まれていなければマージを中止する。
  master をタスクブランチへ取り込み、検証と final レビューをやり直してから再開する。
  rebase は明示指示がない限り行わない。
- master がタスクブランチの祖先なので fast-forward は常に成立し、内容の衝突は起きない。
  未コミット変更との重なりで止まった場合は、そのファイルの扱いをユーザーに確認する
  （stash・破棄をしない）。

### 7. push（`--no-push` 指定時はスキップ）

```bash
set -eu
SHIP_STATE="$(git rev-parse --absolute-git-dir)/ship-state"
test -r "$SHIP_STATE"
# Step 6 が %q で保存した、このタスク専用の状態だけを読み込む。
source "$SHIP_STATE"
test "$(git branch --show-current)" = "$TASK_BRANCH"
test "$(git rev-parse --show-toplevel)" = "$TASK_WORKTREE"
test "$(git -C "$MAIN_ROOT" rev-parse HEAD)" = "$MERGE_SHA"
if [ "$SHIP_PUSH" = no ]; then exit 0; fi
git -C "$MAIN_ROOT" push origin master
test "$(git -C "$MAIN_ROOT" rev-parse origin/master)" = "$MERGE_SHA"
```

push が拒否された場合は原因を報告し、force push や履歴改変で解決しない。

### 8. 後片付け

マージ済みのタスク worktree とブランチを同じ作業の中で削除する。
状態は worktree 削除前に読み込む。

```bash
set -eu
SHIP_STATE="$(git rev-parse --absolute-git-dir)/ship-state"
test -r "$SHIP_STATE"
source "$SHIP_STATE"
test "$(git branch --show-current)" = "$TASK_BRANCH"
test "$(git rev-parse --show-toplevel)" = "$TASK_WORKTREE"
git merge-base --is-ancestor "$TASK_BRANCH" master
cd "$MAIN_ROOT"
git worktree remove "$TASK_WORKTREE"
git worktree prune
# -d は upstream を優先する。master への取り込み確認済みの対象だけ解除する。
if [ -n "$(git for-each-ref --format='%(upstream)' "refs/heads/$TASK_BRANCH")" ]; then
  git branch --unset-upstream "$TASK_BRANCH"
fi
git branch -d "$TASK_BRANCH"
if [ "$SHIP_PUSH" = yes ] && git show-ref --verify --quiet "refs/remotes/origin/$TASK_BRANCH"; then
  git push origin --delete "$TASK_BRANCH"
fi
```

- Claude Code で EnterWorktree により入った worktree では、`git merge-base --is-ancestor` までを
  確認したあと、上のスクリプトの残りの代わりに ExitWorktree（`remove`）で worktree と
  ブランチを削除する（セッションの作業ディレクトリが消えるため）。
- `-D` は使わない。削除が拒否されたら原因を確認して報告する。
- 承認記録と ship 状態は worktree の Git 管理ディレクトリにあり、worktree と一緒に消える。

### 9. 報告

- マージ後の master の SHA と取り込んだコミット
- 実行した検証コマンドと結果
- 最終レビューゲートの結果（省略時はその旨と理由）
- push の結果（スキップ時はその旨）
- 削除したブランチ・worktree
- 残作業・未検証事項
