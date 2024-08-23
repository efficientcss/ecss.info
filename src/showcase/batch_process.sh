#!/bin/bash

# Directory containing the folders to be normalized
BASE_DIR="songlist"
# File containing the paths to be normalized
INPUT_FILE="songlist.xml"

# Function to normalize folder names
normalize() {
	echo "$1" | tr ' ' '_' | tr -cd '[:alnum:]_' | tr '[:upper:]' '[:lower:]'
}

# Function to recursively normalize directories
normalize_directories() {
	for dir in "$1"/*/; do
		# Check if it's a directory
		if [ -d "$dir" ]; then
			# Remove trailing slash
			dir=${dir%/}

		# Get the parent directory and the original folder name
		parent_dir=$(dirname "$dir")
		original_folder=$(basename "$dir")
		# Normalize the folder name
		normalized_folder=$(normalize "$original_folder")

		# Rename the folder if the new name is different
		if [ "$original_folder" != "$normalized_folder" ]; then
			mv "$parent_dir/$original_folder" "$parent_dir/$normalized_folder"
			echo "Renamed: $parent_dir/$original_folder -> $parent_dir/$normalized_folder"
		fi

		# Recursively normalize subdirectories
		normalize_directories "$parent_dir/$normalized_folder"
		fi
	done
}

# Function to update paths in the file
update_paths_in_file() {
	while IFS= read -r line; do
		if [[ "$line" == *"<key>Location</key>"* ]]; then
			# Get the directory path and original folder name
			dir_path=$(dirname "$line")
			original_folder=$(basename "$line")
			# Normalize the folder name
			normalized_folder=$(normalize "$original_folder")

		# Update the line in the file with the normalized path
		gsed -i "s|$line|$dir_path/$normalized_folder|g" "$INPUT_FILE"
		fi
	done < "$INPUT_FILE"
}

# Start normalizing directories from the base directory
normalize_directories "$BASE_DIR"

# Update paths in the file after renaming directories
update_paths_in_file
