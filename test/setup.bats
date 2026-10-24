#!/usr/bin/env bats
# 実際の HOME を変更せず、導入・復元と既存ファイルの保護を確認する。
bats_require_minimum_version 1.5.0
load setup-tools

setup() {
    SETUP_SCRIPT="$BATS_TEST_DIRNAME/../setup.sh"
    SOURCE_FILE="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)/_zshrc"
    export HOME="$BATS_TEST_TMPDIR/home with spaces"
    mkdir -p "$HOME"
    export ZDOTDIR="$HOME"
    BACKUP="$HOME/.zshrc.zsh-config-backup"
    prepare_tools
}

@test "新規導入と uninstall で元の空の状態へ戻る" {
    run -0 bash "$SETUP_SCRIPT" install
    [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]
    [ -x "$HOME/.fzf/bin/fzf" ]
    [ -x "$HOME/.local/bin/starship" ]
    [ -x "$HOME/.local/bin/zoxide" ]
    [ "$(readlink "$HOME/.zshrc")" = "$SOURCE_FILE" ]
    [ -d "$BACKUP" ]
    run -0 bash "$SETUP_SCRIPT" uninstall
    [ ! -L "$HOME/.zshrc" ]
    [ ! -e "$HOME/.zshrc" ]
    [ ! -e "$BACKUP" ]
}

@test "既存の設定と読み取り専用のコンパイル結果を復元する" {
    printf '元の設定\n' > "$HOME/.zshrc"
    printf '元のコンパイル結果\n' > "$HOME/.zshrc.zwc"
    chmod 444 "$HOME/.zshrc.zwc"
    run -0 bash "$SETUP_SCRIPT" install
    [ ! -e "$HOME/.zshrc.zwc" ]
    printf '導入後のコンパイル結果\n' > "$HOME/.zshrc.zwc"
    run -0 bash "$SETUP_SCRIPT" uninstall
    [ "$(cat "$HOME/.zshrc")" = '元の設定' ]
    [ "$(cat "$HOME/.zshrc.zwc")" = '元のコンパイル結果' ]
    [ ! -w "$HOME/.zshrc.zwc" ]
}

@test "繰り返し install しても退避内容を上書きしない" {
    printf '元の設定\n' > "$HOME/.zshrc"
    run -0 bash "$SETUP_SCRIPT" install
    run -0 bash "$SETUP_SCRIPT" install
    [ "$(wc -l < "$TOOLS_DOWNLOAD_LOG")" -eq 2 ]
    [ "$(cat "$BACKUP/.zshrc")" = '元の設定' ]
    run -0 bash "$SETUP_SCRIPT" uninstall
    [ "$(cat "$HOME/.zshrc")" = '元の設定' ]
}

@test "リンク切れの設定もリンクのまま復元する" {
    ln -s '存在しない設定' "$HOME/.zshrc"
    run -0 bash "$SETUP_SCRIPT" install
    [ "$(readlink "$BACKUP/.zshrc")" = '存在しない設定' ]
    run -0 bash "$SETUP_SCRIPT" uninstall
    [ "$(readlink "$HOME/.zshrc")" = '存在しない設定' ]
}

@test "手動で導入済みの同じリンクも退避して元どおり復元する" {
    ln -s "$SOURCE_FILE" "$HOME/.zshrc"
    run -0 bash "$SETUP_SCRIPT" install
    [ "$(readlink "$BACKUP/.zshrc")" = "$SOURCE_FILE" ]
    run -0 bash "$SETUP_SCRIPT" uninstall
    [ "$(readlink "$HOME/.zshrc")" = "$SOURCE_FILE" ]
    [ ! -e "$BACKUP" ]
}

@test "既存の退避先があると何も変更しない" {
    printf '元の設定\n' > "$HOME/.zshrc"
    mkdir "$BACKUP"
    printf '退避済み\n' > "$BACKUP/.zshrc"
    run -1 bash "$SETUP_SCRIPT" install
    [ "$(cat "$HOME/.zshrc")" = '元の設定' ]
    [ "$(cat "$BACKUP/.zshrc")" = '退避済み' ]
}

@test "リンク先が別の設定へ変更されたら uninstall は触らない" {
    run -0 bash "$SETUP_SCRIPT" install
    ln -sfn '別の設定' "$HOME/.zshrc"
    printf '別のコンパイル結果\n' > "$HOME/.zshrc.zwc"
    run -1 bash "$SETUP_SCRIPT" uninstall
    [ "$(readlink "$HOME/.zshrc")" = '別の設定' ]
    [ "$(cat "$HOME/.zshrc.zwc")" = '別のコンパイル結果' ]
    [ -d "$BACKUP" ]
}

@test "設定またはコンパイル結果がディレクトリなら拒否する" {
    for name in .zshrc .zshrc.zwc; do
        mkdir "$HOME/$name"
        run -1 bash "$SETUP_SCRIPT" install
        [ -d "$HOME/$name" ]
        [ ! -e "$BACKUP" ]
        rmdir "$HOME/$name"
    done
}

@test "ディレクトリを指すリンクもリンク先へ触れずに復元する" {
    mkdir "$HOME/元のディレクトリ"
    ln -s "$HOME/元のディレクトリ" "$HOME/.zshrc"
    run -0 bash "$SETUP_SCRIPT" install
    run -0 bash "$SETUP_SCRIPT" uninstall
    [ "$(readlink "$HOME/.zshrc")" = "$HOME/元のディレクトリ" ]
    [ -d "$HOME/元のディレクトリ" ]
}

