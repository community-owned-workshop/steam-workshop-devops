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
# Never print STEAM_CONFIG_VDF: it contains Steam session/authentication data.
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

# Escape quotes and backslashes for a quoted Valve KeyValues/VDF string while
# preserving physical newlines. Steam Workshop accepts multiline description
# values this way; literal \n sequences are displayed as text by the Workshop UI.
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

# Safe diagnostics for opaque SteamCMD "Failure" responses. Deliberately do not
# print passwords, config.vdf, Steam Guard/session values, or config.vdf contents.
echo "Workshop update diagnostics:"
printf '  app-id: %s\n' "$app_id"
printf '  published-file-id: %s\n' "$published_file_id"
printf '  content-folder: %s\n' "$content_folder"
if [[ -n "$preview_path" && -f "$GITHUB_WORKSPACE/$preview_path" ]]; then
    printf '  preview-file: %s\n' "$GITHUB_WORKSPACE/$preview_path"
else
    echo '  preview-file: <none>'
fi
printf '  title: %s\n' "${title:-<none>}"
printf '  visibility: %s\n' "${visibility_number:-<unchanged>}"
printf '  description-length: %s characters\n' "${#description}"
printf '  changenote-length: %s characters\n' "${#changelog}"
printf '  content-files: %s\n' "$(find "$content_folder" -type f | wc -l | tr -d ' ')"
printf '  content-bytes: %s\n' "$(du -sb "$content_folder" | cut -f1)"

# Keep this verbose diagnostic until the Scrap Mechanic publisher is stable.
# The generated item VDF contains only public Workshop metadata and local runner
# paths; Steam credentials/session data are never written to this file.
echo 'Generated workshop item VDF:'
sed 's/^/  | /' "$item_vdf"

echo 'End generated workshop item VDF.'

if [[ -n "${STEAM_CONFIG_VDF:-}" ]]; then
    login_arguments=("$STEAM_ACCOUNT_NAME")
else
    login_arguments=("$STEAM_ACCOUNT_NAME" "$STEAM_PASSWORD")
fi

# Temporarily disable errexit so we can print useful, sanitized diagnostics when
# SteamCMD returns its otherwise opaque "Failed to update workshop item (Failure)".
set +e
steamcmd \
    +login "${login_arguments[@]}" \
    +workshop_build_item "$item_vdf" \
    +quit
steam_exit_code=$?
set -e

if [[ $steam_exit_code -ne 0 ]]; then
    echo "SteamCMD failed with exit code $steam_exit_code." >&2

    workshop_log="$HOME/.local/share/Steam/logs/workshop_log.txt"
    if [[ -f "$workshop_log" ]]; then
        echo "Sanitized workshop_log.txt diagnostics:" >&2
        # workshop_log.txt normally contains UGC result/status information, but
        # filter aggressively before exposing anything in a public Actions log.
        grep -Ei 'error|fail|workshop|ugc|result' "$workshop_log" 2>/dev/null \
            | sed -E \
                -e 's/(password|passwd|token|secret|auth|credential|session|login)[=: ]+[^ ]+/\1=<redacted>/Ig' \
                -e 's/([A-Fa-f0-9]{32,})/<redacted>/g' \
            >&2 || echo "  <no matching diagnostic lines>" >&2
    else
        echo "workshop_log.txt was not found." >&2
    fi

    echo "SteamCMD log files present (contents are otherwise intentionally not dumped):" >&2
    find "$HOME/.local/share/Steam/logs" -maxdepth 1 -type f -printf '  %f (%s bytes)\n' 2>/dev/null | sort >&2 || true
    exit "$steam_exit_code"
fi
