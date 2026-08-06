# agent-worktree

codex / agy などの CLI エージェントを、Claude Code の `--worktree` と同じ感覚で git worktree 内で起動するための bash ラッパーです。`.worktreeinclude` による gitignore 済みファイルのコピーにも対応しています。

```console
$ agy -w AA
wt: origin/main から worktree-AA を作成します
wt: worktree へ 5 個のファイルをコピーしました
wt: /path/to/repo/.gemini/worktree/AA で agy を起動します
```

## 特徴

- `codex -w <name>` / `agy -w <name>` で worktree を自動作成してその中で起動
- `codex -w` (名前省略) で矢印キーのセレクタを表示。既存 worktree の選択と新規作成の両方に対応
- gitignore 済みのスキル / カスタムコマンド (`.gemini/skills` `.agents/skills` `.gemini/commands` など) を既定で worktree へコピー。worktree でも `/` にプロジェクトのスキルが出る
- `.worktreeinclude` を Claude Code Desktop と同じ AND 条件 (パターン一致 かつ gitignore 済み) で展開。パターン解釈は git 本体に委譲
- エージェント終了時に worktree を「残す / 削除」から矢印キーで選択 (Claude Code の終了時プロンプト相当)。未コミットの変更があっても削除できる。`WT_ON_EXIT` で常に残す・常に削除にも変更可
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

エージェントを終了すると、worktree をどうするかを矢印キーで選べます (`WT_ON_EXIT=ask` のとき)。

```console
worktree "AA" をどうしますか？ (↑↓: 移動, Enter: 決定, q: 残す)
 > 残す
   削除 (未コミットの変更 3 件を破棄)
```

コアの `wt` コマンドは単体でも使えます。

```bash
wt resolve AA         # パスを出力 (無ければ作成)
wt create AA          # 新規作成
wt select             # セレクタでパスを1つ出力
wt list               # worktree 一覧
wt remove AA          # worktree とブランチを削除 (未マージなら残す)
wt remove -f AA       # 未コミットの変更ごと削除
wt cleanup AA         # 「残す / 削除」をセレクタで選んで後始末
wt include <path>     # 既存 worktree へ .worktreeinclude を手動展開
```

`wt remove` は未コミットの変更 (未追跡ファイル含む) があると削除せずに終了します。エージェントが作業したあとの worktree はたいてい変更が残っているため、破棄してよい場合は `-f` を付けてください。

コミット済みの内容は `-f` でも失われません。worktree は消えますが、未マージのブランチ (`worktree-AA`) はそのまま残るので、不要なら `git branch -D worktree-AA` で削除します。

## スキル / カスタムコマンドの引き継ぎ

git worktree には **git 管理下のファイルしか入りません**。プロジェクトのスキルを `.gemini/skills/` などに置いたまま `.gitignore` していると、worktree 側にはそれが存在せず `/` を押してもユーザースコープ (`~/.gemini/skills`) のものしか出てきません。

そのため worktree の新規作成時に、下記のディレクトリにある gitignore 済みファイルを既定でコピーします。

| エージェント | コピー対象 |
|---|---|
| Antigravity (`agy`) / Gemini CLI | `.agents/skills/**`, `.agents/commands/**`, `.agent/skills/**`, `.gemini/skills/**`, `.gemini/commands/**` |
| Claude Code | `.claude/skills/**`, `.claude/commands/**`, `.claude/agents/**` |
| Codex | `.codex/prompts/**` |

`gemini skills link` が張ったシンボリックリンクは実体をコピーします。Gemini CLI / Antigravity はスキルのシンボリックリンクを辿らないため ([gemini-cli#16247](https://github.com/google-gemini/gemini-cli/issues/16247), [vercel-labs/skills#633](https://github.com/vercel-labs/skills/issues/633))、リンクのまま複製しても認識されないからです。スキルを git 管理下に置いている場合は worktree に元から入るので、この処理は何もしません。

コピーは新規作成時だけです。作成済みの worktree に後から反映するには `wt include <path>` を実行してください。既定のコピーを止めるには `WT_INCLUDE_AGENT_ASSETS=0` を設定します。

上記以外 (`.gemini/extensions/` など) を持ち込みたい場合は `.worktreeinclude` に追記してください。

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
| `WT_INCLUDE_AGENT_ASSETS` | `1` | gitignore 済みのスキル / カスタムコマンドを worktree へコピーするか (`0` で無効) |
| `WT_ON_EXIT` | `ask` | エージェント終了時の worktree の扱い。`ask`: 残す/削除を矢印キーのセレクタで選択 / `keep`: 常に残す / `remove`: 常に削除。削除する場合は未コミットの変更ごと削除します |

配置先の既定値はラップするコマンドごとに異なります。優先順位は `WT_ROOT_DIR_<CMD>` > `WT_ROOT_DIR` > 既定値です。

| コマンド | 既定の配置先 |
|---|---|
| `agy` (antigravity) | `.gemini/worktree` |
| `codex` | `.codex/worktree` |
| その他のラップコマンド | `.<コマンド名>/worktree` |
| `wt` 単体 | `.claude/worktrees` |

使用する配置先 (`.gemini/worktree/` など) は `.gitignore` に追加してください。

## 既知の制限 (agy / Antigravity CLI)

**agy は git worktree から起動するとプロジェクトをワークスペースとして認識しません** ([antigravity-cli#253](https://github.com/google-antigravity/antigravity-cli/issues/253), 未修正)。ワークスペースが scratch にフォールバックするため、`/` を押してもプロジェクトのスキルやカスタムコマンドが読み込まれません。agy 側の問題なので agent-worktree では回避できません。

試す価値のある回避策:

- 起動後に `/add-dir .` を実行する (`/add-dir` はスキルとスラッシュコマンドの再検出を伴う)
- `agy --new-project <name>` で worktree をプロジェクトとして登録してから使う

また **agy 1.1.0 未満は `.gemini/worktree/` のようなドット始まりディレクトリ配下でワークスペース初期化に失敗します**。既定の配置先を使うなら 1.1.0 以上が必要です。古いバージョンから動かせない場合は配置先をドット無しにしてください。

```bash
export WT_ROOT_DIR_AGY=worktrees
```

worktree 運用時に踏みやすい他の未修正バグ:

- [antigravity-cli#388](https://github.com/google-antigravity/antigravity-cli/issues/388) 会話を削除すると worktree ごと削除される
- [antigravity-cli#103](https://github.com/google-antigravity/antigravity-cli/issues/103) `~/.agents/skills` のユーザースキルが読み込まれない (`~/.gemini/antigravity-cli/skills/` などへ置くと読まれる)

## ライセンス

MIT