@test "別の ZDOTDIR がある環境では変更しない" {
    export ZDOTDIR="$HOME/別の設定場所"
    run -1 bash "$SETUP_SCRIPT" install
    [ ! -e "$HOME/.zshrc" ]
    [ ! -e "$BACKUP" ]
}

@test "最初の退避が失敗しても手動導入済みのリンクを削除しない" {
    ln -s "$SOURCE_FILE" "$HOME/.zshrc"
    printf '元のコンパイル結果\n' > "$HOME/.zshrc.zwc"
    # バイナリ配置ではなく、設定の退避で mv が失敗するようにする。
    mkdir -p "$HOME/.local/bin"
    for tool in starship zoxide; do
        printf '#!/bin/sh\nexit 0\n' > "$HOME/.local/bin/$tool"
        chmod +x "$HOME/.local/bin/$tool"
    done
    mkdir "$HOME/bin"
    printf '#!/bin/sh\nexit 1\n' > "$HOME/bin/mv"
    chmod +x "$HOME/bin/mv"
    run -1 env PATH="$HOME/bin:$PATH" bash "$SETUP_SCRIPT" install
    [ "$(readlink "$HOME/.zshrc")" = "$SOURCE_FILE" ]
    [ "$(cat "$HOME/.zshrc.zwc")" = '元のコンパイル結果' ]
    [ ! -e "$BACKUP" ]
}

@test "リンク作成が失敗しても退避した設定とコンパイル結果を戻す" {
    printf '元の設定\n' > "$HOME/.zshrc"
    printf '元のコンパイル結果\n' > "$HOME/.zshrc.zwc"
    mkdir "$HOME/bin"
    printf '#!/bin/sh\nexit 1\n' > "$HOME/bin/ln"
    chmod +x "$HOME/bin/ln"
    run -1 env PATH="$HOME/bin:$PATH" bash "$SETUP_SCRIPT" install
    [ "$(cat "$HOME/.zshrc")" = '元の設定' ]
    [ "$(cat "$HOME/.zshrc.zwc")" = '元のコンパイル結果' ]
    [ ! -e "$BACKUP" ]
}

@test "コンパイル結果がリンクでもリンク先のファイルは削除しない" {
    run -0 bash "$SETUP_SCRIPT" install
    printf '保持するファイル\n' > "$HOME/保持するファイル"
    ln -s "$HOME/保持するファイル" "$HOME/.zshrc.zwc"
    run -0 bash "$SETUP_SCRIPT" uninstall
    [ "$(cat "$HOME/保持するファイル")" = '保持するファイル' ]
    [ ! -L "$HOME/.zshrc.zwc" ]
}

@test "取得に失敗しても元の設定を保持し、再実行で導入できる" {
    printf '元の設定\n' > "$HOME/.zshrc"
    run -22 env FAIL_DOWNLOAD=1 bash "$SETUP_SCRIPT" install
    [ "$(cat "$HOME/.zshrc")" = '元の設定' ]
    [ ! -e "$BACKUP" ]
    run -0 bash "$SETUP_SCRIPT" install
    [ "$(cat "$BACKUP/.zshrc")" = '元の設定' ]
}

@test "update は公式配布元の変更を取り込み、設定の退避には触らない" {
    printf '元の設定\n' > "$HOME/.zshrc"
    run -0 bash "$SETUP_SCRIPT" install
    local upstream="$BATS_TEST_TMPDIR/upstream/ohmyzsh/ohmyzsh.git"
    printf '# 更新\n' > "$upstream/oh-my-zsh.sh"
    git -C "$upstream" add -- oh-my-zsh.sh
    git -C "$upstream" commit -qm 'テスト用の更新'
    run -0 bash "$SETUP_SCRIPT" update
    [ "$(cat "$HOME/.oh-my-zsh/oh-my-zsh.sh")" = '# 更新' ]
    [ "$(cat "$BACKUP/.zshrc")" = '元の設定' ]
    [ "$(wc -l < "$TOOLS_DOWNLOAD_LOG")" -eq 4 ]
}

@test "update は依存リポジトリの未コミット変更を保持して停止する" {
    run -0 bash "$SETUP_SCRIPT" install
    printf '# 手元の変更\n' > "$HOME/.oh-my-zsh/oh-my-zsh.sh"
    run -1 bash "$SETUP_SCRIPT" update
    [ "$(cat "$HOME/.oh-my-zsh/oh-my-zsh.sh")" = '# 手元の変更' ]
    [ "$(wc -l < "$TOOLS_DOWNLOAD_LOG")" -eq 2 ]
}

@test "既存の導入先が別のリポジトリなら上書きしない" {
    run -0 bash "$SETUP_SCRIPT" install
    git -C "$HOME/.oh-my-zsh" remote set-url origin https://example.invalid/unrelated.git
    run -1 bash "$SETUP_SCRIPT" install
    [[ $output == *'origin が公式 URL と異なります'* ]]
    [ "$(readlink "$HOME/.zshrc")" = "$SOURCE_FILE" ]
}

@test "update は別の場所を指すバイナリのリンク先へ書き込まない" {
    run -0 bash "$SETUP_SCRIPT" install
    mv "$HOME/.local/bin/starship" "$HOME/保持するツール"
    ln -s "$HOME/保持するツール" "$HOME/.local/bin/starship"
    run -1 bash "$SETUP_SCRIPT" update
    [ -L "$HOME/.local/bin/starship" ]
    [ "$("$HOME/保持するツール")" = 'starship test-version' ]
}
