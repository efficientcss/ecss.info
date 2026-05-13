#!/bin/sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

SRC_DIR="${1:-src/content}"
OUT_FILE="${2:-temp/pages.xml}"

tmp_records="$(mktemp)"
trap 'rm -f "$tmp_records"' EXIT

extract_records "$SRC_DIR" "$tmp_records"

{
	printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
	printf '%s\n' '<pages>'

	sort -r "$tmp_records" | while IFS="$(printf '\t')" read -r pub_date lang page_id page_href_id page_title rss_excerpt; do
		case "$page_href_id" in
			index|*/index)
				continue
				;;
		esac
		href="$(build_href "$lang" "$page_href_id")"
		printf '  <page lang="%s" id="%s" date="%s">\n' \
			"$(xml_escape "$lang")" \
			"$(xml_escape "$page_id")" \
			"$(xml_escape "$pub_date")"
		printf '    <title>%s</title>\n' "$(xml_escape "$page_title")"
		if [ -n "$rss_excerpt" ]; then
			printf '    <excerpt>%s</excerpt>\n' "$(xml_escape "$rss_excerpt")"
		fi
		printf '    <href>%s</href>\n' "$(xml_escape "$href")"
		printf '%s\n' '  </page>'
	done

	printf '%s\n' '</pages>'
} > "$OUT_FILE"
