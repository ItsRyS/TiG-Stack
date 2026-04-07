#!/usr/bin/env bash
# =============================================================================
# lib/common.sh — Colour helpers, logging, shared defaults
# Source this file; do not execute directly.
# =============================================================================

# ── Colour / log ──────────────────────────────────────────────────────────
_green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
_yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
_cyan()   { printf '\033[0;36m%s\033[0m\n' "$*"; }
_bold()   { printf '\033[1m%s\033[0m'      "$*"; }

log()  { printf '\033[0;32m[%s] [INFO]  %s\033[0m\n' "$(date +'%H:%M:%S')" "$*"; }
warn() { printf '\033[0;33m[%s] [WARN]  %s\033[0m\n' "$(date +'%H:%M:%S')" "$*"; }
die()  { printf '\033[0;31m[%s] [ERROR] %s\033[0m\n' "$(date +'%H:%M:%S')" "$*" >&2; exit 1; }

# ── Shared defaults ───────────────────────────────────────────────────────
DEVICE_TYPE="" DEVICE_NAME="" DEVICE_IP="" SNMP_VERSION=""
SNMP_PORT="161" SNMP_TIMEOUT="5s" SNMP_RETRIES="3" POLL_INTERVAL="60s"
OUTPUT_DIR="./telegraf-config/telegraf.d"
DRY_RUN="false" FORCE="false"
COMMUNITY="public"
SEC_NAME="" AUTH_PROTO="SHA256" AUTH_PASS=""
PRIV_PROTO="AES256" PRIV_PASS="" SEC_LEVEL="authPriv"

# ── Edit override tracking ────────────────────────────────────────────────
# Tracks which flags were explicitly set by the user (used by cmd_edit)
_EDIT_OVERRIDES=""

# ── Telegraf reload ───────────────────────────────────────────────────────
NO_RELOAD="false"

_telegraf_reload() {
    if [ "$NO_RELOAD" = "true" ]; then return; fi

    # Must be in a directory with docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        _yellow "Tip: run 'docker compose restart telegraf' to apply changes."
        return
    fi

    # Check telegraf container is actually running
    local state
    state=$(docker compose ps --format '{{.Name}} {{.State}}' 2>/dev/null \
        | grep telegraf | awk '{print $2}') || true

    if [ "$state" != "running" ]; then
        _yellow "Telegraf is not running — skipping reload."
        return
    fi

    printf '\n'; log "Reloading Telegraf..."
    if docker compose restart telegraf >/dev/null 2>&1; then
        _green "✔ Telegraf reloaded."
    else
        warn "Reload failed — run manually: docker compose restart telegraf"
    fi
}

# ── InfluxDB connection (auto-detect from TiG-Stack files) ────────────────
INFLUX_URL="http://localhost:8086"
INFLUX_TOKEN=""
INFLUX_BUCKET=""
INFLUX_ORG=""

influx_load_config() {
    # Token
    if [ -z "$INFLUX_TOKEN" ] && [ -f ".env.influxdb-admin-token" ]; then
        INFLUX_TOKEN=$(cat .env.influxdb-admin-token | tr -d '[:space:]')
    fi

    # Bucket — parse from docker-compose.yml
    if [ -z "$INFLUX_BUCKET" ] && [ -f "docker-compose.yml" ]; then
        INFLUX_BUCKET=$(grep 'DOCKER_INFLUXDB_INIT_BUCKET' docker-compose.yml \
            | head -1 | sed 's/.*: *//' | tr -d '"[:space:]')
    fi

    # Org — parse from docker-compose.yml
    if [ -z "$INFLUX_ORG" ] && [ -f "docker-compose.yml" ]; then
        INFLUX_ORG=$(grep 'DOCKER_INFLUXDB_INIT_ORG' docker-compose.yml \
            | head -1 | sed 's/.*: *//' | tr -d '"[:space:]')
    fi

    # Org fallback — query InfluxDB API
    if [ -z "$INFLUX_ORG" ] && [ -n "$INFLUX_TOKEN" ]; then
        INFLUX_ORG=$(curl -sf --max-time 3 \
            -H "Authorization: Token ${INFLUX_TOKEN}" \
            "${INFLUX_URL}/api/v2/orgs" 2>/dev/null \
            | grep -o '"name":"[^"]*"' | head -1 \
            | sed 's/"name":"//;s/"//g') || true
    fi
}