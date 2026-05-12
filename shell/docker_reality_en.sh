#!/usr/bin/env bash
# docker_reality_en.sh — Docker-based VLESS-Reality standalone launcher (no domain required)
# Usage: bash shell/docker_reality_en.sh [options]
export LANG=en_US.UTF-8

# ---------------------------------------------------------------------------
# Output helper — style consistent with echoContent in install.sh
# ---------------------------------------------------------------------------
echoContent() {
    case $1 in
    "red")
        printf "\033[31m%s\033[0m\n" "$2"
        ;;
    "skyBlue")
        printf "\033[1;36m%s\033[0m\n" "$2"
        ;;
    "green")
        printf "\033[32m%s\033[0m\n" "$2"
        ;;
    "white")
        printf "\033[37m%s\033[0m\n" "$2"
        ;;
    "magenta")
        printf "\033[35m%s\033[0m\n" "$2"
        ;;
    "yellow")
        printf "\033[33m%s\033[0m\n" "$2"
        ;;
    esac
}

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
nonInteractive=0
dataDir="/etc/v2ray-agent/docker/"
installMode=""
port=""
xhttpPort=""
xhttpPath=""
serverName=""
privateKey=""
uuid=""
email=""
generateOnly=0
startOnly=0
skipSelfInstall=0

# ---------------------------------------------------------------------------
# QA override: set V2RAY_AGENT_FORCE_NO_DOCKER=1 to skip Docker check in tests
# ---------------------------------------------------------------------------
forceNoDocker="${V2RAY_AGENT_FORCE_NO_DOCKER:-0}"

# ---------------------------------------------------------------------------
# showHelp — print usage and exit
# ---------------------------------------------------------------------------
showHelp() {
    echoContent "skyBlue" "docker_reality_en.sh — Run VLESS-Reality via Docker (no domain required)"
    echoContent "white" ""
    echoContent "white" "Usage:"
    echoContent "white" "  bash shell/docker_reality_en.sh [options]"
    echoContent "white" ""
    echoContent "white" "Run modes:"
    echoContent "white" "  Default / interactive     Detect install state first, then show install/reinstall/start menu options"
    echoContent "white" "  --non-interactive         Non-interactive mode; exit with error if required values are missing"
    echoContent "white" "  --generate-only           Generate config and summary files only, then exit"
    echoContent "white" "  --start-only              Reuse existing config and only start/recreate the container"
    echoContent "white" "  --skip-self-install       Skip script relocation and vasmad shortcut creation"
    echoContent "white" ""
    echoContent "white" "Options:"
    echoContent "white" "  --non-interactive           Run non-interactively; all required values must be supplied via flags"
    echoContent "white" "  --data-dir <path>           Persistent config/data directory (default: /etc/v2ray-agent/docker/)"
    echoContent "white" "  --install-mode <mode>       Install mode: vision / xhttp / all"
    echoContent "white" "  --port <port>               Vision or single-protocol external listen port (leave blank to pick randomly)"
    echoContent "white" "  --xhttp-port <port>         XHTTP mode port (leave blank to pick randomly)"
    echoContent "white" "  --xhttp-path <path>         XHTTP path base value (rendered as /<path>xHTTP)"
    echoContent "white" "  --server-name <sni>         SNI / server name used for Reality handshake"
    echoContent "white" "  --private-key <key>         X25519 private key (auto-generated if blank)"
    echoContent "white" "  --uuid <uuid>               Client UUID (auto-generated if blank)"
    echoContent "white" "  --email <email>             Contact email stored in the config"
    echoContent "white" "  --generate-only             Generate config and keys then exit without starting Docker"
    echoContent "white" "  --start-only                Skip config generation and start Docker with existing config"
    echoContent "white" "  --skip-self-install         Skip script relocation and vasmad shortcut creation"
    echoContent "white" "  -h, --help                  Show this help and exit"
    echoContent "white" ""
    echoContent "white" "Notes:"
    echoContent "white" "  1. Interactive mode checks both config.json and the v2ray-agent-docker container before showing a menu."
    echoContent "white" "  2. If both are missing, it shows an install menu; if either exists, it shows view-account / reinstall / start-or-recreate options."
    echoContent "white" "  3. Install mode selects Reality Vision, Reality XHTTP, or both; XHTTP requires an additional path input."
    echoContent "white" "  4. Non-interactive mode requires all values explicitly; privateKey/uuid/email may still be auto-generated/derived."
    echoContent "white" "  5. Data directory defaults to /etc/v2ray-agent/docker/; override with --data-dir for QA or custom paths."
    echoContent "white" "  6. If the script is not running from /etc/v2ray-agent/docker_reality_en.sh, it will relocate itself and create the vasmad shortcut."
    echoContent "white" ""
    echoContent "yellow" "QA / Testing:"
    echoContent "white" "  V2RAY_AGENT_FORCE_NO_DOCKER=1  Skip Docker availability check (test environments)"
    echoContent "white" "  --data-dir /tmp/v2ray-agent/docker  Example path override for isolated verification"
    exit "${1:-0}"
}

# jsonEscape — escape a string for safe insertion into JSON.
jsonEscape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "${value}"
}

# validateDataDirPath — reject obviously unsafe data-dir path forms (for root-run scenarios).
validateDataDirPath() {
    local path="$1"
    if [[ -z "${path}" || "${path}" != /* || "${path}" == *:* ]]; then
        echoContent "red" "--data-dir must be an absolute path without colons"
        exit 1
    fi

    if [[ -e "${path}" && -L "${path}" ]]; then
        echoContent "red" "--data-dir must not be a symbolic link: ${path}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# promptValue — interactive prompt; pressing Enter keeps the current value
# ---------------------------------------------------------------------------
promptValue() {
    local promptMessage="$1"
    local currentValue="$2"
    local inputValue

    printf '%b' "${promptMessage}" >/dev/tty
    read -r inputValue </dev/tty
    if [[ -n "${inputValue}" ]]; then
        printf '%s' "${inputValue}"
    else
        printf '%s' "${currentValue}"
    fi
}

# initRandomPath — generate a 4-character random path base value, close to install.sh style.
initRandomPath() {
    local chars="abcdefghijklmnopqrstuvwxyz"
    local randomPath=""
    local _idx
    for _idx in 1 2 3 4; do
        randomPath+="${chars:RANDOM%${#chars}:1}"
    done
    printf '%s' "${randomPath}"
}

# normalizeInstallMode — normalise install mode, defaulting to vision for backward compatibility.
normalizeInstallMode() {
    local rawMode="$1"
    case "${rawMode}" in
    "")
        if [[ -n "${port}" && ( -n "${xhttpPort}" || -n "${xhttpPath}" ) ]]; then
            resolvedInstallMode="all"
        elif [[ -n "${xhttpPort}" || -n "${xhttpPath}" ]]; then
            resolvedInstallMode="xhttp"
        else
            resolvedInstallMode="vision"
        fi
        ;;
    vision | xhttp | all)
        resolvedInstallMode="${rawMode}"
        ;;
    *)
        echoContent "red" "Invalid install mode: ${rawMode} (must be vision / xhttp / all)"
        exit 1
        ;;
    esac
}

# normalizeXHTTPPath — normalise the XHTTP path base value; the xHTTP suffix is appended at render time.
normalizeXHTTPPath() {
    local rawPath="$1"
    local normalized="${rawPath#/}"

    while [[ "${normalized}" == */ ]]; do
        normalized="${normalized%/}"
    done
    if [[ "${normalized}" == *xHTTP ]]; then
        normalized="${normalized%xHTTP}"
    fi
    if [[ -z "${normalized}" ]]; then
        normalized="$(initRandomPath)"
    fi
    if [[ "${normalized}" == *ws ]]; then
        echoContent "red" "XHTTP path base must not end with 'ws' — it conflicts with the legacy ws path convention in install.sh"
        exit 1
    fi
    resolvedXHTTPPath="${normalized}"
}

# renderXHTTPPath — render the path base value into the /<path>xHTTP form used by install.sh.
renderXHTTPPath() {
    printf '/%sxHTTP' "$1"
}

installModeHasVision() {
    [[ "$1" == "vision" || "$1" == "all" ]]
}

installModeHasXHTTP() {
    [[ "$1" == "xhttp" || "$1" == "all" ]]
}

