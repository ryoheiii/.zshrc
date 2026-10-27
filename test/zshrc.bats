#!/usr/bin/env bats
# _zshrc の回帰テスト (bats-core 1.5 以上)。リポジトリルートで `bats test` を実行する。
# AGENTS.md「検証と完了条件」の構文検査と起動検査を自動化し、規約のうち機械的に確かめられるものも検査する。

bats_require_minimum_version 1.5.0

setup() {
    # PC 固有の設定に依存しないよう、共通設定も一時ディレクトリへコピーする。
    CONFIG_REPO="$BATS_TEST_TMPDIR/config repo"
    mkdir "$CONFIG_REPO"
    ZSHRC="$CONFIG_REPO/_zshrc"
    cp "$BATS_TEST_DIRNAME/../_zshrc" "$ZSHRC"
    cp "$BATS_TEST_DIRNAME/../starship.toml" "$CONFIG_REPO/"
    # ~/.zshrc を差し替えずに作業中の _zshrc を読ませる。compinit の .zcompdump もここにでき、テスト後に消える
    export ZDOTDIR="$BATS_TEST_TMPDIR"
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
    export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
    ln -s "$ZSHRC" "$ZDOTDIR/.zshrc"
}

@test "構文エラーがない" {
    zsh -n "$ZSHRC"
}

@test "対話シェルとして起動すると最後まで読み込まれ、stderr に出力がない" {
    # 非対話ガードより後にある alias (zns) が定義されていれば、ガードを越えて読まれたと判定する
    run -0 --separate-stderr zsh -i -c 'alias zns'
    [ -z "$stderr" ]
}

@test "対話シェルで source し直しても終了状態 0 で、stderr に出力がない" {
    # zns と同じ読み直し。最終行の文が偽で終わると source が失敗するので、その回帰も検出する
    run -0 --separate-stderr zsh -i -c 'source "$ZDOTDIR/.zshrc"'
    [ -z "$stderr" ]
}

