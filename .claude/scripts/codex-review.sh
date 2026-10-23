#!/usr/bin/env bash
# Codex CLI を read-only サンドボックスで実行し、今回生成した回答を指定先のファイルへ保存する。
# codex-review.sh PROMPT REPLY {SESSION_FILE | --resume SESSION_ID}
#   PROMPT        レビュー依頼のプロンプト（非空ファイル）
#   REPLY         回答の保存先。実行ログは REPLY.log に保存する
#   SESSION_FILE  新規セッションの ID を保存する先。再レビューは --resume SESSION_ID で同じセッションを続ける
# モデルと reasoning effort は ~/.codex/config.toml の既定に従う。
# CODEX_REVIEW_MODEL / CODEX_REVIEW_EFFORT を設定した場合だけ上書きし、
# CODEX_REVIEW_TIMEOUT_SEC（既定 1800 秒）で時間切れを決める。
# 終了コード: 0=成功, 1=引数・CLI・保存の失敗, 2=新しい回答なし, 3=セッション不正, 124=時間切れ
set -u
MODEL="${CODEX_REVIEW_MODEL:-}"
EFFORT="${CODEX_REVIEW_EFFORT:-}"
TIMEOUT_SEC="${CODEX_REVIEW_TIMEOUT_SEC:-1800}"
PROMPT_FILE="${1:-}"
REPLY_FILE="${2:-}"
MODE_ARG="${3:-}"
if [ -z "$PROMPT_FILE" ] || [ ! -s "$PROMPT_FILE" ] || [ -z "$REPLY_FILE" ] ||
   { [ "$MODE_ARG" = --resume ] && { [ "$#" -ne 4 ] || [ -z "${4:-}" ]; }; } ||
   { [ "$MODE_ARG" != --resume ] && { [ "$#" -ne 3 ] || [ -z "$MODE_ARG" ]; }; }; then
  echo 'Usage: codex-review.sh PROMPT REPLY {SESSION_FILE | --resume SESSION_ID}' >&2
  exit 1
fi
STAGING="$(mktemp -d "${REPLY_FILE}.run.XXXXXX")" || exit 1
LOG_FILE="$STAGING/log"
TEMP_REPLY="$STAGING/reply"
# 失敗時も診断ログは固有の run ディレクトリに残す。
echo "INFO: log=$LOG_FILE"
args=(exec)
if [ "$MODE_ARG" = --resume ]; then
  args+=(resume "$4" -c 'sandbox_mode="read-only"')
else
  args+=(-s read-only)
fi
if [ -n "$MODEL" ]; then args+=(-m "$MODEL"); fi
if [ -n "$EFFORT" ]; then args+=(-c "model_reasoning_effort=\"$EFFORT\""); fi
if timeout "$TIMEOUT_SEC" codex "${args[@]}" -o "$TEMP_REPLY" - \
   < "$PROMPT_FILE" > "$LOG_FILE" 2>&1; then
  CODEX_EXIT=0
else
  CODEX_EXIT=$?
fi
if [ "$CODEX_EXIT" -ne 0 ]; then
  echo "ERROR: codex exec exit=$CODEX_EXIT（ログ: $LOG_FILE）" >&2
  if [ "$CODEX_EXIT" -eq 124 ]; then exit 124; fi
  exit 1
fi
if [ ! -s "$TEMP_REPLY" ]; then
  echo "ERROR: 今回の reply が空です（ログ: $LOG_FILE）" >&2
  exit 2
fi
sources=("$TEMP_REPLY" "$LOG_FILE")
targets=("$REPLY_FILE" "$REPLY_FILE.log")
if [ "$MODE_ARG" != --resume ]; then
  SESSION_ID="$(awk '/session id: / && !found { sub(/^.*session id: */, ""); gsub(/[[:space:]]/, ""); print; found=1 }' "$LOG_FILE")" || exit 3
  if [[ ! "$SESSION_ID" =~ ^[[:alnum:]_-]+$ ]]; then
    echo "ERROR: session id を抽出できません（ログ: $LOG_FILE）" >&2
    exit 3
  fi
  printf '%s\n' "$SESSION_ID" > "$STAGING/session" || exit 3
  sources+=("$STAGING/session")
  targets+=("$MODE_ARG")
fi
# 全保存先を検証し、各親ディレクトリと同じファイルシステム上に新旧のファイルを用意する。
# セッション ID を保存できない場合に、回答だけが更新されることを防ぐ。
new_files=() old_files=() existed=() published=0 success=no
cleanup() {
  local rc=$? i
  # 復元中の追加シグナルで、退避済み成果物の回収を中断しない。
  trap '' INT TERM
  if [ "$success" = no ]; then
    for ((i=published-1; i>=0; i--)); do
      if [ "${existed[i]}" = yes ]; then
        if ! mv -f -- "${old_files[i]}" "${targets[i]}"; then
          echo "ERROR: 旧成果物を ${old_files[i]} に保持しています。" >&2
          old_files[i]=''
          rc=1
        fi
      else
        rm -f -- "${targets[i]}" || rc=1
      fi
    done
  fi
  for file in "${new_files[@]}" "${old_files[@]}"; do
    if [ -n "$file" ]; then rm -f -- "$file"; fi
  done
  if [ "$success" = yes ]; then rm -rf -- "$STAGING"; fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for ((i=0; i<${#targets[@]}; i++)); do
  target="${targets[i]}"
  if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
    echo "ERROR: 公開先が通常ファイルではありません: $target" >&2
    exit 1
  fi
  for ((j=0; j<i; j++)); do
    if [ "$target" = "${targets[j]}" ] || [ "$target" -ef "${targets[j]}" ]; then
      echo "ERROR: 公開先が重複しています。" >&2
      exit 1
    fi
  done
  new="$(mktemp "${target}.new.XXXXXX")" || exit 1
  new_files+=("$new")
  cp -- "${sources[i]}" "$new" || exit 1
  old_files+=('')
  existed+=(no)
  if [ -e "$target" ]; then
    old="$(mktemp "${target}.old.XXXXXX")" || exit 1
    old_files[i]="$old"
    cp -p -- "$target" "$old" || exit 1
    existed[i]=yes
  fi
done
for ((i=0; i<${#targets[@]}; i++)); do
  # rename 後に mv が失敗・シグナル終了しても、この公開先を復元する。
  published=$((published + 1))
  mv -f -- "${new_files[i]}" "${targets[i]}" || exit 1
done
success=yes
if [ "$MODE_ARG" != --resume ]; then echo "OK: session=$SESSION_ID"; fi
echo "OK: reply=$REPLY_FILE"
