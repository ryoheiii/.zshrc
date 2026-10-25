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
| [fzf-tab](https://github.com/Aloxaf/fzf-tab) | Tab 補完の候補を検索して選択 |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | よく訪問するディレクトリへ `z` / `zi` で移動 |

入力候補の `zsh-autosuggestions` と色分けの `zsh-syntax-highlighting` は、
現在の Oh My Zsh に同梱されたプラグインを使います。別途 clone する必要はありません。
プロンプトの見た目は [starship.toml](starship.toml) で管理します。
`ZSH_THEME` は空のままにし、Starship でプロンプトと入力位置を同じ行に表示します。
パスはホームの `~` 以外を省略せず、Git のブランチ・変更状態・rebase などの進行状態を表示します。
パスや入力が端末の幅を超える場合は、端末側で折り返されます。

### 有効なプラグイン

| プラグイン | できること |
|---|---|
| `git` | `gst`・`gd`・`gco` などで Git 操作を短縮 |
| `fzf` | Ctrl+R の履歴検索、Ctrl+T のファイル選択、Alt+C の移動 |
| `fzf-tab` | Tab で出た補完候補を文字入力で絞り込む。Enter は候補の採用で、コマンド実行はしない |
| `zoxide` | `z`・`zi` で訪問済みディレクトリへ移動 |
| `zsh-autosuggestions` | 入力候補を薄く表示。行末の → で採用 |
| `zsh-syntax-highlighting` | 入力中の構文を色分け |
| `vscode` | `vsc` で現在地を開き、`vscg file:42` で指定行、`vscd a b` で差分を表示 |
| `extract` | `extract archive.tar.gz` で形式に応じて展開。元のアーカイブと現在地は保持 |
| `sudo` | Esc を2回押して、入力中または直前のコマンドに `sudo` を付ける。実行は Enter |
| `copypath` | `copypath` または `copypath file` で絶対パスをクリップボードへコピー |

`fzf-tab` だけを外部プラグインとして取得し、残りは Oh My Zsh 同梱版を使います。
`vscode` は `code` が利用できる場合、`sudo` は同名のコマンドがある場合に有効になります。
入力支援は行編集できる端末でだけ有効になります。
共通する先頭部分がある候補は、最初の Tab でそこまで補完し、次の Tab で検索画面を開きます。
fzf-tab が未導入なら標準の補完メニューへ戻ります。起動時のダウンロードはありません。
Oh My Zsh の補完キャッシュは `${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh/.zcompdump` に保存し、
OS 側の `.zcompdump` と分離します。プラグイン追加後も、毎回の補完キャッシュ再生成を防ぎます。
展開には形式に応じた `tar`・`unzip`・`7z` などが必要です。コピーには利用可能なクリップボードが必要で、
WSL では Windows の `clip.exe`・`powershell.exe` に対応します。パスは Linux 形式のままです。

### VS Code と WSL

WSL 内で `code .` が使える状態なら、`vsc` でも同じフォルダーを開けます。
`vscr .` は既存ウィンドウを再利用し、`vscn .` は新しいウィンドウを開きます。
このプラグインは VS Code 本体や拡張機能をインストールせず、既存の `code` を短縮します。
Windows 側の `/mnt/<ドライブ>/` にしか `code` がない場合は、起動時の遅い探索を避けるため読み込みません。
その場合も `code .` 自体は直接利用できます。

VS Code の WSL 接続先では「Terminal: Select Default Profile」で zsh を選ぶと、この設定を使えます。
成功・失敗表示や出力コピーを提供する [Shell Integration](https://code.visualstudio.com/docs/terminal/shell-integration) は
VS Code が通常自動で有効にします。ターミナルタブの詳細で状態を確認でき、追加の source は通常不要です。
VS Code 側の補完ポップアップが Tab を受け取る場合は、`terminal.integrated.suggest.enabled` を無効にすると
zsh / fzf-tab の補完操作に統一できます。既存の Emacs 用 `EDITOR` は変更しません。

## セットアップ

Ubuntu / WSL では次を実行します。公式ツールの取得にはインターネット接続が必要です。

```sh
sudo apt update
sudo apt install zsh git bash coreutils curl tar gzip ca-certificates
git clone git@github.com:ryoheiii/.zshrc.git "$HOME/.config/zsh"
cd "$HOME/.config/zsh"
bash setup.sh install
exec zsh
```

必要な apt パッケージは次のとおりです。fzf・Starship・zoxide は公式配布版を使うため、
これらの apt パッケージや Rust・Go のビルド環境は不要です。

| 用途 | apt パッケージ |
|---|---|
| 通常のセットアップ | `zsh git bash coreutils curl tar gzip ca-certificates` |
| オフライン用の梱包・展開 | 上記に加えて `python3`（3.9 以上。アーカイブの検査用） |
| 回帰テスト | `bats`（1.5 以上）、`python3` |
| 任意の追加ツール | `emacs`、fnm 導入時は `unzip` |

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

## オフライン用の梱包・展開

通信できる PC で通常のセットアップを済ませ、導入済みの依存物を圧縮します。
[Emacs の梱包・展開コマンド](https://github.com/ryoheiii/.emacs.d/blob/main/emacs-setup.sh) と同じ名前です。

```sh
sudo apt install python3
cd "$HOME/.config/zsh"
bash setup.sh --packing-package
```

`package.tar.gz` に Oh My Zsh（同梱プラグインを含む）、fzf、fzf-tab、Starship、zoxide を保存します。
Git のローカル設定・hooks・未追跡ファイル、
独自の custom 設定、履歴・キャッシュ・資格情報、任意の Emacs・fnm・Node.js は含めません。
zsh 本体などの OS パッケージは移行先の apt で用意します。依存リポジトリの追跡ファイルにある未コミット変更は
梱包せず、エラーにします。圧縮に失敗した場合は既存のアーカイブを保持します。

会社 PC へは、この設定リポジトリと `package.tar.gz` の両方を渡してください。
設定リポジトリは Git で取得しても、必要なファイル（`setup.sh`・`_zshrc`・`starship.toml`）を
コピーしても構いません。アーカイブを `setup.sh` と同じディレクトリへ置き、次を実行します。

```sh
sudo apt install zsh git bash coreutils tar gzip python3
cd "$HOME/.config/zsh"
bash setup.sh --extract-package
exec zsh
```

`--extract-package` はネットワークへ接続せず依存物を配置し、通常の `install` と同じく
既存の `~/.zshrc`・コンパイル結果を退避して設定リンクを作ります。続けて `install` を実行する必要はありません。
`-p` / `-x` も使え、`bash setup.sh --extract-package /path/to/package.tar.gz` のように
アーカイブの場所を指定できます（梱包時も同様）。自分で作成した信頼できるアーカイブだけを使ってください。

配布元と配布先は同じ OS・CPU アーキテクチャに揃えてください。共有ライブラリの互換性も必要です。
展開先の外へ向くパス・リンク、形式不一致、不足ファイル、バイナリの実行失敗は配置前に拒否します。
梱包・展開では `ZSH` / `ZSH_CUSTOM` は未設定か標準配置にしてください。
プロンプトに独自の `STARSHIP_CONFIG` を指定している場合、その設定は別途移行してください。

既存のツールは `~/.zsh-package-backup.XXXXXX/` に退避し、配置途中の失敗時は復元します。
成功後も退避先は残り、`restore-map.txt` で元の配置先を確認できます。独自の custom 設定は
自動統合しないため、必要なら退避先から移行してください。動作確認後に不要な退避先を手動で削除できます。
`uninstall` は設定リンクの復元だけを行い、ツールの版は戻しません。
通信できる環境では、展開した依存物も `bash setup.sh update` で更新できます。

## 使い方

| 操作 | 内容 |
|---|---|
| Tab | 補完候補を検索して選択（fzf-tab）。未導入なら標準の補完メニュー |
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
補完・プラグインの変更や alias・関数・オプションの削除後は `exec zsh` で起動し直してください。

ツールの更新は次のとおりです。

```sh
cd "$HOME/.config/zsh"
git pull --ff-only
bash setup.sh update
exec zsh
```

`update` は Oh My Zsh・fzf・fzf-tab・Starship・zoxide を公式の最新版へ更新します。
fzf-tab の配置先は `${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab` です。
依存リポジトリの未コミット変更や異なる取得元は上書きせず停止します。
途中で失敗した場合、先に更新したツールは元へ戻りません。

検証には bats-core 1.5 以上と Python 3（TTY 付き検査用）を使います。

```sh
sudo apt install bats python3
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