@test "非対話シェルから source すると非対話ガードで止まり、終了状態 0 でエラーも出ない" {
    # Claude Code や Codex のシェルスナップショットと同じ読み込み方。ガードより前の PATH は設定され、後の alias・setopt・関数は定義されない
    # 起動元の PATH を固定し、~/.local/bin を rc が足したこと (親から引き継いだのではないこと) を順序で確かめる
    run -0 --separate-stderr env PATH=/usr/bin:/bin zsh -c "
        source '$ZSHRC' || { print \"source の終了状態が \$?\"; exit 1; }
        if alias zns >/dev/null; then print 'ガードより後の alias zns が定義された'; exit 1; fi
        if [[ -o autopushd ]]; then print 'ガードより後の setopt auto_pushd が有効になった'; exit 1; fi
        if (( \$+functions[command_not_found_handler] )); then print 'ガードより後の command-not-found が読まれた'; exit 1; fi
        if (( \$+functions[up] )); then print 'ガードより後の関数 up が定義された'; exit 1; fi
        if [[ -n \$(print -l -- \$path | sort | uniq -d) ]]; then print 'PATH に重複がある'; exit 1; fi
        if (( \${path[(i)\$HOME/.local/bin]} > \${path[(i)/usr/bin]} )); then print \"~/.local/bin が /usr/bin より前に無い: \$PATH\"; exit 1; fi
        print -r -- \"\$PATH\"
    "
    [ -z "$stderr" ]
    [[ ":$output:" == *":$HOME/.local/bin:"* ]]
}

@test "PS1 が export された環境から非対話で source しても非対話ガードで止まる" {
    # 旧ガードは PROMPT の長さで判定していたので、PS1 を export した親から起動されると止まらなかった
    run -0 --separate-stderr env PS1=x zsh -c "
        source '$ZSHRC' || exit 1
        if alias zns >/dev/null; then print 'ガードより後の alias zns が定義された'; exit 1; fi
    "
    [ -z "$stderr" ]
}

@test "ローカル設定は Git 除外され、テンプレートは除外されない" {
    local repo="$BATS_TEST_DIRNAME/.."
    run -0 git -C "$repo" check-ignore -- _zshrc.env.local _zshrc.local
    [ "${#lines[@]}" -eq 2 ]
    run -1 git -C "$repo" check-ignore --no-index -- _zshrc.env.local.template _zshrc.local.template
    [ -z "$output" ]
}

@test "symlink の先にある環境設定だけを非対話で読み込み、proxy と空白付き PATH を引き継ぐ" {
    mkdir -p "$ZDOTDIR/build tools/bin" "$ZDOTDIR/env-home"
    cat > "$CONFIG_REPO/_zshrc.env.local" <<'ZSH'
export http_proxy='http://proxy.example.test:8080'
export https_proxy="$http_proxy"
export no_proxy='localhost,127.0.0.1'
export PATH="$ZDOTDIR/build tools/bin:$PATH"
ZSH
    # 配置先ではなく ZDOTDIR を読んだり、対話用の設定まで読んだりすると失敗する。
    printf 'print -u2 読み込み禁止; return 1\n' > "$ZDOTDIR/_zshrc.env.local"
    printf 'print -u2 読み込み禁止; return 1\n' > "$CONFIG_REPO/_zshrc.local"
    run -0 --separate-stderr env HOME="$ZDOTDIR/env-home" PATH=/usr/bin:/bin zsh -d -f -c '
        source "$ZDOTDIR/.zshrc" || exit 1
        source "$ZDOTDIR/.zshrc" || exit 1
        unique_path=("${(@u)path}")
        (( ${#path} == ${#unique_path} )) || exit 1
        zsh -d -f -c '\''
            [[ $http_proxy == http://proxy.example.test:8080 ]] || exit 1
            [[ $https_proxy == "$http_proxy" && $no_proxy == localhost,127.0.0.1 ]] || exit 1
            [[ $path[1] == "$ZDOTDIR/build tools/bin" ]]
        '\''
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
}

@test "対話用のローカル設定で共通の alias を上書きでき、zns で両ファイルを読み直す" {
    cat > "$CONFIG_REPO/_zshrc.env.local" <<'ZSH'
export EDITOR=local-editor
typeset local_scope_probe=global
local_env_reads=$(( ${local_env_reads:-0} + 1 ))
ZSH
    cat > "$CONFIG_REPO/_zshrc.local" <<'ZSH'
# 補完などの共通設定が終わった後に読まれることを確かめる。
(( $+functions[compdef] )) || return 1
[[ $EDITOR == local-editor ]] || return 1
local_rc_reads=$(( ${local_rc_reads:-0} + 1 ))
alias ll='ls -l'
alias build-special='BUILD_PROFILE=special make'
function build-special-target() { print -r -- "$@"; }
ZSH
    run -0 --separate-stderr zsh -d -i -c '
        [[ $local_env_reads == 1 && $local_rc_reads == 1 ]] || exit 1
        [[ $local_scope_probe == global ]] || exit 1
        [[ ${aliases[ll]} == "ls -l" ]] || exit 1
        [[ ${aliases[build-special]} == "BUILD_PROFILE=special make" ]] || exit 1
        [[ $(build-special-target "a b") == "a b" ]] || exit 1
        zns || exit 1
        [[ $local_env_reads == 2 && $local_rc_reads == 2 ]] || exit 1
        [[ ${aliases[ll]} == "ls -l" ]]
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
}

@test "テンプレートは構文が正しく、初期状態では設定を変更しない" {
    for name in _zshrc.env.local _zshrc.local; do
        cp "$BATS_TEST_DIRNAME/../$name.template" "$CONFIG_REPO/$name"
        zsh -n "$CONFIG_REPO/$name"
    done
    run -0 --separate-stderr zsh -d -i -c '
        [[ ${aliases[ll]} == "ls -lh" ]] || exit 1
        (( ! $+aliases[build-special] && ! $+functions[build-special-target] )) || exit 1
        source "$ZDOTDIR/.zshrc"
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
}

@test "ローカル設定が失敗した場合は警告し、共通設定の source は正常終了する" {
    printf 'false\n' > "$CONFIG_REPO/_zshrc.env.local"
    printf 'false\n' > "$CONFIG_REPO/_zshrc.local"
    run -0 --separate-stderr zsh -d -f -c 'source "$ZDOTDIR/.zshrc"'
    [ -z "$output" ]
    [ "$stderr" = '警告: _zshrc.env.local の読み込みが失敗しました。' ]
    run -0 --separate-stderr zsh -d -f -i -c 'source "$ZDOTDIR/.zshrc"'
    [ -z "$output" ]
    [ "$stderr" = $'警告: _zshrc.env.local の読み込みが失敗しました。\n警告: _zshrc.local の読み込みが失敗しました。' ]
}

@test "ローカル設定の構文エラーを報告し、後続の環境変数と対話用設定を読み込む" {
    printf 'if true; then\n' > "$CONFIG_REPO/_zshrc.env.local"
    printf 'if true; then\n' > "$CONFIG_REPO/_zshrc.local"
    mkdir -p "$ZDOTDIR/parse-home/.local/bin"
    printf '#!/bin/sh\nexit 0\n' > "$ZDOTDIR/parse-home/.local/bin/emacsclient"
    chmod +x "$ZDOTDIR/parse-home/.local/bin/emacsclient"
    run -0 --separate-stderr env -u EDITOR HOME="$ZDOTDIR/parse-home" PATH=/usr/bin:/bin zsh -d -f -c '
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ $EDITOR == "emacsclient -nw -a '\'''\''" ]]
    '
    [ -z "$output" ]
    [[ "$stderr" == *'parse error'* ]]
    [[ "$stderr" == *'警告: _zshrc.env.local の読み込みが失敗しました。'* ]]
    [[ "$stderr" != *'警告: _zshrc.local の読み込みが失敗しました。'* ]]
    run -0 --separate-stderr zsh -d -f -i -c '
        source "$ZDOTDIR/.zshrc" || exit 1
        alias zns >/dev/null || exit 1
        (( $+functions[compdef] ))
    '
    [ -z "$output" ]
    [[ "$stderr" == *'parse error'* ]]
    [[ "$stderr" == *'警告: _zshrc.env.local の読み込みが失敗しました。'* ]]
    [[ "$stderr" == *'警告: _zshrc.local の読み込みが失敗しました。'* ]]
}

@test "source し直しても動的に登録された補完を保持する" {
    # Oh My Zsh の登録と、起動後に追加した登録の両方を保つ。
    run -0 --separate-stderr zsh -i -c '
        [[ ${_comps[ggpnp]} == _git ]] || exit 1
        compdef _files zshrcprobe
        source "$ZDOTDIR/.zshrc" || exit 1
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ ${_comps[ggpnp]} == _git ]] || exit 1
        [[ ${_comps[zshrcprobe]} == _files ]] || exit 1
    '
    [ -z "$stderr" ]
}

@test "Oh My Zsh がなくても再読み込みで補完登録と基本操作を保持する" {
    mkdir "$ZDOTDIR/empty-home"
    run -0 --separate-stderr env HOME="$ZDOTDIR/empty-home" ZSH="$ZDOTDIR/missing-omz" \
        PATH=/usr/bin:/bin EDITOR=vi zsh -d -i -c '
        (( $+functions[compdef] )) || exit 1
        compdef _files fallbackprobe
        source "$ZDOTDIR/.zshrc" || exit 1
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ ${_comps[fallbackprobe]} == _files ]] || exit 1
        [[ $(bindkey "^A") == *beginning-of-line && $(bindkey "^E") == *end-of-line ]] || exit 1
        [[ $(bindkey "^P") == *up-line-or-history && $(bindkey "^N") == *down-line-or-history ]] || exit 1
        [[ -o autocd && -o autopushd && -o pushdignoredups && -o pushdminus && -o pushdsilent ]] || exit 1
        [[ -o sharehistory && -o histignoredups && -o histignorespace && -o histverify ]] || exit 1
        [[ -o histexpiredupsfirst && -o histsavenodups && -o histfindnodups ]] || exit 1
        [[ -o interactivecomments && ! -o beep && ! -o correct && ! -o correctall ]] || exit 1
        (( HISTSIZE > SAVEHIST && SAVEHIST == 10000 ))
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
}

