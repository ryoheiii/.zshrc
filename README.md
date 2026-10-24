<!-- -*- gfm -*- -->

# zsh 設定

履歴の共有、Tab 補完、ディレクトリ移動、短縮コマンドをまとめた個人用設定です。
設定本体は [_zshrc](_zshrc) の 1 ファイル。WSL2 / Ubuntu・zsh 5.9 で動作確認しています。
追加ツールがある場合だけ、対応する機能を有効にします。

## セットアップ

必要なのは **zsh・Git・Bash・GNU coreutils・日本語ロケール**です。
Ubuntu / WSL では次を実行します。

```sh
sudo apt update
sudo apt install zsh git bash coreutils locales
sudo locale-gen ja_JP.UTF-8
git clone git@github.com:ryoheiii/.zshrc.git "$HOME/.config/zsh"
cd "$HOME/.config/zsh"
bash setup.sh install
exec zsh
```

clone にはリポジトリへのアクセス権と GitHub に登録した SSH 鍵が必要です。
既に clone 済みなら `cd` から実行してください。

`setup.sh` は `~/.zshrc` を設定本体へのリンクにします。既存の設定とコンパイル結果は
`~/.zshrc.zsh-config-backup/` に退避し、再実行しても上書きしません。
ツールの導入とログインシェルの変更は手動です。`ZDOTDIR` は未設定か `$HOME` にしてください。

ログインシェルも zsh にする場合:

```sh
chsh -s "$(command -v zsh)"
```

変更後はログインし直します。
Emacs・Node.js などは任意です。[追加ツールの導入](docs/tools.md)を参照してください。

## 使い方

| 操作 | 内容 |
|---|---|
| Tab / 矢印キー | 補完候補を表示 / 選択 |
| Ctrl+R | 履歴を検索 |
| Alt+↑ / Alt+← | 親ディレクトリへ / 移動履歴を戻る |
| `up src` | 上位にある最寄りの `src` ディレクトリへ移動 |
| `ll` / `lla` | 詳細一覧 / 隠しファイルも含む詳細一覧 |
| `gts` / `gtd` | `git status` / `git diff` |
| `zns` | 設定をコンパイルして現在のシェルへ再読み込み |

ディレクトリ名だけでも移動できます。履歴は `~/.zsh_history` に最大 10,000 件保存し、シェル間で共有します。
キー操作は emacs キーマップを前提にしています。Ctrl+R などが効かない場合は `bindkey -e` で切り替えてください。
Alt+矢印は端末側のショートカット設定にも依存します。

そのほかのコマンドと注意点は[操作リファレンス](docs/usage.md)へ。

## 設定の変更

`~/.config/zsh/_zshrc` を編集します。新しいシェルにはそのまま反映され、現在のシェルには `zns` で反映できます。
alias・関数を削除した場合は、新しいシェルで確認してください。

検証には bats-core 1.5 以上を使います。

```sh
sudo apt install bats
cd "$HOME/.config/zsh"
bats test
```

変更時の規約は [AGENTS.md](AGENTS.md)、エージェント設定は [.codex/README.md](.codex/README.md) にあります。

## アンインストール

```sh
cd "$HOME/.config/zsh"
bash setup.sh uninstall
```

リンクと使用中のコンパイル結果を削除し、退避した設定を復元します。
リンク先が変更されている場合は、安全のため処理を中止します。
導入済みのツール・リポジトリ・履歴・ログインシェルは残ります。
