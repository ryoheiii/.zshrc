#!/usr/bin/env bats
# 実 HOME とネットワークを使わず、配布と復元の往復・失敗時の保護を確認する。
bats_require_minimum_version 1.5.0
load setup-tools

setup() {
    SETUP_SCRIPT="$BATS_TEST_DIRNAME/../setup.sh"
    export HOME="$BATS_TEST_TMPDIR/online home"
    mkdir -p "$HOME"
    export ZDOTDIR="$HOME"
    unset ZSH ZSH_CUSTOM
    prepare_tools
    ARCHIVE="$BATS_TEST_TMPDIR/package with spaces.tar.gz"
    bash "$SETUP_SCRIPT" install >/dev/null 2>&1
}

pack() {
    bash "$SETUP_SCRIPT" --packing-package "$ARCHIVE"
}

offline_home() {
    export HOME="$BATS_TEST_TMPDIR/offline home" ZDOTDIR="$BATS_TEST_TMPDIR/offline home"
    mkdir -p "$HOME" "$BATS_TEST_TMPDIR/offline-bin"
    # clone/fetch と curl の試行自体を失敗させ、ログで通信経路へ入っていないことも確かめる。
    for tool in curl git; do
        printf '#!/bin/sh\necho called >> "$TOOLS_DOWNLOAD_LOG"\nexit 99\n' > "$BATS_TEST_TMPDIR/offline-bin/$tool"
        chmod +x "$BATS_TEST_TMPDIR/offline-bin/$tool"
    done
    export PATH="$BATS_TEST_TMPDIR/offline-bin:$PATH"
    : > "$TOOLS_DOWNLOAD_LOG"
}

