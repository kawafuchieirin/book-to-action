#!/usr/bin/env bash
# オープンな「読みたい本」Issueから 01_want-to-read/want-to-read.md の表を再生成する
# 使い方: ./scripts/sync-want-to-read.sh
#
# Issueが正（single source of truth）で、このmdは Obsidian / オフラインで読むための一覧。
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
require_gh

LIST_FILE="$REPO_ROOT/01_want-to-read/want-to-read.md"
[ -f "$LIST_FILE" ] || die "一覧ファイルが見つかりません: $LIST_FILE"
grep -q '<!-- BEGIN:issues -->' "$LIST_FILE" \
  || die "$LIST_FILE に <!-- BEGIN:issues --> マーカーがありません"

# Issueフォームの「### 見出し」直下の段落を1行に畳んで取り出す
read -r -d '' JQ_PROG <<'JQ' || true
def clean: if . == "_No response_" then "" else . end;
def cell: gsub("\\|"; "\\\\|");
def sect($h):
  ((.body // "") | gsub("\r"; "") | split("\n")) as $lines
  | ($lines | index("### " + $h)) as $i
  | if $i == null then "" else
      ($lines[$i + 1:]) as $rest
      | ($rest | map(startswith("### ")) | index(true)) as $j
      | (if $j == null then $rest else $rest[0:$j] end)
      | map(select(. != "")) | join(" ") | clean
    end;
def prio: (.labels | map(.name) | map(select(test("^(🔥|🌱|🧊)"))) | first) // "❓ 未設定";
# ステータスはラベルが正。未設定のopen Issueは「読みたい」として扱う
def status: (.labels | map(.name) | map(select(test("^(📋|💰|📚|📖|✅|🛑)"))) | first) // "📋 読みたい";
# スマホから貼ると [ラベル](URL) のマークダウン形式になるため、括弧内のURLを優先して取り出す
def extract_url:
  ([scan("\\]\\((https?://[^)\\s]+)\\)")] | map(.[0]) | first)
  // ([scan("https?://[^\\s)\\]]+")] | first)
  // "";
def rank($p): if ($p | startswith("🔥")) then 0
              elif ($p | startswith("🌱")) then 1
              elif ($p | startswith("🧊")) then 2
              else 3 end;
# 読書中の本は 02_reading のノートが本体なので、読みたい本の一覧には出さない
map(select(status | startswith("📖") | not))
| map({
  prio:   prio,
  status: status,
  title:  (.title | sub("^📚\\s*"; "") | cell),
  genre:  ((sect("ジャンル") | cell) as $g
           | (sect("ジャンル（その他を選んだ場合）") | cell) as $other
           | if ($g | startswith("✏️")) and ($other != "") then $other else $g end),
  motive: (sect("きっかけ・解決したいこと") | cell),
  want:   (sect("手に入れたいもの") | cell),
  url:    (sect("購入リンク") | extract_url | cell),
  created: .createdAt,
  num:    .number
})
| map(.title = (if (.url | test("^https?://")) then "[" + .title + "](" + .url + ")" else .title end))
| sort_by(rank(.prio), .num)
| .[]
| [(.prio | .[0:1]), .status, .title, .genre, .motive, .want, .created, ("#" + (.num | tostring))]
| join("\u001f")
JQ

rows="$(gh issue list --label want-to-read --state open --limit 200 \
          --json number,title,body,labels,createdAt --jq "$JQ_PROG")"

table="$(printf '%s\n' \
  '| 優先度 | 状態 | タイトル | ジャンル | きっかけ・解決したいこと | 手に入れたいもの | 追加日 | Issue |' \
  '| --- | --- | --- | --- | --- | --- | --- | --- |')"

count=0
if [ -n "$rows" ]; then
  # 区切りは US(0x1f)。タブは空白文字扱いで空フィールドが詰められてしまうため使わない
  while IFS=$'\037' read -r prio status title genre motive want created num; do
    [ -n "$title" ] || continue
    date="$(to_local_date "$created")"
    table="${table}
| ${prio} | ${status} | ${title} | ${genre} | ${motive} | ${want} | ${date} | ${num} |"
    count=$((count + 1))
  done <<EOF
$rows
EOF
fi

if [ "$count" -eq 0 ]; then
  table="${table}
| | | _未読の本はありません_ | | | | | |"
fi

# 表は複数行なので awk -v では渡せない（改行を含む値はエラーになる）。一時ファイル経由で挿入する
table_file="$(mktemp)"
tmp="$(mktemp)"
printf '%s\n' "$table" > "$table_file"
awk -v table_file="$table_file" '
  /<!-- BEGIN:issues -->/ {
    print
    while ((getline line < table_file) > 0) print line
    close(table_file)
    skip = 1
    next
  }
  /<!-- END:issues -->/ { skip = 0 }
  !skip { print }
' "$LIST_FILE" > "$tmp" || { rm -f "$tmp" "$table_file"; die "一覧の更新に失敗しました"; }
mv "$tmp" "$LIST_FILE"
rm -f "$table_file"

printf '%s を更新しました（未読の本: %d 冊）\n' "${LIST_FILE#$REPO_ROOT/}" "$count"
cat <<'NEXT'

次にやること:
  - 読み始める本を決めたら ./scripts/new-book.sh --issue <Issue番号>
  - 本を追加したいときは GitHub の Issue から「📚 読みたい本を登録」
NEXT
