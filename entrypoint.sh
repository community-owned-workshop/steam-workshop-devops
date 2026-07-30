#!/usr/bin/env bash
set -euo pipefail

app_id="${1:?app-id is required}"
published_file_id="$2"
content_path="${3:?content-path is required}"
metadata_path="${4:?metadata-path is required}"
preview_path="$5"
changelog="$6"

content_folder="$GITHUB_WORKSPACE/$content_path"
metadata_file="$GITHUB_WORKSPACE/$metadata_path"

# SteamCMD may replace config.vdf during its first update, so bootstrap it first.
if [[ -n "${STEAM_CONFIG_VDF:-}" ]]; then
    steamcmd +quit

    steam_root="$HOME/.local/share/Steam"
    mkdir -p "$steam_root/config"
    printf '%s' "$STEAM_CONFIG_VDF" | base64 --decode > "$steam_root/config/config.vdf"
    echo "SteamCMD session restored."
fi

[[ -d "$content_folder" ]] || {
    echo "Workshop content folder does not exist: $content_folder" >&2
    exit 1
}

[[ -f "$metadata_file" ]] || {
    echo "Workshop metadata does not exist: $metadata_file" >&2
    exit 1
}

read_value() {
    local key="$1"
    sed -n "s/^${key}=//p" "$metadata_file" | head -n 1 | tr -d '\r'
}

escape_vdf() {
    awk '
        BEGIN { first = 1 }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            if (!first) {
                printf "\n"
            }
            printf "%s", $0
            first = 0
        }
    '
}

if [[ -z "$published_file_id" ]]; then
    published_file_id="$(read_value id)"
fi

[[ -n "$published_file_id" ]] || {
    echo "Workshop ID is required via published-file-id or the metadata file." >&2
    exit 1
}

title="$(read_value title)"
visibility="$(read_value visibility)"
description="$(sed -n 's/^description=//p' "$metadata_file" | tr -d '\r')"

case "$visibility" in
    "") visibility_number="" ;;
    0|public) visibility_number="0" ;;
    1|friendsOnly) visibility_number="1" ;;
    2|private) visibility_number="2" ;;
    3|unlisted) visibility_number="3" ;;
    *)
        echo "Unsupported Workshop visibility: $visibility" >&2
        exit 1
        ;;
esac

item_vdf="$(mktemp)"
trap 'rm -f "$item_vdf"' EXIT

{
    echo '"workshopitem"'
    echo '{'
    printf '    "appid" "%s"\n' "$app_id"
    printf '    "publishedfileid" "%s"\n' "$published_file_id"
    printf '    "contentfolder" "%s"\n' "$content_folder"

    if [[ -n "$preview_path" && -f "$GITHUB_WORKSPACE/$preview_path" ]]; then
        printf '    "previewfile" "%s"\n' "$GITHUB_WORKSPACE/$preview_path"
    fi

    [[ -z "$title" ]] ||
        printf '    "title" "%s"\n' "$(printf '%s' "$title" | escape_vdf)"
    [[ -z "$description" ]] ||
        printf '    "description" "%s"\n' "$(printf '%s' "$description" | escape_vdf)"
    [[ -z "$visibility_number" ]] ||
        printf '    "visibility" "%s"\n' "$visibility_number"
    [[ -z "$changelog" ]] ||
        printf '    "changenote" "%s"\n' "$(printf '%s' "$changelog" | escape_vdf)"

    echo '}'
} > "$item_vdf"

if [[ -n "${STEAM_CONFIG_VDF:-}" ]]; then
    login_arguments=("$STEAM_ACCOUNT_NAME")
else
    login_arguments=("$STEAM_ACCOUNT_NAME" "$STEAM_PASSWORD")
fi

steamcmd \
    +login "${login_arguments[@]}" \
    +workshop_build_item "$item_vdf" \
    +quit
