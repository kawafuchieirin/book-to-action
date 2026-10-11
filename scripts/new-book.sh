#!/usr/bin/env bash
# 読み始める本のノートを 02_reading/ に作成する
# 使い方:
#   ./scripts/new-book.sh "タイトル" "著者"      手で指定する
#   ./scripts/new-book.sh --issue <Issue番号>     読みたい本Issueから作る（Issueはcloseされる）
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
  cat >&2 <<'USAGE'
使い方:
  ./scripts/new-book.sh "タイトル" "著者"
  ./scripts/new-book.sh --issue <Issue番号>

例:
  ./scripts/new-book.sh "イシューからはじめよ" "安宅和人"
  ./scripts/new-book.sh --issue 1
USAGE
  exit 1
}

[ "$#" -ge 1 ] || usage

issue_number=""
title=""
author=""
motivation=""

if [ "$1" = "--issue" ]; then
  [ "$#" -ge 2 ] || usage
  require_gh
  issue_number="$2"
  case "$issue_number" in
    ''|*[!0-9]*) die "Issue番号は数字で指定してください: $issue_number" ;;
  esac

  issue_title="$(gh issue view "$issue_number" --json title --jq .title)" \
    || die "Issue #$issue_number を取得できませんでした"
  issue_body="$(gh issue view "$issue_number" --json body --jq .body)"

  title="$(strip_title_prefix "$issue_title")"
  author="$(issue_section "$issue_body" "著者" | head -1)"
  motivation="$(issue_section "$issue_body" "きっかけ・解決したいこと" | tr '\n' ' ' | sed -e 's/[[:space:]]*$//')"
  [ -n "$title" ] || die "Issue #$issue_number からタイトルを取得できませんでした"
else
  title="$1"
  author="${2:-}"
fi

slug="$(slugify "$title")"
[ -n "$slug" ] || die "タイトルからファイル名を作れませんでした: $title"

dest="$REPO_ROOT/02_reading/${slug}.md"
[ -e "$dest" ] && die "すでに同名のノートがあります: ${dest#$REPO_ROOT/}"

render_template "$TEMPLATE_DIR/book-note.md" \
  "TITLE=$title" "AUTHOR=$author" "DATE=$(today)" "MOTIVATION=$motivation" \
  | sed -e 's/[[:space:]]*$//' > "$dest"

if [ -n "$issue_number" ]; then
  update_frontmatter "$dest" "issue" "#$issue_number"
  gh issue close "$issue_number" \
    --comment "読み始めました。読書ノート: \`${dest#$REPO_ROOT/}\`" >/dev/null
  printf 'Issue #%s をcloseしました\n' "$issue_number"
fi

printf '読書ノートを作成しました: %s\n' "${dest#$REPO_ROOT/}"
cat <<'NEXT'

次にやること:
  1. 「読む前に：なぜ読むのか」を5分で埋める（ここが空だと読んで終わりになる）
  2. 読み終えたら ./scripts/finish-book.sh <ノートのパス>
NEXT
