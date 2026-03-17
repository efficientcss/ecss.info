#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
input_xml=${1:-"$script_dir/tracks.xml"}
template_xsl=${2:-"$script_dir/../templates/music.xsl"}
shell_output=${3:-"$script_dir/tracks.html"}
artists_output=${4:-"$script_dir/artists.html"}
full_output=${5:-"$script_dir/tracks-full.html"}
batch_size=${BATCH_SIZE:-24}

xsltproc \
	--stringparam artist_offset 0 \
	--stringparam max_artists "$batch_size" \
	--stringparam enable_infinite_loading 1 \
	-o "$shell_output" \
	"$template_xsl" \
	"$input_xml"

xsltproc \
	--stringparam artist_offset 0 \
	--stringparam max_artists 999999 \
	--stringparam enable_infinite_loading 0 \
	-o "$artists_output" \
	"$template_xsl" \
	"$input_xml"

xsltproc \
	--stringparam artist_offset 0 \
	--stringparam max_artists 999999 \
	--stringparam enable_infinite_loading 0 \
	--stringparam render_full_page 1 \
	-o "$full_output" \
	"$template_xsl" \
	"$input_xml"
