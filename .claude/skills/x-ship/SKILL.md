---
name: x-ship
description: タスクブランチを検証・最終レビュー後に main へ fast-forward マージし、push・後片付けまで行う。ship またはマージ完了までの依頼で使う。
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Skill, ExitWorktree
disable-model-invocation: true
---

現在のブランチの変更をコミットし、検証 → 最終レビューゲート → `main` への fast-forward マージ →
push → 後片付けまでを一気通貫で行う。

## 引数

- `$ARGUMENTS`: コミットメッセージや変更概要の補足（任意）。
  `--no-push` を含む場合は push だけを省略し、main へのローカルマージと後片付けまで行う
  （push は後でメインチェックアウトから `git push origin main` を実行する）。

## 前提とルール

- [AGENTS.md](../../../AGENTS.md) の「Git 運用」「検証と完了条件」に従う。
- タスク worktree のブランチから実行する。main 上では実行しない。
  main へのマージは `--ff-only` とし、マージコミットを作らない。force push をしない。
- fixup / squash などの履歴改変は **ユーザーの明示指示がある場合のみ** 行う。
- コミットメッセージは Conventional Commits の日本語形式。`Co-Authored-By` トレーラーを付けない。
- メインチェックアウト（`~/.zshrc` の symlink 先）にあるユーザーの未コミット変更は保持する。
  マージはそれらのファイルに触れない場合だけ進める。
- 各ステップは独立したシェルで実行されるため、変数はステップ内で解決する。
- Claude Code の EnterWorktree セッション内では、worktree 隔離のため `git -C` や `$(git …)` を含む
  複合コマンドが拒否される。Step 4 までは worktree 内で行い、final レビューを始める前に
  ExitWorktree（`keep`）でメインチェックアウトのセッションへ戻る。以降の final レビュー
  （既存の承認記録の失効を含む）、承認記録の作成、Step 5 以降の各 bash ブロックは、先頭に
  `cd <TASK_WORKTREE> &&` を付けて実行する。Codex は worktree 内でそのまま実行する。
- このリポジトリに CI はない。push 後はリモートの `main` がマージ後のローカル `main` と一致することで確認する。

## 手順

### 1. 開始判定

worktree 内で実行できる単純なコマンドだけを使う。

```bash
git branch --show-current
git status --porcelain
git rev-list main..HEAD --oneline
git rev-parse --absolute-git-dir
```

- ブランチが main または空なら停止する（タスク worktree のブランチで実行する）。
- 最後に表示した Git 管理ディレクトリに `ship-state` があれば（`ls` で確認）、前回の Step 6 で
  マージ済み（push 失敗後の再実行など）。clean で、その `MERGE_SHA` が `git rev-parse main` と
  一致することを確認して Step 7 から再開する。一致しなければ停止して報告する。
- dirty（未コミット変更あり）→ Step 2 へ。
- clean かつ main から ahead のコミットあり → Step 2 をスキップして Step 4 へ（resume）。
- clean かつ ahead なし → 「ship 対象がありません」と報告して停止する。

### 2. 論理単位コミット

- 変更を小さな論理単位に分け、ファイル名を指定してステージしてコミットする
  （`git add -A`・`git add .`・`git commit -a` は使わない）。整形とロジック変更を混在させない。
- `$ARGUMENTS` があればメッセージの参考にする。
- 検証中に生成された意図しないファイル（`.zcompdump*`、`*.zwc` など）を
  コミット対象に含めない（`git status --porcelain --ignored` で確認）。

### 3. 履歴確認

`git log --oneline main..HEAD` で履歴を確認する。整理（fixup/squash）が望ましい場合は
**提案のみ** 行い、ユーザーの明示指示があった場合に実施する。

### 4. 検証

「検証と完了条件」に従い、変更範囲に対応する検査を実行する:

