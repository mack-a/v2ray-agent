#!/usr/bin/env bash
# docker_reality.sh — 基于 Docker 的 VLESS-Reality 独立启动器（无需域名）
# 用法：bash shell/docker_reality.sh [选项]
export LANG=en_US.UTF-8

# ---------------------------------------------------------------------------
# 输出辅助函数 — 与 install.sh 中的 echoContent 风格保持一致
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
# 默认值
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
# QA 覆盖：设置 V2RAY_AGENT_FORCE_NO_DOCKER=1 可在测试中跳过 Docker 检查
# ---------------------------------------------------------------------------
forceNoDocker="${V2RAY_AGENT_FORCE_NO_DOCKER:-0}"

# ---------------------------------------------------------------------------
# showHelp — 打印用法说明并退出
# ---------------------------------------------------------------------------
showHelp() {
    echoContent "skyBlue" "docker_reality.sh — 通过 Docker 运行 VLESS-Reality（无需域名）"
    echoContent "white" ""
    echoContent "white" "用法："
    echoContent "white" "  bash shell/docker_reality.sh [选项]"
    echoContent "white" ""
    echoContent "white" "运行模式："
    echoContent "white" "  默认 / 交互模式       先检测安装状态，再显示安装/重装/启动相关菜单"
    echoContent "white" "  --non-interactive     非交互模式；若必填值缺失则确定性地报错退出"
    echoContent "white" "  --generate-only       仅生成配置和摘要文件，然后退出"
    echoContent "white" "  --start-only          复用已有配置，仅启动/重建容器"
    echoContent "white" "  --skip-self-install   跳过脚本迁移与 vasmad 快捷方式创建"
    echoContent "white" ""
    echoContent "white" "选项："
    echoContent "white" "  --non-interactive       非交互运行；所有必填值须通过参数提供"
    echoContent "white" "  --data-dir <路径>       持久化配置/数据目录（默认：/etc/v2ray-agent/docker/）"
    echoContent "white" "  --install-mode <模式>   安装模式：vision / xhttp / all"
    echoContent "white" "  --port <端口>           Vision 或单协议模式的外部监听端口（留空则随机）"
    echoContent "white" "  --xhttp-port <端口>     XHTTP 模式端口（留空则随机）"
    echoContent "white" "  --xhttp-path <路径>     XHTTP path 基础值（最终写为 /<path>xHTTP）"
    echoContent "white" "  --server-name <sni>     Reality 握手所用的 SNI / 服务器名称"
    echoContent "white" "  --private-key <密钥>    X25519 私钥（留空则自动生成）"
    echoContent "white" "  --uuid <uuid>           客户端 UUID（留空则自动生成）"
    echoContent "white" "  --email <邮箱>          存储在配置中的联系邮箱"
    echoContent "white" "  --generate-only         生成配置和密钥后退出，不启动 Docker"
    echoContent "white" "  --start-only            跳过配置生成，直接用已有配置启动 Docker"
    echoContent "white" "  --skip-self-install     跳过脚本迁移与 vasmad 快捷方式创建"
    echoContent "white" "  -h, --help              显示本帮助信息并退出"
    echoContent "white" ""
    echoContent "white" "操作说明："
    echoContent "white" "  1. 交互模式会同时检测 config.json 与 v2ray-agent-docker 容器是否存在，再显示对应菜单。"
    echoContent "white" "  2. 若两者都不存在，则显示安装菜单；若任一存在，则显示查看账号/重新安装/启动或重建菜单。"
    echoContent "white" "  3. 安装时可选 Reality Vision、Reality XHTTP 或全部安装；XHTTP 会额外使用 path 输入。"
    echoContent "white" "  4. 非交互模式需要显式提供所有值，但 privateKey/uuid/email 留空时可自动生成/推导。"
    echoContent "white" "  5. 运行数据目录默认为 /etc/v2ray-agent/docker/；可用 --data-dir 覆盖以用于 QA 或自定义路径。"
    echoContent "white" "  6. 若脚本不是从 /etc/v2ray-agent/docker_reality.sh 运行，则会迁移脚本并创建 vasmad 快捷方式。"
    echoContent "white" ""
    echoContent "yellow" "QA / 测试："
    echoContent "white" "  V2RAY_AGENT_FORCE_NO_DOCKER=1  跳过 Docker 可用性检查（测试环境）"
    echoContent "white" "  --data-dir /tmp/v2ray-agent/docker  隔离验证的路径覆盖示例"
    exit "${1:-0}"
}

# jsonEscape — 对字符串进行转义，以便安全地插入 JSON。
jsonEscape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "${value}"
}

