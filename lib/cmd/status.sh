#!/usr/bin/env bash
# =============================================================================
# lib/cmd/status.sh — "tigadd status" command
# Requires: common.sh sourced first
# =============================================================================

_status_row() {
    local component="$1" status="$2" detail="${3:-}"
    printf '%-16s  ' "$component"
    case "$status" in
        "● "*) printf '\033[0;32m%-20s\033[0m' "$status" ;;
        "✗ "*) printf '\033[0;31m%-20s\033[0m' "$status" ;;
        *)     printf '\033[0;90m%-20s\033[0m' "$status" ;;
    esac
    [ -n "$detail" ] && printf '  %s' "$detail"
    printf '\n'
}

cmd_status() {
    influx_load_config

    printf '\n'
    printf '\033[1m%-16s  %-20s  %s\033[0m\n' "COMPONENT" "STATUS" "DETAIL"
    printf '%s\n' "──────────────────────────────────────────────────────────────"

    # ── Docker daemon ─────────────────────────────────────────────────────────
    if ! docker info >/dev/null 2>&1; then
        _status_row "Docker" "✗ Not running" "install or start Docker"
        printf '%s\n\n' "──────────────────────────────────────────────────────────────"
        warn "Docker is required — cannot check stack services."
        return 1
    fi
    _status_row "Docker" "● Running" ""

    # ── docker-compose.yml ────────────────────────────────────────────────────
    if [ ! -f "docker-compose.yml" ]; then
        _status_row "Stack" "✗ Not deployed" "run: sudo ./tig-setup.sh"
        printf '%s\n\n' "──────────────────────────────────────────────────────────────"
        return 1
    fi

    # ── Container states ──────────────────────────────────────────────────────
    local svc state
    for svc in influxdb telegraf grafana; do
        state=$(docker compose ps --format '{{.Name}} {{.State}}' 2>/dev/null \
            | grep -w "$svc" | awk '{print $2}') || true
        case "$state" in
            running) _status_row "$svc"  "● Running"    "" ;;
            exited)  _status_row "$svc"  "✗ Exited"     "run: docker compose start $svc" ;;
            "")      _status_row "$svc"  "? Not found"  "" ;;
            *)       _status_row "$svc"  "? $state"     "" ;;
        esac
    done

    # ── InfluxDB API health ───────────────────────────────────────────────────
    local api_result curl_exit=0
    api_result=$(curl -sf --max-time 5 "${INFLUX_URL}/health" 2>/dev/null) || curl_exit=$?
    if [ "$curl_exit" -eq 0 ] && echo "$api_result" | grep -q '"status":"pass"'; then
        _status_row "InfluxDB API" "● Reachable" "${INFLUX_URL}"
    elif [ "$curl_exit" -eq 0 ]; then
        _status_row "InfluxDB API" "✗ Degraded"  "${INFLUX_URL}"
    else
        _status_row "InfluxDB API" "✗ Unreachable" "${INFLUX_URL}"
    fi

    # ── Telegraf error check ──────────────────────────────────────────────────
    local tele_errors=0
    tele_errors=$(docker compose logs telegraf --tail=50 2>/dev/null \
        | grep -c '\[E!\]') || tele_errors=0
    if [ "$tele_errors" -eq 0 ]; then
        _status_row "Telegraf logs" "● No errors"         "last 50 lines"
    else
        _status_row "Telegraf logs" "✗ ${tele_errors} error(s)" \
            "run: docker compose logs telegraf"
    fi

    printf '%s\n\n' "──────────────────────────────────────────────────────────────"
}
