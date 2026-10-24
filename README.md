<!-- -*- gfm -*- -->

# zsh 設定

履歴検索、Tab 補完、入力候補、構文色分け、Git ブランチ表示をまとめた個人用設定です。
設定本体は [_zshrc](_zshrc) の 1 ファイル。WSL2 / Ubuntu・zsh 5.9 で動作確認しています。
Oh My Zsh を土台に、Starship・fzf・zoxide を組み合わせます。追加ツールがなくても基本機能は動きます。

## 構成の考え方

継続的に開発されるツールへ基本機能を任せ、独自コードを減らします。
追加のプラグインマネージャーと専用フォントは不要です。起動時の取得・自動更新は行いません。

| ツール | 役割 |
|---|---|
| [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) | 補完・履歴・キー操作・Git alias とプラグインの読み込み |
| [Starship](https://starship.rs/guide/) | 現在地・Git ブランチと変更状態・実行時間・終了コード |
| [fzf](https://github.com/junegunn/fzf#key-bindings-for-command-line) | 履歴・ファイル・ディレクトリの絞り込み検索 |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | よく訪問するディレクトリへ `z` / `zi` で移動 |

入力候補の `zsh-autosuggestions` と色分けの `zsh-syntax-highlighting` は、
現在の Oh My Zsh に同梱されたプラグインを使います。別途 clone する必要はありません。
プロンプトの見た目は [starship.toml](starship.toml) で管理します。

## セットアップ

Ubuntu / WSL では次を実行します。公式ツールの取得にはインターネット接続が必要です。

```sh
sudo apt update
sudo apt install zsh git bash coreutils curl tar gzip
git clone git@github.com:ryoheiii/.zshrc.git "$HOME/.config/zsh"
cd "$HOME/.config/zsh"
bash setup.sh install
exec zsh
```

clone にはリポジトリへのアクセス権と GitHub に登録した SSH 鍵が必要です。
既に clone 済みなら `cd` から実行してください。

`setup.sh` はツールを導入してから `~/.zshrc` を設定本体へのリンクにします。既存の設定とコンパイル結果は
`~/.zshrc.zsh-config-backup/` に退避し、再実行しても上書きしません。
取得に失敗した場合は元の設定を保持するため、原因を解消して再実行できます。
ログインシェルの変更は手動です。`ZDOTDIR` は未設定か `$HOME` にしてください。

ログインシェルも zsh にする場合:

```sh
chsh -s "$(command -v zsh)"
```

変更後はログインし直します。
言語と端末の設定は OS から引き継ぐため、日本語ロケールの生成は必須ではありません。
Emacs・Node.js は任意です。[追加ツールの導入](docs/tools.md)を参照してください。

## 使い方

| 操作 | 内容 |
|---|---|
| Tab / 矢印キー | 大文字小文字を区別しない補完 / 候補の選択 |
| ↑ / ↓ | 入力した先頭文字に一致する履歴を検索。空なら通常の履歴移動 |
| Ctrl+R | fzf で履歴を絞り込み検索。fzf がなければ標準の履歴検索 |
| Ctrl+T / Alt+C | ファイルのパスを挿入 / ディレクトリを検索して移動（fzf） |
| 行末で → | 薄く表示された入力候補を採用（autosuggestions） |
| `z 名前` / `zi` | 訪問したディレクトリへ移動 / 候補を検索して移動 |
| `up` / `up src` | 親へ / 上位にある最寄りの `src` ディレクトリへ移動 |
| `ll` / `lla` | 詳細一覧 / 隠しファイルも含む詳細一覧 |
| `gst` / `gd` / `gco` | `git status` / `git diff` / `git checkout` |
| `zns` | 現在のシェルへ設定を再読み込み |

ディレクトリ名だけでも移動できます。履歴は `~/.zsh_history` に最大 10,000 件保存し、シェル間で共有します。
キー操作は emacs キーマップに統一しています。プロンプトには現在地と Git ブランチを表示し、失敗時には終了コードを赤く表示します。

そのほかのコマンドと注意点は[操作リファレンス](docs/usage.md)へ。

## 設定の変更

`~/.config/zsh/_zshrc` と `starship.toml` を編集します。別のプロンプト設定は `STARSHIP_CONFIG` で指定できます。
現在のシェルには `zns` で反映できますが、読み込み済みプラグインは再初期化しません。
プラグインの変更や alias・関数・オプションの削除後は `exec zsh` で起動し直してください。

ツールの更新は次のとおりです。

```sh
cd "$HOME/.config/zsh"
git pull --ff-only
bash setup.sh update
exec zsh
```

`update` は Oh My Zsh・fzf・Starship・zoxide を公式の最新版へ更新します。
依存リポジトリの未コミット変更や異なる取得元は上書きせず停止します。
途中で失敗した場合、先に更新したツールは元へ戻りません。

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
導入済みのツール・リポジトリ・キャッシュ・履歴・ログインシェルは残ります。
