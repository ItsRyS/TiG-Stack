#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# tigadd.sh — TiG Stack device management tool
#
# Commands:
#   add    Add a new SNMP device to monitor  (default when no command given)
#   list   List monitored devices with status
#
# Usage:
#   ./tigadd.sh add  --type <type> --name <n> --ip <ip> --snmp-version <ver>
#   ./tigadd.sh list [--output-dir <path>]
#   ./tigadd.sh --help
# =============================================================================

# ── Resolve script directory (works with symlinks) ────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${SCRIPT_DIR}/lib"

# ── Source all modules ────────────────────────────────────────────────────
# shellcheck source=lib/common.sh
source "${LIB}/common.sh"
# shellcheck source=lib/validate.sh
source "${LIB}/validate.sh"
# shellcheck source=lib/agent.sh
source "${LIB}/agent.sh"
# shellcheck source=lib/oids/system.sh
source "${LIB}/oids/system.sh"
# shellcheck source=lib/oids/if_mib.sh
source "${LIB}/oids/if_mib.sh"
# shellcheck source=lib/oids/host.sh
source "${LIB}/oids/host.sh"
# shellcheck source=lib/oids/ups.sh
source "${LIB}/oids/ups.sh"
# shellcheck source=lib/oids/esxi.sh
source "${LIB}/oids/esxi.sh"
# shellcheck source=lib/gen.sh
source "${LIB}/gen.sh"
# shellcheck source=lib/cmd/add.sh
source "${LIB}/cmd/add.sh"
# shellcheck source=lib/cmd/list.sh
source "${LIB}/cmd/list.sh"
# shellcheck source=lib/cmd/remove.sh
source "${LIB}/cmd/remove.sh"
# shellcheck source=lib/cmd/edit.sh
source "${LIB}/cmd/edit.sh"
# shellcheck source=lib/cmd/status.sh
source "${LIB}/cmd/status.sh"

# ── Usage ─────────────────────────────────────────────────────────────────
usage_main() {
    _cyan "TiG Stack — Device Management Tool"
    cat <<'EOF'

Commands:
  add     Add a new SNMP device (default if no command specified)
  edit    Update an existing device (only pass flags you want to change)
  remove  Remove a monitored device by name
  list    List all monitored devices with InfluxDB status
  status  Show health of Docker, InfluxDB, Telegraf, and Grafana

Usage:
  ./tigadd.sh add    --type <type> --name <n> --ip <ip> --snmp-version <ver> [options]
  ./tigadd.sh edit   --name <n> [--ip <ip>] [--community <s>] [--interval <s>] ...
  ./tigadd.sh remove --name <n> [--output-dir <path>] [--force] [--no-reload]
  ./tigadd.sh list   [--output-dir <path>]
  ./tigadd.sh status

Device Types (add):
  switch / router / firewall   SNMPv2-MIB + IF-MIB
  server-linux                 + HOST-RESOURCES-MIB + UCD-SNMP-MIB
  server-windows               + HOST-RESOURCES-MIB
  ups                          UPS-MIB RFC 1628 (numeric OIDs)
  envmonitor                   HOST-RESOURCES-MIB
  esxi              HOST-RESOURCES-MIB + IF-MIB + VMWARE-MIBs (numeric OIDs)

SNMP v1/v2c:  --community <string>                    [default: public]
SNMP v3:      --sec-name --auth-pass --priv-pass
              --auth-proto MD5|SHA|SHA256|SHA384|SHA512 [default: SHA256]
              --priv-proto DES|AES|AES192|AES256        [default: AES256]
              --sec-level  noAuthNoPriv|authNoPriv|authPriv [default: authPriv]

Options (add):
  --port / --timeout / --retries / --interval
  --output-dir   [default: ./telegraf-config/telegraf.d]
  --dry-run      Preview config only, do not write file
  --force        Overwrite existing file (add) / skip confirmation (remove)
  --no-reload    Skip automatic 'docker compose restart telegraf'

Examples:
  ./tigadd.sh add --type switch --name aruba-1930 --ip 192.168.0.0 \
    --snmp-version v2c --community myCommunity

  ./tigadd.sh add --type server-linux --name web-01 --ip 10.0.0.0 \
    --snmp-version v3 --sec-name monitor \
    --auth-pass "AuthPass123!" --priv-pass "PrivPass123!"

  ./tigadd.sh edit --name aruba-1930 --ip 10.0.0.5

  ./tigadd.sh edit --name web-01 --auth-pass "NewPass456!" --priv-pass "NewPriv456!"

  ./tigadd.sh remove --name aruba-1930

  ./tigadd.sh list

  ./tigadd.sh list --output-dir /custom/path
EOF
    exit 0
}

