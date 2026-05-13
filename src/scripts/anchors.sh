#!/bin/sh

set -e

SRC_DIR="${1:-src/content}"
TEMPLATES_DIR="src/templates"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

if [ ! -d "$SRC_DIR" ]; then
	echo "Le dossier source spécifié n'existe pas: $SRC_DIR" >&2
	exit 1
fi

langs=""
lang_re=""
for d in "$SRC_DIR"/*; do
	if [ -d "$d" ]; then
		lang="$(basename "$d")"
		if [ -z "$langs" ]; then
			langs="$lang"
		else
			langs="$langs,$lang"
		fi
		if [ -z "$lang_re" ]; then
			lang_re="$lang"
		else
			lang_re="$lang_re|$lang"
		fi
	fi
done

if [ -z "$langs" ]; then
	echo "Aucun dossier de langue trouvé dans: $SRC_DIR" >&2
	exit 1
fi

(
	find "$SRC_DIR" -type f -name "*.txt"
	if [ -d "$TEMPLATES_DIR" ]; then
		find "$TEMPLATES_DIR" -type f -name "*.xsl"
	fi
) | while read -r file_path; do
	case "$file_path" in
		"$SRC_DIR"/*)
			relative_path="${file_path#$SRC_DIR/}"
			lang="${relative_path%%/*}"
			;;
		*)
			lang="$DEFAULT_LANG"
			;;
	esac

	tmp_file="$(mktemp)"

	awk -v lang_re="$lang_re" -v cur_lang="$lang" -v mode="$LANG_PREFIX_MODE" -v def_lang="$DEFAULT_LANG" '
		function should_prefix(lang) {
			if (mode == "none") return 0
			if (mode == "all") return 1
			if (mode == "default") return (lang != def_lang)
			return 1
		}
		function rewrite(url, path, seg, rest) {
			path = substr(url, 2)
			split(path, parts, "/")
			seg = parts[1]
			if (seg ~ ("^(" lang_re ")$")) {
				rest = substr(path, length(seg) + 2)
				target_lang = seg
			} else {
				rest = path
				target_lang = cur_lang
			}
			if (should_prefix(target_lang)) return "/" target_lang "/" rest
			return "/" rest
		}
		{
			rest = $0
			out = ""
			while (match(rest, /<a[^>]*href="\/[^"]*"/)) {
				out = out substr(rest, 1, RSTART - 1)
				m = substr(rest, RSTART, RLENGTH)
				url = substr(m, index(m, "href=\"") + 6)
				url = substr(url, 1, length(url) - 1)
				newurl = rewrite(url)
				out = out substr(m, 1, index(m, "href=\"") + 5) newurl "\""
				rest = substr(rest, RSTART + RLENGTH)
			}
			print out rest
		}
	' "$file_path" > "$tmp_file"

	if ! cmp -s "$file_path" "$tmp_file"; then
		mv "$tmp_file" "$file_path"
		echo "✅ Normalisé : $file_path"
	else
		rm -f "$tmp_file"
		echo "⏩ Inchangé : $file_path"
	fi
done