# ---------------------------------------------------------------------------
# promptInteractiveValues — collect missing values in interactive mode
# ---------------------------------------------------------------------------
promptInteractiveValues() {
    if [[ "${startOnly}" == "1" || "${nonInteractive}" == "1" ]]; then
        return 0
    fi

    echoContent "skyBlue" ""
    echoContent "skyBlue" "─── Configuration Input ─────────────────────────────────"
    echoContent "white"   "Docker is ready. Please enter each configuration value."
    echoContent "white"   "Press Enter to accept the default behaviour shown in brackets."
    echoContent "skyBlue" "────────────────────────────────────────────────────────"

    if [[ -z "${installMode}" ]]; then
        echoContent "yellow" "1. Reality Vision"
        echoContent "yellow" "2. Reality XHTTP"
        echoContent "yellow" "3. Install both"
        case "$(promptValue $'\n[Step 1/8] Install mode [1-3]: ' "")" in
        1) installMode="vision" ;;
        2) installMode="xhttp" ;;
        3) installMode="all" ;;
        *)
            echoContent "red" "Invalid selection. Please enter 1 / 2 / 3"
            exit 1
            ;;
        esac
    fi

    normalizeInstallMode "${installMode}"

    if installModeHasVision "${resolvedInstallMode}"; then
        if [[ -z "${port}" ]]; then
            port="$(promptValue $'\n[Step 2/8] Vision port  [leave blank to pick randomly from 10000-30000]: ' "")"
            if [[ -z "${port}" ]]; then
                port=""
            fi
        fi
    fi

    if installModeHasXHTTP "${resolvedInstallMode}"; then
        if [[ -z "${xhttpPort}" ]]; then
            xhttpPort="$(promptValue $'\n[Step 3/8] XHTTP port  [leave blank to pick randomly from 10000-30000]: ' "")"
            if [[ -z "${xhttpPort}" ]]; then
                xhttpPort=""
            fi
        fi
        if [[ -z "${xhttpPath}" ]]; then
            xhttpPath="$(promptValue $'\n[Step 4/8] XHTTP path  [e.g. alone, leave blank to auto-generate]: ' "")"
        fi
    fi

    if [[ -z "${serverName}" ]]; then
        serverName="$(promptValue $'\n[Step 5/8] Server name  [leave blank to pick a random Reality target]: ' "")"
    fi
    if [[ -z "${privateKey}" ]]; then
        privateKey="$(promptValue $'\n[Step 6/8] Private key  [leave blank to auto-generate]: ' "")"
    fi
    if [[ -z "${uuid}" ]]; then
        uuid="$(promptValue $'\n[Step 7/8] UUID  [leave blank to auto-generate]: ' "")"
    fi
    if [[ -z "${email}" ]]; then
        email="$(promptValue $'\n[Step 8/8] Email base name  [leave blank to derive from UUID]: ' "")"
    fi
    echoContent "white" ""
}

