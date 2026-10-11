#!/usr/bin/env bash
# 読み始める本のノートを 02_reading/ に作成する
# 使い方: ./scripts/new-book.sh "タイトル" "著者"
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

if [ "$#" -lt 1 ]; then
  cat >&2 <<'USAGE'
使い方: ./scripts/new-book.sh "タイトル" "著者"
例:     ./scripts/new-book.sh "イシューからはじめよ" "安宅和人"
USAGE
  exit 1
fi

title="$1"
author="${2:-}"
slug="$(slugify "$title")"
[ -n "$slug" ] || die "タイトルからファイル名を作れませんでした: $title"

dest="$REPO_ROOT/02_reading/${slug}.md"
[ -e "$dest" ] && die "すでに同名のノートがあります: ${dest#$REPO_ROOT/}"

render_template "$TEMPLATE_DIR/book-note.md" \
  "TITLE=$title" "AUTHOR=$author" "DATE=$(today)" > "$dest"

printf '読書ノートを作成しました: %s\n' "${dest#$REPO_ROOT/}"
cat <<'NEXT'

次にやること:
  1. 「読む前に：なぜ読むのか」を5分で埋める（ここが空だと読んで終わりになる）
  2. 01_want-to-read/want-to-read.md から、この本の行を削除する
  3. 読み終えたら ./scripts/finish-book.sh <ノートのパス>
NEXT
