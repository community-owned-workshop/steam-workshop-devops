#!/usr/bin/env bash
set -euo pipefail

content_folder="${1:?content folder is required}"
metadata_file="${2:?workshop metadata file is required}"
preview_file="${3:-}"

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$repository_root/scripts/validate-workshop.sh" "$content_folder" "$metadata_file" "$preview_file"

fail() {
    echo "::error::$1" >&2
    exit 1
}

mods_folder="$content_folder/mods"
[[ -d "$mods_folder" ]] || fail "Missing Project Zomboid mods folder: $mods_folder"

mapfile -t mod_info_files < <(
    find "$mods_folder" -mindepth 3 -maxdepth 3 -path '*/42/mod.info' -type f
)
[[ "${#mod_info_files[@]}" -gt 0 ]] ||
    fail "No Project Zomboid Build 42 mod.info found."

declare -A mod_ids=()
for mod_info in "${mod_info_files[@]}"; do
    mod_name="$(sed -n 's/^name=//p' "$mod_info" | head -n 1 | tr -d '\r')"
    mod_id="$(sed -n 's/^id=//p' "$mod_info" | head -n 1 | tr -d '\r')"

    [[ -n "$mod_name" ]] || fail "$mod_info needs a name."
    [[ -n "$mod_id" ]] || fail "$mod_info needs an id."
    [[ -z "${mod_ids[$mod_id]:-}" ]] || fail "Duplicate mod id: $mod_id"
    mod_ids["$mod_id"]=1
done

echo "Project Zomboid Workshop validation passed."