# ---------------------------------------------------------------------------
# parseCli — parse command-line arguments
# ---------------------------------------------------------------------------
parseCli() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --non-interactive)
            nonInteractive=1
            shift
            ;;
        --data-dir)
            if [[ $# -lt 2 || -z "${2:-}" || "${2:0:1}" == "-" || "${2}" == *:* || "${2}" != /* ]]; then
                echoContent "red" "--data-dir requires a path value"
                exit 1
            fi
            dataDir="$2"
            validateDataDirPath "${dataDir}"
            shift 2
            ;;
        --install-mode)
            if [[ $# -lt 2 || -z "${2:-}" || "${2:0:1}" == "-" ]]; then
                echoContent "red" "--install-mode requires a value (vision / xhttp / all)"
                exit 1
            fi
            installMode="$2"
            shift 2
            ;;
        --port)
            if [[ $# -lt 2 || ( -n "${2:-}" && "${2:0:1}" == "-" ) ]]; then
                echoContent "red" "--port requires a numeric value"
                exit 1
            fi
            port="$2"
            shift 2
            ;;
        --xhttp-port)
            if [[ $# -lt 2 || ( -n "${2:-}" && "${2:0:1}" == "-" ) ]]; then
                echoContent "red" "--xhttp-port requires a numeric value"
                exit 1
            fi
            xhttpPort="$2"
            shift 2
            ;;
        --xhttp-path)
            if [[ $# -lt 2 || ( -n "${2:-}" && "${2:0:1}" == "-" ) ]]; then
                echoContent "red" "--xhttp-path requires a value"
                exit 1
            fi
            xhttpPath="$2"
            shift 2
            ;;
        --server-name)
            if [[ $# -lt 2 || ( -n "${2:-}" && "${2:0:1}" == "-" ) ]]; then
                echoContent "red" "--server-name requires a value"
                exit 1
            fi
            serverName="$2"
            shift 2
            ;;
        --private-key)
            if [[ $# -lt 2 || ( -n "${2:-}" && "${2:0:1}" == "-" ) ]]; then
                echoContent "red" "--private-key requires a value"
                exit 1
            fi
            privateKey="$2"
            shift 2
            ;;
        --uuid)
            if [[ $# -lt 2 || ( -n "${2:-}" && "${2:0:1}" == "-" ) ]]; then
                echoContent "red" "--uuid requires a value"
                exit 1
            fi
            uuid="$2"
            shift 2
            ;;
        --email)
            if [[ $# -lt 2 || ( -n "${2:-}" && "${2:0:1}" == "-" ) ]]; then
                echoContent "red" "--email requires a value"
                exit 1
            fi
            email="$2"
            shift 2
            ;;
        --generate-only)
            generateOnly=1
            shift
            ;;
        --start-only)
            startOnly=1
            shift
            ;;
        --skip-self-install)
            skipSelfInstall=1
            shift
            ;;
        -h | --help)
            showHelp
            ;;
        *)
            echoContent "red" "Unknown option: $1"
            showHelp 1
            ;;
        esac
    done

}

# ---------------------------------------------------------------------------
# checkEnvironment — require Linux and root/sudo
# ---------------------------------------------------------------------------
checkEnvironment() {
    local osType
    osType="$(uname -s 2>/dev/null || true)"
    if [[ "${osType}" != "Linux" ]]; then
        echoContent "red" "This script requires a Linux host (detected: ${osType})"
        exit 1
    fi

    if [[ "$(id -u)" != "0" ]]; then
        echoContent "red" "This script must be run as root or with sudo"
        exit 1
    fi
}

# selfInstallShortcut — mirror install.sh aliasInstall behavior for this standalone script and create the vasmad shortcut.
selfInstallShortcut() {
    local targetScript="/etc/v2ray-agent/docker_reality_en.sh"
    local currentScript=""
    local shortcutCreated="false"

    if [[ "${skipSelfInstall}" == "1" ]]; then
        return 0
    fi

    currentScript=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$0" 2>/dev/null || true)
    if [[ -z "${currentScript}" ]]; then
        currentScript="$0"
    fi

    mkdir -p /etc/v2ray-agent

    if [[ "${currentScript}" != "${targetScript}" ]]; then
        if ! mv "${currentScript}" "${targetScript}" 2>/dev/null; then
            echoContent "yellow" "Unable to move the script automatically to ${targetScript}; continuing from the current path."
        else
            chmod 700 "${targetScript}"
            currentScript="${targetScript}"
            echoContent "green" "Script moved to ${targetScript}"
        fi
    else
        chmod 700 "${targetScript}"
    fi

    if [[ -f "${targetScript}" ]]; then
        if [[ -d "/usr/bin/" ]]; then
            rm -f /usr/bin/vasmad
            ln -s "${targetScript}" /usr/bin/vasmad
            chmod 700 /usr/bin/vasmad
            shortcutCreated="true"
        fi

        if [[ -d "/usr/sbin/" ]]; then
            rm -f /usr/sbin/vasmad
            ln -s "${targetScript}" /usr/sbin/vasmad
            chmod 700 /usr/sbin/vasmad
            shortcutCreated="true"
        fi
    fi

    if [[ "${shortcutCreated}" == "true" ]]; then
        echoContent "green" "Shortcut created successfully. Execute [vasmad] to reopen the script"
        echoContent "yellow" "Launch command: vasmad"
    fi
}

# ---------------------------------------------------------------------------
# installDocker — download and run the official Docker convenience install script
# ---------------------------------------------------------------------------
installDocker() {
    echoContent "white" "Downloading Docker install script from https://get.docker.com ..."
    local tmpScript
    tmpScript="$(mktemp /tmp/get-docker-XXXXXX.sh)"
    if ! curl -fsSL https://get.docker.com -o "${tmpScript}"; then
        echoContent "red" "Failed to download Docker install script from https://get.docker.com"
        rm -f "${tmpScript}"
        return 1
    fi
    echoContent "white" "Running Docker install script..."
    if ! sh "${tmpScript}"; then
        echoContent "red" "Docker installation failed"
        rm -f "${tmpScript}"
        return 1
    fi
    rm -f "${tmpScript}"
    echoContent "green" "Docker installed successfully"
    return 0
}

# checkDocker — verify Docker is installed and running; prompt to install if missing
checkDocker() {
    # QA override: V2RAY_AGENT_FORCE_NO_DOCKER=1 forces the Docker-missing branch
    if [[ "${forceNoDocker}" == "1" ]]; then
        echoContent "yellow" "[QA] V2RAY_AGENT_FORCE_NO_DOCKER=1: simulating Docker not installed"
        _promptDockerInstall
        return $?
    fi

    echoContent "white" "Checking Docker availability..."

    if ! command -v docker >/dev/null 2>&1; then
        echoContent "yellow" "Docker is not installed on this system"
        _promptDockerInstall
        return $?
    fi

    # Docker binary exists — verify the daemon is reachable
    if ! docker info >/dev/null 2>&1; then
        echoContent "red" "Docker is installed but the daemon is not running"
        echoContent "white" "Please start the Docker daemon (e.g.: systemctl start docker) and retry"
        exit 1
    fi

    echoContent "green" "Docker is available and running"
    return 0
}

# _promptDockerInstall — ask the user whether to install Docker; exit cleanly on refusal
_promptDockerInstall() {
    local answer
    if [[ "${nonInteractive}" == "1" ]]; then
        echoContent "red" "Docker is required but not installed. Use interactive mode, or set V2RAY_AGENT_FORCE_NO_DOCKER for QA only."
        exit 1
    fi

    echoContent "yellow" "Docker is required to run this script."
    answer="$(promptValue $'\033[33mInstall Docker now via https://get.docker.com? [y/N]: \033[0m' "")"
    case "${answer}" in
    [yY] | [yY][eE][sS])
        if ! installDocker; then
            echoContent "red" "Docker installation failed, exiting."
            exit 1
        fi
        # Verify the daemon started after installation
        if ! docker info >/dev/null 2>&1; then
            echoContent "yellow" "Docker installed but daemon not yet running, starting..."
            systemctl start docker 2>/dev/null || true
            sleep 2
            if ! docker info >/dev/null 2>&1; then
                echoContent "red" "Docker daemon failed to start. Please start it manually and retry."
                exit 1
            fi
        fi
        echoContent "green" "Docker is ready"
        ;;
    *)
        echoContent "white" "Docker installation declined, exiting."
        exit 0
        ;;
    esac
}

# ---------------------------------------------------------------------------
# xrayImagePreflight — validate a config file using the official Xray image
# Usage: xrayImagePreflight <config-file-path>
# ---------------------------------------------------------------------------
xrayImagePreflight() {
    local configFile="$1"
    local xrayImage="ghcr.io/xtls/xray-core:26.5.9"

    if [[ -z "${configFile}" ]]; then
        echoContent "red" "xrayImagePreflight: config file path is required"
        return 1
    fi

    if [[ ! -f "${configFile}" ]]; then
        echoContent "red" "xrayImagePreflight: config file not found: ${configFile}"
        return 1
    fi

    echoContent "white" "Pulling Xray image ${xrayImage} (if not cached)..."
    docker pull "${xrayImage}" >/dev/null 2>&1 || true

    echoContent "white" "Validating config: docker run --rm --user root -v \"${configFile}:/usr/local/etc/xray/config.json:ro\" ${xrayImage} run -test -c /usr/local/etc/xray/config.json"
    if docker run --rm \
        --user root \
        -v "${configFile}:/usr/local/etc/xray/config.json:ro" \
        "${xrayImage}" \
        run -test -c /usr/local/etc/xray/config.json; then
        echoContent "green" "Xray config validation passed"
        return 0
    else
        echoContent "red" "Xray config validation failed"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Value generation helpers
# ---------------------------------------------------------------------------

# _realityDomainList — curated Reality target domain list, kept in sync with install.sh:9618
# Returns a comma-separated domain string (Xray-core list)
_realityDomainList() {
    printf '%s' "download-installer.cdn.mozilla.net,addons.mozilla.org,s0.awsstatic.com,d1.awsstatic.com,images-na.ssl-images-amazon.com,m.media-amazon.com,player.live-video.net,one-piece.com,lol.secure.dyn.riotcdn.net,www.lovelive-anime.jp,academy.nvidia.com,dl.google.com,www.google-analytics.com,www.caltech.edu,www.calstatela.edu,www.suny.edu,www.suffolk.edu,www.python.org,vuejs-jp.org,vuejs.org,zh-hk.vuejs.org,react.dev,www.java.com,www.oracle.com,www.mysql.com,www.mongodb.com,redis.io,cname.vercel-dns.com,vercel-dns.com,www.swift.com,academy.nvidia.com,www.swift.com,www.cisco.com,www.asus.com,www.samsung.com,www.amd.com,www.umcg.nl,www.fom-international.com,www.u-can.co.jp,github.io"
}

# parsePort — validate and normalise a port value.
# Usage: parsePort <raw-port>
# Sets global: resolvedPort
# Returns 0 on success, 1 on invalid input.
parsePort() {
    local raw="$1"
    if [[ -z "${raw}" ]]; then
        # Blank → pick randomly from 10000-30000 (aligned with install.sh:9711)
        resolvedPort=$((RANDOM % 20001 + 10000))
        echoContent "yellow" "No port provided — randomly selected: ${resolvedPort}"
        return 0
    fi
    # Must be a positive integer
    if ! [[ "${raw}" =~ ^[0-9]+$ ]]; then
        echoContent "red" "Invalid port '${raw}': must be a positive integer"
        return 1
    fi
    if [[ "${raw}" -lt 1 || "${raw}" -gt 65535 ]]; then
        echoContent "red" "Invalid port '${raw}': must be in range 1-65535"
        return 1
    fi
    resolvedPort="${raw}"
    return 0
}

# checkPortInUse — exit if the port is occupied by a process other than the v2ray-agent-docker container
# (aligned with install.sh:1951-1957).
# On re-run the script does docker rm -f v2ray-agent-docker before recreating,
# so a port held only by that container is not a real conflict.
# Usage: checkPortInUse <port>
checkPortInUse() {
    local p="$1"
    if ! command -v lsof >/dev/null 2>&1; then
        return 0
    fi
    # Collect PIDs listening on this port
    local listenPids
    listenPids=$(lsof -i "tcp:${p}" -sTCP:LISTEN -t 2>/dev/null || true)
    [[ -z "${listenPids}" ]] && return 0

    # Check whether the existing v2ray-agent-docker container holds the port.
    # If the container exists, its published ports are managed by docker-proxy.
    # If all listening PIDs belong to that container's docker-proxy processes, allow the port.
    local containerExists=0
    if docker ps -a --filter "name=^/v2ray-agent-docker$" --format '{{.Names}}' 2>/dev/null \
            | grep -q "^v2ray-agent-docker$"; then
        containerExists=1
    fi

    if [[ "${containerExists}" == "1" ]]; then
        # Verify all listening PIDs are docker-proxy processes (Docker's forwarder for published ports).
        # If any PID is not docker-proxy, the port is held by an unrelated process — a real conflict.
        local unrelatedPids=0
        local pid
        while IFS= read -r pid; do
            [[ -z "${pid}" ]] && continue
            local comm
            comm=$(cat "/proc/${pid}/comm" 2>/dev/null || ps -p "${pid}" -o comm= 2>/dev/null || true)
            if [[ "${comm}" != *"docker-proxy"* ]]; then
                unrelatedPids=1
                break
            fi
        done <<<"${listenPids}"

        if [[ "${unrelatedPids}" == "0" ]]; then
            # Port is held only by v2ray-agent-docker's docker-proxy — safe to continue
            echoContent "yellow" "Port ${p} is held by the existing v2ray-agent-docker container (will be replaced)"
            return 0
        fi
    fi

    echoContent "red" "Port ${p} is already in use — please free it and retry"
    lsof -i "tcp:${p}" -sTCP:LISTEN 2>/dev/null || true
    exit 1
}

# parseServerName — validate and normalise serverName / host:port input.
# Usage: parseServerName <raw-server-name>
# Sets globals: resolvedServerName, resolvedTargetPort
# Returns 0 on success.
parseServerName() {
    local raw="$1"
    if [[ -z "${raw}" ]]; then
        # Blank → pick randomly from the curated list (aligned with install.sh:9673-9678)
        local domainList count randomIdx
        domainList="$(_realityDomainList)"
        count=$(printf '%s' "${domainList}" | awk -F',' '{print NF}')
        randomIdx=$(( (RANDOM % count) + 1 ))
        resolvedServerName=$(printf '%s' "${domainList}" | awk -F',' -v n="${randomIdx}" '{print $n}')
        resolvedTargetPort=443
        echoContent "yellow" "No serverName provided — randomly selected: ${resolvedServerName}:${resolvedTargetPort}"
        return 0
    fi
    # Support host:port syntax (aligned with install.sh:9679-9682)
    if printf '%s' "${raw}" | grep -q ":"; then
        resolvedTargetPort=$(printf '%s' "${raw}" | awk -F: '{print $2}')
        resolvedServerName=$(printf '%s' "${raw}" | awk -F: '{print $1}')
    else
        resolvedServerName="${raw}"
        resolvedTargetPort=443
    fi
    return 0
}

# generatePrivateKey — generate an X25519 key pair via the pre-checked Xray Docker image.
# Usage: generatePrivateKey <xray-runtime-path>
# Sets globals: resolvedPrivateKey, resolvedPublicKey
# Returns 0 on success, 1 on failure.
generatePrivateKey() {
    local xrayRuntime="$1"
    local x25519Output
    if [[ -z "${xrayRuntime}" ]]; then
        echoContent "red" "generatePrivateKey: xray runtime path is required"
        return 1
    fi
    # xrayRuntime may be a Docker invocation string or a host binary path
    x25519Output=$(${xrayRuntime} x25519 2>/dev/null) || {
        echoContent "red" "Failed to generate X25519 key pair via: ${xrayRuntime} x25519"
        return 1
    }
    resolvedPrivateKey=$(printf '%s' "${x25519Output}" | awk -F': ' '/PrivateKey|Private key/ {print $2; exit}')
    resolvedPublicKey=$(printf '%s' "${x25519Output}" | awk -F': ' '/Password|Public key/ {print $2; exit}')
    if [[ -z "${resolvedPrivateKey}" ]]; then
        echoContent "red" "X25519 key generation produced no PrivateKey output"
        return 1
    fi
    echoContent "green" "Generated public key:  ${resolvedPublicKey}"
    return 0
}

# derivePublicKey — derive the public key from an existing private key via the Xray runtime.
# Usage: derivePublicKey <xray-runtime-path> <private-key>
# Sets global: resolvedPublicKey
# Returns 0 on success, 1 on failure.
derivePublicKey() {
    local xrayRuntime="$1"
    local privKey="$2"
    local x25519Output
    x25519Output=$(${xrayRuntime} x25519 -i "${privKey}" 2>/dev/null) || {
        echoContent "red" "Failed to derive public key from the provided private key"
        return 1
    }
    resolvedPublicKey=$(printf '%s' "${x25519Output}" | awk -F': ' '/Password|Public key/ {print $2; exit}')
    if [[ -z "${resolvedPublicKey}" ]]; then
        echoContent "red" "Provided private key is invalid — cannot derive public key"
        return 1
    fi
    return 0
}

# generateUUID — generate a UUID via the pre-checked Xray Docker image.
# Usage: generateUUID <xray-runtime-path>
# Sets global: resolvedUUID
# Returns 0 on success, 1 on failure.
generateUUID() {
    local xrayRuntime="$1"
    local uuidOutput
    if [[ -z "${xrayRuntime}" ]]; then
        echoContent "red" "generateUUID: xray runtime path is required"
        return 1
    fi
    uuidOutput=$(${xrayRuntime} uuid 2>/dev/null) || {
        echoContent "red" "Failed to generate UUID via: ${xrayRuntime} uuid"
        return 1
    }
    resolvedUUID=$(printf '%s' "${uuidOutput}" | tr -d '[:space:]')
    if [[ -z "${resolvedUUID}" ]]; then
        echoContent "red" "UUID generation produced empty output"
        return 1
    fi
    echoContent "green" "Generated UUID: ${resolvedUUID}"
    return 0
}

# deriveEmail — derive email base from the UUID prefix (aligned with install.sh:3842)
# Usage: deriveEmail <uuid>
# Sets global: resolvedEmail
deriveEmail() {
    local uuidVal="$1"
    # Take the part before the first '-'
    resolvedEmail="${uuidVal%%-*}"
}

# _xrayDockerRuntime — return the docker-run command prefix for the Xray image.
# This is the pre-checked runtime path used in value generation (no host binary assumed).
_xrayDockerRuntime() {
    printf '%s' "docker run --rm ghcr.io/xtls/xray-core:26.5.9"
}

# loadPersistedSummaryIfPresent — optionally read and validate client-summary.txt.
# Sets: persistedContainer, persistedInstallMode, persistedVisionPort, persistedXHTTPPort,
#       persistedXHTTPPath, persistedServerName, persistedPublicKey, persistedUUID,
#       persistedEmailBase, persistedVisionEmail, persistedXHTTPEmail,
#       persistedShortId, persistedConfigPath
loadPersistedSummaryIfPresent() {
    local summaryFile="${dataDir%/}/client-summary.txt"

    persistedContainer=""
    persistedInstallMode=""
    persistedVisionPort=""
    persistedXHTTPPort=""
    persistedXHTTPPath=""
    persistedServerName=""
    persistedPublicKey=""
    persistedUUID=""
    persistedEmailBase=""
    persistedVisionEmail=""
    persistedXHTTPEmail=""
    persistedShortId="6ba85179e30d4fc2"
    persistedConfigPath=""

    if [[ ! -f "${summaryFile}" ]]; then
        return 0
    fi

    while IFS= read -r line; do
        case "${line}" in
        container:\ *) persistedContainer="${line#container: }" ;;
        installMode:\ *) persistedInstallMode="${line#installMode: }" ;;
        visionPort:\ *) persistedVisionPort="${line#visionPort: }" ;;
        xhttpPort:\ *) persistedXHTTPPort="${line#xhttpPort: }" ;;
        xhttpPath:\ *) persistedXHTTPPath="${line#xhttpPath: }" ;;
        serverName:\ *) persistedServerName="${line#serverName: }" ;;
        publicKey:\ *) persistedPublicKey="${line#publicKey: }" ;;
        uuid:\ *) persistedUUID="${line#uuid: }" ;;
        emailBase:\ *) persistedEmailBase="${line#emailBase: }" ;;
        visionEmail:\ *) persistedVisionEmail="${line#visionEmail: }" ;;
        xhttpEmail:\ *) persistedXHTTPEmail="${line#xhttpEmail: }" ;;
        shortId:\ *) persistedShortId="${line#shortId: }" ;;
        configPath:\ *) persistedConfigPath="${line#configPath: }" ;;
        esac
    done <"${summaryFile}"

    persistedContainer="${persistedContainer#"${persistedContainer%%[![:space:]]*}"}"
    persistedInstallMode="${persistedInstallMode#"${persistedInstallMode%%[![:space:]]*}"}"
    persistedVisionPort="${persistedVisionPort#"${persistedVisionPort%%[![:space:]]*}"}"
    persistedXHTTPPort="${persistedXHTTPPort#"${persistedXHTTPPort%%[![:space:]]*}"}"
    persistedXHTTPPath="${persistedXHTTPPath#"${persistedXHTTPPath%%[![:space:]]*}"}"
    persistedServerName="${persistedServerName#"${persistedServerName%%[![:space:]]*}"}"
    persistedPublicKey="${persistedPublicKey#"${persistedPublicKey%%[![:space:]]*}"}"
    persistedUUID="${persistedUUID#"${persistedUUID%%[![:space:]]*}"}"
    persistedEmailBase="${persistedEmailBase#"${persistedEmailBase%%[![:space:]]*}"}"
    persistedVisionEmail="${persistedVisionEmail#"${persistedVisionEmail%%[![:space:]]*}"}"
    persistedXHTTPEmail="${persistedXHTTPEmail#"${persistedXHTTPEmail%%[![:space:]]*}"}"
    persistedShortId="${persistedShortId#"${persistedShortId%%[![:space:]]*}"}"
    persistedConfigPath="${persistedConfigPath#"${persistedConfigPath%%[![:space:]]*}"}"

    if [[ -n "${persistedContainer}" && "${persistedContainer}" != "v2ray-agent-docker" ]]; then
        echoContent "red" "Persisted summary container name mismatch: ${persistedContainer}"
        exit 1
    fi
    if [[ -n "${persistedConfigPath}" && "${persistedConfigPath}" != "${dataDir%/}/config.json" ]]; then
        echoContent "red" "Persisted summary configPath mismatch: ${persistedConfigPath}"
        exit 1
    fi
}

