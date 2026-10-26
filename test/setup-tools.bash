# 実リポジトリのローカル設定を変更せず、一時配置でセットアップを検査する。
prepare_configuration_repo() {
    CONFIG_REPO="$BATS_TEST_TMPDIR/config repo"
    mkdir -p "$CONFIG_REPO"
    cp -- "$BATS_TEST_DIRNAME/../setup.sh" "$BATS_TEST_DIRNAME/../_zshrc" \
        "$BATS_TEST_DIRNAME/../starship.toml" \
        "$BATS_TEST_DIRNAME/../_zshrc.env.local.template" \
        "$BATS_TEST_DIRNAME/../_zshrc.local.template" "$CONFIG_REPO/"
    SETUP_SCRIPT="$CONFIG_REPO/setup.sh"
    SOURCE_FILE="$CONFIG_REPO/_zshrc"
}

# ネットワークを使わず公式導入先への取得・更新を再現する。
prepare_tools() {
    export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
    export GIT_CONFIG_NOSYSTEM=1
    local upstream="$BATS_TEST_TMPDIR/upstream"
    local repo
    git config --file "$GIT_CONFIG_GLOBAL" url."$upstream/".insteadOf https://github.com/
    for repo in ohmyzsh/ohmyzsh.git junegunn/fzf.git Aloxaf/fzf-tab.git; do
        git init -q -b master "$upstream/$repo"
        git -C "$upstream/$repo" config user.name 'テスト'
        git -C "$upstream/$repo" config user.email 'test@example.invalid'
    done
    local omz="$upstream/ohmyzsh/ohmyzsh.git"
    printf '/custom/\n' > "$omz/.gitignore"
    mkdir -p "$omz/plugins/zsh-autosuggestions" "$omz/plugins/zsh-syntax-highlighting"
    touch "$omz/oh-my-zsh.sh" "$omz/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" \
        "$omz/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"
    local fzf="$upstream/junegunn/fzf.git"
    printf '/bin/\n' > "$fzf/.gitignore"
    cat > "$fzf/install" <<'SCRIPT'
#!/usr/bin/env bash
set -eu
[[ $1 == --bin ]]
mkdir -p "$(dirname "$0")/bin"
printf '#!/bin/sh\nexit 0\n' > "$(dirname "$0")/bin/fzf"
chmod +x "$(dirname "$0")/bin/fzf"
SCRIPT
    touch "$upstream/Aloxaf/fzf-tab.git/fzf-tab.plugin.zsh"
    for repo in ohmyzsh/ohmyzsh.git junegunn/fzf.git Aloxaf/fzf-tab.git; do
        git -C "$upstream/$repo" add -- .
        git -C "$upstream/$repo" commit -qm 'テスト用の配布元'
    done
    export TOOLS_DOWNLOAD_LOG="$BATS_TEST_TMPDIR/downloads"
    mkdir -p "$BATS_TEST_TMPDIR/mock-bin"
    cat > "$BATS_TEST_TMPDIR/mock-bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -eu
[[ $1 == -fsSL && $3 == -o ]]
printf '%s\n' "$2" >> "$TOOLS_DOWNLOAD_LOG"
[[ ${FAIL_DOWNLOAD:-0} == 0 ]] || exit 22
case $2 in
    https://starship.rs/install.sh) tool=starship ;;
    https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh) tool=zoxide ;;
    *) exit 1 ;;
esac
printf 'tool=%s\n' "$tool" > "$4"
cat >> "$4" <<'INSTALLER'
set -eu
while [ "$#" -gt 0 ]; do
    case $1 in
        --yes) shift ;;
        --bin-dir) target=$2; shift 2 ;;
        --man-dir|--sudo) shift 2 ;;
        *) exit 1 ;;
    esac
done
printf '#!/bin/sh\necho "%s test-version"\n' "$tool" > "$target/$tool"
chmod +x "$target/$tool"
INSTALLER
SCRIPT
    chmod +x "$BATS_TEST_TMPDIR/mock-bin/curl"
    export PATH="$BATS_TEST_TMPDIR/mock-bin:$PATH"
}