@test "グローバル rc を読まない起動でも補完が初期化される" {
    # OS の設定に依存せず Oh My Zsh、未導入なら標準の compinit で初期化する
    run -0 --separate-stderr zsh -d -i -c '(( $+functions[compdef] )) || { print "compdef がない"; exit 1; }'
    [ -z "$stderr" ]
}

@test "基本の関数と alias を残し、引数や標準コマンドの意味を変える alias は置かない" {
    run -0 zsh -i -c '
        for f in __zshrc_has up; do
            (( $+functions[$f] )) || { print "関数 $f がない"; exit 1; }
        done
        for a in zns gst gd ga gc gm gp gl gco la ll lla mv cp ln ..; do
            (( $+aliases[$a] )) || { print "alias $a がない"; exit 1; }
        done
        for a in rm poweroff reboot go rmtmp gtd gtc gtm gtp gtco; do
            (( ! $+aliases[$a] )) || { print "alias $a が残っている"; exit 1; }
        done
        (( ${#galiases} == 0 && ${#saliases} == 0 ))
    '
}

@test "git の alias は標準の alias 展開を通して補完し、候補選択を明示的に行う" {
    run -0 zsh -i -c '
        [[ ! -o completealiases && ! -o menucomplete ]] || exit 1
        [[ ${_comps[git]} == _git ]] || exit 1
        [[ ${aliases[gst]} == "git status" && ${aliases[gco]} == "git checkout" ]] || exit 1
        [[ ${aliases[gts]} == "git tag --sign" ]] || exit 1
        [[ ${aliases[gta]} == "git tag --annotate" ]] || exit 1
        [[ ${aliases[gtl]} == *"git tag --sort=-v:refname"* ]] || exit 1
        zstyle -a ":completion:*" menu reply
        [[ $reply == select ]]
    '
}

@test "Home / End は通常モードのシーケンスにも割り当てる" {
    run -0 zsh -i -c 'bindkey "^[[H"; bindkey "^[[F"'
    [ "${lines[0]}" = '"^[[H" beginning-of-line' ]
    [ "${lines[1]}" = '"^[[F" end-of-line' ]
}

@test "OS や呼び出し元の TERM・ロケール・DISPLAY・umask を上書きしない" {
    for terminal in xterm tmux-256color dumb; do
        run -0 --separate-stderr env TERM="$terminal" LANG=C LC_ALL=C DISPLAY=localhost:10.0 WSL_DISTRO_NAME=probe \
            zsh -d -f -i -c '
                umask 077
                source "$ZDOTDIR/.zshrc" || exit 1
                print -r -- "$TERM|$LANG|$LC_ALL|$DISPLAY|$(umask)"
            '
        [ -z "$stderr" ]
        [ "$output" = "$terminal|C|C|localhost:10.0|077" ]
    done
}

@test "WSL では ow の配色を di に揃え、補完の色は現在の LS_COLORS に従う" {
    # 重複キーは ls・complist・fzf-tab で優先順位が異なるため、既存の ow= をすべて除いて末尾に付け、再読み込みでも増やさない。
    # tw など他のキーは保つ
    run -0 --separate-stderr env WSL_DISTRO_NAME=probe LS_COLORS='rs=0:di=01;35:ow=34;42:tw=30;42:*.tar=01;31:ow=1;2' \
        zsh -d -f -i -c '
        source "$ZDOTDIR/.zshrc" || exit 1
        expected="rs=0:di=01;35:tw=30;42:*.tar=01;31:ow=01;35"
        [[ $LS_COLORS == "$expected" ]] || { print -r -- "LS_COLORS: $LS_COLORS"; exit 1; }
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ $LS_COLORS == "$expected" ]] || { print -r -- "再読み込み後: $LS_COLORS"; exit 1; }
        for v in colors dir_color; do
            if (( $+parameters[$v] )); then print "作業用の変数 $v が残っている"; exit 1; fi
        done
        # 補完の色は zstyle の定義時ではなく参照時の LS_COLORS を使う
        zstyle -a ":completion:*" list-colors reply
        [[ "${(j.:.)reply}" == "$expected" ]] || { print -r -- "list-colors: $reply"; exit 1; }
        LS_COLORS="di=01;36"
        zstyle -a ":completion:*" list-colors reply
        [[ $reply == "di=01;36" ]]
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
    # di が無ければ dircolors 既定のディレクトリ色にする
    run -0 --separate-stderr env WSL_DISTRO_NAME=probe LS_COLORS='ow=34;42:ex=01;32' zsh -d -f -i -c '
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ $LS_COLORS == "ex=01;32:ow=01;34" ]] || { print -r -- "LS_COLORS: $LS_COLORS"; exit 1; }
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
}

