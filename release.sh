#!/bin/bash

# Copy the current directory to zawarudo
MOD_SRC="."
MOD_DST="zawarudo"
SCRIPT_NAME="$(basename "$0")"
# Remove old zawarudo if it exists
rm -rf "$MOD_DST"
# Copy everything except git-related files and the dest folder itself
mkdir "$MOD_DST"
find "$MOD_SRC" -mindepth 1 \
    -not -path "./$MOD_DST*" \
    -not -path "./.git*" \
    -not -name ".gitignore" \
    -not -name "$SCRIPT_NAME" \
    -exec cp -r --parents "{}" "$MOD_DST" \;
# Edit metadata.xml in the new directory
META="$MOD_DST/metadata.xml"
sed -i 's/ (ZA WARUDO) Dev/ (ZA WARUDO)/' "$META"
sed -i 's|<directory>.*</directory>|<directory>zawarudo</directory>|' "$META"
# Bump version
VERSION_LINE=$(grep '<version>' "$META")
INDENT=$(echo "$VERSION_LINE" | sed -n 's/^\([[:space:]]*\)<version>.*<\/version>/\1/p')
MAJOR=$(echo "$VERSION_LINE" | sed -n 's/.*<version>\([0-9]\+\)\..*<\/version>/\1/p')
MINOR=$(echo "$VERSION_LINE" | sed -n 's/.*<version>[0-9]\+\.\([0-9]\+\)<\/version>/\1/p')
sed -i "s|^[[:space:]]*<version>.*</version>|${INDENT}<version>${MAJOR}.$((MINOR + 1))</version>|" "$META"
