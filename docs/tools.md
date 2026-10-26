# 追加ツールの導入

Ubuntu / WSL 向けの手順です。追加後は `exec zsh` で起動し直します。
設定ファイルへの追記やプラグインマネージャーは不要です。

## 基本ツール

```sh
bash setup.sh install
```

| ツール | 用途 | 導入先 |
|---|---|---|
| Oh My Zsh | 補完・履歴・キー操作・Git alias とプラグイン | `~/.oh-my-zsh` |
| fzf | Ctrl+R で履歴、Ctrl+T でパス挿入、Alt+C で移動 | `~/.fzf` |
| Starship | 現在地・Git・実行結果のプロンプト | `~/.local/bin/starship` |
| zoxide | `z` / `zi` で訪問したディレクトリへ移動 | `~/.local/bin/zoxide` |

Oh My Zsh と fzf は公式リポジトリを clone します。fzf の `install --bin` はバイナリだけを取得します。
Starship と zoxide は公式インストーラーを使います。zoxide のマニュアルは `~/.local/share/man` に入ります。
入力候補の `zsh-autosuggestions` と構文色分けの `zsh-syntax-highlighting` は Oh My Zsh の同梱版です。
追加の clone は不要です。不足しているツールは読み飛ばし、標準の補完・履歴検索を使えます。

更新は `bash setup.sh update`、反映は `exec zsh` です。起動時にはネットワークへ接続しません。
Oh My Zsh / fzf の更新は fast-forward に限定します。
Starship / zoxide が導入先にあれば `install` では保持し、`update` で実行確認済みのバイナリへ置き換えます。
導入先が symlink やディレクトリの場合、`update` は上書きせず停止します。
アンインストールは設定だけを復元し、ツールを残します。

## Emacs

```sh
sudo apt install emacs
```

`e` は `emacs -nw`、`ecli` は `emacsclient -nw -a ''` です。
`ecli` は既存のデーモンへ接続し、なければ起動します。
`emacsclient` があり `EDITOR` が未指定の場合だけ、`EDITOR` にも同じコマンドを設定します。

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
`zns` で設定を再読み込みしても、`fnm use` で選択中のバージョンを保持します。
新しい zsh では fnm の既定バージョンで初期化し、その後の切り替えはシェルごとに独立します。
ローカル設定がない場合、PATH は fnm の Node.js → `~/.local/share/fnm` → `~/.fzf/bin` → `~/.local/bin` → 元の PATH の順です。
PC 固有の PATH は `_zshrc.env.local` へ追加します。共通 PATH 設定後、fnm 初期化前に読み込むため、選択中の Node.js の PATH がその先頭に置かれます。
