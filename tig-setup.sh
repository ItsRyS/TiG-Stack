#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# TiG Stack Setup Script (Telegraf, InfluxDB, Grafana)
# Supports: Ubuntu, Debian, CentOS, RHEL, AlmaLinux, Rocky, Fedora, OpenSUSE/SLES
#
# Usage: sudo ./tig-setup.sh
# =============================================================================

export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

# ── Colour / log helpers ──────────────────────────────────────────────────
_green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
_yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
_cyan()   { printf '\033[0;36m%s\033[0m\n' "$*"; }

log()  { printf '\033[0;32m[%s] [INFO]  %s\033[0m\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
warn() { printf '\033[0;33m[%s] [WARN]  %s\033[0m\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
die()  { printf '\033[0;31m[ERROR] %s\033[0m\n' "$*" >&2; exit 1; }

# ── Global state ──────────────────────────────────────────────────────────
OS="" PKG_MGR="" CMD_PKG_UPDATE="" CMD_PKG_INSTALL=""
INFLUX_ORG="" INFLUX_BUCKET=""

# =============================================================================
# OS Detection
# =============================================================================
detect_os() {
    if [ ! -f /etc/os-release ]; then
        die "/etc/os-release not found. Unsupported OS."
    fi

    . /etc/os-release
    OS="${ID:-linux}"
    log "Detected OS: $OS (${VERSION_ID:-unknown})"

    case "$OS" in
        ubuntu|debian)
            PKG_MGR="apt-get"
            CMD_PKG_UPDATE="apt-get update -qq"
            CMD_PKG_INSTALL="apt-get install -y"
            ;;
        centos|rhel|almalinux|rocky|fedora|ol)
            PKG_MGR="dnf"
            CMD_PKG_UPDATE="dnf check-update || true"
            CMD_PKG_INSTALL="dnf install -y"
            ;;
        opensuse*|sles)
            PKG_MGR="zypper"
            CMD_PKG_UPDATE="zypper refresh"
            CMD_PKG_INSTALL="zypper install -y"
            ;;
        *)
            die "Unsupported OS: $OS"
            ;;
    esac
}

# =============================================================================
# Package helpers
# =============================================================================
pkg_install() {
    log "Installing: $*"
    $CMD_PKG_INSTALL "$@"
}

check_deps() {
    log "Checking dependencies..."
    local missing=""

    for cmd in curl openssl gpg; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done

    if [ -n "$missing" ]; then
        log "Installing missing deps:$missing"
        $CMD_PKG_UPDATE
        case "$PKG_MGR" in
            apt-get) pkg_install curl openssl gnupg ;;
            dnf)     pkg_install curl openssl gnupg2 ;;
            zypper)  pkg_install curl openssl gpg2 ;;
        esac
    else
        log "All dependencies satisfied."
    fi
}

# =============================================================================
# Docker Installation
# =============================================================================
install_docker() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        log "Docker + Compose already installed — skipping."
        return 0
    fi

    log "Installing Docker..."

    case "$PKG_MGR" in
        apt-get)
            $CMD_PKG_UPDATE
            pkg_install ca-certificates curl gnupg

            install -m 0755 -d /etc/apt/keyrings
            rm -f /etc/apt/keyrings/docker.gpg
            curl -fsSL "https://download.docker.com/linux/${OS}/gpg" \
                | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg

            . /etc/os-release
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${OS} ${VERSION_CODENAME} stable" \
                | tee /etc/apt/sources.list.d/docker.list >/dev/null

            $CMD_PKG_UPDATE
            pkg_install docker-ce docker-ce-cli containerd.io \
                        docker-buildx-plugin docker-compose-plugin
            ;;

        dnf)
            local repo_os="$OS"
            case "$OS" in almalinux|rocky|rhel|ol) repo_os="centos" ;; esac

            pkg_install dnf-plugins-core
            dnf config-manager --add-repo \
                "https://download.docker.com/linux/${repo_os}/docker-ce.repo"
            pkg_install docker-ce docker-ce-cli containerd.io \
                        docker-buildx-plugin docker-compose-plugin
            ;;

        zypper)
            zypper addrepo --check --refresh \
                https://download.docker.com/linux/sles/docker-ce.repo 2>/dev/null || true
            zypper --gpg-auto-import-keys refresh

            if ! zypper install -y docker-ce docker-ce-cli containerd.io \
                                   docker-buildx-plugin docker-compose-plugin; then
                warn "Docker CE failed — falling back to distro packages"
                pkg_install docker
                zypper install -y docker-compose-plugin 2>/dev/null || _install_compose_binary
            fi
            ;;
    esac

    _start_docker
    _add_user_to_docker_group
}

