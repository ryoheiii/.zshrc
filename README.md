<!-- -*- gfm -*- -->

# zsh 設定

zsh の設定ファイル (`.zshrc`) を管理するリポジトリ。汎用の 1 ファイル `_zshrc` を置き、`~/.zshrc` からシンボリックリンクを張って使う。OS・WSL・ツールの有無は起動時に判定し、該当しない環境ではその設定を何もしない ([環境ごとに有効になる設定](#環境ごとに有効になる設定))。インストールスクリプトや Makefile は無い。

- 動作確認環境: WSL2 (Ubuntu) 上の zsh 5.9 (`x86_64-ubuntu-linux-gnu`)。`~/.zshrc -> ~/.config/zsh/_zshrc`
- clone 先: `~/.config/zsh` (リポジトリ名は `.zshrc`)
- 前提: 日本語ロケール (`ja_JP.UTF-8`) と zsh の emacs キーマップ。rc に `bindkey -e` は無く、キーマップは zsh 起動時の `EDITOR` / `VISUAL` で決まる ([注意点](#動作に影響するもの))
- Mac 向けの分岐 (`case ${OSTYPE}` の `darwin*`) も一部ある

> 行番号 (例: `_zshrc:92`) は 2026-10 時点の `_zshrc` での位置。編集するとずれるので目安として使う。

## ファイル構成

| ファイル | 役割 |
|---|---|
| `_zshrc` | 設定本体 (525 行)。`~/.zshrc` からリンクして使う。環境やツールに依存する設定はガードで囲み、該当しない環境では何もしない |
| `README.md` | このファイル |
| `AGENTS.md` / `CLAUDE.md` / `.claude/` / `.codex/` | AI エージェント向けの変更規約と設定 ([エージェント向け](#エージェント向け)) |
| `.gitignore` | `*.zwc`、`.zcompdump*`、`/README.html` (mdh で README を変換した HTML)、Claude Code のローカル設定 (`CLAUDE.local.md`、`.claude/settings.local.json`、`.claude/hookify.*.local.md`、`.claude/worktrees/`) を除外 |

### 環境ごとに有効になる設定

旧 `_zshrc-orig` (配布用) と `_zshrc-my-custom` (自分用) を 2026-10 に 1 ファイルへ統合した。環境・ツールに依存する設定は起動時に判定し、該当しなければ定義も export もしない (エラーも出ない)。

- コマンドの有無は関数 `__zshrc_has` (_zshrc:71) で調べる。`PATH` 上の実行ファイルだけを見て alias・関数は数えず、WSL の Windows 側のディレクトリ (`/mnt/c` など `/mnt/<1 文字>/` 配下) は探さない (探すと無いコマンド 1 つにつき 0.1 秒前後かかるため)。判定は起動時の 1 回だけなので、ツールを入れたり消したりしたら新しいシェルか `zns` で反映する。
- ファイル・ディレクトリは `[ -f ]` / `[ -d ]` / `[ -s ]`、OS は `case ${OSTYPE}`、WSL は `WSL_DISTRO_NAME` か `/proc/sys/kernel/osrelease` で判定する ([WSL](#wsl))。

| 条件 | 有効になる設定 |
|---|---|
| 常に | 履歴・ディレクトリスタック・補完の setopt と `INTERACTIVE_COMMENTS`、`LANG`、`~/.local/bin` と `~/.local/share/fnm` の `PATH`、`TERM`、プロンプトと端末タイトルの `precmd`、`WORDCHARS`、関数 `up` `cdup` `cdback`、`zns`、git の alias、`la` `ll` `lla`、`mv -i` `cp -i`、`rm -v` `ln -i -v`、`rmtmp`、`poweroff` `reboot`、グローバル alias (`G` `L` `H` `T` `S` `W` `X` `sl` `LS`)、打ち間違い対策 (`s` `l` `ks` `lsa` `cd..`)、キーバインド、補完ルール、`typeset -U path PATH` |
| Linux (`linux*`) | `ls -FX --color=auto`。さらに `dircolors` があれば `LS_COLORS` と補完候補の色付け |
| macOS (`darwin*`) | `fpath` に `/usr/local/share/zsh-completions`、`PATH` に `/usr/local/bin`、`HOMEBREW_CASK_OPTS`。`/Applications/Emacs.app` (か `~/Applications/Emacs.app`) があれば `e` を `open -a emacs` に |
| WSL | `umask 022`、`DISPLAY=:0`、`LC_ALL=ja_JP.UTF-8`。`~/.Xauthority` があれば `XAUTHORITY` も |
| fnm | `eval "$(fnm env --shell zsh)"` |
| emacsclient | `EDITOR="emacsclient -nw -a ''"` |
| emacs | `e` `ecli` `ekill` `erestart` `em` `emasc`、関数 `estart`、拡張子 alias (`.c` `.C` `.cpp` `.h` `.java` `.txt` `.xml`) |
| nkf / g++ / gtags / apt | `nkfutf8` `nkfsjis` / `g` `a` `g++11` `gna` (`gojt` は oj もある場合) / `gtags-table` `gtags-clear` `rmgtags` / `apt*` |
| nautilus / zipinfo / xsel / firefox (Linux 版) | 関数 `naop` / `.zip` の拡張子 alias / `toclip` 系のグローバル alias / `.html` `.pdf` `.xhtml` の拡張子 alias |
| trash-put | `rm` を `trash-put` に (ただし直後の `rm -v` で上書きされるので効かない。[注意点](#動作に影響するもの)) |
| gnome-open があり、`go` コマンドが無い | `go` → `gnome-open` |
| `~/Dropbox/data/template/make/C_and_C++/Makefile` | `cpmake` |
| `~/.nvm/nvm.sh` | nvm と nvm の bash_completion の読み込み |
| `~/local/lib` | `LD_LIBRARY_PATH` の先頭に追加 |
| `~/.compfunc` | `fpath` の先頭に追加 |
| `/etc/zsh_command_not_found` | command-not-found の読み込み |
| `~/.ssh/known_hosts` / `/etc/hosts` | ホスト名補完の候補に読み込む |

perl (`up`)、git、sudo (`poweroff` `reboot`)、coreutils (`basename`、`whoami`) はガードせず常に使う前提 (無ければ使ったときに失敗する。`whoami` は起動時に実行するので、無いと起動のたびにエラーが出る)。

### ファイル内の節の並び

基本設定 → 環境変数 → **非端末ガード** → プロンプト → シェル変数 → 関数 → alias → キーバインド → 補完ルール → その他。

非端末ガード `[ $#PROMPT -eq 0 -o $#TERM -eq 0 ] && return` (_zshrc:105) は、`PROMPT` か `TERM` が空ならその行で読み込みを打ち切る。対話シェルでは `PROMPT` に初期値がある (`zsh -fic 'echo $#PROMPT'` は 5、非対話の `zsh -fc` では 0) ので、実際に効くのは非対話の zsh から `~/.zshrc` を `source` したときなど。これに当たる主な例は、Claude Code や Codex がシェルスナップショットを作るために非対話シェルから `~/.zshrc` を source する場合 ([AGENTS.md](AGENTS.md))。このときガードより後の alias・関数・setopt・nvm・WSL 節は読まれない。

- ガードより前 (非対話でも適用される): 履歴とディレクトリスタックの setopt、`INTERACTIVE_COMMENTS`、command-not-found の読み込み、関数 `__zshrc_has`、`LANG`、`LD_LIBRARY_PATH` (`~/local/lib` がある場合)、`PATH` と fnm (fnm がある場合)、`TERM`、`EDITOR` (emacsclient がある場合)
- ガードより後 (非対話では適用されない): プロンプト以降の全部。WSL 節 (`umask`、`DISPLAY`、`LC_ALL`、`XAUTHORITY`)、nvm、Codex installer の `PATH`、`typeset -U path PATH` もこちらに入る

環境変数と PATH はガードより前、対話専用の設定は後に置く。

## 前提ツール

### 必須

| ツール | 理由 |
|---|---|
| zsh | 本体。ログインシェルにするなら `chsh -s "$(command -v zsh)"` |
| GNU coreutils (`ls`、`basename`、`whoami`。`dircolors` は任意) | Linux では `ls -FX --color=auto` を alias にし、`dircolors` があれば起動時に実行して `LS_COLORS` を設定する (無ければ色付けを省く)。`basename` は端末タイトル用の `precmd` でプロンプトを出すたびに、`whoami` はプロセス補完全般 (`ps -u $(whoami)`) の設定で起動時に使う |
| `ja_JP.UTF-8` ロケール | `LANG` (WSL では `LC_ALL` も) を `ja_JP.UTF-8` にする。無くても zsh 自体はエラーを出さないが、perl (`up` 関数で使う) などが `perl: warning: Setting locale failed.` を出す。`locale -a` に `ja_JP.utf8` が無ければ生成しておく (Ubuntu なら `sudo locale-gen ja_JP.UTF-8`) |

### 任意 (無くても起動はする。多くの alias・関数はツールがある場合だけ定義する)

| ツール | 使う機能 |
|---|---|
| perl | `up` 関数 (ガードせず常に定義する) |
| git | `gts` などの git 用 alias (ガードせず常に定義する) |
| Emacs (`emacs`、`emacsclient`) | emacsclient があれば `EDITOR`。emacs があれば `e` `ecli` `ekill` `erestart` `em` `emasc` `estart` と拡張子 alias (`.c` `.cpp` `.txt` など)。この機では `~/.local/bin` に置いている |
| xsel と X サーバー | クリップボード用のグローバル alias (`toclip` など) |
| firefox (Linux 版) | 拡張子 alias (`.html` `.pdf` `.xhtml`) |
| zipinfo | 拡張子 alias (`.zip`) |
| nautilus | `naop` 関数 |
| gnome-open | `go` alias (Go 言語の `go` コマンドが無い場合だけ) |
| sudo / apt | `poweroff` `reboot` (sudo。ガードせず常に定義する)、`apt*` (apt がある場合) |
| nkf | `nkfutf8` `nkfsjis` |
| g++、online-judge-tools (`oj`) | `g` `a` `g++11` `gna` (g++)。`gojt` は oj もある場合だけ |
| GNU GLOBAL (`gtags`) と Exuberant Ctags (`/usr/bin/ctags-exuberant`。gtags.conf の `exuberant-ctags` ラベルがこのパスを直接呼ぶ) | `gtags-table` `gtags-clear` `rmgtags`。`gtags-table` はこの機では使えない (下記) |
| `~/Dropbox/data/template/make/C_and_C++/Makefile` | `cpmake`。ファイルがある場合だけ定義し、この機ではパスの大文字小文字が合わず定義されない (下記) |
| fnm | 起動時の `PATH` (`~/.local/share/fnm`、`~/.local/bin` など) にあれば `eval "$(fnm env --shell zsh)"` を実行する ([Node.js](#nodejs)) |
| nvm | `~/.nvm/nvm.sh` があれば末尾で読み込む |
| trash-put | あれば `rm` を `trash-put` にするが、直後の `rm -v` で上書きされる ([注意点](#動作に影響するもの)) |
| `~/local/lib` | あれば `LD_LIBRARY_PATH` の先頭に足す (`~/.local` ではなく `~/local`) |
| command-not-found (Ubuntu) | `/etc/zsh_command_not_found` があれば読み込み、未インストールのコマンドにパッケージ候補を出す |
| `~/.compfunc` | 自作の補完関数置き場。あれば `fpath` の先頭に追加する |

2026-10 時点の WSL2 機には xsel・trash-put・nautilus・oj・gnome-open・Linux 版 firefox が無い (`command -v` で確認)。そのため toclip 系、`naop`、`gojt`、`go`、`.html` `.pdf` `.xhtml` の拡張子 alias (Linux 版の `firefox` を呼ぶ) は定義されない。trash-put は無くても影響しない ([注意点](#動作に影響するもの)の `rm` の項)。

- `~/Dropbox` も無い (あるのは小文字の `~/dropbox -> /mnt/d/Dropbox`) ので、`cpmake` も定義されない。
- `/usr/bin/ctags-exuberant` も無い (入っているのは universal-ctags だけ) ので、`gtags-table` は `gtags: cannot execute '/usr/bin/ctags-exuberant'` で失敗し、中途半端な `GPATH` `GRTAGS` `GTAGS` が残る。この機では `gtags --gtagslabel=universal-ctags` なら動く。

## 導入手順

> リポジトリは非公開なので、clone できるのはアクセス権のあるアカウント (SSH 鍵を GitHub に登録済み) だけ。他人に配るときは `_zshrc` を単体で渡し、相手側で任意の場所に置いて `ln -s <置いた場所>/_zshrc ~/.zshrc` とする (または `~/.zshrc` としてそのままコピーする)。

手順 1-5 のコマンドには `#` のコメントを付けていない。zsh の既定 (この rc を読む前のシェル) では対話入力の `#` がコメントにならず、引数として渡ってしまうため。

1. zsh を入れてログインシェルにする (Ubuntu の例。macOS は標準で zsh)。

   ```sh
   sudo apt install zsh
   chsh -s "$(command -v zsh)"
   ```

2. clone する。

   ```sh
   git clone git@github.com:ryoheiii/.zshrc.git ~/.config/zsh
   ```

3. 既存の設定を退避し、前の設定のコンパイル結果を消す。`-L` も見るのは、リンク切れのシンボリックリンク (`-e` では偽になる) も退避するため。

   ```sh
   { [ -e ~/.zshrc ] || [ -L ~/.zshrc ]; } && mv ~/.zshrc ~/.zshrc.bak
   rm -f ~/.zshrc.zwc
   ```

4. `~/.zshrc` からリンクを張る。

   ```sh
   ln -s ~/.config/zsh/_zshrc ~/.zshrc
   ```

   fnm を使うなら先に入れておく (任意。_zshrc:90-94 が PATH と `fnm env` を設定するので、インストーラには必ず `--skip-shell` を付ける):

   ```sh
   curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
   ```

5. コンパイルして読み込む。`zcompile` は zsh の組み込みコマンドなので、bash からでも動くように `zsh -c` で実行し、zsh を起動し直す。

   ```sh
   zsh -c 'zcompile ~/.zshrc' && exec zsh
   ```

- `ZDOTDIR` は使わず (未設定か `$HOME` のまま)、`$HOME/.zshrc` を読ませる前提。`zns` も `~/.zshrc` を直接指す。
- このリポジトリが用意するのは `~/.zshrc` だけで、`~/.zshenv`・`~/.zprofile`・`~/.zlogin` は使わない。ただし Ubuntu では `/etc/zsh/zshrc` が `~/.zshrc` より先に読まれ、キーマップや `compinit` に影響する ([注意点](#動作に影響するもの))。`/etc/zsh/zshenv` も先に読まれるが、`PATH` が空 (か `/bin:/usr/bin`) のときに初期値を入れるだけ。
- 環境変数節は `fnm env` (_zshrc:92-94) の直前に `~/.local/bin` と `~/.local/share/fnm` だけを `PATH` に足す (_zshrc:89-90)。fnm は `~/.local/share/fnm/fnm` (Linux で公式インストーラを使ったときの既定) か `~/.local/bin` に置くか、zsh 起動時に `PATH` が通っている場所に入れる。それ以外 (cargo の `~/.cargo/bin`、Apple Silicon の Homebrew の `/opt/homebrew/bin` など) に入れたときは `__zshrc_has fnm` が偽になって fnm が設定されないので、_zshrc:90 のパスをその場所に書き換える。公式インストーラは `$SHELL` が zsh だと `${ZDOTDIR:-$HOME}/.zshrc` に設定を追記するので、いつ実行する場合も `--skip-shell` を付ける (付けないと、リンク後ならリポジトリの `_zshrc` に追記され、手順 3 の直後なら通常ファイルの `~/.zshrc` ができて手順 4 の `ln -s` が `File exists` で失敗する)。
- `~/.zshrc` を差し替えずに試すなら、[AGENTS.md](AGENTS.md) の起動検査と同じく一時ディレクトリを `ZDOTDIR` にする。中で `zns` を打つと本物の `~/.zshrc` を読むので注意。また履歴は本物の `~/.zsh_history` に書き込まれ、ほかのシェルとも共有される (`HISTFILE` は `$HOME` 固定で、`share_history` が有効)。避けたいときは中で `HISTFILE=$ZDOTDIR/.zsh_history` を実行するか、`fc -p` で一時的な履歴に切り替える。

  ```sh
  d=$(mktemp -d) && ln -s ~/.config/zsh/_zshrc "$d/.zshrc" && ZDOTDIR="$d" zsh -i; rm -rf "$d"
  ```

### 設定を変更したとき

リンク先 (リポジトリ内のファイル) を編集し、構文を確かめてから `zns` で反映する。

```sh
zsh -n ~/.config/zsh/_zshrc   # 構文チェック
zns                           # = zcompile ~/.zshrc && source ~/.zshrc
```

- `zcompile ~/.zshrc` の出力 `~/.zshrc.zwc` はリンクと同じ `$HOME` にでき、リポジトリ内にはできない。作られたファイルは読み取り専用 (`-r--r--r--`)。
- zsh は `.zwc` が元ファイルと同じか新しいときだけ `.zwc` を使い、古ければ元ファイルを読む。`zns` を忘れても次に起動したシェルには編集内容が反映される (その間 `.zwc` は使われない)。
- 今のシェルで `source` し直しても、一度定義した alias・関数・setopt は残る。定義を消したときは新しいシェルで確かめる。
- ツールの有無は起動時に判定する ([環境ごとに有効になる設定](#環境ごとに有効になる設定))。ツールを入れたり消したりしたときは、新しいシェルで確かめる (入れた場合は `zns` でもよい)。
- 設定を置く位置は[ファイル内の節の並び](#ファイル内の節の並び)に従う (環境変数と PATH は非端末ガードより前)。

## まず覚えるキー操作

この設定で追加したもの。emacs キーマップを前提に書いている。

| キー | 動作 |
|---|---|
| Alt+↑ | 親ディレクトリへ移動 (`cdup`) |
| Alt+← | 直前にいたディレクトリへ戻る (`cdback` = `popd`)。押すたびに残りのディレクトリスタックを表示し、スタックが空なら `directory stack empty` になる |
| Ctrl+← / Ctrl+→ | 単語単位でカーソル移動。`/` も区切りになるので、パスは 1 段ずつ止まる |
| Home / End | 行頭 / 行末へ移動 |
| Delete | カーソル位置の 1 文字を削除 |
| `` Alt+` `` | 入力中の行全体を `` `...` `` で囲み、先頭に空白を入れてカーソルを行頭に戻す |
| Alt+' | 入力中の行全体を `'...'` で囲み、同様に行頭に戻る (zsh 既定の quote-line を上書き) |

`` Alt+` `` は「内側のコマンドを先に打つ」使い方をする。`pwd` と打って `` Alt+` ``、続けて `echo` と打って Enter すると `` echo `pwd` `` が実行される。どちらもカーソルが行末にある前提の動きになる。

zsh の emacs キーマップの既定動作 (ファイル冒頭のコメントに載っているもの。この rc では bindkey していない):

| キー | 動作 |
|---|---|
| Ctrl+R | 履歴を検索 |
| Ctrl+A / Ctrl+E | 行頭 / 行末へ移動 (冒頭コメントには誤記がある。[コメントの誤り](#コメントの誤り)参照) |
| Ctrl+K | カーソルから行末まで削除 |
| Ctrl+W | カーソルより前の 1 単語を削除 (`/` で区切る) |
| Esc h | カーソル位置のコマンドのヘルプ (`run-help`、man など) を表示 |
| Esc q | 入力中の行を退避し、次のプロンプトで戻す |
| Esc ? | コマンドがどう解決されるか (パスや alias 定義) を表示 |
| Ctrl+L | 画面をクリア |

ほかに知っておくと便利な動作:

- Tab を押すと最初の候補がすぐ入り、候補は矢印キーで選べる (`menu_complete`、`menu select`)。
- `cd -<Tab>` で移動履歴から選んで移動できる (`auto_pushd`)。`cd -1` で直前にいたディレクトリへ戻る (`pushd_minus` で `-` が新しい方から数える)。
- ディレクトリ名だけ打てば `cd` する (`auto_cd`)。
- `WORDCHARS` から `/` を外しているので、Ctrl+W、Esc b / Esc f、Ctrl+← / Ctrl+→ はパスの `/` ごとに止まる。
- 打ち間違いには `xxx is correct? [n,y,a,e]:` と修正案が出る (`correct_all`)。n: そのまま実行、y: 修正して実行、a: 中止、e: 編集に戻る。

## 主要な設定内容

### 履歴

- 保存先 `~/.zsh_history`、`HISTSIZE` / `SAVEHIST` はともに 10000。
- 重複は古い方を削除し、直前と同じ行・先頭が空白の行・`history` コマンド自体は記録しない。余分な空白は詰める。
- 実行のたびに追記し、複数の zsh の間で共有する (`inc_append_history`、`share_history`)。

### 補完

- `compinit` で初期化 (dump は `~/.zcompdump`)。グループ見出しを太字で表示し、候補が無いと `No matches for: ...` と出す。
- 小文字で打つと大文字の候補にもマッチする (大文字で打った場合は小文字にマッチしない)。
- Linux で `dircolors` がある場合は、`LS_COLORS` で候補を `ls` と同じ色にする。
- `cd` はカレント配下 → ディレクトリスタック → `cdpath` の順に候補を探す。
- プロセスの候補は自分のプロセスだけ (`ps -u $(whoami)`)。`kill` の候補は色付きで出す。
- ホスト名は起動時に `~/.ssh/known_hosts` (ハッシュ化された行を除く)、`/etc/hosts`、`$HOST` (自ホスト名)、`localhost` から集める。
- その他の setopt: `magic_equal_subst` (`--prefix=~/x` の `=` 以降も展開)、`complete_aliases`、`noautoremoveslash` (補完した末尾の `/` を残す)、`unsetopt promptcr` (改行で終わらない出力の直後にも、そのままプロンプトを出す)。`INTERACTIVE_COMMENTS` (対話入力でも `#` 以降をコメントとして扱う) も有効。
- ディレクトリスタック: `auto_pushd`、`pushd_minus`、`pushd_ignore_dups`。

### プロンプト

```text
user@hostname:dir$                                          [9:05:42]
```

| 変数 | 設定 (色の指定を除く) | 表示 |
|---|---|---|
| `PROMPT` | `%n@%M:%c$ ` | `ユーザー名@ホスト名 (FQDN):カレントディレクトリ名$ `。ディレクトリ名は太字の青、ホームでは `~`。末尾は root でも `$` |
| `RPROMPT` | `[%*]` | プロンプトを出した時刻 `[時:分:秒]`。時刻は太字の緑、時は 0 埋めしない。表示したあとは更新されない |
| `PROMPT2` | `%_$ ` | 継続行に `dquote` などのパーサの状態を出す |
| `SPROMPT` | `%r is correct? [n,y,a,e]: ` | `correct_all` の修正確認 |

`TERM` が `xterm*` / `kterm*` なら、`precmd` (_zshrc:138) で端末のタイトルを `ディレクトリ名[フルパス]` にする。

### 関数

| 関数 | 動作 |
|---|---|
| `up <名前>` | カレントから上へたどり、指定した名前を持つ最も近いディレクトリ (カレント自身を含む) へ移動する。例: `/a/src/foo/src/bar` で `up src` → `/a/src/foo/src`、`up foo` → `/a/src/foo`、`up bar` → 移動しない。見つからなければ `no such file or directory: <名前>` を出して失敗する |
| `cdup` / `cdback` | Alt+↑ / Alt+← 用の ZLE ウィジェット。コマンドとして打つと `cd ..` / `popd` は実行されたうえで、`widgets can only be called when ZLE is active` が出る |
| `naop [dir...]` (nautilus がある場合だけ) | nautilus でフォルダを開く。引数なしならカレント |
| `estart` (emacs がある場合だけ) | Emacs サーバーに接続できないときだけ、`$HOME` で `emacs --daemon` をバックグラウンド起動する。シェル起動時の自動実行 (_zshrc:490) はコメントアウトしてある |

### alias

常に定義する主なもの:

| alias | 展開 |
|---|---|
| `zns` | `zcompile ~/.zshrc && source ~/.zshrc` |
| `gts` `gtd` `gta` `gtc` `gtm` `gtp` `gtl` `gtco` | `git` の `status` `diff` `add` `commit` `merge` `push` `log` `checkout` |
| `ls` (Linux のみ) | `ls -FX --color=auto` (種別記号、拡張子順、色付き) |
| `la` / `ll` / `lla` | `ls -a` / `ls -lh` / `ls -lha` |
| `mv` / `cp` | `mv -i` / `cp -i` (上書き前に確認) |
| `rm` / `ln` | `rm -v` / `ln -i -v` |
| `rmtmp` | `rm -v *~ #*#` (バックアップと Emacs の自動保存ファイルを削除するつもりの alias。[注意点](#動作に影響するもの)参照) |
| `poweroff` / `reboot` | `sudo` 付きで実行 |
| `s` `l` `ks` `lsa` `cd..` | 打ち間違い対策 (`ls`、`la`、`cd ..`) |

グローバル alias (コマンドライン上の単独の単語ならどこでも展開される):

| alias | 展開 |
|---|---|
| `G` `L` `H` `T` `S` `W` `X` | `\| grep` `\| less` `\| head` `\| tail` `\| sort` `\| wc` `\| xargs`。例: `grep "hoge" ./* W -l` = `grep "hoge" ./* \| wc -l` |
| `toclip` / `toclipall` (xsel がある場合だけ) | 標準出力 / 標準出力と標準エラーを xsel でクリップボードへ |
| `andclip` / `andclipall` (同上) | 上と同じ内容をクリップボードへ送り、画面にも表示する |
| `sl` / `LS` | `ls` |

拡張子 alias (ファイル名だけ打つと対応するコマンドで開く。例: `main.cpp` → `emacs main.cpp`。開くコマンドがある場合だけ定義する):

- `.c` `.C` `.cpp` `.h` `.java` `.txt` `.xml` → `emacs`
- `.html` `.pdf` `.xhtml` → `firefox`
- `.zip` → `zipinfo` (中身の一覧)

ツールがある場合だけ定義するもの:

| alias | 条件 | 展開 |
|---|---|---|
| `e` / `ecli` | emacs | `emacs -nw` (Mac で Emacs.app があれば、emacs コマンドの有無にかかわらず `open -a emacs`) / `emacsclient -nw -a ''` (サーバーが無ければデーモンを起動して開く) |
| `ekill` / `erestart` | emacs | Emacs デーモンを終了 / 終了してから `estart` |
| `em` / `emasc` | emacs | 打ち間違い対策 (`emacs`) |
| `nkfutf8` / `nkfsjis` | nkf | `nkf -w --overwrite ` / `nkf -s --overwrite ` (ファイルを UTF-8 / Shift_JIS で上書き) |
| `g` / `a` / `g++11` | g++ | `g++` / `./a.out` / `g++ -std=c++11` |
| `gna` / `gojt` | g++ (`gojt` は oj も) | `g++ main.cpp && ./a.out` / `g++ main.cpp && oj t` (競プロ用) |
| `cpmake` | `~/Dropbox/data/template/make/C_and_C++/Makefile` がある | そのファイルをカレントにコピー |
| `gtags-table` / `gtags-clear` (`rmgtags`) | gtags | `gtags --gtagslabel=exuberant-ctags` / `rm -v GPATH GRTAGS GTAGS` |
| `aptupd` `aptupg` `aptrem` `aptcle` `aptins` | apt | `sudo apt` の `update` `upgrade` `autoremove` `autoclean` `install` |
| `go` | gnome-open があり、`go` コマンドが無い | `gnome-open` |

## プラットフォーム別

### Linux

- `dircolors` があれば `LS_COLORS` を設定し、補完候補も色付けする。これと `ls` の alias は `linux*` 分岐に入れている。
- Ubuntu では `/etc/zsh_command_not_found` が読まれる。また `/etc/zsh/zshrc` が `~/.zshrc` より先に読まれ、zle の読み込み・Home / End などの割り当て・`compinit` を行う ([注意点](#動作に影響するもの))。

### macOS

- その他節の `darwin*` 分岐 (_zshrc:465-477) では、`/Applications/Emacs.app` (か `~/Applications/Emacs.app`) があれば `e` を `open -a emacs` (GUI の Emacs.app) にし、`fpath` に `/usr/local/share/zsh-completions`、`PATH` の先頭に `/usr/local/bin` を足し、`HOMEBREW_CASK_OPTS="--appdir=/Applications"` を設定する。
- Mac では `ls` の alias と、補完候補全般の色付け (`LS_COLORS`) が定義されない。そのため `ls` `la` `ll` などは素の BSD `ls` になる。kill の候補の色付け (_zshrc:412) は OS 分岐の外にあるので Mac でも効く。
- Homebrew は Intel 版の `/usr/local` だけを想定している (Apple Silicon の `/opt/homebrew` は扱っていない)。
- fnm・nvm・WSL 節はガードで判定するので、無い環境では何もしない。
- コマンドの有無は起動時の `PATH` で判定する。`darwin*` 分岐の `/usr/local/bin` の追加はガードより後 (その他節) にあるので、起動時の `PATH` に `/usr/local/bin` が無いと (launchd 経由の GUI アプリから起動した非ログインシェルなど)、Homebrew にだけあるツールの alias や `EDITOR` は定義されない。macOS の既定の `PATH` (`/etc/paths`) には含まれるので、通常は影響しない。

### WSL

その他節の `### WSL` ブロック (_zshrc:493-511) は、`WSL_DISTRO_NAME` があるか、`/proc/sys/kernel/osrelease` に `microsoft` を含むときだけ次を設定する (後者は ssh や `sudo -i`、`env -i` で環境変数が無い場合のため。fork はしない)。

- `umask 022`
- `DISPLAY=:0` (_zshrc:504)、`~/.Xauthority` があれば `XAUTHORITY`。`:0` は WSLg を前提にした値 (この機には `/mnt/wslg` がある)。コメント (_zshrc:498) に Xming の URL があり、WSL1 用の `localhost:0.0` (_zshrc:500) と、WSL2 で `/etc/resolv.conf` から組み立てる方式 (_zshrc:503) が、どちらもコメントアウトで残っている
- `LC_ALL` を `ja_JP.UTF-8` (`LANG` は環境変数節で常に設定する)

WSL のカーネルで動く Docker コンテナなどでも、`osrelease` が同じなので判定が真になる (影響は `umask`、`DISPLAY`、`LC_ALL`)。Windows 側のアプリ (Office、Acrobat、Firefox) の `PATH` と alias は 2026-10 の統合時に削除した。

### Node.js

- fnm: `PATH` に `~/.local/share/fnm` を足し、fnm があれば `eval "$(fnm env --shell zsh)"` する (_zshrc:90-94)。`--use-on-cd` は付けていないので、`.node-version` による自動切り替えはしない。
- nvm: 末尾で `~/.nvm/nvm.sh` と `bash_completion` があれば読み込む (_zshrc:514-518)。
- 最後の `typeset -U path PATH` (_zshrc:525) で `PATH` の重複を取り除く。重複したパスは最初に出てきた位置に残る。

環境を引き継がずに起動した対話シェルでの `PATH` の並びは、下の 1-5 のとおり。次のコマンドで確かめられる。

```sh
env -i HOME="$HOME" TERM=xterm SHELL="$(command -v zsh)" zsh -i -c 'print -l $path; whence -a node'
```

1. `~/.local/bin` (Codex installer のブロック (_zshrc:522) が最後に先頭へ足し、`typeset -U` で _zshrc:89 の分がまとめられる)
2. nvm の node (`~/.nvm/versions/node/<版>/bin`)
3. fnm の multishell (`fnm env` が作る一時ディレクトリ)
4. `~/.local/share/fnm`
5. 元の `PATH`

この場合は nvm の `node` が先に見つかる。ただし入れ子のシェル (zsh の中で zsh を起動した場合など) では、`nvm.sh` が `PATH` に既にある nvm のパスをその場で置き換えるので、引き継いだ順序が残り、fnm の `node` が先頭になる (`whence -a node` で確認)。

エージェントのシェル (非対話で `~/.zshrc` を source) では nvm.sh は読まれず、fnm の `node` が先頭になる (親から引き継いだ `PATH` に nvm のパスがあれば、それはその後ろに残る)。

## 既知の注意点

> どのツールが入っているかなど、環境の状態は 2026-10 時点の WSL2 機で確かめたもの。

### 動作に影響するもの

- **キーマップは zsh 起動時の `EDITOR` / `VISUAL` で決まる**: rc に `bindkey -e` は無い。Ubuntu の `/etc/zsh/zshrc` は `~/.zshrc` より先に `bindkey -M` (49 行目) と `zle -N` (82-83 行目) で zle を読み込むので、main キーマップはその時点で zsh が親プロセスから受け継いだ `EDITOR` / `VISUAL` で決まる (`vi` を含めば viins、含まなければ emacs)。環境変数節の `EDITOR` (_zshrc:100-102。emacsclient がある場合だけ設定する) はこのシェルのキーマップには効かず、子プロセス (`EDITOR` を見るコマンドや入れ子の zsh) にだけ効く。git は `core.editor` が設定されていればそちらを使う。
  - 確認: `env EDITOR=vi zsh -i -c 'bindkey -lL main'` はこの rc でも `bindkey -A viins main` になる。`/etc/zsh/zshrc` を読まない `zsh -d` では、_zshrc:380 の最初の `bindkey` で zle が読み込まれ、_zshrc:100 の `EDITOR` (emacsclient がある場合) が効いて emacs になる。
  - vi キーマップになると、Ctrl+A / Ctrl+E など emacs の既定キーは使えない (この rc の bindkey は main キーマップ、つまり viins に入る)。
  - 確実に emacs にするなら、キーバインド節の先頭 (ほかの `bindkey` より前) に `bindkey -e` を書く。
- **`TERM=xterm-256color` を無条件に設定する** (_zshrc:97):
  - tmux や screen の中でも `TERM` が上書きされる。
  - Emacs の `M-x shell` のような dumb 端末でも `precmd` が定義され、タイトル用のエスケープシーケンスが出る。
  - 非端末ガードの `$#TERM -eq 0` は成り立たなくなり、実際には `PROMPT` だけで判定している。
- **fnm と nvm を両方読み込んでいる** (_zshrc:90-94, 514-518): どちらの `node` が使われるかはシェルの起動のしかたで変わる ([Node.js](#nodejs))。どちらか一方に寄せたい。
- **`rm` はゴミ箱に移さない** (_zshrc:313-318): `trash-put` があれば `rm` を `trash-put` にする分岐があるが、直後の `alias rm='rm -v'` で必ず上書きされる。`rm` は確認もせずに削除する。
- **`rmtmp` が思うように消えない** (_zshrc:319):
  - `*~` に該当するファイルが無いと、`no matches found` で何も削除しない (zsh の `NOMATCH`)。`#*#` は次項のとおりコメントになるので、`#...#` ファイルの有無は関係しない。
  - `setopt INTERACTIVE_COMMENTS` (_zshrc:54) により、展開された `#*#` 以降がコメント扱いになる。`#...#` は消えず、同じ行で後ろに続けたコマンド (`rmtmp; ls` の `ls` など) も実行されない。
- **グローバル alias の副作用**: `G` `L` `H` `T` `S` `W` `X` `sl` `LS` などは引数の位置でも展開される。`echo X` は `echo | xargs`、`git sl` は `git ls` になる。文字どおり渡したいときはクォートする。
- **`nkfutf8` / `nkfsjis` の後ろの単語も alias 展開される** (_zshrc:240-241): 展開結果が空白で終わる alias なので、次の単語も alias として展開される。例えばファイル名が `l` だと `ls` に化ける。
- **alias に git の補完が効かない** (_zshrc:450): `complete_aliases` により alias は別のコマンドとして補完される。`gtco` などには補完関数が割り当てられていない (`$_comps[gtco]` は空、`git` は `_git`) ので、git のブランチ名などは補完されない。対処は `complete_aliases` を外すか、`compdef _git gtco=git-checkout` のように割り当てる (対処は未検証)。
- **`compinit` が 2 回走る**: Ubuntu の `/etc/zsh/zshrc` (110-112 行目) が `compinit` を実行したあと、rc でも実行する (_zshrc:405-406)。前者を省くなら `~/.zshenv` に `skip_global_compinit=1` を書く。
- **`precmd` を直接定義している** (_zshrc:138): `add-zsh-hook` を使っていないので、ほかに `precmd` を定義するツールを入れると上書きし合う。
- **Home / End は `^[OH` / `^[OF` だけ** (_zshrc:380-381): アプリケーションモードのシーケンスしか bindkey していない。Ubuntu では `/etc/zsh/zshrc` が `zle-line-init` で端末をアプリケーションモードにし、terminfo で同じ割り当てもするので動く。それが無い環境では、通常モードの `^[[H` / `^[[F` は未定義のまま (この機でも `bindkey '^[[H'` は `undefined-key`)。
- **Alt+矢印は端末依存**: 端末が `^[[1;3A` などの xterm 形式のシーケンスを送る前提。Windows Terminal や VS Code のターミナルなど、端末側が Alt+矢印 を自分のショートカットに使っていると届かない。
- **ssh のホストが補完に出ないことがある** (_zshrc:417): `known_hosts` がハッシュ化 (`HashKnownHosts`) されていると、そのホストは候補にならない。この機では `known_hosts` が全行ハッシュ化されているので、候補は `/etc/hosts`・`$HOST`・`localhost` 由来だけになる。候補は起動時に一度だけ作る。
- **Codex installer のブロック** (_zshrc:521-523): Codex のインストーラーが追記した `# >>> Codex installer >>>` のブロック。統合時に、インストーラーが書いたユーザー名入りの絶対パスを `$HOME` に書き換え、マーカー行は残した。nvm の後で `~/.local/bin` を `PATH` の先頭に戻す働きがあり (_zshrc:89 と同じ追加で、_zshrc:525 の `typeset -U` で 1 つにまとまる)、削除すると `~/.local/bin` が nvm・fnm の node より後ろに下がる。インストーラーを再実行したときに追記し直されるかは未確認。
- **Mac の zsh-completions が効かない**: `fpath` への追加 (_zshrc:471) が `compinit` (_zshrc:406) より後にあるので、そのシェルの補完には効かない。

### 重複している・効いていない定義

- `~/.local/bin` の `PATH` 追加が、環境変数節 (_zshrc:89) と Codex installer のブロック (_zshrc:522) の 2 回ある (結果は同じ。[注意点](#動作に影響するもの)の Codex の項)。
- `gtags-clear` と `rmgtags` (_zshrc:267-268) は同じコマンド。
- `hist_ignore_dups` は `hist_ignore_all_dups` に含まれる。`share_history` は `inc_append_history` の動作も含む (man では併用しないよう勧めている)。`hist_expire_dups_first` は、`hist_ignore_all_dups` で重複が残らず `HISTSIZE` と `SAVEHIST` も同じ値なので、ほぼ効かない。
- `menu_complete` が `auto_menu` より優先される。`auto_list`・`auto_menu`・`list_types`・`auto_param_keys` は zsh の既定で on なので、setopt しなくても同じ。
- `up` は変数 `to` を `local` にしていない (_zshrc:175) ので、実行後もグローバル変数として残る。
- プロンプト節の `local GREEN` `BLUE` `DEFAULT` (_zshrc:114-120) は関数の外にあるので local にならず、グローバル変数として残る。補完節の `hosts` `_ssh_hosts` `_etc_hosts` (_zshrc:417-425) も同じくグローバルに残る。

### コメントの誤り

- _zshrc:12 の「C-a 末尾に移動」は C-e の誤り。
- _zshrc:43 の「キューではなくスタックで番号付け」: `pushd_minus` の実際の意味は、`+` と `-` の意味を入れ替えること。
- _zshrc:395 の「#M-@」: 実際のキーは `` Alt+` `` と Alt+'。
- _zshrc:443 の「一覧表示 (auto_list) せず、すぐに最初の候補を補完する」: _zshrc:430 の `menu select` があるので、実際には候補の選択メニューも出る。
- _zshrc:449 の「補完される前にオリジナルのコマンドまで展開してチェックする」: `complete_aliases` の実際の意味はこの逆で、alias を展開せずに補完する。
- _zshrc:451 の「カッコの対応などを自動的に補完」: `auto_param_keys` は、パラメータ名の補完で自動的に入った空白などを、次に `}` などを打ったときに消す機能。
- _zshrc:498 の Xming の URL は、今の `DISPLAY=:0` (WSLg) とは関係が無い (古い設定の名残)。

## エージェント向け

- 変更するときの規約は [AGENTS.md](AGENTS.md)。Claude Code は [CLAUDE.md](CLAUDE.md)、Codex は [.codex/README.md](.codex/README.md) も読む。