# ── Parse global flags + route to sub-command ─────────────────────────────
main() {
    if [ $# -eq 0 ]; then
        usage_main
    fi

    # Determine command
    local cmd="add"   # default
    case "$1" in
        add|list|remove|edit|status)  cmd="$1"; shift ;;
        -h|--help)             usage_main ;;
        --*)                   cmd="add" ;;   # no command → treat all args as "add"
        *)                     die "Unknown command: '$1'. Valid: add, edit, remove, list, status  (use --help)" ;;
    esac

    # Parse remaining flags
    while [ $# -gt 0 ]; do
        case "$1" in
            --type)         DEVICE_TYPE=$(echo "$2"  | tr '[:upper:]' '[:lower:]'); _EDIT_OVERRIDES+=" type";        shift 2 ;;
            --name)         DEVICE_NAME="$2";                                                                          shift 2 ;;
            --ip)           DEVICE_IP="$2";                                          _EDIT_OVERRIDES+=" ip";           shift 2 ;;
            --snmp-version) SNMP_VERSION=$(echo "$2" | tr '[:upper:]' '[:lower:]'); _EDIT_OVERRIDES+=" snmp-version"; shift 2 ;;
            --port)         SNMP_PORT="$2";                                          _EDIT_OVERRIDES+=" port";         shift 2 ;;
            --timeout)      SNMP_TIMEOUT="$2";                                       _EDIT_OVERRIDES+=" timeout";      shift 2 ;;
            --retries)      SNMP_RETRIES="$2";                                       _EDIT_OVERRIDES+=" retries";      shift 2 ;;
            --interval)     POLL_INTERVAL="$2";                                      _EDIT_OVERRIDES+=" interval";     shift 2 ;;
            --output-dir)   OUTPUT_DIR="$2";                                                                           shift 2 ;;
            --community)    COMMUNITY="$2";                                          _EDIT_OVERRIDES+=" community";    shift 2 ;;
            --sec-name)     SEC_NAME="$2";                                           _EDIT_OVERRIDES+=" sec-name";     shift 2 ;;
            --auth-proto)   AUTH_PROTO=$(echo "$2" | tr '[:lower:]' '[:upper:]');   _EDIT_OVERRIDES+=" auth-proto";   shift 2 ;;
            --auth-pass)    AUTH_PASS="$2";                                          _EDIT_OVERRIDES+=" auth-pass";    shift 2 ;;
            --priv-proto)   PRIV_PROTO=$(echo "$2" | tr '[:lower:]' '[:upper:]');   _EDIT_OVERRIDES+=" priv-proto";   shift 2 ;;
            --priv-pass)    PRIV_PASS="$2";                                          _EDIT_OVERRIDES+=" priv-pass";    shift 2 ;;
            --sec-level)    SEC_LEVEL="$2";                                          _EDIT_OVERRIDES+=" sec-level";    shift 2 ;;
            --dry-run)      DRY_RUN="true";                                                                            shift   ;;
            --force)        FORCE="true";                                                                               shift   ;;
            --no-reload)    NO_RELOAD="true";                                                                           shift   ;;
            -h|--help)      usage_main ;;
            *) die "Unknown flag: $1  (use --help)" ;;
        esac
    done

    # Route to command
    case "$cmd" in
        add)    cmd_add    ;;
        edit)   cmd_edit   ;;
        remove) cmd_remove ;;
        list)   cmd_list   ;;
        status) cmd_status ;;
    esac
}

main "$@"