# loadPersistedStateFromConfig — restore protocol mode, ports, path, and display fields from config.json.
loadPersistedStateFromConfig() {
    local configFile="${dataDir%/}/config.json"
    local parsedLines=()

    if [[ ! -f "${configFile}" ]]; then
        echoContent "red" "Persisted config not found: ${configFile}"
        exit 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echoContent "red" "python3 is required to safely parse the persisted config.json"
        exit 1
    fi

    loadPersistedSummaryIfPresent

    mapfile -t parsedLines < <(python3 - <<'PY' "${configFile}"
import json, sys

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
except Exception:
    sys.exit(1)

vision_port = ''
xhttp_port = ''
xhttp_path = ''
server_name = ''
public_key = ''
uuid = ''
vision_email = ''
xhttp_email = ''

for inbound in data.get('inbounds', []):
    tag = inbound.get('tag')
    port = inbound.get('port')
    if tag == 'dokodemo-in-VLESSReality' and isinstance(port, int):
        vision_port = str(port)
    elif tag == 'VLESSRealityXHTTP' and isinstance(port, int):
        xhttp_port = str(port)
        xhttp_settings = (inbound.get('streamSettings') or {}).get('xhttpSettings') or {}
        raw_path = xhttp_settings.get('path') or ''
        if raw_path.startswith('/'):
            raw_path = raw_path[1:]
        if raw_path.endswith('xHTTP'):
            raw_path = raw_path[:-5]
        xhttp_path = raw_path.rstrip('/')

for inbound in data.get('inbounds', []):
    if inbound.get('protocol') != 'vless':
        continue
    settings = inbound.get('settings') or {}
    clients = settings.get('clients') or []
    if not clients:
        continue
    stream_settings = inbound.get('streamSettings') or {}
    reality_settings = stream_settings.get('realitySettings') or {}
    server_names = reality_settings.get('serverNames') or []
    if not server_name and server_names:
        server_name = server_names[0]
    if not public_key:
        public_key = reality_settings.get('publicKey') or ''
    if not uuid:
        uuid = clients[0].get('id') or ''

    network = stream_settings.get('network')
    if network == 'tcp':
        vision_email = clients[0].get('email') or ''
    elif network == 'xhttp':
        xhttp_email = clients[0].get('email') or ''

if vision_port and xhttp_port:
    install_mode = 'all'
elif vision_port:
    install_mode = 'vision'
elif xhttp_port:
    install_mode = 'xhttp'
else:
    sys.exit(1)

print(install_mode)
print(vision_port)
print(xhttp_port)
print(xhttp_path)
print(server_name)
print(public_key)
print(uuid)
print(vision_email)
print(xhttp_email)
PY
)

    if [[ ${#parsedLines[@]} -ne 9 ]]; then
        echoContent "red" "Persisted config format error: cannot read protocol state from ${configFile}"
        exit 1
    fi

    persistedInstallMode="${parsedLines[0]}"
    persistedVisionPort="${parsedLines[1]}"
    persistedXHTTPPort="${parsedLines[2]}"
    persistedXHTTPPath="${parsedLines[3]}"
    persistedServerName="${parsedLines[4]}"
    persistedPublicKey="${parsedLines[5]}"
    persistedUUID="${parsedLines[6]}"
    persistedVisionEmail="${parsedLines[7]}"
    persistedXHTTPEmail="${parsedLines[8]}"

    if [[ -z "${persistedEmailBase}" ]]; then
        persistedEmailBase="${persistedUUID%%-*}"
    fi
    if installModeHasVision "${persistedInstallMode}" && [[ -z "${persistedVisionEmail}" ]]; then
        persistedVisionEmail="${persistedEmailBase}-VLESS_TCP/TLS_Vision"
    fi
    if installModeHasXHTTP "${persistedInstallMode}" && [[ -z "${persistedXHTTPEmail}" ]]; then
        persistedXHTTPEmail="${persistedEmailBase}-VLESS_Reality_XHTTP"
    fi

    case "${persistedInstallMode}" in
    vision)
        [[ -n "${persistedVisionPort}" ]] || { echoContent "red" "Persisted config missing Vision port"; exit 1; }
        ;;
    xhttp)
        [[ -n "${persistedXHTTPPort}" && -n "${persistedXHTTPPath}" ]] || { echoContent "red" "Persisted config missing XHTTP port or path"; exit 1; }
        ;;
    all)
        [[ -n "${persistedVisionPort}" && -n "${persistedXHTTPPort}" && -n "${persistedXHTTPPath}" ]] || { echoContent "red" "Persisted config missing fields for 'all' install mode"; exit 1; }
        ;;
    *)
        echoContent "red" "Invalid install mode in persisted config: ${persistedInstallMode}"
        exit 1
        ;;
    esac
}