_install_compose_binary() {
    local dest="/usr/local/lib/docker/cli-plugins"
    mkdir -p "$dest"
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
        -o "$dest/docker-compose"
    chmod +x "$dest/docker-compose"
    ln -sf "$dest/docker-compose" /usr/local/bin/docker-compose
    log "Docker Compose binary installed."
}

_start_docker() {
    if systemctl --version >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        systemctl enable --now docker
        return
    fi

    if command -v service >/dev/null 2>&1; then
        service docker start || true
    fi

    if ! docker info >/dev/null 2>&1; then
        if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
            die "Docker failed to start in WSL.
  Fix: add [boot] systemd=true to /etc/wsl.conf then run: wsl --shutdown"
        fi
        die "Docker failed to start. Check: journalctl -u docker"
    fi
}

_add_user_to_docker_group() {
    local target_user="${SUDO_USER:-$USER}"
    if [ -n "$target_user" ] && [ "$target_user" != "root" ]; then
        getent group docker >/dev/null 2>&1 || groupadd docker
        usermod -aG docker "$target_user"
        log "User '$target_user' added to docker group."
    fi
}

# =============================================================================
# Firewall
# =============================================================================
configure_firewall() {
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        log "Configuring UFW (ports 8086, 3000)..."
        ufw allow 8086/tcp >/dev/null
        ufw allow 3000/tcp >/dev/null

    elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        log "Configuring Firewalld (ports 8086, 3000)..."
        firewall-cmd --permanent --add-port=8086/tcp >/dev/null
        firewall-cmd --permanent --add-port=3000/tcp >/dev/null
        firewall-cmd --reload >/dev/null

    else
        log "No active firewall detected — skipping firewall config."
    fi
}

# =============================================================================
# Interactive credential collection
# =============================================================================
collect_credentials() {
    log "Collecting InfluxDB credentials..."
    printf '\n'

    # Username
    if [ ! -f .env.influxdb-admin-username ]; then
        while true; do
            read -r -p "  InfluxDB Admin Username: " admuser
            if [ -n "$admuser" ]; then break; fi
            warn "Username cannot be empty."
        done
        printf '%s' "$admuser" > .env.influxdb-admin-username
        log "Username saved."
    else
        log "Username file exists — skipping."
    fi

    # Password
    if [ ! -f .env.influxdb-admin-password ]; then
        while true; do
            read -r -s -p "  InfluxDB Admin Password (min 8 chars): " admpass
            printf '\n'
            if [ "${#admpass}" -ge 8 ]; then break; fi
            warn "Password must be at least 8 characters."
        done
        printf '%s' "$admpass" > .env.influxdb-admin-password
        log "Password saved."
    else
        log "Password file exists — skipping."
    fi

    # Token (auto-generate)
    if [ ! -f .env.influxdb-admin-token ]; then
        printf '%s' "$(openssl rand -hex 32)" > .env.influxdb-admin-token
        log "Token generated and saved."
    else
        log "Token file exists — skipping."
    fi

    # Org
    if [ -z "$INFLUX_ORG" ]; then
        read -r -p "  InfluxDB Org name [myorg]: " input_org
        INFLUX_ORG="${input_org:-myorg}"
    fi

    # Bucket
    if [ -z "$INFLUX_BUCKET" ]; then
        read -r -p "  InfluxDB Bucket name [monitoring]: " input_bucket
        INFLUX_BUCKET="${input_bucket:-monitoring}"
    fi

    printf '\n'
    log "Org: $INFLUX_ORG  |  Bucket: $INFLUX_BUCKET"
}

