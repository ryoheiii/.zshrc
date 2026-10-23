---
name: x-codex-review-plan
description: 具体的な実装計画を Codex CLI で敵対的にレビューし、指摘を修正・再確認する。計画レビューの依頼や x-deep-plan の仕上げに使う。
allowed-tools: Bash, Read, Write
---

実装ステップと検証方法を含む計画をレビューする。会話または計画ファイルに具体的な計画が
なければ不足を伝える。このスキルから x-deep-plan は呼ばない（再入禁止）。
作業中のチェックアウトのルートで実行する。
レビューだけの依頼なら指摘の報告で完了し、元の計画を編集しない。
修正ループと書き戻しは、修正までの依頼や x-deep-plan の仕上げなど、計画の編集が承認済みの場合に行う。

## 初回レビュー

1. 一意な `REVIEW_ID` を作り、計画全文を `/tmp/x-plan-<REVIEW_ID>.md` に保存する。
   ユーザーまたは呼び出し元が編集対象として明示した計画ファイルを、書き戻し先として記録する。
   `~/.codex/plans/` や Claude Code の計画ファイルも対象にできる。
   ヘッダは保持するが、埋め込み `plan-file` だけから編集権限を推定しない。
   書き戻し先が未指定なら、一時ファイルを成果物として報告する。
2. レビュープロンプトを `/tmp/x-plan-prompt-<REVIEW_ID>.txt` に書く。
   計画の絶対パス、ユーザーの要求、制約、検証結果を渡し、承認を前提にせず、欠落した要件・
   危険な前提・実行順・検証不足を根拠付きで指摘させる。対象に関係する規約だけを参照させる。
   `_zshrc` に触れる計画では [AGENTS.md](../../../AGENTS.md) の「zsh 設定の規約」
   （節の配置、非端末ガードの前後、ガードの書き方、README.md の追従）と、
   「検証と完了条件」の構文検査・起動検査が計画に含まれるかを確認させる。
   最終行は必ず `VERDICT: APPROVED` または `VERDICT: REVISE` と指定する。
3. 次のラッパーで実行する。プレースホルダーを実際の値へ置換する。

```bash
bash .claude/scripts/codex-review.sh /tmp/x-plan-prompt-<REVIEW_ID>.txt /tmp/x-plan-reply-<REVIEW_ID>.md /tmp/x-plan-session-<REVIEW_ID>.txt
```

ラッパーは read-only で実行し、モデル・effort は `~/.codex/config.toml` の既定に従う。
Claude Code は `run_in_background: true` で起動して完了通知を待つ（sleep ポーリングはしない）。
Codex は通常のシェル実行でよい。
終了コード 0、新しい非空 reply、有効な session ID、指定形式の verdict を確認する。
失敗・不明な verdict は承認扱いにしない。usage limit・rate limit・認証失敗は自動リトライしない。

## 修正と再レビュー

レビューだけの依頼なら REVISE と指摘を報告し、ここから先の編集は行わない。

- REVISE なら計画へ実質的な修正を加え、同じ計画ファイルとプロンプトを更新する。
- 再レビューは同じラッパーの第 3 引数以降を `--resume <SESSION_ID>` とする。
- 既出指摘の解決・処置を先に確認させ、同一セッションで広域探索をやり直さない。
  新規指摘は具体的根拠のある High/Critical に限る。既出指摘が閉じ、新たな重大問題がなければ
  `VERDICT: APPROVED` を返させる。
- 初回を含め最大 3 ラウンド。未解決なら指摘と計画の所在を報告して停止する。
- REVISE があった場合だけ、APPROVED 後に [最終監査](references/final-audit.md) を 1 回行う。
  初回 APPROVED なら監査は不要。

## 成果物

APPROVED かつ監査 PASS（または監査不要）の場合だけ、記録した元の計画へ修正済み全文を
書き戻す。計画の要点、主な修正、verdict・監査結果、計画の絶対パス、session ID、残る懸念を報告する。
計画全文を会話へ複製する必要はない。