# loadPersistedPort — restore protocol mode and ports from persisted config.
loadPersistedPort() {
    loadPersistedStateFromConfig
}

# getPublicIP — try to resolve the current host's public IP for account display output.
getPublicIP() {
    local currentIP=""

    if command -v curl >/dev/null 2>&1; then
        currentIP=$(curl -fsS -4 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep '^ip=' | awk -F '=' '{print $2}')
        if [[ -z "${currentIP}" ]]; then
            currentIP=$(curl -fsS -6 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep '^ip=' | awk -F '=' '{print $2}')
        fi
        if [[ -z "${currentIP}" ]]; then
            currentIP=$(curl -fsS https://api.ipify.org 2>/dev/null || true)
        fi
    fi

    if [[ -z "${currentIP}" ]]; then
        currentIP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    fi

    printf '%s' "${currentIP}"
}

# loadPersistedAccountInfo — restore account fields needed for display from summary (preferred) or config.json.
# Sets: persistedInstallMode, persistedVisionPort, persistedXHTTPPort, persistedXHTTPPath,
#       persistedServerName, persistedPublicKey, persistedUUID, persistedEmailBase,
#       persistedVisionEmail, persistedXHTTPEmail, persistedShortId
loadPersistedAccountInfo() {
    local configFile="${dataDir%/}/config.json"

    if [[ ! -f "${configFile}" ]]; then
        echoContent "red" "Persisted config not found: ${configFile}"
        exit 1
    fi

    # Prefer summary file (most complete field set)
    loadPersistedSummaryIfPresent

    # Fall back to config.json for any missing critical fields
    if [[ -z "${persistedInstallMode}" || -z "${persistedServerName}" || -z "${persistedUUID}" || -z "${persistedPublicKey}" ]]; then
        if ! command -v python3 >/dev/null 2>&1; then
            echoContent "red" "python3 is required to safely parse the persisted config.json"
            exit 1
        fi

        local parsedLines=()
        mapfile -t parsedLines < <(python3 - <<'PY' "${configFile}"
import json, sys

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
except Exception:
    sys.exit(1)

vision_port = ''
xhttp_port = ''
xhttp_path = ''
server_name = ''
public_key = ''
uuid = ''
vision_email = ''
xhttp_email = ''

for inbound in data.get('inbounds', []):
    tag = inbound.get('tag')
    port = inbound.get('port')
    if tag == 'dokodemo-in-VLESSReality' and isinstance(port, int):
        vision_port = str(port)
    elif tag == 'VLESSRealityXHTTP' and isinstance(port, int):
        xhttp_port = str(port)
        xhttp_settings = (inbound.get('streamSettings') or {}).get('xhttpSettings') or {}
        raw_path = xhttp_settings.get('path') or ''
        if raw_path.startswith('/'):
            raw_path = raw_path[1:]
        if raw_path.endswith('xHTTP'):
            raw_path = raw_path[:-5]
        xhttp_path = raw_path.rstrip('/')

for inbound in data.get('inbounds', []):
    if inbound.get('protocol') != 'vless':
        continue
    settings = inbound.get('settings') or {}
    clients = settings.get('clients') or []
    if not clients:
        continue
    stream_settings = inbound.get('streamSettings') or {}
    reality_settings = stream_settings.get('realitySettings') or {}
    server_names = reality_settings.get('serverNames') or []
    if not server_name and server_names:
        server_name = server_names[0]
    if not public_key:
        public_key = reality_settings.get('publicKey') or ''
    if not uuid:
        uuid = clients[0].get('id') or ''
    network = stream_settings.get('network')
    if network == 'tcp' and not vision_email:
        vision_email = clients[0].get('email') or ''
    elif network == 'xhttp' and not xhttp_email:
        xhttp_email = clients[0].get('email') or ''

if vision_port and xhttp_port:
    install_mode = 'all'
elif vision_port:
    install_mode = 'vision'
elif xhttp_port:
    install_mode = 'xhttp'
else:
    sys.exit(1)

print(install_mode)
print(vision_port)
print(xhttp_port)
print(xhttp_path)
print(server_name)
print(public_key)
print(uuid)
print(vision_email)
print(xhttp_email)
PY
)

        if [[ ${#parsedLines[@]} -ne 9 ]]; then
            echoContent "red" "Persisted config format error: failed to read account info from ${configFile}"
            exit 1
        fi

        [[ -z "${persistedInstallMode}" ]] && persistedInstallMode="${parsedLines[0]}"
        [[ -z "${persistedVisionPort}" ]]  && persistedVisionPort="${parsedLines[1]}"
        [[ -z "${persistedXHTTPPort}" ]]   && persistedXHTTPPort="${parsedLines[2]}"
        [[ -z "${persistedXHTTPPath}" ]]   && persistedXHTTPPath="${parsedLines[3]}"
        [[ -z "${persistedServerName}" ]]  && persistedServerName="${parsedLines[4]}"
        [[ -z "${persistedPublicKey}" ]]   && persistedPublicKey="${parsedLines[5]}"
        [[ -z "${persistedUUID}" ]]        && persistedUUID="${parsedLines[6]}"
        [[ -z "${persistedVisionEmail}" ]] && persistedVisionEmail="${parsedLines[7]}"
        [[ -z "${persistedXHTTPEmail}" ]]  && persistedXHTTPEmail="${parsedLines[8]}"
    fi

    # Fill in any still-missing email fields
    if [[ -z "${persistedEmailBase}" && -n "${persistedUUID}" ]]; then
        persistedEmailBase="${persistedUUID%%-*}"
    fi
    if installModeHasVision "${persistedInstallMode}" && [[ -z "${persistedVisionEmail}" ]]; then
        persistedVisionEmail="${persistedEmailBase}-VLESS_TCP/TLS_Vision"
    fi
    if installModeHasXHTTP "${persistedInstallMode}" && [[ -z "${persistedXHTTPEmail}" ]]; then
        persistedXHTTPEmail="${persistedEmailBase}-VLESS_Reality_XHTTP"
    fi
}

# hasPersistedConfig — check whether a persisted config already exists under dataDir.
hasPersistedConfig() {
    local configFile="${dataDir%/}/config.json"
    [[ -f "${configFile}" ]]
}

# hasManagedContainer — check whether the target Docker container exists (running or stopped).
hasManagedContainer() {
    docker ps -a --filter "name=^/v2ray-agent-docker$" --format '{{.Names}}' 2>/dev/null | grep -q '^v2ray-agent-docker$'
}

# hasExistingInstallState — treat either config presence or container presence as existing/residual install state.
hasExistingInstallState() {
    if hasPersistedConfig || hasManagedContainer; then
        return 0
    fi
    return 1
}

# uninstallDockerReality — remove the standalone Docker Reality container, data, script shortcut, and installed script copy.
uninstallDockerReality() {
    local answer=""
    local installedScript="/etc/v2ray-agent/docker_reality_en.sh"

    answer="$(promptValue $'Confirm uninstall of Docker Reality content? [y/N]: ' "")"
    case "${answer}" in
    [yY] | [yY][eE][sS])
        ;;
    *)
        echoContent "green" " ---> Uninstall cancelled"
        return 0
        ;;
    esac

    if hasManagedContainer; then
        docker rm -f v2ray-agent-docker >/dev/null 2>&1 || true
        echoContent "green" " ---> Docker container removed"
    fi

    rm -rf "${dataDir%/}" >/dev/null 2>&1 || true
    echoContent "green" " ---> Docker Reality data directory removed"

    rm -rf /usr/bin/vasmad >/dev/null 2>&1 || true
    rm -rf /usr/sbin/vasmad >/dev/null 2>&1 || true
    echoContent "green" " ---> Shortcut removed"

    if [[ -f "${installedScript}" ]]; then
        rm -f "${installedScript}" >/dev/null 2>&1 || true
        echoContent "green" " ---> Installed script removed"
    fi

    exit 0
}

# promptExistingInstallAction — offer an interactive menu based on combined config/container state.
promptExistingInstallAction() {
    local action=""
    local hasConfig=1
    local hasContainer=1

    if [[ "${nonInteractive}" == "1" || "${startOnly}" == "1" || "${generateOnly}" == "1" ]]; then
        return 0
    fi

    if hasPersistedConfig; then
        hasConfig=0
    fi
    if hasManagedContainer; then
        hasContainer=0
    fi

    echoContent "skyBlue" ""
    if [[ ${hasConfig} -ne 0 && ${hasContainer} -ne 0 ]]; then
        echoContent "skyBlue" "─── No Existing Docker Reality Installation Detected ───────────────"
        echoContent "white" "No config file or container was detected. Choose the next action:"
        echoContent "yellow" "1. Install"
        echoContent "yellow" "2. Exit"

        while true; do
            action="$(promptValue $'Choose [1-2]: ' "")"
            case "${action}" in
            1)
                echoContent "yellow" "Install selected. The script will collect values and create the container."
                return 0
                ;;
            2)
                echoContent "white" "Exiting without changes."
                exit 0
                ;;
            *)
                echoContent "red" "Invalid selection. Please enter 1-2."
                ;;
            esac
        done
    fi

    echoContent "skyBlue" "─── Existing/Residual Docker Reality State Detected ───────────────"
    if [[ ${hasConfig} -eq 0 && ${hasContainer} -eq 0 ]]; then
        echoContent "white" "Detected both the config file and the container. Choose the next action:"
    elif [[ ${hasConfig} -eq 0 ]]; then
        echoContent "white" "Detected the config file but not the container. Choose the next action:"
    else
        echoContent "white" "Detected the container but not the config file. Choose the next action:"
    fi
    echoContent "yellow" "1. View account"
    echoContent "yellow" "2. Reinstall"
    echoContent "yellow" "3. Start/Recreate container"
    echoContent "yellow" "4. Uninstall"
    echoContent "yellow" "5. Exit"

    while true; do
        action="$(promptValue $'Choose [1-5]: ' "")"
        case "${action}" in
        1)
            if hasPersistedConfig; then
                showClientInfo
                exit 0
            else
                echoContent "red" "No existing config was found, so the account cannot be shown. Please reinstall first."
            fi
            ;;
        2)
            echoContent "yellow" "Reinstall selected. The script will collect new values and recreate the container."
            return 0
            ;;
        3)
            if ! hasExistingInstallState; then
                echoContent "red" "No installed state was detected, so the container cannot be started/recreated. Please install first."
                continue
            fi
            if ! hasPersistedConfig; then
                echoContent "red" "No existing config was found, so the container cannot be started/recreated. Please reinstall first."
                continue
            fi
            startOnly=1
            echoContent "yellow" "Using the existing config to start/recreate the container."
            return 0
            ;;
        4)
            uninstallDockerReality
            ;;
        5)
            echoContent "white" "Exiting without changes."
            exit 0
            ;;
        *)
            echoContent "red" "Invalid selection. Please enter 1-5."
            ;;
        esac
    done
}

