#!/usr/bin/env python3
"""Kindleのハイライトを読書ノートの「読書メモ」表に取り込む。

対応する入力:
  - Kindleアプリ / read.amazon.co.jp/notebook の「エクスポート」で得られるHTML
  - Kindle端末の My Clippings.txt

Kindleの「メモ」は直前のハイライトに紐づくので、「自分の反応」の列に入れる。
同じ引用が既にノートにあれば飛ばすので、読み進めながら何度でも実行できる。
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path

TABLE_HEADER = "| ページ | 引用・要点 | 自分の反応（→ だから何？） |"
EMPTY_ROW = re.compile(r"^\|\s*p\.\s*\|\s*\|\s*\|\s*$")

# 「ハイライト(黄色) - 42ページ・位置No. 123」「Highlight (yellow) - Page 42 · Location 123」など、
# 言語や書籍によって表記が変わるため、種類と数値だけを拾う
NOTE_KINDS = ("メモ", "ノート", "Note")
HIGHLIGHT_KINDS = ("ハイライト", "Highlight")
PAGE_RE = re.compile(r"(?:ページ|[Pp]age)\s*[:：]?\s*(\d+)|(\d+)\s*ページ")
LOCATION_RE = re.compile(r"(?:位置|[Ll]ocation)\s*(?:No\.)?\s*[:：]?\s*(\d+)")


@dataclass
class Entry:
    kind: str  # "highlight" | "note"
    text: str
    page: str = ""
    location: str = ""

    @property
    def label(self) -> str:
        if self.page:
            return f"p.{self.page}"
        if self.location:
            return f"位置{self.location}"
        return "p."


@dataclass
class _HtmlState:
    entries: list[Entry] = field(default_factory=list)
    current_class: str = ""
    heading: str = ""
    buffer: list[str] = field(default_factory=list)


class KindleNotebookParser(HTMLParser):
    """エクスポートHTMLの noteHeading / noteText の組を拾う。"""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.state = _HtmlState()

    def handle_starttag(self, tag, attrs):
        if tag != "div":
            return
        classes = dict(attrs).get("class", "") or ""
        if "noteHeading" in classes:
            self._flush()
            self.state.current_class = "heading"
        elif "noteText" in classes:
            self.state.current_class = "text"
        else:
            self._flush()
            self.state.current_class = ""

    def handle_endtag(self, tag):
        if tag == "div" and self.state.current_class == "text":
            self._flush()

    def handle_data(self, data):
        if self.state.current_class == "heading":
            self.state.heading += data
        elif self.state.current_class == "text":
            self.state.buffer.append(data)

    def _flush(self) -> None:
        text = " ".join("".join(self.state.buffer).split())
        heading = " ".join(self.state.heading.split())
        if text and heading:
            self.state.entries.append(_build_entry(heading, text))
        if self.state.current_class == "text":
            self.state.heading = ""
        self.state.buffer = []
        self.state.current_class = ""


def _build_entry(heading: str, text: str) -> Entry:
    kind = "note" if any(k in heading for k in NOTE_KINDS) else "highlight"
    page = ""
    if m := PAGE_RE.search(heading):
        page = m.group(1) or m.group(2) or ""
    location = m.group(1) if (m := LOCATION_RE.search(heading)) else ""
    return Entry(kind=kind, text=text, page=page, location=location)


def parse_html(source: str) -> list[Entry]:
    parser = KindleNotebookParser()
    parser.feed(source)
    parser._flush()
    return parser.state.entries


def parse_clippings(source: str) -> list[Entry]:
    """My Clippings.txt を読む。1件が「タイトル / 見出し / 空行 / 本文 / ==========」の形。"""
    entries: list[Entry] = []
    for block in source.split("=========="):
        lines = [line.rstrip() for line in block.strip().splitlines()]
        if len(lines) < 3:
            continue
        heading = lines[1].lstrip("- ").strip()
        text = " ".join(" ".join(lines[2:]).split())
        if not text:
            continue
        entries.append(_build_entry(heading, text))
    return entries


def to_rows(entries: list[Entry]) -> list[tuple[str, str, str]]:
    """ハイライトを1行にし、直後のメモを「自分の反応」に寄せる。"""
    rows: list[tuple[str, str, str]] = []
    pending_note = ""
    for entry in reversed(entries):
        if entry.kind == "note":
            # 逆順に見ているので、メモは次に現れるハイライト（本来の直前）のもの
            pending_note = entry.text if not pending_note else f"{entry.text} / {pending_note}"
            continue
        rows.append((entry.label, entry.text, pending_note))
        pending_note = ""
    if pending_note:
        rows.append(("p.", "", pending_note))
    rows.reverse()
    return rows


def escape_cell(text: str) -> str:
    return text.replace("|", "\\|").strip()


def insert_rows(note: str, rows: list[tuple[str, str, str]]) -> tuple[str, int, int]:
    """読書メモ表に行を足す。既にある引用は飛ばす。"""
    lines = note.splitlines()
    try:
        header_at = next(i for i, line in enumerate(lines) if line.strip() == TABLE_HEADER)
    except StopIteration:
        raise SystemExit(
            f"エラー: ノートに読書メモの表が見つかりません。次の見出し行が必要です:\n  {TABLE_HEADER}"
        )

    # 表の範囲（ヘッダ・区切り行のあと、表以外の行が来るまで）
    end = header_at + 2
    while end < len(lines) and lines[end].lstrip().startswith("|"):
        end += 1

    existing = lines[header_at:end]
    body = [line for line in lines[header_at + 2 : end] if not EMPTY_ROW.match(line.strip())]

    added, skipped = [], 0
    for label, quote, reaction in rows:
        cell = escape_cell(quote)
        if cell and any(cell in line for line in existing + added):
            skipped += 1
            continue
        added.append(f"| {label} | {cell} | {escape_cell(reaction)} |")

    if not added:
        return note, 0, skipped

    rebuilt = lines[: header_at + 2] + body + added + lines[end:]
    return "\n".join(rebuilt) + ("\n" if note.endswith("\n") else ""), len(added), skipped


def main() -> int:
    ap = argparse.ArgumentParser(description="Kindleのハイライトを読書ノートに取り込む")
    ap.add_argument("note", type=Path, help="読書ノートのパス")
    ap.add_argument("export", type=Path, help="KindleのエクスポートHTML または My Clippings.txt")
    ap.add_argument("--dry-run", action="store_true", help="書き込まずに結果だけ表示する")
    args = ap.parse_args()

    if not args.note.is_file():
        print(f"エラー: ノートが見つかりません: {args.note}", file=sys.stderr)
        return 1
    if not args.export.is_file():
        print(f"エラー: エクスポートファイルが見つかりません: {args.export}", file=sys.stderr)
        return 1

    source = args.export.read_text(encoding="utf-8", errors="replace")
    is_html = args.export.suffix.lower() in {".html", ".htm"} or "<html" in source[:2048].lower()
    entries = parse_html(source) if is_html else parse_clippings(source)

    if not entries:
        print(
            "ハイライトを読み取れませんでした。"
            f"（{'HTML' if is_html else 'テキスト'}として解析）\n"
            "ファイルの形式が想定と違う可能性があります。",
            file=sys.stderr,
        )
        return 1

    rows = to_rows(entries)
    note_text = args.note.read_text(encoding="utf-8")
    updated, added, skipped = insert_rows(note_text, rows)

    highlights = sum(1 for e in entries if e.kind == "highlight")
    notes = len(entries) - highlights
    print(f"読み取り: ハイライト {highlights} 件 / メモ {notes} 件")

    if args.dry_run:
        print("\n--- 追加される行（--dry-run なので書き込みません） ---")
        for row in rows:
            print(f"| {row[0]} | {escape_cell(row[1])} | {escape_cell(row[2])} |")
        return 0

    if added:
        args.note.write_text(updated, encoding="utf-8")
    print(f"追記: {added} 行 / 既にあったので飛ばした: {skipped} 行")
    return 0


if __name__ == "__main__":
    sys.exit(main())
