#!/usr/bin/env bash
# =============================================================================
# lib/cmd/list.sh — "tigadd list" command
# =============================================================================

_parse_conf() {
    local file="$1"

    PARSED_NAME=""  PARSED_TYPE="" PARSED_IP="" PARSED_SNMP_VER=""
    PARSED_COMMUNITY="" PARSED_SEC_NAME=""

    PARSED_NAME=$(grep '^# Device  :' "$file"            | sed 's/^# Device  : *//')            || true
    PARSED_TYPE=$(grep '^# Telegraf SNMP Input —' "$file" | sed 's/.*— *//' | tr '[:upper:]' '[:lower:]') || true
    PARSED_SNMP_VER=$(grep '^# SNMP    :' "$file"        | sed 's/^# SNMP    : *//' | tr '[:upper:]' '[:lower:]') || true
    PARSED_IP=$(grep 'agents.*=.*udp://' "$file"         | sed 's/.*udp:\/\///' | sed 's/:[0-9]*.*//') || true
    PARSED_COMMUNITY=$(grep '^\s*community\s*=' "$file"  | head -1 | sed 's/.*= *"//' | sed 's/".*//') || true
    PARSED_SEC_NAME=$(grep '^\s*sec_name\s*=' "$file"    | head -1 | sed 's/.*= *"//' | sed 's/".*//') || true
}

_check_influx_status() {
    local device_name="$1"

    if [ -z "$INFLUX_TOKEN" ] || [ -z "$INFLUX_BUCKET" ]; then
        echo "? Unknown"
        return
    fi

    # Single query: get last data point within 5m
    local flux_query result last_ts
    flux_query="from(bucket: \"${INFLUX_BUCKET}\")
  |> range(start: -5m)
  |> filter(fn: (r) => r.device_name == \"${device_name}\")
  |> last()
  |> keep(columns: [\"_time\"])
  |> limit(n: 1)"

    result=$(curl -sf --max-time 5 \
        -H "Authorization: Token ${INFLUX_TOKEN}" \
        -H "Content-Type: application/vnd.flux" \
        "${INFLUX_URL}/api/v2/query?org=${INFLUX_ORG}" \
        --data-raw "$flux_query" 2>/dev/null) || true

    # Extract timestamp from CSV result (skip comment/header lines)
    last_ts=$(echo "$result" | grep -v '^#\|^,result\|^$\|_time' | \
        grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:]*Z' | head -1) || true

    if [ -n "$last_ts" ]; then
        local now_ts last_epoch diff_sec ago
        now_ts=$(date -u +%s)
        last_epoch=$(date -u -d "$last_ts" +%s 2>/dev/null) || true
        if [ -n "$last_epoch" ]; then
            diff_sec=$(( now_ts - last_epoch ))
            if   [ "$diff_sec" -lt 60 ];   then ago="${diff_sec}s ago"
            elif [ "$diff_sec" -lt 3600 ];  then ago="$(( diff_sec / 60 ))m ago"
            else                                 ago="$(( diff_sec / 3600 ))h ago"
            fi
            echo "● Active (${ago})"
        else
            echo "● Active"
        fi
    elif [ -n "$result" ]; then
        # Query reached InfluxDB but no data in last 5m — check 24h
        local flux_query_24h result_24h
        flux_query_24h="from(bucket: \"${INFLUX_BUCKET}\")
  |> range(start: -24h)
  |> filter(fn: (r) => r.device_name == \"${device_name}\")
  |> last()
  |> keep(columns: [\"_time\"])
  |> limit(n: 1)"

        result_24h=$(curl -sf --max-time 5 \
            -H "Authorization: Token ${INFLUX_TOKEN}" \
            -H "Content-Type: application/vnd.flux" \
            "${INFLUX_URL}/api/v2/query?org=${INFLUX_ORG}" \
            --data-raw "$flux_query_24h" 2>/dev/null) || true

        last_ts=$(echo "$result_24h" | grep -v '^#\|^,result\|^$\|_time' | \
            grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:]*Z' | head -1) || true

        if [ -n "$last_ts" ]; then
            local now_ts last_epoch diff_sec ago
            now_ts=$(date -u +%s)
            last_epoch=$(date -u -d "$last_ts" +%s 2>/dev/null) || true
            if [ -n "$last_epoch" ]; then
                diff_sec=$(( now_ts - last_epoch ))
                if   [ "$diff_sec" -lt 3600 ]; then ago="$(( diff_sec / 60 ))m ago"
                else                                ago="$(( diff_sec / 3600 ))h ago"
                fi
                echo "✗ No data (last: ${ago})"
            else
                echo "✗ No data (>5m)"
            fi
        else
            echo "✗ No data (>5m)"
        fi
    else
        echo "? Unknown"
    fi
}

_colour_status() {
    local s="$1"
    case "$s" in
        "● Active"*)  printf '\033[0;32m%-20s\033[0m' "$s" ;;
        "✗ No data"*) printf '\033[0;33m%-20s\033[0m' "$s" ;;
        *)            printf '\033[0;90m%-20s\033[0m' "$s" ;;
    esac
}

cmd_list() {
    influx_load_config

    local files=()
    for f in "${OUTPUT_DIR}"/[0-9][0-9][0-9]-snmp-*.conf; do
        if [ -e "$f" ]; then files+=("$f"); fi
    done

    if [ "${#files[@]}" -eq 0 ]; then
        warn "No SNMP device configs found in: $OUTPUT_DIR"
        printf '  Run: ./tigadd.sh add --type switch --name <n> --ip <ip> ...\n\n'
        return
    fi

    local influx_ok="true"
    if [ -z "$INFLUX_TOKEN" ]; then
        influx_ok="false"
        warn "InfluxDB token not found — status shows '? Unknown'"
        warn "Tip: run from TiG-Stack directory (where .env.influxdb-admin-token exists)"
    fi

    printf '\n'
    printf '\033[1m%-20s  %-15s  %-16s  %-5s  %s\033[0m\n' \
        "NAME" "TYPE" "IP" "SNMP" "STATUS"
    printf '%s\n' "──────────────────────────────────────────────────────────────────"

    local total=0 active=0 nodata=0 unknown=0 status

    for f in "${files[@]}"; do
        _parse_conf "$f"
        status=$(_check_influx_status "$PARSED_NAME")

        total=$((total+1))
        case "$status" in
            "● Active"*)  active=$((active+1))  ;;
            "✗ No data"*) nodata=$((nodata+1))  ;;
            *)            unknown=$((unknown+1)) ;;
        esac

        printf '%-20s  %-15s  %-16s  %-5s  ' \
            "$PARSED_NAME" "$PARSED_TYPE" "$PARSED_IP" "$PARSED_SNMP_VER"
        _colour_status "$status"
        printf '\n'
    done

    printf '%s\n' "──────────────────────────────────────────────────────────────────"
    printf 'Total: %s  ' "$total"
    printf '\033[0;32m● %s active\033[0m  '   "$active"
    printf '\033[0;33m✗ %s no data\033[0m  '  "$nodata"
    printf '\033[0;90m? %s unknown\033[0m\n\n' "$unknown"
}