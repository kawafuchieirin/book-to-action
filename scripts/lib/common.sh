#!/usr/bin/env bash
# 各スクリプトから読み込む共通処理

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/templates"

die() {
  printf 'エラー: %s\n' "$1" >&2
  exit 1
}

today() { date +%Y-%m-%d; }

# ファイル名に使えない文字を除き、空白を - に置き換える（日本語はそのまま残す）
slugify() {
  printf '%s' "$1" \
    | tr '/\\:*?"<>|' '-' \
    | tr -s '[:space:]' '-' \
    | sed -e 's/^-*//' -e 's/-*$//'
}

# テンプレートの {{KEY}} を値に置き換えて標準出力へ
# 使い方: render_template <テンプレートのパス> KEY=値 ...
render_template() {
  local tpl="$1"; shift
  [ -f "$tpl" ] || die "テンプレートが見つかりません: $tpl"

  local content pair key value
  content="$(cat "$tpl")"
  for pair in "$@"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    content="${content//\{\{$key\}\}/$value}"
  done
  printf '%s\n' "$content"
}

# フロントマター内の key を value に書き換える（無ければ追記）
# 使い方: update_frontmatter <ファイル> <key> <value>
update_frontmatter() {
  local file="$1" key="$2" value="$3" tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    NR == 1 && $0 == "---" { in_fm = 1; print; next }
    in_fm && $0 == "---" {
      in_fm = 0
      if (!done) { print key ": " value; done = 1 }
      print; next
    }
    in_fm && index($0, key ":") == 1 { print key ": " value; done = 1; next }
    { print }
  ' "$file" > "$tmp" || { rm -f "$tmp"; die "フロントマターの更新に失敗しました: $file"; }
  mv "$tmp" "$file"
}

# フロントマターから値を取り出す（見つからなければ空文字）
read_frontmatter() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { exit }
    in_fm && index($0, key ":") == 1 {
      sub(/^[^:]*:[[:space:]]*/, "")
      sub(/[[:space:]]*#.*$/, "")
      gsub(/^"|"$/, "")
      print; exit
    }
  ' "$file"
}

# git 管理下なら git mv、そうでなければ mv
move_file() {
  local src="$1" dest="$2"
  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
     && git -C "$REPO_ROOT" ls-files --error-unmatch "$src" >/dev/null 2>&1; then
    git -C "$REPO_ROOT" mv "$src" "$dest"
  else
    mv "$src" "$dest"
  fi
}
