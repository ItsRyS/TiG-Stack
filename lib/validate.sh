#!/usr/bin/env bash
# =============================================================================
# lib/validate.sh — Input validation for tigadd add command
# Requires: common.sh sourced first
# =============================================================================

validate() {
    local errors=0 val var_name

    # Required fields
    for var_name in DEVICE_TYPE DEVICE_NAME DEVICE_IP SNMP_VERSION; do
        eval "val=\${$var_name:-}"
        if [ -z "$val" ]; then
            warn "Missing --$(echo "$var_name" | tr '[:upper:]_' '[:lower:]-' | sed 's/device-//')"
            errors=$((errors+1))
        fi
    done

    # Device type enum
    case "$DEVICE_TYPE" in
        switch|router|firewall|server-linux|server-windows|ups|envmonitor|"") ;;
        *) warn "Unknown --type '$DEVICE_TYPE'"; errors=$((errors+1)) ;;
    esac

    # SNMP version enum
    case "$SNMP_VERSION" in
        v1|v2c|v3|"") ;;
        *) warn "Unknown --snmp-version '$SNMP_VERSION'. Valid: v1, v2c, v3"
           errors=$((errors+1)) ;;
    esac

    # IP format
    if [ -n "$DEVICE_IP" ]; then
        if ! echo "$DEVICE_IP" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
            warn "Invalid IP: '$DEVICE_IP'"
            errors=$((errors+1))
        fi
    fi

    # Device name — safe chars only
    if [ -n "$DEVICE_NAME" ]; then
        if ! echo "$DEVICE_NAME" | grep -qE '^[a-zA-Z0-9_-]+$'; then
            warn "--name: only letters, numbers, hyphens, underscores allowed"
            errors=$((errors+1))
        fi
    fi

    # SNMPv3 specifics
    if [ "$SNMP_VERSION" = "v3" ]; then
        if [ -z "$SEC_NAME" ]; then
            warn "SNMPv3 requires --sec-name"
            errors=$((errors+1))
        fi

        case "$SEC_LEVEL" in
            noAuthNoPriv|authNoPriv|authPriv) ;;
            *) warn "Unknown --sec-level '$SEC_LEVEL'"; errors=$((errors+1)) ;;
        esac

        if [ "$SEC_LEVEL" = "authNoPriv" ] || [ "$SEC_LEVEL" = "authPriv" ]; then
            if [ -z "$AUTH_PASS" ]; then
                warn "--auth-pass required for sec-level '$SEC_LEVEL'"
                errors=$((errors+1))
            fi
        fi

        if [ "$SEC_LEVEL" = "authPriv" ]; then
            if [ -z "$PRIV_PASS" ]; then
                warn "--priv-pass required for sec-level authPriv"
                errors=$((errors+1))
            fi
        fi
    fi

    if [ "$errors" -gt 0 ]; then
        die "Validation failed with $errors error(s). See warnings above."
    fi
}