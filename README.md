<!-- -*- gfm -*- -->

# zsh 設定

zsh の設定ファイル (`.zshrc`) を管理するリポジトリ。配布用と自分用の 2 種類を置き、`~/.zshrc` からシンボリックリンクを張って使う。インストールスクリプトや Makefile は無い。

- 動作確認環境: WSL2 (Ubuntu) 上の zsh 5.9 (`x86_64-ubuntu-linux-gnu`)。`~/.zshrc -> ~/.config/zsh/_zshrc-my-custom`
- clone 先: `~/.config/zsh` (リポジトリ名は `.zshrc`)
- 前提: 日本語ロケール (`ja_JP.UTF-8`) と zsh の emacs キーマップ。rc に `bindkey -e` は無く、キーマップは zsh 起動時の `EDITOR` / `VISUAL` で決まる ([注意点](#動作に影響するもの))
- Mac 向けの分岐 (`case ${OSTYPE}` の `darwin*`) も一部ある

> - 本文の custom は `_zshrc-my-custom`、orig は `_zshrc-orig` の略。
> - 行番号 (例: `custom:73`) は 2026-10 時点の作業ツリーでの位置。編集するとずれるので目安として使う。

## ファイル構成

| ファイル | 役割 |
|---|---|
| `_zshrc-orig` | 配布用 (362 行)。他人に渡すための汎用版 |
| `_zshrc-my-custom` | 自分用 (471 行)。`~/.zshrc` からリンクして実際に使っている |
| `README.md` | このファイル |
| `AGENTS.md` / `CLAUDE.md` / `.claude/` / `.codex/` | AI エージェント向けの変更規約と設定 ([エージェント向け](#エージェント向け)) |
| `.gitignore` | `*.zwc`、`.zcompdump*`、`/README.html` (mdh で README を変換した HTML)、Claude Code のローカル設定 (`CLAUDE.local.md`、`.claude/settings.local.json`、`.claude/hookify.*.local.md`、`.claude/worktrees/`) を除外 |

2 つの zshrc は自動では同期しない。片方を直しても、もう片方には反映されない ([AGENTS.md](AGENTS.md) でも自動で反映しない決まりにしている)。

### 配布用と自分用の違い

基本設定 (履歴・ディレクトリスタック)、シェル変数、関数、キーバインド、補完ルールの各節は 2 つで同じ (custom だけにある関数 `estart` は「その他」節に置いている)。プロンプト節は、補完候補の色付け (`dircolors` と kill 候補の `list-colors`) を custom では `linux*` 分岐の中に入れている点が違う。kill 用の値も違い、custom では 2 行に割れて壊れている ([重複している・効いていない定義](#重複している効いていない定義))。そのほかの違いは次のとおり。

| 項目 | `_zshrc-orig` | `_zshrc-my-custom` |
|---|---|---|
| PATH | 変更しない | `~/.local/bin`、fnm、nvm、Windows アプリのパスを追加 (Mac では `/usr/local/bin` も) |
| 環境変数 | `LANG`、`LD_LIBRARY_PATH`、`GREP_OPTIONS` | `LANG`、`TERM`、`EDITOR` (`emacsclient -nw -a ''`。`EDITOR` を見るコマンドが開くエディタは `ecli` と同じ動作になる。git は `core.editor` が優先されるので、この機では `~/.gitconfig` の `emacs -nw` が開く)、WSL 用 (`DISPLAY`、`LC_ALL`、`XAUTHORITY`)、`NVM_DIR`。Mac では `HOMEBREW_CASK_OPTS` も |
| OS 分岐 | 無し (`dircolors` と GNU `ls` を無条件に使う) | `case ${OSTYPE}` で Linux / Mac を分ける |
| alias | 汎用的なもの + `go="gnome-open"` | Emacs、nkf、g++、競プロ、gtags、apt、`mv -i` / `cp -i`、Windows アプリ用などを追加 |
| 関数 | `up` `cdup` `cdback` `naop` | 左に加えて `estart` (「その他」節) |
| 「その他」節 | 見出しだけ | Mac 分岐、`estart`、WSL 設定、nvm、Codex installer の PATH、`setopt INTERACTIVE_COMMENTS`、`typeset -U path PATH` |

自分用には個人環境の前提 (`/home/ryohei` の直書き、`~/Dropbox` 上のテンプレート、WSL 用の設定) が入っている。自分以外の環境で試すなら `_zshrc-orig` を使う。

### ファイル内の節の並び

基本設定 → 環境変数 → **非端末ガード** → プロンプト → シェル変数 → 関数 → alias → キーバインド → 補完ルール → その他 (2 ファイル共通)。

非端末ガード `[ $#PROMPT -eq 0 -o $#TERM -eq 0 ] && return` (custom:82 / orig:74) は、`PROMPT` か `TERM` が空ならその行で読み込みを打ち切る。対話シェルでは `PROMPT` に初期値がある (`zsh -fic 'echo $#PROMPT'` は 5、非対話の `zsh -fc` では 0) ので、実際に効くのは非対話の zsh から `~/.zshrc` を `source` したときなど。これに当たる主な例は、Claude Code や Codex がシェルスナップショットを作るために非対話シェルから `~/.zshrc` を source する場合 ([AGENTS.md](AGENTS.md))。このときガードより後の alias・関数・setopt・nvm・WSL 節は読まれない。

- ガードより前 (非対話でも適用される): 履歴とディレクトリスタックの setopt、command-not-found の読み込み、`LANG`、`PATH` と fnm、`TERM`、`EDITOR` (orig は `LANG` と `LD_LIBRARY_PATH`)
- ガードより後 (非対話では適用されない): プロンプト以降の全部。custom の WSL 節 (`DISPLAY`、`LC_ALL`、Windows の PATH)、nvm、`typeset -U path PATH` もこちらに入る

環境変数と PATH はガードより前、対話専用の設定は後に置く。

## 前提ツール

### 必須

| ツール | 理由 |
|---|---|
| zsh | 本体。ログインシェルにするなら `chsh -s "$(command -v zsh)"` |
| GNU coreutils (`dircolors`、`ls`、`basename`、`whoami`) | 起動時に `dircolors` を実行し、`ls -FX --color=auto` を alias にする (orig は無条件、custom は Linux のみ)。`basename` は端末タイトル用の `precmd` でプロンプトを出すたびに、`whoami` はプロセス補完全般 (`ps -u $(whoami)`) の設定で起動時に使う |
| `hostname` | ホスト名補完の候補を起動時に作る |
| fnm (custom のみ) | `eval "$(fnm env)"` (custom:73) に存在チェックが無く、無いと起動のたびにエラーが出る |
| `ja_JP.UTF-8` ロケール | `LANG` (custom は `LC_ALL` も) を `ja_JP.UTF-8` にする。無くても zsh 自体はエラーを出さないが、perl (`up` 関数で使う) などが `perl: warning: Setting locale failed.` を出す。`locale -a` に `ja_JP.utf8` が無ければ生成しておく (Ubuntu なら `sudo locale-gen ja_JP.UTF-8`) |

### 任意 (無くても起動はする。使う機能だけ動かない)

| ツール | 使う機能 |
|---|---|
| perl | `up` 関数 |
| git | `gts` などの git 用 alias |
| Emacs (`emacs`、`emacsclient`) | `em`、拡張子 alias (`.c` `.cpp` `.txt` など)。custom では `EDITOR`、`e` `ecli` `ekill` `erestart` `estart` も。この機では `~/.local/bin` に置いている |
| xsel と X サーバー | クリップボード用のグローバル alias (`toclip` など) |
| firefox (Linux 版) | 拡張子 alias (`.html` `.pdf` `.xhtml`) |
| zipinfo | 拡張子 alias (`.zip`) |
| nautilus | `naop` 関数 |
| sudo / apt | `poweroff` `reboot`、`apt*` (custom) |
| nkf | `nkfutf8` `nkfsjis` (custom) |
| g++、online-judge-tools (`oj`) | `g` `g++11` `gna` `gojt` (custom) |
| GNU GLOBAL (`gtags`) と Exuberant Ctags (`/usr/bin/ctags-exuberant`。gtags.conf の `exuberant-ctags` ラベルがこのパスを直接呼ぶ) | `gtags-table` (custom)。この機では使えない (下記) |
| `~/Dropbox/data/template/make/C_and_C++/Makefile` | `cpmake` (custom)。この機ではパスの大文字小文字が合わず使えない (下記) |
| Windows 側の Office / Acrobat 11.0 / Firefox | `ppt` `exl` `word` `adobe` `fx` (custom、WSL) |
| nvm | custom の末尾で `~/.nvm/nvm.sh` があれば読み込む |
| command-not-found (Ubuntu) | `/etc/zsh_command_not_found` があれば読み込み、未インストールのコマンドにパッケージ候補を出す |
| `~/.compfunc` | 自作の補完関数置き場。あれば `fpath` の先頭に追加する |

2026-10 時点の WSL2 機には xsel・trash-put・nautilus・oj・Linux 版 firefox が無い (`command -v` で確認)。そのため toclip 系、`naop`、`gojt`、`.html` `.pdf` `.xhtml` の拡張子 alias (Linux 版の `firefox` を呼ぶ) はそのままでは動かない。Windows 版の Firefox は `fx` (`firefox.exe`) で開ける。trash-put は無くても影響しない ([注意点](#動作に影響するもの)の `rm` の項)。

- `~/Dropbox` も無い (あるのは小文字の `~/dropbox -> /mnt/d/Dropbox`) ので、`cpmake` も `cp: cannot stat` で失敗する。
- `/usr/bin/ctags-exuberant` も無い (入っているのは universal-ctags だけ) ので、`gtags-table` は `gtags: cannot execute '/usr/bin/ctags-exuberant'` で失敗し、中途半端な `GPATH` `GRTAGS` `GTAGS` が残る。この機では `gtags --gtagslabel=universal-ctags` なら動く。

## 導入手順

> リポジトリは非公開なので、clone できるのはアクセス権のあるアカウント (SSH 鍵を GitHub に登録済み) だけ。他人に配るときは `_zshrc-orig` を単体で渡し、相手側で任意の場所に置いて `ln -s <置いた場所>/_zshrc-orig ~/.zshrc` とする (または `~/.zshrc` としてそのままコピーする)。

手順 1-5 のコマンドには `#` のコメントを付けていない。zsh の既定 (orig を読んだシェルも同じ) では対話入力の `#` がコメントにならず、引数として渡ってしまうため。

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

4. `~/.zshrc` からリンクを張る。どちらか一方だけを実行する。

   配布用:

   ```sh
   ln -s ~/.config/zsh/_zshrc-orig ~/.zshrc
   ```

   自分用 (先に fnm を入れておく。custom:72-73 が PATH と `fnm env` を設定するので、インストーラには必ず `--skip-shell` を付ける):

   ```sh
   curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
   ln -s ~/.config/zsh/_zshrc-my-custom ~/.zshrc
   ```

5. コンパイルして読み込む。`zcompile` は zsh の組み込みコマンドなので、bash からでも動くように `zsh -c` で実行し、zsh を起動し直す。

   ```sh
   zsh -c 'zcompile ~/.zshrc' && exec zsh
   ```

- `ZDOTDIR` は使わず (未設定か `$HOME` のまま)、`$HOME/.zshrc` を読ませる前提。`zns` も `~/.zshrc` を直接指す。
- このリポジトリが用意するのは `~/.zshrc` だけで、`~/.zshenv`・`~/.zprofile`・`~/.zlogin` は使わない。ただし Ubuntu では `/etc/zsh/zshrc` が `~/.zshrc` より先に読まれ、キーマップや `compinit` に影響する ([注意点](#動作に影響するもの))。`/etc/zsh/zshenv` も先に読まれるが、`PATH` が空 (か `/bin:/usr/bin`) のときに初期値を入れるだけ。
- custom は `fnm env` (custom:73) の直前に `~/.local/bin` と `~/.local/share/fnm` だけを `PATH` に足す (custom:71-72)。fnm は `~/.local/share/fnm/fnm` (Linux で公式インストーラを使ったときの既定) か `~/.local/bin` に置くか、zsh 起動時に `PATH` が通っている場所に入れる。それ以外 (cargo の `~/.cargo/bin`、Apple Silicon の Homebrew の `/opt/homebrew/bin` など) に入れたときは custom:72 のパスを書き換える。公式インストーラは `$SHELL` が zsh だと `${ZDOTDIR:-$HOME}/.zshrc` に設定を追記するので、いつ実行する場合も `--skip-shell` を付ける (付けないと、リンク後ならリポジトリの custom に追記され、手順 3 の直後なら通常ファイルの `~/.zshrc` ができて手順 4 の `ln -s` が `File exists` で失敗する)。
- fnm を入れずに custom を使う場合は、custom:73 の `eval "$(fnm env)"` を `command -v fnm >/dev/null && eval "$(fnm env)"` のようにガードする。
- `~/.zshrc` を差し替えずに試すなら、[AGENTS.md](AGENTS.md) の起動検査と同じく一時ディレクトリを `ZDOTDIR` にする。中で `zns` を打つと本物の `~/.zshrc` を読むので注意。また履歴は本物の `~/.zsh_history` に書き込まれ、ほかのシェルとも共有される (`HISTFILE` は `$HOME` 固定で、`share_history` が有効)。避けたいときは中で `HISTFILE=$ZDOTDIR/.zsh_history` を実行するか、`fc -p` で一時的な履歴に切り替える。

  ```sh
  d=$(mktemp -d) && ln -s ~/.config/zsh/_zshrc-orig "$d/.zshrc" && ZDOTDIR="$d" zsh -i; rm -rf "$d"
  ```

### 設定を変更したとき

リンク先 (リポジトリ内のファイル) を編集し、構文を確かめてから `zns` で反映する。

```sh
zsh -n ~/.config/zsh/_zshrc-my-custom   # 構文チェック
zns                                     # = zcompile ~/.zshrc && source ~/.zshrc
```

- `zcompile ~/.zshrc` の出力 `~/.zshrc.zwc` はリンクと同じ `$HOME` にでき、リポジトリ内にはできない。作られたファイルは読み取り専用 (`-r--r--r--`)。
- zsh は `.zwc` が元ファイルと同じか新しいときだけ `.zwc` を使い、古ければ元ファイルを読む。`zns` を忘れても次に起動したシェルには編集内容が反映される (その間 `.zwc` は使われない)。
- 今のシェルで `source` し直しても、一度定義した alias・関数・setopt は残る。定義を消したときは新しいシェルで確かめる。
- 設定を置く位置は[ファイル内の節の並び](#ファイル内の節の並び)に従う (環境変数と PATH は非端末ガードより前)。

## まず覚えるキー操作

この設定で追加したもの (2 ファイル共通)。emacs キーマップを前提に書いている。

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
- Linux では `LS_COLORS` で候補を `ls` と同じ色にする。
- `cd` はカレント配下 → ディレクトリスタック → `cdpath` の順に候補を探す。
- プロセスの候補は自分のプロセスだけ (`ps -u $(whoami)`)。`kill` の候補は色付きで出す。
- ホスト名は起動時に `~/.ssh/known_hosts` (ハッシュ化された行を除く)、`/etc/hosts`、`hostname`、`localhost` から集める。
- その他の setopt: `magic_equal_subst` (`--prefix=~/x` の `=` 以降も展開)、`complete_aliases`、`noautoremoveslash` (補完した末尾の `/` を残す)、`unsetopt promptcr` (改行で終わらない出力の直後にも、そのままプロンプトを出す)。custom は `INTERACTIVE_COMMENTS` (対話入力でも `#` 以降をコメントとして扱う) も有効。
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

`TERM` が `xterm*` / `kterm*` なら、`precmd` (custom:115 / orig:108) で端末のタイトルを `ディレクトリ名[フルパス]` にする。

### 関数

| 関数 | 動作 |
|---|---|
| `up <名前>` | カレントから上へたどり、指定した名前を持つ最も近いディレクトリ (カレント自身を含む) へ移動する。例: `/a/src/foo/src/bar` で `up src` → `/a/src/foo/src`、`up foo` → `/a/src/foo`、`up bar` → 移動しない。見つからなければ `no such file or directory: <名前>` を出して失敗する |
| `cdup` / `cdback` | Alt+↑ / Alt+← 用の ZLE ウィジェット。コマンドとして打つと `cd ..` / `popd` は実行されたうえで、`widgets can only be called when ZLE is active` が出る |
| `naop [dir...]` | nautilus でフォルダを開く。引数なしならカレント |
| `estart` (custom) | Emacs サーバーに接続できないときだけ、`$HOME` で `emacs --daemon` をバックグラウンド起動する。シェル起動時の自動実行 (custom:434) はコメントアウトしてある |

### alias

2 ファイル共通の主なもの:

| alias | 展開 |
|---|---|
| `zns` | `zcompile ~/.zshrc && source ~/.zshrc` |
| `gts` `gtd` `gta` `gtc` `gtm` `gtp` `gtl` `gtco` | `git` の `status` `diff` `add` `commit` `merge` `push` `log` `checkout` |
| `ls` (custom は Linux のみ) | `ls -FX --color=auto` (種別記号、拡張子順、色付き) |
| `la` / `ll` / `lla` | `ls -a` / `ls -lh` / `ls -lha` |
| `rm` / `ln` | `rm -v` / `ln -i -v` |
| `rmtmp` | `rm -v *~ #*#` (バックアップと Emacs の自動保存ファイルを削除するつもりの alias。[注意点](#動作に影響するもの)参照) |
| `poweroff` / `reboot` | `sudo` 付きで実行 |
| `s` `l` `ks` `lsa` `cd..` `em` `emasc` | 打ち間違い対策 (`ls`、`la`、`cd ..`、`emacs`) |

グローバル alias (コマンドライン上の単独の単語ならどこでも展開される):

| alias | 展開 |
|---|---|
| `G` `L` `H` `T` `S` `W` `X` | `\| grep` `\| less` `\| head` `\| tail` `\| sort` `\| wc` `\| xargs`。例: `grep "hoge" ./* W -l` = `grep "hoge" ./* \| wc -l` |
| `toclip` / `toclipall` | 標準出力 / 標準出力と標準エラーを xsel でクリップボードへ |
| `andclip` / `andclipall` | 上と同じ内容をクリップボードへ送り、画面にも表示する |
| `sl` / `LS` | `ls` |

拡張子 alias (ファイル名だけ打つと対応するコマンドで開く。例: `main.cpp` → `emacs main.cpp`):

- `.c` `.C` `.cpp` `.h` `.java` `.txt` `.xml` → `emacs`
- `.html` `.pdf` `.xhtml` → `firefox`
- `.zip` → `zipinfo` (中身の一覧)

custom だけにあるもの:

| alias | 展開 |
|---|---|
| `mv` / `cp` | `mv -i` / `cp -i` (上書き前に確認) |
| `e` / `ecli` | `emacs -nw` (Mac では `open -a emacs`) / `emacsclient -nw -a ''` (サーバーが無ければデーモンを起動して開く) |
| `ekill` / `erestart` | Emacs デーモンを終了 / 終了してから `estart` |
| `nkfutf8` / `nkfsjis` | `nkf -w --overwrite ` / `nkf -s --overwrite ` (ファイルを UTF-8 / Shift_JIS で上書き) |
| `g` / `a` / `g++11` | `g++` / `./a.out` / `g++ -std=c++11` |
| `gna` / `gojt` | `g++ main.cpp && ./a.out` / `g++ main.cpp && oj t` (競プロ用) |
| `cpmake` | `~/Dropbox/data/template/make/C_and_C++/Makefile` をカレントにコピー |
| `gtags-table` / `gtags-clear` (`rmgtags`) | `gtags --gtagslabel=exuberant-ctags` / `rm -v GPATH GRTAGS GTAGS` |
| `aptupd` `aptupg` `aptrem` `aptcle` `aptins` | `sudo apt` の `update` `upgrade` `autoremove` `autoclean` `install` |
| `ppt` `exl` `word` `adobe` `fx` | WSL から Windows の PowerPoint、Excel、Word、Acrobat、Firefox を起動 |

orig だけにあるもの: `go` → `gnome-open`。

## プラットフォーム別

### Linux

- 2 ファイルとも `dircolors` で `LS_COLORS` を設定し、補完候補も色付けする。custom ではこれと `ls` の alias を `linux*` 分岐に入れている。
- Ubuntu では `/etc/zsh_command_not_found` が読まれる。また `/etc/zsh/zshrc` が `~/.zshrc` より先に読まれ、zle の読み込み・Home / End などの割り当て・`compinit` を行う ([注意点](#動作に影響するもの))。

### macOS

- `_zshrc-orig` は GNU 版の `dircolors` と `ls -FX --color=auto` を無条件に使う (orig:114, 210)。標準の macOS には `dircolors` が無いので、そのままでは動かない。
- `_zshrc-my-custom` の `darwin*` 分岐 (custom:413-422) では、`e` を `open -a emacs` (GUI の Emacs.app) にし、`fpath` に `/usr/local/share/zsh-completions`、`PATH` の先頭に `/usr/local/bin` を足し、`HOMEBREW_CASK_OPTS="--appdir=/Applications"` を設定する。
- Mac では `ls` の alias と、補完候補全般の色付け (`LS_COLORS`) が定義されない。そのため `ls` `la` `ll` などは素の BSD `ls` になる。kill の候補の色付け (custom:361) は OS 分岐の外にあるので Mac でも効く。
- Homebrew は Intel 版の `/usr/local` だけを想定している (Apple Silicon の `/opt/homebrew` は扱っていない)。
- custom を Mac で使う場合も fnm は必要 (ガードが無い)。WSL 節も実行される (下記)。

### WSL (custom のみ)

ファイル末尾の「WSL」節 (custom:436-461) で次を設定する。

- `umask 022`
- `DISPLAY=:0` (custom:445)、`XAUTHORITY=~/.Xauthority`。`:0` は WSLg を前提にした値 (この機には `/mnt/wslg` がある)。コメント (custom:439) に Xming の URL があり、WSL1 用の `localhost:0.0` (custom:441) と、WSL2 で `/etc/resolv.conf` から組み立てる方式 (custom:444) が、どちらもコメントアウトで残っている
- `LC_ALL` / `LANG` を `ja_JP.UTF-8`
- Windows のアプリのディレクトリを `PATH` の末尾に追加し (custom:453-455)、`ppt` などの alias を定義する
  - Office16: `/mnt/c/Program Files/Microsoft Office/root/Office16`
  - Acrobat 11.0: `/mnt/c/Program Files (x86)/Adobe/Acrobat 11.0/Acrobat`
  - Firefox: `/mnt/c/Program Files/Mozilla Firefox/`

WSL かどうかの判定は無い。WSL 節から末尾まで (custom:436-471。nvm と Codex installer の行も含む) は OS 判定の外にあるので、macOS や素の Linux でも実行される。

### Node.js (custom のみ)

- fnm: `PATH` に `~/.local/share/fnm` を足して `eval "$(fnm env)"` する (custom:72-73)。`--use-on-cd` は付けていないので、`.node-version` による自動切り替えはしない。
- nvm: 末尾で `~/.nvm/nvm.sh` と `bash_completion` があれば読み込む (custom:463-465)。
- 最後の `typeset -U path PATH` (custom:471) で `PATH` の重複を取り除く。重複したパスは最初に出てきた位置に残る。

環境を引き継がずに起動した対話シェルでの `PATH` の並びは、下の 1-6 のとおり。次のコマンドで確かめられる (`SHELL` を渡さないと、custom:126 の `dircolors` が `dircolors: no SHELL environment variable, and no shell type option given` を出す)。

```sh
env -i HOME="$HOME" TERM=xterm SHELL="$(command -v zsh)" zsh -i -c 'print -l $path; whence -a node'
```

1. `~/.local/bin` (Codex installer の行 (custom:468) が最後に先頭へ足し、`typeset -U` で custom:71 の分がまとめられる)
2. nvm の node (`~/.nvm/versions/node/<版>/bin`)
3. fnm の multishell (`fnm env` が作る一時ディレクトリ)
4. `~/.local/share/fnm`
5. 元の `PATH`
6. Windows アプリの 3 ディレクトリ

この場合は nvm の `node` が先に見つかる。ただし入れ子のシェル (zsh の中で zsh を起動した場合など) では、`nvm.sh` が `PATH` に既にある nvm のパスをその場で置き換えるので、引き継いだ順序が残り、fnm の `node` が先頭になる (`whence -a node` で確認)。

エージェントのシェル (非対話で `~/.zshrc` を source) では nvm.sh は読まれず、fnm の `node` が先頭になる (親から引き継いだ `PATH` に nvm のパスがあれば、それはその後ろに残る)。

## 既知の注意点

> どのツールが入っているかなど、環境の状態は 2026-10 時点の WSL2 機で確かめたもの。

### 動作に影響するもの

- **fnm にガードが無い** (custom:73): fnm が無いと、起動のたびに `Command 'fnm' not found, did you mean: ...` (command-not-found がある場合。無ければ `command not found: fnm`) が出る。起動自体は続く。ガードの例は[導入手順](#導入手順)。
- **キーマップは zsh 起動時の `EDITOR` / `VISUAL` で決まる**: rc に `bindkey -e` は無い。Ubuntu の `/etc/zsh/zshrc` は `~/.zshrc` より先に `bindkey -M` (49 行目) と `zle -N` (82-83 行目) で zle を読み込むので、main キーマップはその時点で zsh が親プロセスから受け継いだ `EDITOR` / `VISUAL` で決まる (`vi` を含めば viins、含まなければ emacs)。custom:79 の `EDITOR` はこのシェルのキーマップには効かず、子プロセス (`EDITOR` を見るコマンドや入れ子の zsh) にだけ効く。git は `core.editor` が設定されていればそちらを使う。orig は `EDITOR` を設定しない。
  - 確認: `env EDITOR=vi zsh -i -c 'bindkey -lL main'` は custom でも `bindkey -A viins main` になる。`/etc/zsh/zshrc` を読まない `zsh -d` では、custom:329 の最初の `bindkey` で zle が読み込まれ、custom:79 の `EDITOR` が効いて emacs になる。
  - vi キーマップになると、Ctrl+A / Ctrl+E など emacs の既定キーは使えない (この rc の bindkey は main キーマップ、つまり viins に入る)。
  - 確実に emacs にするなら、キーバインド節の先頭 (ほかの `bindkey` より前) に `bindkey -e` を書く。
- **`TERM=xterm-256color` を無条件に設定する** (custom:76):
  - tmux や screen の中でも `TERM` が上書きされる。
  - Emacs の `M-x shell` のような dumb 端末でも `precmd` が定義され、タイトル用のエスケープシーケンスが出る。
  - 非端末ガードの `$#TERM -eq 0` は成り立たなくなり、実際には `PROMPT` だけで判定している。
- **fnm と nvm を両方読み込んでいる** (custom:72-73, 463-465): どちらの `node` が使われるかはシェルの起動のしかたで変わる ([Node.js](#nodejs-custom-のみ))。どちらか一方に寄せたい。
- **`rm` はゴミ箱に移さない** (custom:276-281 / orig:217-221): `trash-put` があれば `rm` を `trash-put` にする分岐があるが、直後の `alias rm='rm -v'` で必ず上書きされる。`rm` は確認もせずに削除する。
- **`rmtmp` が思うように消えない** (custom:282 / orig:222):
  - `*~` か `#*#` の片方でも該当ファイルが無いと、`no matches found` で何も削除しない (zsh の `NOMATCH`)。
  - custom では `setopt INTERACTIVE_COMMENTS` (custom:470) により、展開された `#*#` 以降がコメント扱いになる。`#...#` は消えず、同じ行で後ろに続けたコマンド (`rmtmp; ls` の `ls` など) も実行されない。
- **グローバル alias の副作用**: `G` `L` `H` `T` `S` `W` `X` `sl` `LS` などは引数の位置でも展開される。`echo X` は `echo | xargs`、`git sl` は `git ls` になる。文字どおり渡したいときはクォートする。
- **`nkfutf8` / `nkfsjis` の後ろの単語も alias 展開される** (custom:211-212): 展開結果が空白で終わる alias なので、次の単語も alias として展開される。例えばファイル名が `l` だと `ls` に化ける。
- **alias に git の補完が効かない** (custom:398 / orig:351): `complete_aliases` により alias は別のコマンドとして補完される。`gtco` などには補完関数が割り当てられていない (`$_comps[gtco]` は空、`git` は `_git`) ので、git のブランチ名などは補完されない。対処は `complete_aliases` を外すか、`compdef _git gtco=git-checkout` のように割り当てる (対処は未検証)。
- **`compinit` が 2 回走る**: Ubuntu の `/etc/zsh/zshrc` (110-112 行目) が `compinit` を実行したあと、rc でも実行する (custom:354-355 / orig:307-308)。前者を省くなら `~/.zshenv` に `skip_global_compinit=1` を書く。
- **`precmd` を直接定義している** (custom:115 / orig:108): `add-zsh-hook` を使っていないので、ほかに `precmd` を定義するツールを入れると上書きし合う。
- **Home / End は `^[OH` / `^[OF` だけ** (custom:329-330 / orig:282-283): アプリケーションモードのシーケンスしか bindkey していない。Ubuntu では `/etc/zsh/zshrc` が `zle-line-init` で端末をアプリケーションモードにし、terminfo で同じ割り当てもするので動く。それが無い環境では、通常モードの `^[[H` / `^[[F` は未定義のまま (この機でも `bindkey '^[[H'` は `undefined-key`)。
- **Alt+矢印は端末依存**: 端末が `^[[1;3A` などの xterm 形式のシーケンスを送る前提。Windows Terminal や VS Code のターミナルなど、端末側が Alt+矢印 を自分のショートカットに使っていると届かない。
- **ssh のホストが補完に出ないことがある** (custom:366): `known_hosts` がハッシュ化 (`HashKnownHosts`) されていると、そのホストは候補にならない。この機では `known_hosts` が全行ハッシュ化されているので、候補は `/etc/hosts`・`hostname`・`localhost` 由来だけになる。候補は起動時に一度だけ作る。
- **Codex installer の行** (custom:467-469): `export PATH="/home/ryohei/.local/bin:$PATH"` とユーザー名を直書きしている。[AGENTS.md](AGENTS.md) の「パスは `$HOME` で書く」とは食い違うが、インストーラーが管理するブロックなので、AGENTS.md でも依頼が無い限り書き換えない扱いにしている。他のユーザーや Mac ではこのパスは存在しない。中身は custom:71 と同じ `~/.local/bin` の追加で、custom:471 の `typeset -U` で 1 つにまとまる。
- **OS 判定の外にある設定**: WSL 節から末尾まで (nvm と Codex installer の行も含む) は Mac でも実行される ([WSL](#wsl-custom-のみ))。
- **Mac の zsh-completions が効かない**: `fpath` への追加 (custom:416) が `compinit` (custom:355) より後にあるので、そのシェルの補完には効かない。

### 重複している・効いていない定義

- `l` は `ls -CF` と定義した (custom:258 / orig:209) あと、打ち間違い対策で `ls` に上書きされる (custom:314 / orig:262)。最終的には `l=ls`。
- `auto_pushd` と `pushd_ignore_dups` が、基本設定 (42 / 46 行) と alias 節 (custom:243-244 / orig:194-195) の 2 か所にある (両ファイル)。
- custom では `LANG` (custom:67, 448) と `~/.local/bin` の `PATH` 追加 (custom:71, 468) も 2 回ずつ書かれている (結果は同じ)。
- `gtags-clear` (custom:228) と `rmgtags` (custom:283) は同じコマンド。
- kill 補完の `list-colors` (custom:129-130) は、シングルクォートの中で `\` と改行に分かれているので値が壊れている。custom:361 で上書きされるので実害は無い (orig では正常な値の orig:117 が orig:314 で上書きされる)。
- `hist_ignore_dups` は `hist_ignore_all_dups` に含まれる。`share_history` は `inc_append_history` の動作も含む (man では併用しないよう勧めている)。`hist_expire_dups_first` は、`hist_ignore_all_dups` で重複が残らず `HISTSIZE` と `SAVEHIST` も同じ値なので、ほぼ効かない。
- `menu_complete` が `auto_menu` より優先される。`auto_list`・`auto_menu`・`list_types`・`auto_param_keys` は zsh の既定で on なので、setopt しなくても同じ。
- `up` は変数 `to` を `local` にしていない (custom:152 / orig:137) ので、実行後もグローバル変数として残る。
- プロンプト節の `local GREEN` `BLUE` `DEFAULT` (custom:91-97 / orig:84-90) は関数の外にあるので local にならず、グローバル変数として残る。補完節の `hosts` `_ssh_hosts` `_etc_hosts` (custom:366-373 / orig:319-326) も同じくグローバルに残る。

### コメントの誤り

- custom:12 / orig:12 の「C-a 末尾に移動」は C-e の誤り。
- custom:43 / orig:43 の「キューではなくスタックで番号付け」: `pushd_minus` の実際の意味は、`+` と `-` の意味を入れ替えること。
- custom:344 / orig:297 の「#M-@」: 実際のキーは `` Alt+` `` と Alt+'。
- custom:391 / orig:344 の「一覧表示 (auto_list) せず、すぐに最初の候補を補完する」: custom:378 / orig:331 の `menu select` があるので、実際には候補の選択メニューも出る。
- custom:397 / orig:350 の「補完される前にオリジナルのコマンドまで展開してチェックする」: `complete_aliases` の実際の意味はこの逆で、alias を展開せずに補完する。
- custom:399 / orig:352 の「カッコの対応などを自動的に補完」: `auto_param_keys` は、パラメータ名の補完で自動的に入った空白などを、次に `}` などを打ったときに消す機能。
- custom:439 の Xming の URL は、今の `DISPLAY=:0` (WSLg) とは関係が無い (古い設定の名残)。

### orig だけの問題

- `LD_LIBRARY_PATH=${HOME}/local/lib:${LD_LIBRARY_PATH}` (orig:71) は、元の値が空だと末尾が `:` になり、カレントディレクトリが検索パスに入る。パスも `~/.local` ではなく `~/local`。
- `GREP_OPTIONS` (orig:225) は、GNU grep 3.6 以降では無視される。
- `alias go="gnome-open"` (orig:258) は、Go 言語の `go` コマンドを隠す。
- Mac ではそのまま動かない (GNU 版の `dircolors` と `ls` を無条件に使うため。[macOS](#macos) 参照)。

## エージェント向け

- 変更するときの規約は [AGENTS.md](AGENTS.md)。Claude Code は [CLAUDE.md](CLAUDE.md)、Codex は [.codex/README.md](.codex/README.md) も読む。
