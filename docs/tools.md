# 追加ツールの導入

必要な機能だけ導入してください。追加・削除した後は、新しい zsh を起動します。
以下は Ubuntu / WSL 向けです。

| 機能 | インストール方法 | 主なコマンド |
|---|---|---|
| Emacs | `sudo apt install emacs` | `e`、`ecli`、`estart` |
| 文字コード変換 | `sudo apt install nkf` | `nkfutf8`、`nkfsjis` |
| C++ | `sudo apt install g++` | `g`、`gna` |
| ソースコードの索引 | `sudo apt install global universal-ctags` | `gtags-table` |
| クリップボード | `sudo apt install xsel` | `toclip`、`andclip` |
| ZIP の内容表示 | `sudo apt install unzip` | ZIP ファイル名で実行 |
| ファイルマネージャー | `sudo apt install nautilus` | `naop` |
| ブラウザー | `sudo apt install firefox` | HTML・PDF ファイル名で実行 |

GUI とクリップボードには WSLg などの X サーバーが必要です。Firefox は Linux 側のコマンドを使います。
`emacsclient` があれば `EDITOR` も Emacs に設定されます。
`gtags-table` は GNU GLOBAL の設定から利用可能な ctags を選びます。

## Node.js（fnm）

この設定は fnm を自動で読み込みます。nvm は読み込みません。
[fnm の公式手順](https://github.com/Schniz/fnm#installation)に従い、設定ファイルへの追記を省いて導入します。
導入先はこの設定が読み込む場所に揃えます。

```sh
sudo apt install curl unzip
curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell --install-dir "$HOME/.local/share/fnm"
exec zsh
```

新しい zsh で Node.js を導入します。

```sh
fnm install --lts
fnm use lts-latest
fnm default lts-latest
```

`--skip-shell` は必須です。省略するとリンク先の `_zshrc` へ設定が追記されます。
`.node-version` による自動切り替えは設定していません。
PATH は fnm の Node.js → `~/.local/share/fnm` → `~/.local/bin` → 元の PATH の順です。

## 競技プログラミング（oj）

`gojt` を使う場合だけ、g++ に加えて online-judge-tools を導入します。

```sh
sudo apt install g++ pipx
pipx install online-judge-tools
```

`~/.local/bin` は設定本体で PATH に追加されます。
