#!/usr/bin/env bash
# agent-worktree アンインストーラ: rc ファイルからマーカーブロックを除去する
set -euo pipefail

MARKER_BEGIN='# >>> agent-worktree >>>'
MARKER_END='# <<< agent-worktree <<<'

removed=0
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  grep -qF "$MARKER_BEGIN" "$rc" || continue
  tmp=$(mktemp)
  awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
    $0 == b {skip=1; next}
    $0 == e {skip=0; next}
    !skip
  ' "$rc" > "$tmp"
  mv "$tmp" "$rc"
  echo "削除しました: $rc"
  removed=1
done

[ "$removed" -eq 1 ] || echo "agent-worktree のブロックは見つかりませんでした"