@test "LS_COLORS が無い環境では補完に ls 既定色を使い、FZF_DEFAULT_OPTS は未指定のときだけ設定する" {
    mkdir "$BATS_TEST_TMPDIR/empty-home"
    # Oh My Zsh も dircolors も無い環境。空文字 1 つの list-colors は zsh 組み込みの ls 既定色を意味する
    run -0 --separate-stderr env -u LS_COLORS HOME="$BATS_TEST_TMPDIR/empty-home" ZSH="$BATS_TEST_TMPDIR/missing-omz" \
        PATH=/usr/bin:/bin zsh -d -f -i -c '
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ -z $LS_COLORS ]] || { print -r -- "LS_COLORS: $LS_COLORS"; exit 1; }
        zstyle -a ":completion:*" list-colors reply
        (( ${#reply} == 1 )) && [[ -z $reply[1] ]]
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
    # 呼び出し元やローカル設定の FZF_DEFAULT_OPTS を上書きしない
    run -0 --separate-stderr env FZF_DEFAULT_OPTS='--color=light' zsh -d -f -c '
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ $FZF_DEFAULT_OPTS == "--color=light" ]]
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
}


@test "typeset -gU path PATH は最初の PATH の変更と非対話ガードより前にある" {
    typeset_line=$(grep -n '^typeset -gU path PATH$' "$ZSHRC" | cut -d: -f1)
    first_path_line=$(grep -n 'PATH=' "$ZSHRC" | head -n 1 | cut -d: -f1)
    guard_line=$(grep -n '^\[\[ -o interactive \]\] || return 0$' "$ZSHRC" | cut -d: -f1)
    [ -n "$typeset_line" ] && [ -n "$first_path_line" ] && [ -n "$guard_line" ]
    [ "$typeset_line" -lt "$first_path_line" ] && [ "$typeset_line" -lt "$guard_line" ]
}

