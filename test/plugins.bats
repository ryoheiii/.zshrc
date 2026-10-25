#!/usr/bin/env bats
# 本物のTTYで、入力支援の読み込み順・再読み込み・標準補完への復帰を検査する。
bats_require_minimum_version 1.5.0

setup() {
    export ZDOTDIR="$BATS_TEST_TMPDIR"
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
    export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
    export ZSH_CUSTOM="$ZSH/custom"
    export TERM=xterm-256color
    ln -s "$BATS_TEST_DIRNAME/../_zshrc" "$ZDOTDIR/.zshrc"
    PTY_RUN="$BATS_TEST_DIRNAME/pty-run.py"
}

@test "TTYでTab検索と既存の履歴・ファイル検索が共存し、再読み込みしても重複しない" {
    [ -f "$ZSH_CUSTOM/plugins/fzf-tab/fzf-tab.plugin.zsh" ] || skip 'fzf-tab が未導入'
    command -v fzf >/dev/null || skip 'fzf が未導入'
    run -0 python3 "$PTY_RUN" zsh -i -c '
        [[ ${plugins[(i)fzf]} -lt ${plugins[(i)fzf-tab]} ]] || exit 1
        [[ ${plugins[(i)fzf-tab]} -lt ${plugins[(i)zsh-autosuggestions]} ]] || exit 1
        [[ ${plugins[-1]} == zsh-syntax-highlighting ]] || exit 1
        (( $+functions[fzf-tab-complete] && $+functions[_zsh_highlight] )) || exit 1
        before=$(bindkey)
        before_widgets=$(zle -l -L)
        before_hooks="${(j:,:)precmd_functions}|${(j:,:)chpwd_functions}"
        compdef _files pluginprobe
        source "$ZDOTDIR/.zshrc" || exit 1
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ $(bindkey) == "$before" && $(zle -l -L) == "$before_widgets" ]] || exit 1
        [[ "${(j:,:)precmd_functions}|${(j:,:)chpwd_functions}" == "$before_hooks" ]] || exit 1
        [[ ${_comps[pluginprobe]} == _files && ${_comps[git]} == _git ]] || exit 1
        zstyle -s ":completion:*" menu reply
        [[ $reply == no ]] || exit 1
        [[ $(bindkey "^I") == *fzf-tab-complete ]] || exit 1
        [[ $(bindkey "^R") == *fzf-history-widget ]] || exit 1
        [[ $(bindkey "^T") == *fzf-file-widget ]] || exit 1
        [[ $(bindkey "^[c") == *fzf-cd-widget ]] || exit 1
        [[ $(bindkey "^[^[") == *sudo-command-line ]] || exit 1
        [[ $(bindkey "^[[A") == *up-line-or-beginning-search ]] || exit 1
        [[ $(bindkey "^P") == *up-line-or-beginning-search ]] || exit 1
        [[ $(bindkey "^N") == *down-line-or-beginning-search ]] || exit 1
        [[ ${aliases[gco]} == "git checkout" ]]
    '
    [ -z "$output" ]
}

@test "fzf-tab 未導入と dumb 端末では標準の補完メニューを保持する" {
    mkdir "$ZDOTDIR/empty-custom"
    for mode in missing dumb; do
        if [[ $mode == missing ]]; then
            export ZSH_CUSTOM="$ZDOTDIR/empty-custom"
        else
            export ZSH_CUSTOM="$ZSH/custom" TERM=dumb
        fi
        run -0 python3 "$PTY_RUN" zsh -i -c '
            (( ! $+functions[fzf-tab-complete] )) || exit 1
            zstyle -s ":completion:*" menu reply
            [[ $reply == select ]] || exit 1
            [[ ${_comps[git]} == _git ]]
        '
        [ -z "$output" ]
    done
}

@test "コマンドがあってもプラグインの実体がなければ警告を出さず除外する" {
    mkdir -p "$ZDOTDIR/partial-omz/plugins" "$ZDOTDIR/empty-custom" "$ZDOTDIR/empty-home" "$ZDOTDIR/bin"
    # 本体だけを借りた部分導入環境を作り、実際のプラグイン探索を通す。
    for entry in oh-my-zsh.sh lib tools functions completions; do
        ln -s "$ZSH/$entry" "$ZDOTDIR/partial-omz/$entry"
    done
    for tool in fzf zoxide; do
        printf '#!/bin/sh\nexit 1\n' > "$ZDOTDIR/bin/$tool"
        chmod +x "$ZDOTDIR/bin/$tool"
    done
    run -0 --separate-stderr env HOME="$ZDOTDIR/empty-home" ZSH="$ZDOTDIR/partial-omz" \
        ZSH_CUSTOM="$ZDOTDIR/empty-custom" PATH="$ZDOTDIR/bin:/usr/bin:/bin" \
        python3 "$PTY_RUN" zsh -d -i -c '
        (( $+functions[omz] && $+functions[compdef] )) || exit 1
        for tool in git fzf zoxide; do
            __zshrc_has "$tool" || exit 1
            (( ! ${plugins[(Ie)$tool]} )) || exit 1
        done
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
}