# showVisionAccount — display the Vision account in a showAccounts-style layout.
# Args: $1=address $2=port $3=serverName $4=publicKey $5=uuid $6=email $7=shortId
showVisionAccount() {
    local displayAddress="$1"
    local displayPort="$2"
    local displayServerName="$3"
    local displayPublicKey="$4"
    local displayUUID="$5"
    local displayEmail="$6"
    local displayShortId="$7"
    local vlessLink qrData qrLink

    if [[ -z "${displayAddress}" ]]; then
        displayAddress="YOUR_SERVER_IP"
    fi

    vlessLink="vless://${displayUUID}@${displayAddress}:${displayPort}?encryption=none&security=reality&type=tcp&sni=${displayServerName}&fp=chrome&pbk=${displayPublicKey}&sid=${displayShortId}&flow=xtls-rprx-vision#${displayEmail}"
    qrData="${vlessLink//:/%3A}"
    qrData="${qrData//\//%2F}"
    qrData="${qrData//@/%40}"
    qrData="${qrData//\?/%3F}"
    qrData="${qrData//&/%26}"
    qrData="${qrData//#/%23}"
    qrData="${qrData//=/%3D}"
    qrLink="https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=${qrData}"

    echoContent "skyBlue" "============================= VLESS Reality Vision [Recommended] =============================="
    echoContent "skyBlue" ""
    echoContent "skyBlue" " ---> Account: ${displayEmail}"
    echoContent "white" ""
    echoContent "yellow" " ---> Universal Format (VLESS+reality+uTLS+Vision)"
    echoContent "green" "    ${vlessLink}"
    echoContent "white" ""
    echoContent "yellow" " ---> Formatted Plaintext (VLESS+reality+uTLS+Vision)"
    echoContent "green" "Protocol: VLESS reality, Address: ${displayAddress}, publicKey: ${displayPublicKey}, shortId: ${displayShortId}, serverNames: ${displayServerName}, Port: ${displayPort}, UserID: ${displayUUID}, Transport: tcp, Account: ${displayEmail}"
    echoContent "white" ""
    echoContent "yellow" " ---> QR Code VLESS (VLESS+reality+uTLS+Vision)"
    echoContent "green" "    ${qrLink}"
}

# showXHTTPAccount — display the XHTTP account in a showAccounts-style layout.
# Args: $1=address $2=port $3=serverName $4=publicKey $5=uuid $6=email $7=shortId $8=renderedPath
showXHTTPAccount() {
    local displayAddress="$1"
    local displayPort="$2"
    local displayServerName="$3"
    local displayPublicKey="$4"
    local displayUUID="$5"
    local displayEmail="$6"
    local displayShortId="$7"
    local displayPath="$8"
    local vlessLink qrLink

    if [[ -z "${displayAddress}" ]]; then
        displayAddress="YOUR_SERVER_IP"
    fi

    vlessLink="vless://${displayUUID}@${displayAddress}:${displayPort}?encryption=none&security=reality&type=xhttp&sni=${displayServerName}&host=${displayServerName}&fp=chrome&path=${displayPath}&pbk=${displayPublicKey}&sid=${displayShortId}#${displayEmail}"
    qrLink="https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${displayUUID}%40${displayAddress}%3A${displayPort}%3Fencryption%3Dnone%26security%3Dreality%26type%3Dxhttp%26sni%3D${displayServerName}%26fp%3Dchrome%26path%3D${displayPath}%26host%3D${displayServerName}%26pbk%3D${displayPublicKey}%26sid%3D${displayShortId}%23${displayEmail}"

    echoContent "skyBlue" "============================= VLESS Reality XHTTP =============================="
    echoContent "skyBlue" ""
    echoContent "skyBlue" " ---> Account: ${displayEmail}"
    echoContent "white" ""
    echoContent "yellow" " ---> Universal Format (VLESS+reality+xhttp)"
    echoContent "green" "    ${vlessLink}"
    echoContent "white" ""
    echoContent "yellow" " ---> Formatted Plaintext (VLESS+reality+xhttp)"
    echoContent "green" "Protocol: VLESS reality, Address: ${displayAddress}, publicKey: ${displayPublicKey}, shortId: ${displayShortId}, serverNames: ${displayServerName}, Port: ${displayPort}, Path: ${displayPath}, SNI: ${displayServerName}, Host: ${displayServerName}, UserID: ${displayUUID}, Transport: xhttp, Account: ${displayEmail}"
    echoContent "white" ""
    echoContent "yellow" " ---> QR Code VLESS (VLESS+reality+xhttp)"
    echoContent "green" "    ${qrLink}"
}