@test "対話シェルに作業用のグローバル変数を残さない" {
    # 関数の外で local にしていたプロンプトの色変数と、ホスト名補完の作業用配列 (旧名と無名関数内の local)
    run -0 zsh -i -c '
        for v in GREEN BLUE DEFAULT hosts _etc_hosts _ssh_hosts ssh_hosts etc_hosts; do
            if (( $+parameters[$v] )); then print "変数 $v が残っている"; exit 1; fi
        done
    '
}

@test "up はカレントを含めて上へたどり、見つからなければ失敗する" {
    mkdir -p "$BATS_TEST_TMPDIR/a/src/foo/src/bar"
    run -0 zsh -i -c '
        cd "$ZDOTDIR/a/src/foo/src/bar"
        up src; [[ $PWD == "$ZDOTDIR/a/src/foo/src" ]] || { print "up src: $PWD"; exit 1; }
        cd "$ZDOTDIR/a/src/foo/src/bar"
        up foo; [[ $PWD == "$ZDOTDIR/a/src/foo" ]] || { print "up foo: $PWD"; exit 1; }
        cd "$ZDOTDIR/a/src/foo/src/bar"
        up bar; [[ $PWD == "$ZDOTDIR/a/src/foo/src/bar" ]] || { print "up bar: $PWD"; exit 1; }
        cd /usr/share
        up usr; [[ $PWD == /usr ]] || { print "up usr: $PWD"; exit 1; }
        for v in to p current_path target; do
            if (( $+parameters[$v] )); then print "up のローカル変数 $v が残っている"; exit 1; fi
        done
    '
    run -1 --separate-stderr zsh -i -c 'cd /; up nope'
    [ "$stderr" = "no such file or directory: nope" ]
    [ -z "$output" ]
}

@test "ユーザー名を含む絶対パスが無い" {
    run -1 grep -nE '/(home|Users)/' "$ZSHRC" \
        "$BATS_TEST_DIRNAME/../_zshrc.env.local.template" "$BATS_TEST_DIRNAME/../_zshrc.local.template"
}