@test "起動後にコマンドが PATH から消えても読み込み済みプラグインの一覧を保持する" {
    mkdir "$ZDOTDIR/bin" "$ZDOTDIR/empty-home"
    printf '#!/bin/sh\nexit 1\n' > "$ZDOTDIR/bin/code"
    chmod +x "$ZDOTDIR/bin/code"
    run -0 --separate-stderr env HOME="$ZDOTDIR/empty-home" PATH="$ZDOTDIR/bin:/usr/bin:/bin" \
        zsh -d -i -c '
        (( ${plugins[(Ie)vscode]} && $+functions[vsc] )) || exit 1
        before="${(j: :)plugins}"
        path=()
        if __zshrc_has code; then exit 1; fi
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ "${(j: :)plugins}" == "$before" ]] || exit 1
        (( $+functions[vsc] ))
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
}

@test "VS Code の短縮は空白付き引数と行指定を保持し、実際のエディターを起動しない" {
    mkdir "$ZDOTDIR/bin"
    printf '#!/bin/sh\nprintf "<%%s>\\n" "$@"\n' > "$ZDOTDIR/bin/code"
    chmod +x "$ZDOTDIR/bin/code"
    run -0 env PATH="$ZDOTDIR/bin:$PATH" python3 "$PTY_RUN" zsh -i -c '
        vsc "a b.txt"
        vscg "a b.txt:42"
        vscd "a b.txt" "c d.txt"
    '
    [ "$output" = $'<a b.txt>\n<--goto>\n<a b.txt:42>\n<--diff>\n<a b.txt>\n<c d.txt>' ]
}

@test "extract はアーカイブを保持して展開し、copypath は空白付き絶対パスを渡す" {
    mkdir -p "$ZDOTDIR/input" "$ZDOTDIR/unpacked"
    printf '保持する内容\n' > "$ZDOTDIR/input/a b.txt"
    tar -czf "$ZDOTDIR/archive.tar.gz" -C "$ZDOTDIR/input" 'a b.txt'
    run -0 --separate-stderr zsh -i -c '
        cd "$ZDOTDIR/unpacked"
        extract "$ZDOTDIR/archive.tar.gz" >/dev/null || exit 1
        [[ -f "$ZDOTDIR/archive.tar.gz" && $(<"a b.txt") == 保持する内容 ]] || exit 1
        function clipcopy() { cat > "$ZDOTDIR/copied"; }
        copypath "a b.txt" >/dev/null || exit 1
        [[ $(<"$ZDOTDIR/copied") == "$PWD/a b.txt" ]]
    '
    [ -z "$output" ]
    [[ "$stderr" == 'extract: extracting to archive' ]]
}

@test "sudo がない TTY 環境では Esc 二回のキー割り当てを変更しない" {
    mkdir -p "$ZDOTDIR/bin" "$ZDOTDIR/empty-home"
    # Oh My Zsh が使う OS コマンドを残し、sudo だけがない PATH を作る。
    python3 - "$ZDOTDIR/bin" <<'PYTHON'
import os
import sys
from pathlib import Path
for directory in (Path('/usr/bin'), Path('/bin')):
    for source in directory.iterdir():
        target = Path(sys.argv[1]) / source.name
        if source.name != 'sudo' and not target.exists() and source.is_file() and os.access(source, os.X_OK):
            target.symlink_to(source)
PYTHON
    run -0 python3 "$PTY_RUN" zsh -d -f -i -c '
        HOME="$ZDOTDIR/empty-home"
        path=("$ZDOTDIR/bin")
        before=$(bindkey "^[^[")
        source "$ZDOTDIR/.zshrc" || exit 1
        (( ! ${plugins[(Ie)sudo]} )) || exit 1
        (( ! $+functions[sudo-command-line] )) || exit 1
        [[ $(bindkey "^[^[") == "$before" ]]
    '
    [ -z "$output" ]
}

@test "別プロセスで起動し直しても Oh My Zsh と OS の補完キャッシュを作り直さない" {
    run -0 python3 "$PTY_RUN" zsh -i -c '
        [[ $ZSH_COMPDUMP == "$ZSH_CACHE_DIR/.zcompdump" && -s $ZSH_COMPDUMP ]]
    '
    [ -z "$output" ]
    local cache="$XDG_CACHE_HOME/oh-my-zsh/.zcompdump"
    local before system_before=''
    before=$(stat -c '%y:%i' "$cache")
    if [[ -f "$ZDOTDIR/.zcompdump" ]]; then
        system_before=$(stat -c '%y:%i' "$ZDOTDIR/.zcompdump")
    fi
    run -0 python3 "$PTY_RUN" zsh -i -c ':'
    [ -z "$output" ]
    [ "$(stat -c '%y:%i' "$cache")" = "$before" ]
    if [[ -n $system_before ]]; then
        [ "$(stat -c '%y:%i' "$ZDOTDIR/.zcompdump")" = "$system_before" ]
    fi
}
