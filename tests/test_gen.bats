#!/usr/bin/env bats
# =============================================================================
# tests/test_gen.bats — Tests for lib/gen.sh (config generation + numbering)
# Run: bats tests/test_gen.bats
# =============================================================================

SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
    source "$SCRIPT_DIR/lib/common.sh"
    source "$SCRIPT_DIR/lib/agent.sh"
    source "$SCRIPT_DIR/lib/oids/system.sh"
    source "$SCRIPT_DIR/lib/oids/if_mib.sh"
    source "$SCRIPT_DIR/lib/oids/host.sh"
    source "$SCRIPT_DIR/lib/oids/ups.sh"
    source "$SCRIPT_DIR/lib/oids/esxi.sh"
    source "$SCRIPT_DIR/lib/gen.sh"

    TEST_DIR="$(mktemp -d)"

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
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── next_file_number ──────────────────────────────────────────────────────────

@test "next_file_number: empty dir returns 000" {
    run next_file_number "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "000" ]
}

@test "next_file_number: increments past existing files" {
    touch "$TEST_DIR/101-snmp-sw1.conf"
    touch "$TEST_DIR/102-snmp-sw2.conf"
    run next_file_number "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "103" ]
}

@test "next_file_number: counts all NNN-*.conf files including non-snmp" {
    touch "$TEST_DIR/100-snmp-sw1.conf"
    touch "$TEST_DIR/README.md"
    touch "$TEST_DIR/000-influxdb.conf"
    run next_file_number "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "101" ]
}

@test "next_file_number: handles non-sequential gaps correctly" {
    touch "$TEST_DIR/101-snmp-sw1.conf"
    touch "$TEST_DIR/150-snmp-sw2.conf"
    run next_file_number "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "151" ]
}

# ── gen_config structure ──────────────────────────────────────────────────────

@test "gen_config: output contains [[inputs.snmp]] block" {
    run gen_config
    [ "$status" -eq 0 ]
    [[ "$output" == *"[[inputs.snmp]]"* ]]
}

@test "gen_config: output contains device IP" {
    run gen_config
    [[ "$output" == *"10.0.0.1"* ]]
}

@test "gen_config: output contains device_name tag" {
    run gen_config
    [[ "$output" == *'device_name = "core-sw-01"'* ]]
}

@test "gen_config: output contains device_type tag" {
    run gen_config
    [[ "$output" == *'device_type = "switch"'* ]]
}

@test "gen_config: output contains poll interval" {
    POLL_INTERVAL="120s"
    run gen_config
    [[ "$output" == *'interval = "120s"'* ]]
}

# ── SNMPv2c agent block ───────────────────────────────────────────────────────

@test "gen_config: v2c includes community string" {
    SNMP_VERSION="v2c" COMMUNITY="private"
    run gen_config
    [[ "$output" == *'community = "private"'* ]]
}

@test "gen_config: v2c does NOT include sec_name" {
    SNMP_VERSION="v2c"
    run gen_config
    [[ "$output" != *"sec_name"* ]]
}

# ── SNMPv3 agent block ────────────────────────────────────────────────────────

@test "gen_config: v3 includes sec_name and auth fields" {
    SNMP_VERSION="v3" SEC_NAME="monitor" SEC_LEVEL="authPriv"
    AUTH_PROTO="SHA256" AUTH_PASS="Auth1234!"
    PRIV_PROTO="AES256" PRIV_PASS="Priv1234!"
    run gen_config
    [[ "$output" == *'sec_name  = "monitor"'* ]]
    [[ "$output" == *'auth_protocol = "SHA256"'* ]]
    [[ "$output" == *'priv_protocol = "AES256"'* ]]
}

@test "gen_config: v3 noAuthNoPriv omits auth/priv fields" {
    SNMP_VERSION="v3" SEC_NAME="monitor" SEC_LEVEL="noAuthNoPriv"
    AUTH_PASS="" PRIV_PASS=""
    run gen_config
    [[ "$output" != *"auth_protocol"* ]]
    [[ "$output" != *"priv_protocol"* ]]
}

# ── Device type → OID selection ───────────────────────────────────────────────

@test "gen_config: switch includes IF-MIB fields" {
    DEVICE_TYPE="switch"
    run gen_config
    [[ "$output" == *"IF-MIB"* ]]
}

@test "gen_config: server-linux includes IF-MIB and HOST-RESOURCES-MIB" {
    DEVICE_TYPE="server-linux"
    run gen_config
    [[ "$output" == *"IF-MIB"* ]]
    [[ "$output" == *"HOST-RESOURCES-MIB"* ]]
}

@test "gen_config: ups does NOT include IF-MIB" {
    DEVICE_TYPE="ups"
    run gen_config
    [[ "$output" != *"IF-MIB"* ]]
}

@test "gen_config: ups includes UPS-MIB fields" {
    DEVICE_TYPE="ups"
    run gen_config
    [[ "$output" == *"UPS"* ]]
}

@test "gen_config: esxi does NOT include UPS-MIB fields" {
    DEVICE_TYPE="esxi"
    run gen_config
    [[ "$output" != *"UPS"* ]]
}

@test "gen_config: envmonitor does NOT include IF-MIB" {
    DEVICE_TYPE="envmonitor"
    run gen_config
    [[ "$output" != *"IF-MIB"* ]]
}
