#!/usr/bin/env bash
# =============================================================================
# lib/cmd/remove.sh — "tigadd remove" command implementation
# Requires: common.sh sourced first
# =============================================================================

cmd_remove() {
    if [ -z "$DEVICE_NAME" ]; then
        die "Missing --name <device-name>  (use --help)"
    fi

    local safe_name target
    safe_name=$(echo "$DEVICE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    target=$(find "$OUTPUT_DIR" -maxdepth 1 -name "[0-9][0-9][0-9]-snmp-${safe_name}.conf" \
        2>/dev/null | head -1)

    if [ -z "$target" ]; then
        die "No config found for device '${DEVICE_NAME}' in ${OUTPUT_DIR}"
    fi

    printf '\n'
    log "Found    : $target"

    if [ "$FORCE" != "true" ]; then
        printf '\033[0;33m  Remove this file? [y/N] \033[0m'
        read -r answer
        case "$answer" in
            y|Y|yes|YES) ;;
            *) printf 'Aborted.\n\n'; return ;;
        esac
    fi

    rm "$target"
    _green "✔ Removed: $target"

    _telegraf_reload

    printf '\n'
}