@test "個人設定を含めず梱包し、別 HOME へ通信なしで導入・復元できる" {
    mkdir -p "$HOME/.oh-my-zsh/custom"
    printf '配布しない個別設定\n' > "$HOME/.oh-my-zsh/custom/private.zsh"
    git -C "$HOME/.oh-my-zsh" config custom.private '配布しないローカル設定'
    printf '#!/bin/sh\nexit 98\n' > "$HOME/.oh-my-zsh/.git/hooks/post-checkout"
    chmod +x "$HOME/.oh-my-zsh/.git/hooks/post-checkout"
    run -0 pack
    mkdir "$BATS_TEST_TMPDIR/inspect"
    tar -xzf "$ARCHIVE" -C "$BATS_TEST_TMPDIR/inspect"
    local omz="$BATS_TEST_TMPDIR/inspect/zsh-package/oh-my-zsh"
    [ ! -e "$omz/custom/private.zsh" ]
    [ ! -e "$omz/.git/hooks/post-checkout" ]
    run -1 git -C "$omz" config --get custom.private
    [ "$(git -C "$omz" config --get remote.origin.url)" = https://github.com/ohmyzsh/ohmyzsh.git ]
    offline_home
    printf '元の設定\n' > "$HOME/.zshrc"
    run -0 bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
    [ -x "$HOME/.fzf/bin/fzf" ]
    [ -x "$HOME/.local/bin/starship" ]
    [ -x "$HOME/.local/bin/zoxide" ]
    [ -L "$HOME/.zshrc" ]
    [ ! -s "$TOOLS_DOWNLOAD_LOG" ]
    run -0 bash "$SETUP_SCRIPT" uninstall
    [ "$(cat "$HOME/.zshrc")" = '元の設定' ]
}

@test "既存のツールと custom は成功時も退避先に保持する" {
    run -0 pack
    printf '保持する custom\n' > "$HOME/.oh-my-zsh/custom.zsh"
    printf '#!/bin/sh\necho old\n' > "$HOME/.local/bin/starship"
    run -0 bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
    local saved=("$HOME"/.zsh-package-backup.*)
    [ "$(cat "${saved[0]}/0/custom.zsh")" = '保持する custom' ]
    [ "$("${saved[0]}/2")" = old ]
    [ "$("$HOME/.local/bin/starship")" = 'starship test-version' ]
}

@test "不完全な導入物やローカル変更の梱包失敗で旧アーカイブを失わない" {
    printf '旧アーカイブ\n' > "$ARCHIVE"
    chmod -x "$HOME/.local/bin/starship"
    run -1 pack
    [ "$(cat "$ARCHIVE")" = '旧アーカイブ' ]
    chmod +x "$HOME/.local/bin/starship"
    printf '変更\n' >> "$HOME/.oh-my-zsh/oh-my-zsh.sh"
    run -1 pack
    [ "$(cat "$ARCHIVE")" = '旧アーカイブ' ]
}

@test "破損・パストラバーサル・外部リンクのアーカイブを既存環境へ反映しない" {
    for kind in corrupt traversal symlink; do
        python3 - "$ARCHIVE" "$kind" <<'PYTHON'
import io
import sys
import tarfile
name, kind = sys.argv[1:]
if kind == 'corrupt':
    open(name, 'wb').write(b'invalid')
else:
    with tarfile.open(name, 'w:gz') as archive:
        info = tarfile.TarInfo('zsh-package/../../escaped' if kind == 'traversal' else 'zsh-package/oh-my-zsh')
        if kind == 'symlink':
            info.type = tarfile.SYMTYPE
            info.linkname = '/tmp'
        archive.addfile(info, io.BytesIO())
PYTHON
        run -1 bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
        [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]
        [ -L "$HOME/.zshrc" ]
        [ ! -e "$HOME/escaped" ]
    done
}

@test "OS・CPU の不一致と実行不能なバイナリは配置前に拒否する" {
    run -0 pack
    mkdir "$BATS_TEST_TMPDIR/change"
    tar -xzf "$ARCHIVE" -C "$BATS_TEST_TMPDIR/change"
    local root="$BATS_TEST_TMPDIR/change/zsh-package"
    printf '1\nOtherOS\nothercpu\n' > "$root/platform"
    tar -czf "$ARCHIVE" -C "$BATS_TEST_TMPDIR/change" zsh-package
    run -1 bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
    [[ $output == *'OS・CPU が一致しません'* ]]
    printf '1\n%s\n%s\n' "$(uname -s)" "$(uname -m)" > "$root/platform"
    printf '#!/bin/sh\nexit 42\n' > "$root/bin/starship"
    tar -czf "$ARCHIVE" -C "$BATS_TEST_TMPDIR/change" zsh-package
    run -1 bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
    [ "$("$HOME/.local/bin/starship")" = 'starship test-version' ]
}

@test "配置途中の失敗は旧ツールを復元する" {
    run -0 pack
    mkdir -p "$BATS_TEST_TMPDIR/fail-bin"
    cat > "$BATS_TEST_TMPDIR/fail-bin/mv" <<'SCRIPT'
#!/usr/bin/env bash
for arg in "$@"; do
    if [[ $arg == */zsh-package/bin/starship ]]; then exit 1; fi
done
exec /usr/bin/mv "$@"
SCRIPT
    chmod +x "$BATS_TEST_TMPDIR/fail-bin/mv"
    printf '旧ツールの印\n' > "$HOME/.oh-my-zsh/marker"
    run -1 env PATH="$BATS_TEST_TMPDIR/fail-bin:$PATH" bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
    [ "$(cat "$HOME/.oh-my-zsh/marker")" = '旧ツールの印' ]
    [ -x "$HOME/.fzf/bin/fzf" ]
    [ -x "$HOME/.local/bin/starship" ]
    [ -L "$HOME/.zshrc" ]
}

@test "設定リンク作成の失敗は設定とツールの両方を復元する" {
    run -0 pack
    run -0 bash "$SETUP_SCRIPT" uninstall
    printf '旧設定\n' > "$HOME/.zshrc"
    printf '旧ツールの印\n' > "$HOME/.oh-my-zsh/marker"
    mkdir -p "$BATS_TEST_TMPDIR/fail-bin"
    printf '#!/bin/sh\nexit 1\n' > "$BATS_TEST_TMPDIR/fail-bin/ln"
    chmod +x "$BATS_TEST_TMPDIR/fail-bin/ln"
    run -1 env PATH="$BATS_TEST_TMPDIR/fail-bin:$PATH" bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
    [ "$(cat "$HOME/.zshrc")" = '旧設定' ]
    [ "$(cat "$HOME/.oh-my-zsh/marker")" = '旧ツールの印' ]
    [ ! -e "$HOME/.zshrc.zsh-config-backup" ]
}

@test "バイナリのリンクは実体を梱包し、依存物の更新先は維持する" {
    mv "$HOME/.fzf/bin/fzf" "$HOME/fzf-binary"
    ln -s "$HOME/fzf-binary" "$HOME/.fzf/bin/fzf"
    run -0 pack
    run -0 bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
    [ ! -L "$HOME/.fzf/bin/fzf" ]
    run -0 bash "$SETUP_SCRIPT" update
}

@test "既存退避先や独自配置のため導入できないときはツールを変更しない" {
    run -0 pack
    run -0 bash "$SETUP_SCRIPT" uninstall
    mkdir "$HOME/.zshrc.zsh-config-backup"
    printf '旧設定\n' > "$HOME/.zshrc"
    run -1 bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
    [ "$(cat "$HOME/.zshrc")" = '旧設定' ]
    run -1 env ZSH_CUSTOM="$HOME/custom" bash "$SETUP_SCRIPT" --packing-package "$ARCHIVE"
}

@test "導入済みの fzf-tab も個人の custom 設定と分離して梱包する" {
    local plugin="$HOME/.oh-my-zsh/custom/plugins/fzf-tab"
    # 通常導入で作られたテスト用 checkout があっても、この検査専用に作り直す。
    rm -rf -- "$plugin"
    git init -q -b master "$plugin"
    printf '# テスト用プラグイン\n' > "$plugin/fzf-tab.plugin.zsh"
    git -C "$plugin" add -- fzf-tab.plugin.zsh
    git -C "$plugin" -c user.name=テスト -c user.email=test@example.invalid commit -qm 'テスト用'
    git -C "$plugin" remote add origin https://github.com/Aloxaf/fzf-tab.git
    git -C "$plugin" update-ref refs/remotes/origin/master HEAD
    run -0 pack
    offline_home
    run -0 bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
    [ -f "$HOME/.oh-my-zsh/custom/plugins/fzf-tab/fzf-tab.plugin.zsh" ]
    [ ! -s "$TOOLS_DOWNLOAD_LOG" ]
}

@test "重複パス・リンク配下への書き込み・特殊ファイルを拒否する" {
    for kind in duplicate nested fifo; do
        python3 - "$ARCHIVE" "$kind" <<'PYTHON'
import io
import sys
import tarfile
archive, kind = sys.argv[1:]
with tarfile.open(archive, 'w:gz') as out:
    info = tarfile.TarInfo('zsh-package/oh-my-zsh')
    if kind == 'nested':
        info.type = tarfile.SYMTYPE
        info.linkname = 'fzf'
    elif kind == 'fifo':
        info.type = tarfile.FIFOTYPE
    out.addfile(info, io.BytesIO())
    if kind == 'duplicate':
        out.addfile(info, io.BytesIO())
    elif kind == 'nested':
        out.addfile(tarfile.TarInfo('zsh-package/oh-my-zsh/file'), io.BytesIO())
PYTHON
        run -1 bash "$SETUP_SCRIPT" --extract-package "$ARCHIVE"
        [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]
    done
}

@test "公式追跡 ref と異なるローカルコミットは clean でも梱包しない" {
    printf '旧アーカイブ\n' > "$ARCHIVE"
    local omz="$HOME/.oh-my-zsh"
    printf '個別の設定\n' > "$omz/private.zsh"
    git -C "$omz" add -- private.zsh
    git -C "$omz" -c user.name=テスト -c user.email=test@example.invalid commit -qm 'ローカルの変更'
    run -1 pack
    [[ $output == *'公式の追跡コミットと一致しません'* ]]
    [ "$(cat "$ARCHIVE")" = '旧アーカイブ' ]
}

@test "別ブランチを選んでいてもローカル master の独自コミットを梱包しない" {
    local omz="$HOME/.oh-my-zsh"
    git -C "$omz" -c user.name=テスト -c user.email=test@example.invalid commit --allow-empty -qm 'ローカルの変更'
    git -C "$omz" checkout -q -b official origin/master
    run -1 pack
    [[ $output == *'公式の追跡コミットと一致しません'* ]]
    [ ! -e "$ARCHIVE" ]
}

@test "完了通知の出力失敗でも設定とツールは同じ新しい状態を保つ" {
    run -0 pack
    run -0 bash "$SETUP_SCRIPT" uninstall
    printf '旧設定\n' > "$HOME/.zshrc"
    printf '#!/bin/sh\necho old\n' > "$HOME/.local/bin/starship"
    run -0 bash -c 'bash "$1" --extract-package "$2" > /dev/full' _ "$SETUP_SCRIPT" "$ARCHIVE"
    [ -L "$HOME/.zshrc" ]
    [ "$(cat "$HOME/.zshrc.zsh-config-backup/.zshrc")" = '旧設定' ]
    [ "$("$HOME/.local/bin/starship")" = 'starship test-version' ]
}
