#!/usr/bin/env bash
set -euo pipefail

content_folder="${1:?content folder is required}"
metadata_file="${2:?workshop metadata file is required}"
preview_file="${3:-}"
expected_workshop_id="${EXPECTED_WORKSHOP_ID:-}"

fail() {
    echo "::error::$1" >&2
    exit 1
}

read_value() {
    local key="$1"
    awk -v key="$key" '
        index($0, key "=") == 1 {
            sub("^" key "=", "")
            sub("\r$", "")
            print
            exit
        }
    ' "$metadata_file"
}

[[ -d "$content_folder" ]] || fail "Missing Workshop content folder: $content_folder"
[[ -f "$metadata_file" ]] || fail "Missing Workshop metadata: $metadata_file"
[[ -n "$(find "$content_folder" -mindepth 1 -print -quit)" ]] ||
    fail "Workshop content folder is empty."

workshop_id="$(read_value id)"
title="$(read_value title)"
visibility="$(read_value visibility)"

[[ "$workshop_id" =~ ^[0-9]+$ ]] || fail "Workshop id must be numeric."
[[ -n "$title" ]] || fail "Workshop title is required."
grep -q '^description=.' "$metadata_file" || fail "Workshop description is required."

case "$visibility" in
    0|1|2|3|public|friendsOnly|private|unlisted) ;;
    *) fail "Workshop visibility must be 0-3, public, friendsOnly, private, or unlisted." ;;
esac

if [[ -n "$expected_workshop_id" && "$workshop_id" != "$expected_workshop_id" ]]; then
    fail "Workshop id does not match EXPECTED_WORKSHOP_ID."
fi

if [[ -n "$preview_file" ]]; then
    [[ -f "$preview_file" ]] || fail "Missing Workshop preview: $preview_file"
    [[ -s "$preview_file" ]] || fail "Workshop preview is empty."
    [[ "$(stat -c '%s' "$preview_file")" -le 1048576 ]] ||
        fail "Workshop preview must not exceed 1 MiB."
fi

echo "Steam Workshop validation passed."
