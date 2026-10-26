#!/usr/bin/env bash
# Oh My Zsh と入力支援を導入し、設定の退避・復元・明示的な更新をまとめる。
set -euo pipefail

usage() {
    printf '使い方: bash setup.sh {install|update|uninstall}\n'
    printf '        bash setup.sh {--packing-package|--extract-package} [アーカイブ.tar.gz]\n'
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
    -p|--packing-package|-x|--extract-package) [[ $# -le 2 ]] || { usage >&2; exit 1; } ;;
    *) usage >&2; exit 1 ;;
esac

action=$1
case $action in
    -p) action=--packing-package ;;
    -x) action=--extract-package ;;
esac

# ZDOTDIR に別の設定がある環境では、使われないリンクを作らない。
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || fail 'HOME が有効な絶対パスではありません。'
[[ ${ZDOTDIR:-$HOME} == "$HOME" ]] || fail 'ZDOTDIR を解除するか HOME と同じ値にしてください。'
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
package_archive=${2:-$repo_dir/package.tar.gz}
source_file="$repo_dir/_zshrc"
rc="$HOME/.zshrc"
compiled="$HOME/.zshrc.zwc"
backup="$HOME/.zshrc.zsh-config-backup"

is_installed() {
    [[ -L $rc && $(readlink -- "$rc") == "$source_file" ]]
}

# PC 固有の設定は、未作成の場合だけ説明と設定例の入ったテンプレートから用意する。
prepare_local_configuration() {
    local name target template
    for name in _zshrc.env.local _zshrc.local; do
        target="$repo_dir/$name"
        template="$target.template"
        if exists "$target"; then
            [[ -f $target ]] || fail "$target が通常のファイルを参照していません。"
            continue
        fi
        [[ -f $template && -r $template ]] || fail "$template が読み込めません。"
        # 同時にファイルが作られた場合も既存の内容を上書きしない。
        (umask 077; set -o noclobber; cat -- "$template" > "$target") || fail "$target を作成できません。"
    done
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
    # 外部プラグインもセットアップ時に取得し、update で公式 master へ追従する。
    sync_repo "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab" https://github.com/Aloxaf/fzf-tab.git

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

# 梱包・展開は標準配置を使う。個別の配置先を暗黙に取り違えない。
check_package_environment() {
    for tool in git tar gzip python3 zsh; do
        command -v "$tool" >/dev/null 2>&1 || fail "先に $tool をインストールしてください。"
    done
    [[ ${ZSH:-$HOME/.oh-my-zsh} == "$HOME/.oh-my-zsh" &&
       ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom} == "$HOME/.oh-my-zsh/custom" ]] ||
        fail '梱包・展開では ZSH と ZSH_CUSTOM を標準の配置先にしてください。'
}

# 個人の Git 設定・hooks・未追跡ファイルを持ち出さず、更新可能な checkout を複製する。
package_repo() {
    local source=$1 destination=$2 url=$3 official
    [[ -d $source/.git && ! -L $source ]] || fail "$source が通常の Git checkout ではありません。"
    [[ $(git -C "$source" config --get remote.origin.url) == "$url" ]] || fail "$source の origin が公式 URL と異なります。"
    [[ -z $(git -C "$source" status --porcelain --untracked-files=no) ]] || fail "$source に未コミット変更があります。"
    # URL だけではローカルコミットを判別できないため、取得済みの公式 master と照合する。
    official=$(git -C "$source" rev-parse --verify refs/remotes/origin/master) ||
        fail "$source に公式 master の追跡 ref がありません。"
    [[ $(git -C "$source" rev-parse HEAD) == "$official" &&
       $(git -C "$source" rev-parse --verify refs/heads/master) == "$official" ]] ||
        fail "$source の HEAD または master が公式の追跡コミットと一致しません。"
    git -c core.hooksPath=/dev/null clone --quiet --branch master --single-branch --no-tags --no-local --template= -- "$source" "$destination"
    git -C "$destination" remote set-url origin "$url"
    # clone 実行者の名前・メールアドレスが入る reflog は配布しない。
    rm -rf -- "$destination/.git/logs"
}

