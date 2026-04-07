#!/usr/bin/env bash
# =============================================================================
# lib/cmd/edit.sh — "tigadd edit" command implementation
# Requires: common.sh, validate.sh, agent.sh, oids/*.sh, gen.sh sourced first
#
# Only flags explicitly passed by the user override existing values.
# Everything else is loaded from the existing config file.
# =============================================================================

_edit_has_override() { [[ " ${_EDIT_OVERRIDES} " == *" $1 "* ]]; }

_edit_parse_existing() {
    local file="$1"

    # Device type (from header comment)
    local raw_type
    raw_type=$(grep '^# Telegraf SNMP Input —' "$file" \
        | sed 's/.*— *//' | tr '[:upper:]' '[:lower:]') || true
    _edit_has_override "type" || DEVICE_TYPE="$raw_type"

    # SNMP version (version = 1 / 2 / 3)
    local raw_ver
    raw_ver=$(grep '^\s*version\s*=' "$file" | head -1 | grep -o '[123]') || true
    if ! _edit_has_override "snmp-version"; then
        case "$raw_ver" in
            1) SNMP_VERSION="v1"  ;;
            2) SNMP_VERSION="v2c" ;;
            3) SNMP_VERSION="v3"  ;;
        esac
    fi

    # IP and port from: agents = ["udp://IP:PORT"]
    local raw_agent raw_ip raw_port
    raw_agent=$(grep '^\s*agents\s*=' "$file" | head -1 \
        | grep -o 'udp://[^"]*') || true
    raw_ip=${raw_agent#udp://};  raw_ip=${raw_ip%:*}
    raw_port=${raw_agent##*:}
    _edit_has_override "ip"   || DEVICE_IP="$raw_ip"
    _edit_has_override "port" || SNMP_PORT="$raw_port"

    # Polling parameters
    local raw_interval raw_timeout raw_retries
    raw_interval=$(grep '^\s*interval\s*=' "$file" | head -1 \
        | sed 's/.*= *"//' | sed 's/".*//') || true
    raw_timeout=$(grep '^\s*timeout\s*=' "$file" | head -1 \
        | sed 's/.*= *"//' | sed 's/".*//') || true
    raw_retries=$(grep '^\s*retries\s*=' "$file" | head -1 \
        | sed 's/.*= *//' | tr -d ' ') || true
    _edit_has_override "interval" || POLL_INTERVAL="$raw_interval"
    _edit_has_override "timeout"  || SNMP_TIMEOUT="$raw_timeout"
    _edit_has_override "retries"  || SNMP_RETRIES="$raw_retries"

    # SNMPv1/v2c
    local raw_community
    raw_community=$(grep '^\s*community\s*=' "$file" | head -1 \
        | sed 's/.*= *"//' | sed 's/".*//') || true
    _edit_has_override "community" || COMMUNITY="$raw_community"

    # SNMPv3
    local raw_sec_name raw_sec_level raw_auth_proto raw_auth_pass raw_priv_proto raw_priv_pass
    raw_sec_name=$(grep '^\s*sec_name\s*=' "$file" | head -1 \
        | sed 's/.*= *"//' | sed 's/".*//') || true
    raw_sec_level=$(grep '^\s*sec_level\s*=' "$file" | head -1 \
        | sed 's/.*= *"//' | sed 's/".*//') || true
    raw_auth_proto=$(grep '^\s*auth_protocol\s*=' "$file" | head -1 \
        | sed 's/.*= *"//' | sed 's/".*//') || true
    raw_auth_pass=$(grep '^\s*auth_password\s*=' "$file" | head -1 \
        | sed 's/.*= *"//' | sed 's/".*//') || true
    raw_priv_proto=$(grep '^\s*priv_protocol\s*=' "$file" | head -1 \
        | sed 's/.*= *"//' | sed 's/".*//') || true
    raw_priv_pass=$(grep '^\s*priv_password\s*=' "$file" | head -1 \
        | sed 's/.*= *"//' | sed 's/".*//') || true
    _edit_has_override "sec-name"   || SEC_NAME="$raw_sec_name"
    _edit_has_override "sec-level"  || SEC_LEVEL="$raw_sec_level"
    _edit_has_override "auth-proto" || AUTH_PROTO="$raw_auth_proto"
    _edit_has_override "auth-pass"  || AUTH_PASS="$raw_auth_pass"
    _edit_has_override "priv-proto" || PRIV_PROTO="$raw_priv_proto"
    _edit_has_override "priv-pass"  || PRIV_PASS="$raw_priv_pass"
}

cmd_edit() {
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

    _edit_parse_existing "$target"
    validate

    if [ "$DRY_RUN" = "true" ]; then
        printf '\n'; _cyan "── DRY RUN ── preview only ──"
        printf '\n'; gen_config; printf '\n'
        _green "Remove --dry-run to apply changes."
        return
    fi

    cp "$target" "${target}.bak"
    gen_config > "$target"

    printf '\n'; _green "✔ Config updated: $target"
    log "Backup  : ${target}.bak"
    printf '\n'
    log "Device  : $DEVICE_NAME ($DEVICE_TYPE)"
    log "Target  : ${DEVICE_IP}:${SNMP_PORT}  (SNMP ${SNMP_VERSION})"

    _telegraf_reload
    printf '\n'
}
