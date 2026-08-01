#!/usr/bin/env bash
# agent-worktree アンインストーラ
#
#   curl -fsSL https://raw.githubusercontent.com/dio0550/agent-worktree/main/uninstall.sh | bash
#   ./uninstall.sh
#
# rc ファイルからマーカーブロックを除去し、インストーラが配置したファイルを削除する。
# (クローンしたリポジトリから install.sh を実行していた場合、そのリポジトリには触れない)
set -euo pipefail

MARKER_BEGIN='# >>> agent-worktree >>>'
MARKER_END='# <<< agent-worktree <<<'

INSTALL_HOME=${AGENT_WORKTREE_HOME:-$HOME/.agent-worktree}
STAMP=.agent-worktree-managed

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

# インストーラが自分で作ったディレクトリのみ削除する (目印ファイルで判定)
if [ -f "$INSTALL_HOME/$STAMP" ]; then
  rm -rf "$INSTALL_HOME"
  echo "削除しました: $INSTALL_HOME"
  removed=1
fi

[ "$removed" -eq 1 ] || echo "agent-worktree のインストールは見つかりませんでした"
