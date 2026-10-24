#!/usr/bin/env bash
# Oh My Zsh と入力支援を導入し、設定の退避・復元・明示的な更新をまとめる。
set -euo pipefail

usage() {
    printf '使い方: bash setup.sh {install|update|uninstall}\n'
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
    install|update|uninstall) [[ $# == 1 ]] || { usage >&2; exit 1; } ;;
    *) usage >&2; exit 1 ;;
esac

action=$1

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

# 公式リポジトリを導入する。更新はローカル変更を保持し、fast-forward に限定する。
sync_repo() {
    local directory=$1 url=$2
    if exists "$directory"; then
        [[ ! -L $directory && -d $directory/.git ]] || fail "$directory は通常の Git checkout ではありません。"
        [[ $(git -C "$directory" config --get remote.origin.url) == "$url" ]] || fail "$directory の origin が公式 URL と異なります。"
        if [[ $action == update ]]; then
            [[ -z $(git -C "$directory" status --porcelain) ]] || fail "$directory に未コミット変更があります。"
            git -C "$directory" pull --ff-only origin master
        fi
    else
        git clone --depth 1 "$url" "$directory"
    fi
}

# 起動時には取得せず、セットアップ時だけ公式の導入手順を実行する。
install_tools() (
    for tool in git curl tar gzip zsh; do
        command -v "$tool" >/dev/null 2>&1 || fail "先に $tool をインストールしてください。"
    done
    sync_repo "$HOME/.oh-my-zsh" https://github.com/ohmyzsh/ohmyzsh.git
    # 入力支援の同梱前の checkout なら、明示的な update を案内する。
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        [[ -f $HOME/.oh-my-zsh/plugins/$plugin/$plugin.plugin.zsh ]] ||
            fail "Oh My Zsh が古いため、bash setup.sh update を実行してください。"
    done
    sync_repo "$HOME/.fzf" https://github.com/junegunn/fzf.git
    bash "$HOME/.fzf/install" --bin

    mkdir -p "$HOME/.local/bin"
    local staging version
    staging=$(mktemp -d "$HOME/.local/bin/.zsh-tools.XXXXXX")
    trap 'rm -rf -- "$staging"' EXIT
    for tool in starship zoxide; do
        if [[ $action == install && -x $HOME/.local/bin/$tool ]]; then
            continue
        fi
        [[ ! -L $HOME/.local/bin/$tool && ! -d $HOME/.local/bin/$tool ]] ||
            fail "$HOME/.local/bin/$tool がリンクまたはディレクトリのため上書きしません。"
        if [[ $tool == starship ]]; then
            curl -fsSL https://starship.rs/install.sh -o "$staging/install.sh"
            if ! sh "$staging/install.sh" --yes --bin-dir "$staging" > "$staging/install.log" 2>&1; then
                cat "$staging/install.log" >&2
                exit 1
            fi
        else
            curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o "$staging/install.sh"
            if ! sh "$staging/install.sh" --bin-dir "$staging" --man-dir "$HOME/.local/share/man" --sudo '' > "$staging/install.log" 2>&1; then
                cat "$staging/install.log" >&2
                exit 1
            fi
        fi
        # 正常に実行できるバイナリだけを配置する。
        version=$("$staging/$tool" --version)
        printf '%s\n' "${version%%$'\n'*}"
        mv -f -- "$staging/$tool" "$HOME/.local/bin/$tool"
    done
)

# ディレクトリの削除・上書きを防ぐ。ディレクトリを指すリンク自体は退避できる。
for file in "$rc" "$compiled"; do
    [[ ! -d $file || -L $file ]] || fail "$file はディレクトリです。"
done

if [[ $action == update ]]; then
    install_tools
    printf 'ツールを更新しました。設定ファイルへの追記は不要です。exec zsh で起動し直してください。\n'
    exit 0
fi

if [[ $action == install ]]; then
    command -v zsh >/dev/null 2>&1 || fail '先に zsh をインストールしてください。'
    zsh -n "$source_file"
    if is_installed && [[ -d $backup && ! -L $backup ]]; then
        install_tools
        printf '導入済みです: %s\n設定ファイルへの追記は不要です。\n' "$rc"
        exit 0
    fi
    exists "$backup" && fail "$backup が既にあります。退避内容を確認してください。"

    # 依存ツールを揃えてから設定を切り替える。取得失敗時は元の設定を保持する。
    install_tools

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
    printf '導入しました。退避先: %s\n設定ファイルへの追記は不要です。exec zsh で起動し直してください。\n' "$backup"
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
