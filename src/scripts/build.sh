#!/bin/sh

# Vérifier si suffisamment d'arguments sont fournis
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
	echo "Usage: $0 dossier_source dossier_temp dossier_destination [fichier_xslt]"
	exit 1
fi

# Récupérer les arguments
SRC_DIR="$1"    # Dossier contenant les fichiers .txt et .xml d'origine
TEMP_DIR="$2"   # Dossier temporaire où seront placés les HTML intermédiaires
DEST_DIR="$3"   # Dossier final où seront placés les HTML transformés par XSLT
XSLT_FILE="$4"  # Fichier XSLT optionnel
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"
FORCE="${FORCE:-0}"
ENV_MODE="${ENV:-dev}"
if [ -z "${TEMPLATE_OUTPUTS:-}" ]; then
	if [ -n "$XSLT_FILE" ]; then
		TEMPLATE_OUTPUTS="$XSLT_FILE:index.html"
	else
		TEMPLATE_OUTPUTS="src/templates/index.xsl:index.html"
	fi
fi

# Vérifier si le dossier source existe
if [ ! -d "$SRC_DIR" ]; then
	echo "Le dossier source spécifié n'existe pas: $SRC_DIR"
	exit 1
fi

# Déterminer sed in-place (GNU ou BSD)
SED_BIN="sed"
SED_FLAVOR="bsd"
if command -v gsed >/dev/null 2>&1; then
	SED_BIN="gsed"
	SED_FLAVOR="gnu"
elif sed --version >/dev/null 2>&1; then
	SED_FLAVOR="gnu"
fi

sed_inplace() {
	if [ "$SED_FLAVOR" = "gnu" ]; then
		"$SED_BIN" -i "$@"
	else
		"$SED_BIN" -i '' "$@"
	fi
}

# Créer les dossiers TEMP et DEST s'ils n'existent pas
mkdir -p "$TEMP_DIR"
mkdir -p "$DEST_DIR"

# Générer la liste des pages pour XSLT
META_DIR="$TEMP_DIR/.meta"
PAGES_XML="$META_DIR/pages.xml"
mkdir -p "$META_DIR"
sh "$SCRIPT_DIR/pages.sh" "$SRC_DIR" "$PAGES_XML"
PAGES_URI="file://$(cd "$META_DIR" && pwd)/pages.xml"
SITE_URL="$(get_site_url "$DEST_DIR/CNAME")"

# === 1️⃣ Phase 1 : Transformer les fichiers TXT en HTML avec Pandoc ===
echo "📄 Phase 1: Conversion TXT → HTML dans $TEMP_DIR"
find "$SRC_DIR" -type f -name "*.txt" | while read -r txt_file; do
	relative_path="${txt_file#$SRC_DIR/}"
	relative_dir="$(dirname "$relative_path")"
	filename="$(basename "$txt_file" .txt)"
	output_subdir="$TEMP_DIR/$relative_dir"
	output_file="$output_subdir/$filename.html"

	mkdir -p "$output_subdir"

	# MODIFIÉ : ne reconvertir que si nécessaire
	if [ "$FORCE" = "1" ] || [ ! -f "$output_file" ] || [ "$txt_file" -nt "$output_file" ]; then
		pandoc "$txt_file" -o "$output_file" --wrap=none --from=markdown+fenced_divs
		if [ $? -eq 0 ]; then
			echo "✅ TXT → HTML : $txt_file → $output_file"
		else
			echo "❌ Échec de conversion TXT → HTML : $txt_file"
		fi
	else
		echo "⏩ TXT inchangé : $txt_file"
	fi

done

# === 2️⃣ Phase 2 : Insérer le HTML généré dans un modèle XML ===
echo "📄 Phase 2: Génération des fichiers XML avec le contenu HTML"
find "$TEMP_DIR" -type f -name "*.html" | while read -r html_file; do
	relative_path="${html_file#$TEMP_DIR/}"
	relative_dir="$(dirname "$relative_path")"
	filename="$(basename "$html_file" .html)"

	# Déterminer la langue (fr/en) à partir du dossier parent
	if echo "$relative_path" | grep -q "^fr/"; then
		LANG="fr"
	elif echo "$relative_path" | grep -q "^en/"; then
		LANG="en"
	else
		echo "⚠️ Impossible de déterminer la langue pour : $html_file"
		continue
	fi

	# Copier le modèle XML correspondant
	xml_template="src/includes/$LANG.xml"
	xml_output="$TEMP_DIR/$relative_dir/$filename.xml"

	if [ ! -f "$xml_template" ]; then
		echo "❌ Modèle XML introuvable : $xml_template"
		continue
	fi

	mkdir -p "$(dirname "$xml_output")"

	# MODIFIÉ : ne réinsérer que si le HTML ou le modèle est plus récent
	if [ "$FORCE" = "1" ] || [ ! -f "$xml_output" ] || [ "$html_file" -nt "$xml_output" ] || [ "$xml_template" -nt "$xml_output" ] || find src/includes -type f -newer "$xml_output" | grep -q .; then
		cp "$xml_template" "$xml_output"
		sed_inplace "/<root lang=\"$LANG\">/,/<\\/root>/!b;//!d;/<root lang=\"$LANG\">/r $html_file" "$xml_output"
		echo "✅ Insertion : $html_file → $xml_output"
	else
		echo "⏩ Insertion inchangée : $html_file"
	fi
done

# === 3️⃣ Phase 3 : Transformer les fichiers XML avec xsltproc ===
echo "📄 Phase 3: Transformation XML → HTML avec XSLT dans $DEST_DIR"
find "$TEMP_DIR" -type f -name "*.xml" -not -path "$META_DIR/*" | while read -r xml_file; do
	relative_path="${xml_file#$TEMP_DIR/}"
	relative_dir="$(dirname "$relative_path")"
	lang="${relative_path%%/*}"
	rest_path="${relative_path#*/}"
	rest_dir="$(dirname "$rest_path")"
	if [ "$rest_dir" = "." ]; then
		rest_dir=""
	fi

	if should_prefix_lang "$lang"; then
		if [ -n "$rest_dir" ]; then
			output_subdir="$DEST_DIR/$lang/$rest_dir"
		else
			output_subdir="$DEST_DIR/$lang"
		fi
	else
		if [ -n "$rest_dir" ]; then
			output_subdir="$DEST_DIR/$rest_dir"
		else
			output_subdir="$DEST_DIR"
		fi
	fi

	mkdir -p "$output_subdir"

	for template_output in $TEMPLATE_OUTPUTS; do
		template_file="${template_output%%:*}"
		output_name="${template_output#*:}"
		output_file="$output_subdir/$output_name"

		if [ ! -f "$template_file" ]; then
			echo "❌ Template XSLT introuvable : $template_file"
			continue
		fi

		# MODIFIÉ : ne transformer que si le XML ou le XSLT est plus récent
		if [ "$FORCE" = "1" ] || [ ! -f "$output_file" ] || [ "$xml_file" -nt "$output_file" ] || [ "$template_file" -nt "$output_file" ] || find src/includes src/templates -type f -newer "$output_file" | grep -q .; then
			xsltproc --stringparam pages_path "$PAGES_URI" --stringparam site_url "$SITE_URL" --stringparam env "$ENV_MODE" "$template_file" "$xml_file" > "$output_file"
			if [ $? -eq 0 ]; then
				echo "✅ XSLT : $xml_file + $template_file → $output_file"
			else
				echo "❌ Échec XSLT : $xml_file + $template_file"
			fi
		else
			echo "⏩ XSLT inchangé : $output_file"
		fi
	done
done
