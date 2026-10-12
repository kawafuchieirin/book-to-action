#!/usr/bin/env bash
# Issueから「いま何冊抱えているか」を1コマンドで表示する
# 使い方: ./scripts/status.sh [--all] [YYYY-MM]
#
# Issueが正（single source of truth）なので、状況もIssueから集計する。
# ローカルのmdは見ないので、sync していなくても正しい数が出る。
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
require_gh

show_all=0
month="$(date +%Y-%m)"
for arg in "$@"; do
  case "$arg" in
    --all|-a) show_all=1 ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]) month="$arg" ;;
    -h|--help)
      cat <<'USAGE'
使い方: ./scripts/status.sh [--all] [YYYY-MM]

  （引数なし）  冊数のサマリと、読書中・次に読む候補を表示
  --all        未読の本を状態ごとにすべて一覧表示する
  YYYY-MM      読了・やめた冊数を数える月（省略時は今月）
USAGE
      exit 0
      ;;
    *) die "知らないオプションです: ${arg}（./scripts/status.sh --help）" ;;
  esac
done

# 1回のAPI呼び出しでopen/closedをまとめて取る（状態ごとに叩くと遅い）
read -r -d '' JQ_PROG <<'JQ' || true
def labels_of: (.labels | map(.name));
# ステータスはラベルが正。ラベルなしのIssueはopenなら読みたい、closedなら読了として扱う
def status: (labels_of | map(select(test("^(📋|💰|📚|📖|✅|🛑)"))) | first)
            // (if .state == "CLOSED" then "✅ 読了" else "📋 読みたい" end);
def prio: (labels_of | map(select(test("^(🔥|🌱|🧊)"))) | first) // "❓ 未設定";
def rank($s): if   ($s | startswith("📖")) then 0
              elif ($s | startswith("💰")) then 1
              elif ($s | startswith("📚")) then 2
              elif ($s | startswith("📋")) then 3
              else 4 end;
def prio_rank($p): if   ($p | startswith("🔥")) then 0
                   elif ($p | startswith("🌱")) then 1
                   elif ($p | startswith("🧊")) then 2
                   else 3 end;
map({
  status: status,
  prio:   prio,
  title:  (.title | sub("^📚\\s*"; "")),
  num:    .number,
  closed: (.closedAt // ""),
  state:  .state
})
| sort_by(rank(.status), prio_rank(.prio), .num)
| .[]
| [.status, (.prio | .[0:1]), .title, ("#" + (.num | tostring)), .closed, .state]
| join("\u001f")
JQ

# closeした月(YYYY-MM)を返す。closedAtが空なら何も返さない
closed_month() {
  [ -n "${1:-}" ] || return 0
  local date
  date="$(to_local_date "$1")"
  printf '%s' "${date%-*}"
}

# 「  #12 🔥 タイトル」の1行を作る（Issue番号は4桁ぶん空けて揃える）
book_line() {
  printf '  %-5s %s %s\n' "$1" "$2" "$3"
}

rows="$(gh issue list --label want-to-read --state all --limit 300 \
          --json number,title,state,labels,closedAt --jq "$JQ_PROG")"

reading_n=0; bought_n=0; stacked_n=0; want_n=0; done_n=0; dropped_n=0; stale_n=0
reading_list=""; bought_list=""; stacked_list=""; want_list=""; next_list=""; stale_nums=""

# 区切りは US(0x1f)。タブは空白文字扱いで空フィールドが詰められてしまうため使わない
while IFS=$'\037' read -r status prio title num closed state; do
  [ -n "$title" ] || continue

  # ラベルとopen/closedの食い違い（closeし忘れ・リオープン直後など）は、
  # どちらの冊数にも混ぜずに件数だけ報告する
  is_closed_status=0
  case "$status" in "✅ 読了"|"🛑 辞めた") is_closed_status=1 ;; esac
  is_closed_issue=0
  [ "$state" = "CLOSED" ] && is_closed_issue=1
  if [ "$is_closed_issue" -ne "$is_closed_status" ]; then
    stale_n=$((stale_n + 1))
    stale_nums="${stale_nums}${stale_nums:+ }${num}"
    continue
  fi

  case "$status" in
    "📖 読書中")
      reading_n=$((reading_n + 1))
      reading_list="${reading_list}$(book_line "$num" "$prio" "$title")
