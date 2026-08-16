#!/usr/bin/env bash
set -euo pipefail

app_id="${1:?app-id is required}"
published_file_id="$2"
content_path="${3:?content-path is required}"
metadata_path="${4:?metadata-path is required}"
preview_path="$5"
changelog="$6"
debug="${7:-false}"

content_folder="$GITHUB_WORKSPACE/$content_path"
metadata_file="$GITHUB_WORKSPACE/$metadata_path"

case "${debug,,}" in
    true|1|yes) debug_enabled=true ;;
    false|0|no|"") debug_enabled=false ;;
    *)
        echo "Unsupported debug value: $debug (expected true or false)." >&2
        exit 1
        ;;
esac

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

# SteamCMD's workshop_build_item appears to parse this KeyValues file without
# escape-sequence support. Physical newlines and backslashes work, while \" is
# not decoded as an embedded quote and can truncate the published description.
# Fail explicitly rather than silently publishing corrupted Workshop metadata.
validate_no_double_quotes() {
    local field_name="$1"
    local value="$2"
    if [[ "$value" == *'"'* ]]; then
        echo "Workshop $field_name contains an unsupported ASCII double quote (\")." >&2
        echo "Remove or replace the double quote before publishing." >&2
        exit 1
    fi
}

validate_no_double_quotes "title" "$title"
validate_no_double_quotes "description" "$description"
validate_no_double_quotes "changenote" "$changelog"

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

    # Workshop text is written verbatim. Physical newlines and backslashes are
    # intentional; translating them to \n or \\ makes Steam display them literally.
    [[ -z "$title" ]] || printf '    "title" "%s"\n' "$title"
    [[ -z "$description" ]] || printf '    "description" "%s"\n' "$description"
    [[ -z "$visibility_number" ]] || printf '    "visibility" "%s"\n' "$visibility_number"
    [[ -z "$changelog" ]] || printf '    "changenote" "%s"\n' "$changelog"

    echo '}'
} > "$item_vdf"

if $debug_enabled; then
    # Verbose diagnostics are opt-in. The generated item VDF contains only
    # Workshop metadata and local runner paths; credentials/session data are
    # never written to this file.
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
    echo 'Generated workshop item VDF:'
    sed 's/^/  | /' "$item_vdf"
    echo 'End generated workshop item VDF.'
fi

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
