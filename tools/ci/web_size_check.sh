#!/usr/bin/env bash
# Checks the web zip against docs/specs/web.md §4.2's budget before it can
# reach itch.io (§4.3, itch.md §9.1). Prints the four numbers either way, one
# line per breach of a hard limit, a warning over the targets. Exit code 0
# means the zip may be uploaded.
#
#   tools/ci/web_size_check.sh dist/Doomsday-<version>-web.zip
#
# MB is 10^6 bytes, as in web.md §4. itch.io also wants `index.html` at the
# root of an HTML upload (web.md §16.1), so that is checked here too.

set -euo pipefail

ZIP="${1:?usage: web_size_check.sh <web zip>}"

MB=1000000
ZIP_TARGET_MB=25
ZIP_HARD_MB=30
EXTRACTED_TARGET_MB=70
EXTRACTED_HARD_MB=80
FILE_HARD_MB=64
FILES_HARD=50

# Bytes as megabytes with two decimals, without floating point in the shell.
mb() {
	printf '%d.%02d' "$(($1 / MB))" "$((($1 % MB) * 100 / MB))"
}

temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
unzip -q "$ZIP" -d "$temp"

zip_bytes="$(wc -c < "$ZIP" | tr -d ' ')"
extracted_bytes=0
largest_bytes=0
largest_name=""
files=0
while IFS= read -r -d '' file; do
	size="$(wc -c < "$file" | tr -d ' ')"
	files=$((files + 1))
	extracted_bytes=$((extracted_bytes + size))
	if [ "$size" -gt "$largest_bytes" ]; then
		largest_bytes="$size"
		largest_name="${file#"$temp"/}"
	fi
done < <(find "$temp" -type f -print0)

echo "web zip:   $(mb "$zip_bytes") MB (target ${ZIP_TARGET_MB}, limit ${ZIP_HARD_MB})"
echo "extracted: $(mb "$extracted_bytes") MB (target ${EXTRACTED_TARGET_MB}, limit ${EXTRACTED_HARD_MB})"
echo "largest:   $(mb "$largest_bytes") MB, ${largest_name} (limit ${FILE_HARD_MB})"
echo "files:     ${files} (limit ${FILES_HARD})"

status=0
if [ "$zip_bytes" -gt $((ZIP_HARD_MB * MB)) ]; then
	echo "FAIL: the web zip is over ${ZIP_HARD_MB} MB"
	status=1
fi
if [ "$extracted_bytes" -gt $((EXTRACTED_HARD_MB * MB)) ]; then
	echo "FAIL: the extracted build is over ${EXTRACTED_HARD_MB} MB"
	status=1
fi
if [ "$largest_bytes" -gt $((FILE_HARD_MB * MB)) ]; then
	echo "FAIL: ${largest_name} is over ${FILE_HARD_MB} MB"
	status=1
fi
if [ "$files" -gt "$FILES_HARD" ]; then
	echo "FAIL: the zip holds more than ${FILES_HARD} files"
	status=1
fi
if [ ! -f "$temp/index.html" ]; then
	echo "FAIL: no index.html at the root of the zip"
	status=1
fi
if [ "$status" -eq 0 ] && [ "$zip_bytes" -gt $((ZIP_TARGET_MB * MB)) ]; then
	echo "warning: the web zip is over the ${ZIP_TARGET_MB} MB target"
fi
if [ "$status" -eq 0 ] && [ "$extracted_bytes" -gt $((EXTRACTED_TARGET_MB * MB)) ]; then
	echo "warning: the extracted build is over the ${EXTRACTED_TARGET_MB} MB target"
fi
exit "$status"