# =============================================================================
# Config file generation
# =============================================================================
gen_configs() {
    log "Generating config files..."

    mkdir -p influxdb/data influxdb/config telegraf-config/telegraf.d mibs

    # ── telegraf.conf ──────────────────────────────────────────────────────
    if [ ! -f telegraf-config/telegraf.conf ]; then
        cat > telegraf-config/telegraf.conf << EOF
[global_tags]
  server_name = "$(hostname)"

[agent]
  interval            = "30s"
  round_interval      = true
  metric_batch_size   = 1000
  metric_buffer_limit = 10000
  collection_jitter   = "0s"
  flush_interval      = "10s"
  flush_jitter        = "0s"
  precision           = "0s"
  hostname            = ""
  omit_hostname       = false
EOF
        log "Created telegraf-config/telegraf.conf"
    fi

    # ── 000-influxdb.conf (output) ─────────────────────────────────────────
    local token
    token=$(cat .env.influxdb-admin-token)
    cat > telegraf-config/telegraf.d/000-influxdb.conf << EOF
[[outputs.influxdb_v2]]
  urls         = ["http://influxdb:8086"]
  token        = "$token"
  organization = "${INFLUX_ORG}"
  bucket       = "${INFLUX_BUCKET}"
EOF
    log "Created telegraf-config/telegraf.d/000-influxdb.conf"

    # ── 100-inputs.conf (host metrics) ────────────────────────────────────
    if [ ! -f telegraf-config/telegraf.d/100-inputs.conf ]; then
        cat > telegraf-config/telegraf.d/100-inputs.conf << 'EOF'
[[inputs.cpu]]
  percpu          = true
  totalcpu        = true
  collect_cpu_time = false
  report_active   = false

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.diskio]]

[[inputs.mem]]

[[inputs.net]]

[[inputs.system]]
EOF
        log "Created telegraf-config/telegraf.d/100-inputs.conf"
    fi

    # ── docker-compose.yml ─────────────────────────────────────────────────
    cat > docker-compose.yml << EOF
services:
  influxdb:
    image: influxdb:latest
    container_name: influxdb
    ports: ["8086:8086"]
    environment:
      INFLUXDB_HTTP_AUTH_ENABLED: "true"
      DOCKER_INFLUXDB_INIT_MODE: setup
      DOCKER_INFLUXDB_INIT_USERNAME_FILE: /run/secrets/influxdb-admin-username
      DOCKER_INFLUXDB_INIT_PASSWORD_FILE: /run/secrets/influxdb-admin-password
      DOCKER_INFLUXDB_INIT_ADMIN_TOKEN_FILE: /run/secrets/influxdb-admin-token
      DOCKER_INFLUXDB_INIT_ORG: ${INFLUX_ORG}
      DOCKER_INFLUXDB_INIT_BUCKET: ${INFLUX_BUCKET}
    secrets:
      - influxdb-admin-username
      - influxdb-admin-password
      - influxdb-admin-token
    volumes:
      - ./influxdb/data:/var/lib/influxdb2
      - ./influxdb/config:/etc/influxdb2
    restart: unless-stopped

  grafana:
    image: grafana/grafana-oss:latest
    container_name: grafana
    ports: ["3000:3000"]
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - influxdb
    restart: unless-stopped

  telegraf:
    image: telegraf:latest
    container_name: telegraf
    depends_on:
      - influxdb
    volumes:
      - ./telegraf-config/telegraf.d:/etc/telegraf/telegraf.d:ro
      - ./telegraf-config/telegraf.conf:/etc/telegraf/telegraf.conf:ro
      - /usr/share/snmp/mibs:/usr/share/snmp/mibs:ro
      - /etc/snmp/snmp.conf:/etc/snmp/snmp.conf:ro
      - ./mibs:/etc/telegraf/mibs:ro
    environment:
      MIBDIRS: "/usr/share/snmp/mibs:/etc/telegraf/mibs"
    restart: unless-stopped

volumes:
  influxdb-data:
  influxdb-config:
  grafana-data:

secrets:
  influxdb-admin-username:
    file: .env.influxdb-admin-username
  influxdb-admin-password:
    file: .env.influxdb-admin-password
  influxdb-admin-token:
    file: .env.influxdb-admin-token

networks:
  default:
    name: tig-network
EOF
    log "Created docker-compose.yml"
}

# =============================================================================
# SNMP MIBs
# =============================================================================
install_mibs() {
    log "Installing SNMP MIBs..."

    case "$PKG_MGR" in
        apt-get)
            DEBIAN_FRONTEND=noninteractive pkg_install snmp snmpd snmp-mibs-downloader \
                2>/dev/null || pkg_install snmp snmpd || true
            ;;
        dnf)
            pkg_install net-snmp net-snmp-utils net-snmp-libs 2>/dev/null || \
            pkg_install net-snmp net-snmp-utils || true
            ;;
        zypper)
            pkg_install net-snmp 2>/dev/null || true
            ;;
    esac

    # Enable all MIBs
    local conf="/etc/snmp/snmp.conf"
    mkdir -p "$(dirname "$conf")"
    if ! grep -q "^mibs +ALL" "$conf" 2>/dev/null; then
        printf '\n# Added by tig-setup.sh\nmibs +ALL\n' >> "$conf"
        log "Enabled mibs +ALL in $conf"
    else
        log "mibs +ALL already set."
    fi
}

# =============================================================================
# Start services + health check
# =============================================================================
start_services() {
    log "Pulling images and starting services..."
    docker compose pull
    docker compose up -d

    log "Waiting for InfluxDB to be healthy..."
    local count=0 retries=30
    until curl -sf "http://localhost:8086/health" | grep -q '"status":"pass"'; do
        sleep 2
        count=$((count+1))
        printf '.'
        if [ "$count" -ge "$retries" ]; then
            printf '\n'
            die "InfluxDB did not become healthy after $((retries*2))s. Check: docker compose logs influxdb"
        fi
    done
    printf '\n'
    log "InfluxDB is healthy."

    # Verify all containers running
    local failed=""
    for svc in influxdb grafana telegraf; do
        if ! docker compose ps "$svc" 2>/dev/null | grep -q "Up"; then
            failed="$failed $svc"
        fi
    done
    if [ -n "$failed" ]; then
        warn "These services may not be running:$failed"
        warn "Check with: docker compose logs"
    fi
}

# =============================================================================
# Summary
# =============================================================================
print_summary() {
    local token
    token=$(cat .env.influxdb-admin-token)
    local host_ip
    host_ip=$(hostname -I 2>/dev/null | awk '{print $1}') || host_ip="localhost"

    printf '\n'
    _cyan "════════════════════════════════════════════════════════"
    _green "  TiG Stack — Installation Complete"
    _cyan "════════════════════════════════════════════════════════"
    printf '\n'
    printf '  %-12s %s\n' "Grafana:"  "http://${host_ip}:3000  (admin / admin)"
    printf '  %-12s %s\n' "InfluxDB:" "http://${host_ip}:8086"
    printf '  %-12s %s\n' "Org:"      "$INFLUX_ORG"
    printf '  %-12s %s\n' "Bucket:"   "$INFLUX_BUCKET"
    printf '  %-12s %s\n' "Token:"    "$token"
    printf '\n'
    _yellow "Next steps:"
    printf '  1. Add SNMP devices:\n'
    printf '     ./tigadd.sh add --type switch --name <n> --ip <ip> --snmp-version v2c --community <c>\n\n'
    printf '  2. List monitored devices:\n'
    printf '     ./tigadd.sh list\n\n'
    printf '  3. Change Grafana password:\n'
    printf '     http://%s:3000  →  Profile → Change Password\n\n' "$host_ip"
    _cyan "════════════════════════════════════════════════════════"
    printf '\n'
}

# =============================================================================
# Entry point
# =============================================================================
main() {
    _cyan "TiG Stack Setup"
    printf '\n'

    detect_os
    check_deps
    install_docker
    configure_firewall
    collect_credentials
    gen_configs
    install_mibs
    start_services
    print_summary
}

main "$@"