" ;;
    "💰 購入済み")
      bought_n=$((bought_n + 1))
      bought_list="${bought_list}$(book_line "$num" "$prio" "$title")
" ;;
    "📚 積読")
      stacked_n=$((stacked_n + 1))
      stacked_list="${stacked_list}$(book_line "$num" "$prio" "$title")
" ;;
    "📋 読みたい")
      want_n=$((want_n + 1))
      want_list="${want_list}$(book_line "$num" "$prio" "$title")
" ;;
    "✅ 読了")
      [ "$(closed_month "$closed")" = "$month" ] && done_n=$((done_n + 1)) ;;
    "🛑 辞めた")
      [ "$(closed_month "$closed")" = "$month" ] && dropped_n=$((dropped_n + 1)) ;;
  esac

  # 次に読む候補は「🔥 今すぐ」のまだ読んでいない本
  if [ "$prio" = "🔥" ]; then
    case "$status" in
      "💰 購入済み"|"📚 積読"|"📋 読みたい")
        next_list="${next_list}$(book_line "$num" "${status%% *}" "$title")
" ;;
    esac
  fi
done <<EOF
$rows
EOF

unread_n=$((bought_n + stacked_n + want_n))

printf '📊 いまの状況（%s 時点）\n\n' "$(today)"
printf '  📖 読書中     %2d 冊\n' "$reading_n"
printf '  💰 購入済み   %2d 冊\n' "$bought_n"
printf '  📚 積読       %2d 冊\n' "$stacked_n"
printf '  📋 読みたい   %2d 冊\n' "$want_n"
printf '  ----------------------\n'
printf '  %s の読了  %2d 冊 / やめた %d 冊\n' "$month" "$done_n" "$dropped_n"

if [ -n "$reading_list" ]; then
  printf '\n📖 いま読んでいる本\n%s' "$reading_list"
fi

if [ "$show_all" -eq 1 ]; then
  printf '\n📚 未読の本（%d 冊）\n' "$unread_n"
  if [ "$unread_n" -eq 0 ]; then
    printf '  （ありません）\n'
  else
    [ -n "$bought_list" ]  && printf '\n 💰 購入済み（%d）\n%s' "$bought_n" "$bought_list"
    [ -n "$stacked_list" ] && printf '\n 📚 積読（%d）\n%s' "$stacked_n" "$stacked_list"
    [ -n "$want_list" ]    && printf '\n 📋 読みたい（%d）\n%s' "$want_n" "$want_list"
  fi
elif [ -n "$next_list" ]; then
  printf '\n🔥 次に読む候補（今すぐ）\n%s' "$next_list"
fi

# README「困ったときの目安」に引っかかったものだけ出す
warnings=""
if [ "$reading_n" -gt 3 ]; then
  warnings="${warnings}  - 読書中が${reading_n}冊あります。1冊に絞る（残りは drop-book.sh か 📚 積読 に戻す）
"
fi
if [ "$reading_n" -eq 0 ] && [ "$unread_n" -gt 0 ]; then
  warnings="${warnings}  - 読書中の本がありません。候補から1冊選んで new-book.sh --issue <番号>
"
fi
if [ "$stale_n" -gt 0 ]; then
  warnings="${warnings}  - 状態ラベルとopen/closedが食い違う本が${stale_n}件あります（${stale_nums}）。集計から外しました
"
fi
if [ "$stacked_n" -ge 10 ]; then
  warnings="${warnings}  - 積読が${stacked_n}冊あります。読まないと決めた本は drop-book.sh <番号> \"理由\" で手放す
"
fi
if [ -n "$warnings" ]; then
  printf '\n⚠️ 気になる点\n%s' "$warnings"
fi

cat <<'NEXT'

次にやること:
  - 読み始める   ./scripts/new-book.sh --issue <Issue番号>
  - 一覧を更新   ./scripts/sync-want-to-read.sh
  - 本を追加     GitHubのIssueから「📚 読みたい本を登録」
NEXT
