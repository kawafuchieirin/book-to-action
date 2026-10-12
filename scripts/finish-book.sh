#!/usr/bin/env bash
# 読み終えた本のノートを done にして 03_notes/<年>/ へ移動する
# 使い方: ./scripts/finish-book.sh 02_reading/イシューからはじめよ.md
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

if [ "$#" -lt 1 ]; then
  cat >&2 <<'USAGE'
使い方: ./scripts/finish-book.sh <ノートのパス>
例:     ./scripts/finish-book.sh 02_reading/イシューからはじめよ.md
USAGE
  exit 1
fi

src="$1"
[ -f "$src" ] || die "ファイルが見つかりません: $src"

finished="$(today)"
year="${finished%%-*}"

update_frontmatter "$src" "status" "done"
update_frontmatter "$src" "finished" "$finished"

dest_dir="$REPO_ROOT/03_notes/$year"
mkdir -p "$dest_dir"
dest="$dest_dir/$(basename "$src")"
[ -e "$dest" ] && die "移動先にすでに同名のノートがあります: ${dest#$REPO_ROOT/}"

move_file "$src" "$dest"

title="$(read_frontmatter "$dest" title)"
printf '読了にしました: %s（%s）\n' "${title:-$(basename "$dest" .md)}" "$finished"
printf '移動先: %s\n' "${dest#$REPO_ROOT/}"

# 連携しているIssueがあれば「✅ 読了」にしてcloseする
issue_number="$(note_issue_number "$dest")"
if [ -n "$issue_number" ]; then
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    set_status_label "$issue_number" "✅ 読了" || true
    gh issue close "$issue_number" \
      --comment "読了しました（${finished}）。読書ノート: \`${dest#$REPO_ROOT/}\`" >/dev/null
    printf 'Issue #%s を「✅ 読了」にしてcloseしました\n' "$issue_number"
  else
    printf '※ ghが使えないため Issue #%s は手で閉じてください\n' "$issue_number"
  fi
fi
cat <<'NEXT'

次にやること:
  1. 「1文で言うと」と「重要ポイント3つ」を書く
  2. 「変える行動」を1つだけ決めて、04_actions/action-tracker.md の「実践中」に転記する
  3. 「人に話すなら（30秒）」を埋める → そのまま ./scripts/new-output.sh "タイトル" の下書きになる
  4. rating（★1〜5）を記入する
NEXT
