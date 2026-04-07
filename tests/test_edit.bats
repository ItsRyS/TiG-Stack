#!/usr/bin/env bats
# =============================================================================
# tests/test_edit.bats — Integration tests for lib/cmd/edit.sh
# Run: bats tests/test_edit.bats
# =============================================================================

SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
    source "$SCRIPT_DIR/lib/common.sh"
    source "$SCRIPT_DIR/lib/validate.sh"
    source "$SCRIPT_DIR/lib/agent.sh"
    source "$SCRIPT_DIR/lib/oids/system.sh"
    source "$SCRIPT_DIR/lib/oids/if_mib.sh"
    source "$SCRIPT_DIR/lib/oids/host.sh"
    source "$SCRIPT_DIR/lib/oids/ups.sh"
    source "$SCRIPT_DIR/lib/oids/esxi.sh"
    source "$SCRIPT_DIR/lib/gen.sh"
    source "$SCRIPT_DIR/lib/cmd/add.sh"
    source "$SCRIPT_DIR/lib/cmd/edit.sh"

    die() { printf '[ERROR] %s\n' "$*"; exit 1; }

    TEST_DIR="$(mktemp -d)"
    OUTPUT_DIR="$TEST_DIR"

    # Valid defaults — used when creating initial conf and during edit
    DEVICE_TYPE="switch"
    DEVICE_NAME="core-sw-01"
    DEVICE_IP="10.0.0.1"
    SNMP_PORT="161"
    SNMP_VERSION="v2c"
    SNMP_TIMEOUT="5s"
    SNMP_RETRIES="3"
    POLL_INTERVAL="60s"
    COMMUNITY="public"
    SEC_NAME="" AUTH_PROTO="SHA256" AUTH_PASS=""
    PRIV_PROTO="AES256" PRIV_PASS="" SEC_LEVEL="authPriv"
    DRY_RUN="false"
    FORCE="false"
    NO_RELOAD="true"   # never touch docker in tests
    _EDIT_OVERRIDES=""
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Helper: create a device config using the real add pipeline
_make_device_conf() {
    cmd_add >/dev/null 2>&1
}

# Helper: find the main .conf file (not .bak)
_conf_file() {
    find "$TEST_DIR" -maxdepth 1 -name "[0-9][0-9][0-9]-snmp-*.conf" | head -1
}

# ── Input validation ──────────────────────────────────────────────────────────

@test "edit: missing --name fails" {
    DEVICE_NAME=""
    run cmd_edit
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing --name"* ]]
}

@test "edit: nonexistent device fails" {
    DEVICE_NAME="ghost-device"
    run cmd_edit
    [ "$status" -eq 1 ]
    [[ "$output" == *"No config found"* ]]
}

# ── Dry-run ───────────────────────────────────────────────────────────────────

@test "edit --dry-run: does not modify the file" {
    _make_device_conf
    DRY_RUN="true"
    DEVICE_IP="9.9.9.9"
    _EDIT_OVERRIDES="ip"
    run cmd_edit
    [ "$status" -eq 0 ]
    local file
    file=$(_conf_file)
    ! grep -q "9.9.9.9" "$file"
}

@test "edit --dry-run: prints config to stdout" {
    _make_device_conf
    DRY_RUN="true"
    run cmd_edit
    [ "$status" -eq 0 ]
    [[ "$output" == *"[[inputs.snmp]]"* ]]
    [[ "$output" == *"DRY RUN"* ]]
}

# ── Override behaviour ────────────────────────────────────────────────────────

@test "edit: changes IP in config file when ip is in overrides" {
    _make_device_conf
    DEVICE_IP="9.9.9.9"
    _EDIT_OVERRIDES="ip"
    run cmd_edit
    [ "$status" -eq 0 ]
    local file
    file=$(_conf_file)
    grep -q "9.9.9.9" "$file"
}

