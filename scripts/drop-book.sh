#!/usr/bin/env bash
# 本を読むのをやめる。理由を必ず残す
# 使い方:
#   ./scripts/drop-book.sh 02_reading/本のタイトル.md "理由"   読書中の本をやめる
#   ./scripts/drop-book.sh 3 "理由"                            読む前（Issueのみ）にやめる
#
# やめるのは失敗ではない。理由が残っていれば、自分の傾向を知るデータになる。
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
  cat >&2 <<'USAGE'
使い方:
  ./scripts/drop-book.sh <ノートのパス> "理由"
  ./scripts/drop-book.sh <Issue番号> "理由"

例:
  ./scripts/drop-book.sh "02_reading/イシューからはじめよ.md" "期待していた内容と違った"
  ./scripts/drop-book.sh 3 "先に別の本を読むことにした"
USAGE
  exit 1
}

[ "$#" -ge 2 ] || usage
target="$1"
reason="$2"
[ -n "$reason" ] || die "理由は必須です。あとで振り返るときに効きます"

dropped="$(today)"
issue_number=""
note=""

case "$target" in
  ''|*[!0-9]*)
    [ -f "$target" ] || die "ファイルが見つかりません: $target"
    note="$target"
    issue_number="$(note_issue_number "$note")"
    ;;
  *)
    issue_number="$target"
    ;;
esac

# --- ノートがある場合: statusをdroppedにし、理由を残して 03_notes へ移す ---
if [ -n "$note" ]; then
  update_frontmatter "$note" "status" "dropped"
  update_frontmatter "$note" "finished" "$dropped"

  cat >> "$note" <<EOF

---

## やめた理由（${dropped}）

$reason
EOF

  year="${dropped%%-*}"
  dest_dir="$REPO_ROOT/03_notes/$year"
  mkdir -p "$dest_dir"
  dest="$dest_dir/$(basename "$note")"
  [ -e "$dest" ] && die "移動先にすでに同名のノートがあります: ${dest#$REPO_ROOT/}"
  move_file "$note" "$dest"
  printf 'やめた記録を残しました: %s\n' "${dest#$REPO_ROOT/}"
fi

# --- Issueがある場合: 「🛑 辞めた」にして理由を残してcloseする ---
if [ -n "$issue_number" ]; then
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    set_status_label "$issue_number" "🛑 辞めた" || true
    gh issue close "$issue_number" --comment "読むのをやめました（${dropped}）

**理由**: $reason" >/dev/null
    printf 'Issue #%s を「🛑 辞めた」にしてcloseしました\n' "$issue_number"
  else
    printf '※ ghが使えないため Issue #%s は手で閉じてください\n' "$issue_number"
  fi
fi

cat <<'NEXT'

次にやること:
  - やめた理由は月次振り返り（06_reviews）の「やめた本」に効いてくる
  - 同じ理由で何度もやめているなら、本の選び方を変えるサイン
NEXT
