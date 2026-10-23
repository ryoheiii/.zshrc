<!-- -*- gfm -*- -->

# zsh 設定

zsh の設定ファイル (`.zshrc`) を管理するリポジトリ。汎用の 1 ファイル `_zshrc` を置き、`~/.zshrc` からシンボリックリンクを張って使う。OS・WSL・ツールの有無は起動時に判定し、該当しない環境ではその設定を何もしない ([環境ごとに有効になる設定](#環境ごとに有効になる設定))。インストールスクリプトや Makefile は無い。

- 動作確認環境: WSL2 (Ubuntu) 上の zsh 5.9 (`x86_64-ubuntu-linux-gnu`)。`~/.zshrc -> ~/.config/zsh/_zshrc`
- clone 先: `~/.config/zsh` (リポジトリ名は `.zshrc`)
- 前提: 日本語ロケール (`ja_JP.UTF-8`) と zsh の emacs キーマップ。rc に `bindkey -e` は無く、キーマップは zsh 起動時の `EDITOR` / `VISUAL` で決まる ([注意点](#動作に影響するもの))
- OS の分岐は alias 節にある `case ${OSTYPE}` の `linux*` だけ (`ls` の alias)。Mac 向けの設定 (`darwin*` 分岐) は 2026-10 に削除した

> 行番号 (例: `_zshrc:92`) は 2026-10 時点の `_zshrc` での位置。編集するとずれるので目安として使う。

## ファイル構成

| ファイル | 役割 |
|---|---|
| `_zshrc` | 設定本体 (468 行)。`~/.zshrc` からリンクして使う。環境やツールに依存する設定はガードで囲み、該当しない環境では何もしない |
| `test/zshrc.bats` | `_zshrc` の回帰テスト。`bats test` で実行する ([設定を変更したとき](#設定を変更したとき)) |
| `README.md` | このファイル |
| `AGENTS.md` / `CLAUDE.md` / `.claude/` / `.codex/` | AI エージェント向けの変更規約と設定 ([エージェント向け](#エージェント向け)) |
| `.gitignore` | `*.zwc`、`.zcompdump*`、`/README.html` (mdh で README を変換した HTML)、Claude Code のローカル設定 (`CLAUDE.local.md`、`.claude/settings.local.json`、`.claude/hookify.*.local.md`、`.claude/worktrees/`) を除外 |

### 環境ごとに有効になる設定

旧 `_zshrc-orig` (配布用) と `_zshrc-my-custom` (自分用) を 2026-10 に 1 ファイルへ統合した。環境・ツールに依存する設定は起動時に判定し、該当しなければ定義も export もしない (エラーも出ない)。

- コマンドの有無は関数 `__zshrc_has` (_zshrc:27) で調べる。`PATH` 上の実行ファイルだけを見て alias・関数は数えず、WSL の Windows 側のディレクトリ (`/mnt/c` など `/mnt/<1 文字>/` 配下) は探さない (探すと無いコマンド 1 つにつき 0.1 秒前後かかるため)。判定は起動時の 1 回だけなので、ツールを入れたら新しいシェルか `zns`、消したら新しいシェルで反映する。
- ファイル・ディレクトリは `[ -f ]` / `[ -d ]` / `[ -r ]`、OS は `case ${OSTYPE}`、WSL は `WSL_DISTRO_NAME` か `/proc/sys/kernel/osrelease` で判定する ([WSL](#wsl))。

| 条件 | 有効になる設定 |
|---|---|
| 常に | 履歴・ディレクトリスタック・補完の setopt と `auto_cd`・`correct_all`・`interactive_comments`、`typeset -gU path PATH`、`LANG`、`~/.local/bin` の `PATH`、`TERM` (`xterm` のときだけ `xterm-256color` に上げる)、プロンプト、`WORDCHARS`、関数 `up` `cdup` `cdback`、`zns`、git の alias とその補完の割り当て (`compdef`)、`la` `ll` `lla`、`mv -i` `cp -i`、`rm -v` `ln -i -v`、`rmtmp`、`poweroff` `reboot`、グローバル alias (`G` `L` `H` `T` `S` `W` `X`)、打ち間違い対策 (`s` `l` `ks` `sl` `LS` `lsa` `cd..`)、キーバインド、補完ルール |
| `TERM` が `dumb`・`linux`・`eterm*`・空のどれでもない | 端末タイトル (precmd フックに登録する関数 `__zshrc_title`) |
| `compdef` が未定義 (Ubuntu の `/etc/zsh/zshrc` が `compinit` していない) か、`zns` で読み直したとき | `compinit` ([補完](#補完)) |
| Linux (`linux*`) | `ls -FX --color=auto` |
| WSL | `umask 022`、`DISPLAY=:0`、`LC_ALL=ja_JP.UTF-8`。`~/.Xauthority` があれば `XAUTHORITY` も |
| fnm | `eval "$(fnm env --shell zsh)"` |
| emacsclient | `EDITOR="emacsclient -nw -a ''"` |
| emacs | `e` `ecli` `ekill` `erestart` `em` `emasc`、関数 `estart`、拡張子 alias (`.c` `.C` `.cpp` `.h` `.java` `.txt` `.xml`) |
| dircolors | `LS_COLORS` と補完候補の色付け (OS に依らない) |
| nkf / g++ / gtags / apt | `nkfutf8` `nkfsjis` / `g` `a` `g++11` `gna` (`gojt` は oj もある場合) / `gtags-clear` `rmgtags` (`gtags-table` は ctags プラグイン用の ctags もある場合) / `apt*` |
| nautilus / zipinfo / xsel / firefox (Linux 版) | 関数 `naop` / `.zip` の拡張子 alias / `toclip` 系のグローバル alias / `.html` `.pdf` `.xhtml` の拡張子 alias |
| gnome-open があり、`go` コマンドが無い | `go` → `gnome-open` |
| `~/.local/share/fnm` | `PATH` の先頭に追加 (環境変数節の「カスタムインストール先」) |
| `/etc/zsh_command_not_found` | command-not-found の読み込み |
| `~/.ssh/known_hosts` / `/etc/hosts` | ホスト名補完の候補に読み込む |

git と sudo (`poweroff` `reboot`) はガードせず常に使う前提 (無ければ使ったときに失敗する)。

### ファイル内の節の並び

環境変数 → **非対話ガード** → 基本設定 → プロンプト → シェル変数 → 関数 → alias → キーバインド → 補完ルール → その他 (WSL ブロックだけ)。

非対話ガード `[[ -o interactive ]] || return 0` (_zshrc:68) は、対話シェルでなければその行で読み込みを打ち切る (`source` の終了状態は 0)。zsh は非対話シェルでは `~/.zshrc` を読まないので、実際に効くのは非対話の zsh から `~/.zshrc` を `source` したときなど。これに当たる主な例は、Claude Code や Codex がシェルスナップショットを作るために非対話シェルから `~/.zshrc` を source する場合 ([AGENTS.md](AGENTS.md))。シェルのオプションで判定するので、`PS1` を export した親から起動された場合でも止まる。このときガードより後の基本設定・alias・関数・setopt・WSL 節は読まれない。

- ガードより前 (非対話でも適用される): 関数 `__zshrc_has`、`typeset -gU path PATH`、`LANG`、`PATH` (`~/.local/bin`。`~/.local/share/fnm` はある場合)、fnm (fnm がある場合)、`TERM` (`xterm` のときだけ上げる)、`EDITOR` (emacsclient がある場合)
- ガードより後 (非対話では適用されない): 基本設定以降の全部。履歴とディレクトリスタックの setopt、`auto_cd`・`correct_all`・`interactive_comments`、command-not-found の読み込み、WSL 節 (`umask`、`DISPLAY`、`LC_ALL`、`XAUTHORITY`) もこちらに入る。WSL 節は、非対話で source する呼び出し元の `umask`・`LC_ALL` を上書きしないよう、意図してガードより後に置いている

環境変数と PATH はガードより前、対話専用の設定は後に置く (WSL 節は上記の理由で例外)。

## 前提ツール

### 必須

| ツール | 理由 |
|---|---|
| zsh | 本体。ログインシェルにするなら `chsh -s "$(command -v zsh)"` |
| GNU coreutils (`ls`。`dircolors` は任意) | Linux では `ls -FX --color=auto` を alias にする。`dircolors` があれば OS に依らず起動時に実行して `LS_COLORS` を設定する (無ければ色付けを省く) |
| `ja_JP.UTF-8` ロケール | `LANG` (WSL では `LC_ALL` も) を `ja_JP.UTF-8` にする。無くても zsh 自体はエラーを出さないが、ロケールを参照するほかのコマンドが警告を出すことがある (perl の `perl: warning: Setting locale failed.` など)。`locale -a` に `ja_JP.utf8` が無ければ生成しておく (Ubuntu なら `sudo locale-gen ja_JP.UTF-8`) |

### 任意 (無くても起動はする。多くの alias・関数はツールがある場合だけ定義する)

| ツール | 使う機能 |
|---|---|
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
| GNU GLOBAL (`gtags`)。`gtags-table` は Universal Ctags か Exuberant Ctags も (gtags.conf の `universal-ctags` / `exuberant-ctags` ラベルの `ctagscom` が指す実体。Debian 系では `/usr/bin/ctags-universal` / `/usr/bin/ctags-exuberant`) | `gtags-clear` `rmgtags`。`gtags-table` は起動時に `gtags --config=ctagscom` で実行できる ctags のラベルを選び (universal-ctags 優先)、どちらも無ければ定義しない |
| fnm | `~/.local/share/fnm` があれば `PATH` に足し (環境変数節の「カスタムインストール先」)、起動時の `PATH` に fnm があれば `eval "$(fnm env --shell zsh)"` を実行する ([Node.js](#nodejs)) |
| command-not-found (Ubuntu) | `/etc/zsh_command_not_found` があれば読み込み、未インストールのコマンドにパッケージ候補を出す |

2026-10 時点の WSL2 機には xsel・nautilus・oj・gnome-open・Linux 版 firefox が無い (`command -v` で確認)。そのため toclip 系、`naop`、`gojt`、`go`、`.html` `.pdf` `.xhtml` の拡張子 alias (Linux 版の `firefox` を呼ぶ) は定義されない。

- `/usr/bin/ctags-exuberant` も無い (入っているのは universal-ctags だけ) ので、`gtags-table` は `gtags --gtagslabel=universal-ctags` になる。

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

   fnm を使うなら先に入れておく (任意。Node.js のバージョン管理は fnm だけを設定し、nvm は読み込まない。環境変数節が PATH と `fnm env` を設定するので、インストーラには必ず `--skip-shell` を付ける):

   ```sh
   curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
   ```

5. コンパイルして読み込む。`zcompile` は zsh の組み込みコマンドなので、bash からでも動くように `zsh -c` で実行し、zsh を起動し直す。

   ```sh
   zsh -c 'zcompile ~/.zshrc' && exec zsh
   ```

- `ZDOTDIR` は使わず (未設定か `$HOME` のまま)、`$HOME/.zshrc` を読ませる前提。`zns` も `~/.zshrc` を直接指す。
- このリポジトリが用意するのは `~/.zshrc` だけで、`~/.zshenv`・`~/.zprofile`・`~/.zlogin` は使わない。ただし Ubuntu では `/etc/zsh/zshrc` が `~/.zshrc` より先に読まれ、キーマップや `compinit` に影響する ([注意点](#動作に影響するもの))。`/etc/zsh/zshenv` も先に読まれるが、`PATH` が空 (か `/bin:/usr/bin`) のときに初期値を入れるだけ。
- 環境変数節は `fnm env` の直前に `~/.local/bin` と、あれば `~/.local/share/fnm` を `PATH` に足す。後者は「カスタムインストール先」(標準でない場所に入れたツールの `PATH` をまとめる置き場) にある。fnm は `~/.local/share/fnm/fnm` (Linux で公式インストーラを使ったときの既定) か `~/.local/bin` に置くか、zsh 起動時に `PATH` が通っている場所に入れる。それ以外 (cargo の `~/.cargo/bin`、Homebrew の `/opt/homebrew/bin` など) に入れたときは `__zshrc_has fnm` が偽になって fnm が設定されないので、「カスタムインストール先」にその場所を同じ形で足す。公式インストーラは `$SHELL` が zsh だと `${ZDOTDIR:-$HOME}/.zshrc` に設定を追記するので、いつ実行する場合も `--skip-shell` を付ける (付けないと、リンク後ならリポジトリの `_zshrc` に追記され、手順 3 の直後なら通常ファイルの `~/.zshrc` ができて手順 4 の `ln -s` が `File exists` で失敗する)。
- `~/.zshrc` を差し替えずに試すなら、[AGENTS.md](AGENTS.md) の起動検査と同じく一時ディレクトリを `ZDOTDIR` にする。中で `zns` を打つと本物の `~/.zshrc` を読むので注意。また履歴は本物の `~/.zsh_history` に書き込まれ、ほかのシェルとも共有される (`HISTFILE` は `$HOME` 固定で、`share_history` が有効)。避けたいときは中で `HISTFILE=$ZDOTDIR/.zsh_history` を実行するか、`fc -p` で一時的な履歴に切り替える。

  ```sh
  d=$(mktemp -d) && ln -s ~/.config/zsh/_zshrc "$d/.zshrc" && ZDOTDIR="$d" zsh -i; rm -rf "$d"
  ```

### 設定を変更したとき

リンク先 (リポジトリ内のファイル) を編集し、テストで確かめてから `zns` で反映する。

```sh
zsh -n ~/.config/zsh/_zshrc   # 構文チェック
bats ~/.config/zsh/test       # 回帰テスト (push 前に実行する)
zns                           # = zcompile ~/.zshrc && source ~/.zshrc
```

- テストは `test/zshrc.bats` にあり、[bats-core](https://github.com/bats-core/bats-core) 1.5 以上で動く (Ubuntu なら `sudo apt install bats`)。[AGENTS.md](AGENTS.md) の構文検査・起動検査 (対話シェルで最後まで読まれ、stderr に出力がない) に加えて、次を確かめる (全 16 件): 対話シェルで source し直しても終了状態 0 で、後から足した補完関数を拾うために `compinit` を再実行すること、非対話シェルから source すると (`PS1` を export した環境からでも) 非対話ガードで止まり、終了状態 0 で `~/.local/bin` が `PATH` に足され重複が無いこと、グローバル rc を読まない起動 (`zsh -d`) でも補完が初期化されること、常に定義する関数・alias がそろっていること (`sl` `LS` がグローバル alias でないことも)、git の alias に git の補完が割り当てられていること、Home / End が通常モードのシーケンスにも割り当てられていること、`TERM` の昇格と端末タイトルのフックの有無、`rmtmp` が消すファイル、`typeset -gU path PATH` が最初の `PATH` の変更と非対話ガードより前にあること、作業用のグローバル変数を残さないこと、`up` の移動先と失敗時の動作、ユーザー名入りの絶対パスが無いこと。`~/.zshrc` は差し替えず、一時ディレクトリを `ZDOTDIR` にして作業中の `_zshrc` を読ませる。
- `zcompile ~/.zshrc` の出力 `~/.zshrc.zwc` はリンクと同じ `$HOME` にでき、リポジトリ内にはできない。作られたファイルは読み取り専用 (`-r--r--r--`)。
- zsh は `.zwc` が元ファイルと同じか新しいときだけ `.zwc` を使い、古ければ元ファイルを読む。`zns` を忘れても次に起動したシェルには編集内容が反映される (その間 `.zwc` は使われない)。
- 今のシェルで `source` し直しても、一度定義した alias・関数・setopt は残る。定義を消したときは新しいシェルで確かめる。
- 2026-10 のリファクタ (端末タイトルのフック化など) のような構成の変更は、新しいシェルで反映する。旧設定で起動中のシェルで `zns` すると、旧設定が定義した `precmd` 関数が残って新しいタイトル用のフックと両方動き、最初の 1 回は `compinit` も省かれる (判定に使う `__zshrc_loaded` がまだ無いため)。
- ツールの有無は起動時に判定する ([環境ごとに有効になる設定](#環境ごとに有効になる設定))。ツールを入れたり消したりしたときは、新しいシェルで確かめる (入れた場合は `zns` でもよい)。
- 設定を置く位置は[ファイル内の節の並び](#ファイル内の節の並び)に従う (環境変数と PATH は非対話ガードより前)。

## まず覚えるキー操作

この設定で追加したもの。emacs キーマップを前提に書いている。

| キー | 動作 |
|---|---|
| Alt+↑ | 親ディレクトリへ移動 (`cdup`) |
| Alt+← | 直前にいたディレクトリへ戻る (`cdback` = `popd`)。押すたびに残りのディレクトリスタックを表示し、スタックが空なら `directory stack empty` になる |
| Ctrl+← / Ctrl+→ | 単語単位でカーソル移動。`/` も区切りになるので、パスは 1 段ずつ止まる |
| Home / End | 行頭 / 行末へ移動 (`^[OH` `^[OF` と `^[[H` `^[[F` の両方に割り当てる) |
| Delete | カーソル位置の 1 文字を削除 |
| `` Alt+` `` | 入力中の行全体を `` `...` `` で囲み、先頭に空白を入れてカーソルを行頭に戻す |
| Alt+' | 入力中の行全体を `'...'` で囲み、同様に行頭に戻る (zsh 既定の quote-line を上書き) |

`` Alt+` `` は「内側のコマンドを先に打つ」使い方をする。`pwd` と打って `` Alt+` ``、続けて `echo` と打って Enter すると `` echo `pwd` `` が実行される。どちらもカーソルが行末にある前提の動きになる。

zsh の emacs キーマップの既定動作 (ファイル冒頭のコメントに載っているもの。この rc では bindkey していない):

| キー | 動作 |
|---|---|
| Ctrl+R | 履歴を検索 |
| Ctrl+A / Ctrl+E | 行頭 / 行末へ移動 |
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
- 実行のたびに追記し、複数の zsh の間で共有する (`share_history`。追記の動作も含むので `inc_append_history` は使わない)。

### 補完

- `compinit` で初期化 (dump は `~/.zcompdump`)。Ubuntu では `/etc/zsh/zshrc` が先に `compinit` を済ませている (`compdef` が定義済み) ので、起動時は rc で再実行しない (補完関数の検査に約 0.1 秒かかるため)。`zns` で読み直したとき (内部用のグローバル変数 `__zshrc_loaded` が設定済み) は実行し、後から入れた補完関数を拾う。`/etc/zsh/zshrc` が `compinit` しない環境 (Ubuntu 以外など) では起動時に実行する。
- グループ見出しを太字で表示し、候補が無いと `No matches for: ...` と出す。
- git の alias (`gts` `gtd` `gta` `gtc` `gtm` `gtp` `gtl` `gtco`) には `compdef _git gts=git-status … gtco=git-checkout` で git の補完を割り当てている (`complete_aliases` が有効なので alias 名ごとに指定する)。`gtco <Tab>` でブランチなどが補完される。
- 小文字で打つと大文字の候補にもマッチする (大文字で打った場合は小文字にマッチしない)。
- `dircolors` がある場合は (OS に依らず)、`LS_COLORS` で候補を `ls` と同じ色にする。
- `cd` はカレント配下 → ディレクトリスタック → `cdpath` の順に候補を探す。
- プロセスの候補は自分のプロセスだけ (`ps -u $EUID`。`$EUID` は補完の実行時に展開する)。`kill` の候補は色付きで出す。
- ホスト名は起動時に `~/.ssh/known_hosts` (ハッシュ化された行を除く)、`/etc/hosts`、`$HOST` (自ホスト名)、`localhost` から集める (`/etc/hosts` の IP アドレスも候補に入る)。作業用の変数は無名関数の中に閉じ、グローバル変数を残さない。`zns` で読み直すと集め直す。
- その他の setopt: `magic_equal_subst` (`--prefix=~/x` の `=` 以降も展開)、`complete_aliases` (alias を展開せず、別のコマンドとして補完する)、`noautoremoveslash` (補完した末尾の `/` を残す)、`unsetopt promptcr` (改行で終わらない出力の直後にも、そのままプロンプトを出す。[注意点](#動作に影響するもの)参照)。`interactive_comments` (対話入力でも `#` 以降をコメントとして扱う) も有効。
- ディレクトリスタック: `auto_pushd`、`pushd_minus`、`pushd_ignore_dups`。

### プロンプト

```text
user@hostname:dir$                                          [9:05:42]
```

| 変数 | 設定 (色の指定を除く) | 表示 |
|---|---|---|
| `PROMPT` | `%n@%M:%1~$ ` | `ユーザー名@ホスト名 (FQDN):カレントディレクトリ名$ `。ディレクトリ名は太字の青、ホームでは `~`。末尾は root でも `$` |
| `RPROMPT` | `[%*]` | プロンプトを出した時刻 `[時:分:秒]`。時刻は太字の緑、時は 0 埋めしない。表示したあとは更新されない |
| `PROMPT2` | `%_$ ` | 継続行に `dquote` などのパーサの状態を出す |
| `SPROMPT` | `%r is correct? [n,y,a,e]: ` | `correct_all` の修正確認 |

`TERM` が `dumb`・`linux`・`eterm*`・空のどれでもなければ、`add-zsh-hook` で precmd フックに登録した関数 `__zshrc_title` (_zshrc:133-137) が、プロンプトを出す前に端末のタイトルを `ディレクトリ名[フルパス]` にする (`/` ではディレクトリ名も `/`)。外部コマンドは使わない。tmux や screen の中でも設定する。

### 関数

| 関数 | 動作 |
|---|---|
| `up <名前>` | カレントから上へたどり、指定した名前を持つ最も近いディレクトリ (カレント自身を含む) へ移動する。例: `/a/src/foo/src/bar` で `up src` → `/a/src/foo/src`、`up foo` → `/a/src/foo`、`up bar` → 移動しない。見つからなければ `no such file or directory: <名前>` を出して失敗する。perl などの外部コマンドは使わず、`-` で始まる名前も扱える |
| `cdup` / `cdback` | Alt+↑ / Alt+← 用の ZLE ウィジェット。コマンドとして打つと `cd ..` / `popd` は実行されたうえで、`widgets can only be called when ZLE is active` が出る |
| `naop [dir...]` (nautilus がある場合だけ) | nautilus でフォルダを開く。引数なしならカレント |
| `estart` (emacs がある場合だけ) | Emacs サーバーに接続できないときだけ、`$HOME` で `emacs --daemon` をバックグラウンド起動する。シェル起動時の自動実行 (関数節の `# estart` の行) はコメントアウトしてある |

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
| `rmtmp` | `rm -v -- *\~(N) \#*\#(N)` (バックアップ `*~` と Emacs の自動保存ファイル `#*#` を削除する。片方しか無くても消す。どちらも無いと rm が `missing operand` で失敗する (終了状態 1)) |
| `poweroff` / `reboot` | `sudo` 付きで実行 |
| `s` `l` `ks` `sl` `LS` `lsa` `cd..` | 打ち間違い対策 (`ls`、`la`、`cd ..`) |

グローバル alias (コマンドライン上の単独の単語ならどこでも展開される):

| alias | 展開 |
|---|---|
| `G` `L` `H` `T` `S` `W` `X` | `\| grep` `\| less` `\| head` `\| tail` `\| sort` `\| wc` `\| xargs`。例: `grep "hoge" ./* W -l` = `grep "hoge" ./* \| wc -l` |
| `toclip` / `toclipall` (xsel がある場合だけ) | 標準出力 / 標準出力と標準エラーを xsel でクリップボードへ |
| `andclip` / `andclipall` (同上) | 上と同じ内容をクリップボードへ送り、画面にも表示する |

拡張子 alias (ファイル名だけ打つと対応するコマンドで開く。例: `main.cpp` → `emacs main.cpp`。開くコマンドがある場合だけ定義する):

- `.c` `.C` `.cpp` `.h` `.java` `.txt` `.xml` → `emacs`
- `.html` `.pdf` `.xhtml` → `firefox`
- `.zip` → `zipinfo` (中身の一覧)

ツールがある場合だけ定義するもの:

| alias | 条件 | 展開 |
|---|---|---|
| `e` / `ecli` | emacs | `emacs -nw` / `emacsclient -nw -a ''` (サーバーが無ければデーモンを起動して開く) |
| `ekill` / `erestart` | emacs | Emacs デーモンを終了 / 終了してから `estart` |
| `em` / `emasc` | emacs | 打ち間違い対策 (`emacs`) |
| `nkfutf8` / `nkfsjis` | nkf | `nkf -w --overwrite` / `nkf -s --overwrite` (ファイルを UTF-8 / Shift_JIS で上書き) |
| `g` / `a` / `g++11` | g++ | `g++` / `./a.out` / `g++ -std=c++11` |
| `gna` / `gojt` | g++ (`gojt` は oj も) | `g++ main.cpp && ./a.out` / `g++ main.cpp && oj t` (競プロ用) |
| `gtags-table` | gtags と、gtags.conf の `universal-ctags` か `exuberant-ctags` ラベルが指す ctags | `gtags --gtagslabel=universal-ctags` (universal-ctags の実体が無く exuberant-ctags があれば `--gtagslabel=exuberant-ctags`)。ラベルは起動時に選ぶ |
| `gtags-clear` (`rmgtags`) | gtags | `rm -v GPATH GRTAGS GTAGS` |
| `aptupd` `aptupg` `aptrem` `aptcle` `aptins` | apt | `sudo apt` の `update` `upgrade` `autoremove` `autoclean` `install` |
| `go` | gnome-open があり、`go` コマンドが無い | `gnome-open` |

## プラットフォーム別

### Linux

- `ls` の alias (`ls -FX --color=auto`) は alias 節の `linux*` 分岐に入れている。ほかの OS では素の `ls` のまま。`dircolors` による `LS_COLORS` と補完候補の色付けは OS 分岐の外にあり、OS に依らず `dircolors` がある場合だけ設定する。
- Ubuntu では `/etc/zsh_command_not_found` が読まれる。また `/etc/zsh/zshrc` が `~/.zshrc` より先に読まれ、zle の読み込み・Home / End などの割り当て・`compinit` を行う ([注意点](#動作に影響するもの))。

### WSL

その他節の `### WSL` ブロック (_zshrc:452-466) は、`WSL_DISTRO_NAME` があるか、`/proc/sys/kernel/osrelease` に `microsoft` を含むときだけ次を設定する (後者は ssh や `sudo -i`、`env -i` で環境変数が無い場合のため。fork はしない)。非対話ガードより後にあるので、エージェントのシェル (非対話で `~/.zshrc` を source) には適用されない ([ファイル内の節の並び](#ファイル内の節の並び))。

- `umask 022`
- `DISPLAY=:0` (_zshrc:459)、`~/.Xauthority` があれば `XAUTHORITY`。`:0` は WSLg を前提にした値 (この機には `/mnt/wslg` がある)
- `LC_ALL` を `ja_JP.UTF-8` (`LANG` は環境変数節で常に設定する)

WSL のカーネルで動く Docker コンテナなどでも、`osrelease` が同じなので判定が真になる (影響は `umask`、`DISPLAY`、`LC_ALL`)。Windows 側のアプリ (Office、Acrobat、Firefox) の `PATH` と alias は 2026-10 の統合時に削除した。

### Node.js

- fnm: `~/.local/share/fnm` があれば `PATH` に足し (環境変数節の「カスタムインストール先」)、fnm があれば `eval "$(fnm env --shell zsh)"` する。`--use-on-cd` は付けていないので、`.node-version` による自動切り替えはしない。
- nvm は読み込まない。起動のたびに約 0.55 秒かかっていた `~/.nvm/nvm.sh` の読み込みは 2026-10 に削除し、fnm に一本化した。`nvm` コマンドは使えず、npm も fnm 側の版になる (2026-10 時点で fnm 側は 11.14.1、nvm 側は 10.9.4)。fnm が無く nvm だけがある機では、node が `PATH` に入らない。
- 環境変数節の `__zshrc_has` の直後 (最初の `PATH` の変更より前) にある `typeset -gU path PATH` (_zshrc:36) で、以降の代入のたびに `PATH` の重複を取り除く。重複したパスは最初に出てきた位置に残る。非対話ガードより前にあるので、非対話の source でも効く。`-g` は、関数の中から source されても局所変数にしないため。

環境を引き継がずに起動した対話シェルでの `PATH` の並びは、下の 1-4 のとおり。次のコマンドで確かめられる。

```sh
env -i HOME="$HOME" TERM=xterm SHELL="$(command -v zsh)" zsh -i -c 'print -l $path; whence -a node'
```

1. fnm の multishell (`fnm env` が作る一時ディレクトリ)
2. `~/.local/share/fnm`
3. `~/.local/bin`
4. 元の `PATH`

`~/.local/bin` は node のパスより後ろになる (nvm の後で `~/.local/bin` を先頭へ戻していた Codex installer のブロックは 2026-10 に削除した)。2026-10 時点では `~/.local/bin` と node の `bin` に同名のコマンドは無い。

入れ子のシェル (zsh の中で zsh を起動した場合など) やエージェントのシェル (非対話で `~/.zshrc` を source) でも、`fnm env` が新しい multishell を `PATH` の先頭に足すので、fnm の `node` が先頭になる (親から引き継いだ `PATH` に nvm のパスがあれば、それはその後ろに残る)。

## 既知の注意点

> どのツールが入っているかなど、環境の状態は 2026-10 時点の WSL2 機で確かめたもの。

### 動作に影響するもの

- **キーマップは zsh 起動時の `EDITOR` / `VISUAL` で決まる**: rc に `bindkey -e` は無い。Ubuntu の `/etc/zsh/zshrc` は `~/.zshrc` より先に `bindkey -M` (49 行目) と `zle -N` (82-83 行目) で zle を読み込むので、main キーマップはその時点で zsh が親プロセスから受け継いだ `EDITOR` / `VISUAL` で決まる (`vi` を含めば viins、含まなければ emacs)。環境変数節の `EDITOR` (_zshrc:63-65。emacsclient がある場合だけ設定する) はこのシェルのキーマップには効かず、子プロセス (`EDITOR` を見るコマンドや入れ子の zsh) にだけ効く。git は `core.editor` が設定されていればそちらを使う。
  - 確認: `env EDITOR=vi zsh -i -c 'bindkey -lL main'` はこの rc でも `bindkey -A viins main` になる。`/etc/zsh/zshrc` を読まない `zsh -d` では、_zshrc:362 の最初の `bindkey` で zle が読み込まれ、_zshrc:64 の `EDITOR` (emacsclient がある場合) が効いて emacs になる。
  - vi キーマップになると、Ctrl+A / Ctrl+E など emacs の既定キーは使えない (この rc の bindkey は main キーマップ、つまり viins に入る)。
  - 確実に emacs にするなら、キーバインド節の先頭 (ほかの `bindkey` より前) に `bindkey -e` を書く。
- **`TERM` は `xterm` のときだけ `xterm-256color` に上げる** (_zshrc:57-60): tmux (既定は `tmux-256color`)・screen・dumb などの `TERM` は上書きしない。普段の Windows Terminal や VS Code のターミナル (`xterm-256color`) では変化がない。
  - Emacs の `M-x shell` (`TERM=dumb`) では、端末タイトルのエスケープシーケンスが出ない代わりに、`ls`・git・grep の色やプロンプトの太字も出ない。`RPROMPT` の時刻も描かれず、直前のコマンドが戻さなかった文字属性はプロンプトに残る。Emacs 側で `comint-terminfo-terminal` を設定すれば戻せる。
  - 以前は上書きで隠れていた `TERM` 側の問題が表に出る。terminfo の無い `TERM` (kitty や ghostty から ssh で入ったときの `xterm-kitty` `xterm-ghostty` など) では `unknown terminal type` が出る (対処は接続先に terminfo を入れる。kitty なら `kitten ssh`)。GNU screen の既定 (`TERM=screen`) では 8 色になる (`~/.screenrc` に `term screen-256color` を書く)。
  - tmux の中から ssh すると、接続先にも `tmux-256color` が渡る (接続先に terminfo が無ければ同じエラーになる)。
- **改行で終わらない出力の直後は表示がずれる** (`unsetopt promptcr`、_zshrc:126): `printf foo` のように改行で終わらない出力の直後は、その続きにプロンプトが出る。zle はプロンプトを行頭から描いた前提で位置を計算するため、`RPROMPT` が右端で次の行へ折り返し、入力は次の行の先頭から始まる。長い行の編集でも表示が崩れる。Ctrl+L で再描画するか改行すれば直る。既定の `prompt_cr` と `prompt_sp` に戻す (`unsetopt promptcr` の行を消す) と、改行の無い出力の末尾に反転した `%` が付き、プロンプトは次の行に出る (`PROMPT_EOL_MARK=''` で記号を消せる)。
- **グローバル alias の副作用**: `G` `L` `H` `T` `S` `W` `X` (xsel がある場合は `toclip` 系も) は引数の位置でも展開される。`echo X` は `echo | xargs` になる。文字どおり渡したいときはクォートする。`sl` `LS` は通常の alias なので、`echo sl` や `git sl` で `ls` に化けることはない。
- **Ubuntu では `compinit` を `/etc/zsh/zshrc` 側で実行する**: Ubuntu の `/etc/zsh/zshrc` (109-112 行目) が先に `compinit` を実行するので、rc 側は起動時に再実行しない (`compdef` が定義済みかで判定する。`zns` で読み直したときは実行する。_zshrc:391-395)。`~/.zshenv` に `skip_global_compinit=1` を書くと、`/etc/zsh/zshrc` は `compinit` を省き、rc 側が実行する。
- **Alt+矢印は端末依存**: 端末が `^[[1;3A` などの xterm 形式のシーケンスを送る前提。Windows Terminal や VS Code のターミナルなど、端末側が Alt+矢印 を自分のショートカットに使っていると届かない。
- **ssh のホストが補完に出ないことがある** (_zshrc:418): `known_hosts` がハッシュ化 (`HashKnownHosts`) されていると、そのホストは候補にならない。この機では `known_hosts` が全行ハッシュ化されているので、候補は `/etc/hosts`・`$HOST`・`localhost` 由来だけになる。候補は起動時 (と `zns` で読み直したとき) にだけ作る。
- **Codex installer のブロックは削除済み**: Codex のインストーラーが追記していた `# >>> Codex installer >>>` のブロック (nvm の後で `~/.local/bin` を `PATH` の先頭へ戻す) は 2026-10 に削除した ([Node.js](#nodejs))。インストーラーを再実行すると、ユーザー名入りの絶対パスで追記し直される可能性がある (未確認)。追記されたら削除するか、残すなら `$HOME` 表記に直す。

### 重複している・効いていない定義

- `gtags-clear` と `rmgtags` (_zshrc:264-265) は同じコマンド。
- `hist_ignore_dups` は、記録の上では `hist_ignore_all_dups` と同じ働きになる。ただし ↑↓ で今の行と同じ履歴を飛ばす働きがあるので、意図して残している。`hist_expire_dups_first` は、`hist_ignore_all_dups` で重複が残らず `HISTSIZE` と `SAVEHIST` も同じ値なので、ほぼ効かない。
- `menu_complete` が `auto_menu` より優先される。`auto_list`・`auto_menu`・`list_types`・`auto_param_keys` は zsh の既定で on なので、setopt しなくても同じ (明示のために残している)。

## エージェント向け

- 変更するときの規約は [AGENTS.md](AGENTS.md)。Claude Code は [CLAUDE.md](CLAUDE.md)、Codex は [.codex/README.md](.codex/README.md) も読む。
