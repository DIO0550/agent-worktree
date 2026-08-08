# agent-worktree シェルラッパー (bash / zsh 共用, source して使う)
#
# WT_WRAP_COMMANDS に列挙したコマンドをシェル関数でラップし、
# -w / --worktree オプションを横取りして worktree 内で起動する。
#
#   codex -w AA          → worktree "AA" を解決 (無ければ作成) してその中で codex 起動
#   codex -w             → セレクタで worktree を選択 (新規作成も可)
#   codex -w AA --model x → -w AA 以外の引数はそのまま codex へ渡す
#   codex (フラグ無し)    → 通常どおり起動
#
# 環境変数:
#   WT_WRAP_COMMANDS   ラップするコマンド (空白区切り, 既定: "codex agy opencode cursor-agent")
#   WT_ROOT_DIR        worktree 配置先の全コマンド共通の上書き
#   WT_ROOT_DIR_<CMD>  コマンド別の配置先上書き (例: WT_ROOT_DIR_CODEX)
#   WT_ON_EXIT         エージェント終了時の worktree の扱い
#                      ask (既定): 残す/削除をセレクタで選択 / keep: 常に残す / remove: 常に削除
#                      削除する場合は未コミットの変更ごと削除する
#
# 配置先の既定値はコマンドごとに異なる:
#   agy          → .gemini/worktree
#   cursor-agent → .cursor/worktree
#   codex        → .codex/worktree
#   opencode     → .opencode/worktree
#   それ以外      → .<コマンド名>/worktree

: "${WT_WRAP_COMMANDS:=codex agy opencode cursor-agent}"

# このファイル自身の場所から bin/wt を特定
if [ -n "${BASH_SOURCE:-}" ]; then
  _WT_WRAP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
else
  _WT_WRAP_DIR=$(cd "$(dirname "${(%):-%N}")" && pwd)   # zsh
fi
_WT_BIN="$_WT_WRAP_DIR/../bin/wt"

# コマンド名 → worktree 配置先
# 優先順位: WT_ROOT_DIR_<CMD> > WT_ROOT_DIR > コマンド別既定値
_wt_root_dir_for() {
  local cmd=$1 var val
  var="WT_ROOT_DIR_$(printf '%s' "$cmd" | tr 'a-z-' 'A-Z_')"
  eval "val=\${$var:-}"
  if [ -n "$val" ]; then
    printf '%s\n' "$val"
  elif [ -n "${WT_ROOT_DIR:-}" ]; then
    printf '%s\n' "$WT_ROOT_DIR"
  else
    # 設定ディレクトリ名がコマンド名と一致しないものだけ個別に持つ
    case "$cmd" in
      agy)          printf '.gemini/worktree\n' ;;
      cursor-agent) printf '.cursor/worktree\n' ;;
      *)            printf '.%s/worktree\n' "$cmd" ;;
    esac
  fi
}

# 共通処理: $1=実コマンド名, 以降=ユーザ引数
_wt_run() {
  local cmd=$1; shift
  local -a passthru=()
  local wt_name='' wt_mode=0 arg

  # -w / --worktree を1回だけ横取りし、残りはパススルー
  while [ $# -gt 0 ]; do
    arg=$1
    case "$arg" in
      -w|--worktree)
        wt_mode=1
        # 次の引数がオプションでなければ worktree 名として消費
        if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then
          wt_name=$2; shift
        fi
        ;;
      --worktree=*)
        wt_mode=1
        wt_name=${arg#--worktree=}
        ;;
      *)
        passthru+=("$arg")
        ;;
    esac
    shift
  done

  if [ "$wt_mode" -eq 0 ]; then
    command "$cmd" "${passthru[@]}"
    return
  fi

  # 注意: zsh では小文字 path が PATH 連動の特殊配列のため使わない
  local wt_dir wt_root
  wt_root=$(_wt_root_dir_for "$cmd")
  if [ -n "$wt_name" ]; then
    wt_dir=$(WT_ROOT_DIR="$wt_root" "$_WT_BIN" resolve "$wt_name") || return 1
  else
    wt_dir=$(WT_ROOT_DIR="$wt_root" "$_WT_BIN" select) || return 1
  fi

  printf 'wt: %s で %s を起動します\n' "$wt_dir" "$cmd" >&2
  ( cd "$wt_dir" && command "$cmd" "${passthru[@]}" )
  local status=$?
  _wt_on_exit "$wt_root" "$wt_dir"
  return $status
}

# エージェント終了後の worktree の後始末 (Claude Code の終了時プロンプト相当)
# $1=WT_ROOT_DIR, $2=worktree パス
#
# エージェントは worktree の中で作業するので終了時はほぼ必ず未コミットの
# 変更が残る。素の `git worktree remove` はそれを理由に失敗するため、
# 「削除」を選んだときは変更ごと消す (= --force) 前提で扱う。
_wt_on_exit() {
  local wt_root=$1 wt_dir=$2
  local name=${wt_dir##*/}
  [ -d "$wt_dir" ] || return 0

  case "${WT_ON_EXIT:-ask}" in
    keep) return 0 ;;
    remove)
      WT_ROOT_DIR="$wt_root" "$_WT_BIN" remove --force "$name" \
        || printf 'wt: 削除に失敗したため worktree を残しました: %s\n' "$wt_dir" >&2
      return 0
      ;;
  esac

  # 「残す / 削除」のセレクタ表示と削除は wt 側に任せる
  # (対話できない環境ではそのまま残る)
  WT_ROOT_DIR="$wt_root" "$_WT_BIN" cleanup "$name" \
    || printf 'wt: 削除に失敗したため worktree を残しました: %s\n' "$wt_dir" >&2
}

# WT_WRAP_COMMANDS の各コマンドに対して同名のシェル関数を生成
_wt_define_wrappers() {
  local c
  for c in $WT_WRAP_COMMANDS; do
    eval "${c}() { _wt_run ${c} \"\$@\"; }"
  done
}
_wt_define_wrappers
