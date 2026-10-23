#!/usr/bin/env bats
# _zshrc の回帰テスト (bats-core 1.5 以上)。リポジトリルートで `bats test` を実行する。
# AGENTS.md「検証と完了条件」の構文検査と起動検査を自動化し、規約のうち機械的に確かめられるものも検査する。

bats_require_minimum_version 1.5.0

setup() {
    ZSHRC="$BATS_TEST_DIRNAME/../_zshrc"
    # ~/.zshrc を差し替えずに作業中の _zshrc を読ませる。compinit の .zcompdump もここにでき、テスト後に消える
    export ZDOTDIR="$BATS_TEST_TMPDIR"
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
    # zns (zcompile ~/.zshrc && source ~/.zshrc) と同じ読み直し。最終行の文が偽で終わると source が失敗するので、その回帰も検出する
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

@test "source し直すと compinit を再実行し、後から足した補完関数を拾う" {
    # 起動時は /etc/zsh/zshrc の compinit を使い回すが、zns のような読み直し (__zshrc_loaded が設定済み) では再実行する
    mkdir -p "$BATS_TEST_TMPDIR/fn"
    printf '#compdef zshrcprobe\n_files\n' > "$BATS_TEST_TMPDIR/fn/_zshrcprobe"
    run -0 --separate-stderr zsh -i -c '
        fpath=("$ZDOTDIR/fn" $fpath)
        source "$ZDOTDIR/.zshrc" || exit 1
        [[ ${_comps[zshrcprobe]} == _zshrcprobe ]] || { print "読み直しで compinit が走っていない: ${_comps[zshrcprobe]:-(none)}"; exit 1; }
    '
    [ -z "$stderr" ]
}

@test "グローバル rc を読まない起動でも補完が初期化される" {
    # Ubuntu 以外 (/etc/zsh/zshrc が compinit を実行しない環境) と同じ経路。自前の compinit が走る
    run -0 --separate-stderr zsh -d -i -c '(( $+functions[compdef] )) || { print "compdef がない"; exit 1; }'
    [ -z "$stderr" ]
}

@test "常に定義する関数と alias がそろっている" {
    run -0 zsh -i -c '
        for f in __zshrc_has up cdup cdback; do
            (( $+functions[$f] )) || { print "関数 $f がない"; exit 1; }
        done
        for a in zns gts gtd gta gtc gtm gtp gtl gtco la ll lla mv cp rm ln rmtmp poweroff reboot s l ks sl LS lsa cd..; do
            (( $+aliases[$a] )) || { print "alias $a がない"; exit 1; }
        done
        # グローバル alias は引数の位置でも展開されるので、名前はクォートして渡す
        for a in "G" "L" "H" "T" "S" "W" "X"; do
            (( $+galiases[$a] )) || { print "グローバル alias $a がない"; exit 1; }
        done
        # sl / LS は引数の位置で展開されないよう、通常の alias にしている
        if (( $+galiases[sl] || $+galiases[LS] )); then print "sl / LS がグローバル alias になっている"; exit 1; fi
    '
}

@test "git の alias に git の補完が割り当てられている" {
    run -0 zsh -i -c '
        for a in gts:git-status gtd:git-diff gta:git-add gtc:git-commit gtm:git-merge gtp:git-push gtl:git-log gtco:git-checkout; do
            [[ ${_comps[${a%%:*}]} == _git && ${_services[${a%%:*}]} == ${a#*:} ]] || { print "$a: comps=${_comps[${a%%:*}]} services=${_services[${a%%:*}]}"; exit 1; }
        done
    '
}

@test "Home / End は通常モードのシーケンスにも割り当てる" {
    run -0 zsh -i -c 'bindkey "^[[H"; bindkey "^[[F"'
    [ "${lines[0]}" = '"^[[H" beginning-of-line' ]
    [ "${lines[1]}" = '"^[[F" end-of-line' ]
}

@test "TERM は xterm のときだけ xterm-256color に昇格し、端末タイトルは dumb などタイトルを扱えない端末以外で設定する" {
    # precmd_functions が未定義 (フックを登録していない) なら添字 (I) は空になるので 0 に寄せる
    run -0 env TERM=xterm zsh -i -c 'print -r -- "$TERM ${precmd_functions[(I)__zshrc_title]:-0}"'
    [ "$output" = "xterm-256color 1" ]
    run -0 env TERM=tmux-256color zsh -i -c 'print -r -- "$TERM ${precmd_functions[(I)__zshrc_title]:-0}"'
    [ "$output" = "tmux-256color 1" ]
    run -0 env TERM=dumb zsh -i -c 'print -r -- "$TERM ${precmd_functions[(I)__zshrc_title]:-0}"'
    [ "$output" = "dumb 0" ]
}

@test "rmtmp はバックアップと Emacs の自動保存ファイルだけを消す" {
    mkdir -p "$BATS_TEST_TMPDIR/both" "$BATS_TEST_TMPDIR/only-backup" "$BATS_TEST_TMPDIR/only-autosave" "$BATS_TEST_TMPDIR/empty"
    touch "$BATS_TEST_TMPDIR/both/a~" "$BATS_TEST_TMPDIR/both/#b#" "$BATS_TEST_TMPDIR/both/-x~" "$BATS_TEST_TMPDIR/both/c"
    touch "$BATS_TEST_TMPDIR/only-backup/a~" "$BATS_TEST_TMPDIR/only-backup/c"
    touch "$BATS_TEST_TMPDIR/only-autosave/#b#" "$BATS_TEST_TMPDIR/only-autosave/c"
    # 両方あるとき、片方しか無いとき (旧 alias は *~ が無いと no matches found で止まった) のどれでも対象だけを消し、c は残す
    for d in both only-backup only-autosave; do
        run -0 zsh -i -c "cd \"\$ZDOTDIR/$d\" && rmtmp >/dev/null && ls -A"
        [ "$output" = "c" ]
    done
    # 対象が無いときは rm が missing operand で失敗する (旧 alias の no matches found と同じく終了状態 1)
    run -1 zsh -i -c 'cd "$ZDOTDIR/empty" && rmtmp 2>/dev/null'
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
        for v in to p; do
            if (( $+parameters[$v] )); then print "up のローカル変数 $v が残っている"; exit 1; fi
        done
    '
    run -1 --separate-stderr zsh -i -c 'cd /; up nope'
    [ "$stderr" = "no such file or directory: nope" ]
    [ -z "$output" ]
}

@test "ユーザー名を含む絶対パスが無い" {
    run -1 grep -nE '/(home|Users)/' "$ZSHRC"
}
