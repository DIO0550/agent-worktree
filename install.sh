#!/usr/bin/env bash
# agent-worktree インストーラ
#
# 使い方:
#   ./install.sh          # $SHELL から bash / zsh を自動判定
#   ./install.sh bash     # ~/.bashrc に追記
#   ./install.sh zsh      # ~/.zshrc に追記
#
# rc ファイルにはマーカー付きブロックを追記する (再実行時は置き換え):
#   # >>> agent-worktree >>>
#   ...
#   # <<< agent-worktree <<<
set -euo pipefail

MARKER_BEGIN='# >>> agent-worktree >>>'
MARKER_END='# <<< agent-worktree <<<'

REPO_DIR=$(cd "$(dirname "$0")" && pwd)

shell_kind=${1:-}
if [ -z "$shell_kind" ]; then
  case "${SHELL:-}" in
    */zsh)  shell_kind=zsh ;;
    */bash) shell_kind=bash ;;
    *) echo "シェルを判定できません。./install.sh bash か ./install.sh zsh を指定してください" >&2; exit 1 ;;
  esac
fi

case "$shell_kind" in
  bash) rc="$HOME/.bashrc" ;;
  zsh)  rc="$HOME/.zshrc" ;;
  *) echo "対応シェルは bash / zsh のみです: $shell_kind" >&2; exit 1 ;;
esac

block=$(cat <<EOF
$MARKER_BEGIN
# agent-worktree: CLI エージェントを git worktree 内で起動するラッパー
# ラップ対象は WT_WRAP_COMMANDS で変更可能 (例: export WT_WRAP_COMMANDS="codex agy claude")
export PATH="\$PATH:$REPO_DIR/bin"
source "$REPO_DIR/shell/wt-wrap.sh"
$MARKER_END
EOF
)

touch "$rc"

if grep -qF "$MARKER_BEGIN" "$rc"; then
  # 既存ブロックを置き換え (再インストール / リポジトリ移動に対応)
  tmp=$(mktemp)
  awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
    $0 == b {skip=1; next}
    $0 == e {skip=0; next}
    !skip
  ' "$rc" > "$tmp"
  mv "$tmp" "$rc"
  echo "既存の agent-worktree ブロックを更新します: $rc"
else
  echo "agent-worktree ブロックを追記します: $rc"
fi

printf '\n%s\n' "$block" >> "$rc"

echo "完了しました。反映するには次を実行してください:"
echo "  source $rc"
