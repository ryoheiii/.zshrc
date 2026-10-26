#!/usr/bin/env bats
# 実際の HOME を変更せず、導入・復元と既存ファイルの保護を確認する。
bats_require_minimum_version 1.5.0
load setup-tools

setup() {
    prepare_configuration_repo
    export HOME="$BATS_TEST_TMPDIR/home with spaces"
    mkdir -p "$HOME"
    export ZDOTDIR="$HOME"
    unset ZSH_CUSTOM
    BACKUP="$HOME/.zshrc.zsh-config-backup"
    prepare_tools
}

@test "新規導入と uninstall で元の空の状態へ戻る" {
    run -0 bash "$SETUP_SCRIPT" install
    [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]
    [ -x "$HOME/.fzf/bin/fzf" ]
    [ -f "$HOME/.oh-my-zsh/custom/plugins/fzf-tab/fzf-tab.plugin.zsh" ]
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

@test "ローカル設定をテンプレートから作成し、再導入・更新・削除でも編集内容を保持する" {
    run -0 bash "$SETUP_SCRIPT" install
    for name in _zshrc.env.local _zshrc.local; do
        cmp "$CONFIG_REPO/$name.template" "$CONFIG_REPO/$name"
        [ "$(stat -c '%a' "$CONFIG_REPO/$name")" = 600 ]
        printf '# この PC の設定\n' > "$CONFIG_REPO/$name"
    done
    run -0 bash "$SETUP_SCRIPT" install
    run -0 bash "$SETUP_SCRIPT" update
    run -0 bash "$SETUP_SCRIPT" uninstall
    for name in _zshrc.env.local _zshrc.local; do
        [ "$(cat "$CONFIG_REPO/$name")" = '# この PC の設定' ]
    done
}

@test "既存のローカル設定へのリンクを保ち、不正な配置やテンプレート不足は退避前に拒否する" {
    printf '# 別の場所の設定\n' > "$HOME/custom.zsh"
    ln -s "$HOME/custom.zsh" "$CONFIG_REPO/_zshrc.env.local"
    run -0 bash "$SETUP_SCRIPT" install
    [ -L "$CONFIG_REPO/_zshrc.env.local" ]
    [ "$(cat "$HOME/custom.zsh")" = '# 別の場所の設定' ]
    run -0 bash "$SETUP_SCRIPT" uninstall
    rm "$CONFIG_REPO/_zshrc.local"
    mkdir "$CONFIG_REPO/_zshrc.local"
    run -1 bash "$SETUP_SCRIPT" install
    [ ! -e "$BACKUP" ]
    rmdir "$CONFIG_REPO/_zshrc.local"
    ln -s missing "$CONFIG_REPO/_zshrc.local"
    run -1 bash "$SETUP_SCRIPT" install
    [ -L "$CONFIG_REPO/_zshrc.local" ]
    [ ! -e "$BACKUP" ]
    rm "$CONFIG_REPO/_zshrc.local" "$CONFIG_REPO/_zshrc.local.template"
    run -1 bash "$SETUP_SCRIPT" install
    [ ! -e "$BACKUP" ]
    [ ! -e "$HOME/.zshrc" ]
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
    # 導入済みの PC が git pull 後に更新する場合も、未作成のローカル設定を用意する。
    rm "$CONFIG_REPO/_zshrc.env.local" "$CONFIG_REPO/_zshrc.local"
    local upstream="$BATS_TEST_TMPDIR/upstream/ohmyzsh/ohmyzsh.git"
    printf '# 更新\n' > "$upstream/oh-my-zsh.sh"
    git -C "$upstream" add -- oh-my-zsh.sh
    git -C "$upstream" commit -qm 'テスト用の更新'
    run -0 bash "$SETUP_SCRIPT" update
    cmp "$CONFIG_REPO/_zshrc.env.local.template" "$CONFIG_REPO/_zshrc.env.local"
    cmp "$CONFIG_REPO/_zshrc.local.template" "$CONFIG_REPO/_zshrc.local"
    [ "$(cat "$HOME/.oh-my-zsh/oh-my-zsh.sh")" = '# 更新' ]
    [ "$(cat "$BACKUP/.zshrc")" = '元の設定' ]
    [ "$(wc -l < "$TOOLS_DOWNLOAD_LOG")" -eq 4 ]
}

@test "update は別 remote の追跡設定に従わず公式 origin master を取り込む" {
    run -0 bash "$SETUP_SCRIPT" install
    local repositories=(ohmyzsh/ohmyzsh.git junegunn/fzf.git Aloxaf/fzf-tab.git)
    local directories=("$HOME/.oh-my-zsh" "$HOME/.fzf" "$HOME/.oh-my-zsh/custom/plugins/fzf-tab")
    local i upstream fork directory
    for i in 0 1 2; do
        upstream="$BATS_TEST_TMPDIR/upstream/${repositories[$i]}"
        fork="$BATS_TEST_TMPDIR/fork-$i"
        directory="${directories[$i]}"

        # 同じ起点から fork と公式を別々に進め、fork を追跡させる。
        git clone -q "$upstream" "$fork"
        printf 'fork だけの変更\n' > "$fork/fork-only"
        git -C "$fork" add -- fork-only
        git -C "$fork" -c user.name=テスト -c user.email=test@example.invalid \
            commit -qm 'fork 側の更新'
        git -C "$directory" remote add fork "$fork"
        git -C "$directory" fetch -q fork
        git -C "$directory" branch --set-upstream-to=fork/master master

        printf '公式の変更\n' > "$upstream/official-update"
        git -C "$upstream" add -- official-update
        git -C "$upstream" commit -qm '公式側の更新'
    done

    run -0 bash "$SETUP_SCRIPT" update
    for i in 0 1 2; do
        upstream="$BATS_TEST_TMPDIR/upstream/${repositories[$i]}"
        directory="${directories[$i]}"
        [ ! -e "$directory/fork-only" ]
        [ "$(cat "$directory/official-update")" = '公式の変更' ]
        [ "$(git -C "$directory" rev-parse HEAD)" = "$(git -C "$upstream" rev-parse master)" ]
    done
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

@test "fzf-tab の独自配置先も導入し、未コミット変更と異なる配布元を保護する" {
    export ZSH_CUSTOM="$HOME/custom plugins"
    run -0 bash "$SETUP_SCRIPT" install
    local plugin="$ZSH_CUSTOM/plugins/fzf-tab"
    [ -f "$plugin/fzf-tab.plugin.zsh" ]
    printf '# 保持する変更\n' > "$plugin/fzf-tab.plugin.zsh"
    run -1 bash "$SETUP_SCRIPT" update
    [ "$(cat "$plugin/fzf-tab.plugin.zsh")" = '# 保持する変更' ]
    git -C "$plugin" remote set-url origin https://example.invalid/unrelated.git
    run -1 bash "$SETUP_SCRIPT" install
    [[ $output == *'origin が公式 URL と異なります'* ]]
    [ "$(cat "$plugin/fzf-tab.plugin.zsh")" = '# 保持する変更' ]
}