- `_zshrc` または `test/zshrc.bats` を含む変更: worktree のルートで `bats test` を実行し、全件 `ok` を
  確認する（`bats` が無ければ「検証と完了条件」の手動の構文検査・起動検査で代える）。
  README.md の該当箇所が追従しているかも確認する。
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
case "$CURRENT_BRANCH" in main|'') exit 2;; esac
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
- 承認記録は final レビューの開始時に失効させ、APPROVED 後にだけ作り直される
  （[最終承認の契約](../x-codex-review-impl/references/final-approval.md)）。
- ドキュメントのみの軽微な変更でゲートを省略したい場合は、ユーザーの明示同意を得て
  省略した旨を最終報告に残す。

### 6. main へ fast-forward マージ

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
case "$TASK_BRANCH" in main|'') echo "停止: タスク worktree が必要です" >&2; exit 2;; esac
test "$TASK_WORKTREE" != "$MAIN_ROOT"
SHIP_STATE="$(git rev-parse --absolute-git-dir)/ship-state"
test "$(git -C "$MAIN_ROOT" branch --show-current)" = main
# メインチェックアウトの未コミット変更（ユーザーの作業中の _zshrc など）は保持する。
DIRTY_BEFORE="$(git -C "$MAIN_ROOT" status --porcelain)"
git -C "$MAIN_ROOT" pull --ff-only origin main
MAIN_HEAD="$(git -C "$MAIN_ROOT" rev-parse HEAD)"
# このステップより前に main が更新されていた場合も検出する。
git merge-base --is-ancestor "$MAIN_HEAD" "$TASK_BRANCH"
# マージが書き換えるファイルに未コミット変更があれば、git が拒否する前に止める。
# rename は元と先の両方を照合する。見逃しても git 自身が上書きを拒否する。
if [ -n "$DIRTY_BEFORE" ] && git diff --name-only --no-renames "$MAIN_HEAD" "$TASK_BRANCH" |
   grep -Fx -f <(printf '%s\n' "$DIRTY_BEFORE" | cut -c4- | sed 's/ -> /\n/'); then
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

- 更新後の main がタスクブランチに含まれていなければマージを中止する。
  main をタスクブランチへ取り込み、検証と final レビューをやり直してから再開する。
  rebase は明示指示がない限り行わない。
- main がタスクブランチの祖先なので fast-forward は常に成立し、内容の衝突は起きない。
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
git -C "$MAIN_ROOT" push origin main
test "$(git -C "$MAIN_ROOT" rev-parse origin/main)" = "$MERGE_SHA"
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
git merge-base --is-ancestor "$TASK_BRANCH" main
cd "$MAIN_ROOT"
git worktree remove "$TASK_WORKTREE"
git worktree prune
# -d は upstream を優先する。main への取り込み確認済みの対象だけ解除する。
if [ -n "$(git for-each-ref --format='%(upstream)' "refs/heads/$TASK_BRANCH")" ]; then
  git branch --unset-upstream "$TASK_BRANCH"
fi
git branch -d "$TASK_BRANCH"
```

- タスクブランチは push しない運用なので、リモートブランチの削除は行わない。手動で push していた
  場合は、未マージのコミットがないことを確認したうえでユーザーの指示で削除する。
- Claude Code では「前提とルール」のとおり ExitWorktree（`keep`）で戻った後に、このスクリプトを
  `cd <TASK_WORKTREE> &&` 付きで実行する。ExitWorktree（`remove`）は使わない
  （ship-state を読む前に worktree が消えるため）。
- `-D` は使わない。削除が拒否されたら原因を確認して報告する。
- 承認記録と ship 状態は worktree の Git 管理ディレクトリにあり、worktree と一緒に消える。

### 9. 報告

- マージ後の main の SHA と取り込んだコミット
- 実行した検証コマンドと結果
- 最終レビューゲートの結果（省略時はその旨と理由）
- push の結果（スキップ時はその旨）
- 削除したブランチ・worktree
- 残作業・未検証事項
