# final モードの承認記録

final は clean tree が必須である。`git status --porcelain` が非空なら、レビューを開始せず
「final レビューは clean tree 必須」と報告する。step の APPROVED から記録を作らない。

レビュー開始時にブランチ名、HEAD、ベースの SHA を記録し、ベースが HEAD の祖先であることを確認する。
ベース未統合なら承認せず、統合後の関連検証が必要と報告する。
修正まで承認された依頼で REVISE を直した後は、その修正だけを
論理単位でコミットし、必要な検証と clean tree の確認後、新しい HEAD を記録して再レビューする。
無関係な差分は取り込まず、想定外の HEAD・ブランチ・差分の変更は停止して報告する。

承認記録はタスク worktree の Git 管理ディレクトリ（`git rev-parse --git-path review-state`。
linked worktree では `<メインチェックアウト>/.git/worktrees/<name>/review-state/`）に置く。
追跡対象にならず、`git worktree remove` で worktree と一緒に消える。
本書の bash ブロックは `$(git …)` を含むため、Claude Code の EnterWorktree セッション内では拒否される。
Claude Code は [x-ship](../../x-ship/SKILL.md) の「前提とルール」のとおり、final レビューを始める前に
ExitWorktree（`keep`）で戻り、失効・レビュー・記録作成のすべてを `cd <TASK_WORKTREE> &&` 付きで実行する。

final レビューを開始するときは、まず同じブランチの既存の承認記録を削除する。前回の APPROVED が
残っていると、今回 REVISE になっても x-ship のゲートが通ってしまう。

```bash
set -eu
BRANCH_SAFE="$(printf '%s' "$(git branch --show-current)" | tr '/' '-')"
rm -f -- "$(git rev-parse --path-format=absolute --git-path "review-state/final-approval-${BRANCH_SAFE}")"
```

APPROVED 後、同じブランチ・同じ HEAD・clean tree であることを再確認して初めて
x-ship が照合する記録を書く。次は Bash で実行し、`REVIEWED_BRANCH`・`REVIEWED_HEAD`・`REVIEWED_BASE` には
レビュー前に記録した実際の値を渡す（承認後の現在値で代用しない）。

```bash
set -eu
CURRENT_BRANCH="$(git branch --show-current)"
CURRENT_HEAD="$(git rev-parse HEAD)"
CURRENT_STATUS="$(git status --porcelain)"
test "$CURRENT_BRANCH" = "$REVIEWED_BRANCH"
test "$CURRENT_HEAD" = "$REVIEWED_HEAD"
test -z "$CURRENT_STATUS"
git merge-base --is-ancestor "$REVIEWED_BASE" "$REVIEWED_HEAD"
BRANCH_SAFE="$(printf '%s' "$CURRENT_BRANCH" | tr '/' '-')"
RECORD="$(git rev-parse --path-format=absolute --git-path "review-state/final-approval-${BRANCH_SAFE}")"
mkdir -p "$(dirname "$RECORD")"
printf '%s\n' "$REVIEWED_HEAD" > "$RECORD"
echo "final approval: $RECORD"
```

記録後に HEAD が変われば記録は stale であり、final レビューをやり直す。
既存の記録があることだけを理由に承認扱いにしない。
