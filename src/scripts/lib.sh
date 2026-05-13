#!/bin/sh

DEFAULT_LANG="${DEFAULT_LANG:-fr}"
LANG_PREFIX_MODE="${LANG_PREFIX_MODE:-all}"

get_site_url() {
	cname_file="${1:-CNAME}"
	if [ ! -f "$cname_file" ] && [ -f "CNAME" ]; then
		cname_file="CNAME"
	fi
	if [ -f "$cname_file" ]; then
		cname="$(sed -n '1p' "$cname_file" | tr -d '\r')"
		printf "https://%s" "$cname"
	else
		printf "%s" "http://localhost"
	fi
}

xml_escape() {
	printf '%s' "$1" | sed \
		-e 's/&/&amp;/g' \
		-e 's/</&lt;/g' \
		-e 's/>/&gt;/g' \
		-e 's/"/&quot;/g' \
		-e "s/'/&apos;/g"
}

rfc822_date() {
	iso_date="$1"
	if date -j -f "%Y-%m-%d" "$iso_date" "+%a, %d %b %Y 00:00:00 %z" >/dev/null 2>&1; then
		date -j -f "%Y-%m-%d" "$iso_date" "+%a, %d %b %Y 00:00:00 %z"
	else
		date -d "$iso_date" "+%a, %d %b %Y 00:00:00 %z"
	fi
}

strip_tags() {
	printf '%s' "$1" | sed -e 's/<[^>]*>//g' -e 's/[[:space:]]\{1,\}/ /g' -e 's/^ //;s/ $//'
}

extract_first_paragraph() {
	awk '
		BEGIN { in_p = 0; text = "" }
		/<p[ >]/ { in_p = 1 }
		{
			if (in_p) {
				text = text $0 " "
				if ($0 ~ /<\/p>/) {
					print text
					exit
				}
			}
		}
	' "$1"
}

build_url() {
	site_url="$1"
	lang="$2"
	page_id="$3"
	href="$(build_href "$lang" "$page_id")"
	printf "%s/%s" "${site_url%/}" "${href#/}"
}

should_prefix_lang() {
	lang="$1"
	case "$LANG_PREFIX_MODE" in
		all) return 0 ;;
		default)
			if [ "$lang" = "$DEFAULT_LANG" ]; then
				return 1
			fi
			return 0
			;;
		none) return 1 ;;
		*) return 0 ;;
	esac
}

build_href() {
	lang="$1"
	page_id="$2"
	if should_prefix_lang "$lang"; then
		printf "/%s/%s" "$lang" "$page_id"
	else
		printf "/%s" "$page_id"
	fi
}

extract_records() {
	src_dir="$1"
	out_file="$2"
	: > "$out_file"

	find "$src_dir" -type f -name "*.txt" | while read -r txt_file; do
		relative_path="${txt_file#$src_dir/}"
		lang="$(printf '%s' "$relative_path" | awk -F/ '{print $1}')"
		page_path="${relative_path#*/}"
		default_id="$(basename "$txt_file" .txt)"
		page_href_id="${page_path%.txt}"

		page_id="$(sed -n 's/.*page-id="\([^"]*\)".*/\1/p' "$txt_file" | head -n 1)"
		page_title="$(sed -n 's/.*page-title="\([^"]*\)".*/\1/p' "$txt_file" | head -n 1)"
		pub_date="$(sed -n 's/.*pub-date="\([^"]*\)".*/\1/p' "$txt_file" | head -n 1)"
		rss_excerpt="$(sed -n 's/.*rss-excerpt="\([^"]*\)".*/\1/p' "$txt_file" | head -n 1)"

		if [ -z "$page_id" ]; then
			page_id="$default_id"
		fi
		if printf '%s' "$page_id" | grep -q '/'; then
			page_href_id="$page_id"
		fi
		if [ -z "$page_title" ]; then
			page_title="$page_id"
		fi
		if [ -z "$pub_date" ]; then
			pub_date="$(date +%F)"
		fi
		if [ -z "$rss_excerpt" ]; then
			first_para="$(extract_first_paragraph "$txt_file")"
			rss_excerpt="$(strip_tags "$first_para")"
		fi

		printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$pub_date" "$lang" "$page_id" "$page_href_id" "$page_title" "$rss_excerpt" >> "$out_file"
	done
}