@test "edit: overrides community when community is in overrides" {
    _make_device_conf   # written with community = "public"
    COMMUNITY="override-community"
    _EDIT_OVERRIDES="community"
    run cmd_edit
    [ "$status" -eq 0 ]
    local file
    file=$(_conf_file)
    grep -q '"override-community"' "$file"
}

# ── Preserve-existing behaviour ───────────────────────────────────────────────

@test "edit: preserves device type when type not in overrides" {
    _make_device_conf   # written as switch
    DEVICE_TYPE="ups"   # set wrong type in globals
    _EDIT_OVERRIDES=""  # no overrides → parse_existing restores from file
    run cmd_edit
    [ "$status" -eq 0 ]
    local file
    file=$(_conf_file)
    grep -qi "SWITCH" "$file"
}

@test "edit: preserves SNMP version when snmp-version not in overrides" {
    _make_device_conf   # written as v2c
    SNMP_VERSION="v3"   # set wrong version in globals
    _EDIT_OVERRIDES=""
    run cmd_edit
    [ "$status" -eq 0 ]
    local file
    file=$(_conf_file)
    ! grep -q 'sec_name' "$file"
}

@test "edit: preserves community when community not in overrides" {
    _make_device_conf   # written with community = "public"
    COMMUNITY="intruder"
    _EDIT_OVERRIDES=""  # no override → parse_existing restores "public"
    run cmd_edit
    [ "$status" -eq 0 ]
    local file
    file=$(_conf_file)
    grep -q '"public"' "$file"
    ! grep -q '"intruder"' "$file"
}

# ── Backup ────────────────────────────────────────────────────────────────────

@test "edit: creates a .bak file before overwriting" {
    _make_device_conf
    run cmd_edit
    [ "$status" -eq 0 ]
    local bak
    bak=$(find "$TEST_DIR" -name "*.bak" | head -1)
    [ -n "$bak" ]
}

@test "edit: .bak file contains the original content" {
    _make_device_conf   # IP is 10.0.0.1
    DEVICE_IP="9.9.9.9"
    _EDIT_OVERRIDES="ip"
    run cmd_edit
    [ "$status" -eq 0 ]
    local bak
    bak=$(find "$TEST_DIR" -name "*.bak" | head -1)
    grep -q "10.0.0.1" "$bak"
    ! grep -q "9.9.9.9" "$bak"
}

# ── Type change ───────────────────────────────────────────────────────────────

@test "edit: changing type to ups removes IF-MIB OIDs" {
    _make_device_conf   # switch → has IF-MIB
    DEVICE_TYPE="ups"
    _EDIT_OVERRIDES="type"
    run cmd_edit
    [ "$status" -eq 0 ]
    local file
    file=$(_conf_file)
    ! grep -q "IF-MIB" "$file"
}

@test "edit: changing type to ups adds UPS-MIB OIDs" {
    _make_device_conf   # switch → no UPS-MIB
    DEVICE_TYPE="ups"
    _EDIT_OVERRIDES="type"
    run cmd_edit
    [ "$status" -eq 0 ]
    local file
    file=$(_conf_file)
    grep -q "UPS-MIB" "$file"
}

# ── Protocol upgrade ──────────────────────────────────────────────────────────

@test "edit: v2c → v3 adds sec_name to config" {
    _make_device_conf   # v2c
    SNMP_VERSION="v3"
    SEC_NAME="monitor"
    SEC_LEVEL="authPriv"
    AUTH_PASS="Auth1234!"
    PRIV_PASS="Priv1234!"
    _EDIT_OVERRIDES="snmp-version sec-name sec-level auth-pass priv-pass"
    run cmd_edit
    [ "$status" -eq 0 ]
    local file
    file=$(_conf_file)
    grep -q 'sec_name' "$file"
    grep -q '"monitor"' "$file"
}

# ── Case sensitivity ──────────────────────────────────────────────────────────

@test "edit: device name lookup is case-insensitive" {
    _make_device_conf   # creates core-sw-01
    DEVICE_NAME="CORE-SW-01"
    run cmd_edit
    [ "$status" -eq 0 ]
    [[ "$output" == *"Config updated"* ]]
}
