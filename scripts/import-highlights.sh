#!/usr/bin/env bash
# Kindleのハイライトを読書ノートの「読書メモ」表に取り込む
# 使い方:
#   ./scripts/import-highlights.sh <ノートのパス> <エクスポートファイル> [--dry-run]
#
# エクスポートの取り方:
#   1. read.amazon.co.jp/notebook を開き、本を選んで「エクスポート」
#   2. またはKindleアプリの「ハイライトをエクスポート」でメール送信
#   3. またはKindle端末をUSB接続し documents/My Clippings.txt をコピー
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

if [ "$#" -lt 2 ]; then
  cat >&2 <<'USAGE'
使い方: ./scripts/import-highlights.sh <ノートのパス> <エクスポートファイル> [--dry-run]

例:
  ./scripts/import-highlights.sh "02_reading/ブラウザのしくみ.md" ~/Downloads/Notebook.html
  ./scripts/import-highlights.sh "02_reading/ブラウザのしくみ.md" /Volumes/Kindle/documents/My\ Clippings.txt --dry-run
USAGE
  exit 1
fi

command -v python3 >/dev/null 2>&1 \
  || die "python3 が必要です。mise install で用意できます（.mise.toml に宣言済み）"

python3 "$REPO_ROOT/scripts/lib/import_highlights.py" "$@"

cat <<'NEXT'

次にやること:
  1. 「自分の反応（→ だから何？）」を埋める（引用だけでは行動に変わらない）
  2. 心に残った引用を「人に話すなら（30秒）」に書き直す
NEXT