# validateDataDirPath — 拒绝明显不安全的 data-dir 路径形式（用于 root 运行场景）。
validateDataDirPath() {
    local path="$1"
    if [[ -z "${path}" || "${path}" != /* || "${path}" == *:* ]]; then
        echoContent "red" "--data-dir 必须是不含冒号的绝对路径"
        exit 1
    fi

    if [[ -e "${path}" && -L "${path}" ]]; then
        echoContent "red" "--data-dir 不能是符号链接：${path}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# promptValue — 交互式输入提示，允许直接回车保留空值
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

# initRandomPath — 生成与 install.sh 风格接近的 4 位随机 path 基础值。
initRandomPath() {
    local chars="abcdefghijklmnopqrstuvwxyz"
    local randomPath=""
    local _idx
    for _idx in 1 2 3 4; do
        randomPath+="${chars:RANDOM%${#chars}:1}"
    done
    printf '%s' "${randomPath}"
}

# normalizeInstallMode — 规范安装模式，默认保持对旧 Vision 行为的兼容。
normalizeInstallMode() {
    local rawMode="$1"
    case "${rawMode}" in
    "")
        if [[ -n "${port}" && (-n "${xhttpPort}" || -n "${xhttpPath}") ]]; then
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
        echoContent "red" "安装模式无效：${rawMode}（必须是 vision / xhttp / all）"
        exit 1
        ;;
    esac
}

# normalizeXHTTPPath — 规范 XHTTP path 基础值，最终渲染时自动追加 xHTTP 后缀。
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
        echoContent "red" "XHTTP path 基础值结尾不可用 ws，否则会和 install.sh 的旧分流路径约定冲突"
        exit 1
    fi
    resolvedXHTTPPath="${normalized}"
}

# renderXHTTPPath — 将 path 基础值渲染为 install.sh 使用的 /<path>xHTTP 形式。
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
# promptInteractiveValues — 在交互模式下收集缺失的值
# ---------------------------------------------------------------------------
promptInteractiveValues() {
    if [[ "${startOnly}" == "1" || "${nonInteractive}" == "1" ]]; then
        return 0
    fi

    echoContent "skyBlue" ""
    echoContent "skyBlue" "─── 配置输入 ───────────────────────────────────────────"
    echoContent "white" "Docker 已就绪。请依次输入各项配置值。"
    echoContent "white" "直接回车则接受括号内的默认行为（自动生成或随机选取）。"
    echoContent "skyBlue" "────────────────────────────────────────────────────────"
    if [[ -z "${installMode}" ]]; then
        echoContent "yellow" "1. Reality Vision"
        echoContent "yellow" "2. Reality XHTTP"
        echoContent "yellow" "3. 全部安装"
        case "$(promptValue $'\n[步骤 1/8] 安装模式 [1-3]：' "")" in
        1) installMode="vision" ;;
        2) installMode="xhttp" ;;
        3) installMode="all" ;;
        *)
            echoContent "red" "无效选择，请输入 1 / 2 / 3"
            exit 1
            ;;
        esac
    fi

    normalizeInstallMode "${installMode}"

    if installModeHasVision "${resolvedInstallMode}"; then
        if [[ -z "${port}" ]]; then
            port="$(promptValue $'\n[步骤 2/8] Vision 端口  [留空则随机选取 10000-30000]：' "")"
            if [[ -z "${port}" ]]; then
                port=""
            fi
        fi
    fi

    if installModeHasXHTTP "${resolvedInstallMode}"; then
        if [[ -z "${xhttpPort}" ]]; then
            xhttpPort="$(promptValue $'\n[步骤 3/8] XHTTP 端口  [留空则随机选取 10000-30000]：' "")"
            if [[ -z "${xhttpPort}" ]]; then
                xhttpPort=""
            fi
        fi
        if [[ -z "${xhttpPath}" ]]; then
            xhttpPath="$(promptValue $'\n[步骤 4/8] XHTTP path  [例: alone，留空则随机生成]：' "")"
        fi
    fi

    if [[ -z "${serverName}" ]]; then
        serverName="$(promptValue $'\n[步骤 5/8] 服务器名称  [留空则随机选取 Reality 目标]：' "")"
    fi
    if [[ -z "${privateKey}" ]]; then
        privateKey="$(promptValue $'\n[步骤 6/8] 私钥  [留空则自动生成]：' "")"
    fi
    if [[ -z "${uuid}" ]]; then
        uuid="$(promptValue $'\n[步骤 7/8] UUID  [留空则自动生成]：' "")"
    fi
    if [[ -z "${email}" ]]; then
        email="$(promptValue $'\n[步骤 8/8] 邮箱基础名称  [留空则从 UUID 推导]：' "")"
    fi
    echoContent "white" ""
}

# ---------------------------------------------------------------------------
# parseCli — 解析命令行参数
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
                echoContent "red" "--data-dir 需要一个路径值"
                exit 1
            fi
            dataDir="$2"
            validateDataDirPath "${dataDir}"
            shift 2
            ;;
        --install-mode)
            if [[ $# -lt 2 || -z "${2:-}" || "${2:0:1}" == "-" ]]; then
                echoContent "red" "--install-mode 需要一个值（vision / xhttp / all）"
                exit 1
            fi
            installMode="$2"
            shift 2
            ;;
        --port)
            if [[ $# -lt 2 || (-n "${2:-}" && "${2:0:1}" == "-") ]]; then
                echoContent "red" "--port 需要一个数字值"
                exit 1
            fi
            port="$2"
            shift 2
            ;;
        --xhttp-port)
            if [[ $# -lt 2 || (-n "${2:-}" && "${2:0:1}" == "-") ]]; then
                echoContent "red" "--xhttp-port 需要一个数字值"
                exit 1
            fi
            xhttpPort="$2"
            shift 2
            ;;
        --xhttp-path)
            if [[ $# -lt 2 || (-n "${2:-}" && "${2:0:1}" == "-") ]]; then
                echoContent "red" "--xhttp-path 需要一个值"
                exit 1
            fi
            xhttpPath="$2"
            shift 2
            ;;
        --server-name)
            if [[ $# -lt 2 || (-n "${2:-}" && "${2:0:1}" == "-") ]]; then
                echoContent "red" "--server-name 需要一个值"
                exit 1
            fi
            serverName="$2"
            shift 2
            ;;
        --private-key)
            if [[ $# -lt 2 || (-n "${2:-}" && "${2:0:1}" == "-") ]]; then
                echoContent "red" "--private-key 需要一个值"
                exit 1
            fi
            privateKey="$2"
            shift 2
            ;;
        --uuid)
            if [[ $# -lt 2 || (-n "${2:-}" && "${2:0:1}" == "-") ]]; then
                echoContent "red" "--uuid 需要一个值"
                exit 1
            fi
            uuid="$2"
            shift 2
            ;;
        --email)
            if [[ $# -lt 2 || (-n "${2:-}" && "${2:0:1}" == "-") ]]; then
                echoContent "red" "--email 需要一个值"
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
            echoContent "red" "未知选项：$1"
            showHelp 1
            ;;
        esac
    done

}

# ---------------------------------------------------------------------------
# checkEnvironment — 强制要求 Linux 系统及 root/sudo 权限
# ---------------------------------------------------------------------------
checkEnvironment() {
    local osType
    osType="$(uname -s 2>/dev/null || true)"
    if [[ "${osType}" != "Linux" ]]; then
        echoContent "red" "本脚本需要 Linux 主机（检测到：${osType}）"
        exit 1
    fi

    if [[ "$(id -u)" != "0" ]]; then
        echoContent "red" "本脚本必须以 root 或 sudo 方式运行"
        exit 1
    fi
}

# selfInstallShortcut — 参考 install.sh 的 aliasInstall 逻辑，为本脚本创建稳定位置与 vasmad 快捷方式。
selfInstallShortcut() {
    local targetScript="/etc/v2ray-agent/docker_reality.sh"
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
            echoContent "yellow" "无法自动移动脚本到 ${targetScript}，继续使用当前路径运行。"
        else
            chmod 700 "${targetScript}"
            currentScript="${targetScript}"
            echoContent "green" "脚本已移动到 ${targetScript}"
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
        echoContent "green" "快捷方式创建成功，可执行 [vasmad] 重新打开脚本"
        echoContent "yellow" "启动方式：vasmad"
    fi
}

# ---------------------------------------------------------------------------
# installDocker — 下载并运行 Docker 官方便捷安装脚本
# ---------------------------------------------------------------------------
installDocker() {
    echoContent "white" "正在从 https://get.docker.com 下载 Docker 安装脚本..."
    local tmpScript
    tmpScript="$(mktemp /tmp/get-docker-XXXXXX.sh)"
    if ! curl -fsSL https://get.docker.com -o "${tmpScript}"; then
        echoContent "red" "从 https://get.docker.com 下载 Docker 安装脚本失败"
        rm -f "${tmpScript}"
        return 1
    fi
    echoContent "white" "正在运行 Docker 安装脚本..."
    if ! sh "${tmpScript}"; then
        echoContent "red" "Docker 安装失败"
        rm -f "${tmpScript}"
        return 1
    fi
    rm -f "${tmpScript}"
    echoContent "green" "Docker 安装成功"
    return 0
}

# checkDocker — 验证 Docker 是否已安装并正在运行；若未安装则提示安装
checkDocker() {
    # QA 覆盖：V2RAY_AGENT_FORCE_NO_DOCKER=1 强制进入 Docker 缺失分支
    if [[ "${forceNoDocker}" == "1" ]]; then
        echoContent "yellow" "[QA] V2RAY_AGENT_FORCE_NO_DOCKER=1：模拟 Docker 未安装"
        _promptDockerInstall
        return $?
    fi

    echoContent "white" "正在检查 Docker 可用性..."

    if ! command -v docker >/dev/null 2>&1; then
        echoContent "yellow" "本系统未安装 Docker"
        _promptDockerInstall
        return $?
    fi

    # Docker 二进制存在 — 验证守护进程是否可达
    if ! docker info >/dev/null 2>&1; then
        echoContent "red" "Docker 已安装但守护进程未运行"
        echoContent "white" "请启动 Docker 守护进程（例如：systemctl start docker）后重试"
        exit 1
    fi

    echoContent "green" "Docker 可用且正在运行"
    return 0
}

# _promptDockerInstall — 询问用户是否安装 Docker；拒绝时干净退出
_promptDockerInstall() {
    local answer
    if [[ "${nonInteractive}" == "1" ]]; then
        echoContent "red" "Docker 是必需的但未安装。请使用交互模式，或仅在 QA 中设置 V2RAY_AGENT_FORCE_NO_DOCKER。"
        exit 1
    fi

    echoContent "yellow" "运行本脚本需要 Docker。"
    answer="$(promptValue $'\033[33m是否通过 https://get.docker.com 立即安装 Docker？[y/N]：\033[0m' "")"
    case "${answer}" in
    [yY] | [yY][eE][sS])
        if ! installDocker; then
            echoContent "red" "Docker 安装失败，正在退出。"
            exit 1
        fi
        # 安装后验证守护进程是否已启动
        if ! docker info >/dev/null 2>&1; then
            echoContent "yellow" "Docker 已安装但守护进程尚未运行，正在启动..."
            systemctl start docker 2>/dev/null || true
            sleep 2
            if ! docker info >/dev/null 2>&1; then
                echoContent "red" "Docker 守护进程未能启动，请手动启动后重试。"
                exit 1
            fi
        fi
        echoContent "green" "Docker 已就绪"
        ;;
    *)
        echoContent "white" "已拒绝安装 Docker，正在退出。"
        exit 0
        ;;
    esac
}

# ---------------------------------------------------------------------------
# xrayImagePreflight — 使用官方 Xray 镜像验证配置文件
# 用法：xrayImagePreflight <配置文件路径>
# ---------------------------------------------------------------------------
xrayImagePreflight() {
    local configFile="$1"
    local xrayImage="ghcr.io/xtls/xray-core:26.5.9"

    if [[ -z "${configFile}" ]]; then
        echoContent "red" "xrayImagePreflight：需要提供配置文件路径"
        return 1
    fi

    if [[ ! -f "${configFile}" ]]; then
        echoContent "red" "xrayImagePreflight：配置文件未找到：${configFile}"
        return 1
    fi

    echoContent "white" "正在拉取 Xray 镜像 ${xrayImage}（如未缓存）..."
    docker pull "${xrayImage}" >/dev/null 2>&1 || true

    echoContent "white" "正在验证配置：docker run --rm --user root -v \"${configFile}:/usr/local/etc/xray/config.json:ro\" ${xrayImage} run -test -c /usr/local/etc/xray/config.json"
    if docker run --rm \
        --user root \
        -v "${configFile}:/usr/local/etc/xray/config.json:ro" \
        "${xrayImage}" \
        run -test -c /usr/local/etc/xray/config.json; then
        echoContent "green" "Xray 配置验证通过"
        return 0
    else
        echoContent "red" "Xray 配置验证失败"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# 值生成辅助函数（任务 2）
# ---------------------------------------------------------------------------

# _realityDomainList — 精选的 Reality 目标域名列表，与 install.sh:9618 保持同步
# 返回逗号分隔的域名字符串（Xray-core 列表）
_realityDomainList() {
    printf '%s' "download-installer.cdn.mozilla.net,addons.mozilla.org,s0.awsstatic.com,d1.awsstatic.com,images-na.ssl-images-amazon.com,m.media-amazon.com,player.live-video.net,one-piece.com,lol.secure.dyn.riotcdn.net,www.lovelive-anime.jp,academy.nvidia.com,dl.google.com,www.google-analytics.com,www.caltech.edu,www.calstatela.edu,www.suny.edu,www.suffolk.edu,www.python.org,vuejs-jp.org,vuejs.org,zh-hk.vuejs.org,react.dev,www.java.com,www.oracle.com,www.mysql.com,www.mongodb.com,redis.io,cname.vercel-dns.com,vercel-dns.com,www.swift.com,academy.nvidia.com,www.swift.com,www.cisco.com,www.asus.com,www.samsung.com,www.amd.com,www.umcg.nl,www.fom-international.com,www.u-can.co.jp,github.io"
}

# parsePort — 验证并规范化端口值。
# 用法：parsePort <原始端口>
# 设置全局变量：resolvedPort
# 成功返回 0，输入无效返回 1。
parsePort() {
    local raw="$1"
    if [[ -z "${raw}" ]]; then
        # 留空 → 随机选取 10000-30000（与 install.sh:9711 保持一致）
        resolvedPort=$((RANDOM % 20001 + 10000))
        echoContent "yellow" "未提供端口 — 随机选取：${resolvedPort}"
        return 0
    fi
    # 必须是正整数
    if ! [[ "${raw}" =~ ^[0-9]+$ ]]; then
        echoContent "red" "端口无效 '${raw}'：必须是正整数"
        return 1
    fi
    if [[ "${raw}" -lt 1 || "${raw}" -gt 65535 ]]; then
        echoContent "red" "端口无效 '${raw}'：必须在 1-65535 范围内"
        return 1
    fi
    resolvedPort="${raw}"
    return 0
}

# checkPortInUse — 若端口已被 v2ray-agent-docker 容器以外的进程占用则退出
# （与 install.sh:1951-1957 保持一致）。
# 重新运行时脚本会在重建前执行 docker rm -f v2ray-agent-docker，
# 因此仅由该容器占用的端口不构成真正的冲突。
# 用法：checkPortInUse <端口>
checkPortInUse() {
    local p="$1"
    if ! command -v lsof >/dev/null 2>&1; then
        return 0
    fi
    # 收集监听该端口的 PID
    local listenPids
    listenPids=$(lsof -i "tcp:${p}" -sTCP:LISTEN -t 2>/dev/null || true)
    [[ -z "${listenPids}" ]] && return 0

    # 检查现有 v2ray-agent-docker 容器是否占用该端口。
    # 若容器存在，其发布端口由 docker-proxy 管理。
    # 若所有监听 PID 均属于该容器的 docker-proxy 进程，则允许使用该端口。
    local containerExists=0
    if docker ps -a --filter "name=^/v2ray-agent-docker$" --format '{{.Names}}' 2>/dev/null |
        grep -q "^v2ray-agent-docker$"; then
        containerExists=1
    fi

    if [[ "${containerExists}" == "1" ]]; then
        # 验证所有监听 PID 是否均为 docker-proxy 进程（Docker 为发布端口生成的转发器）。
        # 若有任何 PID 不是 docker-proxy，则该端口被无关进程占用 — 这是真正的冲突。
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
            # 端口仅由 v2ray-agent-docker 的 docker-proxy 占用 — 可以继续
            echoContent "yellow" "端口 ${p} 由现有 v2ray-agent-docker 容器占用（将被替换）"
            return 0
        fi
    fi

    echoContent "red" "端口 ${p} 已被占用 — 请释放后重试"
    lsof -i "tcp:${p}" -sTCP:LISTEN 2>/dev/null || true
    exit 1
}

# parseServerName — 验证并规范化 serverName / host:port 输入。
# 用法：parseServerName <原始服务器名称>
# 设置全局变量：resolvedServerName、resolvedTargetPort
# 成功返回 0。
parseServerName() {
    local raw="$1"
    if [[ -z "${raw}" ]]; then
        # 留空 → 从精选列表随机选取（与 install.sh:9673-9678 保持一致）
        local domainList count randomIdx
        domainList="$(_realityDomainList)"
        count=$(printf '%s' "${domainList}" | awk -F',' '{print NF}')
        randomIdx=$(((RANDOM % count) + 1))
        resolvedServerName=$(printf '%s' "${domainList}" | awk -F',' -v n="${randomIdx}" '{print $n}')
        resolvedTargetPort=443
        echoContent "yellow" "未提供 serverName — 随机选取：${resolvedServerName}:${resolvedTargetPort}"
        return 0
    fi
    # 支持 host:port 语法（与 install.sh:9679-9682 保持一致）
    if printf '%s' "${raw}" | grep -q ":"; then
        resolvedTargetPort=$(printf '%s' "${raw}" | awk -F: '{print $2}')
        resolvedServerName=$(printf '%s' "${raw}" | awk -F: '{print $1}')
    else
        resolvedServerName="${raw}"
        resolvedTargetPort=443
    fi
    return 0
}

# generatePrivateKey — 通过预检的 Xray Docker 镜像生成 X25519 密钥对。
# 用法：generatePrivateKey <xray运行时路径>
# 设置全局变量：resolvedPrivateKey、resolvedPublicKey
# 成功返回 0，失败返回 1。
generatePrivateKey() {
    local xrayRuntime="$1"
    local x25519Output
    if [[ -z "${xrayRuntime}" ]]; then
        echoContent "red" "generatePrivateKey：需要提供 xray 运行时路径"
        return 1
    fi
    # xrayRuntime 可以是 Docker 调用字符串或宿主机二进制路径
    x25519Output=$(${xrayRuntime} x25519 2>/dev/null) || {
        echoContent "red" "通过以下命令生成 X25519 密钥对失败：${xrayRuntime} x25519"
        return 1
    }
    resolvedPrivateKey=$(printf '%s' "${x25519Output}" | awk -F': ' '/PrivateKey|Private key/ {print $2; exit}')
    resolvedPublicKey=$(printf '%s' "${x25519Output}" | awk -F': ' '/Password|Public key/ {print $2; exit}')
    if [[ -z "${resolvedPrivateKey}" ]]; then
        echoContent "red" "X25519 密钥生成未产生 PrivateKey 输出"
        return 1
    fi
    echoContent "green" "已生成公钥：  ${resolvedPublicKey}"
    return 0
}

# derivePublicKey — 通过 Xray 运行时从已有私钥推导公钥。
# 用法：derivePublicKey <xray运行时路径> <私钥>
# 设置全局变量：resolvedPublicKey
# 成功返回 0，失败返回 1。
derivePublicKey() {
    local xrayRuntime="$1"
    local privKey="$2"
    local x25519Output
    x25519Output=$(${xrayRuntime} x25519 -i "${privKey}" 2>/dev/null) || {
        echoContent "red" "从提供的私钥推导公钥失败"
        return 1
    }
    resolvedPublicKey=$(printf '%s' "${x25519Output}" | awk -F': ' '/Password|Public key/ {print $2; exit}')
    if [[ -z "${resolvedPublicKey}" ]]; then
        echoContent "red" "提供的私钥无效 — 无法推导公钥"
        return 1
    fi
    return 0
}

# generateUUID — 通过预检的 Xray Docker 镜像生成 UUID。
# 用法：generateUUID <xray运行时路径>
# 设置全局变量：resolvedUUID
# 成功返回 0，失败返回 1。
generateUUID() {
    local xrayRuntime="$1"
    local uuidOutput
    if [[ -z "${xrayRuntime}" ]]; then
        echoContent "red" "generateUUID：需要提供 xray 运行时路径"
        return 1
    fi
    uuidOutput=$(${xrayRuntime} uuid 2>/dev/null) || {
        echoContent "red" "通过以下命令生成 UUID 失败：${xrayRuntime} uuid"
        return 1
    }
    resolvedUUID=$(printf '%s' "${uuidOutput}" | tr -d '[:space:]')
    if [[ -z "${resolvedUUID}" ]]; then
        echoContent "red" "UUID 生成产生了空输出"
        return 1
    fi
    echoContent "green" "已生成 UUID：${resolvedUUID}"
    return 0
}

# deriveEmail — 从 UUID 前缀推导邮箱（与 install.sh:3842 保持一致）
# 用法：deriveEmail <uuid>
# 设置全局变量：resolvedEmail
deriveEmail() {
    local uuidVal="$1"
    # 取第一个 '-' 之前的部分
    resolvedEmail="${uuidVal%%-*}"
}

# _xrayDockerRuntime — 返回 Xray 镜像的 docker-run 命令前缀。
# 这是任务 3 中预检的运行时路径（不假设宿主机有二进制文件）。
_xrayDockerRuntime() {
    printf '%s' "docker run --rm ghcr.io/xtls/xray-core:26.5.9"
}

# loadPersistedSummaryIfPresent — 可选地读取并验证 client-summary.txt。
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
        echoContent "red" "持久化摘要容器名称不匹配：${persistedContainer}"
        exit 1
    fi
    if [[ -n "${persistedConfigPath}" && "${persistedConfigPath}" != "${dataDir%/}/config.json" ]]; then
        echoContent "red" "持久化摘要 configPath 不匹配：${persistedConfigPath}"
        exit 1
    fi
}

# loadPersistedStateFromConfig — 从 config.json 恢复协议模式、端口、path 与展示字段。
loadPersistedStateFromConfig() {
    local configFile="${dataDir%/}/config.json"
    local parsedLines=()

    if [[ ! -f "${configFile}" ]]; then
        echoContent "red" "未找到持久化配置：${configFile}"
        exit 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echoContent "red" "需要 python3 才能安全解析持久化的 config.json"
        exit 1
    fi

    loadPersistedSummaryIfPresent

    mapfile -t parsedLines < <(
        python3 - "${configFile}" <<'PY'
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
        echoContent "red" "持久化配置格式错误：无法从 ${configFile} 读取协议状态"
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
        [[ -n "${persistedVisionPort}" ]] || {
            echoContent "red" "持久化配置未包含 Vision 端口"
            exit 1
        }
        ;;
    xhttp)
        [[ -n "${persistedXHTTPPort}" && -n "${persistedXHTTPPath}" ]] || {
            echoContent "red" "持久化配置未包含 XHTTP 端口或 path"
            exit 1
        }
        ;;
    all)
        [[ -n "${persistedVisionPort}" && -n "${persistedXHTTPPort}" && -n "${persistedXHTTPPath}" ]] || {
            echoContent "red" "持久化配置未完整包含全部安装字段"
            exit 1
        }
        ;;
    *)
        echoContent "red" "安装模式无效：${persistedInstallMode}"
        exit 1
        ;;
    esac
}

# loadPersistedPort — 从持久化配置恢复协议模式与端口。
loadPersistedPort() {
    loadPersistedStateFromConfig
}

# getPublicIP — 尝试获取当前主机的公网 IP，用于展示 Reality 连接信息。
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

# loadPersistedAccountInfo — 从持久化摘要（优先）或 config.json 恢复展示所需的账号信息。
# 设置：persistedInstallMode、persistedVisionPort、persistedXHTTPPort、
#       persistedXHTTPPath、persistedServerName、persistedPublicKey、
#       persistedUUID、persistedEmailBase、persistedVisionEmail、
#       persistedXHTTPEmail、persistedShortId
loadPersistedAccountInfo() {
    local configFile="${dataDir%/}/config.json"

    if [[ ! -f "${configFile}" ]]; then
        echoContent "red" "未找到持久化配置：${configFile}"
        exit 1
    fi

    # 优先从摘要文件恢复（字段最完整）
    loadPersistedSummaryIfPresent

    # 若摘要文件缺失关键字段，则从 config.json 补充
    if [[ -z "${persistedInstallMode}" || -z "${persistedServerName}" || -z "${persistedUUID}" || -z "${persistedPublicKey}" ]]; then
        if ! command -v python3 >/dev/null 2>&1; then
            echoContent "red" "需要 python3 才能安全解析持久化的 config.json"
            exit 1
        fi

        local parsedLines=()
        mapfile -t parsedLines < <(
            python3 - "${configFile}" <<'PY'
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
            echoContent "red" "持久化配置格式错误：无法从 ${configFile} 读取账号信息"
            exit 1
        fi

        [[ -z "${persistedInstallMode}" ]] && persistedInstallMode="${parsedLines[0]}"
        [[ -z "${persistedVisionPort}" ]] && persistedVisionPort="${parsedLines[1]}"
        [[ -z "${persistedXHTTPPort}" ]] && persistedXHTTPPort="${parsedLines[2]}"
        [[ -z "${persistedXHTTPPath}" ]] && persistedXHTTPPath="${parsedLines[3]}"
        [[ -z "${persistedServerName}" ]] && persistedServerName="${parsedLines[4]}"
        [[ -z "${persistedPublicKey}" ]] && persistedPublicKey="${parsedLines[5]}"
        [[ -z "${persistedUUID}" ]] && persistedUUID="${parsedLines[6]}"
        [[ -z "${persistedVisionEmail}" ]] && persistedVisionEmail="${parsedLines[7]}"
        [[ -z "${persistedXHTTPEmail}" ]] && persistedXHTTPEmail="${parsedLines[8]}"
    fi

    # 补全邮箱字段
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

# hasPersistedConfig — 判断 dataDir 下是否已有持久化配置。
hasPersistedConfig() {
    local configFile="${dataDir%/}/config.json"
    [[ -f "${configFile}" ]]
}

# hasManagedContainer — 判断目标 Docker 容器是否存在（运行中或已停止均算存在）。
hasManagedContainer() {
    docker ps -a --filter "name=^/v2ray-agent-docker$" --format '{{.Names}}' 2>/dev/null | grep -q '^v2ray-agent-docker$'
}

# hasExistingInstallState — 只要配置文件或容器任意一个存在，就视为已安装/残留状态。
hasExistingInstallState() {
    if hasPersistedConfig || hasManagedContainer; then
        return 0
    fi
    return 1
}

# uninstallDockerReality — 卸载 Docker Reality 独立脚本生成的容器、配置与快捷方式。
uninstallDockerReality() {
    local answer=""
    local installedScript="/etc/v2ray-agent/docker_reality.sh"

    answer="$(promptValue $'是否确认卸载 Docker Reality 安装内容？[y/N]：' "")"
    case "${answer}" in
    [yY] | [yY][eE][sS]) ;;

    *)
        echoContent "green" " ---> 放弃卸载"
        return 0
        ;;
    esac

    if hasManagedContainer; then
        docker rm -f v2ray-agent-docker >/dev/null 2>&1 || true
        echoContent "green" " ---> 删除 Docker 容器完成"
    fi

    rm -rf "${dataDir%/}" >/dev/null 2>&1 || true
    echoContent "green" " ---> 删除 Docker Reality 配置目录完成"

    rm -rf /usr/bin/vasmad >/dev/null 2>&1 || true
    rm -rf /usr/sbin/vasmad >/dev/null 2>&1 || true
    echoContent "green" " ---> 卸载快捷方式完成"

    if [[ -f "${installedScript}" ]]; then
        rm -f "${installedScript}" >/dev/null 2>&1 || true
        echoContent "green" " ---> 删除脚本本体完成"
    fi

    exit 0
}

# promptExistingInstallAction — 根据配置文件与容器的组合状态提供交互菜单。
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
    echoContent green "作者：mack-a"
    echoContent green "当前版本：v0.0.1"
    echoContent green "Github：https://github.com/mack-a/v2ray-agent"
    echoContent green "描述：八合一docker版"
    if [[ ${hasConfig} -ne 0 && ${hasContainer} -ne 0 ]]; then
        echoContent "skyBlue" "─── 未检测到现有 Docker Reality 安装 ─────────────────────"
        echoContent "white" "未检测到配置文件与容器，请选择下一步操作："
        echoContent "yellow" "1. 安装"
        echoContent "yellow" "2. 退出"

        while true; do
            action="$(promptValue $'请选择 [1-2]：' "")"
            case "${action}" in
            1)
                echoContent "yellow" "已选择安装，将收集配置并创建容器。"
                return 0
                ;;
            2)
                echoContent "white" "已退出，不做任何修改。"
                exit 0
                ;;
            *)
                echoContent "red" "无效选择，请输入 1-2。"
                ;;
            esac
        done
    fi

    echoContent "skyBlue" "─── 检测到已有 Docker Reality 安装/残留状态 ──────────────"
    if [[ ${hasConfig} -eq 0 && ${hasContainer} -eq 0 ]]; then
        echoContent "white" "已检测到配置文件与容器。请选择下一步操作："
    elif [[ ${hasConfig} -eq 0 ]]; then
        echoContent "white" "已检测到配置文件，但未检测到容器。请选择下一步操作："
    else
        echoContent "white" "已检测到容器，但未检测到配置文件。请选择下一步操作："
    fi

    echoContent "yellow" "1. 查看账号"
    echoContent "yellow" "2. 重新安装"
    echoContent "yellow" "3. 启动/重建容器"
    echoContent "yellow" "4. 卸载"
    echoContent "yellow" "5. 退出"

    while true; do
        action="$(promptValue $'请选择 [1-5]：' "")"
        case "${action}" in
        1)
            if hasPersistedConfig; then
                showClientInfo
                exit 0
            else
                echoContent "red" "未找到现有配置，无法查看账号。请先重新安装。"
            fi
            ;;
        2)
            echoContent "yellow" "已选择重新安装，将重新收集配置并重建容器。"
            return 0
            ;;
        3)
            if ! hasExistingInstallState; then
                echoContent "red" "未检测到已安装状态，无法启动/重建容器。请先安装。"
                continue
            fi
            if ! hasPersistedConfig; then
                echoContent "red" "未找到现有配置，无法启动/重建容器。请先重新安装。"
                continue
            fi
            startOnly=1
            echoContent "yellow" "已选择使用已有配置启动/重建容器。"
            return 0
            ;;
        4)
            uninstallDockerReality
            ;;
        5)
            echoContent "white" "已退出，不做任何修改。"
            exit 0
            ;;
        *)
            echoContent "red" "无效选择，请输入 1-5。"
            ;;
        esac
    done
}

# showVisionAccount — 以 install.sh showAccounts 风格展示 Vision 账号。
# 参数：$1=address $2=port $3=serverName $4=publicKey $5=uuid $6=email $7=shortId
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

    echoContent "skyBlue" "============================= VLESS reality_vision [推荐]  =============================="
    echoContent "skyBlue" ""
    echoContent "skyBlue" " ---> 账号:${displayEmail}"
    echoContent "white" ""
    echoContent "yellow" " ---> 通用格式(VLESS+reality+uTLS+Vision)"
    echoContent "green" "    ${vlessLink}"
    echoContent "white" ""
    echoContent "yellow" " ---> 格式化明文(VLESS+reality+uTLS+Vision)"
    echoContent "green" "协议类型:VLESS reality，地址:${displayAddress}，publicKey:${displayPublicKey}，shortId: ${displayShortId}，serverNames：${displayServerName}，端口:${displayPort}，用户ID:${displayUUID}，传输方式:tcp，账户名:${displayEmail}"
    echoContent "white" ""
    echoContent "yellow" " ---> 二维码 VLESS(VLESS+reality+uTLS+Vision)"
    echoContent "green" "    ${qrLink}"
}

# showXHTTPAccount — 以 install.sh showAccounts 风格展示 XHTTP 账号。
# 参数：$1=address $2=port $3=serverName $4=publicKey $5=uuid $6=email $7=shortId $8=renderedPath
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

    echoContent "skyBlue" "============================= VLESS reality_xhttp  =============================="
    echoContent "skyBlue" ""
    echoContent "skyBlue" " ---> 账号:${displayEmail}"
    echoContent "white" ""
    echoContent "yellow" " ---> 通用格式(VLESS+reality+xhttp)"
    echoContent "green" "    ${vlessLink}"
    echoContent "white" ""
    echoContent "yellow" " ---> 格式化明文(VLESS+reality+xhttp)"
    echoContent "green" "协议类型:VLESS reality，地址:${displayAddress}，publicKey:${displayPublicKey}，shortId: ${displayShortId}，serverNames：${displayServerName}，端口:${displayPort}，路径：${displayPath}，SNI:${displayServerName}，伪装域名:${displayServerName}，用户ID:${displayUUID}，传输方式:xhttp，账户名:${displayEmail}"
    echoContent "white" ""
    echoContent "yellow" " ---> 二维码 VLESS(VLESS+reality+xhttp)"
    echoContent "green" "    ${qrLink}"
}

# resolveValues — 将所有 CLI 提供或留空的值解析为 resolved* 全局变量。
# 依赖：installMode/resolvedInstallMode、port、xhttpPort、xhttpPath、
#       serverName、privateKey、uuid、email（来自 parseCli 的全局变量）
# 设置：resolvedInstallMode、resolvedVisionPort、resolvedXHTTPPort、
#       resolvedXHTTPPath、resolvedServerName、resolvedTargetPort、
#       resolvedPrivateKey、resolvedPublicKey、resolvedUUID、
#       resolvedEmailBase、resolvedVisionEmail、resolvedXHTTPEmail
# 成功返回 0，输入无效时退出。
resolveValues() {
    local xrayRuntime
    xrayRuntime="$(_xrayDockerRuntime)"

    # --- 安装模式 ---
    normalizeInstallMode "${installMode}"
    # resolvedInstallMode 已由 normalizeInstallMode 设置

    # --- Vision 端口 ---
    if installModeHasVision "${resolvedInstallMode}"; then
        if ! parsePort "${port}"; then
            exit 1
        fi
        resolvedVisionPort="${resolvedPort}"
        checkPortInUse "${resolvedVisionPort}"
    fi

    # --- XHTTP 端口与 path ---
    if installModeHasXHTTP "${resolvedInstallMode}"; then
        if ! parsePort "${xhttpPort}"; then
            exit 1
        fi
        resolvedXHTTPPort="${resolvedPort}"
        # 确保 XHTTP 端口与 Vision 端口不冲突（all 模式）
        if installModeHasVision "${resolvedInstallMode}" && [[ "${resolvedXHTTPPort}" == "${resolvedVisionPort}" ]]; then
            echoContent "red" "XHTTP 端口（${resolvedXHTTPPort}）与 Vision 端口相同，请使用不同端口"
            exit 1
        fi
        checkPortInUse "${resolvedXHTTPPort}"

        normalizeXHTTPPath "${xhttpPath}"
        resolvedXHTTPPath="${resolvedXHTTPPath:-${resolvedXHTTPPath}}"
    fi

    # --- 服务器名称 ---
    parseServerName "${serverName}"

    # --- 私钥 ---
    if [[ -z "${privateKey}" ]]; then
        if ! generatePrivateKey "${xrayRuntime}"; then
            exit 1
        fi
    else
        resolvedPrivateKey="${privateKey}"
        if ! derivePublicKey "${xrayRuntime}" "${resolvedPrivateKey}"; then
            echoContent "red" "提供的私钥无效"
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

    # --- 邮箱基础名称与各协议邮箱 ---
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
        echoContent "green" "已解析 Vision 端口：  ${resolvedVisionPort}"
    fi
    if installModeHasXHTTP "${resolvedInstallMode}"; then
        echoContent "green" "已解析 XHTTP 端口：   ${resolvedXHTTPPort}"
        echoContent "green" "已解析 XHTTP path：   $(renderXHTTPPath "${resolvedXHTTPPath}")"
    fi
    echoContent "green" "已解析服务器名称：    ${resolvedServerName}:${resolvedTargetPort}"
    echoContent "green" "已解析邮箱基础名：    ${resolvedEmailBase}"
}

# ---------------------------------------------------------------------------
# _buildVisionInbounds — 输出 Vision 协议的两个 inbound JSON 块（不含尾随逗号）
# 参数：$1=visionPort $2=serverName $3=targetPort $4=privateKey $5=publicKey
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
# _buildXHTTPInbound — 输出 XHTTP 协议的 inbound JSON 块（不含尾随逗号）
# 参数：$1=xhttpPort $2=serverName $3=targetPort $4=privateKey $5=publicKey
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
# generateConfig — 将 Xray Reality 配置和客户端摘要写入 dataDir
# 支持 installMode: vision / xhttp / all
# ---------------------------------------------------------------------------
generateConfig() {
    # 去除末尾斜杠，使路径拼接无歧义
    dataDir="${dataDir%/}"

    echoContent "white" "正在 ${dataDir} 中生成 Reality 配置..."
    resolveValues

    # 创建数据目录；若路径无法创建则干净退出
    if ! mkdir -p "${dataDir}" 2>/dev/null; then
        echoContent "red" "创建数据目录失败：${dataDir}"
        echoContent "red" "请检查父路径是否存在且为目录而非普通文件"
        exit 1
    fi

    local configFile="${dataDir}/config.json"
    local summaryFile="${dataDir}/client-summary.txt"

    # 清除由之前失败运行留下的陈旧目录残留
    if [[ -d "${configFile}" ]]; then
        echoContent "yellow" "正在清除 ${configFile} 处由之前失败运行留下的陈旧目录"
        rm -rf "${configFile}" 2>/dev/null || {
            echoContent "red" "无法清除陈旧目录：${configFile}"
            exit 1
        }
    fi
    if [[ -d "${summaryFile}" ]]; then
        echoContent "yellow" "正在清除 ${summaryFile} 处由之前失败运行留下的陈旧目录"
        rm -rf "${summaryFile}" 2>/dev/null || {
            echoContent "red" "无法清除陈旧目录：${summaryFile}"
            exit 1
        }
    fi

    local renderedXHTTPPath=""
    if installModeHasXHTTP "${resolvedInstallMode}"; then
        renderedXHTTPPath="$(renderXHTTPPath "${resolvedXHTTPPath}")"
    fi

    # --- 构建 inbounds 数组内容 ---
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

    # --- 构建路由规则 ---
    # Vision 模式需要 dokodemo-door 路由规则；XHTTP 直接监听公网端口无需转发
    local routingRules=""
    if installModeHasVision "${resolvedInstallMode}"; then
        routingRules=$(
            cat <<REOF
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
        routingRules=$(
            cat <<REOF
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

    # 对配置文件设置严格权限（包含私钥）
    chmod 600 "${configFile}"

    # --- 写入人类可读的客户端摘要 ---
    # 字段与 loadPersistedSummaryIfPresent 解析逻辑严格对应
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

    # 写后验证：确认两个输出均为普通文件
    if [[ ! -f "${configFile}" ]]; then
        echoContent "red" "配置写入失败 — 写入后 ${configFile} 不是普通文件"
        exit 1
    fi
    if [[ ! -f "${summaryFile}" ]]; then
        echoContent "red" "摘要写入失败 — 写入后 ${summaryFile} 不是普通文件"
        exit 1
    fi

    echoContent "green" "配置已写入 ${configFile}"
    echoContent "green" "摘要已写入 ${summaryFile}"
}

# startContainer — 验证配置，删除已有容器，并重建（任务 5）
# 使用 dataDir 下的配置；在 generateConfig 之后或直接在 --start-only 模式下调用。
startContainer() {
    local xrayImage="ghcr.io/xtls/xray-core:26.5.9"
    local containerName="v2ray-agent-docker"

    # 去除末尾斜杠，使路径拼接一致
    dataDir="${dataDir%/}"

    local configFile="${dataDir}/config.json"

    # 在尝试任何操作前验证配置文件是否存在
    if [[ ! -f "${configFile}" ]]; then
        echoContent "red" "配置文件未找到：${configFile}"
        echoContent "red" "请不带 --start-only 运行以先生成配置"
        exit 1
    fi

    # --- 使用目录挂载验证配置 ---
    echoContent "white" "正在拉取 Xray 镜像 ${xrayImage}"
    docker pull "${xrayImage}" >/dev/null 2>&1 || true

    echoContent "white" "正在使用 Xray 镜像验证配置（目录挂载方式）..."
    if ! docker run --rm \
        --user root \
        -v "${dataDir}:/usr/local/etc/xray:ro" \
        "${xrayImage}" \
        run -test -c /usr/local/etc/xray/config.json; then
        echoContent "red" "Xray 配置验证失败 — 容器将不会启动"
        exit 1
    fi
    echoContent "green" "Xray 配置验证通过"

    # --- 删除同名的已有容器以避免名称冲突 ---
    if docker ps -a --filter "name=^/${containerName}$" --format '{{.Names}}' | grep -q "^${containerName}$"; then
        echoContent "yellow" "正在删除已有容器：${containerName}"
        docker rm -f "${containerName}" >/dev/null 2>&1 || true
    fi

    # --- 确定需要发布的端口列表 ---
    # start-only 模式从持久化摘要/配置中恢复协议模式与端口
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

    # 构建 -p 参数列表
    local portArgs=()
    if installModeHasVision "${activeInstallMode}" && [[ -n "${activeVisionPort}" ]]; then
        portArgs+=("-p" "${activeVisionPort}:${activeVisionPort}")
    fi
    if installModeHasXHTTP "${activeInstallMode}" && [[ -n "${activeXHTTPPort}" ]]; then
        portArgs+=("-p" "${activeXHTTPPort}:${activeXHTTPPort}")
    fi

    if [[ ${#portArgs[@]} -eq 0 ]]; then
        echoContent "red" "无法确定要发布的端口 — 请检查持久化配置"
        exit 1
    fi

    echoContent "white" "正在启动容器 ${containerName}（端口：${portArgs[*]})..."
    if ! docker run -d \
        --name "${containerName}" \
        --restart unless-stopped \
        --user root \
        "${portArgs[@]}" \
        -v "${dataDir}:/usr/local/etc/xray:ro" \
        "${xrayImage}" \
        run -c /usr/local/etc/xray/config.json; then
        echoContent "red" "启动容器 ${containerName} 失败"
        exit 1
    fi

    # --- 验证容器是否确实处于运行状态 ---
    local runningName
    runningName=$(docker ps --filter "name=^/${containerName}$" --format '{{.Names}}' 2>/dev/null || true)
    if [[ "${runningName}" != "${containerName}" ]]; then
        echoContent "red" "容器 ${containerName} 未能进入运行状态"
        docker logs "${containerName}" 2>/dev/null || true
        exit 1
    fi

}

# showClientInfo — 以 showAccounts 风格打印当前 Reality 账号信息
# 根据 installMode 只显示已安装协议的账号块
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
# main — 顶层流程
# ---------------------------------------------------------------------------
main() {
    parseCli "$@"

    if [[ "${generateOnly}" == "1" && "${startOnly}" == "1" ]]; then
        echoContent "red" "--generate-only 与 --start-only 互斥，不能同时使用"
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
