#!/usr/bin/env bats
# =============================================================================
# tests/test_remove.bats — Integration tests for lib/cmd/remove.sh
# Run: bats tests/test_remove.bats
# =============================================================================

SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
    source "$SCRIPT_DIR/lib/common.sh"
    source "$SCRIPT_DIR/lib/cmd/remove.sh"

    die() { printf '[ERROR] %s\n' "$*"; exit 1; }

    TEST_DIR="$(mktemp -d)"
    OUTPUT_DIR="$TEST_DIR"

    DEVICE_NAME="core-sw-01"
    FORCE="false"
    NO_RELOAD="true"   # never touch docker in tests
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Helper: create a fake device config file
_make_device_conf() {
    local name="$1" number="${2:-101}"
    local safe_name
    safe_name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    touch "$TEST_DIR/${number}-snmp-${safe_name}.conf"
}

# ── Input validation ──────────────────────────────────────────────────────────

@test "remove: missing --name fails" {
    DEVICE_NAME=""
    run cmd_remove
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing --name"* ]]
}

@test "remove: nonexistent device fails" {
    DEVICE_NAME="ghost-device"
    run cmd_remove
    [ "$status" -eq 1 ]
    [[ "$output" == *"No config found"* ]]
}

# ── File deletion ─────────────────────────────────────────────────────────────

@test "remove --force: deletes the config file" {
    _make_device_conf "core-sw-01"
    FORCE="true"
    run cmd_remove
    [ "$status" -eq 0 ]
    local count
    count=$(find "$TEST_DIR" -name "*core-sw-01*" | wc -l)
    [ "$count" -eq 0 ]
}

@test "remove --force: prints confirmation message" {
    _make_device_conf "core-sw-01"
    FORCE="true"
    run cmd_remove
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed"* ]]
}

@test "remove: only removes the matching device, leaves others" {
    _make_device_conf "core-sw-01" "101"
    _make_device_conf "core-sw-02" "102"
    DEVICE_NAME="core-sw-01" FORCE="true"
    run cmd_remove
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_DIR/101-snmp-core-sw-01.conf" ]
    [ -f "$TEST_DIR/102-snmp-core-sw-02.conf" ]
}

@test "remove: device name lookup is case-insensitive" {
    _make_device_conf "core-sw-01" "101"
    DEVICE_NAME="CORE-SW-01" FORCE="true"
    run cmd_remove
    [ "$status" -eq 0 ]
    local count
    count=$(find "$TEST_DIR" -name "*core-sw-01*" | wc -l)
    [ "$count" -eq 0 ]
}

# ── Confirmation prompt ───────────────────────────────────────────────────────

@test "remove: without --force prompts for confirmation and aborts on 'n'" {
    _make_device_conf "core-sw-01"
    FORCE="false"
    # Feed 'n' to the read prompt
    run bash -c "
        source '$SCRIPT_DIR/lib/common.sh'
        source '$SCRIPT_DIR/lib/cmd/remove.sh'
        die() { printf '[ERROR] %s\n' \"\$*\"; exit 1; }
        OUTPUT_DIR='$TEST_DIR' DEVICE_NAME='core-sw-01' FORCE='false' NO_RELOAD='true'
        cmd_remove <<< 'n'
    "
    [ "$status" -eq 0 ]
    # File should still exist
    [ -f "$TEST_DIR/101-snmp-core-sw-01.conf" ]
    [[ "$output" == *"Aborted"* ]]
}

@test "remove: without --force prompts for confirmation and proceeds on 'y'" {
    _make_device_conf "core-sw-01"
    FORCE="false"
    run bash -c "
        source '$SCRIPT_DIR/lib/common.sh'
        source '$SCRIPT_DIR/lib/cmd/remove.sh'
        die() { printf '[ERROR] %s\n' \"\$*\"; exit 1; }
        OUTPUT_DIR='$TEST_DIR' DEVICE_NAME='core-sw-01' FORCE='false' NO_RELOAD='true'
        cmd_remove <<< 'y'
    "
    [ "$status" -eq 0 ]
    local count
    count=$(find "$TEST_DIR" -name "*core-sw-01*" | wc -l)
    [ "$count" -eq 0 ]
}