# 導入済みの依存物だけを梱包する。設定リポジトリ・履歴・資格情報・キャッシュは含めない。
packing_package() (
    check_package_environment
    local staging temporary='' root
    [[ ! -L $package_archive && ! -d $package_archive ]] || fail 'アーカイブ出力先がリンクまたはディレクトリです。'
    staging=$(mktemp -d)
    trap 'rm -rf -- "$staging"; if [[ -n $temporary ]]; then rm -f -- "$temporary"; fi' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    root="$staging/zsh-package"
    mkdir -p "$root/bin"
    printf '1\n%s\n%s\n' "$(uname -s)" "$(uname -m)" > "$root/platform"
    package_repo "$HOME/.oh-my-zsh" "$root/oh-my-zsh" https://github.com/ohmyzsh/ohmyzsh.git
    package_repo "$HOME/.fzf" "$root/fzf" https://github.com/junegunn/fzf.git
    # 外部プラグインも通常のセットアップと同じ構成で含める。
    mkdir -p "$root/oh-my-zsh/custom/plugins"
    package_repo "$HOME/.oh-my-zsh/custom/plugins/fzf-tab" \
        "$root/oh-my-zsh/custom/plugins/fzf-tab" https://github.com/Aloxaf/fzf-tab.git
    mkdir -p "$root/fzf/bin"
    cp -L -- "$HOME/.fzf/bin/fzf" "$root/fzf/bin/fzf"
    for tool in starship zoxide; do
        cp -L -- "$HOME/.local/bin/$tool" "$root/bin/$tool"
    done
    validate_package "$root"
    # 一時ファイルは出力先と同じファイルシステムに作り、圧縮成功後だけ公開する。
    temporary=$(mktemp "${package_archive}.XXXXXX")
    tar -czf "$temporary" -C "$staging" zsh-package
    mv -fT -- "$temporary" "$package_archive"
    temporary=''
    printf '梱包しました: %s\n設定リポジトリと一緒に配布してください。\n' "$package_archive"
)

# 別 OS・CPU 向けのバイナリや、不完全なパッケージを既存環境へ配置しない。
validate_package() {
    local root=$1 file directory
    [[ $(cat "$root/platform") == "$(printf '1\n%s\n%s' "$(uname -s)" "$(uname -m)")" ]] ||
        fail 'パッケージ形式または OS・CPU が一致しません。'
    for file in oh-my-zsh/oh-my-zsh.sh \
        oh-my-zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh \
        oh-my-zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh \
        oh-my-zsh/custom/plugins/fzf-tab/fzf-tab.plugin.zsh fzf/install; do
        [[ -f $root/$file ]] || fail 'パッケージに必要なファイルがありません。'
    done
    for directory in oh-my-zsh fzf oh-my-zsh/custom/plugins/fzf-tab; do
        [[ -d $root/$directory/.git ]] || fail 'パッケージに Git checkout がありません。'
    done
    for file in fzf/bin/fzf bin/starship bin/zoxide; do
        [[ -x $root/$file ]] || fail 'パッケージに実行可能なバイナリがありません。'
        "$root/$file" --version >/dev/null || fail 'パッケージのバイナリを実行できません。'
    done
}

# 展開先から抜けるパス・リンク・特殊ファイルを、書き込み前に全件検査する。
unpack_package() {
    python3 - "$package_archive" "$1" <<'PYTHON'
import posixpath
import shutil
import sys
import tarfile
from pathlib import Path, PurePosixPath

archive, destination = sys.argv[1:]
try:
    with tarfile.open(archive, 'r:gz') as source:
        members = source.getmembers()
        names = set()
        links = set()
        for member in members:
            path = PurePosixPath(member.name)
            if (path.is_absolute() or '..' in path.parts or not path.parts
                    or path.parts[0] != 'zsh-package' or str(path) in names):
                raise ValueError('不正または重複するパス')
            if len(path.parts) > 1 and path.parts[1] not in {'platform', 'oh-my-zsh', 'fzf', 'bin'}:
                raise ValueError('対象外のパス')
            if not (member.isdir() or member.isfile() or member.issym()):
                raise ValueError('未対応のファイル形式')
            names.add(str(path))
            if member.issym():
                links.add(path)
                target = PurePosixPath(posixpath.normpath(posixpath.join(str(path.parent), member.linkname)))
                if (target.is_absolute() or len(target.parts) < 2 or len(path.parts) < 2
                        or target.parts[:2] != path.parts[:2]):
                    raise ValueError('展開先の外へ向くリンク')
        for member in members:
            if any(parent in links for parent in PurePosixPath(member.name).parents):
                raise ValueError('リンク配下への書き込み')
        # 所有者や特殊な権限は復元せず、実行ビットだけを保持する。
        for member in members:
            target = Path(destination, member.name)
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif member.issym():
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(member.linkname)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with source.extractfile(member) as src, target.open('wb') as dst:
                    shutil.copyfileobj(src, dst)
                target.chmod(0o755 if member.mode & 0o111 else 0o644)
        root = Path(destination, 'zsh-package').resolve()
        for link in links:
            if not Path(destination, link).resolve().is_relative_to(root):
                raise ValueError('展開先の外へ向くリンクの連鎖')
except (OSError, ValueError, RuntimeError, tarfile.TarError):
    sys.exit('エラー: パッケージが破損しているか、安全に展開できない内容です。')
PYTHON
}

