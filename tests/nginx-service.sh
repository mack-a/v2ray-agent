#!/usr/bin/env bash
# Isolated regression tests: no root, network, nginx or service manager required.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
# Load only the functions under test; sourcing install.sh would run the installer.
{
    sed -n '/^handleNginx() {$/,/^# 定时任务更新tls证书/p' "$repo_dir/install.sh"
    sed -n '/^checkPortOpen() {$/,/^# 初始化Nginx申请证书配置/p' "$repo_dir/install.sh"
} | sed "s@/etc/v2ray-agent/nginx_error.log@${test_dir}/nginx_error.log@g" > "$test_dir/functions.sh"
source "$test_dir/functions.sh"

echoContent() { printf '%s\n' "$*" >> "$test_dir/messages"; }
pgrep() { echo pgrep >> "$test_dir/unsafe"; return 0; }
kill() { echo kill >> "$test_dir/unsafe"; return 1; }
nginx() {
    printf '%s\n' "$*" >> "$test_dir/nginx-calls"
    [[ "$*" == '-t' ]]
}
updateSELinuxHTTPPortT() {
    repairs=$((repairs + 1))
    [[ "$repairable" == yes ]] || return 1
    fail_start=no
}
mock_service() {
    printf '%s\n' "$1" >> "$test_dir/service-calls"
    case "$1" in
    status) [[ "$state" == active ]];;
    start)
        starts=$((starts + 1))
        [[ "$fail_start" == no ]] || return 1
        [[ "$inactive_after_start" == yes ]] || state=active
        ;;
    stop)
        [[ "$fail_stop" == no ]] || return 1
        [[ "$active_after_stop" == yes ]] || state=inactive
        ;;
    *) return 99;;
    esac
}
systemctl() {
    [[ "$release" != alpine ]] || return 99
    case "$*" in
    'is-active --quiet nginx') mock_service status;;
    'start nginx') mock_service start;;
    'stop nginx') mock_service stop;;
    *) return 99;;
    esac
}
rc-service() {
    [[ "$release" == alpine && "$1" == nginx ]] || return 99
    mock_service "$2"
}
handleSingBox() { :; }
handleXray() { :; }
allowPort() { :; }
checkIP() { printf '%s\n' "$1" > "$test_dir/checked-ip"; }
curl() {
    case "$*" in
    *cdn-cgi/trace*) return 0;;
    *checkPort*) echo request >> "$test_dir/requests"; printf fjkvymb6len;;
    */ip) printf 192.0.2.1;;
    *) return 99;;
    esac
}

run_case() (
    local release=$1 scenario=$2
    local state=inactive starts=0 repairs=0 fail_start=no fail_stop=no
    local repairable=no inactive_after_start=no active_after_stop=no
    local selectCustomInstallType='' btDomain='' localIP=''
    local nginxConfigPath="$test_dir/"
    rm -f "$test_dir/unsafe" "$test_dir/messages" "$test_dir/nginx-calls" \
        "$test_dir/service-calls" "$test_dir/requests" "$test_dir/checked-ip" \
        "$test_dir/checkPortOpen.conf"
    case "$scenario" in
    lifecycle)
        handleNginx start
        [[ "$state" == active && "$starts" == 1 ]]
        handleNginx start
        [[ "$starts" == 1 ]]
        handleNginx stop
        [[ "$state" == inactive ]]
        handleNginx stop
        ;;
    start_failure)
        fail_start=yes
        if handleNginx start; then exit 1; fi
        [[ "$starts" == 1 && "$state" == inactive ]]
        [[ "$(cat "$test_dir/nginx-calls")" == '-t' ]]
        ;;
    inactive_after_start)
        inactive_after_start=yes
        if handleNginx start; then exit 1; fi
        ;;
    selinux_retry)
        fail_start=yes repairable=yes
        if [[ "$release" == alpine ]]; then
            if handleNginx start; then exit 1; fi
            [[ "$starts" == 1 && "$repairs" == 0 ]]
        else
            handleNginx start
            [[ "$starts" == 2 && "$repairs" == 1 && "$state" == active ]]
        fi
        ;;
    bounded_retry)
        inactive_after_start=yes repairable=yes
        if handleNginx start; then exit 1; fi
        [[ "$starts" -le 2 && "$repairs" -le 1 ]]
        ;;
    stop_failure)
        state=active fail_stop=yes
        if handleNginx stop; then exit 1; fi
        [[ "$state" == active ]]
        ;;
    active_after_stop)
        state=active active_after_stop=yes
        if handleNginx stop; then exit 1; fi
        ;;
    skip_nginx)
        selectCustomInstallType=',7,'
        handleNginx start
        [[ "$starts" == 0 ]]
        ;;
    probe_success)
        checkPortOpen 20028 example.invalid
        [[ ! -e "$test_dir/checkPortOpen.conf" && "$state" == inactive ]]
        [[ "$(cat "$test_dir/checked-ip")" == 192.0.2.1 ]]
        ;;
    probe_start_failure)
        fail_start=yes
        if (checkPortOpen 20028 example.invalid); then exit 1; fi
        [[ ! -e "$test_dir/checkPortOpen.conf" && ! -e "$test_dir/requests" ]]
        ! grep -q '未检测到.*端口开放' "$test_dir/messages"
        ;;
    probe_stop_failure)
        state=active fail_stop=yes
        if (checkPortOpen 20028 example.invalid); then exit 1; fi
        [[ ! -e "$test_dir/checkPortOpen.conf" && ! -e "$test_dir/requests" ]]
        ;;
    esac
    [[ ! -e "$test_dir/unsafe" ]]
    printf 'PASS %s / %s\n' "$release" "$scenario"
)
for manager in debian alpine; do
    for scenario in lifecycle start_failure inactive_after_start selinux_retry bounded_retry \
        stop_failure active_after_stop skip_nginx probe_success probe_start_failure probe_stop_failure; do
        run_case "$manager" "$scenario"
    done
done