@test "EDITOR が vi でも emacs 形式のキーと先頭一致の履歴検索を使える" {
    run -0 --separate-stderr env EDITOR=vi zsh -d -i -c '
        [[ $EDITOR == vi ]] || exit 1
        bindkey "^A"
        bindkey "^E"
        bindkey "^[[A"
        bindkey "^[[B"
        bindkey "^R"
        bindkey "^P"
        bindkey "^N"
    '
    [ -z "$stderr" ]
    [ "${lines[0]}" = '"^A" beginning-of-line' ]
    [ "${lines[1]}" = '"^E" end-of-line' ]
    [ "${lines[2]}" = '"^[[A" up-line-or-beginning-search' ]
    [ "${lines[3]}" = '"^[[B" down-line-or-beginning-search' ]
    [ "${lines[4]}" = '"^R" history-incremental-search-backward' ]
    [ "${lines[5]}" = '"^P" up-line-or-beginning-search' ]
    [ "${lines[6]}" = '"^N" down-line-or-beginning-search' ]
}

@test "履歴は保存件数に余裕を持たせ、重複を整理して履歴展開を確認できる" {
    run -0 zsh -i -c '
        (( HISTSIZE > SAVEHIST && SAVEHIST == 10000 )) || exit 1
        [[ -o sharehistory && -o histignorespace && -o histverify ]] || exit 1
        [[ -o histexpiredupsfirst && -o histfindnodups && -o histsavenodups ]] || exit 1
        [[ ! -o correct && ! -o correctall ]]
    '
}

@test "起動時の自動更新を無効にし、Oh My Zsh のテーマと独自 Git プロンプトを重ねない" {
    run -0 --separate-stderr zsh -i -c '
        zstyle -s ":omz:update" mode mode
        [[ $mode == disabled && -z $ZSH_THEME ]] || exit 1
        (( ! $+functions[__zshrc_vcs] )) || exit 1
        [[ -o promptcr && -o promptsp ]]
    '
    [ -z "$stderr" ]
}