# 検証を済ませた依存物を配置し、途中で失敗したら退避した旧版へ戻す。
extract_package() (
    check_package_environment
    [[ -f $package_archive ]] || fail 'パッケージがありません。'
    local staging saved root i committed=no
    local -a targets=("$HOME/.oh-my-zsh" "$HOME/.fzf" "$HOME/.local/bin/starship" "$HOME/.local/bin/zoxide")
    local -a sources=(oh-my-zsh fzf bin/starship bin/zoxide) installed=()
    staging=$(mktemp -d "$HOME/.zsh-package-stage.XXXXXX")
    saved=''
    # EXIT トラップから呼ぶ復元処理。
    # shellcheck disable=SC2317
    cleanup_package() {
        local result=$? i
        trap '' INT TERM
        if [[ $committed == no && -n $saved ]]; then
            for ((i=${#targets[@]}-1; i>=0; i--)); do
                if [[ ${installed[i]:-no} == yes ]]; then rm -rf -- "${targets[i]}" || result=1; fi
                if exists "$saved/$i"; then
                    if ! mv -T -- "$saved/$i" "${targets[i]}"; then
                        printf '復元失敗: 旧ファイルは %s/%s に保持しています。\n' "$saved" "$i" >&2
                        result=1
                    fi
                fi
            done
            rmdir -- "$saved" 2>/dev/null || true
        fi
        rm -rf -- "$staging"
        exit "$result"
    }
    trap cleanup_package EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    unpack_package "$staging"
    root="$staging/zsh-package"
    validate_package "$root"
    # 親が symlink の場合も止め、別の場所への意図しない配置を防ぐ。
    [[ ! -L $HOME/.local && ! -L $HOME/.local/bin ]] || fail 'HOME 配下の .local または .local/bin がリンクです。'
    mkdir -p "$HOME/.local/bin"
    saved=$(mktemp -d "$HOME/.zsh-package-backup.XXXXXX")
    for i in "${!targets[@]}"; do
        printf '%s -> %s\n' "$i" "${targets[i]}" >> "$saved/restore-map.txt"
        if exists "${targets[i]}"; then mv -T -- "${targets[i]}" "$saved/$i"; fi
        installed[i]=yes
        mv -T -- "$root/${sources[i]}" "${targets[i]}"
    done
    activate_configuration
    committed=yes
    # 配置完了後の通知失敗で、ツールだけを旧版へ戻さない。
    report_configuration
    printf '依存物を展開しました。旧ファイルの退避先: %s\n' "$saved" || true
)

# 設定リンクの作成はオンライン導入とオフライン展開で共通にする。
activate_configuration() {
    if is_installed && [[ -d $backup && ! -L $backup ]]; then
        return
    fi
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
}

# 通知は変更完了後に行い、出力先の障害を導入トランザクションの失敗にしない。
report_configuration() {
    printf '導入しました。退避先: %s\n設定ファイルへの追記は不要です。exec zsh で起動し直してください。\n' "$backup" || true
}

# 梱包は現在の設定リンクや退避先を変更しない。
if [[ $action == --packing-package ]]; then
    packing_package
    exit 0
fi

# ディレクトリの削除・上書きを防ぐ。ディレクトリを指すリンク自体は退避できる。
for file in "$rc" "$compiled"; do
    [[ ! -d $file || -L $file ]] || fail "$file はディレクトリです。"
done

if [[ $action == update ]]; then
    prepare_local_configuration
    install_tools
    printf 'ツールを更新しました。設定ファイルへの追記は不要です。exec zsh で起動し直してください。\n'
    exit 0
fi

if [[ $action == install || $action == --extract-package ]]; then
    command -v zsh >/dev/null 2>&1 || fail '先に zsh をインストールしてください。'
    zsh -n "$source_file"
    if ! is_installed || [[ ! -d $backup || -L $backup ]]; then
        exists "$backup" && fail "$backup が既にあります。退避内容を確認してください。"
    fi
    # テンプレートの作成失敗は、ツールの配置や既存設定の退避を始める前に検出する。
    prepare_local_configuration
    # オフライン展開は依存物の入れ替えと設定リンク作成をまとめて復元対象にする。
    if [[ $action == --extract-package ]]; then
        extract_package
    else
        install_tools
        activate_configuration
        report_configuration
    fi
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
