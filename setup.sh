#!/usr/bin/env bash
# 設定のリンクを作成し、uninstall 時に導入前の設定を復元する。
set -euo pipefail

usage() {
    printf '使い方: bash setup.sh {install|uninstall}\n'
}

fail() {
    printf 'エラー: %s\n' "$*" >&2
    exit 1
}

exists() {
    [[ -e $1 || -L $1 ]]
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    install|uninstall) [[ $# == 1 ]] || { usage >&2; exit 1; } ;;
    *) usage >&2; exit 1 ;;
esac

# ZDOTDIR に別の設定がある環境では、使われないリンクを作らない。
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || fail 'HOME が有効な絶対パスではありません。'
[[ ${ZDOTDIR:-$HOME} == "$HOME" ]] || fail 'ZDOTDIR を解除するか HOME と同じ値にしてください。'
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source_file="$repo_dir/_zshrc"
rc="$HOME/.zshrc"
compiled="$HOME/.zshrc.zwc"
backup="$HOME/.zshrc.zsh-config-backup"

is_installed() {
    [[ -L $rc && $(readlink -- "$rc") == "$source_file" ]]
}

# ディレクトリの削除・上書きを防ぐ。ディレクトリを指すリンク自体は退避できる。
for file in "$rc" "$compiled"; do
    [[ ! -d $file || -L $file ]] || fail "$file はディレクトリです。"
done

if [[ $1 == install ]]; then
    command -v zsh >/dev/null 2>&1 || fail '先に zsh をインストールしてください。'
    zsh -n "$source_file"
    if is_installed && [[ -d $backup && ! -L $backup ]]; then
        printf '導入済みです: %s\n' "$rc"
        exit 0
    fi
    exists "$backup" && fail "$backup が既にあります。退避内容を確認してください。"

    # 途中で失敗した場合は、退避できたファイルを元へ戻す。
    rollback() {
        trap - ERR
        for name in .zshrc .zshrc.zwc; do
            if exists "$backup/$name" && ! exists "$HOME/$name"; then
                mv -- "$backup/$name" "$HOME/$name"
            fi
        done
        rmdir -- "$backup"
    }
    mkdir -- "$backup"
    trap 'rollback' ERR
    if exists "$rc"; then mv -- "$rc" "$backup/.zshrc"; fi
    if exists "$compiled"; then mv -- "$compiled" "$backup/.zshrc.zwc"; fi
    ln -s -- "$source_file" "$rc"
    trap - ERR
    printf '導入しました。退避先: %s\n新しい zsh を起動してください。\n' "$backup"
else
    # 別の設定へ差し替えられていたら、触らずに止まる。
    [[ -d $backup && ! -L $backup ]] || fail 'このスクリプトによる退避先がありません。'
    is_installed || fail "$rc のリンク先が変わっています。自動復元を中止しました。"
    for name in .zshrc .zshrc.zwc; do
        [[ ! -d $backup/$name || -L $backup/$name ]] || fail "$backup/$name はディレクトリです。"
    done
    if exists "$compiled"; then unlink -- "$compiled"; fi
    unlink -- "$rc"
    for name in .zshrc .zshrc.zwc; do
        if exists "$backup/$name"; then mv -- "$backup/$name" "$HOME/$name"; fi
    done
    rmdir -- "$backup"
    printf '導入前の状態へ戻しました。新しいシェルを起動してください。\n'
fi
