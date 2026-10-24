# 操作リファレンス

## 移動・編集

| 操作 | 動作 |
|---|---|
| `up <名前>` | カレント自身も含め、上位の最も近い同名ディレクトリへ移動 |
| `cd -1` / `cd -<Tab>` | 直前のディレクトリへ / 移動履歴から選択 |
| Ctrl+A / Ctrl+E、Home / End | 行頭 / 行末へ移動 |
| Ctrl+← / Ctrl+→ | 単語単位で移動。パスは `/` ごとに区切る |
| Ctrl+K / Ctrl+W | 行末まで / 直前の単語を削除 |
| Ctrl+L | 画面を再描画 |
| Esc h / Esc q / Esc ? | コマンドのヘルプ / 入力を一時退避 / コマンドの解決先を表示 |
| `` Alt+` `` / Alt+' | 入力行をバッククォート / シングルクォートで囲む（カーソルが行末にある前提） |

emacs キーマップを前提にしています。必要なら `bindkey -e` で切り替えます。
Alt+↑ と Alt+← はキー操作専用です。対応する `cdup` / `cdback` は直接実行しません。
打ち間違いの修正確認では、`n` はそのまま実行、`y` は修正、`a` は中止、`e` は編集へ戻ります。

## 短縮コマンド

| コマンド | 内容 |
|---|---|
| `gts` `gtd` `gta` `gtc` | `git status` / `diff` / `add` / `commit` |
| `gtm` `gtp` `gtl` `gtco` | `git merge` / `push` / `log` / `checkout` |
| `la` `ll` `lla` | `ls -a` / `ls -lh` / `ls -lha` |
| `rmtmp` | カレントのバックアップ `*~` と Emacs 自動保存 `#*#` を削除 |
| `aptupd` `aptupg` `aptins` | `sudo apt update` / `upgrade` / `install` |
| `aptrem` `aptcle` | `sudo apt autoremove` / `autoclean` |
| `poweroff` `reboot` | `sudo` 付きで電源断 / 再起動 |

Linux の `ls` は色・種別記号付きで、拡張子順に並べます。
`cp`・`mv`・`ln` は上書きを確認し、`rm` は削除した名前を表示します。
`rmtmp` は対象が無いとエラーになります。

### グローバル alias

| 単語 | 展開 |
|---|---|
| `G` `L` `H` `T` `S` `W` `X` | `\| grep` / `\| less` / `\| head` / `\| tail` / `\| sort` / `\| wc` / `\| xargs` |
| `toclip` / `toclipall` | 標準出力 / 標準出力と標準エラーをクリップボードへ（xsel が必要） |
| `andclip` / `andclipall` | 同じ内容をクリップボードと画面の両方へ（xsel が必要） |

例: `ls G txt` は `ls | grep txt` になります。
引数の位置でも展開されるため、文字として渡す場合は `echo 'X'` のようにクォートしてください。

### ツールがある場合だけ使えるもの

| コマンド | 内容 |
|---|---|
| `e` / `ecli` | ターミナル版 Emacs / emacsclient を起動 |
| `estart` / `ekill` / `erestart` | Emacs デーモンの起動 / 終了 / 再起動 |
| `nkfutf8 <file>` / `nkfsjis <file>` | UTF-8 / Shift_JIS に変換して上書き |
| `g` / `g++11` / `a` | `g++` / C++11 指定 / `./a.out` |
| `gna` / `gojt` | `main.cpp` をコンパイルして実行 / `oj t`（後者は oj も必要） |
| `gtags-table` | ctags を利用して GNU GLOBAL の索引を作成 |
| `gtags-clear` / `rmgtags` | `GPATH`・`GRTAGS`・`GTAGS` を削除 |
| `naop [dir...]` | Nautilus で指定フォルダーを開く。省略時はカレント |
| `go` | gnome-open があり、Go 言語の `go` が無い場合に gnome-open を実行 |

ファイル名だけでも開けます。C/C++・Java・TXT・XML は Emacs、HTML・PDF・XHTML は Firefox、ZIP は zipinfo を使います。
ツールの導入方法は[追加ツール](tools.md)へ。

## 設定と注意点

- プロンプトは `user@hostname:dir$`、右側は表示時の時刻です。
- 履歴は共有され、重複と先頭が空白の入力は保存しません。
- WSL では `umask 022`、`DISPLAY=:0`、`LC_ALL=ja_JP.UTF-8` を設定します。WSLg を想定しています。
- `TERM` は `xterm` の場合だけ `xterm-256color` にします。SSH 先で端末エラーが出る場合は、接続先に対応する terminfo が必要です。
- 改行で終わらない出力の直後はプロンプトが崩れることがあります。Ctrl+L で再描画できます。
- ハッシュ化された `known_hosts` のホスト名は SSH 補完に出ません。
- `zns` は `~/.zshrc.zwc` を生成します。設定より古いコンパイル結果は起動時に無視されます。
- 非対話シェルから明示的に source した場合も環境変数と PATH を設定します。`up` などの操作用関数・alias・キーバインドは対話シェル用です。

実装の細部は [_zshrc](../_zshrc) の日本語コメント、変更規約と検証方法は [AGENTS.md](../AGENTS.md) を参照してください。