@test "繰り返し読み込んでもフックと PATH を重複させない" {
    run -0 --separate-stderr zsh -i -c '
        source "$ZDOTDIR/.zshrc" || exit 1
        source "$ZDOTDIR/.zshrc" || exit 1
        unique_hooks=(${(u)precmd_functions})
        (( ${#precmd_functions} == ${#unique_hooks} )) || exit 1
        unique_hooks=(${(u)chpwd_functions})
        (( ${#chpwd_functions} == ${#unique_hooks} )) || exit 1
        unique_path=("${(@u)path}")
        (( ${#path} == ${#unique_path} ))
    '
    [ -z "$stderr" ]
}

@test "非対話で source しても Oh My Zsh と画面用のツールは実行しない" {
    mkdir -p "$BATS_TEST_TMPDIR/forbidden"
    printf 'print -u2 読み込み禁止; return 1\n' > "$BATS_TEST_TMPDIR/forbidden/oh-my-zsh.sh"
    run -0 --separate-stderr env ZSH="$BATS_TEST_TMPDIR/forbidden" zsh -c '
        source "$ZDOTDIR/.zshrc"
    '
    [ -z "$stderr" ]
    [ -z "$output" ]
}

@test "up は引数なしで親へ移動し、空文字や複数の名前を拒否する" {
    mkdir -p "$BATS_TEST_TMPDIR/parent/child"
    run -0 zsh -i -c '
        cd "$ZDOTDIR/parent/child"
        up
        [[ $PWD == "$ZDOTDIR/parent" ]]
    '
    run -1 zsh -i -c 'up ""'
    [ "$output" = '使い方: up [ディレクトリ名]' ]
    run -1 zsh -i -c 'up a b'
    [ "$output" = '使い方: up [ディレクトリ名]' ]
    run -1 zsh -i -c 'up a/b'
    [ "$output" = '使い方: up [ディレクトリ名]' ]
}

@test "zns は現在の ZDOTDIR から読み直し、コンパイルファイルを作らない" {
    run -0 --separate-stderr zsh -i -c 'zns'
    [ -z "$stderr" ]
    [ ! -e "$ZDOTDIR/.zshrc.zwc" ]
}

@test "追加ツールのない環境でも標準機能で起動できる" {
    mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/empty-home"
    # compdump の保存に必要な coreutils だけを PATH に残す。
    ln -s /usr/bin/mv "$BATS_TEST_TMPDIR/bin/mv"
    run -0 --separate-stderr zsh -d -f -i -c '
        path=("$ZDOTDIR/bin")
        HOME="$ZDOTDIR/empty-home"
        ZSH="$HOME/.oh-my-zsh"
        TERM=dumb
        source "$ZDOTDIR/.zshrc" || exit 1
        (( $+functions[compdef] && $+functions[up] )) || exit 1
        (( ! $+functions[__zshrc_vcs] && ! $+functions[fzf-history-widget] )) || exit 1
        (( ! $+aliases[ecli] ))
    '
    [ -z "$stderr" ]
}

# fnm env のシェルごとの PATH 生成を再現し、実際の Node.js 導入に依存せず検査する。
prepare_fnm() {
    export HOME="$ZDOTDIR/fnm-home"
    export PATH="$HOME/.local/share/fnm:/usr/bin:/bin"
    mkdir -p "$HOME/.local/share/fnm"
    cat > "$HOME/.local/share/fnm/fnm" <<'SCRIPT'
#!/bin/sh
[ "$*" = 'env --shell zsh' ] || exit 1
if [ -f "$HOME/fnm-fail" ]; then
    printf 'fnm env の失敗\n' >&2
    exit 1
fi
multishell=$(mktemp -d "$HOME/multishell.XXXXXX")
mkdir "$multishell/bin"
printf '#!/bin/sh\nprintf "default\\n"\n' > "$multishell/bin/node"
chmod +x "$multishell/bin/node"
printf 'export FNM_MULTISHELL_PATH="%s"\nexport PATH="%s/bin:$PATH"\n' "$multishell" "$multishell"
SCRIPT
    chmod +x "$HOME/.local/share/fnm/fnm"
}

@test "fnm は再読み込みで選択版と PATH を保ち、子シェルでは独立して初期化する" {
    prepare_fnm
    mkdir -p "$HOME/build-tools/bin"
    printf 'export PATH="$HOME/build-tools/bin:$PATH"\n' > "$CONFIG_REPO/_zshrc.env.local"
    run -0 --separate-stderr zsh -d -f -c '
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ $(node) == default ]] || exit 1
        [[ $path[2] == "$HOME/build-tools/bin" ]] || exit 1
        export parent_multishell=$FNM_MULTISHELL_PATH
        before=$PATH
        # fnm use に相当する選択変更。再初期化すると新しい default に戻ってしまう。
        printf "#!/bin/sh\nprintf selected" > "$FNM_MULTISHELL_PATH/bin/node"
        source "$ZDOTDIR/.zshrc" || exit 1
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ $FNM_MULTISHELL_PATH == "$parent_multishell" && $PATH == "$before" ]] || exit 1
        [[ $(node) == selected && $path[1] == "$FNM_MULTISHELL_PATH/bin" ]] || exit 1
        (( ! $+parameters[init] )) || exit 1
        zsh -d -f -c '\''
            source "$ZDOTDIR/.zshrc" || exit 1
            [[ $FNM_MULTISHELL_PATH != "$parent_multishell" && $(node) == default ]]
        '\'' || exit 1
        [[ $(node) == selected ]]
    '
    [ -z "$output" ]
    [ -z "$stderr" ]
}

@test "fnm の初期化に失敗しても次の読み込みで再試行できる" {
    prepare_fnm
    touch "$HOME/fnm-fail"
    run -0 --separate-stderr zsh -d -f -c '
        source "$ZDOTDIR/.zshrc" || exit 1
        (( ! $+parameters[__zshrc_fnm_pid] && ! $+parameters[init] )) || exit 1
        rm "$HOME/fnm-fail"
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ $(node) == default && $path[1] == "$FNM_MULTISHELL_PATH/bin" ]]
    '
    [ -z "$output" ]
    [ "$stderr" = 'fnm env の失敗' ]
}
