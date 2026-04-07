#!/usr/bin/env bats
# =============================================================================
# tests/test_add.bats — Integration tests for lib/cmd/add.sh
# Run: bats tests/test_add.bats
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

    die() { printf '[ERROR] %s\n' "$*"; exit 1; }

    TEST_DIR="$(mktemp -d)"
    OUTPUT_DIR="$TEST_DIR"

    # Valid defaults
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
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── Dry-run ───────────────────────────────────────────────────────────────────

@test "add --dry-run: does not write any file" {
    DRY_RUN="true"
    run cmd_add
    [ "$status" -eq 0 ]
    local count
    count=$(find "$TEST_DIR" -name "*.conf" | wc -l)
    [ "$count" -eq 0 ]
}

@test "add --dry-run: prints config to stdout" {
    DRY_RUN="true"
    run cmd_add
    [ "$status" -eq 0 ]
    [[ "$output" == *"[[inputs.snmp]]"* ]]
    [[ "$output" == *"DRY RUN"* ]]
}

# ── File creation ─────────────────────────────────────────────────────────────

@test "add: creates a .conf file in OUTPUT_DIR" {
    run cmd_add
    [ "$status" -eq 0 ]
    local count
    count=$(find "$TEST_DIR" -name "*.conf" | wc -l)
    [ "$count" -eq 1 ]
}

@test "add: filename uses sanitised device name" {
    DEVICE_NAME="Core-SW-01"
    run cmd_add
    [ "$status" -eq 0 ]
    local file
    file=$(find "$TEST_DIR" -name "*core-sw-01*")
    [ -n "$file" ]
}

@test "add: first device gets number 000" {
    run cmd_add
    [ "$status" -eq 0 ]
    local file
    file=$(find "$TEST_DIR" -name "000-snmp-core-sw-01.conf")
    [ -f "$file" ]
}

@test "add: second device gets incremented number" {
    run cmd_add
    DEVICE_NAME="core-sw-02" DEVICE_IP="10.0.0.2"
    run cmd_add
    [ "$status" -eq 0 ]
    local file
    file=$(find "$TEST_DIR" -name "001-snmp-core-sw-02.conf")
    [ -f "$file" ]
}

@test "add: written config contains correct device_name tag" {
    run cmd_add
    [ "$status" -eq 0 ]
    local file
    file=$(find "$TEST_DIR" -name "*.conf" | head -1)
    grep -q 'device_name = "core-sw-01"' "$file"
}

@test "add: written config contains correct IP" {
    run cmd_add
    [ "$status" -eq 0 ]
    local file
    file=$(find "$TEST_DIR" -name "*.conf" | head -1)
    grep -q "10.0.0.1" "$file"
}

# ── Duplicate handling ────────────────────────────────────────────────────────

@test "add: duplicate device without --force fails" {
    run cmd_add
    [ "$status" -eq 0 ]
    run cmd_add
    [ "$status" -eq 1 ]
    [[ "$output" == *"use --force"* ]]
}

@test "add: duplicate device with --force overwrites" {
    run cmd_add
    [ "$status" -eq 0 ]

    FORCE="true" DEVICE_IP="10.0.0.99"
    run cmd_add
    [ "$status" -eq 0 ]

    local count
    count=$(find "$TEST_DIR" -name "*core-sw-01*" | wc -l)
    [ "$count" -eq 1 ]

    local file
    file=$(find "$TEST_DIR" -name "*core-sw-01*" | head -1)
    grep -q "10.0.0.99" "$file"
}

# ── Content correctness per device type ───────────────────────────────────────

@test "add: server-linux config includes HOST-RESOURCES-MIB" {
    DEVICE_TYPE="server-linux"
    run cmd_add
    [ "$status" -eq 0 ]
    local file
    file=$(find "$TEST_DIR" -name "*.conf" | head -1)
    grep -q "HOST-RESOURCES-MIB" "$file"
}

@test "add: ups config does not include IF-MIB" {
    DEVICE_TYPE="ups"
    run cmd_add
    [ "$status" -eq 0 ]
    local file
    file=$(find "$TEST_DIR" -name "*.conf" | head -1)
    ! grep -q "IF-MIB" "$file"
}

# ── SNMPv3 ────────────────────────────────────────────────────────────────────

@test "add: v3 config includes sec_name" {
    SNMP_VERSION="v3" SEC_NAME="monitor" SEC_LEVEL="authPriv"
    AUTH_PASS="Auth1234!" PRIV_PASS="Priv1234!"
    run cmd_add
    [ "$status" -eq 0 ]
    local file
    file=$(find "$TEST_DIR" -name "*.conf" | head -1)
    grep -q 'sec_name  = "monitor"' "$file"
}
