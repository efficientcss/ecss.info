#!/bin/zsh

set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
	echo "curl is required" >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	echo "jq is required" >&2
	exit 1
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
	echo "Usage: $0 <playlist-id-or-url> [output-xml]" >&2
	exit 1
fi

if [[ -z "${SPOTIFY_ACCESS_TOKEN:-}" ]]; then
	echo "SPOTIFY_ACCESS_TOKEN is required" >&2
	exit 1
fi

script_dir=${0:A:h}
playlist_input=$1
output_xml=${2:-"$script_dir/spotify-playlist.xml"}
market=${SPOTIFY_MARKET:-CA}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

playlist_id=$playlist_input
if [[ "$playlist_input" == *"open.spotify.com/playlist/"* ]]; then
	playlist_id=${playlist_input%%\?*}
	playlist_id=${playlist_id%/}
	playlist_id=${playlist_id##*/}
fi

api_get() {
	local url=$1
	curl --silent --show-error --fail \
		-H "Authorization: Bearer $SPOTIFY_ACCESS_TOKEN" \
		"$url"
}

xml_escape() {
	printf '%s' "$1" | perl -0pe 's/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g; s/"/&quot;/g; s/'"'"'/&apos;/g;'
}

playlist_meta_path="$tmp_dir/playlist-meta.json"
tracks_path="$tmp_dir/tracks.ndjson"
artist_ids_path="$tmp_dir/artist-ids.txt"
artists_map_path="$tmp_dir/artists-map.json"
artist_genres_tsv_path="$tmp_dir/artist-genres.tsv"

api_get "https://api.spotify.com/v1/playlists/$playlist_id?fields=id,name,external_urls,tracks.total&market=$market" > "$playlist_meta_path"

next_url="https://api.spotify.com/v1/playlists/$playlist_id/items?limit=100&market=$market"
: > "$tracks_path"
: > "$artist_ids_path"

while [[ -n "$next_url" ]]; do
	page_path="$tmp_dir/page.json"
	api_get "$next_url" > "$page_path"

	jq -c '
		.items[]
		| (.item // .track) as $track
		| select($track != null and $track.type == "track")
		| {
			name: $track.name,
			artist: (($track.album.artists[0].name // $track.artists[0].name // "") | tostring),
			artist_id: ($track.album.artists[0].id // $track.artists[0].id // ""),
			artist_url: ($track.album.artists[0].external_urls.spotify // $track.artists[0].external_urls.spotify // ""),
			album: ($track.album.name // ""),
			year: (($track.album.release_date // "") | split("-")[0]),
			location: ($track.album.images[0].url // ""),
			spotify_track_url: ($track.external_urls.spotify // ""),
			spotify_album_url: ($track.album.external_urls.spotify // ""),
			cover_url: ($track.album.images[0].url // "")
		}
	' "$page_path" >> "$tracks_path"

	jq -r '
		.items[]
		| (.item // .track) as $track
		| select($track != null and $track.type == "track")
		| ($track.album.artists[0].id // $track.artists[0].id // empty)
	' "$page_path" >> "$artist_ids_path"

	next_url=$(jq -r '.next // ""' "$page_path")
done

sort -u "$artist_ids_path" | sed '/^$/d' > "$tmp_dir/artist-ids-unique.txt"
: > "$artist_genres_tsv_path"

while IFS= read -r artist_id; do
	[[ -z "$artist_id" ]] && continue
	artist_path="$tmp_dir/artist-$artist_id.json"
	api_get "https://api.spotify.com/v1/artists/$artist_id" > "$artist_path"
	genres=$(jq -r '(.genres // []) | join(", ")' "$artist_path")
	printf '%s\t%s\n' "$artist_id" "$genres" >> "$artist_genres_tsv_path"
done < "$tmp_dir/artist-ids-unique.txt"

jq -Rn '
	reduce inputs as $line ({};
		($line | split("\t")) as $fields
		| . + {
			($fields[0]): ($fields[1] // "")
		}
	)
' < "$artist_genres_tsv_path" > "$artists_map_path"

{
	echo '<?xml version="1.0" encoding="UTF-8"?>'
	echo '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
	echo '<plist version="1.0">'
	echo '<dict>'
	echo $'\t<key>Major Version</key><integer>1</integer>'
	echo $'\t<key>Minor Version</key><integer>1</integer>'
	echo $'\t<key>Date</key><date>'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"$'</date>'
	echo $'\t<key>Application Version</key><string>Spotify Import</string>'
	echo $'\t<key>Features</key><integer>1</integer>'
	echo $'\t<key>Playlist ID</key><string>'"$(xml_escape "$(jq -r '.id' "$playlist_meta_path")")"$'</string>'
	echo $'\t<key>Playlist Name</key><string>'"$(xml_escape "$(jq -r '.name' "$playlist_meta_path")")"$'</string>'
	echo $'\t<key>Playlist URL</key><string>'"$(xml_escape "$(jq -r '.external_urls.spotify // ""' "$playlist_meta_path")")"$'</string>'
	echo $'\t<key>Tracks</key>'
	echo $'\t<dict>'

	index=1
	while IFS= read -r track_json; do
		artist_id=$(jq -r '.artist_id' <<< "$track_json")
		genre=$(jq -r --arg artist_id "$artist_id" '.[$artist_id] // ""' "$artists_map_path")
		track_name=$(jq -r '.name' <<< "$track_json")
		artist_name=$(jq -r '.artist' <<< "$track_json")
		album_name=$(jq -r '.album' <<< "$track_json")
		year=$(jq -r '.year' <<< "$track_json")
		location=$(jq -r '.location' <<< "$track_json")
		cover_url=$(jq -r '.cover_url' <<< "$track_json")
		track_url=$(jq -r '.spotify_track_url' <<< "$track_json")
		album_url=$(jq -r '.spotify_album_url' <<< "$track_json")
		artist_url=$(jq -r '.artist_url' <<< "$track_json")

		echo $'\t\t<key>'"$index"$'</key>'
		echo $'\t\t<dict>'
		echo $'\t\t\t<key>Name</key><string>'"$(xml_escape "$track_name")"$'</string>'
		echo $'\t\t\t<key>Artist</key><string>'"$(xml_escape "$artist_name")"$'</string>'
		echo $'\t\t\t<key>Album</key><string>'"$(xml_escape "$album_name")"$'</string>'
		if [[ -n "$genre" ]]; then
			echo $'\t\t\t<key>Genre</key><string>'"$(xml_escape "$genre")"$'</string>'
		fi
		if [[ "$year" == <-> ]]; then
			echo $'\t\t\t<key>Year</key><integer>'"$year"$'</integer>'
		fi
		echo $'\t\t\t<key>Location</key><string>'"$(xml_escape "$location")"$'</string>'
		if [[ -n "$cover_url" ]]; then
			echo $'\t\t\t<key>Cover URL</key><string>'"$(xml_escape "$cover_url")"$'</string>'
		fi
		if [[ -n "$track_url" ]]; then
			echo $'\t\t\t<key>Spotify Track URL</key><string>'"$(xml_escape "$track_url")"$'</string>'
		fi
		if [[ -n "$album_url" ]]; then
			echo $'\t\t\t<key>Spotify Album URL</key><string>'"$(xml_escape "$album_url")"$'</string>'
		fi
		if [[ -n "$artist_url" ]]; then
			echo $'\t\t\t<key>Spotify Artist URL</key><string>'"$(xml_escape "$artist_url")"$'</string>'
		fi
		echo $'\t\t</dict>'

		index=$((index + 1))
	done < "$tracks_path"

	echo $'\t</dict>'
	echo '</dict>'
	echo '</plist>'
} > "$output_xml"

echo "Wrote $output_xml"
