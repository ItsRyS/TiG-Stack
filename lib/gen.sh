#!/usr/bin/env bash
# =============================================================================
# lib/gen.sh — Config assembly (gen_config) + auto file numbering
# Requires: common.sh, agent.sh, oids/*.sh sourced first
# =============================================================================

gen_config() {
    printf '# ============================================================\n'
    printf '# Telegraf SNMP Input — %s\n' "$(echo "$DEVICE_TYPE" | tr '[:lower:]' '[:upper:]')"
    printf '# Device  : %s\n' "$DEVICE_NAME"
    printf '# IP      : %s:%s\n' "$DEVICE_IP" "$SNMP_PORT"
    printf '# SNMP    : %s\n' "$(echo "$SNMP_VERSION" | tr '[:lower:]' '[:upper:]')"
    printf '# Generated: %s by tigadd.sh\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '# ============================================================\n'

    build_agent_block
    oids_system_info

    case "$DEVICE_TYPE" in
        switch|router|firewall) oids_if_mib ;;
        server-linux)           oids_if_mib; oids_host_resources; oids_ucd_snmp ;;
        server-windows)         oids_if_mib; oids_host_resources ;;
        ups)                    oids_ups_mib ;;
        envmonitor)             oids_host_resources ;;
    esac
}

# Returns next 3-digit sequence number based on existing files in dir
next_file_number() {
    local dir="$1" max=-1 num
    mkdir -p "$dir"
    for f in "$dir"/[0-9][0-9][0-9]-*.conf; do
        if [ ! -e "$f" ]; then continue; fi
        num=$((10#$(basename "$f" | cut -d'-' -f1)))
        if [ "$num" -gt "$max" ]; then max="$num"; fi
    done
    printf '%03d' $((max + 1))
}