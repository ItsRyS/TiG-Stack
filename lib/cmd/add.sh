#!/usr/bin/env bash
# =============================================================================
# lib/cmd/add.sh — "tigadd add" command implementation
# Requires: common.sh, validate.sh, agent.sh, oids/*.sh, gen.sh sourced first
# =============================================================================

cmd_add() {
    validate

    if [ "$DRY_RUN" = "true" ]; then
        printf '\n'; _cyan "── DRY RUN ── preview only ──"
        printf '\n'; gen_config; printf '\n'
        _green "Remove --dry-run to write the file."
        return
    fi

    local safe_name outfile
    safe_name=$(echo "$DEVICE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    outfile="${OUTPUT_DIR}/$(next_file_number "$OUTPUT_DIR")-snmp-${safe_name}.conf"

    # --force: find and overwrite existing file with same device name
    if [ "$FORCE" = "true" ]; then
        local existing
        existing=$(find "$OUTPUT_DIR" -name "[0-9][0-9][0-9]-snmp-${safe_name}.conf" \
            2>/dev/null | head -1)
        if [ -n "$existing" ]; then outfile="$existing"; fi
    fi

    if [ -f "$outfile" ] && [ "$FORCE" != "true" ]; then
        die "File exists: $outfile — use --force to overwrite."
    fi

    mkdir -p "$OUTPUT_DIR"
    gen_config > "$outfile"

    printf '\n'; _green "✔ Config written: $outfile"
    printf '\n'
    log "Device  : $DEVICE_NAME ($DEVICE_TYPE)"
    log "Target  : ${DEVICE_IP}:${SNMP_PORT}  (SNMP ${SNMP_VERSION})"
    log "Interval: ${POLL_INTERVAL}"
    printf '\n'; _yellow "Next steps:"
    printf '  docker compose restart telegraf\n'
    printf '  docker compose logs telegraf --tail=50 -f\n\n'
}