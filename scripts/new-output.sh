#!/usr/bin/env bash
# アウトプット（ブログ・SNS・共有メモなど）のファイルを 05_outputs/ に作成する
# 使い方: ./scripts/new-output.sh "タイトル"
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

if [ "$#" -lt 1 ]; then
  cat >&2 <<'USAGE'
使い方: ./scripts/new-output.sh "タイトル"
例:     ./scripts/new-output.sh "イシューを立てるだけで会議が早く終わった"
USAGE
  exit 1
fi

title="$1"
slug="$(slugify "$title")"
[ -n "$slug" ] || die "タイトルからファイル名を作れませんでした: $title"

dest="$REPO_ROOT/05_outputs/$(today)_${slug}.md"
[ -e "$dest" ] && die "すでに同名のファイルがあります: ${dest#$REPO_ROOT/}"

render_template "$TEMPLATE_DIR/output.md" "TITLE=$title" > "$dest"

printf 'アウトプットを作成しました: %s\n' "${dest#$REPO_ROOT/}"
cat <<'NEXT'

次にやること:
  1. 「伝えたいこと（1文）」だけ先に書く
  2. 本文は雑でいい。読書ノートの「人に話すなら（30秒）」をコピーして膨らませる
  3. 公開したら published と url を記入し、元になった本のノートの「アウトプット記録」にも1行追加する
NEXT
