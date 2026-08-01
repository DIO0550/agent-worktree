#!/usr/bin/env bash
# agent-worktree インストーラ
#
# 使い方 (クローン不要):
#   curl -fsSL https://raw.githubusercontent.com/dio0550/agent-worktree/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- zsh   # シェルを明示指定
#
# 使い方 (リポジトリをクローン済みの場合は手元のファイルをそのまま使う):
#   ./install.sh          # $SHELL から bash / zsh を自動判定
#   ./install.sh bash     # ~/.bashrc に追記
#   ./install.sh zsh      # ~/.zshrc に追記
#
# rc ファイルにはマーカー付きブロックを追記する (再実行時は置き換え):
#   # >>> agent-worktree >>>
#   ...
#   # <<< agent-worktree <<<
#
# 環境変数:
#   AGENT_WORKTREE_HOME  ダウンロード先 (既定: ~/.agent-worktree)
#   AGENT_WORKTREE_REF   取得する git ref (既定: main)
#   AGENT_WORKTREE_REPO  取得元リポジトリ (既定: dio0550/agent-worktree)
set -euo pipefail

MARKER_BEGIN='# >>> agent-worktree >>>'
MARKER_END='# <<< agent-worktree <<<'

REPO_SLUG=${AGENT_WORKTREE_REPO:-dio0550/agent-worktree}
REF=${AGENT_WORKTREE_REF:-main}
BASE_URL=${AGENT_WORKTREE_BASE_URL:-https://raw.githubusercontent.com/$REPO_SLUG/$REF}
INSTALL_HOME=${AGENT_WORKTREE_HOME:-$HOME/.agent-worktree}
# インストーラが作った (= uninstall.sh で消してよい) 目印
STAMP=.agent-worktree-managed
FILES="bin/wt shell/wt-wrap.sh"

die() { printf 'install: %s\n' "$*" >&2; exit 1; }

# ダウンロード用の一時ディレクトリ (途中で失敗しても必ず片付ける)
dl_tmp=''
cleanup() {
  if [ -n "$dl_tmp" ]; then rm -rf "$dl_tmp"; fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# 配置元の決定: 手元にリポジトリがあればそれを使い、無ければダウンロードする
# ---------------------------------------------------------------------------

local_dir=''
if [ -f "${BASH_SOURCE[0]:-}" ]; then
  d=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  if [ -f "$d/bin/wt" ] && [ -f "$d/shell/wt-wrap.sh" ]; then
    local_dir=$d
  fi
fi

fetch() {
  # $1=URL, $2=保存先
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    die "curl または wget が必要です"
  fi
}

download() {
  # 一時ディレクトリに全部落としてから配置する (途中で失敗しても壊さない)
  local f
  dl_tmp=$(mktemp -d) || die "mktemp に失敗しました"

  echo "ダウンロードします: $REPO_SLUG@$REF"
  for f in $FILES; do
    mkdir -p "$dl_tmp/$(dirname "$f")"
    fetch "$BASE_URL/$f" "$dl_tmp/$f" || die "ダウンロードに失敗しました: $BASE_URL/$f"
    [ -s "$dl_tmp/$f" ] || die "取得したファイルが空です: $f"
  done
  chmod +x "$dl_tmp/bin/wt"

  mkdir -p "$INSTALL_HOME"
  touch "$INSTALL_HOME/$STAMP"
  for f in $FILES; do
    mkdir -p "$INSTALL_HOME/$(dirname "$f")"
    mv -f "$dl_tmp/$f" "$INSTALL_HOME/$f"
  done
  echo "配置しました: $INSTALL_HOME"
}

if [ -n "$local_dir" ]; then
  REPO_DIR=$local_dir
  echo "手元のリポジトリを使います: $REPO_DIR"
else
  download
  REPO_DIR=$INSTALL_HOME
fi

# ---------------------------------------------------------------------------
# rc ファイルへの追記
# ---------------------------------------------------------------------------

shell_kind=${1:-}
rcs=()
if [ -n "$shell_kind" ]; then
  case "$shell_kind" in
    bash) rcs=("$HOME/.bashrc") ;;
    zsh)  rcs=("$HOME/.zshrc") ;;
    *) die "対応シェルは bash / zsh のみです: $shell_kind" ;;
  esac
else
  case "${SHELL:-}" in
    */zsh)  rcs=("$HOME/.zshrc") ;;
    */bash) rcs=("$HOME/.bashrc") ;;
    *)
      # $SHELL から判定できない場合は既にある rc すべてに追記する
      if [ -f "$HOME/.zshrc" ]; then rcs+=("$HOME/.zshrc"); fi
      if [ -f "$HOME/.bashrc" ]; then rcs+=("$HOME/.bashrc"); fi
      if [ ${#rcs[@]} -eq 0 ]; then
        die "シェルを判定できません。bash か zsh を引数で指定してください (例: bash -s -- zsh)"
      fi
      ;;
  esac
fi

block=$(cat <<EOF
$MARKER_BEGIN
# agent-worktree: CLI エージェントを git worktree 内で起動するラッパー
# ラップ対象は WT_WRAP_COMMANDS で変更可能 (例: export WT_WRAP_COMMANDS="codex agy claude")
export PATH="\$PATH:$REPO_DIR/bin"
source "$REPO_DIR/shell/wt-wrap.sh"
$MARKER_END
EOF
)

for rc in "${rcs[@]}"; do
  touch "$rc"
  if grep -qF "$MARKER_BEGIN" "$rc"; then
    # 既存ブロックを置き換え (再インストール / 配置先変更に対応)
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
done

echo "完了しました。反映するには次を実行してください:"
for rc in "${rcs[@]}"; do
  echo "  source $rc"
done
