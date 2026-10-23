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
    # 非端末ガードより後にある alias (zns) が定義されていれば、ガードを越えて読まれたと判定する
    run -0 --separate-stderr zsh -i -c 'alias zns'
    [ -z "$stderr" ]
}

@test "非対話シェルから source すると非端末ガードで止まり、エラーも出ない" {
    # Claude Code や Codex のシェルスナップショットと同じ読み込み方。ガードより前の PATH は設定され、後の alias は定義されない
    run -0 --separate-stderr zsh -c "
        source '$ZSHRC'
        if alias zns >/dev/null; then print 'ガードより後の alias zns が定義された'; exit 1; fi
        print -r -- \"\$PATH\"
    "
    [ -z "$stderr" ]
    [[ ":$output:" == *":$HOME/.local/bin:"* ]]
}

@test "常に定義する関数と alias がそろっている" {
    run -0 zsh -i -c '
        for f in __zshrc_has up cdup cdback; do
            (( $+functions[$f] )) || { print "関数 $f がない"; exit 1; }
        done
        for a in zns gts gtd gta gtc gtm gtp gtl gtco la ll lla mv cp rm ln rmtmp poweroff reboot s l ks lsa cd..; do
            (( $+aliases[$a] )) || { print "alias $a がない"; exit 1; }
        done
        # グローバル alias は引数の位置でも展開されるので、名前はクォートして渡す
        for a in "G" "L" "H" "T" "S" "W" "X" "sl" "LS"; do
            (( $+galiases[$a] )) || { print "グローバル alias $a がない"; exit 1; }
        done
    '
}

@test "最終行が typeset -U path PATH のままである" {
    [ "$(tail -n 1 "$ZSHRC")" = "typeset -U path PATH" ]
}

@test "ユーザー名を含む絶対パスが無い" {
    run -1 grep -nE '/(home|Users)/' "$ZSHRC"
}