# resolveValues — resolve all CLI-supplied or blank values into resolved* globals.
# Depends on: installMode, port, xhttpPort, xhttpPath, serverName, privateKey, uuid, email
# Sets: resolvedInstallMode, resolvedVisionPort, resolvedXHTTPPort, resolvedXHTTPPath,
#       resolvedServerName, resolvedTargetPort, resolvedPrivateKey, resolvedPublicKey,
#       resolvedUUID, resolvedEmailBase, resolvedVisionEmail, resolvedXHTTPEmail
# Returns 0 on success; exits on invalid input.
resolveValues() {
    local xrayRuntime
    xrayRuntime="$(_xrayDockerRuntime)"

    # --- Install mode ---
    normalizeInstallMode "${installMode}"
    # resolvedInstallMode is set by normalizeInstallMode

    # --- Vision port ---
    if installModeHasVision "${resolvedInstallMode}"; then
        if ! parsePort "${port}"; then
            exit 1
        fi
        resolvedVisionPort="${resolvedPort}"
        checkPortInUse "${resolvedVisionPort}"
    fi

    # --- XHTTP port and path ---
    if installModeHasXHTTP "${resolvedInstallMode}"; then
        if ! parsePort "${xhttpPort}"; then
            exit 1
        fi
        resolvedXHTTPPort="${resolvedPort}"
        # Ensure XHTTP port does not collide with Vision port in 'all' mode
        if installModeHasVision "${resolvedInstallMode}" && [[ "${resolvedXHTTPPort}" == "${resolvedVisionPort}" ]]; then
            echoContent "red" "XHTTP port (${resolvedXHTTPPort}) is the same as the Vision port — please use different ports"
            exit 1
        fi
        checkPortInUse "${resolvedXHTTPPort}"

        normalizeXHTTPPath "${xhttpPath}"
        resolvedXHTTPPath="${resolvedXHTTPPath:-${resolvedXHTTPPath}}"
    fi

    # --- Server name ---
    parseServerName "${serverName}"

    # --- Private key ---
    if [[ -z "${privateKey}" ]]; then
        if ! generatePrivateKey "${xrayRuntime}"; then
            exit 1
        fi
    else
        resolvedPrivateKey="${privateKey}"
        if ! derivePublicKey "${xrayRuntime}" "${resolvedPrivateKey}"; then
            echoContent "red" "Provided private key is invalid"
            exit 1
        fi
    fi

    # --- UUID ---
    if [[ -z "${uuid}" ]]; then
        if ! generateUUID "${xrayRuntime}"; then
            exit 1
        fi
    else
        resolvedUUID="${uuid}"
    fi

    # --- Email base and per-protocol emails ---
    if [[ -z "${email}" ]]; then
        deriveEmail "${resolvedUUID}"
        resolvedEmailBase="${resolvedEmail}"
    else
        resolvedEmailBase="${email}"
        resolvedEmail="${email}"
    fi
    resolvedVisionEmail="${resolvedEmailBase}-VLESS_TCP/TLS_Vision"
    resolvedXHTTPEmail="${resolvedEmailBase}-VLESS_Reality_XHTTP"

    if installModeHasVision "${resolvedInstallMode}"; then
        echoContent "green" "Resolved Vision port:   ${resolvedVisionPort}"
    fi
    if installModeHasXHTTP "${resolvedInstallMode}"; then
        echoContent "green" "Resolved XHTTP port:    ${resolvedXHTTPPort}"
        echoContent "green" "Resolved XHTTP path:    $(renderXHTTPPath "${resolvedXHTTPPath}")"
    fi
    echoContent "green" "Resolved server name:   ${resolvedServerName}:${resolvedTargetPort}"
    echoContent "green" "Resolved email base:    ${resolvedEmailBase}"
}

# ---------------------------------------------------------------------------
# _buildVisionInbounds — emit the two Vision inbound JSON blocks (no trailing comma)
# Args: $1=visionPort $2=serverName $3=targetPort $4=privateKey $5=publicKey
#       $6=uuid $7=visionEmail
# ---------------------------------------------------------------------------
_buildVisionInbounds() {
    local vPort="$1" sName="$2" tPort="$3" privKey="$4" pubKey="$5"
    local vuuid="$6" vEmail="$7"
    cat <<VEOF
    {
      "tag": "dokodemo-in-VLESSReality",
      "port": ${vPort},
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1",
        "port": 45987,
        "network": "tcp"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["tls"],
        "routeOnly": true
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 45987,
      "protocol": "vless",
      "tag": "VLESSRealityVision",
      "settings": {
        "clients": [
          {
            "id": "$(jsonEscape "${vuuid}")",
            "flow": "xtls-rprx-vision",
            "email": "$(jsonEscape "${vEmail}")"
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "$(jsonEscape "${sName}:${tPort}")",
          "xver": 0,
          "serverNames": ["$(jsonEscape "${sName}")"],
          "privateKey": "$(jsonEscape "${privKey}")",
          "publicKey": "$(jsonEscape "${pubKey}")",
          "maxTimeDiff": 70000,
          "shortIds": ["", "6ba85179e30d4fc2"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      }
    }
VEOF
}

# ---------------------------------------------------------------------------
# _buildXHTTPInbound — emit the XHTTP inbound JSON block (no trailing comma)
# Args: $1=xhttpPort $2=serverName $3=targetPort $4=privateKey $5=publicKey
#       $6=uuid $7=xhttpEmail $8=renderedPath
# ---------------------------------------------------------------------------
_buildXHTTPInbound() {
    local xPort="$1" sName="$2" tPort="$3" privKey="$4" pubKey="$5"
    local xuuid="$6" xEmail="$7" xPath="$8"
    cat <<XEOF
    {
      "port": ${xPort},
      "listen": "0.0.0.0",
      "protocol": "vless",
      "tag": "VLESSRealityXHTTP",
      "settings": {
        "clients": [
          {
            "id": "$(jsonEscape "${xuuid}")",
            "email": "$(jsonEscape "${xEmail}")"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "$(jsonEscape "${sName}:${tPort}")",
          "xver": 0,
          "serverNames": ["$(jsonEscape "${sName}")"],
          "privateKey": "$(jsonEscape "${privKey}")",
          "publicKey": "$(jsonEscape "${pubKey}")",
          "maxTimeDiff": 70000,
          "shortIds": ["", "6ba85179e30d4fc2"]
        },
        "xhttpSettings": {
          "host": "$(jsonEscape "${sName}")",
          "path": "$(jsonEscape "${xPath}")",
          "mode": "auto"
        }
      }
    }
XEOF
}

# ---------------------------------------------------------------------------
# generateConfig — write the Xray Reality config and client summary to dataDir
# Supports installMode: vision / xhttp / all
# ---------------------------------------------------------------------------
generateConfig() {
    # Strip trailing slash for unambiguous path concatenation
    dataDir="${dataDir%/}"

    echoContent "white" "Generating Reality config in ${dataDir} ..."
    resolveValues

    # Create the data directory; exit cleanly if the path cannot be created
    if ! mkdir -p "${dataDir}" 2>/dev/null; then
        echoContent "red" "Failed to create data directory: ${dataDir}"
        echoContent "red" "Check that the parent path exists and is a directory, not a regular file"
        exit 1
    fi

    local configFile="${dataDir}/config.json"
    local summaryFile="${dataDir}/client-summary.txt"

    # Remove stale directory remnants left by previous failed runs
    if [[ -d "${configFile}" ]]; then
        echoContent "yellow" "Removing stale directory at ${configFile} left by a previous failed run"
        rm -rf "${configFile}" 2>/dev/null || { echoContent "red" "Cannot remove stale directory: ${configFile}"; exit 1; }
    fi
    if [[ -d "${summaryFile}" ]]; then
        echoContent "yellow" "Removing stale directory at ${summaryFile} left by a previous failed run"
        rm -rf "${summaryFile}" 2>/dev/null || { echoContent "red" "Cannot remove stale directory: ${summaryFile}"; exit 1; }
    fi

    local renderedXHTTPPath=""
    if installModeHasXHTTP "${resolvedInstallMode}"; then
        renderedXHTTPPath="$(renderXHTTPPath "${resolvedXHTTPPath}")"
    fi

    # --- Build inbounds array content ---
    local inboundsContent=""
    case "${resolvedInstallMode}" in
    vision)
        inboundsContent="$(_buildVisionInbounds \
            "${resolvedVisionPort}" "${resolvedServerName}" "${resolvedTargetPort}" \
            "${resolvedPrivateKey}" "${resolvedPublicKey}" \
            "${resolvedUUID}" "${resolvedVisionEmail}")"
        ;;
    xhttp)
        inboundsContent="$(_buildXHTTPInbound \
            "${resolvedXHTTPPort}" "${resolvedServerName}" "${resolvedTargetPort}" \
            "${resolvedPrivateKey}" "${resolvedPublicKey}" \
            "${resolvedUUID}" "${resolvedXHTTPEmail}" "${renderedXHTTPPath}")"
        ;;
    all)
        local visionPart xhttpPart
        visionPart="$(_buildVisionInbounds \
            "${resolvedVisionPort}" "${resolvedServerName}" "${resolvedTargetPort}" \
            "${resolvedPrivateKey}" "${resolvedPublicKey}" \
            "${resolvedUUID}" "${resolvedVisionEmail}")"
        xhttpPart="$(_buildXHTTPInbound \
            "${resolvedXHTTPPort}" "${resolvedServerName}" "${resolvedTargetPort}" \
            "${resolvedPrivateKey}" "${resolvedPublicKey}" \
            "${resolvedUUID}" "${resolvedXHTTPEmail}" "${renderedXHTTPPath}")"
        inboundsContent="${visionPart},"$'\n'"${xhttpPart}"
        ;;
    esac

    # --- Build routing rules ---
    # Vision mode needs dokodemo-door routing rules; XHTTP listens directly on the public port
    local routingRules=""
    if installModeHasVision "${resolvedInstallMode}"; then
        routingRules=$(cat <<REOF
      {
        "inboundTag": ["dokodemo-in-VLESSReality"],
        "domain": ["$(jsonEscape "${resolvedServerName}")"],
        "outboundTag": "direct"
      },
      {
        "inboundTag": ["dokodemo-in-VLESSReality"],
        "outboundTag": "blackhole"
      }
REOF
)
    else
        routingRules=$(cat <<REOF
      {
        "type": "field",
        "outboundTag": "direct",
        "network": "udp,tcp"
      }
REOF
)
    fi

    local oldUmask
    oldUmask="$(umask)"
    umask 077
    cat >"${configFile}" <<EOF
{
  "inbounds": [
${inboundsContent}
  ],
  "routing": {
    "rules": [
${routingRules}
    ]
  },
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "blackhole",
      "protocol": "blackhole"
    }
  ]
}
EOF
    umask "${oldUmask}"

    # Apply strict permissions to the config file (contains private key)
    chmod 600 "${configFile}"

    # --- Write human-readable client summary ---
    # Fields are strictly aligned with loadPersistedSummaryIfPresent parsing logic
    {
        printf 'container: v2ray-agent-docker\n'
        printf 'installMode: %s\n' "${resolvedInstallMode}"
        if installModeHasVision "${resolvedInstallMode}"; then
            printf 'visionPort: %s\n' "${resolvedVisionPort}"
        fi
        if installModeHasXHTTP "${resolvedInstallMode}"; then
            printf 'xhttpPort: %s\n' "${resolvedXHTTPPort}"
            printf 'xhttpPath: %s\n' "${resolvedXHTTPPath}"
        fi
        printf 'serverName: %s\n' "${resolvedServerName}"
        printf 'publicKey: %s\n' "${resolvedPublicKey}"
        printf 'uuid: %s\n' "${resolvedUUID}"
        printf 'emailBase: %s\n' "${resolvedEmailBase}"
        if installModeHasVision "${resolvedInstallMode}"; then
            printf 'visionEmail: %s\n' "${resolvedVisionEmail}"
        fi
        if installModeHasXHTTP "${resolvedInstallMode}"; then
            printf 'xhttpEmail: %s\n' "${resolvedXHTTPEmail}"
        fi
        printf 'shortId: 6ba85179e30d4fc2\n'
        printf 'configPath: %s\n' "${configFile}"
    } >"${summaryFile}"
    chmod 600 "${summaryFile}"

    # Post-write validation: confirm both outputs are regular files
    if [[ ! -f "${configFile}" ]]; then
        echoContent "red" "Config write failed — ${configFile} is not a regular file after write"
        exit 1
    fi
    if [[ ! -f "${summaryFile}" ]]; then
        echoContent "red" "Summary write failed — ${summaryFile} is not a regular file after write"
        exit 1
    fi

    echoContent "green" "Config written to ${configFile}"
    echoContent "green" "Summary written to ${summaryFile}"
}

