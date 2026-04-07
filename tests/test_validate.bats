#!/usr/bin/env bats
# =============================================================================
# tests/test_validate.bats — Unit tests for lib/validate.sh
# Run: bats tests/test_validate.bats
# =============================================================================

SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
    source "$SCRIPT_DIR/lib/common.sh"
    source "$SCRIPT_DIR/lib/validate.sh"

    # Override die() to print to stdout so bats can capture it
    die() { printf '[ERROR] %s\n' "$*"; exit 1; }

    # Valid defaults — individual tests override what they need
    DEVICE_TYPE="switch"
    DEVICE_NAME="test-sw-01"
    DEVICE_IP="192.168.1.1"
    SNMP_VERSION="v2c"
    COMMUNITY="public"
    SEC_NAME="" AUTH_PASS="" PRIV_PASS=""
    SEC_LEVEL="authPriv"
    AUTH_PROTO="SHA256" PRIV_PROTO="AES256"
}

# ── Required fields ──────────────────────────────────────────────────────────

@test "validate: missing --type fails" {
    DEVICE_TYPE=""
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing --type"* ]]
}

@test "validate: missing --name fails" {
    DEVICE_NAME=""
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing --name"* ]]
}

@test "validate: missing --ip fails" {
    DEVICE_IP=""
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing --ip"* ]]
}

@test "validate: missing --snmp-version fails" {
    SNMP_VERSION=""
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing --snmp-version"* ]]
}

@test "validate: all required fields missing reports all errors" {
    DEVICE_TYPE="" DEVICE_NAME="" DEVICE_IP="" SNMP_VERSION=""
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"4 error"* ]]
}

# ── Device type ───────────────────────────────────────────────────────────────

@test "validate: unknown device type fails" {
    DEVICE_TYPE="printer"
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown --type 'printer'"* ]]
}

@test "validate: all known device types pass" {
    for t in switch router firewall server-linux server-windows ups envmonitor esxi; do
        DEVICE_TYPE="$t"
        run validate
        [ "$status" -eq 0 ] || fail "Expected type '$t' to pass, got status $status"
    done
}

# ── IP address ────────────────────────────────────────────────────────────────

@test "validate: IP with too few octets fails" {
    DEVICE_IP="10.0.0"
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid IP"* ]]
}

@test "validate: IP with out-of-range octet fails" {
    DEVICE_IP="999.999.999.999"
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid IP"* ]]
}

@test "validate: hostname instead of IP fails" {
    DEVICE_IP="my-switch.local"
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid IP"* ]]
}

@test "validate: valid IPs pass" {
    for ip in "10.0.0.1" "192.168.100.254" "172.16.0.1"; do
        DEVICE_IP="$ip"
        run validate
        [ "$status" -eq 0 ] || fail "Expected IP '$ip' to pass"
    done
}

# ── Device name ───────────────────────────────────────────────────────────────

@test "validate: device name with spaces fails" {
    DEVICE_NAME="my switch"
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"only letters, numbers, hyphens, underscores"* ]]
}

@test "validate: device name with special chars fails" {
    DEVICE_NAME="sw@01"
    run validate
    [ "$status" -eq 1 ]
}

@test "validate: device name with hyphens and underscores passes" {
    DEVICE_NAME="core-sw_01"
    run validate
    [ "$status" -eq 0 ]
}

# ── SNMP version ──────────────────────────────────────────────────────────────

@test "validate: unknown SNMP version fails" {
    SNMP_VERSION="v4"
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown --snmp-version"* ]]
}

@test "validate: v1, v2c, v3 all pass" {
    for ver in v1 v2c v3; do
        SNMP_VERSION="$ver"
        # v3 needs sec-name
        if [ "$ver" = "v3" ]; then
            SEC_NAME="monitor" AUTH_PASS="Auth1234!" PRIV_PASS="Priv1234!"
        fi
        run validate
        [ "$status" -eq 0 ] || fail "Expected SNMP version '$ver' to pass"
    done
}

# ── SNMPv3 specifics ──────────────────────────────────────────────────────────

@test "validate: v3 without --sec-name fails" {
    SNMP_VERSION="v3"
    SEC_NAME="" AUTH_PASS="Auth1234!" PRIV_PASS="Priv1234!"
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires --sec-name"* ]]
}

@test "validate: v3 authPriv without --auth-pass fails" {
    SNMP_VERSION="v3"
    SEC_NAME="monitor" SEC_LEVEL="authPriv"
    AUTH_PASS="" PRIV_PASS="Priv1234!"
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"--auth-pass required"* ]]
}

@test "validate: v3 authPriv without --priv-pass fails" {
    SNMP_VERSION="v3"
    SEC_NAME="monitor" SEC_LEVEL="authPriv"
    AUTH_PASS="Auth1234!" PRIV_PASS=""
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"--priv-pass required"* ]]
}

@test "validate: v3 noAuthNoPriv needs only sec-name" {
    SNMP_VERSION="v3"
    SEC_NAME="monitor" SEC_LEVEL="noAuthNoPriv"
    AUTH_PASS="" PRIV_PASS=""
    run validate
    [ "$status" -eq 0 ]
}

@test "validate: v3 authNoPriv needs sec-name and auth-pass" {
    SNMP_VERSION="v3"
    SEC_NAME="monitor" SEC_LEVEL="authNoPriv"
    AUTH_PASS="Auth1234!" PRIV_PASS=""
    run validate
    [ "$status" -eq 0 ]
}

@test "validate: v3 invalid sec-level fails" {
    SNMP_VERSION="v3"
    SEC_NAME="monitor" SEC_LEVEL="superSecure"
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown --sec-level"* ]]
}

# ── Happy path ────────────────────────────────────────────────────────────────

@test "validate: valid v2c config passes" {
    DEVICE_TYPE="switch" DEVICE_NAME="core-sw" DEVICE_IP="10.0.0.1"
    SNMP_VERSION="v2c" COMMUNITY="private"
    run validate
    [ "$status" -eq 0 ]
}

@test "validate: valid v3 authPriv config passes" {
    DEVICE_TYPE="server-linux" DEVICE_NAME="web-srv-01" DEVICE_IP="10.0.1.5"
    SNMP_VERSION="v3" SEC_NAME="monitor" SEC_LEVEL="authPriv"
    AUTH_PASS="Auth1234!" PRIV_PASS="Priv1234!"
    run validate
    [ "$status" -eq 0 ]
}
