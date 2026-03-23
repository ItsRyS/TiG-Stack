#!/usr/bin/env bash
# =============================================================================
# lib/agent.sh — Build [[inputs.snmp]] agent block
# Requires: common.sh sourced first
# =============================================================================

build_agent_block() {
    local ver=1
    case "$SNMP_VERSION" in v1) ver=1;; v2c) ver=2;; v3) ver=3;; esac

    printf '[[inputs.snmp]]\n'
    printf '  agents   = ["udp://%s:%s"]\n' "$DEVICE_IP" "$SNMP_PORT"
    printf '  version  = %s\n'              "$ver"
    printf '  timeout  = "%s"\n'            "$SNMP_TIMEOUT"
    printf '  retries  = %s\n'              "$SNMP_RETRIES"
    printf '  interval = "%s"\n'            "$POLL_INTERVAL"

    case "$SNMP_VERSION" in
        v1|v2c)
            printf '  community = "%s"\n' "$COMMUNITY"
            ;;
        v3)
            printf '  sec_name  = "%s"\n' "$SEC_NAME"
            printf '  sec_level = "%s"\n' "$SEC_LEVEL"
            if [ "$SEC_LEVEL" != "noAuthNoPriv" ]; then
                printf '  auth_protocol = "%s"\n' "$AUTH_PROTO"
                printf '  auth_password = "%s"\n' "$AUTH_PASS"
            fi
            if [ "$SEC_LEVEL" = "authPriv" ]; then
                printf '  priv_protocol = "%s"\n' "$PRIV_PROTO"
                printf '  priv_password = "%s"\n' "$PRIV_PASS"
            fi
            ;;
    esac

    printf '\n  [inputs.snmp.tags]\n'
    printf '    device_name = "%s"\n' "$DEVICE_NAME"
    printf '    device_type = "%s"\n' "$DEVICE_TYPE"
    printf '    device_ip   = "%s"\n' "$DEVICE_IP"
}