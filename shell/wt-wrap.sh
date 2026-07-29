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
#   WT_WRAP_COMMANDS  ラップするコマンド (空白区切り, 既定: "codex agy")

: "${WT_WRAP_COMMANDS:=codex agy}"

# このファイル自身の場所から bin/wt を特定
if [ -n "${BASH_SOURCE:-}" ]; then
  _WT_WRAP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
else
  _WT_WRAP_DIR=$(cd "$(dirname "${(%):-%N}")" && pwd)   # zsh
fi
_WT_BIN="$_WT_WRAP_DIR/../bin/wt"

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
  local wt_dir
  if [ -n "$wt_name" ]; then
    wt_dir=$("$_WT_BIN" resolve "$wt_name") || return 1
  else
    wt_dir=$("$_WT_BIN" select) || return 1
  fi

  printf 'wt: %s で %s を起動します\n' "$wt_dir" "$cmd" >&2
  ( cd "$wt_dir" && command "$cmd" "${passthru[@]}" )
}

# WT_WRAP_COMMANDS の各コマンドに対して同名のシェル関数を生成
_wt_define_wrappers() {
  local c
  for c in $WT_WRAP_COMMANDS; do
    eval "${c}() { _wt_run ${c} \"\$@\"; }"
  done
}
_wt_define_wrappers
