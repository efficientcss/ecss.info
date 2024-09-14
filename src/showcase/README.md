# ECSS Showcase : Playlist

## Copy structure folders with image

```
# Variables pour les chemins source et destination
source_path="chemin_source"
destination_path="chemin_destination"

# Créer la structure de dossiers avec seulement les dossiers contenant des fichiers JPG
find "$source_path" -type f -name "*.jpg" | while read -r filepath; do
    # Extraire le répertoire contenant le fichier
    dir=$(dirname "$filepath")
    # Créer le répertoire correspondant dans le chemin de destination
    mkdir -p "$destination_path/$dir"
    # Copier le fichier vers le chemin de destination avec gcp
    gcp "$filepath" "$destination_path/$dir"
done

# Supprimer les dossiers vides
find "$destination_path" -type d -empty -delete
```

## Prepare playlist XML

```
 gsed -i -e '/<key>Track ID<\/key>/d' -e '/<key>Track Number<\/key>/d' -e '/<key>Track Count<\/key>/d' -e '/<key>Total Time<\/key>/d' -e '/<key>Size<\/key>/d' -e '/<key>Date Modified<\/key>/d' -e '/<key>Date Added<\/key>/d' -e '/<key>Bit Rate<\/key>/d' -e '/<key>Sample Rate<\/key>/d' -e '/<key>Play Count<\/key>/d' -e '/<key>Play Date<\/key>/d' -e '/<key>Play Date UTC<\/key>/d' -e '/<key>Skip Count<\/key>/d' -e '/<key>Skip Date<\/key>/d' -e '/<key>Album Rating<\/key>/d' -e '/<key>Album Rating Computed<\/key>/d' -e '/<key>Normalization<\/key>/d' -e '/<key>Artwork Count<\/key>/d' -e '/<key>Sort Album Artist<\/key>/d' -e '/<key>Sort Artist<\/key>/d' -e '/<key>Track Type<\/key>/d' -e '/<key>File Folder Count<\/key>/d' -e '/<key>Library Folder Count<\/key>/d' -e '/<key>Album Artist<\/key>/d' -e '/<key>Kind<\/key>/d' -e '/<key>Disc Number<\/key>/d' -e '/<key>Disc Count<\/key>/d' -e '/<key>Release Date<\/key>/d' -e '/<key>Sort Album<\/key>/d' -e '/<key>Sort Name<\/key>/d' -e '/<key>Purchased<\/key>/d' -e '/<key>Comments<\/key>/,/<\/string>/d' -e '/<key>Composer<\/key>/d' -e '/<key>Location<\/key>/s|\(<string>\)\(.*\)\(</string>\)|\1\L\2\E\3|' -e '/<key>Location<\/key>/s|\(<string>.*\)/[^/]*\.[a-zA-Z0-9]\{1,5\}</string>|\1</string>|' -e "/<key>Location<\/key>/ {s/%20/_/g;s/%3A/_/g;s/%2F/_/g;s/%40/_/g;s/%3F/_/g;s/%26/_/g;s/%23/_/g;s/%5B/_/g;s/%5D/_/g;s/%[0-9A-Fa-f]\{2\}//g;s/&#[0-9]\{1,4\};//g;s/&[a-zA-Z]\{2,6\};//g;s/\.//g;s/'//g;s/\!//g;s/(//g;s/)//g}" -e '/<key>Location<\/key>/s|file:///users/emma/music/itunes/itunes_media/music/||g' -e '/<array>/,/<\/array>/{ :start; /<\/array>/!{ N; b start }; d }'
```