# startContainer — validate config, remove existing container, and recreate.
# Uses config under dataDir; called after generateConfig or directly in --start-only mode.
startContainer() {
    local xrayImage="ghcr.io/xtls/xray-core:26.5.9"
    local containerName="v2ray-agent-docker"

    # Strip trailing slash for consistent path concatenation
    dataDir="${dataDir%/}"

    local configFile="${dataDir}/config.json"

    # Verify the config file exists before attempting anything
    if [[ ! -f "${configFile}" ]]; then
        echoContent "red" "Config file not found: ${configFile}"
        echoContent "red" "Run without --start-only to generate the config first"
        exit 1
    fi

    # --- Validate config using directory mount ---
    echoContent "white" "Pulling Xray image ${xrayImage} (if not cached)..."
    docker pull "${xrayImage}" >/dev/null 2>&1 || true

    echoContent "white" "Validating config with Xray image (directory mount)..."
    if ! docker run --rm \
        --user root \
        -v "${dataDir}:/usr/local/etc/xray:ro" \
        "${xrayImage}" \
        run -test -c /usr/local/etc/xray/config.json; then
        echoContent "red" "Xray config validation failed — container will not be started"
        exit 1
    fi
    echoContent "green" "Xray config validation passed"

    # --- Remove any existing container with the same name to avoid name conflicts ---
    if docker ps -a --filter "name=^/${containerName}$" --format '{{.Names}}' | grep -q "^${containerName}$"; then
        echoContent "yellow" "Removing existing container: ${containerName}"
        docker rm -f "${containerName}" >/dev/null 2>&1 || true
    fi

    # --- Determine the port list to publish ---
    # start-only mode restores protocol mode and ports from persisted summary/config
    local activeInstallMode activeVisionPort activeXHTTPPort
    if [[ "${startOnly}" == "1" ]]; then
        loadPersistedPort
        activeInstallMode="${persistedInstallMode}"
        activeVisionPort="${persistedVisionPort}"
        activeXHTTPPort="${persistedXHTTPPort}"
    else
        activeInstallMode="${resolvedInstallMode}"
        activeVisionPort="${resolvedVisionPort}"
        activeXHTTPPort="${resolvedXHTTPPort}"
    fi

    # Build the -p argument list
    local portArgs=()
    if installModeHasVision "${activeInstallMode}" && [[ -n "${activeVisionPort}" ]]; then
        portArgs+=("-p" "${activeVisionPort}:${activeVisionPort}")
    fi
    if installModeHasXHTTP "${activeInstallMode}" && [[ -n "${activeXHTTPPort}" ]]; then
        portArgs+=("-p" "${activeXHTTPPort}:${activeXHTTPPort}")
    fi

    if [[ ${#portArgs[@]} -eq 0 ]]; then
        echoContent "red" "Cannot determine ports to publish — check the persisted config"
        exit 1
    fi

    echoContent "white" "Starting container ${containerName} (ports: ${portArgs[*]})..."
    if ! docker run -d \
        --name "${containerName}" \
        --restart unless-stopped \
        --user root \
        "${portArgs[@]}" \
        -v "${dataDir}:/usr/local/etc/xray:ro" \
        "${xrayImage}" \
        run -c /usr/local/etc/xray/config.json; then
        echoContent "red" "Failed to start container ${containerName}"
        exit 1
    fi

    # --- Verify the container is actually running ---
    local runningName
    runningName=$(docker ps --filter "name=^/${containerName}$" --format '{{.Names}}' 2>/dev/null || true)
    if [[ "${runningName}" != "${containerName}" ]]; then
        echoContent "red" "Container ${containerName} failed to reach running state"
        docker logs "${containerName}" 2>/dev/null || true
        exit 1
    fi

}

# showClientInfo — print the current Reality account in a showAccounts-style layout.
# Displays only the protocol blocks that are actually installed.
showClientInfo() {
    local displayAddress=""

    loadPersistedAccountInfo
    displayAddress="$(getPublicIP)"

    local shortId="${persistedShortId:-6ba85179e30d4fc2}"
    local mode="${persistedInstallMode}"

    if installModeHasVision "${mode}"; then
        showVisionAccount \
            "${displayAddress}" \
            "${persistedVisionPort}" \
            "${persistedServerName}" \
            "${persistedPublicKey}" \
            "${persistedUUID}" \
            "${persistedVisionEmail}" \
            "${shortId}"
    fi

    if installModeHasXHTTP "${mode}"; then
        local renderedPath
        renderedPath="$(renderXHTTPPath "${persistedXHTTPPath}")"
        showXHTTPAccount \
            "${displayAddress}" \
            "${persistedXHTTPPort}" \
            "${persistedServerName}" \
            "${persistedPublicKey}" \
            "${persistedUUID}" \
            "${persistedXHTTPEmail}" \
            "${shortId}" \
            "${renderedPath}"
    fi
}

# ---------------------------------------------------------------------------
# main — top-level flow
# ---------------------------------------------------------------------------
main() {
    parseCli "$@"

    if [[ "${generateOnly}" == "1" && "${startOnly}" == "1" ]]; then
        echoContent "red" "--generate-only and --start-only are mutually exclusive"
        exit 1
    fi

    checkEnvironment
    selfInstallShortcut
    checkDocker
    promptExistingInstallAction
    promptInteractiveValues

    if [[ "${startOnly}" != "1" ]]; then
        generateConfig
    fi

    if [[ "${generateOnly}" != "1" ]]; then
        startContainer
        showClientInfo
    fi
}

main "$@"
