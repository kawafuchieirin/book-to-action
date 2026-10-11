#!/usr/bin/env bash
# 月次振り返りファイルを 06_reviews/ に作成する
# 使い方: ./scripts/new-review.sh [YYYY-MM]   （省略時は今月）
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

month="${1:-$(date +%Y-%m)}"
case "$month" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]) ;;
  *) die "月の指定は YYYY-MM 形式で渡してください（例: 2026-10）: $month" ;;
esac

# その月に finished が入ったノートを数える
finished_count=0
finished_list=""
year="${month%%-*}"
notes_dir="$REPO_ROOT/03_notes/$year"
if [ -d "$notes_dir" ]; then
  while IFS= read -r note; do
    [ -n "$note" ] || continue
    case "$(read_frontmatter "$note" finished)" in
      "$month"-*)
        finished_count=$((finished_count + 1))
        title="$(read_frontmatter "$note" title)"
        finished_list="${finished_list}  - ${title:-$(basename "$note" .md)}
"
        ;;
    esac
  done <<EOF
$(find "$notes_dir" -type f -name '*.md' | sort)
EOF
fi

dest="$REPO_ROOT/06_reviews/${month}.md"
if [ -e "$dest" ]; then
  printf '既存の振り返りを開いてください: %s\n' "${dest#$REPO_ROOT/}"
else
  render_template "$TEMPLATE_DIR/monthly-review.md" \
    "MONTH=$month" "FINISHED_COUNT=$finished_count" > "$dest"
  printf '振り返りを作成しました: %s\n' "${dest#$REPO_ROOT/}"
fi

printf '\n%s の読了: %d 冊\n' "$month" "$finished_count"
[ -n "$finished_list" ] && printf '%s' "$finished_list"
cat <<'NEXT'

次にやること:
  1. 04_actions/action-tracker.md を開き、「実践中」を「定着」か「やめた」に動かす
  2. 続かなかった行動は、理由とハードルの下げ方を書く（やめるのは失敗ではない）
  3. 来月読む本を 01_want-to-read/want-to-read.md から1〜3冊選ぶ
NEXT
