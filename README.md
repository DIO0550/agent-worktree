# agent-worktree

codex / agy などの CLI エージェントを、Claude Code の `--worktree` と同じ感覚で git worktree 内で起動するための bash ラッパーです。`.worktreeinclude` による gitignore 済みファイルのコピーにも対応しています。

```console
$ agy -w AA
wt: origin/main から worktree-AA を作成します
wt: .worktreeinclude: 2 個のファイルをコピーしました
wt: /path/to/repo/.gemini/worktree/AA で agy を起動します
```

## 特徴

- `codex -w <name>` / `agy -w <name>` で worktree を自動作成してその中で起動
- `codex -w` (名前省略) で矢印キーのセレクタを表示。既存 worktree の選択と新規作成の両方に対応
- `.worktreeinclude` を Claude Code Desktop と同じ AND 条件 (パターン一致 かつ gitignore 済み) で展開。パターン解釈は git 本体に委譲
- エージェント終了時に worktree を「残す / 削除」から選択 (Claude Code の終了時プロンプト相当)。`WT_ON_EXIT` で常に残す・常に削除にも変更可
- 配置先はエージェントごとに自動で切り替え (`agy` → `.gemini/worktree/<name>`, `codex` → `.codex/worktree/<name>`, その他 → `.<コマンド名>/worktree/<name>`)。ブランチ名 `worktree-<name>`・分岐元 `origin/HEAD` は Claude Code のネイティブ挙動に合わせたデフォルト
- 依存は git と bash のみ。fzf などの外部ツールは不要

## インストール

クローン不要、1コマンドで入ります。

```bash
curl -fsSL https://raw.githubusercontent.com/dio0550/agent-worktree/main/install.sh | bash
source ~/.zshrc       # または ~/.bashrc
```

本体は `~/.agent-worktree` に配置され、rc ファイル (`$SHELL` から自動判定) に `# >>> agent-worktree >>>` マーカー付きブロックが追記されます。更新は同じコマンドを再実行するだけです。

シェルを明示指定する場合は引数を渡します。

```bash
curl -fsSL https://raw.githubusercontent.com/dio0550/agent-worktree/main/install.sh | bash -s -- zsh
```

アンインストール (rc のブロックと `~/.agent-worktree` を削除):

```bash
curl -fsSL https://raw.githubusercontent.com/dio0550/agent-worktree/main/uninstall.sh | bash
```

インストーラの挙動は環境変数で変更できます。

| 変数 | 既定値 | 説明 |
|---|---|---|
| `AGENT_WORKTREE_HOME` | `~/.agent-worktree` | 本体の配置先 |
| `AGENT_WORKTREE_REF` | `main` | 取得する git ref (タグやブランチを指定可) |
| `AGENT_WORKTREE_REPO` | `dio0550/agent-worktree` | 取得元リポジトリ |

<details>
<summary>クローンして使う場合 (開発時)</summary>

`install.sh` はスクリプトと同じ場所に `bin/wt` と `shell/wt-wrap.sh` があればダウンロードせず、そのクローンをそのまま参照します。

```bash
git clone https://github.com/dio0550/agent-worktree.git
cd agent-worktree
./install.sh          # $SHELL から自動判定 (bash / zsh を明示指定も可)
source ~/.zshrc
```

この場合 `uninstall.sh` は rc のブロックだけを消し、クローンしたリポジトリには触れません。

</details>

## 使い方

```bash
agy -w AA             # worktree "AA" を解決 (無ければ作成) して agy 起動
agy -w                # セレクタで選択 (「+ 新規作成」も選べる)
agy -w AA --model x   # -w AA 以外の引数はそのまま agy へ渡る
agy                   # フラグ無しなら通常どおり起動
```

コアの `wt` コマンドは単体でも使えます。

```bash
wt resolve AA         # パスを出力 (無ければ作成)
wt create AA          # 新規作成
wt select             # セレクタでパスを1つ出力
wt list               # worktree 一覧
wt remove AA          # worktree とブランチを削除 (未マージなら残す)
wt include <path>     # 既存 worktree へ .worktreeinclude を手動展開
```

## .worktreeinclude

プロジェクトルートに置くと、worktree 新規作成時に gitignore 済みファイルをコピーします。記法は `.gitignore` と同じです (`.worktreeinclude.example` 参照)。

```
.env
.env.*
**/.claude/settings.local.json
```

コピーされるのは「パターンに一致し、かつ gitignore 済みの未追跡ファイル」のみです。既存ファイルは上書きしません。macOS (APFS) では clonefile によるコピーを試み、`node_modules` のような大きなディレクトリも高速に複製できます。

## 設定

環境変数で挙動を変更できます。

| 変数 | 既定値 | 説明 |
|---|---|---|
| `WT_WRAP_COMMANDS` | `codex agy` | ラップするコマンド (空白区切り) |
| `WT_ROOT_DIR` | コマンド別 (下表参照) | worktree の配置先 (メイン worktree 相対) の全コマンド共通の上書き |
| `WT_ROOT_DIR_<CMD>` | 未設定 | コマンド別の配置先上書き (例: `WT_ROOT_DIR_CODEX=.mycodex/wt`)。コマンド名は大文字化し `-` は `_` に置換 |
| `WT_BRANCH_PREFIX` | `worktree-` | ブランチ名の接頭辞 |
| `WT_BASE_REF` | `origin/HEAD` (無ければ `HEAD`) | 分岐元 |
| `WT_ON_EXIT` | `ask` | エージェント終了時の worktree の扱い。`ask`: 残すか削除するかを選択 / `keep`: 常に残す / `remove`: 常に削除 |

配置先の既定値はラップするコマンドごとに異なります。優先順位は `WT_ROOT_DIR_<CMD>` > `WT_ROOT_DIR` > 既定値です。

| コマンド | 既定の配置先 |
|---|---|
| `agy` (antigravity) | `.gemini/worktree` |
| `codex` | `.codex/worktree` |
| その他のラップコマンド | `.<コマンド名>/worktree` |
| `wt` 単体 | `.claude/worktrees` |

使用する配置先 (`.gemini/worktree/` など) は `.gitignore` に追加してください。

## ライセンス

MIT
