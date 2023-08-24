#!/usr/bin/env bash
# 检测区
# -------------------------------------------------------------
# 检查系统
export LANG=en_US.UTF-8

echoContent() {
    case $1 in
    # 红色
    "red")
        # shellcheck disable=SC2154
        ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        # 天蓝色
    "skyBlue")
        ${echoType} "\033[1;36m${printN}$2 \033[0m"
        ;;
        # 绿色
    "green")
        ${echoType} "\033[32m${printN}$2 \033[0m"
        ;;
        # 白色
    "white")
        ${echoType} "\033[37m${printN}$2 \033[0m"
        ;;
    "magenta")
        ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        # 黄色
    "yellow")
        ${echoType} "\033[33m${printN}$2 \033[0m"
        ;;
    esac
}
# 检查SELinux状态
checkCentosSELinux() {
    if [[ -f "/etc/selinux/config" ]] && ! grep -q "SELINUX=disabled" <"/etc/selinux/config"; then
        echoContent yellow "# 注意事项"
        echoContent yellow "检测到SELinux已开启，请手动关闭，教程如下"
        echoContent yellow "https://www.v2ray-agent.com/archives/1679931532764#heading-8 "
        exit 0
    fi
}
checkSystem() {
    if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
        mkdir -p /etc/yum.repos.d

        if [[ -f "/etc/centos-release" ]]; then
            centosVersion=$(rpm -q centos-release | awk -F "[-]" '{print $3}' | awk -F "[.]" '{print $1}')

            if [[ -z "${centosVersion}" ]] && grep </etc/centos-release -q -i "release 8"; then
                centosVersion=8
            fi
        fi

        release="centos"
        installType='yum -y install'
        removeType='yum -y remove'
        upgrade="yum update -y --skip-broken"
        checkCentosSELinux
    elif [[ -f "/etc/issue" ]] && grep </etc/issue -q -i "debian" || [[ -f "/proc/version" ]] && grep </etc/issue -q -i "debian" || [[ -f "/etc/os-release" ]] && grep </etc/os-release -q -i "ID=debian"; then
        release="debian"
        installType='apt -y install'
        upgrade="apt update"
        updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
        removeType='apt -y autoremove'

    elif [[ -f "/etc/issue" ]] && grep </etc/issue -q -i "ubuntu" || [[ -f "/proc/version" ]] && grep </etc/issue -q -i "ubuntu"; then
        release="ubuntu"
        installType='apt -y install'
        upgrade="apt update"
        updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
        removeType='apt -y autoremove'
        if grep </etc/issue -q -i "16."; then
            release=
        fi
    fi

    if [[ -z ${release} ]]; then
        echoContent red "\n本脚本不支持此系统，请将下方日志反馈给开发者\n"
        echoContent yellow "$(cat /etc/issue)"
        echoContent yellow "$(cat /proc/version)"
        exit 0
    fi
}

# 检查CPU提供商
checkCPUVendor() {
    if [[ -n $(which uname) ]]; then
        if [[ "$(uname)" == "Linux" ]]; then
            case "$(uname -m)" in
            'amd64' | 'x86_64')
                xrayCoreCPUVendor="Xray-linux-64"
                v2rayCoreCPUVendor="v2ray-linux-64"
                hysteriaCoreCPUVendor="hysteria-linux-amd64"
                tuicCoreCPUVendor="-x86_64-unknown-linux-musl"
                warpRegCoreCPUVendor="main-linux-amd64"
                ;;
            'armv8' | 'aarch64')
                cpuVendor="arm"
                xrayCoreCPUVendor="Xray-linux-arm64-v8a"
                v2rayCoreCPUVendor="v2ray-linux-arm64-v8a"
                hysteriaCoreCPUVendor="hysteria-linux-arm64"
                tuicCoreCPUVendor="-aarch64-unknown-linux-musl"
                warpRegCoreCPUVendor="main-linux-arm64"
                ;;
            *)
                echo "  不支持此CPU架构--->"
                exit 1
                ;;
            esac
        fi
    else
        echoContent red "  无法识别此CPU架构，默认amd64、x86_64--->"
        xrayCoreCPUVendor="Xray-linux-64"
        v2rayCoreCPUVendor="v2ray-linux-64"
    fi
}

# 初始化全局变量
initVar() {
    installType='yum -y install'
    removeType='yum -y remove'
    upgrade="yum -y update"
    echoType='echo -e'

    # 核心支持的cpu版本
    xrayCoreCPUVendor=""
    v2rayCoreCPUVendor=""
    hysteriaCoreCPUVendor=""
    warpRegCoreCPUVendor=""
    cpuVendor=""

    # 域名
    domain=

    # CDN节点的address
    add=

    # 安装总进度
    totalProgress=1

    # 1.xray-core安装
    # 2.v2ray-core 安装
    # 3.v2ray-core[xtls] 安装
    coreInstallType=

    # 核心安装path
    # coreInstallPath=

    # v2ctl Path
    ctlPath=
    # 1.全部安装
    # 2.个性化安装
    # v2rayAgentInstallType=

    # 当前的个性化安装方式 01234
    currentInstallProtocolType=

    # 当前alpn的顺序
    currentAlpn=

    # 前置类型
    frontingType=

    # 选择的个性化安装方式
    selectCustomInstallType=

    # v2ray-core、xray-core配置文件的路径
    configPath=

    # xray-core reality状态
    realityStatus=

    # hysteria 配置文件的路径
    hysteriaConfigPath=
    #    interfaceName=
    # 端口跳跃
    portHoppingStart=
    portHoppingEnd=
    portHopping=

    # tuic配置文件路径
    tuicConfigPath=
    tuicAlgorithm=
    tuicPort=

    # 配置文件的path
    currentPath=

    # 配置文件的host
    currentHost=

    # 安装时选择的core类型
    selectCoreType=

    # 默认core版本
    v2rayCoreVersion=

    # 随机路径
    customPath=

    # centos version
    centosVersion=

    # UUID
    currentUUID=

    # clients
    currentClients=

    # previousClients
    previousClients=

    localIP=

    # 定时任务执行任务名称 RenewTLS-更新证书 UpdateGeo-更新geo文件
    cronName=$1

    # tls安装失败后尝试的次数
    installTLSCount=

    # BTPanel状态
    #	BTPanelStatus=
    # 宝塔域名
    btDomain=
    # nginx配置文件路径
    nginxConfigPath=/etc/nginx/conf.d/
    nginxStaticPath=/usr/share/nginx/html/

    # 是否为预览版
    prereleaseStatus=false

    # ssl类型
    sslType=

    # ssl邮箱
    sslEmail=

    # 检查天数
    sslRenewalDays=90

    # dns ssl状态
    dnsSSLStatus=

    # dns tls domain
    dnsTLSDomain=

    # 该域名是否通过dns安装通配符证书
    installDNSACMEStatus=

    # 自定义端口
    customPort=

    # hysteria端口
    hysteriaPort=

    # hysteria协议
    hysteriaProtocol=

    # hysteria延迟
    hysteriaLag=

    # hysteria下行速度
    hysteriaClientDownloadSpeed=

    # hysteria上行速度
    hysteriaClientUploadSpeed=

    # Reality
    realityPrivateKey=
    realityServerNames=
    realityDestDomain=

    # 端口状态
    #    isPortOpen=
    # 通配符域名状态
    #    wildcardDomainStatus=
    # 通过nginx检查的端口
    #    nginxIPort=

    # wget show progress
    wgetShowProgressStatus=

    # warp
    reservedWarpReg=
    publicKeyWarpReg=
    addressWarpReg=
    secretKeyWarpReg=
}

# 读取tls证书详情
readAcmeTLS() {
    if [[ -n "${currentHost}" ]]; then
        dnsTLSDomain=$(echo "${currentHost}" | awk -F "[.]" '{print $(NF-1)"."$NF}')
    fi
    if [[ -d "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc" && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.key" && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.cer" ]]; then
        installDNSACMEStatus=true
    fi
}
# 读取默认自定义端口
readCustomPort() {
    if [[ -n "${configPath}" && -z "${realityStatus}" ]]; then
        local port=
        port=$(jq -r .inbounds[0].port "${configPath}${frontingType}.json")
        if [[ "${port}" != "443" ]]; then
            customPort=${port}
        fi
    fi
}
# 检测安装方式
readInstallType() {
    coreInstallType=
    configPath=
    hysteriaConfigPath=

    # 1.检测安装目录
    if [[ -d "/etc/v2ray-agent" ]]; then
        # 检测安装方式 v2ray-core
        if [[ -d "/etc/v2ray-agent/v2ray" && -f "/etc/v2ray-agent/v2ray/v2ray" && -f "/etc/v2ray-agent/v2ray/v2ctl" ]]; then
            if [[ -d "/etc/v2ray-agent/v2ray/conf" && -f "/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json" ]]; then
                configPath=/etc/v2ray-agent/v2ray/conf/
                if grep </etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json -q '"security": "tls"'; then
                    coreInstallType=2
                    ctlPath=/etc/v2ray-agent/v2ray/v2ctl
                fi
            fi
        fi

        if [[ -d "/etc/v2ray-agent/xray" && -f "/etc/v2ray-agent/xray/xray" ]]; then
            # 这里检测xray-core
            if [[ -d "/etc/v2ray-agent/xray/conf" ]] && [[ -f "/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json" || -f "/etc/v2ray-agent/xray/conf/02_trojan_TCP_inbounds.json" || -f "/etc/v2ray-agent/xray/conf/07_VLESS_vision_reality_inbounds.json" ]]; then
                # xray-core
                configPath=/etc/v2ray-agent/xray/conf/
                ctlPath=/etc/v2ray-agent/xray/xray
                coreInstallType=1
                if [[ -f "${configPath}07_VLESS_vision_reality_inbounds.json" ]]; then
                    realityStatus=1
                fi
            fi
        fi

        if [[ -d "/etc/v2ray-agent/hysteria" && -f "/etc/v2ray-agent/hysteria/hysteria" ]]; then
            # 这里检测 hysteria
            if [[ -d "/etc/v2ray-agent/hysteria/conf" ]] && [[ -f "/etc/v2ray-agent/hysteria/conf/config.json" ]] && [[ -f "/etc/v2ray-agent/hysteria/conf/client_network.json" ]]; then
                hysteriaConfigPath=/etc/v2ray-agent/hysteria/conf/
            fi
        fi

        if [[ -d "/etc/v2ray-agent/tuic" && -f "/etc/v2ray-agent/tuic/tuic" ]]; then
            if [[ -d "/etc/v2ray-agent/tuic/conf" ]] && [[ -f "/etc/v2ray-agent/tuic/conf/config.json" ]]; then
                tuicConfigPath=/etc/v2ray-agent/tuic/conf/
            fi
        fi

    fi
}

# 读取协议类型
readInstallProtocolType() {
    currentInstallProtocolType=
    frontingType=
    while read -r row; do
        if echo "${row}" | grep -q 02_trojan_TCP_inbounds; then
            currentInstallProtocolType=${currentInstallProtocolType}'trojan'
            frontingType=02_trojan_TCP_inbounds
        fi
        if echo "${row}" | grep -q VLESS_TCP_inbounds; then
            currentInstallProtocolType=${currentInstallProtocolType}'0'
            frontingType=02_VLESS_TCP_inbounds
        fi
        if echo "${row}" | grep -q VLESS_WS_inbounds; then
            currentInstallProtocolType=${currentInstallProtocolType}'1'
        fi
        if echo "${row}" | grep -q trojan_gRPC_inbounds; then
            currentInstallProtocolType=${currentInstallProtocolType}'2'
        fi
        if echo "${row}" | grep -q VMess_WS_inbounds; then
            currentInstallProtocolType=${currentInstallProtocolType}'3'
        fi
        if echo "${row}" | grep -q 04_trojan_TCP_inbounds; then
            currentInstallProtocolType=${currentInstallProtocolType}'4'
        fi
        if echo "${row}" | grep -q VLESS_gRPC_inbounds; then
            currentInstallProtocolType=${currentInstallProtocolType}'5'
        fi
        if echo "${row}" | grep -q VLESS_vision_reality_inbounds; then
            currentInstallProtocolType=${currentInstallProtocolType}'7'
        fi
        if echo "${row}" | grep -q VLESS_reality_fallback_grpc_inbounds; then
            currentInstallProtocolType=${currentInstallProtocolType}'8'
        fi

    done < <(find ${configPath} -name "*inbounds.json" | awk -F "[.]" '{print $1}')

    if [[ -n "${hysteriaConfigPath}" ]]; then
        currentInstallProtocolType=${currentInstallProtocolType}'6'
    fi
    if [[ -n "${tuicConfigPath}" ]]; then
        currentInstallProtocolType=${currentInstallProtocolType}'9'
    fi
}

# 检查是否安装宝塔
checkBTPanel() {
    if [[ -n $(pgrep -f "BT-Panel") ]]; then
        # 读取域名
        if [[ -d '/www/server/panel/vhost/cert/' && -n $(find /www/server/panel/vhost/cert/*/fullchain.pem) ]]; then
            if [[ -z "${currentHost}" ]]; then
                echoContent skyBlue "\n读取宝塔配置\n"

                find /www/server/panel/vhost/cert/*/fullchain.pem | awk -F "[/]" '{print $7}' | awk '{print NR""":"$0}'

                read -r -p "请输入编号选择:" selectBTDomain
            else
                selectBTDomain=$(find /www/server/panel/vhost/cert/*/fullchain.pem | awk -F "[/]" '{print $7}' | awk '{print NR""":"$0}' | grep "${currentHost}" | cut -d ":" -f 1)
            fi

            if [[ -n "${selectBTDomain}" ]]; then
                btDomain=$(find /www/server/panel/vhost/cert/*/fullchain.pem | awk -F "[/]" '{print $7}' | awk '{print NR""":"$0}' | grep "${selectBTDomain}:" | cut -d ":" -f 2)

                if [[ -z "${btDomain}" ]]; then
                    echoContent red " ---> 选择错误，请重新选择"
                    checkBTPanel
                else
                    domain=${btDomain}
                    if [[ ! -f "/etc/v2ray-agent/tls/${btDomain}.crt" && ! -f "/etc/v2ray-agent/tls/${btDomain}.key" ]]; then
                        ln -s "/www/server/panel/vhost/cert/${btDomain}/fullchain.pem" "/etc/v2ray-agent/tls/${btDomain}.crt"
                        ln -s "/www/server/panel/vhost/cert/${btDomain}/privkey.pem" "/etc/v2ray-agent/tls/${btDomain}.key"
                    fi

                    nginxStaticPath="/www/wwwroot/${btDomain}/"
                    if [[ -f "/www/wwwroot/${btDomain}/.user.ini" ]]; then
                        chattr -i "/www/wwwroot/${btDomain}/.user.ini"
                    fi
                    nginxConfigPath="/www/server/panel/vhost/nginx/"
                fi
            else
                echoContent red " ---> 选择错误，请重新选择"
                checkBTPanel
            fi
        fi
    fi
}
# 读取当前alpn的顺序
readInstallAlpn() {
    if [[ -n "${currentInstallProtocolType}" && -z "${realityStatus}" ]]; then
        local alpn
        alpn=$(jq -r .inbounds[0].streamSettings.tlsSettings.alpn[0] ${configPath}${frontingType}.json)
        if [[ -n ${alpn} ]]; then
            currentAlpn=${alpn}
        fi
    fi
}

# 检查防火墙
allowPort() {
    local type=$2
    if [[ -z "${type}" ]]; then
        type=tcp
    fi
    # 如果防火墙启动状态则添加相应的开放端口
    if systemctl status netfilter-persistent 2>/dev/null | grep -q "active (exited)"; then
        local updateFirewalldStatus=
        if ! iptables -L | grep -q "$1/${type}(mack-a)"; then
            updateFirewalldStatus=true
            iptables -I INPUT -p ${type} --dport "$1" -m comment --comment "allow $1/${type}(mack-a)" -j ACCEPT
        fi

        if echo "${updateFirewalldStatus}" | grep -q "true"; then
            netfilter-persistent save
        fi
    elif systemctl status ufw 2>/dev/null | grep -q "active (exited)"; then
        if ufw status | grep -q "Status: active"; then
            if ! ufw status | grep -q "$1/${type}"; then
                sudo ufw allow "$1/${type}"
                checkUFWAllowPort "$1"
            fi
        fi

    elif systemctl status firewalld 2>/dev/null | grep -q "active (running)"; then
        local updateFirewalldStatus=
        if ! firewall-cmd --list-ports --permanent | grep -qw "$1/${type}"; then
            updateFirewalldStatus=true
            local firewallPort=$1

            if echo "${firewallPort}" | grep ":"; then
                firewallPort=$(echo "${firewallPort}" | awk -F ":" '{print $1-$2}')
            fi

            firewall-cmd --zone=public --add-port="${firewallPort}/${type}" --permanent
            checkFirewalldAllowPort "${firewallPort}"
        fi

        if echo "${updateFirewalldStatus}" | grep -q "true"; then
            firewall-cmd --reload
        fi
    fi
}
# 获取公网IP
getPublicIP() {
    local type=4
    if [[ -n "$1" ]]; then
        type=$1
    fi
    if [[ -n "${currentHost}" && -n "${currentRealityServerNames}" && "${currentRealityServerNames}" == "${currentHost}" ]]; then
        echo "${currentHost}"
    else
        local currentIP=
        currentIP=$(curl -s "-${type}" http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
        if [[ -z "${currentIP}" && -z "$1" ]]; then
            currentIP=$(curl -s "-6" http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
        fi
        echo "${currentIP}"
    fi

}

# 输出ufw端口开放状态
checkUFWAllowPort() {
    if ufw status | grep -q "$1"; then
        echoContent green " ---> $1端口开放成功"
    else
        echoContent red " ---> $1端口开放失败"
        exit 0
    fi
}

# 输出firewall-cmd端口开放状态
checkFirewalldAllowPort() {
    if firewall-cmd --list-ports --permanent | grep -q "$1"; then
        echoContent green " ---> $1端口开放成功"
    else
        echoContent red " ---> $1端口开放失败"
        exit 0
    fi
}

# 读取hysteria网络环境
readHysteriaConfig() {
    if [[ -n "${hysteriaConfigPath}" ]]; then
        hysteriaLag=$(jq -r .hysteriaLag <"${hysteriaConfigPath}client_network.json")
        hysteriaClientDownloadSpeed=$(jq -r .hysteriaClientDownloadSpeed <"${hysteriaConfigPath}client_network.json")
        hysteriaClientUploadSpeed=$(jq -r .hysteriaClientUploadSpeed <"${hysteriaConfigPath}client_network.json")
        hysteriaPort=$(jq -r .listen <"${hysteriaConfigPath}config.json" | awk -F "[:]" '{print $2}')
        hysteriaProtocol=$(jq -r .protocol <"${hysteriaConfigPath}config.json")
    fi
}
# 读取Tuic配置
readTuicConfig() {
    if [[ -n "${tuicConfigPath}" ]]; then
        tuicPort=$(jq -r .server <"${tuicConfigPath}config.json" | cut -d ':' -f 4)
        tuicAlgorithm=$(jq -r .congestion_control <"${tuicConfigPath}config.json")
    fi
}
# 读取xray reality配置
readXrayCoreRealityConfig() {
    currentRealityServerNames=
    currentRealityPublicKey=
    currentRealityPrivateKey=
    currentRealityPort=

    if [[ -n "${realityStatus}" ]]; then
        currentRealityServerNames=$(jq -r .inbounds[0].streamSettings.realitySettings.serverNames[0] "${configPath}07_VLESS_vision_reality_inbounds.json")
        currentRealityPublicKey=$(jq -r .inbounds[0].streamSettings.realitySettings.publicKey "${configPath}07_VLESS_vision_reality_inbounds.json")
        currentRealityPrivateKey=$(jq -r .inbounds[0].streamSettings.realitySettings.privateKey "${configPath}07_VLESS_vision_reality_inbounds.json")
        currentRealityPort=$(jq -r .inbounds[0].port "${configPath}07_VLESS_vision_reality_inbounds.json")
    fi
}

# 检查文件目录以及path路径
readConfigHostPathUUID() {
    currentPath=
    currentDefaultPort=
    currentUUID=
    currentClients=
    currentHost=
    currentPort=
    currentAdd=

    if [[ "${coreInstallType}" == "1" ]]; then

        # 安装
        if [[ -n "${frontingType}" ]]; then
            currentHost=$(jq -r .inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile ${configPath}${frontingType}.json | awk -F '[t][l][s][/]' '{print $2}' | awk -F '[.][c][r][t]' '{print $1}')
            currentAdd=$(jq -r .inbounds[0].add ${configPath}${frontingType}.json)

            if [[ "${currentAdd}" == "null" ]]; then
                currentAdd=${currentHost}
            fi
            currentPort=$(jq .inbounds[0].port ${configPath}${frontingType}.json)

            local defaultPortFile=
            defaultPortFile=$(find ${configPath}* | grep "default")

            if [[ -n "${defaultPortFile}" ]]; then
                currentDefaultPort=$(echo "${defaultPortFile}" | awk -F [_] '{print $4}')
            else
                currentDefaultPort=$(jq -r .inbounds[0].port ${configPath}${frontingType}.json)
            fi
            currentUUID=$(jq -r .inbounds[0].settings.clients[0].id ${configPath}${frontingType}.json)
            currentClients=$(jq -r .inbounds[0].settings.clients ${configPath}${frontingType}.json)
        fi

        # reality
        if [[ -n "${realityStatus}" && -z "${currentClients}" ]]; then
            currentUUID=$(jq -r .inbounds[0].settings.clients[0].id ${configPath}07_VLESS_vision_reality_inbounds.json)
            currentClients=$(jq -r .inbounds[0].settings.clients ${configPath}07_VLESS_vision_reality_inbounds.json)

        fi
    elif [[ "${coreInstallType}" == "2" ]]; then
        currentHost=$(jq -r .inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile ${configPath}${frontingType}.json | awk -F '[t][l][s][/]' '{print $2}' | awk -F '[.][c][r][t]' '{print $1}')
        currentAdd=$(jq -r .inbounds[0].settings.clients[0].add ${configPath}${frontingType}.json)

        if [[ "${currentAdd}" == "null" ]]; then
            currentAdd=${currentHost}
        fi
        currentUUID=$(jq -r .inbounds[0].settings.clients[0].id ${configPath}${frontingType}.json)
        currentPort=$(jq .inbounds[0].port ${configPath}${frontingType}.json)
    fi

    # 读取path
    if [[ -n "${configPath}" && -n "${frontingType}" ]]; then
        local fallback
        fallback=$(jq -r -c '.inbounds[0].settings.fallbacks[]|select(.path)' ${configPath}${frontingType}.json | head -1)

        local path
        path=$(echo "${fallback}" | jq -r .path | awk -F "[/]" '{print $2}')

        if [[ $(echo "${fallback}" | jq -r .dest) == 31297 ]]; then
            currentPath=$(echo "${path}" | awk -F "[w][s]" '{print $1}')
        elif [[ $(echo "${fallback}" | jq -r .dest) == 31299 ]]; then
            currentPath=$(echo "${path}" | awk -F "[v][w][s]" '{print $1}')
        fi

        # 尝试读取alpn h2 Path
        if [[ -z "${currentPath}" ]]; then
            dest=$(jq -r -c '.inbounds[0].settings.fallbacks[]|select(.alpn)|.dest' ${configPath}${frontingType}.json | head -1)
            if [[ "${dest}" == "31302" || "${dest}" == "31304" ]]; then
                checkBTPanel
                if grep -q "trojangrpc {" <${nginxConfigPath}alone.conf; then
                    currentPath=$(grep "trojangrpc {" <${nginxConfigPath}alone.conf | awk -F "[/]" '{print $2}' | awk -F "[t][r][o][j][a][n]" '{print $1}')
                elif grep -q "grpc {" <${nginxConfigPath}alone.conf; then
                    currentPath=$(grep "grpc {" <${nginxConfigPath}alone.conf | head -1 | awk -F "[/]" '{print $2}' | awk -F "[g][r][p][c]" '{print $1}')
                fi
            fi
        fi

    fi
}

# 状态展示
showInstallStatus() {
    if [[ -n "${coreInstallType}" ]]; then
        if [[ "${coreInstallType}" == 1 ]]; then
            if [[ -n $(pgrep -f "xray/xray") ]]; then
                echoContent yellow "\n核心: Xray-core[运行中]"
            else
                echoContent yellow "\n核心: Xray-core[未运行]"
            fi

        elif [[ "${coreInstallType}" == 2 || "${coreInstallType}" == 3 ]]; then
            if [[ -n $(pgrep -f "v2ray/v2ray") ]]; then
                echoContent yellow "\n核心: v2ray-core[运行中]"
            else
                echoContent yellow "\n核心: v2ray-core[未运行]"
            fi
        fi
        # 读取协议类型
        readInstallProtocolType

        if [[ -n ${currentInstallProtocolType} ]]; then
            echoContent yellow "已安装协议: \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q 0; then
            if [[ "${coreInstallType}" == 2 ]]; then
                echoContent yellow "VLESS+TCP[TLS] \c"
            else
                echoContent yellow "VLESS+TCP[TLS_Vision] \c"
            fi
        fi

        if echo ${currentInstallProtocolType} | grep -q trojan; then
            if [[ "${coreInstallType}" == 1 ]]; then
                echoContent yellow "Trojan+TCP[TLS_Vision] \c"
            fi
        fi

        if echo ${currentInstallProtocolType} | grep -q 1; then
            echoContent yellow "VLESS+WS[TLS] \c"
        fi

        if echo ${currentInstallProtocolType} | grep -q 2; then
            echoContent yellow "Trojan+gRPC[TLS] \c"
        fi

        if echo ${currentInstallProtocolType} | grep -q 3; then
            echoContent yellow "VMess+WS[TLS] \c"
        fi

        if echo ${currentInstallProtocolType} | grep -q 4; then
            echoContent yellow "Trojan+TCP[TLS] \c"
        fi

        if echo ${currentInstallProtocolType} | grep -q 5; then
            echoContent yellow "VLESS+gRPC[TLS] \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q 7; then
            echoContent yellow "VLESS+Reality+Vision \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q 8; then
            echoContent yellow "VLESS+Reality+gRPC \c"
        fi
    fi
}

# 清理旧残留
cleanUp() {
    if [[ "$1" == "v2rayClean" ]]; then
        rm -rf "$(find /etc/v2ray-agent/v2ray/* | grep -E '(config_full.json|conf)')"
        handleV2Ray stop >/dev/null
        rm -f /etc/systemd/system/v2ray.service
    elif [[ "$1" == "xrayClean" ]]; then
        rm -rf "$(find /etc/v2ray-agent/xray/* | grep -E '(config_full.json|conf)')"
        handleXray stop >/dev/null
        rm -f /etc/systemd/system/xray.service

    elif [[ "$1" == "v2rayDel" ]]; then
        rm -rf /etc/v2ray-agent/v2ray/*

    elif [[ "$1" == "xrayDel" ]]; then
        rm -rf /etc/v2ray-agent/xray/*
    fi
}
initVar "$1"
checkSystem
checkCPUVendor
readInstallType
readInstallProtocolType
readConfigHostPathUUID
readInstallAlpn
readCustomPort
readXrayCoreRealityConfig
# -------------------------------------------------------------

# 初始化安装目录
mkdirTools() {
    mkdir -p /etc/v2ray-agent/tls
    mkdir -p /etc/v2ray-agent/subscribe_local/default
    mkdir -p /etc/v2ray-agent/subscribe_local/clashMeta

    mkdir -p /etc/v2ray-agent/subscribe_remote/default
    mkdir -p /etc/v2ray-agent/subscribe_remote/clashMeta

    mkdir -p /etc/v2ray-agent/subscribe/default
    mkdir -p /etc/v2ray-agent/subscribe/clashMetaProfiles
    mkdir -p /etc/v2ray-agent/subscribe/clashMeta

    mkdir -p /etc/v2ray-agent/v2ray/conf
    mkdir -p /etc/v2ray-agent/v2ray/tmp
    mkdir -p /etc/v2ray-agent/xray/conf
    mkdir -p /etc/v2ray-agent/xray/tmp
    mkdir -p /etc/v2ray-agent/hysteria/conf
    mkdir -p /etc/systemd/system/
    mkdir -p /tmp/v2ray-agent-tls/

    mkdir -p /etc/v2ray-agent/warp

    mkdir -p /etc/v2ray-agent/tuic/conf
}

# 安装工具包
installTools() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装工具"
    # 修复ubuntu个别系统问题
    if [[ "${release}" == "ubuntu" ]]; then
        dpkg --configure -a
    fi

    if [[ -n $(pgrep -f "apt") ]]; then
        pgrep -f apt | xargs kill -9
    fi

    echoContent green " ---> 检查、安装更新【新机器会很慢，如长时间无反应，请手动停止后重新执行】"

    ${upgrade} >/etc/v2ray-agent/install.log 2>&1
    if grep <"/etc/v2ray-agent/install.log" -q "changed"; then
        ${updateReleaseInfoChange} >/dev/null 2>&1
    fi

    if [[ "${release}" == "centos" ]]; then
        rm -rf /var/run/yum.pid
        ${installType} epel-release >/dev/null 2>&1
    fi

    #	[[ -z `find /usr/bin /usr/sbin |grep -v grep|grep -w curl` ]]

    if ! find /usr/bin /usr/sbin | grep -q -w wget; then
        echoContent green " ---> 安装wget"
        ${installType} wget >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w curl; then
        echoContent green " ---> 安装curl"
        ${installType} curl >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w unzip; then
        echoContent green " ---> 安装unzip"
        ${installType} unzip >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w socat; then
        echoContent green " ---> 安装socat"
        ${installType} socat >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w tar; then
        echoContent green " ---> 安装tar"
        ${installType} tar >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w cron; then
        echoContent green " ---> 安装crontabs"
        if [[ "${release}" == "ubuntu" ]] || [[ "${release}" == "debian" ]]; then
            ${installType} cron >/dev/null 2>&1
        else
            ${installType} crontabs >/dev/null 2>&1
        fi
    fi
    if ! find /usr/bin /usr/sbin | grep -q -w jq; then
        echoContent green " ---> 安装jq"
        ${installType} jq >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w binutils; then
        echoContent green " ---> 安装binutils"
        ${installType} binutils >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w ping6; then
        echoContent green " ---> 安装ping6"
        ${installType} inetutils-ping >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w qrencode; then
        echoContent green " ---> 安装qrencode"
        ${installType} qrencode >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w sudo; then
        echoContent green " ---> 安装sudo"
        ${installType} sudo >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w lsb-release; then
        echoContent green " ---> 安装lsb-release"
        ${installType} lsb-release >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w lsof; then
        echoContent green " ---> 安装lsof"
        ${installType} lsof >/dev/null 2>&1
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w dig; then
        echoContent green " ---> 安装dig"
        if echo "${installType}" | grep -q -w "apt"; then
            ${installType} dnsutils >/dev/null 2>&1
        elif echo "${installType}" | grep -q -w "yum"; then
            ${installType} bind-utils >/dev/null 2>&1
        fi
    fi

    # 检测nginx版本，并提供是否卸载的选项
    if [[ "${selectCustomInstallType}" == "7" ]]; then
        echoContent green " ---> 检测到无需依赖Nginx的服务，跳过安装"
    else
        if ! find /usr/bin /usr/sbin | grep -q -w nginx; then
            echoContent green " ---> 安装nginx"
            installNginxTools
        else
            nginxVersion=$(nginx -v 2>&1)
            nginxVersion=$(echo "${nginxVersion}" | awk -F "[n][g][i][n][x][/]" '{print $2}' | awk -F "[.]" '{print $2}')
            if [[ ${nginxVersion} -lt 14 ]]; then
                read -r -p "读取到当前的Nginx版本不支持gRPC，会导致安装失败，是否卸载Nginx后重新安装 ？[y/n]:" unInstallNginxStatus
                if [[ "${unInstallNginxStatus}" == "y" ]]; then
                    ${removeType} nginx >/dev/null 2>&1
                    echoContent yellow " ---> nginx卸载完成"
                    echoContent green " ---> 安装nginx"
                    installNginxTools >/dev/null 2>&1
                else
                    exit 0
                fi
            fi
        fi
    fi

    if ! find /usr/bin /usr/sbin | grep -q -w semanage; then
        echoContent green " ---> 安装semanage"
        ${installType} bash-completion >/dev/null 2>&1

        if [[ "${centosVersion}" == "7" ]]; then
            policyCoreUtils="policycoreutils-python.x86_64"
        elif [[ "${centosVersion}" == "8" ]]; then
            policyCoreUtils="policycoreutils-python-utils-2.9-9.el8.noarch"
        fi

        if [[ -n "${policyCoreUtils}" ]]; then
            ${installType} ${policyCoreUtils} >/dev/null 2>&1
        fi
        if [[ -n $(which semanage) ]]; then
            semanage port -a -t http_port_t -p tcp 31300

        fi
    fi
    if [[ "${selectCustomInstallType}" == "7" ]]; then
        echoContent green " ---> 检测到无需依赖证书的服务，跳过安装"
    else
        if [[ ! -d "$HOME/.acme.sh" ]] || [[ -d "$HOME/.acme.sh" && -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
            echoContent green " ---> 安装acme.sh"
            curl -s https://get.acme.sh | sh >/etc/v2ray-agent/tls/acme.log 2>&1

            if [[ ! -d "$HOME/.acme.sh" ]] || [[ -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
                echoContent red "  acme安装失败--->"
                tail -n 100 /etc/v2ray-agent/tls/acme.log
                echoContent yellow "错误排查:"
                echoContent red "  1.获取Github文件失败，请等待Github恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
                echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
                echoContent red "  3.如纯IPv6机器，请设置NAT64,可执行下方命令，如果添加下方命令还是不可用，请尝试更换其他NAT64"
                #                echoContent skyBlue "  echo -e \"nameserver 2001:67c:2b0::4\\\nnameserver 2a00:1098:2c::1\" >> /etc/resolv.conf"
                echoContent skyBlue "  sed -i \"1i\\\nameserver 2001:67c:2b0::4\\\nnameserver 2a00:1098:2c::1\" /etc/resolv.conf"
                exit 0
            fi
        fi
    fi

}

# 安装Nginx
installNginxTools() {

    if [[ "${release}" == "debian" ]]; then
        sudo apt install gnupg2 ca-certificates lsb-release -y >/dev/null 2>&1
        echo "deb http://nginx.org/packages/mainline/debian $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null 2>&1
        echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx >/dev/null 2>&1
        curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key >/dev/null 2>&1
        # gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
        sudo mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc
        sudo apt update >/dev/null 2>&1

    elif [[ "${release}" == "ubuntu" ]]; then
        sudo apt install gnupg2 ca-certificates lsb-release -y >/dev/null 2>&1
        echo "deb http://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null 2>&1
        echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx >/dev/null 2>&1
        curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key >/dev/null 2>&1
        # gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
        sudo mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc
        sudo apt update >/dev/null 2>&1

    elif [[ "${release}" == "centos" ]]; then
        ${installType} yum-utils >/dev/null 2>&1
        cat <<EOF >/etc/yum.repos.d/nginx.repo
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
        sudo yum-config-manager --enable nginx-mainline >/dev/null 2>&1
    fi
    ${installType} nginx >/dev/null 2>&1
    systemctl daemon-reload
    systemctl enable nginx
}

# 安装warp
installWarp() {
    if [[ "${cpuVendor}" == "arm" ]]; then
        echoContent red " ---> 官方WARP客户端不支持ARM架构"
        exit 0
    fi

    ${installType} gnupg2 -y >/dev/null 2>&1
    if [[ "${release}" == "debian" ]]; then
        curl -s https://pkg.cloudflareclient.com/pubkey.gpg | sudo apt-key add - >/dev/null 2>&1
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null 2>&1
        sudo apt update >/dev/null 2>&1

    elif [[ "${release}" == "ubuntu" ]]; then
        curl -s https://pkg.cloudflareclient.com/pubkey.gpg | sudo apt-key add - >/dev/null 2>&1
        echo "deb http://pkg.cloudflareclient.com/ focal main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null 2>&1
        sudo apt update >/dev/null 2>&1

    elif [[ "${release}" == "centos" ]]; then
        ${installType} yum-utils >/dev/null 2>&1
        sudo rpm -ivh "http://pkg.cloudflareclient.com/cloudflare-release-el${centosVersion}.rpm" >/dev/null 2>&1
    fi

    echoContent green " ---> 安装WARP"
    ${installType} cloudflare-warp >/dev/null 2>&1
    if [[ -z $(which warp-cli) ]]; then
        echoContent red " ---> 安装WARP失败"
        exit 0
    fi
    systemctl enable warp-svc
    warp-cli --accept-tos register
    warp-cli --accept-tos set-mode proxy
    warp-cli --accept-tos set-proxy-port 31303
    warp-cli --accept-tos connect
    warp-cli --accept-tos enable-always-on

    local warpStatus=
    warpStatus=$(curl -s --socks5 127.0.0.1:31303 https://www.cloudflare.com/cdn-cgi/trace | grep "warp" | cut -d "=" -f 2)

    if [[ "${warpStatus}" == "on" ]]; then
        echoContent green " ---> WARP启动成功"
    fi
}

# 通过dns检查域名的IP
checkDNSIP() {
    local domain=$1
    local dnsIP=
    local type=4
    dnsIP=$(dig @1.1.1.1 +time=1 +short "${domain}")
    if echo "${dnsIP}" | grep -q "timed out" || [[ -z "${dnsIP}" ]]; then
        echo
        echoContent red " ---> 无法通过DNS获取域名 IPv4 地址"
        echoContent green " ---> 尝试检查域名 IPv6 地址"
        dnsIP=$(dig @2606:4700:4700::1111 +time=1 aaaa +short "${domain}")
        type=6
        if [[ -z "${dnsIP}" ]]; then
            echoContent red " ---> 无法通过DNS获取域名IPv6地址，退出安装"
            exit 0
        fi
    fi
    local publicIP=

    publicIP=$(getPublicIP "${type}")
    if [[ "${publicIP}" != "${dnsIP}" ]]; then
        echoContent red " ---> 域名解析IP与当前服务器IP不一致\n"
        echoContent yellow " ---> 请检查域名解析是否生效以及正确"
        echoContent green " ---> 当前VPS IP：${publicIP}"
        echoContent green " ---> DNS解析 IP：${dnsIP}"
        exit 0
    else
        echoContent green " ---> 域名IP校验通过"
    fi
}
# 检查端口实际开放状态
checkPortOpen() {

    local port=$1
    local domain=$2
    local checkPortOpenResult=

    allowPort "${port}"

    # 初始化nginx配置
    touch ${nginxConfigPath}checkPortOpen.conf
    cat <<EOF >${nginxConfigPath}checkPortOpen.conf
    server {
        listen ${port};
        listen [::]:${port};
        server_name ${domain};
        location /checkPort {
            return 200 'fjkvymb6len';
        }
        location /ip {
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header REMOTE-HOST \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            default_type text/plain;
            return 200 \$proxy_add_x_forwarded_for;
        }
    }
EOF
    handleNginx start

    # 检查域名+端口的开放
    checkPortOpenResult=$(curl -s -m 2 "http://${domain}:${port}/checkPort")
    localIP=$(curl -s -m 2 "http://${domain}:${port}/ip")
    rm "${nginxConfigPath}checkPortOpen.conf"
    handleNginx stop
    if [[ "${checkPortOpenResult}" == "fjkvymb6len" ]]; then
        echoContent green " ---> 检测到${port}端口已开放"
    else
        echoContent green " ---> 未检测到${port}端口开放，退出安装"
        if echo "${checkPortOpenResult}" | grep -q "cloudflare"; then
            echoContent yellow " ---> 请关闭云朵后等待三分钟重新尝试"
        else
            if [[ -z "${checkPortOpenResult}" ]]; then
                echoContent red " ---> 请检查是否有网页防火墙，比如Oracle等云服务商"
                echoContent red " ---> 检查是否自己安装过nginx并且有配置冲突，可以尝试DD纯净系统后重新尝试"
            else
                echoContent red " ---> 错误日志：${checkPortOpenResult}，请将此错误日志通过issues提交反馈"
            fi
        fi
        exit 0
    fi
    checkIP "${localIP}"
}

# 初始化Nginx申请证书配置
initTLSNginxConfig() {
    handleNginx stop
    echoContent skyBlue "\n进度  $1/${totalProgress} : 初始化Nginx申请证书配置"
    if [[ -n "${currentHost}" ]]; then
        echo
        read -r -p "读取到上次安装记录，是否使用上次安装时的域名 ？[y/n]:" historyDomainStatus
        if [[ "${historyDomainStatus}" == "y" ]]; then
            domain=${currentHost}
            echoContent yellow "\n ---> 域名: ${domain}"
        else
            echo
            echoContent yellow "请输入要配置的域名 例: www.v2ray-agent.com --->"
            read -r -p "域名:" domain
        fi
    else
        echo
        echoContent yellow "请输入要配置的域名 例: www.v2ray-agent.com --->"
        read -r -p "域名:" domain
    fi

    if [[ -z ${domain} ]]; then
        echoContent red "  域名不可为空--->"
        initTLSNginxConfig 3
    else
        dnsTLSDomain=$(echo "${domain}" | awk -F "[.]" '{print $(NF-1)"."$NF}')
        customPortFunction
        # 修改配置
        handleNginx stop
        #        touch ${nginxConfigPath}alone.conf
        #        nginxIPort=80
        #        if [[ "${wildcardDomainStatus}" == "true" ]]; then
        #            nginxIPort=${port}
        #        fi
        #
        #        cat <<EOF >${nginxConfigPath}alone.conf
        #server {
        #    listen ${port};
        #    listen [::]:${port};
        #    server_name ${domain};
        #    location /test {
        #    	return 200 'fjkvymb6len';
        #    }
        #	location /ip {
        #		proxy_set_header Host \$host;
        #        proxy_set_header X-Real-IP \$remote_addr;
        #        proxy_set_header REMOTE-HOST \$remote_addr;
        #        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        #		default_type text/plain;
        #		return 200 \$proxy_add_x_forwarded_for;
        #	}
        #}
        #EOF
    fi

    #    readAcmeTLS
    #    handleNginx start
}

# 删除nginx默认的配置
removeNginxDefaultConf() {
    if [[ -f ${nginxConfigPath}default.conf ]]; then
        if [[ "$(grep -c "server_name" <${nginxConfigPath}default.conf)" == "1" ]] && [[ "$(grep -c "server_name  localhost;" <${nginxConfigPath}default.conf)" == "1" ]]; then
            echoContent green " ---> 删除Nginx默认配置"
            rm -rf ${nginxConfigPath}default.conf
        fi
    fi
}
# 修改nginx重定向配置
updateRedirectNginxConf() {
    local redirectDomain=
    redirectDomain=${domain}:${port}

    cat <<EOF >${nginxConfigPath}alone.conf
    server {
    		listen 127.0.0.1:31300;
    		server_name _;
    		return 403;
    }
EOF

    if echo "${selectCustomInstallType}" | grep -q 2 && echo "${selectCustomInstallType}" | grep -q 5 || [[ -z "${selectCustomInstallType}" ]]; then
        local nginxH2Conf=
        nginxH2Conf="listen 127.0.0.1:31302 http2 so_keepalive=on;"
        nginxVersion=$(nginx -v 2>&1)

        if echo "${nginxVersion}" | grep -q "1.25"; then
            nginxH2Conf="listen 127.0.0.1:31302 so_keepalive=on;http2 on;"
        fi
        cat <<EOF >>${nginxConfigPath}alone.conf
server {
	${nginxH2Conf}
	server_name ${domain};
	root ${nginxStaticPath};

	client_header_timeout 1071906480m;
    keepalive_timeout 1071906480m;

	location ~ ^/s/(clashMeta|default|clashMetaProfiles)/(.*) {
        default_type 'text/plain; charset=utf-8';
        alias /etc/v2ray-agent/subscribe/\$1/\$2;
    }

    location /${currentPath}grpc {
    	if (\$content_type !~ "application/grpc") {
    		return 404;
    	}
 		client_max_body_size 0;
		grpc_set_header X-Real-IP \$proxy_add_x_forwarded_for;
		client_body_timeout 1071906480m;
		grpc_read_timeout 1071906480m;
		grpc_pass grpc://127.0.0.1:31301;
	}

	location /${currentPath}trojangrpc {
		if (\$content_type !~ "application/grpc") {
            		return 404;
		}
 		client_max_body_size 0;
		grpc_set_header X-Real-IP \$proxy_add_x_forwarded_for;
		client_body_timeout 1071906480m;
		grpc_read_timeout 1071906480m;
		grpc_pass grpc://127.0.0.1:31304;
	}
	location / {
        	add_header Strict-Transport-Security "max-age=15552000; preload" always;
    }
}
EOF
    elif echo "${selectCustomInstallType}" | grep -q 5 || [[ -z "${selectCustomInstallType}" ]]; then
        cat <<EOF >>${nginxConfigPath}alone.conf
server {
	listen 127.0.0.1:31302 http2;
	server_name ${domain};
	root ${nginxStaticPath};
	location ~ ^/s/(clashMeta|default|clashMetaProfiles)/(.*) {
        default_type 'text/plain; charset=utf-8';
        alias /etc/v2ray-agent/subscribe/\$1/\$2;
    }
	location /${currentPath}grpc {
		client_max_body_size 0;
#		keepalive_time 1071906480m;
		keepalive_requests 4294967296;
		client_body_timeout 1071906480m;
 		send_timeout 1071906480m;
 		lingering_close always;
 		grpc_read_timeout 1071906480m;
 		grpc_send_timeout 1071906480m;
		grpc_pass grpc://127.0.0.1:31301;
	}
}
EOF

    elif echo "${selectCustomInstallType}" | grep -q 2 || [[ -z "${selectCustomInstallType}" ]]; then

        cat <<EOF >>${nginxConfigPath}alone.conf
server {
	listen 127.0.0.1:31302 http2;
	server_name ${domain};
	root ${nginxStaticPath};
	location ~ ^/s/(clashMeta|default|clashMetaProfiles)/(.*) {
        default_type 'text/plain; charset=utf-8';
        alias /etc/v2ray-agent/subscribe/\$1/\$2;
    }
	location /${currentPath}trojangrpc {
		client_max_body_size 0;
		# keepalive_time 1071906480m;
		keepalive_requests 4294967296;
		client_body_timeout 1071906480m;
 		send_timeout 1071906480m;
 		lingering_close always;
 		grpc_read_timeout 1071906480m;
 		grpc_send_timeout 1071906480m;
		grpc_pass grpc://127.0.0.1:31301;
	}
}
EOF
    else

        cat <<EOF >>${nginxConfigPath}alone.conf
server {
	listen 127.0.0.1:31302 http2;
	server_name ${domain};
	root ${nginxStaticPath};

    location ~ ^/s/(clashMeta|default|clashMetaProfiles)/(.*) {
            default_type 'text/plain; charset=utf-8';
            alias /etc/v2ray-agent/subscribe/\$1/\$2;
        }
	location / {
	}
}
EOF
    fi

    cat <<EOF >>${nginxConfigPath}alone.conf
server {
	listen 127.0.0.1:31300;
	server_name ${domain};
	root ${nginxStaticPath};
	location ~ ^/s/(clashMeta|default|clashMetaProfiles)/(.*) {
            default_type 'text/plain; charset=utf-8';
            alias /etc/v2ray-agent/subscribe/\$1/\$2;
        }
	location / {
		add_header Strict-Transport-Security "max-age=15552000; preload" always;
	}
}
EOF
    handleNginx stop
}

# 检查ip
checkIP() {
    echoContent skyBlue "\n ---> 检查域名ip中"
    local localIP=$1

    if [[ -z ${localIP} ]] || ! echo "${localIP}" | sed '1{s/[^(]*(//;s/).*//;q}' | grep -q '\.' && ! echo "${localIP}" | sed '1{s/[^(]*(//;s/).*//;q}' | grep -q ':'; then
        echoContent red "\n ---> 未检测到当前域名的ip"
        echoContent skyBlue " ---> 请依次进行下列检查"
        echoContent yellow " --->  1.检查域名是否书写正确"
        echoContent yellow " --->  2.检查域名dns解析是否正确"
        echoContent yellow " --->  3.如解析正确，请等待dns生效，预计三分钟内生效"
        echoContent yellow " --->  4.如报Nginx启动问题，请手动启动nginx查看错误，如自己无法处理请提issues"
        echo
        echoContent skyBlue " ---> 如以上设置都正确，请重新安装纯净系统后再次尝试"

        if [[ -n ${localIP} ]]; then
            echoContent yellow " ---> 检测返回值异常，建议手动卸载nginx后重新执行脚本"
            echoContent red " ---> 异常结果：${localIP}"
            exit 0
        fi
    else
        if echo "${localIP}" | awk -F "[,]" '{print $2}' | grep -q "." || echo "${localIP}" | awk -F "[,]" '{print $2}' | grep -q ":"; then
            echoContent red "\n ---> 检测到多个ip，请确认是否关闭cloudflare的云朵"
            echoContent yellow " ---> 关闭云朵后等待三分钟后重试"
            echoContent yellow " ---> 检测到的ip如下:[${localIP}]"
            exit 0
        fi
        #        echoContent green " ---> 当前域名ip为:[${localIP}]"
        echoContent green " ---> 检查当前域名IP正确"
    fi
}
# 自定义email
customSSLEmail() {
    if echo "$1" | grep -q "validate email"; then
        read -r -p "是否重新输入邮箱地址[y/n]:" sslEmailStatus
        if [[ "${sslEmailStatus}" == "y" ]]; then
            sed '/ACCOUNT_EMAIL/d' /root/.acme.sh/account.conf >/root/.acme.sh/account.conf_tmp && mv /root/.acme.sh/account.conf_tmp /root/.acme.sh/account.conf
        else
            exit 0
        fi
    fi

    if [[ -d "/root/.acme.sh" && -f "/root/.acme.sh/account.conf" ]]; then
        if ! grep -q "ACCOUNT_EMAIL" <"/root/.acme.sh/account.conf" && ! echo "${sslType}" | grep -q "letsencrypt"; then
            read -r -p "请输入邮箱地址:" sslEmail
            if echo "${sslEmail}" | grep -q "@"; then
                echo "ACCOUNT_EMAIL='${sslEmail}'" >>/root/.acme.sh/account.conf
                echoContent green " ---> 添加成功"
            else
                echoContent yellow "请重新输入正确的邮箱格式[例: username@example.com]"
                customSSLEmail
            fi
        fi
    fi

}
# 选择ssl安装类型
switchSSLType() {
    if [[ -z "${sslType}" ]]; then
        echoContent red "\n=============================================================="
        echoContent yellow "1.letsencrypt[默认]"
        echoContent yellow "2.zerossl"
        echoContent yellow "3.buypass[不支持DNS申请]"
        echoContent red "=============================================================="
        read -r -p "请选择[回车]使用默认:" selectSSLType
        case ${selectSSLType} in
        1)
            sslType="letsencrypt"
            ;;
        2)
            sslType="zerossl"
            ;;
        3)
            sslType="buypass"
            ;;
        *)
            sslType="letsencrypt"
            ;;
        esac
        echo "${sslType}" >/etc/v2ray-agent/tls/ssl_type

    fi
}

# 选择acme安装证书方式
selectAcmeInstallSSL() {
    local installSSLIPv6=

    if echo "${localIP}" | grep -q ":"; then
        installSSLIPv6="--listen-v6"
    fi
    echo
    if [[ -n "${customPort}" ]]; then
        if [[ "${selectSSLType}" == "3" ]]; then
            echoContent red " ---> buypass不支持免费通配符证书"
            echo
            exit
        fi
        dnsSSLStatus=true
        #    else
        #        if [[ -z "${dnsSSLStatus}" ]]; then
        #            read -r -p "是否使用DNS申请证书，如不会使用DNS申请证书请输入n[y/n]:" installSSLDNStatus
        #
        #            if [[ ${installSSLDNStatus} == 'y' ]]; then
        #                dnsSSLStatus=true
        #            else
        #                dnsSSLStatus=false
        #            fi
        #        fi

    fi
    acmeInstallSSL

    readAcmeTLS
}

# 安装SSL证书
acmeInstallSSL() {
    if [[ "${dnsSSLStatus}" == "true" ]]; then

        sudo "$HOME/.acme.sh/acme.sh" --issue -d "*.${dnsTLSDomain}" -d "${dnsTLSDomain}" --dns --yes-I-know-dns-manual-mode-enough-go-ahead-please -k ec-256 --server "${sslType}" ${installSSLIPv6} 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null

        local txtValue=
        txtValue=$(tail -n 10 /etc/v2ray-agent/tls/acme.log | grep "TXT value" | awk -F "'" '{print $2}')
        if [[ -n "${txtValue}" ]]; then
            echoContent green " ---> 请手动添加DNS TXT记录"
            echoContent yellow " ---> 添加方法请参考此教程，https://github.com/mack-a/v2ray-agent/blob/master/documents/dns_txt.md"
            echoContent yellow " ---> 如同一个域名多台机器安装通配符证书，请添加多个TXT记录，不需要修改以前添加的TXT记录"
            echoContent green " --->  name：_acme-challenge"
            echoContent green " --->  value：${txtValue}"
            echoContent yellow " ---> 添加完成后等请等待1-2分钟"
            echo
            read -r -p "是否添加完成[y/n]:" addDNSTXTRecordStatus
            if [[ "${addDNSTXTRecordStatus}" == "y" ]]; then
                local txtAnswer=
                txtAnswer=$(dig @1.1.1.1 +nocmd "_acme-challenge.${dnsTLSDomain}" txt +noall +answer | awk -F "[\"]" '{print $2}')
                if echo "${txtAnswer}" | grep -q "^${txtValue}"; then
                    echoContent green " ---> TXT记录验证通过"
                    echoContent green " ---> 生成证书中"
                    if [[ -n "${installSSLIPv6}" ]]; then
                        sudo "$HOME/.acme.sh/acme.sh" --renew -d "*.${dnsTLSDomain}" -d "${dnsTLSDomain}" --yes-I-know-dns-manual-mode-enough-go-ahead-please --ecc --server "${sslType}" ${installSSLIPv6} 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
                    else
                        sudo "$HOME/.acme.sh/acme.sh" --renew -d "*.${dnsTLSDomain}" -d "${dnsTLSDomain}" --yes-I-know-dns-manual-mode-enough-go-ahead-please --ecc --server "${sslType}" 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
                    fi
                else
                    echoContent red " ---> 验证失败，请等待1-2分钟后重新尝试"
                    acmeInstallSSL
                fi
            else
                echoContent red " ---> 放弃"
                exit 0
            fi
        fi
    else
        echoContent green " ---> 生成证书中"
        sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 --server "${sslType}" ${installSSLIPv6} 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
    fi
}
# 自定义端口
customPortFunction() {
    local historyCustomPortStatus=
    if [[ -n "${customPort}" || -n "${currentPort}" ]]; then
        echo
        read -r -p "读取到上次安装时的端口，是否使用上次安装时的端口？[y/n]:" historyCustomPortStatus
        if [[ "${historyCustomPortStatus}" == "y" ]]; then
            port=${currentPort}
            echoContent yellow "\n ---> 端口: ${port}"
        fi
    fi
    if [[ -z "${currentPort}" ]] || [[ "${historyCustomPortStatus}" == "n" ]]; then
        echo

        if [[ -n "${btDomain}" ]]; then
            echoContent yellow "请输入端口[不可与BT Panel端口相同，回车随机]"
            read -r -p "端口:" port
            if [[ -z "${port}" ]]; then
                port=$((RANDOM % 20001 + 10000))
            fi
        else
            echo
            echoContent yellow "请输入端口[默认: 443]，可自定义端口[回车使用默认]"
            read -r -p "端口:" port
            if [[ -z "${port}" ]]; then
                port=443
            fi
            if [[ "${port}" == "${currentRealityPort}" ]]; then
                handleXray stop
            fi

            # todo dns api
        fi

        if [[ -n "${port}" ]]; then
            if ((port >= 1 && port <= 65535)); then
                allowPort "${port}"
                echoContent yellow "\n ---> 端口: ${port}"
                if [[ -z "${btDomain}" ]]; then
                    checkDNSIP "${domain}"
                    removeNginxDefaultConf
                    checkPortOpen "${port}" "${domain}"
                fi
            else
                echoContent red " ---> 端口输入错误"
                exit 0
            fi
        else
            echoContent red " ---> 端口不可为空"
            exit 0
        fi
    fi
}

# 检测端口是否占用
checkPort() {
    if [[ -n "$1" ]] && lsof -i "tcp:$1" | grep -q LISTEN; then
        echoContent red "\n ---> $1端口被占用，请手动关闭后安装\n"
        lsof -i "tcp:$1" | grep LISTEN
        exit 0
    fi
}

# 安装TLS
installTLS() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 申请TLS证书\n"
    local tlsDomain=${domain}

    # 安装tls
    if [[ -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" && -f "/etc/v2ray-agent/tls/${tlsDomain}.key" && -n $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]] || [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
        echoContent green " ---> 检测到证书"
        # checkTLStatus
        renewalTLS

        if [[ -z $(find /etc/v2ray-agent/tls/ -name "${tlsDomain}.crt") ]] || [[ -z $(find /etc/v2ray-agent/tls/ -name "${tlsDomain}.key") ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
            sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
        else
            echoContent yellow " ---> 如未过期或者自定义证书请选择[n]\n"
            read -r -p "是否重新安装？[y/n]:" reInstallStatus
            if [[ "${reInstallStatus}" == "y" ]]; then
                rm -rf /etc/v2ray-agent/tls/*
                installTLS "$1"
            fi
        fi

    elif [[ -d "$HOME/.acme.sh" ]] && [[ ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" || ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" ]]; then
        echoContent green " ---> 安装TLS证书，需要依赖80端口"
        allowPort 80
        if [[ "${installDNSACMEStatus}" != "true" ]]; then
            switchSSLType
            customSSLEmail
            selectAcmeInstallSSL
            #   else
            #   echoContent green " ---> 检测到已安装通配符证书，自动生成中"
        fi
        #        if [[ "${installDNSACMEStatus}" == "true" ]]; then
        #            echo
        #            if [[ -d "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc" && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.key" && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.cer" ]]; then
        #                sudo "$HOME/.acme.sh/acme.sh" --installcert -d "*.${dnsTLSDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
        #            fi
        #
        #        el
        if [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
            sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
        fi

        if [[ ! -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" || ! -f "/etc/v2ray-agent/tls/${tlsDomain}.key" ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.key") || -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
            tail -n 10 /etc/v2ray-agent/tls/acme.log
            if [[ ${installTLSCount} == "1" ]]; then
                echoContent red " ---> TLS安装失败，请检查acme日志"
                exit 0
            fi

            installTLSCount=1
            echo

            if tail -n 10 /etc/v2ray-agent/tls/acme.log | grep -q "Could not validate email address as valid"; then
                echoContent red " ---> 邮箱无法通过SSL厂商验证，请重新输入"
                echo
                customSSLEmail "validate email"
                installTLS "$1"
            else
                installTLS "$1"
            fi
        fi

        echoContent green " ---> TLS生成成功"
    else
        echoContent yellow " ---> 未安装acme.sh"
        exit 0
    fi
}

# 初始化随机字符串
initRandomPath() {
    local chars="abcdefghijklmnopqrtuxyz"
    local initCustomPath=
    for i in {1..4}; do
        echo "${i}" >/dev/null
        initCustomPath+="${chars:RANDOM%${#chars}:1}"
    done
    customPath=${initCustomPath}
}

# 自定义/随机路径
randomPathFunction() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 生成随机路径"

    if [[ -n "${currentPath}" ]]; then
        echo
        read -r -p "读取到上次安装记录，是否使用上次安装时的path路径 ？[y/n]:" historyPathStatus
        echo
    fi

    if [[ "${historyPathStatus}" == "y" ]]; then
        customPath=${currentPath}
        echoContent green " ---> 使用成功\n"
    else
        echoContent yellow "请输入自定义路径[例: alone]，不需要斜杠，[回车]随机路径"
        read -r -p '路径:' customPath
        if [[ -z "${customPath}" ]]; then
            initRandomPath
            currentPath=${customPath}
        else
            if [[ "${customPath: -2}" == "ws" ]]; then
                echo
                echoContent red " ---> 自定义path结尾不可用ws结尾，否则无法区分分流路径"
                randomPathFunction "$1"
            else
                currentPath=${customPath}
            fi
        fi
    fi
    echoContent yellow "\n path:${currentPath}"
    echoContent skyBlue "\n----------------------------"
}
# Nginx伪装博客
nginxBlog() {
    echoContent skyBlue "\n进度 $1/${totalProgress} : 添加伪装站点"
    if [[ -d "${nginxStaticPath}" && -f "${nginxStaticPath}/check" ]]; then
        echo
        read -r -p "检测到安装伪装站点，是否需要重新安装[y/n]:" nginxBlogInstallStatus
        if [[ "${nginxBlogInstallStatus}" == "y" ]]; then
            rm -rf "${nginxStaticPath}"
            randomNum=$((RANDOM % 6 + 1))
            wget -q -P "${nginxStaticPath}" https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip >/dev/null
            unzip -o "${nginxStaticPath}html${randomNum}.zip" -d "${nginxStaticPath}" >/dev/null
            rm -f "${nginxStaticPath}html${randomNum}.zip*"
            echoContent green " ---> 添加伪装站点成功"
        fi
    else
        randomNum=$((RANDOM % 6 + 1))
        rm -rf "${nginxStaticPath}"
        wget -q -P "${nginxStaticPath}" https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip >/dev/null
        unzip -o "${nginxStaticPath}html${randomNum}.zip" -d "${nginxStaticPath}" >/dev/null
        rm -f "${nginxStaticPath}html${randomNum}.zip*"
        echoContent green " ---> 添加伪装站点成功"
    fi

}

# 修改http_port_t端口
updateSELinuxHTTPPortT() {

    $(find /usr/bin /usr/sbin | grep -w journalctl) -xe >/etc/v2ray-agent/nginx_error.log 2>&1

    if find /usr/bin /usr/sbin | grep -q -w semanage && find /usr/bin /usr/sbin | grep -q -w getenforce && grep -E "31300|31302" </etc/v2ray-agent/nginx_error.log | grep -q "Permission denied"; then
        echoContent red " ---> 检查SELinux端口是否开放"
        if ! $(find /usr/bin /usr/sbin | grep -w semanage) port -l | grep http_port | grep -q 31300; then
            $(find /usr/bin /usr/sbin | grep -w semanage) port -a -t http_port_t -p tcp 31300
            echoContent green " ---> http_port_t 31300 端口开放成功"
        fi

        if ! $(find /usr/bin /usr/sbin | grep -w semanage) port -l | grep http_port | grep -q 31302; then
            $(find /usr/bin /usr/sbin | grep -w semanage) port -a -t http_port_t -p tcp 31302
            echoContent green " ---> http_port_t 31302 端口开放成功"
        fi
        handleNginx start

    else
        exit 0
    fi
}

# 操作Nginx
handleNginx() {

    if [[ -z $(pgrep -f "nginx") ]] && [[ "$1" == "start" ]]; then
        systemctl start nginx 2>/etc/v2ray-agent/nginx_error.log

        sleep 0.5

        if [[ -z $(pgrep -f "nginx") ]]; then
            echoContent red " ---> Nginx启动失败"
            echoContent red " ---> 请手动尝试安装nginx后，再次执行脚本"

            if grep -q "journalctl -xe" </etc/v2ray-agent/nginx_error.log; then
                updateSELinuxHTTPPortT
            fi

            # exit 0
        else
            echoContent green " ---> Nginx启动成功"
        fi

    elif [[ -n $(pgrep -f "nginx") ]] && [[ "$1" == "stop" ]]; then
        systemctl stop nginx
        sleep 0.5
        if [[ -n $(pgrep -f "nginx") ]]; then
            pgrep -f "nginx" | xargs kill -9
        fi
        echoContent green " ---> Nginx关闭成功"
    fi
}

# 定时任务更新tls证书
installCronTLS() {
    if [[ -z "${btDomain}" ]]; then
        echoContent skyBlue "\n进度 $1/${totalProgress} : 添加定时维护证书"
        crontab -l >/etc/v2ray-agent/backup_crontab.cron
        local historyCrontab
        historyCrontab=$(sed '/v2ray-agent/d;/acme.sh/d' /etc/v2ray-agent/backup_crontab.cron)
        echo "${historyCrontab}" >/etc/v2ray-agent/backup_crontab.cron
        echo "30 1 * * * /bin/bash /etc/v2ray-agent/install.sh RenewTLS >> /etc/v2ray-agent/crontab_tls.log 2>&1" >>/etc/v2ray-agent/backup_crontab.cron
        crontab /etc/v2ray-agent/backup_crontab.cron
        echoContent green "\n ---> 添加定时维护证书成功"
    fi
}
# 定时任务更新geo文件
installCronUpdateGeo() {
    if [[ -n "${configPath}" ]]; then
        if crontab -l | grep -q "UpdateGeo"; then
            echoContent red "\n ---> 已添加自动更新定时任务，请不要重复添加"
            exit 0
        fi
        echoContent skyBlue "\n进度 1/1 : 添加定时更新geo文件"
        crontab -l >/etc/v2ray-agent/backup_crontab.cron
        echo "35 1 * * * /bin/bash /etc/v2ray-agent/install.sh UpdateGeo >> /etc/v2ray-agent/crontab_tls.log 2>&1" >>/etc/v2ray-agent/backup_crontab.cron
        crontab /etc/v2ray-agent/backup_crontab.cron
        echoContent green "\n ---> 添加定时更新geo文件成功"
    fi
}

# 更新证书
renewalTLS() {

    if [[ -n $1 ]]; then
        echoContent skyBlue "\n进度  $1/1 : 更新证书"
    fi
    readAcmeTLS
    local domain=${currentHost}
    if [[ -z "${currentHost}" && -n "${tlsDomain}" ]]; then
        domain=${tlsDomain}
    fi

    if [[ -f "/etc/v2ray-agent/tls/ssl_type" ]]; then
        if grep -q "buypass" <"/etc/v2ray-agent/tls/ssl_type"; then
            sslRenewalDays=180
        fi
    fi
    if [[ -d "$HOME/.acme.sh/${domain}_ecc" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.key" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.cer" ]] || [[ "${installDNSACMEStatus}" == "true" ]]; then
        modifyTime=

        if [[ "${installDNSACMEStatus}" == "true" ]]; then
            modifyTime=$(stat --format=%z "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.cer")
        else
            modifyTime=$(stat --format=%z "$HOME/.acme.sh/${domain}_ecc/${domain}.cer")
        fi

        modifyTime=$(date +%s -d "${modifyTime}")
        currentTime=$(date +%s)
        ((stampDiff = currentTime - modifyTime))
        ((days = stampDiff / 86400))
        ((remainingDays = sslRenewalDays - days))

        tlsStatus=${remainingDays}
        if [[ ${remainingDays} -le 0 ]]; then
            tlsStatus="已过期"
        fi

        echoContent skyBlue " ---> 证书检查日期:$(date "+%F %H:%M:%S")"
        echoContent skyBlue " ---> 证书生成日期:$(date -d @"${modifyTime}" +"%F %H:%M:%S")"
        echoContent skyBlue " ---> 证书生成天数:${days}"
        echoContent skyBlue " ---> 证书剩余天数:"${tlsStatus}
        echoContent skyBlue " ---> 证书过期前最后一天自动更新，如更新失败请手动更新"

        if [[ ${remainingDays} -le 1 ]]; then
            echoContent yellow " ---> 重新生成证书"
            handleNginx stop

            if [[ "${coreInstallType}" == "1" ]]; then
                handleXray stop
            elif [[ "${coreInstallType}" == "2" ]]; then
                handleV2Ray stop
            fi

            sudo "$HOME/.acme.sh/acme.sh" --cron --home "$HOME/.acme.sh"
            sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${domain}" --fullchainpath /etc/v2ray-agent/tls/"${domain}.crt" --keypath /etc/v2ray-agent/tls/"${domain}.key" --ecc
            reloadCore
            handleNginx start
        else
            echoContent green " ---> 证书有效"
        fi
    else
        echoContent red " ---> 未安装"
    fi
}
# 查看TLS证书的状态
checkTLStatus() {

    if [[ -d "$HOME/.acme.sh/${currentHost}_ecc" ]] && [[ -f "$HOME/.acme.sh/${currentHost}_ecc/${currentHost}.key" ]] && [[ -f "$HOME/.acme.sh/${currentHost}_ecc/${currentHost}.cer" ]]; then
        modifyTime=$(stat "$HOME/.acme.sh/${currentHost}_ecc/${currentHost}.cer" | sed -n '7,6p' | awk '{print $2" "$3" "$4" "$5}')

        modifyTime=$(date +%s -d "${modifyTime}")
        currentTime=$(date +%s)
        ((stampDiff = currentTime - modifyTime))
        ((days = stampDiff / 86400))
        ((remainingDays = sslRenewalDays - days))

        tlsStatus=${remainingDays}
        if [[ ${remainingDays} -le 0 ]]; then
            tlsStatus="已过期"
        fi

        echoContent skyBlue " ---> 证书生成日期:$(date -d "@${modifyTime}" +"%F %H:%M:%S")"
        echoContent skyBlue " ---> 证书生成天数:${days}"
        echoContent skyBlue " ---> 证书剩余天数:${tlsStatus}"
    fi
}

# 安装V2Ray、指定版本
installV2Ray() {
    readInstallType
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装V2Ray"

    if [[ "${coreInstallType}" != "2" && "${coreInstallType}" != "3" ]]; then
        if [[ "${selectCoreType}" == "2" ]]; then

            version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases?per_page=10 | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep -v 'v5' | head -1)
        else
            version=${v2rayCoreVersion}
        fi

        echoContent green " ---> v2ray-core版本:${version}"
        #        if wget --help | grep -q show-progress; then
        wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip"
        #        else
        #            wget -c -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip" >/dev/null 2>&1
        #        fi

        unzip -o "/etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip" -d /etc/v2ray-agent/v2ray >/dev/null
        rm -rf "/etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip"
    else
        if [[ "${selectCoreType}" == "3" ]]; then
            echoContent green " ---> 锁定v2ray-core版本为v4.32.1"
            rm -f /etc/v2ray-agent/v2ray/v2ray
            rm -f /etc/v2ray-agent/v2ray/v2ctl
            installV2Ray "$1"
        else
            echoContent green " ---> v2ray-core版本:$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"
            read -r -p "是否更新、升级？[y/n]:" reInstallV2RayStatus
            if [[ "${reInstallV2RayStatus}" == "y" ]]; then
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                installV2Ray "$1"
            fi
        fi
    fi
}

# 安装 hysteria
installHysteria() {
    readInstallType
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装Hysteria"

    if [[ -z "${hysteriaConfigPath}" ]]; then

        version=$(curl -s https://api.github.com/repos/apernet/hysteria/releases?per_page=5 | jq -r '.[]|select (.prerelease==false)|.tag_name' | head -1)

        echoContent green " ---> Hysteria版本:${version}"
        #        if wget --help | grep -q show-progress; then
        wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/hysteria/ "https://github.com/apernet/hysteria/releases/download/${version}/${hysteriaCoreCPUVendor}"
        #        else
        #            wget -c -P /etc/v2ray-agent/hysteria/ "https://github.com/apernet/hysteria/releases/download/${version}/${hysteriaCoreCPUVendor}" >/dev/null 2>&1
        #        fi
        mv "/etc/v2ray-agent/hysteria/${hysteriaCoreCPUVendor}" /etc/v2ray-agent/hysteria/hysteria
        chmod 655 /etc/v2ray-agent/hysteria/hysteria
    else
        echoContent green " ---> Hysteria版本:$(/etc/v2ray-agent/hysteria/hysteria --version | awk '{print $3}')"
        read -r -p "是否更新、升级？[y/n]:" reInstallHysteriaStatus
        if [[ "${reInstallHysteriaStatus}" == "y" ]]; then
            rm -f /etc/v2ray-agent/hysteria/hysteria
            installHysteria "$1"
        fi
    fi

}

# 安装 tuic
installTuic() {
    readInstallType
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装Tuic"

    if [[ -z "${tuicConfigPath}" ]]; then

        version=$(curl -s https://api.github.com/repos/EAimTY/tuic/releases?per_page=5 | jq -r '.[]|select (.prerelease==false)|.tag_name' | head -1)

        echoContent green " ---> Tuic版本:${version}"
        wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/tuic/ "https://github.com/EAimTY/tuic/releases/download/${version}/${version}${tuicCoreCPUVendor}"
        mv "/etc/v2ray-agent/tuic/${version}${tuicCoreCPUVendor}" /etc/v2ray-agent/tuic/tuic
        chmod 655 /etc/v2ray-agent/tuic/tuic
    else
        echoContent green " ---> Tuic版本:$(/etc/v2ray-agent/tuic/tuic -v)"
        read -r -p "是否更新、升级？[y/n]:" reInstallTuicStatus
        if [[ "${reInstallTuicStatus}" == "y" ]]; then
            rm -f /etc/v2ray-agent/tuic/tuic
            tuicConfigPath=
            installTuic "$1"
        fi
    fi

}
# 检查wget showProgress
checkWgetShowProgress() {
    if find /usr/bin /usr/sbin | grep -q -w wget && wget --help | grep -q show-progress; then
        wgetShowProgressStatus="--show-progress"
    fi
}
# 安装xray
installXray() {
    readInstallType
    local prereleaseStatus=false
    if [[ "$2" == "true" ]]; then
        prereleaseStatus=true
    fi

    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装Xray"

    if [[ "${coreInstallType}" != "1" ]]; then

        version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases?per_page=10 | jq -r '.[]|select (.prerelease=='${prereleaseStatus}')|.tag_name' | head -1)

        echoContent green " ---> Xray-core版本:${version}"

        #        if wget --help | grep -q show-progress; then
        wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
        #        else
        #            wget -c -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip" >/dev/null 2>&1
        #        fi
        if [[ ! -f "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" ]]; then
            echoContent red " ---> 核心下载失败，请重新尝试安装"
            exit 0
        fi

        unzip -o "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" -d /etc/v2ray-agent/xray >/dev/null
        rm -rf "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip"

        version=$(curl -s https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases?per_page=1 | jq -r '.[]|.tag_name')
        echoContent skyBlue "------------------------Version-------------------------------"
        echo "version:${version}"
        rm /etc/v2ray-agent/xray/geo* >/dev/null 2>&1

        wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/xray/ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat"
        wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/xray/ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat"

        chmod 655 /etc/v2ray-agent/xray/xray
    else
        echoContent green " ---> Xray-core版本:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"
        read -r -p "是否更新、升级？[y/n]:" reInstallXrayStatus
        if [[ "${reInstallXrayStatus}" == "y" ]]; then
            rm -f /etc/v2ray-agent/xray/xray
            installXray "$1" "$2"
        fi
    fi
}

# v2ray版本管理
v2rayVersionManageMenu() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : V2Ray版本管理"
    if [[ ! -d "/etc/v2ray-agent/v2ray/" ]]; then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0
    fi
    echoContent red "\n=============================================================="
    echoContent yellow "1.升级v2ray-core"
    echoContent yellow "2.回退v2ray-core"
    echoContent yellow "3.关闭v2ray-core"
    echoContent yellow "4.打开v2ray-core"
    echoContent yellow "5.重启v2ray-core"
    echoContent yellow "6.更新geosite、geoip"
    echoContent yellow "7.设置自动更新geo文件[每天凌晨更新]"
    echoContent red "=============================================================="
    read -r -p "请选择:" selectV2RayType
    if [[ "${selectV2RayType}" == "1" ]]; then
        updateV2Ray
    elif [[ "${selectV2RayType}" == "2" ]]; then
        echoContent yellow "\n1.只可以回退最近的五个版本"
        echoContent yellow "2.不保证回退后一定可以正常使用"
        echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
        echoContent skyBlue "------------------------Version-------------------------------"
        curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep -v 'v5' | head -5 | awk '{print ""NR""":"$0}'

        echoContent skyBlue "--------------------------------------------------------------"
        read -r -p "请输入要回退的版本:" selectV2rayVersionType
        version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep -v 'v5' | head -5 | awk '{print ""NR""":"$0}' | grep "${selectV2rayVersionType}:" | awk -F "[:]" '{print $2}')
        if [[ -n "${version}" ]]; then
            updateV2Ray "${version}"
        else
            echoContent red "\n ---> 输入有误，请重新输入"
            v2rayVersionManageMenu 1
        fi
    elif [[ "${selectV2RayType}" == "3" ]]; then
        handleV2Ray stop
    elif [[ "${selectV2RayType}" == "4" ]]; then
        handleV2Ray start
    elif [[ "${selectV2RayType}" == "5" ]]; then
        reloadCore
    elif [[ "${selectXrayType}" == "6" ]]; then
        updateGeoSite
    elif [[ "${selectXrayType}" == "7" ]]; then
        installCronUpdateGeo
    fi
}

# xray版本管理
xrayVersionManageMenu() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : Xray版本管理"
    if [[ ! -d "/etc/v2ray-agent/xray/" ]]; then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0
    fi
    echoContent red "\n=============================================================="
    echoContent yellow "1.升级Xray-core"
    echoContent yellow "2.升级Xray-core 预览版"
    echoContent yellow "3.回退Xray-core"
    echoContent yellow "4.关闭Xray-core"
    echoContent yellow "5.打开Xray-core"
    echoContent yellow "6.重启Xray-core"
    echoContent yellow "7.更新geosite、geoip"
    echoContent yellow "8.设置自动更新geo文件[每天凌晨更新]"
    echoContent red "=============================================================="
    read -r -p "请选择:" selectXrayType
    if [[ "${selectXrayType}" == "1" ]]; then
        updateXray
    elif [[ "${selectXrayType}" == "2" ]]; then

        prereleaseStatus=true
        updateXray

    elif [[ "${selectXrayType}" == "3" ]]; then
        echoContent yellow "\n1.只可以回退最近的五个版本"
        echoContent yellow "2.不保证回退后一定可以正常使用"
        echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
        echoContent skyBlue "------------------------Version-------------------------------"
        curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | head -5 | awk '{print ""NR""":"$0}'
        echoContent skyBlue "--------------------------------------------------------------"
        read -r -p "请输入要回退的版本:" selectXrayVersionType
        version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | head -5 | awk '{print ""NR""":"$0}' | grep "${selectXrayVersionType}:" | awk -F "[:]" '{print $2}')
        if [[ -n "${version}" ]]; then
            updateXray "${version}"
        else
            echoContent red "\n ---> 输入有误，请重新输入"
            xrayVersionManageMenu 1
        fi
    elif [[ "${selectXrayType}" == "4" ]]; then
        handleXray stop
    elif [[ "${selectXrayType}" == "5" ]]; then
        handleXray start
    elif [[ "${selectXrayType}" == "6" ]]; then
        reloadCore
    elif [[ "${selectXrayType}" == "7" ]]; then
        updateGeoSite
    elif [[ "${selectXrayType}" == "8" ]]; then
        installCronUpdateGeo
    fi
}

# 更新 geosite
updateGeoSite() {
    echoContent yellow "\n来源 https://github.com/Loyalsoldier/v2ray-rules-dat"

    version=$(curl -s https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases?per_page=1 | jq -r '.[]|.tag_name')
    echoContent skyBlue "------------------------Version-------------------------------"
    echo "version:${version}"
    rm ${configPath}../geo* >/dev/null
    wget -c -q "${wgetShowProgressStatus}" -P ${configPath}../ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat"
    wget -c -q "${wgetShowProgressStatus}" -P ${configPath}../ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat"
    reloadCore
    echoContent green " ---> 更新完毕"

}
# 更新V2Ray
updateV2Ray() {
    readInstallType
    if [[ -z "${coreInstallType}" ]]; then

        if [[ -n "$1" ]]; then
            version=$1
        else
            version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep -v 'v5' | head -1)
        fi
        # 使用锁定的版本
        if [[ -n "${v2rayCoreVersion}" ]]; then
            version=${v2rayCoreVersion}
        fi
        echoContent green " ---> v2ray-core版本:${version}"
        #        if wget --help | grep -q show-progress; then
        wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip"
        #        else
        #            wget -c -P "/etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip" >/dev/null 2>&1
        #        fi

        unzip -o "/etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip" -d /etc/v2ray-agent/v2ray >/dev/null
        rm -rf "/etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip"
        handleV2Ray stop
        handleV2Ray start
    else
        echoContent green " ---> 当前v2ray-core版本:$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"

        if [[ -n "$1" ]]; then
            version=$1
        else
            version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep -v 'v5' | head -1)
        fi

        if [[ -n "${v2rayCoreVersion}" ]]; then
            version=${v2rayCoreVersion}
        fi
        if [[ -n "$1" ]]; then
            read -r -p "回退版本为${version}，是否继续？[y/n]:" rollbackV2RayStatus
            if [[ "${rollbackV2RayStatus}" == "y" ]]; then
                if [[ "${coreInstallType}" == "2" ]]; then
                    echoContent green " ---> 当前v2ray-core版本:$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"
                elif [[ "${coreInstallType}" == "1" ]]; then
                    echoContent green " ---> 当前Xray-core版本:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"
                fi

                handleV2Ray stop
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                updateV2Ray "${version}"
            else
                echoContent green " ---> 放弃回退版本"
            fi
        elif [[ "${version}" == "v$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)" ]]; then
            read -r -p "当前版本与最新版相同，是否重新安装？[y/n]:" reInstallV2RayStatus
            if [[ "${reInstallV2RayStatus}" == "y" ]]; then
                handleV2Ray stop
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                updateV2Ray
            else
                echoContent green " ---> 放弃重新安装"
            fi
        else
            read -r -p "最新版本为:${version}，是否更新？[y/n]:" installV2RayStatus
            if [[ "${installV2RayStatus}" == "y" ]]; then
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                updateV2Ray
            else
                echoContent green " ---> 放弃更新"
            fi

        fi
    fi
}

# 更新Xray
updateXray() {
    readInstallType
    if [[ -z "${coreInstallType}" ]]; then
        if [[ -n "$1" ]]; then
            version=$1
        else
            version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
        fi

        echoContent green " ---> Xray-core版本:${version}"

        #        if wget --help | grep -q show-progress; then
        wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
        #        else
        #            wget -c -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip" >/dev/null 2>&1
        #        fi

        unzip -o "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" -d /etc/v2ray-agent/xray >/dev/null
        rm -rf "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip"
        chmod 655 /etc/v2ray-agent/xray/xray
        handleXray stop
        handleXray start
    else
        echoContent green " ---> 当前Xray-core版本:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"

        if [[ -n "$1" ]]; then
            version=$1
        else
            version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
        fi

        if [[ -n "$1" ]]; then
            read -r -p "回退版本为${version}，是否继续？[y/n]:" rollbackXrayStatus
            if [[ "${rollbackXrayStatus}" == "y" ]]; then
                echoContent green " ---> 当前Xray-core版本:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"

                handleXray stop
                rm -f /etc/v2ray-agent/xray/xray
                updateXray "${version}"
            else
                echoContent green " ---> 放弃回退版本"
            fi
        elif [[ "${version}" == "v$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)" ]]; then
            read -r -p "当前版本与最新版相同，是否重新安装？[y/n]:" reInstallXrayStatus
            if [[ "${reInstallXrayStatus}" == "y" ]]; then
                handleXray stop
                rm -f /etc/v2ray-agent/xray/xray
                rm -f /etc/v2ray-agent/xray/xray
                updateXray
            else
                echoContent green " ---> 放弃重新安装"
            fi
        else
            read -r -p "最新版本为:${version}，是否更新？[y/n]:" installXrayStatus
            if [[ "${installXrayStatus}" == "y" ]]; then
                rm -f /etc/v2ray-agent/xray/xray
                updateXray
            else
                echoContent green " ---> 放弃更新"
            fi

        fi
    fi
}

# 验证整个服务是否可用
checkGFWStatue() {
    readInstallType
    echoContent skyBlue "\n进度 $1/${totalProgress} : 验证服务启动状态"
    if [[ "${coreInstallType}" == "1" ]] && [[ -n $(pgrep -f "xray/xray") ]]; then
        echoContent green " ---> 服务启动成功"
    elif [[ "${coreInstallType}" == "2" ]] && [[ -n $(pgrep -f "v2ray/v2ray") ]]; then
        echoContent green " ---> 服务启动成功"
    else
        echoContent red " ---> 服务启动失败，请检查终端是否有日志打印"
        exit 0
    fi

}

# V2Ray开机自启
installV2RayService() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置V2Ray开机自启"
    if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
        rm -rf /etc/systemd/system/v2ray.service
        touch /etc/systemd/system/v2ray.service
        execStart='/etc/v2ray-agent/v2ray/v2ray -confdir /etc/v2ray-agent/v2ray/conf'
        cat <<EOF >/etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray - A unified platform for anti-censorship
Documentation=https://v2ray.com https://guide.v2fly.org
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=yes
ExecStart=${execStart}
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable v2ray.service
        echoContent green " ---> 配置V2Ray开机自启成功"
    fi
}

# 安装hysteria开机自启
installHysteriaService() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置Hysteria开机自启"
    if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
        rm -rf /etc/systemd/system/hysteria.service
        touch /etc/systemd/system/hysteria.service
        execStart='/etc/v2ray-agent/hysteria/hysteria --log-level info -c /etc/v2ray-agent/hysteria/conf/config.json server'
        cat <<EOF >/etc/systemd/system/hysteria.service
[Unit]
Description=Hysteria Service
Documentation=https://github.com/apernet
After=network.target nss-lookup.target
[Service]
User=root
ExecStart=${execStart}
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable hysteria.service
        echoContent green " ---> 配置Hysteria开机自启成功"
    fi
}
# 安装Tuic开机自启动
installTuicService() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置Tuic开机自启"
    if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
        rm -rf /etc/systemd/system/tuic.service
        touch /etc/systemd/system/tuic.service
        execStart='/etc/v2ray-agent/tuic/tuic -c /etc/v2ray-agent/tuic/conf/config.json'
        cat <<EOF >/etc/systemd/system/tuic.service
[Unit]
Description=Tuic Service
Documentation=https://github.com/EAimTY
After=network.target nss-lookup.target
[Service]
User=root
ExecStart=${execStart}
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable tuic.service
        echoContent green " ---> 配置Tuic开机自启成功"
    fi
}
# Xray开机自启
installXrayService() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置Xray开机自启"
    if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
        rm -rf /etc/systemd/system/xray.service
        touch /etc/systemd/system/xray.service
        execStart='/etc/v2ray-agent/xray/xray run -confdir /etc/v2ray-agent/xray/conf'
        cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target
[Service]
User=root
ExecStart=${execStart}
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable xray.service
        echoContent green " ---> 配置Xray开机自启成功"
    fi
}

# 操作V2Ray
handleV2Ray() {
    # shellcheck disable=SC2010
    if find /bin /usr/bin | grep -q systemctl && ls /etc/systemd/system/ | grep -q v2ray.service; then
        if [[ -z $(pgrep -f "v2ray/v2ray") ]] && [[ "$1" == "start" ]]; then
            systemctl start v2ray.service
        elif [[ -n $(pgrep -f "v2ray/v2ray") ]] && [[ "$1" == "stop" ]]; then
            systemctl stop v2ray.service
        fi
    fi
    sleep 0.8

    if [[ "$1" == "start" ]]; then
        if [[ -n $(pgrep -f "v2ray/v2ray") ]]; then
            echoContent green " ---> V2Ray启动成功"
        else
            echoContent red "V2Ray启动失败"
            echoContent red "请手动执行【/etc/v2ray-agent/v2ray/v2ray -confdir /etc/v2ray-agent/v2ray/conf】，查看错误日志"
            exit 0
        fi
    elif [[ "$1" == "stop" ]]; then
        if [[ -z $(pgrep -f "v2ray/v2ray") ]]; then
            echoContent green " ---> V2Ray关闭成功"
        else
            echoContent red "V2Ray关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep v2ray|awk '{print \$2}'|xargs kill -9】"
            exit 0
        fi
    fi
}

# 操作Hysteria
handleHysteria() {
    # shellcheck disable=SC2010
    if find /bin /usr/bin | grep -q systemctl && ls /etc/systemd/system/ | grep -q hysteria.service; then
        if [[ -z $(pgrep -f "hysteria/hysteria") ]] && [[ "$1" == "start" ]]; then
            systemctl start hysteria.service
        elif [[ -n $(pgrep -f "hysteria/hysteria") ]] && [[ "$1" == "stop" ]]; then
            systemctl stop hysteria.service
        fi
    fi
    sleep 0.8

    if [[ "$1" == "start" ]]; then
        if [[ -n $(pgrep -f "hysteria/hysteria") ]]; then
            echoContent green " ---> Hysteria启动成功"
        else
            echoContent red "Hysteria启动失败"
            echoContent red "请手动执行【/etc/v2ray-agent/hysteria/hysteria --log-level debug -c /etc/v2ray-agent/hysteria/conf/config.json server】，查看错误日志"
            exit 0
        fi
    elif [[ "$1" == "stop" ]]; then
        if [[ -z $(pgrep -f "hysteria/hysteria") ]]; then
            echoContent green " ---> Hysteria关闭成功"
        else
            echoContent red "Hysteria关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep hysteria|awk '{print \$2}'|xargs kill -9】"
            exit 0
        fi
    fi
}
# 操作Tuic
handleTuic() {
    # shellcheck disable=SC2010
    if find /bin /usr/bin | grep -q systemctl && ls /etc/systemd/system/ | grep -q tuic.service; then
        if [[ -z $(pgrep -f "tuic/tuic") ]] && [[ "$1" == "start" ]]; then
            systemctl start tuic.service
        elif [[ -n $(pgrep -f "tuic/tuic") ]] && [[ "$1" == "stop" ]]; then
            systemctl stop tuic.service
        fi
    fi
    sleep 0.8

    if [[ "$1" == "start" ]]; then
        if [[ -n $(pgrep -f "tuic/tuic") ]]; then
            echoContent green " ---> Tuic启动成功"
        else
            echoContent red "Tuic启动失败"
            echoContent red "请手动执行【/etc/v2ray-agent/tuic/tuic -c /etc/v2ray-agent/tuic/conf/config.json】，查看错误日志"
            exit 0
        fi
    elif [[ "$1" == "stop" ]]; then
        if [[ -z $(pgrep -f "tuic/tuic") ]]; then
            echoContent green " ---> Tuic关闭成功"
        else
            echoContent red "Tuic关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep tuic|awk '{print \$2}'|xargs kill -9】"
            exit 0
        fi
    fi
}
# 操作xray
handleXray() {
    if [[ -n $(find /bin /usr/bin -name "systemctl") ]] && [[ -n $(find /etc/systemd/system/ -name "xray.service") ]]; then
        if [[ -z $(pgrep -f "xray/xray") ]] && [[ "$1" == "start" ]]; then
            systemctl start xray.service
        elif [[ -n $(pgrep -f "xray/xray") ]] && [[ "$1" == "stop" ]]; then
            systemctl stop xray.service
        fi
    fi

    sleep 0.8

    if [[ "$1" == "start" ]]; then
        if [[ -n $(pgrep -f "xray/xray") ]]; then
            echoContent green " ---> Xray启动成功"
        else
            echoContent red "Xray启动失败"
            echoContent red "请手动执行以下的命令后【/etc/v2ray-agent/xray/xray -confdir /etc/v2ray-agent/xray/conf】将错误日志进行反馈"
            exit 0
        fi
    elif [[ "$1" == "stop" ]]; then
        if [[ -z $(pgrep -f "xray/xray") ]]; then
            echoContent green " ---> Xray关闭成功"
        else
            echoContent red "xray关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep xray|awk '{print \$2}'|xargs kill -9】"
            exit 0
        fi
    fi
}

# 读取用户数据并初始化
initXrayClients() {
    local type=$1
    local newUUID=$2
    local newEmail=$3
    if [[ -n "${newUUID}" ]]; then
        local newUser=
        newUser="{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-vision\",\"email\":\"${newEmail}-VLESS_TCP/TLS_Vision\"}"
        currentClients=$(echo "${currentClients}" | jq -r ". +=[${newUser}]")
    fi
    local users=
    if [[ "${type}" == "9" ]]; then
        users={}
    else
        users=[]
    fi

    while read -r user; do
        uuid=$(echo "${user}" | jq -r .id)
        email=$(echo "${user}" | jq -r .email | awk -F "[-]" '{print $1}')
        currentUser=
        if echo "${type}" | grep -q "0"; then
            currentUser="{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-vision\",\"email\":\"${email}-VLESS_TCP/TLS_Vision\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # VLESS WS
        if echo "${type}" | grep -q "1"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-VLESS_WS\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # trojan grpc
        if echo "${type}" | grep -q "2"; then
            currentUser="{\"password\":\"${uuid}\",\"email\":\"${email}-Trojan_gRPC\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # VMess WS
        if echo "${type}" | grep -q "3"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-VMess_WS\",\"alterId\": 0}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # trojan tcp
        if echo "${type}" | grep -q "4"; then
            currentUser="{\"password\":\"${uuid}\",\"email\":\"${email}-trojan_tcp\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # vless grpc
        if echo "${type}" | grep -q "5"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-vless_grpc\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # hysteria
        if echo "${type}" | grep -q "6"; then
            users=$(echo "${users}" | jq -r ". +=[\"${uuid}\"]")
        fi

        # vless reality vision
        if echo "${type}" | grep -q "7"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-vless_reality_vision\",\"flow\":\"xtls-rprx-vision\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # vless reality grpc
        if echo "${type}" | grep -q "8"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-vless_reality_grpc\",\"flow\":\"\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # tuic
        if echo "${type}" | grep -q "9"; then
            users=$(echo "${users}" | jq -r ".\"${uuid}\"=\"${uuid}\"")
        fi

    done < <(echo "${currentClients}" | jq -c '.[]')
    echo "${users}"
}
getClients() {
    local path=$1

    local addClientsStatus=$2
    previousClients=

    if [[ ${addClientsStatus} == "true" ]]; then
        if [[ ! -f "${path}" ]]; then
            echo
            local protocol
            protocol=$(echo "${path}" | awk -F "[_]" '{print $2 $3}')
            echoContent yellow "没有读取到此协议[${protocol}]上一次安装的配置文件，采用配置文件的第一个uuid"
        else
            previousClients=$(jq -r ".inbounds[0].settings.clients" "${path}")
        fi

    fi
}

# 添加client配置
addClients() {

    local path=$1
    local addClientsStatus=$2
    if [[ ${addClientsStatus} == "true" && -n "${previousClients}" ]]; then
        config=$(jq -r ".inbounds[0].settings.clients = ${previousClients}" "${path}")
        echo "${config}" | jq . >"${path}"
    fi
}
# 添加hysteria配置
addClientsHysteria() {
    local path=$1
    local addClientsStatus=$2

    if [[ ${addClientsStatus} == "true" && -n "${previousClients}" ]]; then
        local uuids=
        uuids=$(echo "${previousClients}" | jq -r [.[].id])

        if [[ "${frontingType}" == "02_trojan_TCP_inbounds" ]]; then
            uuids=$(echo "${previousClients}" | jq -r [.[].password])
        fi
        config=$(jq -r ".auth.config = ${uuids}" "${path}")
        echo "${config}" | jq . >"${path}"
    fi
}

# 初始化hysteria端口
initHysteriaPort() {
    readHysteriaConfig
    if [[ -n "${hysteriaPort}" ]]; then
        read -r -p "读取到上次安装时的端口，是否使用上次安装时的端口？[y/n]:" historyHysteriaPortStatus
        if [[ "${historyHysteriaPortStatus}" == "y" ]]; then
            echoContent yellow "\n ---> 端口: ${hysteriaPort}"
        else
            hysteriaPort=
        fi
    fi

    if [[ -z "${hysteriaPort}" ]]; then
        echoContent yellow "请输入Hysteria端口[回车随机10000-30000]，不可与其他服务重复"
        read -r -p "端口:" hysteriaPort
        if [[ -z "${hysteriaPort}" ]]; then
            hysteriaPort=$((RANDOM % 20001 + 10000))
        fi
    fi
    if [[ -z ${hysteriaPort} ]]; then
        echoContent red " ---> 端口不可为空"
        initHysteriaPort "$2"
    elif ((hysteriaPort < 1 || hysteriaPort > 65535)); then
        echoContent red " ---> 端口不合法"
        initHysteriaPort "$2"
    fi
    allowPort "${hysteriaPort}"
    allowPort "${hysteriaPort}" "udp"
}

# 初始化hysteria的协议
initHysteriaProtocol() {
    echoContent skyBlue "\n请选择协议类型"
    echoContent red "=============================================================="
    echoContent yellow "1.udp(QUIC)(默认)"
    echoContent yellow "2.faketcp"
    echoContent yellow "3.wechat-video"
    echoContent red "=============================================================="
    read -r -p "请选择:" selectHysteriaProtocol
    case ${selectHysteriaProtocol} in
    1)
        hysteriaProtocol="udp"
        ;;
    2)
        hysteriaProtocol="faketcp"
        ;;
    3)
        hysteriaProtocol="wechat-video"
        ;;
    *)
        hysteriaProtocol="udp"
        ;;
    esac
    echoContent yellow "\n ---> 协议: ${hysteriaProtocol}\n"
}

# 初始化hysteria网络信息
initHysteriaNetwork() {

    echoContent yellow "请输入本地到服务器的平均延迟，请按照真实情况填写（默认：180，单位：ms）"
    read -r -p "延迟:" hysteriaLag
    if [[ -z "${hysteriaLag}" ]]; then
        hysteriaLag=180
        echoContent yellow "\n ---> 延迟: ${hysteriaLag}\n"
    fi

    echoContent yellow "请输入本地带宽峰值的下行速度（默认：100，单位：Mbps）"
    read -r -p "下行速度:" hysteriaClientDownloadSpeed
    if [[ -z "${hysteriaClientDownloadSpeed}" ]]; then
        hysteriaClientDownloadSpeed=100
        echoContent yellow "\n ---> 下行速度: ${hysteriaClientDownloadSpeed}\n"
    fi

    echoContent yellow "请输入本地带宽峰值的上行速度（默认：50，单位：Mbps）"
    read -r -p "上行速度:" hysteriaClientUploadSpeed
    if [[ -z "${hysteriaClientUploadSpeed}" ]]; then
        hysteriaClientUploadSpeed=50
        echoContent yellow "\n ---> 上行速度: ${hysteriaClientUploadSpeed}\n"
    fi

    cat <<EOF >/etc/v2ray-agent/hysteria/conf/client_network.json
{
	"hysteriaLag":"${hysteriaLag}",
	"hysteriaClientUploadSpeed":"${hysteriaClientUploadSpeed}",
	"hysteriaClientDownloadSpeed":"${hysteriaClientDownloadSpeed}"
}
EOF

}

# hy端口跳跃
hysteriaPortHopping() {
    if [[ -n "${portHoppingStart}" || -n "${portHoppingEnd}" ]]; then
        echoContent red " ---> 已添加不可重复添加，可删除后重新添加"
        exit 0
    fi

    echoContent skyBlue "\n进度 1/1 : 端口跳跃"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "仅支持UDP"
    echoContent yellow "端口跳跃的起始位置为30000"
    echoContent yellow "端口跳跃的结束位置为60000"
    echoContent yellow "可以在30000-60000范围中选一段"
    echoContent yellow "建议1000个左右"

    echoContent yellow "请输入端口跳跃的范围，例如[30000-31000]"

    read -r -p "范围:" hysteriaPortHoppingRange
    if [[ -z "${hysteriaPortHoppingRange}" ]]; then
        echoContent red " ---> 范围不可为空"
        hysteriaPortHopping
    elif echo "${hysteriaPortHoppingRange}" | grep -q "-"; then

        local portStart=
        local portEnd=
        portStart=$(echo "${hysteriaPortHoppingRange}" | awk -F '-' '{print $1}')
        portEnd=$(echo "${hysteriaPortHoppingRange}" | awk -F '-' '{print $2}')

        if [[ -z "${portStart}" || -z "${portEnd}" ]]; then
            echoContent red " ---> 范围不合法"
            hysteriaPortHopping
        elif ((portStart < 30000 || portStart > 60000 || portEnd < 30000 || portEnd > 60000 || portEnd < portStart)); then
            echoContent red " ---> 范围不合法"
            hysteriaPortHopping
        else
            echoContent green "\n端口范围: ${hysteriaPortHoppingRange}\n"
            #            ip -4 addr show | awk '/inet /{print $NF ":" $2}' | awk '{print ""NR""":"$0}'
            #            read -r -p "请选择对应网卡:" selectInterface
            #            if ! ip -4 addr show | awk '/inet /{print $NF ":" $2}' | awk '{print ""NR""":"$0}' | grep -q "${selectInterface}:"; then
            #                echoContent red " ---> 选择错误"
            #                hysteriaPortHopping
            #            else
            iptables -t nat -A PREROUTING -p udp --dport "${portStart}:${portEnd}" -m comment --comment "mack-a_portHopping" -j DNAT --to-destination :${hysteriaPort}

            if iptables-save | grep -q "mack-a_portHopping"; then
                allowPort "${portStart}:${portEnd}" udp
                echoContent green " ---> 端口跳跃添加成功"
            else
                echoContent red " ---> 端口跳跃添加失败"
            fi
            #            fi
        fi

    fi
}

# 读取端口跳跃的配置
readHysteriaPortHopping() {
    if [[ -n "${hysteriaPort}" ]]; then
        #        interfaceName=$(ip -4 addr show | awk '/inet /{print $NF ":" $2}' | awk '{print ""NR""":"$0}' | grep "${selectInterface}:" | awk -F "[:]" '{print $2}')
        if iptables-save | grep -q "mack-a_portHopping"; then
            portHopping=
            portHopping=$(iptables-save | grep "mack-a_portHopping" | cut -d " " -f 8)
            portHoppingStart=$(echo "${portHopping}" | cut -d ":" -f 1)
            portHoppingEnd=$(echo "${portHopping}" | cut -d ":" -f 2)
        fi
    fi
}

# 删除hysteria 端口条约iptables规则
deleteHysteriaPortHoppingRules() {
    iptables -t nat -L PREROUTING --line-numbers | grep "mack-a_portHopping" | awk '{print $1}' | while read -r line; do
        iptables -t nat -D PREROUTING 1
    done
}

hysteriaPortHoppingMenu() {
    # 判断iptables是否存在
    if ! find /usr/bin /usr/sbin | grep -q -w iptables; then
        echoContent red " ---> 无法识别iptables工具，无法使用端口跳跃，退出安装"
        exit 0
    fi
    readHysteriaConfig
    readHysteriaPortHopping
    echoContent skyBlue "\n进度 1/1 : 端口跳跃"
    echoContent red "\n=============================================================="
    echoContent yellow "1.添加端口跳跃"
    echoContent yellow "2.删除端口跳跃"
    echoContent yellow "3.查看端口跳跃"
    read -r -p "范围:" selectPortHoppingStatus
    if [[ "${selectPortHoppingStatus}" == "1" ]]; then
        hysteriaPortHopping
    elif [[ "${selectPortHoppingStatus}" == "2" ]]; then
        if [[ -n "${portHopping}" ]]; then
            deleteHysteriaPortHoppingRules
            echoContent green " ---> 删除成功"
        fi
    elif [[ "${selectPortHoppingStatus}" == "3" ]]; then
        echoContent green " ---> 当前端口跳跃范围为: ${portHoppingStart}-${portHoppingEnd}"
    else
        hysteriaPortHoppingMenu
    fi
}
# 初始化Hysteria配置
initHysteriaConfig() {
    echoContent skyBlue "\n进度 $1/${totalProgress} : 初始化Hysteria配置"

    initHysteriaPort
    initHysteriaProtocol
    initHysteriaNetwork
    local uuid=
    uuid=$(${ctlPath} uuid)
    getClients "${configPath}${frontingType}.json" true
    cat <<EOF >/etc/v2ray-agent/hysteria/conf/config.json
{
	"listen": ":${hysteriaPort}",
	"protocol": "${hysteriaProtocol}",
	"disable_udp": false,
	"cert": "/etc/v2ray-agent/tls/${currentHost}.crt",
	"key": "/etc/v2ray-agent/tls/${currentHost}.key",
	"auth": {
		"mode": "passwords",
		"config": []
	},
	"socks5_outbound":{
	    "server":"127.0.0.1:31295",
	    "user":"hysteria_socks5_outbound",
	    "password":"${uuid}"
	},
	"alpn": "h3",
	"recv_window_conn": 15728640,
	"recv_window_client": 67108864,
	"max_conn_client": 4096,
	"disable_mtu_discovery": true,
	"resolve_preference": "46",
	"resolver": "https://8.8.8.8:443/dns-query"
}
EOF

    addClientsHysteria "/etc/v2ray-agent/hysteria/conf/config.json" true

    # 添加socks入站
    cat <<EOF >${configPath}/02_socks_inbounds_hysteria.json
{
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 31295,
      "protocol": "Socks",
      "tag": "socksHysteriaOutbound",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "hysteria_socks5_outbound",
            "pass": "${uuid}"
          }
        ],
        "udp": true,
        "ip": "127.0.0.1"
      }
    }
  ]
}
EOF
}

# 初始化tuic端口
initTuicPort() {
    readTuicConfig
    if [[ -n "${tuicPort}" ]]; then
        read -r -p "读取到上次安装时的端口，是否使用上次安装时的端口？[y/n]:" historyTuicPortStatus
        if [[ "${historyTuicPortStatus}" == "y" ]]; then
            echoContent yellow "\n ---> 端口: ${tuicPort}"
        else
            tuicPort=
        fi
    fi

    if [[ -z "${tuicPort}" ]]; then
        echoContent yellow "请输入Tuic端口[回车随机10000-30000]，不可与其他服务重复"
        read -r -p "端口:" tuicPort
        if [[ -z "${tuicPort}" ]]; then
            tuicPort=$((RANDOM % 20001 + 10000))
        fi
    fi
    if [[ -z ${tuicPort} ]]; then
        echoContent red " ---> 端口不可为空"
        initTuicPort "$2"
    elif ((tuicPort < 1 || tuicPort > 65535)); then
        echoContent red " ---> 端口不合法"
        initTuicPort "$2"
    fi
    echoContent green "\n ---> 端口: ${tuicPort}"
    allowPort "${tuicPort}"
    allowPort "${tuicPort}" "udp"
}

# 初始化tuic的协议
initTuicProtocol() {
    echoContent skyBlue "\n请选择算法类型"
    echoContent red "=============================================================="
    echoContent yellow "1.bbr(默认)"
    echoContent yellow "2.cubic"
    echoContent yellow "3.new_reno"
    echoContent red "=============================================================="
    read -r -p "请选择:" selectTuicAlgorithm
    case ${selectTuicAlgorithm} in
    1)
        tuicAlgorithm="bbr"
        ;;
    2)
        tuicAlgorithm="cubic"
        ;;
    3)
        tuicAlgorithm="new_reno"
        ;;
    *)
        tuicAlgorithm="bbr"
        ;;
    esac
    echoContent yellow "\n ---> 算法: ${tuicAlgorithm}\n"
}

# 初始化tuic配置
initTuicConfig() {
    echoContent skyBlue "\n进度 $1/${totalProgress} : 初始化Tuic配置"

    initTuicPort
    initTuicProtocol
    cat <<EOF >/etc/v2ray-agent/tuic/conf/config.json
{
    "server": "[::]:${tuicPort}",
    "users": $(initXrayClients 9),
    "certificate": "/etc/v2ray-agent/tls/${currentHost}.crt",
    "private_key": "/etc/v2ray-agent/tls/${currentHost}.key",
    "congestion_control":"${tuicAlgorithm}",
    "alpn": ["h3"],
    "log_level": "warn"
}
EOF
}

# Tuic安装
tuicCoreInstall() {
    if ! echo "${currentInstallProtocolType}" | grep -q "0" || [[ -z "${coreInstallType}" ]]; then
        echoContent red "\n ---> 由于环境依赖，如安装Tuic，请先安装Xray-core的VLESS_TCP_TLS_Vision"
        exit 0
    fi
    totalProgress=5
    installTuic 1
    initTuicConfig 2
    installTuicService 3
    reloadCore
    showAccounts 4
}

# 初始化V2Ray 配置文件
initV2RayConfig() {
    echoContent skyBlue "\n进度 $2/${totalProgress} : 初始化V2Ray配置"
    echo

    read -r -p "是否自定义UUID ？[y/n]:" customUUIDStatus
    echo
    if [[ "${customUUIDStatus}" == "y" ]]; then
        read -r -p "请输入合法的UUID:" currentCustomUUID
        if [[ -n "${currentCustomUUID}" ]]; then
            uuid=${currentCustomUUID}
        fi
    fi
    local addClientsStatus=
    if [[ -n "${currentUUID}" && -z "${uuid}" ]]; then
        read -r -p "读取到上次安装记录，是否使用上次安装时的UUID ？[y/n]:" historyUUIDStatus
        if [[ "${historyUUIDStatus}" == "y" ]]; then
            uuid=${currentUUID}
            addClientsStatus=true
        else
            uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
        fi
    elif [[ -z "${uuid}" ]]; then
        uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
    fi

    if [[ -z "${uuid}" ]]; then
        addClientsStatus=
        echoContent red "\n ---> uuid读取错误，重新生成"
        uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
    fi

    movePreviousConfig
    # log
    cat <<EOF >/etc/v2ray-agent/v2ray/conf/00_log.json
{
  "log": {
    "error": "/etc/v2ray-agent/v2ray/error.log",
    "loglevel": "warning"
  }
}
EOF
    # outbounds
    if [[ -n "${pingIPv6}" ]]; then
        cat <<EOF >/etc/v2ray-agent/v2ray/conf/10_ipv6_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {},
          "tag": "direct"
        }
    ]
}
EOF

    else
        cat <<EOF >/etc/v2ray-agent/v2ray/conf/10_ipv4_outbounds.json
{
    "outbounds":[
        {
            "protocol":"freedom",
            "settings":{
                "domainStrategy":"UseIPv4"
            },
            "tag":"IPv4-out"
        },
        {
            "protocol":"freedom",
            "settings":{
                "domainStrategy":"UseIPv6"
            },
            "tag":"IPv6-out"
        },
        {
            "protocol":"blackhole",
            "tag":"blackhole-out"
        }
    ]
}
EOF
    fi

    # dns
    cat <<EOF >/etc/v2ray-agent/v2ray/conf/11_dns.json
{
    "dns": {
        "servers": [
          "localhost"
        ]
  }
}
EOF

    # VLESS_TCP_TLS
    # 回落nginx
    local fallbacksList='{"dest":31300,"xver":0},{"alpn":"h2","dest":31302,"xver":0}'

    # trojan
    if echo "${selectCustomInstallType}" | grep -q 4 || [[ "$1" == "all" ]]; then

        fallbacksList='{"dest":31296,"xver":1},{"alpn":"h2","dest":31302,"xver":0}'

        getClients "${configPath}../tmp/04_trojan_TCP_inbounds.json" "${addClientsStatus}"
        cat <<EOF >/etc/v2ray-agent/v2ray/conf/04_trojan_TCP_inbounds.json
{
"inbounds":[
	{
	  "port": 31296,
	  "listen": "127.0.0.1",
	  "protocol": "trojan",
	  "tag":"trojanTCP",
	  "settings": {
		"clients": [
		  {
			"password": "${uuid}",
			"email": "default_Trojan_TCP"
		  }
		],
		"fallbacks":[
			{"dest":"31300"}
		]
	  },
	  "streamSettings": {
		"network": "tcp",
		"security": "none",
		"tcpSettings": {
			"acceptProxyProtocol": true
		}
	  }
	}
	]
}
EOF
        addClients "/etc/v2ray-agent/v2ray/conf/04_trojan_TCP_inbounds.json" "${addClientsStatus}"
    fi

    # VLESS_WS_TLS
    if echo "${selectCustomInstallType}" | grep -q 1 || [[ "$1" == "all" ]]; then
        fallbacksList=${fallbacksList}',{"path":"/'${customPath}'ws","dest":31297,"xver":1}'
        getClients "${configPath}../tmp/03_VLESS_WS_inbounds.json" "${addClientsStatus}"
        cat <<EOF >/etc/v2ray-agent/v2ray/conf/03_VLESS_WS_inbounds.json
{
"inbounds":[
    {
	  "port": 31297,
	  "listen": "127.0.0.1",
	  "protocol": "vless",
	  "tag":"VLESSWS",
	  "settings": {
		"clients": [
		  {
			"id": "${uuid}",
			"email": "default_VLESS_WS"
		  }
		],
		"decryption": "none"
	  },
	  "streamSettings": {
		"network": "ws",
		"security": "none",
		"wsSettings": {
		  "acceptProxyProtocol": true,
		  "path": "/${customPath}ws"
		}
	  }
	}
]
}
EOF
        addClients "/etc/v2ray-agent/v2ray/conf/03_VLESS_WS_inbounds.json" "${addClientsStatus}"
    fi

    # trojan_grpc
    if echo "${selectCustomInstallType}" | grep -q 2 || [[ "$1" == "all" ]]; then
        if ! echo "${selectCustomInstallType}" | grep -q 5 && [[ -n ${selectCustomInstallType} ]]; then
            fallbacksList=${fallbacksList//31302/31304}
        fi
        getClients "${configPath}../tmp/04_trojan_gRPC_inbounds.json" "${addClientsStatus}"
        cat <<EOF >/etc/v2ray-agent/v2ray/conf/04_trojan_gRPC_inbounds.json
{
    "inbounds": [
        {
            "port": 31304,
            "listen": "127.0.0.1",
            "protocol": "trojan",
            "tag": "trojangRPCTCP",
            "settings": {
                "clients": [
                    {
                        "password": "${uuid}",
                        "email": "default_Trojan_gRPC"
                    }
                ],
                "fallbacks": [
                    {
                        "dest": "31300"
                    }
                ]
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "${customPath}trojangrpc"
                }
            }
        }
    ]
}
EOF
        addClients "/etc/v2ray-agent/v2ray/conf/04_trojan_gRPC_inbounds.json" "${addClientsStatus}"
    fi

    # VMess_WS
    if echo "${selectCustomInstallType}" | grep -q 3 || [[ "$1" == "all" ]]; then
        fallbacksList=${fallbacksList}',{"path":"/'${customPath}'vws","dest":31299,"xver":1}'

        getClients "${configPath}../tmp/05_VMess_WS_inbounds.json" "${addClientsStatus}"

        cat <<EOF >/etc/v2ray-agent/v2ray/conf/05_VMess_WS_inbounds.json
{
"inbounds":[
{
  "listen": "127.0.0.1",
  "port": 31299,
  "protocol": "vmess",
  "tag":"VMessWS",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "alterId": 0,
        "add": "${add}",
        "email": "default_VMess_WS"
      }
    ]
  },
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "wsSettings": {
      "acceptProxyProtocol": true,
      "path": "/${customPath}vws"
    }
  }
}
]
}
EOF
        addClients "/etc/v2ray-agent/v2ray/conf/05_VMess_WS_inbounds.json" "${addClientsStatus}"
    fi

    if echo "${selectCustomInstallType}" | grep -q 5 || [[ "$1" == "all" ]]; then
        getClients "${configPath}../tmp/06_VLESS_gRPC_inbounds.json" "${addClientsStatus}"
        cat <<EOF >/etc/v2ray-agent/v2ray/conf/06_VLESS_gRPC_inbounds.json
{
    "inbounds":[
    {
        "port": 31301,
        "listen": "127.0.0.1",
        "protocol": "vless",
        "tag":"VLESSGRPC",
        "settings": {
            "clients": [
                {
                    "id": "${uuid}",
                    "add": "${add}",
                    "email": "default_VLESS_gRPC"
                }
            ],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "grpc",
            "grpcSettings": {
                "serviceName": "${customPath}grpc"
            }
        }
    }
]
}
EOF
        addClients "/etc/v2ray-agent/v2ray/conf/06_VLESS_gRPC_inbounds.json" "${addClientsStatus}"
    fi

    # VLESS_TCP
    getClients "${configPath}../tmp/02_VLESS_TCP_inbounds.json" "${addClientsStatus}"
    local defaultPort=443
    if [[ -n "${customPort}" ]]; then
        defaultPort=${customPort}
    fi

    cat <<EOF >/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json
{
"inbounds":[
{
  "port": ${defaultPort},
  "protocol": "vless",
  "tag":"VLESSTCP",
  "settings": {
    "clients": [
     {
        "id": "${uuid}",
        "add":"${add}",
        "email": "default_VLESS_TCP"
      }
    ],
    "decryption": "none",
    "fallbacks": [
        ${fallbacksList}
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "tls",
    "tlsSettings": {
      "minVersion": "1.2",
      "alpn": [
        "http/1.1",
        "h2"
      ],
      "certificates": [
        {
          "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
          "keyFile": "/etc/v2ray-agent/tls/${domain}.key",
          "ocspStapling": 3600,
          "usage":"encipherment"
        }
      ]
    }
  }
}
]
}
EOF
    addClients "/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json" "${addClientsStatus}"

}

# 初始化Xray Trojan XTLS 配置文件
initXrayFrontingConfig() {
    echoContent red " ---> Trojan暂不支持 xtls-rprx-vision"
    exit 0
    if [[ -z "${configPath}" ]]; then
        echoContent red " ---> 未安装，请使用脚本安装"
        menu
        exit 0
    fi
    if [[ "${coreInstallType}" != "1" ]]; then
        echoContent red " ---> 未安装可用类型"
    fi
    local xtlsType=
    if echo ${currentInstallProtocolType} | grep -q trojan; then
        xtlsType=VLESS
    else
        xtlsType=Trojan

    fi

    echoContent skyBlue "\n功能 1/${totalProgress} : 前置切换为${xtlsType}"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "会将前置替换为${xtlsType}"
    echoContent yellow "如果前置是Trojan，查看账号时则会出现两个Trojan协议的节点，有一个不可用xtls"
    echoContent yellow "再次执行可切换至上一次的前置\n"

    echoContent yellow "1.切换至${xtlsType}"
    echoContent red "=============================================================="
    read -r -p "请选择:" selectType
    if [[ "${selectType}" == "1" ]]; then

        if [[ "${xtlsType}" == "Trojan" ]]; then

            local VLESSConfig
            VLESSConfig=$(cat ${configPath}${frontingType}.json)
            VLESSConfig=${VLESSConfig//"id"/"password"}
            VLESSConfig=${VLESSConfig//VLESSTCP/TrojanTCPXTLS}
            VLESSConfig=${VLESSConfig//VLESS/Trojan}
            VLESSConfig=${VLESSConfig//"vless"/"trojan"}
            VLESSConfig=${VLESSConfig//"id"/"password"}

            echo "${VLESSConfig}" | jq . >${configPath}02_trojan_TCP_inbounds.json
            rm ${configPath}${frontingType}.json
        elif [[ "${xtlsType}" == "VLESS" ]]; then

            local VLESSConfig
            VLESSConfig=$(cat ${configPath}02_trojan_TCP_inbounds.json)
            VLESSConfig=${VLESSConfig//"password"/"id"}
            VLESSConfig=${VLESSConfig//TrojanTCPXTLS/VLESSTCP}
            VLESSConfig=${VLESSConfig//Trojan/VLESS}
            VLESSConfig=${VLESSConfig//"trojan"/"vless"}
            VLESSConfig=${VLESSConfig//"password"/"id"}

            echo "${VLESSConfig}" | jq . >${configPath}02_VLESS_TCP_inbounds.json
            rm ${configPath}02_trojan_TCP_inbounds.json
        fi
        reloadCore
    fi

    exit 0
}

# 移动上次配置文件至临时文件
movePreviousConfig() {

    if [[ -n "${configPath}" ]]; then
        if [[ -z "${realityStatus}" ]]; then
            rm -rf "${configPath}../tmp/*" 2>/dev/null
            mv ${configPath}[0][2-6]* ${configPath}../tmp/ 2>/dev/null
        else
            rm -rf "${configPath}../tmp/*"
            mv ${configPath}[0][7-8]* ${configPath}../tmp/ 2>/dev/null
            mv ${configPath}[0][2]* ${configPath}../tmp/ 2>/dev/null
        fi

    fi
}

# 初始化Xray 配置文件
initXrayConfig() {
    echoContent skyBlue "\n进度 $2/${totalProgress} : 初始化Xray配置"
    echo
    local uuid=
    local addClientsStatus=
    if [[ -n "${currentUUID}" ]]; then
        read -r -p "读取到上次用户配置，是否使用上次安装的配置 ？[y/n]:" historyUUIDStatus
        if [[ "${historyUUIDStatus}" == "y" ]]; then
            addClientsStatus=true
            echoContent green "\n ---> 使用成功"
        fi
    fi

    if [[ -z "${addClientsStatus}" ]]; then
        echoContent yellow "请输入自定义UUID[需合法]，[回车]随机UUID"
        read -r -p 'UUID:' customUUID

        if [[ -n ${customUUID} ]]; then
            uuid=${customUUID}
        else
            uuid=$(/etc/v2ray-agent/xray/xray uuid)
        fi

    fi

    if [[ -z "${addClientsStatus}" && -z "${uuid}" ]]; then
        addClientsStatus=
        echoContent red "\n ---> uuid读取错误，随机生成"
        uuid=$(/etc/v2ray-agent/xray/xray uuid)
    fi

    if [[ -n "${uuid}" ]]; then
        currentClients='[{"id":"'${uuid}'","add":"'${add}'","flow":"xtls-rprx-vision","email":"'${uuid}'-VLESS_TCP/TLS_Vision"}]'
        echoContent yellow "\n ${uuid}"
    fi

    # log
    if [[ ! -f "/etc/v2ray-agent/xray/conf/00_log.json" ]]; then

        cat <<EOF >/etc/v2ray-agent/xray/conf/00_log.json
{
  "log": {
    "error": "/etc/v2ray-agent/xray/error.log",
    "loglevel": "warning"
  }
}
EOF
    fi

    if [[ ! -f "/etc/v2ray-agent/xray/conf/12_policy.json" ]]; then

        cat <<EOF >/etc/v2ray-agent/xray/conf/12_policy.json
{
  "policy": {
      "levels": {
          "0": {
              "handshake": $((1 + RANDOM % 4)),
              "connIdle": $((250 + RANDOM % 51))
          }
      }
  }
}
EOF
    fi

    # outbounds
    if [[ ! -f "/etc/v2ray-agent/xray/conf/10_ipv6_outbounds.json" ]]; then
        if [[ -n "${pingIPv6}" ]]; then
            cat <<EOF >/etc/v2ray-agent/xray/conf/10_ipv6_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {},
          "tag": "direct"
        }
    ]
}
EOF

        else
            cat <<EOF >/etc/v2ray-agent/xray/conf/10_ipv4_outbounds.json
{
    "outbounds":[
        {
            "protocol":"freedom",
            "settings":{
                "domainStrategy":"UseIPv4"
            },
            "tag":"IPv4-out"
        },
        {
            "protocol":"freedom",
            "settings":{
                "domainStrategy":"UseIPv6"
            },
            "tag":"IPv6-out"
        },
        {
            "protocol":"freedom",
            "settings": {},
            "tag":"direct"
        },
        {
            "protocol":"blackhole",
            "tag":"blackhole-out"
        }
    ]
}
EOF
        fi
    fi

    # dns
    if [[ ! -f "/etc/v2ray-agent/xray/conf/11_dns.json" ]]; then
        cat <<EOF >/etc/v2ray-agent/xray/conf/11_dns.json
{
    "dns": {
        "servers": [
          "localhost"
        ]
  }
}
EOF
    fi
    # routing
    if [[ ! -f "/etc/v2ray-agent/xray/conf/09_routing.json" ]]; then
        cat <<EOF >/etc/v2ray-agent/xray/conf/09_routing.json
{
  "routing": {
    "rules": [
      {
        "type": "field",
        "domain": [
          "domain:gstatic.com",
          "domain:googleapis.com"
        ],
        "outboundTag": "direct"
      }
    ]
  }
}
EOF
    fi
    # VLESS_TCP_TLS_Vision
    # 回落nginx
    local fallbacksList='{"dest":31300,"xver":0},{"alpn":"h2","dest":31302,"xver":0}'

    # trojan
    if echo "${selectCustomInstallType}" | grep -q 4 || [[ "$1" == "all" ]]; then
        fallbacksList='{"dest":31296,"xver":1},{"alpn":"h2","dest":31302,"xver":0}'
        cat <<EOF >/etc/v2ray-agent/xray/conf/04_trojan_TCP_inbounds.json
{
"inbounds":[
	{
	  "port": 31296,
	  "listen": "127.0.0.1",
	  "protocol": "trojan",
	  "tag":"trojanTCP",
	  "settings": {
		"clients": $(initXrayClients 4),
		"fallbacks":[
			{"dest":"31300"}
		]
	  },
	  "streamSettings": {
		"network": "tcp",
		"security": "none",
		"tcpSettings": {
			"acceptProxyProtocol": true
		}
	  }
	}
	]
}
EOF
    else
        rm /etc/v2ray-agent/xray/conf/04_trojan_TCP_inbounds.json >/dev/null 2>&1
    fi

    # VLESS_WS_TLS
    if echo "${selectCustomInstallType}" | grep -q 1 || [[ "$1" == "all" ]]; then
        fallbacksList=${fallbacksList}',{"path":"/'${customPath}'ws","dest":31297,"xver":1}'
        cat <<EOF >/etc/v2ray-agent/xray/conf/03_VLESS_WS_inbounds.json
{
"inbounds":[
    {
	  "port": 31297,
	  "listen": "127.0.0.1",
	  "protocol": "vless",
	  "tag":"VLESSWS",
	  "settings": {
		"clients": $(initXrayClients 1),
		"decryption": "none"
	  },
	  "streamSettings": {
		"network": "ws",
		"security": "none",
		"wsSettings": {
		  "acceptProxyProtocol": true,
		  "path": "/${customPath}ws"
		}
	  }
	}
]
}
EOF
    else
        rm /etc/v2ray-agent/xray/conf/03_VLESS_WS_inbounds.json >/dev/null 2>&1
    fi

    # trojan_grpc
    if echo "${selectCustomInstallType}" | grep -q 2 || [[ "$1" == "all" ]]; then
        if ! echo "${selectCustomInstallType}" | grep -q 5 && [[ -n ${selectCustomInstallType} ]]; then
            fallbacksList=${fallbacksList//31302/31304}
        fi
        cat <<EOF >/etc/v2ray-agent/xray/conf/04_trojan_gRPC_inbounds.json
{
    "inbounds": [
        {
            "port": 31304,
            "listen": "127.0.0.1",
            "protocol": "trojan",
            "tag": "trojangRPCTCP",
            "settings": {
                "clients": $(initXrayClients 2),
                "fallbacks": [
                    {
                        "dest": "31300"
                    }
                ]
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "${customPath}trojangrpc"
                }
            }
        }
    ]
}
EOF
    else
        rm /etc/v2ray-agent/xray/conf/04_trojan_gRPC_inbounds.json >/dev/null 2>&1
    fi

    # VMess_WS
    if echo "${selectCustomInstallType}" | grep -q 3 || [[ "$1" == "all" ]]; then
        fallbacksList=${fallbacksList}',{"path":"/'${customPath}'vws","dest":31299,"xver":1}'
        cat <<EOF >/etc/v2ray-agent/xray/conf/05_VMess_WS_inbounds.json
{
"inbounds":[
{
  "listen": "127.0.0.1",
  "port": 31299,
  "protocol": "vmess",
  "tag":"VMessWS",
  "settings": {
    "clients": $(initXrayClients 3)
  },
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "wsSettings": {
      "acceptProxyProtocol": true,
      "path": "/${customPath}vws"
    }
  }
}
]
}
EOF
    else
        rm /etc/v2ray-agent/xray/conf/05_VMess_WS_inbounds.json >/dev/null 2>&1
    fi

    if echo "${selectCustomInstallType}" | grep -q 5 || [[ "$1" == "all" ]]; then
        cat <<EOF >/etc/v2ray-agent/xray/conf/06_VLESS_gRPC_inbounds.json
{
    "inbounds":[
    {
        "port": 31301,
        "listen": "127.0.0.1",
        "protocol": "vless",
        "tag":"VLESSGRPC",
        "settings": {
            "clients": $(initXrayClients 5),
            "decryption": "none"
        },
        "streamSettings": {
            "network": "grpc",
            "grpcSettings": {
                "serviceName": "${customPath}grpc"
            }
        }
    }
]
}
EOF
    else
        rm /etc/v2ray-agent/xray/conf/06_VLESS_gRPC_inbounds.json >/dev/null 2>&1
    fi
    # VLESS Vision
    if echo "${selectCustomInstallType}" | grep -q 0 || [[ "$1" == "all" ]]; then

        cat <<EOF >/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json
{
    "inbounds":[
        {
          "port": ${port},
          "protocol": "vless",
          "tag":"VLESSTCP",
          "settings": {
            "clients":$(initXrayClients 0),
            "decryption": "none",
            "fallbacks": [
                ${fallbacksList}
            ]
          },
          "add": "${add}",
          "streamSettings": {
            "network": "tcp",
            "security": "tls",
            "tlsSettings": {
              "minVersion": "1.2",
              "alpn": [
                "http/1.1",
                "h2"
              ],
              "certificates": [
                {
                  "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
                  "keyFile": "/etc/v2ray-agent/tls/${domain}.key",
                  "ocspStapling": 3600,
                  "usage":"encipherment"
                }
              ]
            }
          }
        }
    ]
}
EOF
    else
        rm /etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json >/dev/null 2>&1
    fi

    # VLESS_TCP/reality
    if echo "${selectCustomInstallType}" | grep -q 7 || [[ "$1" == "all" ]]; then
        echoContent skyBlue "\n===================== 配置VLESS+Reality =====================\n"
        initRealityPort
        initRealityDest
        initRealityClientServersName
        initRealityKey

        cat <<EOF >/etc/v2ray-agent/xray/conf/07_VLESS_vision_reality_inbounds.json
{
  "inbounds": [
    {
      "port": ${realityPort},
      "protocol": "vless",
      "tag": "VLESSReality",
      "settings": {
        "clients": $(initXrayClients 7),
        "decryption": "none",
        "fallbacks":[
            {
                "dest": "31305",
                "xver": 1
            }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
            "show": false,
            "dest": "${realityDestDomain}",
            "xver": 0,
            "serverNames": [
                ${realityServerNames}
            ],
            "privateKey": "${realityPrivateKey}",
            "publicKey": "${realityPublicKey}",
            "maxTimeDiff": 70000,
            "shortIds": [
                ""
            ]
        }
      }
    }
  ]
}
EOF

        cat <<EOF >/etc/v2ray-agent/xray/conf/08_VLESS_reality_fallback_grpc_inbounds.json
{
  "inbounds": [
    {
      "port": 31305,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "tag": "VLESSRealityGRPC",
      "settings": {
        "clients": $(initXrayClients 8),
        "decryption": "none"
      },
      "streamSettings": {
            "network": "grpc",
            "grpcSettings": {
                "serviceName": "grpc",
                "multiMode": true
            },
            "sockopt": {
                "acceptProxyProtocol": true
            }
      }
    }
  ]
}
EOF

    else
        rm /etc/v2ray-agent/xray/conf/07_VLESS_vision_reality_inbounds.json >/dev/null 2>&1
        rm /etc/v2ray-agent/xray/conf/08_VLESS_reality_fallback_grpc_inbounds.json >/dev/null 2>&1
    fi
    installSniffing
}
# 初始化Xray Reality配置
# 自定义CDN IP
customCDNIP() {
    echoContent skyBlue "\n进度 $1/${totalProgress} : 添加cloudflare自选CNAME"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项"
    echoContent yellow "\n教程地址:"
    echoContent skyBlue "https://www.v2ray-agent.com/archives/cloudflarezi-xuan-ip"
    echoContent red "\n如对Cloudflare优化不了解，请不要使用"
    echoContent yellow "\n 1.CNAME www.digitalocean.com"
    echoContent yellow " 2.CNAME who.int"
    echoContent yellow " 3.CNAME blog.hostmonit.com"

    echoContent skyBlue "----------------------------"
    read -r -p "请选择[回车不使用]:" selectCloudflareType
    case ${selectCloudflareType} in
    1)
        add="www.digitalocean.com"
        ;;
    2)
        add="who.int"
        ;;
    3)
        add="blog.hostmonit.com"
        ;;
    *)
        add="${domain}"
        echoContent yellow "\n ---> 不使用"
        ;;
    esac
}
# 通用
defaultBase64Code() {
    local type=$1
    local email=$2
    local id=$3
    local add=$4
    local user=
    user=$(echo "${email}" | awk -F "[-]" '{print $1}')
    port=${currentDefaultPort}

    if [[ "${type}" == "vlesstcp" ]]; then

        if [[ "${coreInstallType}" == "1" ]] && echo "${currentInstallProtocolType}" | grep -q 0; then
            echoContent yellow " ---> 通用格式(VLESS+TCP+TLS_Vision)"
            echoContent green "    vless://${id}@${currentHost}:${currentDefaultPort}?encryption=none&security=tls&fp=chrome&type=tcp&host=${currentHost}&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision#${email}\n"

            echoContent yellow " ---> 格式化明文(VLESS+TCP+TLS_Vision)"
            echoContent green "协议类型:VLESS，地址:${currentHost}，端口:${currentDefaultPort}，用户ID:${id}，安全:tls，client-fingerprint: chrome，传输方式:tcp，flow:xtls-rprx-vision，账户名:${email}\n"
            cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@${currentHost}:${currentDefaultPort}?encryption=none&security=tls&type=tcp&host=${currentHost}&fp=chrome&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision#${email}
EOF
            cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: ${currentHost}
    port: ${currentDefaultPort}
    uuid: ${id}
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    client-fingerprint: chrome
EOF
            echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS_Vision)"
            echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${currentHost}%3A${currentDefaultPort}%3Fencryption%3Dnone%26fp%3Dchrome%26security%3Dtls%26type%3Dtcp%26${currentHost}%3D${currentHost}%26headerType%3Dnone%26sni%3D${currentHost}%26flow%3Dxtls-rprx-vision%23${email}\n"
        elif [[ "${coreInstallType}" == 2 ]]; then
            echoContent yellow " ---> 通用格式(VLESS+TCP+TLS)"
            echoContent green "    vless://${id}@${currentHost}:${currentDefaultPort}?security=tls&encryption=none&host=${currentHost}&fp=chrome&headerType=none&type=tcp#${email}\n"

            echoContent yellow " ---> 格式化明文(VLESS+TCP+TLS)"
            echoContent green "    协议类型:VLESS，地址:${currentHost}，端口:${currentDefaultPort}，用户ID:${id}，安全:tls，client-fingerprint: chrome,传输方式:tcp，账户名:${email}\n"

            cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@${currentHost}:${currentDefaultPort}?security=tls&encryption=none&host=${currentHost}&fp=chrome&headerType=none&type=tcp#${email}
EOF
            echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS)"
            echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3a%2f%2f${id}%40${currentHost}%3a${currentDefaultPort}%3fsecurity%3dtls%26encryption%3dnone%26fp%3Dchrome%26host%3d${currentHost}%26headerType%3dnone%26type%3dtcp%23${email}\n"
        fi

    elif [[ "${type}" == "trojanTCPXTLS" ]]; then
        echoContent yellow " ---> 通用格式(Trojan+TCP+TLS_Vision)"
        echoContent green "    trojan://${id}@${currentHost}:${currentDefaultPort}?encryption=none&security=xtls&type=tcp&host=${currentHost}&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision#${email}\n"

        echoContent yellow " ---> 格式化明文(Trojan+TCP+TLS_Vision)"
        echoContent green "协议类型:Trojan，地址:${currentHost}，端口:${currentDefaultPort}，用户ID:${id}，安全:xtls，传输方式:tcp，flow:xtls-rprx-vision，账户名:${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
trojan://${id}@${currentHost}:${currentDefaultPort}?encryption=none&security=xtls&type=tcp&host=${currentHost}&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision#${email}
EOF
        echoContent yellow " ---> 二维码 Trojan(Trojan+TCP+TLS_Vision)"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3A%2F%2F${id}%40${currentHost}%3A${currentDefaultPort}%3Fencryption%3Dnone%26security%3Dxtls%26type%3Dtcp%26${currentHost}%3D${currentHost}%26headerType%3Dnone%26sni%3D${currentHost}%26flow%3Dxtls-rprx-vision%23${email}\n"

    elif [[ "${type}" == "vmessws" ]]; then
        qrCodeBase64Default=$(echo -n "{\"port\":${currentDefaultPort},\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${currentHost}\",\"type\":\"none\",\"path\":\"/${currentPath}vws\",\"net\":\"ws\",\"add\":\"${add}\",\"allowInsecure\":0,\"method\":\"none\",\"peer\":\"${currentHost}\",\"sni\":\"${currentHost}\"}" | base64 -w 0)
        qrCodeBase64Default="${qrCodeBase64Default// /}"

        echoContent yellow " ---> 通用json(VMess+WS+TLS)"
        echoContent green "    {\"port\":${currentDefaultPort},\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${currentHost}\",\"type\":\"none\",\"path\":\"/${currentPath}vws\",\"net\":\"ws\",\"add\":\"${add}\",\"allowInsecure\":0,\"method\":\"none\",\"peer\":\"${currentHost}\",\"sni\":\"${currentHost}\"}\n"
        echoContent yellow " ---> 通用vmess(VMess+WS+TLS)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echoContent yellow " ---> 二维码 vmess(VMess+WS+TLS)"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vmess://${qrCodeBase64Default}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vmess
    server: ${add}
    port: ${currentDefaultPort}
    uuid: ${id}
    alterId: 0
    cipher: none
    udp: true
    tls: true
    client-fingerprint: chrome
    servername: ${currentHost}
    network: ws
    ws-opts:
      path: /${currentPath}vws
      headers:
        Host: ${currentHost}
EOF
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

    elif [[ "${type}" == "vlessws" ]]; then

        echoContent yellow " ---> 通用格式(VLESS+WS+TLS)"
        echoContent green "    vless://${id}@${add}:${currentDefaultPort}?encryption=none&security=tls&type=ws&host=${currentHost}&sni=${currentHost}&fp=chrome&path=/${currentPath}ws#${email}\n"

        echoContent yellow " ---> 格式化明文(VLESS+WS+TLS)"
        echoContent green "    协议类型:VLESS，地址:${add}，伪装域名/SNI:${currentHost}，端口:${currentDefaultPort}，client-fingerprint: chrome,用户ID:${id}，安全:tls，传输方式:ws，路径:/${currentPath}ws，账户名:${email}\n"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@${add}:${currentDefaultPort}?encryption=none&security=tls&type=ws&host=${currentHost}&sni=${currentHost}&fp=chrome&path=/${currentPath}ws#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: ${add}
    port: ${currentDefaultPort}
    uuid: ${id}
    udp: true
    tls: true
    network: ws
    client-fingerprint: chrome
    servername: ${currentHost}
    ws-opts:
      path: /${currentPath}ws
      headers:
        Host: ${currentHost}
EOF

        echoContent yellow " ---> 二维码 VLESS(VLESS+WS+TLS)"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${currentDefaultPort}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dws%26host%3D${currentHost}%26fp%3Dchrome%26sni%3D${currentHost}%26path%3D%252f${currentPath}ws%23${email}"

    elif [[ "${type}" == "vlessgrpc" ]]; then

        echoContent yellow " ---> 通用格式(VLESS+gRPC+TLS)"
        echoContent green "    vless://${id}@${add}:${currentDefaultPort}?encryption=none&security=tls&type=grpc&host=${currentHost}&path=${currentPath}grpc&fp=chrome&serviceName=${currentPath}grpc&alpn=h2&sni=${currentHost}#${email}\n"

        echoContent yellow " ---> 格式化明文(VLESS+gRPC+TLS)"
        echoContent green "    协议类型:VLESS，地址:${add}，伪装域名/SNI:${currentHost}，端口:${currentDefaultPort}，用户ID:${id}，安全:tls，传输方式:gRPC，alpn:h2，client-fingerprint: chrome,serviceName:${currentPath}grpc，账户名:${email}\n"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@${add}:${currentDefaultPort}?encryption=none&security=tls&type=grpc&host=${currentHost}&path=${currentPath}grpc&serviceName=${currentPath}grpc&fp=chrome&alpn=h2&sni=${currentHost}#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: ${add}
    port: ${currentDefaultPort}
    uuid: ${id}
    udp: true
    tls: true
    network: grpc
    client-fingerprint: chrome
    servername: ${currentHost}
    grpc-opts:
      grpc-service-name: ${currentPath}grpc
EOF
        echoContent yellow " ---> 二维码 VLESS(VLESS+gRPC+TLS)"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${currentDefaultPort}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dgrpc%26host%3D${currentHost}%26serviceName%3D${currentPath}grpc%26fp%3Dchrome%26path%3D${currentPath}grpc%26sni%3D${currentHost}%26alpn%3Dh2%23${email}"

    elif [[ "${type}" == "trojan" ]]; then
        # URLEncode
        echoContent yellow " ---> Trojan(TLS)"
        echoContent green "    trojan://${id}@${currentHost}:${currentDefaultPort}?peer=${currentHost}&fp=chrome&sni=${currentHost}&alpn=http/1.1#${currentHost}_Trojan\n"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
trojan://${id}@${currentHost}:${currentDefaultPort}?peer=${currentHost}&fp=chrome&sni=${currentHost}&alpn=http/1.1#${email}_Trojan
EOF

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: trojan
    server: ${currentHost}
    port: ${currentDefaultPort}
    password: ${id}
    client-fingerprint: chrome
    udp: true
    sni: ${currentHost}
EOF
        echoContent yellow " ---> 二维码 Trojan(TLS)"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${currentHost}%3a${port}%3fpeer%3d${currentHost}%26fp%3Dchrome%26sni%3d${currentHost}%26alpn%3Dhttp/1.1%23${email}\n"

    elif [[ "${type}" == "trojangrpc" ]]; then
        # URLEncode

        echoContent yellow " ---> Trojan gRPC(TLS)"
        echoContent green "    trojan://${id}@${add}:${currentDefaultPort}?encryption=none&peer=${currentHost}&fp=chrome&security=tls&type=grpc&sni=${currentHost}&alpn=h2&path=${currentPath}trojangrpc&serviceName=${currentPath}trojangrpc#${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
trojan://${id}@${add}:${currentDefaultPort}?encryption=none&peer=${currentHost}&security=tls&type=grpc&fp=chrome&sni=${currentHost}&alpn=h2&path=${currentPath}trojangrpc&serviceName=${currentPath}trojangrpc#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    server: ${add}
    port: ${currentDefaultPort}
    type: trojan
    password: ${id}
    network: grpc
    sni: ${currentHost}
    udp: true
    grpc-opts:
      grpc-service-name: ${currentPath}trojangrpc
EOF
        echoContent yellow " ---> 二维码 Trojan gRPC(TLS)"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${add}%3a${currentDefaultPort}%3Fencryption%3Dnone%26fp%3Dchrome%26security%3Dtls%26peer%3d${currentHost}%26type%3Dgrpc%26sni%3d${currentHost}%26path%3D${currentPath}trojangrpc%26alpn%3Dh2%26serviceName%3D${currentPath}trojangrpc%23${email}\n"

    elif [[ "${type}" == "hysteria" ]]; then
        local hysteriaEmail=
        hysteriaEmail=$(echo "${email}" | awk -F "[-]" '{print $1}')_hysteria
        echoContent yellow " ---> Hysteria(TLS)"
        local clashMetaPortTmp="port: ${hysteriaPort}"
        local v2rayNPortHopping=
        local mport=
        if [[ -n "${portHoppingStart}" ]]; then
            mport="mport=${portHoppingStart}-${portHoppingEnd}&"
            clashMetaPortTmp="ports: ${portHoppingStart}-${portHoppingEnd}"
            v2rayNPortHopping=",${portHoppingStart}-${portHoppingEnd}"
        fi
        echoContent green "    hysteria://${currentHost}:${hysteriaPort}?${mport}protocol=${hysteriaProtocol}&auth=${id}&peer=${currentHost}&insecure=0&alpn=h3&upmbps=${hysteriaClientUploadSpeed}&downmbps=${hysteriaClientDownloadSpeed}#${hysteriaEmail}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
hysteria://${currentHost}:${hysteriaPort}?${mport}protocol=${hysteriaProtocol}&auth=${id}&peer=${currentHost}&insecure=0&alpn=h3&upmbps=${hysteriaClientUploadSpeed}&downmbps=${hysteriaClientDownloadSpeed}#${hysteriaEmail}
EOF
        echoContent yellow " ---> v2rayN(hysteria+TLS)"
        cat <<EOF >"/etc/v2ray-agent/hysteria/conf/client.json"
{
  "server": "${currentHost}:${hysteriaPort}${v2rayNPortHopping}",
  "protocol": "${hysteriaProtocol}",
  "up_mbps": ${hysteriaClientUploadSpeed},
  "down_mbps": ${hysteriaClientDownloadSpeed},
  "http": { "listen": "127.0.0.1:10809", "timeout": 300, "disable_udp": false },
  "socks5": { "listen": "127.0.0.1:10808", "timeout": 300, "disable_udp": false },
  "obfs": "",
  "auth_str":"${id}",
  "alpn": "h3",
  "acl": "acl/routes.acl",
  "mmdb": "acl/Country.mmdb",
  "server_name": "${currentHost}",
  "insecure": false,
  "recv_window_conn": 5767168,
  "recv_window": 23068672,
  "disable_mtu_discovery": true,
  "resolver": "https://223.5.5.5/dns-query",
  "retry": 3,
  "retry_interval": 3,
  "quit_on_disconnect": false,
  "handshake_timeout": 15,
  "idle_timeout": 30,
  "fast_open": true,
  "hop_interval": 120
}
EOF
        local v2rayNConf=
        v2rayNConf="$(cat /etc/v2ray-agent/hysteria/conf/client.json)"
        echoContent green "${v2rayNConf}\n"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${hysteriaEmail}"
    type: hysteria
    server: ${currentHost}
    ${clashMetaPortTmp}
    auth_str: ${id}
    alpn:
     - h3
    protocol: ${hysteriaProtocol}
    up: "${hysteriaClientUploadSpeed}"
    down: "${hysteriaClientDownloadSpeed}"
    sni: ${currentHost}
EOF
        echoContent yellow " ---> 二维码 Hysteria(TLS)"
        if [[ -n "${mport}" ]]; then
            mport="mport%3D${portHoppingStart}-${portHoppingEnd}%26"
        fi
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=hysteria%3A%2F%2F${currentHost}%3A${hysteriaPort}%3F${mport}protocol%3D${hysteriaProtocol}%26auth%3D${id}%26peer%3D${currentHost}%26insecure%3D0%26alpn%3Dh3%26upmbps%3D${hysteriaClientUploadSpeed}%26downmbps%3D${hysteriaClientDownloadSpeed}%23${hysteriaEmail}\n"
    elif [[ "${type}" == "vlessReality" ]]; then
        echoContent yellow " ---> 通用格式(VLESS+reality+uTLS+Vision)"
        echoContent green "    vless://${id}@$(getPublicIP):${currentRealityPort}?encryption=none&security=reality&type=tcp&sni=${currentRealityServerNames}&fp=chrome&pbk=${currentRealityPublicKey}&flow=xtls-rprx-vision#${email}\n"

        echoContent yellow " ---> 格式化明文(VLESS+reality+uTLS+Vision)"
        echoContent green "协议类型:VLESS reality，地址:$(getPublicIP)，publicKey:${currentRealityPublicKey}，serverNames：${currentRealityServerNames}，端口:${currentRealityPort}，用户ID:${id}，传输方式:tcp，账户名:${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@$(getPublicIP):${currentRealityPort}?encryption=none&security=reality&type=tcp&sni=${currentRealityServerNames}&fp=chrome&pbk=${currentRealityPublicKey}&flow=xtls-rprx-vision#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: $(getPublicIP)
    port: ${currentRealityPort}
    uuid: ${id}
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: ${currentRealityServerNames}
    reality-opts:
      public-key: ${currentRealityPublicKey}
    client-fingerprint: chrome
EOF
        echoContent yellow " ---> 二维码 VLESS(VLESS+reality+uTLS+Vision)"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40$(getPublicIP)%3A${currentRealityPort}%3Fencryption%3Dnone%26security%3Dreality%26type%3Dtcp%26sni%3D${currentRealityServerNames}%26fp%3Dchrome%26pbk%3D${currentRealityPublicKey}%26flow%3Dxtls-rprx-vision%23${email}\n"

    elif [[ "${type}" == "vlessRealityGRPC" ]]; then
        echoContent yellow " ---> 通用格式(VLESS+reality+uTLS+gRPC)"
        echoContent green "    vless://${id}@$(getPublicIP):${currentRealityPort}?encryption=none&security=reality&type=grpc&sni=${currentRealityServerNames}&fp=chrome&pbk=${currentRealityPublicKey}&path=grpc&serviceName=grpc#${email}\n"

        echoContent yellow " ---> 格式化明文(VLESS+reality+uTLS+gRPC)"
        echoContent green "协议类型:VLESS reality，serviceName:grpc，地址:$(getPublicIP)，publicKey:${currentRealityPublicKey}，serverNames：${currentRealityServerNames}，端口:${currentRealityPort}，用户ID:${id}，传输方式:gRPC，client-fingerprint：chrome，账户名:${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@$(getPublicIP):${currentRealityPort}?encryption=none&security=reality&type=grpc&sni=${currentRealityServerNames}&fp=chrome&pbk=${currentRealityPublicKey}&path=grpc&serviceName=grpc#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: $(getPublicIP)
    port: ${currentRealityPort}
    uuid: ${id}
    network: grpc
    tls: true
    udp: true
    servername: ${currentRealityServerNames}
    reality-opts:
      public-key: ${currentRealityPublicKey}
    grpc-opts:
      grpc-service-name: "grpc"
    client-fingerprint: chrome
EOF
        echoContent yellow " ---> 二维码 VLESS(VLESS+reality+uTLS+gRPC)"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40$(getPublicIP)%3A${currentRealityPort}%3Fencryption%3Dnone%26security%3Dreality%26type%3Dgrpc%26sni%3D${currentRealityServerNames}%26fp%3Dchrome%26pbk%3D${currentRealityPublicKey}%26path%3Dgrpc%26serviceName%3Dgrpc%23${email}\n"
    elif [[ "${type}" == "tuic" ]]; then

        if [[ -z "${email}" ]]; then
            echoContent red " ---> 读取配置失败，请重新安装"
            exit 0
        fi

        echoContent yellow " ---> 格式化明文(Tuic+TLS)"
        echoContent green "    协议类型:Tuic，地址:${currentHost}，端口：${tuicPort}，uuid：${id}，password：${id}，congestion-controller:${tuicAlgorithm}，alpn: h3，账户名:${email}_tuic\n"

        echoContent yellow " ---> v2rayN(Tuic+TLS)"
        cat <<EOF >"/etc/v2ray-agent/tuic/conf/v2rayN.json"
{
    "relay": {
        "server": "${currentHost}:${tuicPort}",
        "uuid": "${id}",
        "password": "${id}",
        "ip": "$(getPublicIP)",
        "congestion_control": "${tuicAlgorithm}",
        "alpn": ["h3"]
    },
    "local": {
        "server": "127.0.0.1:7798"
    },
    "log_level": "warn"
}
EOF
        local v2rayNConf=
        v2rayNConf="$(cat /etc/v2ray-agent/tuic/conf/v2rayN.json)"
        echoContent green "${v2rayNConf}"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${email}"
  - name: "${email}_tuic"
    server: ${currentHost}
    type: tuic
    port: ${tuicPort}
    uuid: ${id}
    password: ${id}
    alpn:
     - h3
    congestion-controller: ${tuicAlgorithm}
    disable-sni: true
    reduce-rtt: true
    fast-open: true
    heartbeat-interval: 8000
    request-timeout: 8000
    max-udp-relay-packet-size: 1500
    max-open-streams: 100
    ip-version: dual
    smux:
        enabled: false
EOF
    fi

}

# 账号
showAccounts() {
    readInstallType
    readInstallProtocolType
    readConfigHostPathUUID
    readHysteriaConfig
    readXrayCoreRealityConfig
    readHysteriaPortHopping
    readTuicConfig
    echo
    echoContent skyBlue "\n进度 $1/${totalProgress} : 账号"
    local show
    # VLESS TCP
    if echo "${currentInstallProtocolType}" | grep -q trojan; then
        echoContent skyBlue "===================== Trojan TCP TLS_Vision ======================\n"
        jq .inbounds[0].settings.clients ${configPath}02_trojan_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email)
            echoContent skyBlue "\n ---> 账号:${email}"
            defaultBase64Code trojanTCPXTLS "${email}" "$(echo "${user}" | jq -r .password)"
        done

    elif echo ${currentInstallProtocolType} | grep -q 0; then
        show=1
        echoContent skyBlue "============================= VLESS TCP TLS_Vision ==============================\n"
        jq .inbounds[0].settings.clients ${configPath}02_VLESS_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email)

            echoContent skyBlue "\n ---> 账号:${email}"
            echo
            defaultBase64Code vlesstcp "${email}" "$(echo "${user}" | jq -r .id)"
        done
    fi

    # VLESS WS
    if echo ${currentInstallProtocolType} | grep -q 1; then
        echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================\n"

        jq .inbounds[0].settings.clients ${configPath}03_VLESS_WS_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email)

            echoContent skyBlue "\n ---> 账号:${email}"
            echo
            local path="${currentPath}ws"
            local count=
            while read -r line; do
                if [[ -n "${line}" ]]; then
                    defaultBase64Code vlessws "${email}${count}" "$(echo "${user}" | jq -r .id)" "${line}"
                    count=$((count + 1))
                fi
            done < <(echo "${currentAdd}" | tr ',' '\n')

        done
    fi

    # VLESS grpc
    if echo ${currentInstallProtocolType} | grep -q 5; then
        echoContent skyBlue "\n=============================== VLESS gRPC TLS CDN ===============================\n"
        jq .inbounds[0].settings.clients ${configPath}06_VLESS_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do

            local email=
            email=$(echo "${user}" | jq -r .email)

            echoContent skyBlue "\n ---> 账号:${email}"
            echo
            local count=
            while read -r line; do
                if [[ -n "${line}" ]]; then
                    defaultBase64Code vlessgrpc "${email}${count}" "$(echo "${user}" | jq -r .id)" "${line}"
                    count=$((count + 1))
                fi
            done < <(echo "${currentAdd}" | tr ',' '\n')

        done
    fi

    # VMess WS
    if echo ${currentInstallProtocolType} | grep -q 3; then
        echoContent skyBlue "\n================================ VMess WS TLS CDN ================================\n"
        local path="${currentPath}vws"
        if [[ ${coreInstallType} == "1" ]]; then
            path="${currentPath}vws"
        fi
        jq .inbounds[0].settings.clients ${configPath}05_VMess_WS_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email)

            echoContent skyBlue "\n ---> 账号:${email}"
            echo
            local count=
            while read -r line; do
                if [[ -n "${line}" ]]; then
                    defaultBase64Code vmessws "${email}${count}" "$(echo "${user}" | jq -r .id)" "${line}"
                    count=$((count + 1))
                fi
            done < <(echo "${currentAdd}" | tr ',' '\n')
        done
    fi

    # trojan tcp
    if echo ${currentInstallProtocolType} | grep -q 4; then
        echoContent skyBlue "\n==================================  Trojan TLS  ==================================\n"
        jq .inbounds[0].settings.clients ${configPath}04_trojan_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email)
            echoContent skyBlue "\n ---> 账号:${email}"

            defaultBase64Code trojan "${email}" "$(echo "${user}" | jq -r .password)"
        done
    fi

    if echo ${currentInstallProtocolType} | grep -q 2; then
        echoContent skyBlue "\n================================  Trojan gRPC TLS  ================================\n"
        jq .inbounds[0].settings.clients ${configPath}04_trojan_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email)

            echoContent skyBlue "\n ---> 账号:${email}"
            echo
            local count=
            while read -r line; do
                if [[ -n "${line}" ]]; then
                    defaultBase64Code trojangrpc "${email}${count}" "$(echo "${user}" | jq -r .password)" "${line}"
                    count=$((count + 1))
                fi
            done < <(echo "${currentAdd}" | tr ',' '\n')

        done
    fi
    if echo ${currentInstallProtocolType} | grep -q 6; then
        echoContent skyBlue "\n================================  Hysteria TLS  ================================\n"
        echoContent red "\n --->Hysteria速度依赖与本地的网络环境，如果被QoS使用体验会非常差。IDC也有可能认为是攻击，请谨慎使用"

        jq .auth.config ${hysteriaConfigPath}config.json | jq -r '.[]' | while read -r user; do
            local defaultUser=
            local uuidType=
            uuidType=".id"

            if [[ "${frontingType}" == "02_trojan_TCP_inbounds" ]]; then
                uuidType=".password"
            fi

            defaultUser=$(jq '.inbounds[0].settings.clients[]|select('${uuidType}'=="'"${user}"'")' ${configPath}${frontingType}.json)
            local email=
            email=$(echo "${defaultUser}" | jq -r .email)
            local hysteriaEmail=
            hysteriaEmail=$(echo "${email}" | awk -F "[_]" '{print $1}')_hysteria

            if [[ -n ${defaultUser} ]]; then
                echoContent skyBlue "\n ---> 账号:$(echo "${hysteriaEmail}" | awk -F "[-]" '{print $1"_hysteria"}')"
                echo
                defaultBase64Code hysteria "${hysteriaEmail}" "${user}"
            fi

        done

    fi

    # VLESS reality vision
    if echo ${currentInstallProtocolType} | grep -q 7; then
        show=1
        echoContent skyBlue "============================= VLESS reality_vision  ==============================\n"
        jq .inbounds[0].settings.clients ${configPath}07_VLESS_vision_reality_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email)

            echoContent skyBlue "\n ---> 账号:${email}"
            echo
            defaultBase64Code vlessReality "${email}" "$(echo "${user}" | jq -r .id)"
        done
    fi

    # VLESS reality
    if echo ${currentInstallProtocolType} | grep -q 8; then
        show=1
        echoContent skyBlue "============================== VLESS reality_gRPC  ===============================\n"
        jq .inbounds[0].settings.clients ${configPath}08_VLESS_reality_fallback_grpc_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email)

            echoContent skyBlue "\n ---> 账号:${email}"
            echo
            defaultBase64Code vlessRealityGRPC "${email}" "$(echo "${user}" | jq -r .id)"
        done
    fi
    # tuic
    if echo ${currentInstallProtocolType} | grep -q 9; then
        echoContent skyBlue "\n================================  Tuic TLS  ================================\n"
        echoContent yellow "\n --->Tuic相对于Hysteria会更加温 使用体验可能会更流畅。"

        jq -r .users[] "${tuicConfigPath}config.json" | while read -r id; do
            local tuicEmail=
            tuicEmail=$(jq -r '.inbounds[0].settings.clients[]|select(.id=="'"${id}"'")|.email' ${configPath}${frontingType}.json | awk -F "[-]" '{print $1}')

            if [[ -n ${tuicEmail} ]]; then
                echoContent skyBlue "\n ---> 账号:${tuicEmail}_tuic"
                echo
                defaultBase64Code tuic "${tuicEmail}" "${id}"
            fi

        done

    fi

    if [[ -z ${show} ]]; then
        echoContent red " ---> 未安装"
    fi
}
# 移除nginx302配置
removeNginx302() {
    local count=
    grep -n "return 302" <"${nginxConfigPath}alone.conf" | while read -r line; do

        if ! echo "${line}" | grep -q "request_uri"; then
            local removeIndex=
            removeIndex=$(echo "${line}" | awk -F "[:]" '{print $1}')
            removeIndex=$((removeIndex + count))
            sed -i "${removeIndex}d" ${nginxConfigPath}alone.conf
            count=$((count - 1))
        fi
    done
}

# 检查302是否成功
checkNginx302() {
    local domain302Status=
    domain302Status=$(curl -s "https://${currentHost}:${currentPort}")
    if echo "${domain302Status}" | grep -q "302"; then
        local domain302Result=
        domain302Result=$(curl -L -s "https://${currentHost}:${currentPort}")
        if [[ -n "${domain302Result}" ]]; then
            echoContent green " ---> 302重定向设置成功"
            exit 0
        fi
    fi
    echoContent red " ---> 302重定向设置失败，请仔细检查是否和示例相同"
    backupNginxConfig restoreBackup
}

# 备份恢复nginx文件
backupNginxConfig() {
    if [[ "$1" == "backup" ]]; then
        cp ${nginxConfigPath}alone.conf /etc/v2ray-agent/alone_backup.conf
        echoContent green " ---> nginx配置文件备份成功"
    fi

    if [[ "$1" == "restoreBackup" ]] && [[ -f "/etc/v2ray-agent/alone_backup.conf" ]]; then
        cp /etc/v2ray-agent/alone_backup.conf ${nginxConfigPath}alone.conf
        echoContent green " ---> nginx配置文件恢复备份成功"
        rm /etc/v2ray-agent/alone_backup.conf
    fi

}
# 添加302配置
addNginx302() {
    #	local line302Result=
    #	line302Result=$(| tail -n 1)
    local count=1
    grep -n "Strict-Transport-Security" <"${nginxConfigPath}alone.conf" | while read -r line; do
        if [[ -n "${line}" ]]; then
            local insertIndex=
            insertIndex="$(echo "${line}" | awk -F "[:]" '{print $1}')"
            insertIndex=$((insertIndex + count))
            sed "${insertIndex}i return 302 '$1';" ${nginxConfigPath}alone.conf >${nginxConfigPath}tmpfile && mv ${nginxConfigPath}tmpfile ${nginxConfigPath}alone.conf
            count=$((count + 1))
        else
            echoContent red " ---> 302添加失败"
            backupNginxConfig restoreBackup
        fi

    done
}

# 更新伪装站
updateNginxBlog() {
    echoContent skyBlue "\n进度 $1/${totalProgress} : 更换伪装站点"

    if ! echo "${currentInstallProtocolType}" | grep -q "0" || [[ -z "${coreInstallType}" ]]; then
        echoContent red "\n ---> 由于环境依赖，请先安装Xray-core的VLESS_TCP_TLS_Vision"
        exit 0
    fi
    echoContent red "=============================================================="
    echoContent yellow "# 如需自定义，请手动复制模版文件到 ${nginxStaticPath} \n"
    echoContent yellow "1.新手引导"
    echoContent yellow "2.游戏网站"
    echoContent yellow "3.个人博客01"
    echoContent yellow "4.企业站"
    echoContent yellow "5.解锁加密的音乐文件模版[https://github.com/ix64/unlock-music]"
    echoContent yellow "6.mikutap[https://github.com/HFIProgramming/mikutap]"
    echoContent yellow "7.企业站02"
    echoContent yellow "8.个人博客02"
    echoContent yellow "9.404自动跳转baidu"
    echoContent yellow "10.302重定向网站"
    echoContent red "=============================================================="
    read -r -p "请选择:" selectInstallNginxBlogType

    if [[ "${selectInstallNginxBlogType}" == "10" ]]; then
        echoContent red "\n=============================================================="
        echoContent yellow "重定向的优先级更高，配置302之后如果更改伪装站点，根路由下伪装站点将不起作用"
        echoContent yellow "如想要伪装站点实现作用需删除302重定向配置\n"
        echoContent yellow "1.添加"
        echoContent yellow "2.删除"
        echoContent red "=============================================================="
        read -r -p "请选择:" redirectStatus

        if [[ "${redirectStatus}" == "1" ]]; then
            backupNginxConfig backup
            read -r -p "请输入要重定向的域名,例如 https://www.baidu.com:" redirectDomain
            removeNginx302
            addNginx302 "${redirectDomain}"
            handleNginx stop
            handleNginx start
            if [[ -z $(pgrep -f "nginx") ]]; then
                backupNginxConfig restoreBackup
                handleNginx start
                exit 0
            fi
            checkNginx302
            exit 0
        fi
        if [[ "${redirectStatus}" == "2" ]]; then
            removeNginx302
            echoContent green " ---> 移除302重定向成功"
            exit 0
        fi
    fi
    if [[ "${selectInstallNginxBlogType}" =~ ^[1-9]$ ]]; then
        rm -rf "${nginxStaticPath}"

        wget -q -P "${nginxStaticPath}" "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${selectInstallNginxBlogType}.zip" >/dev/null

        unzip -o "${nginxStaticPath}html${selectInstallNginxBlogType}.zip" -d "${nginxStaticPath}" >/dev/null
        rm -f "${nginxStaticPath}html${selectInstallNginxBlogType}.zip*"
        echoContent green " ---> 更换伪站成功"
    else
        echoContent red " ---> 选择错误，请重新选择"
        updateNginxBlog
    fi
}

# 添加新端口
addCorePort() {
    readHysteriaConfig
    echoContent skyBlue "\n功能 1/${totalProgress} : 添加新端口"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "支持批量添加"
    echoContent yellow "不影响默认端口的使用"
    echoContent yellow "查看账号时，只会展示默认端口的账号"
    echoContent yellow "不允许有特殊字符，注意逗号的格式"
    echoContent yellow "如已安装hysteria，会同时安装hysteria新端口"
    echoContent yellow "录入示例:2053,2083,2087\n"

    echoContent yellow "1.查看已添加端口"
    echoContent yellow "2.添加端口"
    echoContent yellow "3.删除端口"
    echoContent red "=============================================================="
    read -r -p "请选择:" selectNewPortType
    if [[ "${selectNewPortType}" == "1" ]]; then
        find ${configPath} -name "*dokodemodoor*" | grep -v "hysteria" | awk -F "[c][o][n][f][/]" '{print $2}' | awk -F "[_]" '{print $4}' | awk -F "[.]" '{print ""NR""":"$1}'
        exit 0
    elif [[ "${selectNewPortType}" == "2" ]]; then
        read -r -p "请输入端口号:" newPort
        read -r -p "请输入默认的端口号，同时会更改订阅端口以及节点端口，[回车]默认443:" defaultPort

        if [[ -n "${defaultPort}" ]]; then
            rm -rf "$(find ${configPath}* | grep "default")"
        fi

        if [[ -n "${newPort}" ]]; then

            while read -r port; do
                rm -rf "$(find ${configPath}* | grep "${port}")"

                local fileName=
                local hysteriaFileName=
                if [[ -n "${defaultPort}" && "${port}" == "${defaultPort}" ]]; then
                    fileName="${configPath}02_dokodemodoor_inbounds_${port}_default.json"
                else
                    fileName="${configPath}02_dokodemodoor_inbounds_${port}.json"
                fi

                if [[ -n ${hysteriaPort} ]]; then
                    hysteriaFileName="${configPath}02_dokodemodoor_inbounds_hysteria_${port}.json"
                fi

                # 开放端口
                allowPort "${port}"
                allowPort "${port}" "udp"

                local settingsPort=443
                if [[ -n "${customPort}" ]]; then
                    settingsPort=${customPort}
                fi

                if [[ -n ${hysteriaFileName} ]]; then
                    cat <<EOF >"${hysteriaFileName}"
{
  "inbounds": [
	{
	  "listen": "0.0.0.0",
	  "port": ${port},
	  "protocol": "dokodemo-door",
	  "settings": {
		"address": "127.0.0.1",
		"port": ${hysteriaPort},
		"network": "udp",
		"followRedirect": false
	  },
	  "tag": "dokodemo-door-newPort-hysteria-${port}"
	}
  ]
}
EOF
                fi
                cat <<EOF >"${fileName}"
{
  "inbounds": [
	{
	  "listen": "0.0.0.0",
	  "port": ${port},
	  "protocol": "dokodemo-door",
	  "settings": {
		"address": "127.0.0.1",
		"port": ${settingsPort},
		"network": "tcp",
		"followRedirect": false
	  },
	  "tag": "dokodemo-door-newPort-${port}"
	}
  ]
}
EOF
            done < <(echo "${newPort}" | tr ',' '\n')

            echoContent green " ---> 添加成功"
            reloadCore
            addCorePort
        fi
    elif [[ "${selectNewPortType}" == "3" ]]; then
        find ${configPath} -name "*dokodemodoor*" | grep -v "hysteria" | awk -F "[c][o][n][f][/]" '{print $2}' | awk -F "[_]" '{print $4}' | awk -F "[.]" '{print ""NR""":"$1}'
        read -r -p "请输入要删除的端口编号:" portIndex
        local dokoConfig
        dokoConfig=$(find ${configPath} -name "*dokodemodoor*" | grep -v "hysteria" | awk -F "[c][o][n][f][/]" '{print $2}' | awk -F "[_]" '{print $4}' | awk -F "[.]" '{print ""NR""":"$1}' | grep "${portIndex}:")
        if [[ -n "${dokoConfig}" ]]; then
            rm "${configPath}02_dokodemodoor_inbounds_$(echo "${dokoConfig}" | awk -F "[:]" '{print $2}').json"
            local hysteriaDokodemodoorFilePath=

            hysteriaDokodemodoorFilePath="${configPath}02_dokodemodoor_inbounds_hysteria_$(echo "${dokoConfig}" | awk -F "[:]" '{print $2}').json"
            if [[ -f "${hysteriaDokodemodoorFilePath}" ]]; then
                rm "${hysteriaDokodemodoorFilePath}"
            fi

            reloadCore
            addCorePort
        else
            echoContent yellow "\n ---> 编号输入错误，请重新选择"
            addCorePort
        fi
    fi
}

# 卸载脚本
unInstall() {
    read -r -p "是否确认卸载安装内容？[y/n]:" unInstallStatus
    if [[ "${unInstallStatus}" != "y" ]]; then
        echoContent green " ---> 放弃卸载"
        menu
        exit 0
    fi
    echoContent yellow " ---> 脚本不会删除acme相关配置，删除请手动执行 [rm -rf /root/.acme.sh]"
    handleNginx stop
    if [[ -z $(pgrep -f "nginx") ]]; then
        echoContent green " ---> 停止Nginx成功"
    fi

    if [[ "${coreInstallType}" == "1" ]]; then
        handleXray stop
        rm -rf /etc/systemd/system/xray.service
        echoContent green " ---> 删除Xray开机自启完成"

    elif [[ "${coreInstallType}" == "2" ]]; then

        handleV2Ray stop
        rm -rf /etc/systemd/system/v2ray.service
        echoContent green " ---> 删除V2Ray开机自启完成"

    fi

    if [[ -z "${hysteriaConfigPath}" ]]; then
        handleHysteria stop
        rm -rf /etc/systemd/system/hysteria.service
        echoContent green " ---> 删除Hysteria开机自启完成"
    fi

    if [[ -z "${tuicConfigPath}" ]]; then
        handleTuic stop
        rm -rf /etc/systemd/system/tuic.service
        echoContent green " ---> 删除Tuic开机自启完成"
    fi

    #    if [[ -f "/root/.acme.sh/acme.sh.env" ]] && grep -q 'acme.sh.env' </root/.bashrc; then
    #        sed -i 's/. "\/root\/.acme.sh\/acme.sh.env"//g' "$(grep '. "/root/.acme.sh/acme.sh.env"' -rl /root/.bashrc)"
    #    fi
    #    rm -rf /root/.acme.sh

    #    rm -rf /tmp/v2ray-agent-tls/*
    #    if [[ -d "/etc/v2ray-agent/tls" ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.key") ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.crt") ]]; then
    #        mv /etc/v2ray-agent/tls /tmp/v2ray-agent-tls
    #        if [[ -n $(find /tmp/v2ray-agent-tls -name '*.key') ]]; then
    #            echoContent yellow " ---> 备份证书成功，请注意留存。[/tmp/v2ray-agent-tls]"
    #        fi
    #    fi

    rm -rf /etc/v2ray-agent
    rm -rf ${nginxConfigPath}alone.conf

    if [[ -d "${nginxStaticPath}" && -f "${nginxStaticPath}/check" ]]; then
        rm -rf "${nginxStaticPath}"
        echoContent green " ---> 删除伪装网站完成"
    fi

    rm -rf /usr/bin/vasma
    rm -rf /usr/sbin/vasma
    echoContent green " ---> 卸载快捷方式完成"
    echoContent green " ---> 卸载v2ray-agent脚本完成"
}

# 修改V2Ray CDN节点
updateV2RayCDN() {

    echoContent skyBlue "\n进度 $1/${totalProgress} : 修改CDN节点"

    if [[ -n "${currentAdd}" ]]; then
        echoContent red "=============================================================="
        echoContent yellow "1.CNAME www.digitalocean.com"
        echoContent yellow "2.CNAME who.int"
        echoContent yellow "3.CNAME blog.hostmonit.com"
        echoContent yellow "4.手动输入[可输入多个，比如: 1.1.1.1,1.1.2.2,cloudflare.com 逗号分隔]"
        echoContent yellow "5.移除CDN节点"
        echoContent red "=============================================================="
        read -r -p "请选择:" selectCDNType
        case ${selectCDNType} in
        1)
            setDomain="www.digitalocean.com"
            ;;
        2)
            setDomain="who.int"
            ;;
        3)
            setDomain="blog.hostmonit.com"
            ;;
        4)
            read -r -p "请输入想要自定义CDN IP或者域名:" setDomain
            ;;
        5)
            setDomain=${currentHost}
            ;;
        esac

        if [[ -n "${setDomain}" ]]; then
            local cdnAddressResult=
            cdnAddressResult=$(jq -r ".inbounds[0].add = \"${setDomain}\" " ${configPath}${frontingType}.json)
            echo "${cdnAddressResult}" | jq . >${configPath}${frontingType}.json

            echoContent green " ---> 修改CDN成功"
        fi
    else
        echoContent red " ---> 未安装可用类型"
    fi
}

# manageUser 用户管理
manageUser() {
    echoContent skyBlue "\n进度 $1/${totalProgress} : 多用户管理"
    echoContent skyBlue "-----------------------------------------------------"
    echoContent yellow "1.添加用户"
    echoContent yellow "2.删除用户"
    echoContent skyBlue "-----------------------------------------------------"
    read -r -p "请选择:" manageUserType
    if [[ "${manageUserType}" == "1" ]]; then
        addUser
    elif [[ "${manageUserType}" == "2" ]]; then
        removeUser
    else
        echoContent red " ---> 选择错误"
    fi
}

# 自定义uuid
customUUID() {
    read -r -p "请输入合法的UUID，[回车]随机UUID:" currentCustomUUID
    echo
    if [[ -z "${currentCustomUUID}" ]]; then
        currentCustomUUID=$(${ctlPath} uuid)
        echoContent yellow "uuid：${currentCustomUUID}\n"

    else
        jq -r -c '.inbounds[0].settings.clients[].id' ${configPath}${frontingType}.json | while read -r line; do
            if [[ "${line}" == "${currentCustomUUID}" ]]; then
                echo >/tmp/v2ray-agent
            fi
        done
        if [[ -f "/tmp/v2ray-agent" && -n $(cat /tmp/v2ray-agent) ]]; then
            echoContent red " ---> UUID不可重复"
            rm /tmp/v2ray-agent
            exit 0
        fi
    fi
}

# 自定义email
customUserEmail() {
    read -r -p "请输入合法的email，[回车]随机email:" currentCustomEmail
    echo
    if [[ -z "${currentCustomEmail}" ]]; then
        currentCustomEmail="${currentCustomUUID}"
        echoContent yellow "email: ${currentCustomEmail}\n"
    else
        local defaultConfig=${frontingType}

        if echo "${currentInstallProtocolType}" | grep -q "7" && [[ -z "${frontingType}" ]]; then
            defaultConfig="07_VLESS_vision_reality_inbounds"
        fi

        jq -r -c '.inbounds[0].settings.clients[].email' ${configPath}${defaultConfig}.json | while read -r line; do
            if [[ "${line}" == "${currentCustomEmail}" ]]; then
                echo >/tmp/v2ray-agent
            fi
        done
        if [[ -f "/tmp/v2ray-agent" && -n $(cat /tmp/v2ray-agent) ]]; then
            echoContent red " ---> email不可重复"
            rm /tmp/v2ray-agent
            exit 0
        fi
    fi
    #	fi
}

# 添加用户
addUserXray() {
    readConfigHostPathUUID
    read -r -p "请输入要添加的用户数量:" userNum
    echo
    if [[ -z ${userNum} || ${userNum} -le 0 ]]; then
        echoContent red " ---> 输入有误，请重新输入"
        exit 0
    fi
    # 生成用户
    if [[ "${userNum}" == "1" ]]; then
        customUUID
        customUserEmail
    fi

    while [[ ${userNum} -gt 0 ]]; do
        local users=
        ((userNum--)) || true

        if [[ -n "${currentCustomUUID}" ]]; then
            uuid=${currentCustomUUID}
        else
            uuid=$(${ctlPath} uuid)
        fi
        local email=
        if [[ -z "${currentCustomEmail}" ]]; then
            email=${uuid}
        else
            email=${currentCustomEmail}
        fi

        # VLESS TCP
        if echo "${currentInstallProtocolType}" | grep -q "0"; then
            local clients=
            clients=$(initXrayClients 0 "${uuid}" "${email}")
            clients=$(jq -r ".inbounds[0].settings.clients = ${clients}" ${configPath}${frontingType}.json)
            echo "${clients}" | jq . >${configPath}${frontingType}.json
        fi

        # VLESS WS
        if echo "${currentInstallProtocolType}" | grep -q "1"; then
            local clients=
            clients=$(initXrayClients 1 "${uuid}" "${email}")
            clients=$(jq -r ".inbounds[0].settings.clients = ${clients}" ${configPath}03_VLESS_WS_inbounds.json)
            echo "${clients}" | jq . >${configPath}03_VLESS_WS_inbounds.json
        fi

        # trojan grpc
        if echo "${currentInstallProtocolType}" | grep -q "2"; then
            local clients=
            clients=$(initXrayClients 2 "${uuid}" "${email}")
            clients=$(jq -r ".inbounds[0].settings.clients = ${clients}" ${configPath}04_trojan_gRPC_inbounds.json)
            echo "${clients}" | jq . >${configPath}04_trojan_gRPC_inbounds.json
        fi
        # VMess WS
        if echo "${currentInstallProtocolType}" | grep -q "3"; then
            local clients=
            clients=$(initXrayClients 3 "${uuid}" "${email}")
            clients=$(jq -r ".inbounds[0].settings.clients = ${clients}" ${configPath}05_VMess_WS_inbounds.json)
            echo "${clients}" | jq . >${configPath}05_VMess_WS_inbounds.json
        fi

        # trojan tcp
        if echo "${currentInstallProtocolType}" | grep -q "4"; then
            local clients=
            clients=$(initXrayClients 4 "${uuid}" "${email}")
            clients=$(jq -r ".inbounds[0].settings.clients = ${clients}" ${configPath}04_trojan_TCP_inbounds.json)
            echo "${clients}" | jq . >${configPath}04_trojan_TCP_inbounds.json
        fi

        # vless grpc
        if echo "${currentInstallProtocolType}" | grep -q "5"; then
            local clients=
            clients=$(initXrayClients 5 "${uuid}" "${email}")
            clients=$(jq -r ".inbounds[0].settings.clients = ${clients}" ${configPath}06_VLESS_gRPC_inbounds.json)
            echo "${clients}" | jq . >${configPath}06_VLESS_gRPC_inbounds.json
        fi

        # vless reality vision
        if echo "${currentInstallProtocolType}" | grep -q "7"; then
            local clients=
            clients=$(initXrayClients 7 "${uuid}" "${email}")
            clients=$(jq -r ".inbounds[0].settings.clients = ${clients}" ${configPath}07_VLESS_vision_reality_inbounds.json)
            echo "${clients}" | jq . >${configPath}07_VLESS_vision_reality_inbounds.json
        fi

        # vless reality grpc
        if echo "${currentInstallProtocolType}" | grep -q "8"; then
            local clients=
            clients=$(initXrayClients 8 "${uuid}" "${email}")
            clients=$(jq -r ".inbounds[0].settings.clients = ${clients}" ${configPath}08_VLESS_reality_fallback_grpc_inbounds.json)
            echo "${clients}" | jq . >${configPath}08_VLESS_reality_fallback_grpc_inbounds.json
        fi

        # hysteria
        if echo "${currentInstallProtocolType}" | grep -q "6"; then
            local clients=
            clients=$(initXrayClients 6 "${uuid}" "${email}")

            clients=$(jq -r ".auth.config = ${clients}" ${hysteriaConfigPath}config.json)
            echo "${clients}" | jq . >${hysteriaConfigPath}config.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 9; then
            local tuicResult

            tuicResult=$(jq -r ".users.\"${uuid}\" += \"${uuid}\"" "${tuicConfigPath}config.json")
            echo "${tuicResult}" | jq . >"${tuicConfigPath}config.json"
        fi
    done

    reloadCore
    echoContent green " ---> 添加完成"
    manageAccount 1
}
# 添加用户
addUser() {

    echoContent yellow "添加新用户后，需要重新查看订阅"
    read -r -p "请输入要添加的用户数量:" userNum
    echo
    if [[ -z ${userNum} || ${userNum} -le 0 ]]; then
        echoContent red " ---> 输入有误，请重新输入"
        exit 0
    fi

    # 生成用户
    if [[ "${userNum}" == "1" ]]; then
        customUUID
        customUserEmail
    fi

    while [[ ${userNum} -gt 0 ]]; do
        local users=
        ((userNum--)) || true
        if [[ -n "${currentCustomUUID}" ]]; then
            uuid=${currentCustomUUID}
        else
            uuid=$(${ctlPath} uuid)
        fi

        if [[ -n "${currentCustomEmail}" ]]; then
            email=${currentCustomEmail}_${uuid}
        else
            email=${currentHost}_${uuid}
        fi

        #	兼容v2ray-core
        users="{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-vision\",\"email\":\"${email}\",\"alterId\":0}"

        if [[ "${coreInstallType}" == "2" ]]; then
            users="{\"id\":\"${uuid}\",\"email\":\"${email}\",\"alterId\":0}"
        fi

        if echo ${currentInstallProtocolType} | grep -q 0; then
            local vlessUsers="${users//\,\"alterId\":0/}"
            vlessUsers="${users//${email}/${email}_VLESS_TCP}"
            local vlessTcpResult
            vlessTcpResult=$(jq -r ".inbounds[0].settings.clients += [${vlessUsers}]" ${configPath}${frontingType}.json)
            echo "${vlessTcpResult}" | jq . >${configPath}${frontingType}.json
        fi

        if echo ${currentInstallProtocolType} | grep -q trojan; then
            local trojanXTLSUsers="${users//\,\"alterId\":0/}"
            trojanXTLSUsers="${trojanXTLSUsers//${email}/${email}_Trojan_TCP}"
            trojanXTLSUsers=${trojanXTLSUsers//"id"/"password"}

            local trojanXTLSResult
            trojanXTLSResult=$(jq -r ".inbounds[0].settings.clients += [${trojanXTLSUsers}]" ${configPath}${frontingType}.json)
            echo "${trojanXTLSResult}" | jq . >${configPath}${frontingType}.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 1; then
            local vlessUsers="${users//\,\"alterId\":0/}"
            vlessUsers="${vlessUsers//${email}/${email}_VLESS_TCP}"
            vlessUsers="${vlessUsers//\"flow\":\"xtls-rprx-vision\"\,/}"
            local vlessWsResult
            vlessWsResult=$(jq -r ".inbounds[0].settings.clients += [${vlessUsers}]" ${configPath}03_VLESS_WS_inbounds.json)
            echo "${vlessWsResult}" | jq . >${configPath}03_VLESS_WS_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 2; then
            local trojangRPCUsers="${users//\"flow\":\"xtls-rprx-vision\"\,/}"
            trojangRPCUsers="${trojangRPCUsers//${email}/${email}_Trojan_gRPC}"
            trojangRPCUsers="${trojangRPCUsers//\,\"alterId\":0/}"
            trojangRPCUsers=${trojangRPCUsers//"id"/"password"}

            local trojangRPCResult
            trojangRPCResult=$(jq -r ".inbounds[0].settings.clients += [${trojangRPCUsers}]" ${configPath}04_trojan_gRPC_inbounds.json)
            echo "${trojangRPCResult}" | jq . >${configPath}04_trojan_gRPC_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 3; then
            local vmessUsers="${users//\"flow\":\"xtls-rprx-vision\"\,/}"
            vmessUsers="${vmessUsers//${email}/${email}_VMess_TCP}"
            local vmessWsResult
            vmessWsResult=$(jq -r ".inbounds[0].settings.clients += [${vmessUsers}]" ${configPath}05_VMess_WS_inbounds.json)
            echo "${vmessWsResult}" | jq . >${configPath}05_VMess_WS_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 5; then
            local vlessGRPCUsers="${users//\"flow\":\"xtls-rprx-vision\"\,/}"
            vlessGRPCUsers="${vlessGRPCUsers//\,\"alterId\":0/}"
            vlessGRPCUsers="${vlessGRPCUsers//${email}/${email}_VLESS_gRPC}"
            local vlessGRPCResult
            vlessGRPCResult=$(jq -r ".inbounds[0].settings.clients += [${vlessGRPCUsers}]" ${configPath}06_VLESS_gRPC_inbounds.json)
            echo "${vlessGRPCResult}" | jq . >${configPath}06_VLESS_gRPC_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 4; then
            local trojanUsers="${users//\"flow\":\"xtls-rprx-vision\"\,/}"
            trojanUsers="${trojanUsers//id/password}"
            trojanUsers="${trojanUsers//\,\"alterId\":0/}"
            trojanUsers="${trojanUsers//${email}/${email}_Trojan_TCP}"

            local trojanTCPResult
            trojanTCPResult=$(jq -r ".inbounds[0].settings.clients += [${trojanUsers}]" ${configPath}04_trojan_TCP_inbounds.json)
            echo "${trojanTCPResult}" | jq . >${configPath}04_trojan_TCP_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 6; then
            local hysteriaResult
            hysteriaResult=$(jq -r ".auth.config += [\"${uuid}\"]" ${hysteriaConfigPath}config.json)
            echo "${hysteriaResult}" | jq . >${hysteriaConfigPath}config.json
        fi
    done

    reloadCore
    echoContent green " ---> 添加完成"
    manageAccount 1
}

# 移除用户
removeUser() {
    local uuid=
    if echo ${currentInstallProtocolType} | grep -q 0 || echo ${currentInstallProtocolType} | grep -q trojan; then
        jq -r -c .inbounds[0].settings.clients[].email ${configPath}${frontingType}.json | awk '{print NR""":"$0}'
        read -r -p "请选择要删除的用户编号[仅支持单个删除]:" delUserIndex
        if [[ $(jq -r '.inbounds[0].settings.clients|length' ${configPath}${frontingType}.json) -lt ${delUserIndex} ]]; then
            echoContent red " ---> 选择错误"
        else
            delUserIndex=$((delUserIndex - 1))
            local vlessTcpResult
            uuid=$(jq -r ".inbounds[0].settings.clients[${delUserIndex}].id" ${configPath}${frontingType}.json)
            vlessTcpResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}${frontingType}.json)
            echo "${vlessTcpResult}" | jq . >${configPath}${frontingType}.json
        fi
    elif [[ -n "${realityStatus}" ]]; then
        jq -r -c .inbounds[0].settings.clients[].email ${configPath}07_VLESS_vision_reality_inbounds.json | awk '{print NR""":"$0}'
        read -r -p "请选择要删除的用户编号[仅支持单个删除]:" delUserIndex
        if [[ $(jq -r '.inbounds[0].settings.clients|length' ${configPath}07_VLESS_vision_reality_inbounds.json) -lt ${delUserIndex} ]]; then
            echoContent red " ---> 选择错误"
        else
            delUserIndex=$((delUserIndex - 1))
            local vlessRealityResult
            uuid=$(jq -r ".inbounds[0].settings.clients[${delUserIndex}].id" ${configPath}${frontingType}.json)
            vlessRealityResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}07_VLESS_vision_reality_inbounds.json)
            echo "${vlessRealityResult}" | jq . >${configPath}07_VLESS_vision_reality_inbounds.json
        fi
    fi

    if [[ -n "${delUserIndex}" ]]; then
        if echo ${currentInstallProtocolType} | grep -q 1; then
            local vlessWSResult
            vlessWSResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}03_VLESS_WS_inbounds.json)
            echo "${vlessWSResult}" | jq . >${configPath}03_VLESS_WS_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 2; then
            local trojangRPCUsers
            trojangRPCUsers=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}04_trojan_gRPC_inbounds.json)
            echo "${trojangRPCUsers}" | jq . >${configPath}04_trojan_gRPC_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 3; then
            local vmessWSResult
            vmessWSResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}05_VMess_WS_inbounds.json)
            echo "${vmessWSResult}" | jq . >${configPath}05_VMess_WS_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 5; then
            local vlessGRPCResult
            vlessGRPCResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}06_VLESS_gRPC_inbounds.json)
            echo "${vlessGRPCResult}" | jq . >${configPath}06_VLESS_gRPC_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 4; then
            local trojanTCPResult
            trojanTCPResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}04_trojan_TCP_inbounds.json)
            echo "${trojanTCPResult}" | jq . >${configPath}04_trojan_TCP_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 6; then
            local hysteriaResult
            hysteriaResult=$(jq -r 'del(.auth.config['${delUserIndex}'])' ${hysteriaConfigPath}config.json)
            echo "${hysteriaResult}" | jq . >${hysteriaConfigPath}config.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 7; then
            local vlessRealityResult
            vlessRealityResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}07_VLESS_vision_reality_inbounds.json)
            echo "${vlessRealityResult}" | jq . >${configPath}07_VLESS_vision_reality_inbounds.json
        fi
        if echo ${currentInstallProtocolType} | grep -q 8; then
            local vlessRealityGRPCResult
            vlessRealityGRPCResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}08_VLESS_reality_fallback_grpc_inbounds.json)
            echo "${vlessRealityGRPCResult}" | jq . >${configPath}08_VLESS_reality_fallback_grpc_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q 9; then
            local tuicResult
            tuicResult=$(jq -r "del(.users.\"${uuid}\")" "${tuicConfigPath}config.json")
            echo "${tuicResult}" | jq . >"${tuicConfigPath}config.json"
        fi
        reloadCore
    fi
    manageAccount 1
}
# 更新脚本
updateV2RayAgent() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 更新v2ray-agent脚本"
    rm -rf /etc/v2ray-agent/install.sh
    #    if wget --help | grep -q show-progress; then
    wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
    #    else
    #        wget -c -q -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
    #    fi

    sudo chmod 700 /etc/v2ray-agent/install.sh
    local version
    version=$(grep '当前版本：v' "/etc/v2ray-agent/install.sh" | awk -F "[v]" '{print $2}' | tail -n +2 | head -n 1 | awk -F "[\"]" '{print $1}')

    echoContent green "\n ---> 更新完毕"
    echoContent yellow " ---> 请手动执行[vasma]打开脚本"
    echoContent green " ---> 当前版本：${version}\n"
    echoContent yellow "如更新不成功，请手动执行下面命令\n"
    echoContent skyBlue "wget -P /root -N --no-check-certificate https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh && chmod 700 /root/install.sh && /root/install.sh"
    echo
    exit 0
}

# 防火墙
handleFirewall() {
    if systemctl status ufw 2>/dev/null | grep -q "active (exited)" && [[ "$1" == "stop" ]]; then
        systemctl stop ufw >/dev/null 2>&1
        systemctl disable ufw >/dev/null 2>&1
        echoContent green " ---> ufw关闭成功"

    fi

    if systemctl status firewalld 2>/dev/null | grep -q "active (running)" && [[ "$1" == "stop" ]]; then
        systemctl stop firewalld >/dev/null 2>&1
        systemctl disable firewalld >/dev/null 2>&1
        echoContent green " ---> firewalld关闭成功"
    fi
}

# 安装BBR
bbrInstall() {
    echoContent red "\n=============================================================="
    echoContent green "BBR、DD脚本用的[ylx2016]的成熟作品，地址[https://github.com/ylx2016/Linux-NetSpeed]，请熟知"
    echoContent yellow "1.安装脚本【推荐原版BBR+FQ】"
    echoContent yellow "2.回退主目录"
    echoContent red "=============================================================="
    read -r -p "请选择:" installBBRStatus
    if [[ "${installBBRStatus}" == "1" ]]; then
        wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    else
        menu
    fi
}

# 查看、检查日志
checkLog() {
    if [[ -z "${configPath}" && -z "${realityStatus}" ]]; then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        exit 0
    fi
    local realityLogShow=
    local logStatus=false
    if grep -q "access" ${configPath}00_log.json; then
        logStatus=true
    fi

    echoContent skyBlue "\n功能 $1/${totalProgress} : 查看日志"
    echoContent red "\n=============================================================="
    echoContent yellow "# 建议仅调试时打开access日志\n"

    if [[ "${logStatus}" == "false" ]]; then
        echoContent yellow "1.打开access日志"
    else
        echoContent yellow "1.关闭access日志"
    fi

    echoContent yellow "2.监听access日志"
    echoContent yellow "3.监听error日志"
    echoContent yellow "4.查看证书定时任务日志"
    echoContent yellow "5.查看证书安装日志"
    echoContent yellow "6.清空日志"
    echoContent red "=============================================================="

    read -r -p "请选择:" selectAccessLogType
    local configPathLog=${configPath//conf\//}

    case ${selectAccessLogType} in
    1)
        if [[ "${logStatus}" == "false" ]]; then
            realityLogShow=true
            cat <<EOF >${configPath}00_log.json
{
  "log": {
  	"access":"${configPathLog}access.log",
    "error": "${configPathLog}error.log",
    "loglevel": "debug"
  }
}
EOF
        elif [[ "${logStatus}" == "true" ]]; then
            realityLogShow=false
            cat <<EOF >${configPath}00_log.json
{
  "log": {
    "error": "${configPathLog}error.log",
    "loglevel": "warning"
  }
}
EOF
        fi

        if [[ -n ${realityStatus} ]]; then
            local vlessVisionRealityInbounds
            vlessVisionRealityInbounds=$(jq -r ".inbounds[0].streamSettings.realitySettings.show=${realityLogShow}" ${configPath}07_VLESS_vision_reality_inbounds.json)
            echo "${vlessVisionRealityInbounds}" | jq . >${configPath}07_VLESS_vision_reality_inbounds.json
        fi
        reloadCore
        checkLog 1
        ;;
    2)
        tail -f ${configPathLog}access.log
        ;;
    3)
        tail -f ${configPathLog}error.log
        ;;
    4)
        if [[ ! -f "/etc/v2ray-agent/crontab_tls.log" ]]; then
            touch /etc/v2ray-agent/crontab_tls.log
        fi
        tail -n 100 /etc/v2ray-agent/crontab_tls.log
        ;;
    5)
        tail -n 100 /etc/v2ray-agent/tls/acme.log
        ;;
    6)
        echo >${configPathLog}access.log
        echo >${configPathLog}error.log
        ;;
    esac
}

# 脚本快捷方式
aliasInstall() {

    if [[ -f "$HOME/install.sh" ]] && [[ -d "/etc/v2ray-agent" ]] && grep <"$HOME/install.sh" -q "作者:mack-a"; then
        mv "$HOME/install.sh" /etc/v2ray-agent/install.sh
        local vasmaType=
        if [[ -d "/usr/bin/" ]]; then
            if [[ ! -f "/usr/bin/vasma" ]]; then
                ln -s /etc/v2ray-agent/install.sh /usr/bin/vasma
                chmod 700 /usr/bin/vasma
                vasmaType=true
            fi

            rm -rf "$HOME/install.sh"
        elif [[ -d "/usr/sbin" ]]; then
            if [[ ! -f "/usr/sbin/vasma" ]]; then
                ln -s /etc/v2ray-agent/install.sh /usr/sbin/vasma
                chmod 700 /usr/sbin/vasma
                vasmaType=true
            fi
            rm -rf "$HOME/install.sh"
        fi
        if [[ "${vasmaType}" == "true" ]]; then
            echoContent green "快捷方式创建成功，可执行[vasma]重新打开脚本"
        fi
    fi
}

# 检查ipv6、ipv4
checkIPv6() {
    currentIPv6IP=$(curl -s -6 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)

    if [[ -z "${currentIPv6IP}" ]]; then
        echoContent red " ---> 不支持ipv6"
        exit 0
    fi
}

# ipv6 分流
ipv6Routing() {
    if [[ -z "${configPath}" ]]; then
        echoContent red " ---> 未安装，请使用脚本安装"
        menu
        exit 0
    fi

    checkIPv6
    echoContent skyBlue "\n功能 1/${totalProgress} : IPv6分流"
    echoContent red "\n=============================================================="
    echoContent yellow "1.查看已分流域名"
    echoContent yellow "2.添加域名"
    echoContent yellow "3.设置IPv6全局"
    echoContent yellow "4.卸载IPv6分流"
    echoContent red "=============================================================="
    read -r -p "请选择:" ipv6Status
    if [[ "${ipv6Status}" == "1" ]]; then

        jq -r -c '.routing.rules[]|select (.outboundTag=="IPv6-out")|.domain' ${configPath}09_routing.json | jq -r
        exit 0
    elif [[ "${ipv6Status}" == "2" ]]; then
        echoContent red "=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "# 注意事项"
        echoContent yellow "# 使用教程：https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"

        read -r -p "请按照上面示例录入域名:" domainList
        addInstallRouting IPv6-out outboundTag "${domainList}"

        unInstallOutbounds IPv6-out

        outbounds=$(jq -r '.outbounds += [{"protocol":"freedom","settings":{"domainStrategy":"UseIPv6"},"tag":"IPv6-out"}]' ${configPath}10_ipv4_outbounds.json)

        echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

        echoContent green " ---> 添加成功"

    elif [[ "${ipv6Status}" == "3" ]]; then
        echoContent red "=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "1.会删除设置的所有分流规则"
        echoContent yellow "2.会删除除IPv6之外的所有出站规则"
        read -r -p "是否确认设置？[y/n]:" IPv6OutStatus

        if [[ "${IPv6OutStatus}" == "y" ]]; then
            cat <<EOF >${configPath}10_ipv4_outbounds.json
            {
                "outbounds":[
                    {
                        "protocol":"freedom",
                        "settings":{
                            "domainStrategy":"UseIPv6"
                        },
                        "tag":"IPv6-out"
                    }
                ]
            }
EOF
            rm ${configPath}09_routing.json >/dev/null 2>&1
            echoContent green " ---> IPv6全局出站设置成功"
        else
            echoContent green " ---> 放弃设置"
            exit 0
        fi

    elif [[ "${ipv6Status}" == "4" ]]; then

        unInstallRouting IPv6-out outboundTag

        unInstallOutbounds IPv6-out

        if ! grep -q "IPv4-out" <"${configPath}10_ipv4_outbounds.json"; then
            outbounds=$(jq -r '.outbounds += [{"protocol":"freedom","settings": {"domainStrategy": "UseIPv4"},"tag":"IPv4-out"}]' ${configPath}10_ipv4_outbounds.json)

            echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json
        fi
        echoContent green " ---> IPv6分流卸载成功"
    else
        echoContent red " ---> 选择错误"
        exit 0
    fi

    reloadCore
}

# bt下载管理
btTools() {
    if [[ -z "${configPath}" ]]; then
        echoContent red " ---> 未安装，请使用脚本安装"
        menu
        exit 0
    fi

    echoContent skyBlue "\n功能 1/${totalProgress} : bt下载管理"
    echoContent red "\n=============================================================="

    if [[ -f ${configPath}09_routing.json ]] && grep -q bittorrent <${configPath}09_routing.json; then
        echoContent yellow "当前状态:已禁用"
    else
        echoContent yellow "当前状态:未禁用"
    fi

    echoContent yellow "1.禁用"
    echoContent yellow "2.打开"
    echoContent red "=============================================================="
    read -r -p "请选择:" btStatus
    if [[ "${btStatus}" == "1" ]]; then

        if [[ -f "${configPath}09_routing.json" ]]; then

            unInstallRouting blackhole-out outboundTag

            routing=$(jq -r '.routing.rules += [{"type":"field","outboundTag":"blackhole-out","protocol":["bittorrent"]}]' ${configPath}09_routing.json)

            echo "${routing}" | jq . >${configPath}09_routing.json

        else
            cat <<EOF >${configPath}09_routing.json
{
    "routing":{
        "domainStrategy": "IPOnDemand",
        "rules": [
          {
            "type": "field",
            "outboundTag": "blackhole-out",
            "protocol": [ "bittorrent" ]
          }
        ]
  }
}
EOF
        fi

        installSniffing

        unInstallOutbounds blackhole-out

        outbounds=$(jq -r '.outbounds += [{"protocol":"blackhole","tag":"blackhole-out"}]' ${configPath}10_ipv4_outbounds.json)

        echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

        echoContent green " ---> BT下载禁用成功"

    elif [[ "${btStatus}" == "2" ]]; then

        unInstallSniffing

        unInstallRouting blackhole-out outboundTag bittorrent

        #		unInstallOutbounds blackhole-out

        echoContent green " ---> BT下载打开成功"
    else
        echoContent red " ---> 选择错误"
        exit 0
    fi

    reloadCore
}

# 域名黑名单
blacklist() {
    if [[ -z "${configPath}" ]]; then
        echoContent red " ---> 未安装，请使用脚本安装"
        menu
        exit 0
    fi

    echoContent skyBlue "\n进度  $1/${totalProgress} : 域名黑名单"
    echoContent red "\n=============================================================="
    echoContent yellow "1.查看已屏蔽域名"
    echoContent yellow "2.添加域名"
    echoContent yellow "3.屏蔽国内域名"
    echoContent yellow "4.删除黑名单"
    echoContent red "=============================================================="

    read -r -p "请选择:" blacklistStatus
    if [[ "${blacklistStatus}" == "1" ]]; then
        jq -r -c '.routing.rules[]|select (.outboundTag=="blackhole-out")|.domain' ${configPath}09_routing.json | jq -r
        exit 0
    elif [[ "${blacklistStatus}" == "2" ]]; then
        echoContent red "=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "1.规则支持预定义域名列表[https://github.com/v2fly/domain-list-community]"
        echoContent yellow "2.规则支持自定义域名"
        echoContent yellow "3.录入示例:speedtest,facebook,cn,example.com"
        echoContent yellow "4.如果域名在预定义域名列表中存在则使用 geosite:xx，如果不存在则默认使用输入的域名"
        echoContent yellow "5.添加规则为增量配置，不会删除之前设置的内容\n"
        read -r -p "请按照上面示例录入域名:" domainList

        if [[ -f "${configPath}09_routing.json" ]]; then
            addInstallRouting blackhole-out outboundTag "${domainList}"
        fi
        unInstallOutbounds blackhole-out

        outbounds=$(jq -r '.outbounds += [{"protocol":"blackhole","tag":"blackhole-out"}]' ${configPath}10_ipv4_outbounds.json)

        echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

        echoContent green " ---> 添加成功"

    elif [[ "${blacklistStatus}" == "3" ]]; then
        addInstallRouting blackhole-out outboundTag "cn"

        unInstallOutbounds blackhole-out

        outbounds=$(jq -r '.outbounds += [{"protocol":"blackhole","tag":"blackhole-out"}]' ${configPath}10_ipv4_outbounds.json)

        echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

        echoContent green " ---> 屏蔽国内域名成功"

    elif [[ "${blacklistStatus}" == "4" ]]; then

        unInstallRouting blackhole-out outboundTag

        echoContent green " ---> 域名黑名单删除成功"
    else
        echoContent red " ---> 选择错误"
        exit 0
    fi
    reloadCore
}
# 添加routing配置
addInstallRouting() {

    local tag=$1    # warp-socks
    local type=$2   # outboundTag/inboundTag
    local domain=$3 # 域名

    if [[ -z "${tag}" || -z "${type}" || -z "${domain}" ]]; then
        echoContent red " ---> 参数错误"
        exit 0
    fi

    local routingRule=
    if [[ ! -f "${configPath}09_routing.json" ]]; then
        cat <<EOF >${configPath}09_routing.json
{
    "routing":{
        "type": "field",
        "rules": [
            {
                "type": "field",
                "domain": [
                ],
            "outboundTag": "${tag}"
          }
        ]
  }
}
EOF
    fi
    local routingRule=
    routingRule=$(jq -r '.routing.rules[]|select(.outboundTag=="'"${tag}"'")' ${configPath}09_routing.json)
    if [[ -z "${routingRule}" ]]; then
        if [[ "${tag}" == "dokodemoDoor-80" ]]; then
            routingRule="{\"type\": \"field\",\"port\": 80,\"domain\": [],\"outboundTag\": \"${tag}\"}"
        elif [[ "${tag}" == "dokodemoDoor-443" ]]; then
            routingRule="{\"type\": \"field\",\"port\": 443,\"domain\": [],\"outboundTag\": \"${tag}\"}"
        else
            routingRule="{\"type\": \"field\",\"domain\": [],\"outboundTag\": \"${tag}\"}"
        fi
    fi

    while read -r line; do
        if echo "${routingRule}" | grep -q "${line}"; then
            echoContent yellow " ---> ${line}已存在，跳过"
        else
            local geositeStatus
            geositeStatus=$(curl -s "https://api.github.com/repos/v2fly/domain-list-community/contents/data/${line}" | jq .message)

            if [[ "${geositeStatus}" == "null" ]]; then
                routingRule=$(echo "${routingRule}" | jq -r '.domain += ["geosite:'"${line}"'"]')
            else
                routingRule=$(echo "${routingRule}" | jq -r '.domain += ["domain:'"${line}"'"]')
            fi
        fi
    done < <(echo "${domain}" | tr ',' '\n')

    unInstallRouting "${tag}" "${type}"
    if ! grep -q "gstatic.com" ${configPath}09_routing.json && [[ "${tag}" == "blackhole-out" ]]; then
        local routing=
        routing=$(jq -r ".routing.rules += [{\"type\": \"field\",\"domain\": [\"gstatic.com\"],\"outboundTag\": \"direct\"}]" ${configPath}09_routing.json)
        echo "${routing}" | jq . >${configPath}09_routing.json
    fi

    routing=$(jq -r ".routing.rules += [${routingRule}]" ${configPath}09_routing.json)
    echo "${routing}" | jq . >${configPath}09_routing.json
}
# 根据tag卸载Routing
unInstallRouting() {
    local tag=$1
    local type=$2
    local protocol=$3

    if [[ -f "${configPath}09_routing.json" ]]; then
        local routing
        if grep -q "${tag}" ${configPath}09_routing.json && grep -q "${type}" ${configPath}09_routing.json; then

            jq -c .routing.rules[] ${configPath}09_routing.json | while read -r line; do
                local index=$((index + 1))
                local delStatus=0
                if [[ "${type}" == "outboundTag" ]] && echo "${line}" | jq .outboundTag | grep -q "${tag}"; then
                    delStatus=1
                elif [[ "${type}" == "inboundTag" ]] && echo "${line}" | jq .inboundTag | grep -q "${tag}"; then
                    delStatus=1
                fi

                if [[ -n ${protocol} ]] && echo "${line}" | jq .protocol | grep -q "${protocol}"; then
                    delStatus=1
                elif [[ -z ${protocol} ]] && [[ $(echo "${line}" | jq .protocol) != "null" ]]; then
                    delStatus=0
                fi

                if [[ ${delStatus} == 1 ]]; then
                    routing=$(jq -r 'del(.routing.rules['$((index - 1))'])' ${configPath}09_routing.json)
                    echo "${routing}" | jq . >${configPath}09_routing.json
                fi
            done
        fi
    fi
}

# 根据tag卸载出站
unInstallOutbounds() {
    local tag=$1

    if grep -q "${tag}" ${configPath}10_ipv4_outbounds.json; then
        local ipv6OutIndex
        ipv6OutIndex=$(jq .outbounds[].tag ${configPath}10_ipv4_outbounds.json | awk '{print ""NR""":"$0}' | grep "${tag}" | awk -F "[:]" '{print $1}' | head -1)
        if [[ ${ipv6OutIndex} -gt 0 ]]; then
            routing=$(jq -r 'del(.outbounds['$((ipv6OutIndex - 1))'])' ${configPath}10_ipv4_outbounds.json)
            echo "${routing}" | jq . >${configPath}10_ipv4_outbounds.json
        fi
    fi

}

# 卸载嗅探
unInstallSniffing() {

    find ${configPath} -name "*inbounds.json*" | awk -F "[c][o][n][f][/]" '{print $2}' | while read -r inbound; do
        if grep -q "destOverride" <"${configPath}${inbound}"; then
            sniffing=$(jq -r 'del(.inbounds[0].sniffing)' "${configPath}${inbound}")
            echo "${sniffing}" | jq . >"${configPath}${inbound}"
        fi
    done

}

# 安装嗅探
installSniffing() {
    readInstallType
    find ${configPath} -name "*inbounds.json*" | awk -F "[c][o][n][f][/]" '{print $2}' | while read -r inbound; do
        if ! grep -q "destOverride" <"${configPath}${inbound}"; then
            sniffing=$(jq -r '.inbounds[0].sniffing = {"enabled":true,"destOverride":["http","tls"]}' "${configPath}${inbound}")
            echo "${sniffing}" | jq . >"${configPath}${inbound}"
        fi
    done
}

# warp分流
warpRouting() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : WARP分流"
    echoContent red "=============================================================="
    if [[ -z $(which warp-cli) ]]; then
        echo
        read -r -p "WARP未安装，是否安装 ？[y/n]:" installCloudflareWarpStatus
        if [[ "${installCloudflareWarpStatus}" == "y" ]]; then
            installWarp
        else
            echoContent yellow " ---> 放弃安装"
            exit 0
        fi
    fi

    echoContent red "\n=============================================================="
    echoContent yellow "1.查看已分流域名"
    echoContent yellow "2.添加域名"
    echoContent yellow "3.设置WARP全局"
    echoContent yellow "4.卸载WARP分流"
    echoContent red "=============================================================="
    read -r -p "请选择:" warpStatus
    if [[ "${warpStatus}" == "1" ]]; then
        jq -r -c '.routing.rules[]|select (.outboundTag=="warp-socks-out")|.domain' ${configPath}09_routing.json | jq -r
        exit 0
    elif [[ "${warpStatus}" == "2" ]]; then
        echoContent yellow "# 注意事项"
        echoContent yellow "# 使用教程：https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"

        read -r -p "请按照上面示例录入域名:" domainList

        addInstallRouting warp-socks-out outboundTag "${domainList}"

        unInstallOutbounds warp-socks-out

        local outbounds
        outbounds=$(jq -r '.outbounds += [{"protocol":"socks","settings":{"servers":[{"address":"127.0.0.1","port":31303}]},"tag":"warp-socks-out"}]' ${configPath}10_ipv4_outbounds.json)

        echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

        echoContent green " ---> 添加成功"

    elif [[ "${warpStatus}" == "3" ]]; then

        echoContent red "=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "1.会删除设置的所有分流规则"
        echoContent yellow "2.会删除除WARP之外的所有出站规则"
        read -r -p "是否确认设置？[y/n]:" warpOutStatus

        if [[ "${warpOutStatus}" == "y" ]]; then
            cat <<EOF >${configPath}10_ipv4_outbounds.json
{
    "outbounds":[
        {
          "protocol": "socks",
          "settings": {
            "servers": [
              {
                "address": "127.0.0.1",
                "port": 31303
              }
            ]
          },
          "tag": "warp-socks-out"
        }
    ]
}
EOF
            rm ${configPath}09_routing.json >/dev/null 2>&1
            echoContent green " ---> WARP全局出站设置成功"
        else
            echoContent green " ---> 放弃设置"
            exit 0
        fi

    elif [[ "${warpStatus}" == "4" ]]; then

        ${removeType} cloudflare-warp >/dev/null 2>&1

        unInstallRouting warp-socks-out outboundTag

        unInstallOutbounds warp-socks-out

        if ! grep -q "IPv4-out" <"${configPath}10_ipv4_outbounds.json"; then
            outbounds=$(jq -r '.outbounds += [{"protocol":"freedom","settings": {"domainStrategy": "UseIPv4"},"tag":"IPv4-out"}]' ${configPath}10_ipv4_outbounds.json)

            echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json
        fi

        echoContent green " ---> WARP分流卸载成功"
    else
        echoContent red " ---> 选择错误"
        exit 0
    fi
    reloadCore
}

# 读取第三方warp配置
readConfigWarpReg() {
    if [[ ! -f "/etc/v2ray-agent/warp/config" ]]; then
        /etc/v2ray-agent/warp/warp-reg >/etc/v2ray-agent/warp/config
    fi

    secretKeyWarpReg=$(grep <"/etc/v2ray-agent/warp/config" private_key | awk '{print $2}')

    addressWarpReg=$(grep <"/etc/v2ray-agent/warp/config" v6 | awk '{print $2}')

    publicKeyWarpReg=$(grep <"/etc/v2ray-agent/warp/config" public_key | awk '{print $2}')

    reservedWarpReg=$(grep <"/etc/v2ray-agent/warp/config" reserved | awk -F "[:]" '{print $2}')

}
# warp分流-第三方IPv4
warpRoutingReg() {
    local type=$2
    echoContent skyBlue "\n进度  $1/${totalProgress} : WARP分流[第三方]"
    echoContent red "=============================================================="
    if [[ ! -f "/etc/v2ray-agent/warp/warp-reg" ]]; then
        echo
        echoContent yellow "# 注意事项"
        echoContent yellow "# 依赖第三方程序，请熟知其中风险"
        echoContent yellow "# 项目地址：https://github.com/badafans/warp-reg \n"

        read -r -p "warp-reg未安装，是否安装 ？[y/n]:" installWarpRegStatus

        if [[ "${installWarpRegStatus}" == "y" ]]; then

            curl -sLo /etc/v2ray-agent/warp/warp-reg "https://github.com/badafans/warp-reg/releases/download/v1.0/${warpRegCoreCPUVendor}"
            chmod 655 /etc/v2ray-agent/warp/warp-reg

        else
            echoContent yellow " ---> 放弃安装"
            exit 0
        fi
    fi
    echoContent red "\n=============================================================="
    echoContent yellow "1.查看已分流域名"
    echoContent yellow "2.添加域名"
    echoContent yellow "3.设置WARP全局"
    echoContent yellow "4.卸载WARP分流"
    echoContent red "=============================================================="
    read -r -p "请选择:" warpStatus

    readConfigWarpReg
    local address=
    if [[ ${type} == "IPv4" ]]; then
        address="172.16.0.2/32"
    elif [[ ${type} == "IPv6" ]]; then
        address="${addressWarpReg}/128"
    else
        echoContent red " ---> IP获取失败，退出安装"
    fi

    if [[ "${warpStatus}" == "1" ]]; then
        jq -r -c '.routing.rules[]|select (.outboundTag=="wireguard-out-'"${type}"'")|.domain' ${configPath}09_routing.json | jq -r
        exit 0
    elif [[ "${warpStatus}" == "2" ]]; then
        echoContent yellow "# 注意事项"
        echoContent yellow "# 使用教程：https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"

        read -r -p "请按照上面示例录入域名:" domainList

        addInstallRouting wireguard-out-"${type}" outboundTag "${domainList}"

        unInstallOutbounds wireguard-out-"${type}"

        local outbounds
        outbounds=$(jq -r '.outbounds += [{"protocol":"wireguard","settings":{"secretKey":"'"${secretKeyWarpReg}"'","address":["'"${address}"'"],"peers":[{"publicKey":"'"${publicKeyWarpReg}"'","allowedIPs":["0.0.0.0/0","::/0"],"endpoint":"162.159.192.1:2408"}],"reserved":'"${reservedWarpReg}"',"mtu":1280},"tag":"wireguard-out-'"${type}"'"}]' ${configPath}10_ipv4_outbounds.json)

        echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

        echoContent green " ---> 添加成功"

    elif [[ "${warpStatus}" == "3" ]]; then

        echoContent red "=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "1.会删除设置的所有分流规则"
        echoContent yellow "2.会删除除WARP[第三方]之外的所有出站规则"
        read -r -p "是否确认设置？[y/n]:" warpOutStatus

        if [[ "${warpOutStatus}" == "y" ]]; then
            readConfigWarpReg

            cat <<EOF >${configPath}10_ipv4_outbounds.json
{
    "outbounds":[
        {
            "protocol": "wireguard",
            "settings": {
                "secretKey": "${secretKeyWarpReg}",
                "address": [
                    "${address}"
                ],
                "peers": [
                    {
                        "publicKey": "${publicKeyWarpReg}",
                        "allowedIPs": [
                            "0.0.0.0/0",
                             "::/0"
                        ],
                        "endpoint": "162.159.192.1:2408"
                    }
                ],
                "reserved": ${reservedWarpReg},
                "mtu": 1280
            },
            "tag": "wireguard-out-${type}"
        }
    ]
}
EOF
            rm ${configPath}09_routing.json >/dev/null 2>&1
            echoContent green " ---> WARP全局出站设置成功"
        else
            echoContent green " ---> 放弃设置"
            exit 0
        fi

    elif [[ "${warpStatus}" == "4" ]]; then

        unInstallRouting wireguard-out-"${type}" outboundTag

        unInstallOutbounds wireguard-out-"${type}"
        if [[ "${type}" == "IPv4" ]]; then
            if ! grep -q "wireguard-out-IPv6" <${configPath}10_ipv4_outbounds.json; then
                rm -rf /etc/v2ray-agent/warp/config >/dev/null 2>&1
            fi
        elif [[ "${type}" == "IPv6" ]]; then
            if ! grep -q "wireguard-out-IPv4" <${configPath}10_ipv4_outbounds.json; then
                rm -rf /etc/v2ray-agent/warp/config >/dev/null 2>&1
            fi
        fi

        if ! grep -q "IPv4-out" <"${configPath}10_ipv4_outbounds.json"; then

            cat <<EOF >${configPath}10_ipv4_outbounds.json
            {
                "outbounds":[
                    {
                        "protocol":"freedom",
                        "settings":{
                            "domainStrategy":"UseIPv4"
                        },
                        "tag":"IPv4-out"
                    },
                    {
                        "protocol":"freedom",
                        "settings":{
                            "domainStrategy":"UseIPv6"
                        },
                        "tag":"IPv6-out"
                    },
                    {
                        "protocol":"blackhole",
                        "tag":"blackhole-out"
                    }
                ]
            }
EOF
        fi

        echoContent green " ---> WARP分流卸载成功"
    else
        echoContent red " ---> 选择错误"
        exit 0
    fi
    reloadCore
}

# 分流工具
routingToolsMenu() {
    echoContent skyBlue "\n功能 1/${totalProgress} : 分流工具"
    echoContent red "\n=============================================================="
    echoContent yellow "1.WARP分流【第三方 IPv4】"
    echoContent yellow "2.WARP分流【第三方 IPv6】"
    echoContent yellow "3.IPv6分流"
    echoContent yellow "4.任意门分流"
    echoContent yellow "5.DNS分流"
    echoContent yellow "6.VMess+WS+TLS分流"
    echoContent yellow "7.SNI反向代理分流"

    read -r -p "请选择:" selectType

    case ${selectType} in
    1)
        warpRoutingReg 1 IPv4
        ;;
    2)
        warpRoutingReg 1 IPv6
        ;;
    3)
        ipv6Routing 1
        ;;
    4)
        dokodemoDoorRouting 1
        ;;
    5)
        dnsRouting 1
        ;;
    6)
        vmessWSRouting 1
        ;;
    7)
        sniRouting 1
        ;;
    esac

}
# 流媒体工具箱
streamingToolbox() {
    echoContent skyBlue "\n功能 1/${totalProgress} : 流媒体工具箱"
    echoContent red "\n=============================================================="
    echoContent yellow "1.任意门落地机解锁流媒体"
    echoContent yellow "2.DNS解锁流媒体"
    echoContent yellow "3.VMess+WS+TLS解锁流媒体"
    read -r -p "请选择:" selectType

    case ${selectType} in
    1)
        dokodemoDoorRouting
        ;;
    2)
        dnsRouting
        ;;
    3)
        vmessWSRouting
        ;;
    esac

}

# 任意门解锁流媒体
dokodemoDoorRouting() {
    echoContent skyBlue "\n功能 1/${totalProgress} : 任意门分流"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项"
    echoContent yellow "# 使用教程：https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"

    echoContent yellow "1.添加出站"
    echoContent yellow "2.添加入站"
    echoContent yellow "3.卸载"
    read -r -p "请选择:" selectType

    case ${selectType} in
    1)
        setDokodemoDoorRoutingOutbounds
        ;;
    2)
        setDokodemoDoorRoutingInbounds
        ;;
    3)
        removeDokodemoDoorRouting
        ;;
    esac
}

# VMess+WS+TLS 分流
vmessWSRouting() {
    echoContent skyBlue "\n功能 1/${totalProgress} : VMess+WS+TLS 分流"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项"
    echoContent yellow "# 使用教程：https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"

    echoContent yellow "1.添加出站"
    echoContent yellow "2.卸载"
    read -r -p "请选择:" selectType

    case ${selectType} in
    1)
        setVMessWSRoutingOutbounds
        ;;
    2)
        removeVMessWSRouting
        ;;
    esac
}

# 设置VMess+WS+TLS【仅出站】
setVMessWSRoutingOutbounds() {
    read -r -p "请输入VMess+WS+TLS的地址:" setVMessWSTLSAddress
    echoContent red "=============================================================="
    echoContent yellow "录入示例:netflix,openai\n"
    read -r -p "请按照上面示例录入域名:" domainList

    if [[ -z ${domainList} ]]; then
        echoContent red " ---> 域名不可为空"
        setVMessWSRoutingOutbounds
    fi

    if [[ -n "${setVMessWSTLSAddress}" ]]; then

        unInstallOutbounds VMess-out

        echo
        read -r -p "请输入VMess+WS+TLS的端口:" setVMessWSTLSPort
        echo
        if [[ -z "${setVMessWSTLSPort}" ]]; then
            echoContent red " ---> 端口不可为空"
        fi

        read -r -p "请输入VMess+WS+TLS的UUID:" setVMessWSTLSUUID
        echo
        if [[ -z "${setVMessWSTLSUUID}" ]]; then
            echoContent red " ---> UUID不可为空"
        fi

        read -r -p "请输入VMess+WS+TLS的Path路径:" setVMessWSTLSPath
        echo
        if [[ -z "${setVMessWSTLSPath}" ]]; then
            echoContent red " ---> 路径不可为空"
        elif ! echo "${setVMessWSTLSPath}" | grep -q "/"; then
            setVMessWSTLSPath="/${setVMessWSTLSPath}"
        fi

        outbounds=$(jq -r ".outbounds += [{\"tag\":\"VMess-out\",\"protocol\":\"vmess\",\"streamSettings\":{\"network\":\"ws\",\"security\":\"tls\",\"tlsSettings\":{\"allowInsecure\":false},\"wsSettings\":{\"path\":\"${setVMessWSTLSPath}\"}},\"mux\":{\"enabled\":true,\"concurrency\":8},\"settings\":{\"vnext\":[{\"address\":\"${setVMessWSTLSAddress}\",\"port\":${setVMessWSTLSPort},\"users\":[{\"id\":\"${setVMessWSTLSUUID}\",\"security\":\"auto\",\"alterId\":0}]}]}}]" ${configPath}10_ipv4_outbounds.json)

        echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

        addInstallRouting VMess-out outboundTag "${domainList}"
        reloadCore
        echoContent green " ---> 添加分流成功"
        exit 0
    fi
    echoContent red " ---> 地址不可为空"
    setVMessWSRoutingOutbounds
}

# 设置任意门分流【出站】
setDokodemoDoorRoutingOutbounds() {
    read -r -p "请输入目标vps的IP:" setIP
    echoContent red "=============================================================="
    echoContent yellow "录入示例:netflix,openai\n"
    read -r -p "请按照上面示例录入域名:" domainList

    if [[ -z ${domainList} ]]; then
        echoContent red " ---> 域名不可为空"
        setDokodemoDoorRoutingOutbounds
    fi

    if [[ -n "${setIP}" ]]; then

        unInstallOutbounds dokodemoDoor-80
        unInstallOutbounds dokodemoDoor-443

        addInstallRouting dokodemoDoor-80 outboundTag "${domainList}"
        addInstallRouting dokodemoDoor-443 outboundTag "${domainList}"

        outbounds=$(jq -r ".outbounds += [{\"tag\":\"dokodemoDoor-80\",\"protocol\":\"freedom\",\"settings\":{\"domainStrategy\":\"AsIs\",\"redirect\":\"${setIP}:22387\"}},{\"tag\":\"dokodemoDoor-443\",\"protocol\":\"freedom\",\"settings\":{\"domainStrategy\":\"AsIs\",\"redirect\":\"${setIP}:22388\"}}]" ${configPath}10_ipv4_outbounds.json)

        echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

        reloadCore
        echoContent green " ---> 添加任意门分流成功"
        exit 0
    fi
    echoContent red " ---> ip不可为空"
}

# 设置任意门分流【入站】
setDokodemoDoorRoutingInbounds() {

    echoContent skyBlue "\n功能 1/${totalProgress} : 任意门添加入站"
    echoContent red "\n=============================================================="
    echoContent yellow "ip录入示例:1.1.1.1,1.1.1.2"
    echoContent yellow "下面的域名一定要和出站的vps一致"
    echoContent yellow "域名录入示例:netflix,openai\n"
    read -r -p "请输入允许访问该vps的IP:" setIPs
    if [[ -n "${setIPs}" ]]; then
        read -r -p "请按照上面示例录入域名:" domainList
        allowPort 22387
        allowPort 22388

        cat <<EOF >${configPath}01_dokodemoDoor_inbounds.json
{
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 22387,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "0.0.0.0",
        "port": 80,
        "network": "tcp",
        "followRedirect": false
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http"
        ]
      },
      "tag": "dokodemoDoor-80"
    },
    {
      "listen": "0.0.0.0",
      "port": 22388,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "0.0.0.0",
        "port": 443,
        "network": "tcp",
        "followRedirect": false
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "tls"
        ]
      },
      "tag": "dokodemoDoor-443"
    }
  ]
}
EOF
        local domains=
        domains=[]
        while read -r line; do
            local geositeStatus
            geositeStatus=$(curl -s "https://api.github.com/repos/v2fly/domain-list-community/contents/data/${line}" | jq .message)

            if [[ "${geositeStatus}" == "null" ]]; then
                domains=$(echo "${domains}" | jq -r '. += ["geosite:'"${line}"'"]')
            else
                domains=$(echo "${domains}" | jq -r '. += ["domain:'"${line}"'"]')
            fi
        done < <(echo "${domainList}" | tr ',' '\n')

        if [[ -f "${configPath}09_routing.json" ]]; then
            unInstallRouting dokodemoDoor-80 inboundTag
            unInstallRouting dokodemoDoor-443 inboundTag

            local routing
            routing=$(jq -r ".routing.rules += [{\"source\":[\"${setIPs//,/\",\"}\"],\"domains\":${domains},\"type\":\"field\",\"inboundTag\":[\"dokodemoDoor-80\",\"dokodemoDoor-443\"],\"outboundTag\":\"direct\"},{\"type\":\"field\",\"inboundTag\":[\"dokodemoDoor-80\",\"dokodemoDoor-443\"],\"outboundTag\":\"blackhole-out\"}]" ${configPath}09_routing.json)
            echo "${routing}" | jq . >${configPath}09_routing.json
        else

            cat <<EOF >${configPath}09_routing.json
{
  "routing": {
    "rules": [
      {
        "source": [
            "${setIPs//,/\",\"}"
        ],
        "domains":${domains},
        "type": "field",
        "inboundTag": [
          "dokodemoDoor-80",
          "dokodemoDoor-443"
        ],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "inboundTag": [
          "dokodemoDoor-80",
          "dokodemoDoor-443"
        ],
        "outboundTag": "blackhole-out"
      }
    ]
  }
}
EOF

        fi

        reloadCore
        echoContent green " ---> 添加落地机入站分流成功"
        exit 0
    fi
    echoContent red " ---> ip不可为空"
}

# 移除任意门分流
removeDokodemoDoorRouting() {

    unInstallOutbounds dokodemoDoor-80
    unInstallOutbounds dokodemoDoor-443

    unInstallRouting dokodemoDoor-80 inboundTag
    unInstallRouting dokodemoDoor-443 inboundTag

    unInstallRouting dokodemoDoor-80 outboundTag
    unInstallRouting dokodemoDoor-443 outboundTag

    rm -rf ${configPath}01_dokodemoDoor_inbounds.json

    reloadCore
    echoContent green " ---> 卸载成功"
}

# 移除VMess+WS+TLS分流
removeVMessWSRouting() {

    unInstallOutbounds VMess-out

    unInstallRouting VMess-out outboundTag

    reloadCore
    echoContent green " ---> 卸载成功"
}

# 重启核心
reloadCore() {
    readInstallType

    if [[ "${coreInstallType}" == "1" ]]; then
        handleXray stop
        handleXray start
    elif [[ "${coreInstallType}" == "2" ]]; then
        handleV2Ray stop
        handleV2Ray start
    fi

    if [[ -n "${hysteriaConfigPath}" ]]; then
        handleHysteria stop
        handleHysteria start
    fi

    if [[ -n "${tuicConfigPath}" ]]; then
        handleTuic stop
        handleTuic start
    fi
}

# dns分流
dnsRouting() {

    if [[ -z "${configPath}" ]]; then
        echoContent red " ---> 未安装，请使用脚本安装"
        menu
        exit 0
    fi
    echoContent skyBlue "\n功能 1/${totalProgress} : DNS分流"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项"
    echoContent yellow "# 使用教程：https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"

    echoContent yellow "1.添加"
    echoContent yellow "2.卸载"
    read -r -p "请选择:" selectType

    case ${selectType} in
    1)
        setUnlockDNS
        ;;
    2)
        removeUnlockDNS
        ;;
    esac
}

# SNI反向代理分流
sniRouting() {

    if [[ -z "${configPath}" ]]; then
        echoContent red " ---> 未安装，请使用脚本安装"
        menu
        exit 0
    fi
    echoContent skyBlue "\n功能 1/${totalProgress} : SNI反向代理分流"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项"
    echoContent yellow "# 使用教程：https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"

    echoContent yellow "1.添加"
    echoContent yellow "2.卸载"
    read -r -p "请选择:" selectType

    case ${selectType} in
    1)
        setUnlockSNI
        ;;
    2)
        removeUnlockSNI
        ;;
    esac
}
# 设置SNI分流
setUnlockSNI() {
    read -r -p "请输入分流的SNI IP:" setSNIP
    if [[ -n ${setSNIP} ]]; then
        echoContent red "=============================================================="
        echoContent yellow "录入示例:netflix,disney,hulu"
        read -r -p "请按照上面示例录入域名:" domainList

        if [[ -n "${domainList}" ]]; then
            local hosts={}
            while read -r domain; do
                hosts=$(echo "${hosts}" | jq -r ".\"geosite:${domain}\"=\"${setSNIP}\"")
            done < <(echo "${domainList}" | tr ',' '\n')
            cat <<EOF >${configPath}11_dns.json
{
    "dns": {
        "hosts":${hosts},
        "servers": [
            "8.8.8.8",
            "1.1.1.1"
        ]
    }
}
EOF
            echoContent red " ---> SNI反向代理分流成功"
            reloadCore
        else
            echoContent red " ---> 域名不可为空"
        fi

    else

        echoContent red " ---> SNI IP不可为空"
    fi
    exit 0
}
# 设置dns
setUnlockDNS() {
    read -r -p "请输入分流的DNS:" setDNS
    if [[ -n ${setDNS} ]]; then
        echoContent red "=============================================================="
        echoContent yellow "录入示例:netflix,disney,hulu"
        echoContent yellow "默认方案请输入1，默认方案包括以下内容"
        echoContent yellow "netflix,bahamut,hulu,hbo,disney,bbc,4chan,fox,abema,dmm,niconico,pixiv,bilibili,viu"
        read -r -p "请按照上面示例录入域名:" domainList
        if [[ "${domainList}" == "1" ]]; then
            cat <<EOF >${configPath}11_dns.json
{
    "dns": {
        "servers": [
            {
                "address": "${setDNS}",
                "port": 53,
                "domains": [
                    "geosite:netflix",
                    "geosite:bahamut",
                    "geosite:hulu",
                    "geosite:hbo",
                    "geosite:disney",
                    "geosite:bbc",
                    "geosite:4chan",
                    "geosite:fox",
                    "geosite:abema",
                    "geosite:dmm",
                    "geosite:niconico",
                    "geosite:pixiv",
                    "geosite:bilibili",
                    "geosite:viu"
                ]
            },
        "localhost"
        ]
    }
}
EOF
        elif [[ -n "${domainList}" ]]; then
            cat <<EOF >${configPath}11_dns.json
{
    "dns": {
        "servers": [
            {
                "address": "${setDNS}",
                "port": 53,
                "domains": [
                    "geosite:${domainList//,/\",\"geosite:}"
                ]
            },
        "localhost"
        ]
    }
}
EOF
        fi

        reloadCore

        echoContent yellow "\n ---> 如还无法观看可以尝试以下两种方案"
        echoContent yellow " 1.重启vps"
        echoContent yellow " 2.卸载dns解锁后，修改本地的[/etc/resolv.conf]DNS设置并重启vps\n"
    else
        echoContent red " ---> dns不可为空"
    fi
    exit 0
}

# 移除 DNS分流
removeUnlockDNS() {
    cat <<EOF >${configPath}11_dns.json
{
	"dns": {
		"servers": [
			"localhost"
		]
	}
}
EOF
    reloadCore

    echoContent green " ---> 卸载成功"

    exit 0
}

# 移除SNI分流
removeUnlockSNI() {
    cat <<EOF >${configPath}11_dns.json
{
	"dns": {
		"servers": [
			"localhost"
		]
	}
}
EOF
    reloadCore

    echoContent green " ---> 卸载成功"

    exit 0
}

# v2ray-core个性化安装
customV2RayInstall() {
    echoContent skyBlue "\n========================个性化安装============================"
    echoContent yellow "VLESS前置，默认安装0，如果只需要安装0，则只选择0即可"
    echoContent yellow "0.VLESS+TLS_Vision+TCP"
    echoContent yellow "1.VLESS+TLS+WS[CDN]"
    echoContent yellow "2.Trojan+TLS+gRPC[CDN]"
    echoContent yellow "3.VMess+TLS+WS[CDN]"
    echoContent yellow "4.Trojan+TLS"
    echoContent yellow "5.VLESS+TLS+gRPC[CDN]"
    read -r -p "请选择[多选]，[例如:123]:" selectCustomInstallType
    echoContent skyBlue "--------------------------------------------------------------"
    if [[ -z ${selectCustomInstallType} ]]; then
        selectCustomInstallType=0
    fi
    if [[ "${selectCustomInstallType}" =~ ^[0-5]+$ ]]; then
        cleanUp xrayClean
        checkBTPanel
        totalProgress=17
        installTools 1
        # 申请tls
        initTLSNginxConfig 2
        installTLS 3
        handleNginx stop
        # 随机path
        if echo ${selectCustomInstallType} | grep -q 1 || echo ${selectCustomInstallType} | grep -q 3 || echo ${selectCustomInstallType} | grep -q 4; then
            randomPathFunction 5
            customCDNIP 6
        fi
        nginxBlog 7
        updateRedirectNginxConf
        handleNginx start

        # 安装V2Ray
        installV2Ray 8
        installV2RayService 9
        initV2RayConfig custom 10
        cleanUp xrayDel
        installCronTLS 14
        handleV2Ray stop
        handleV2Ray start
        # 生成账号
        checkGFWStatue 15
        showAccounts 16
    else
        echoContent red " ---> 输入不合法"
        customV2RayInstall
    fi
}

# Xray-core个性化安装
customXrayInstall() {
    echoContent skyBlue "\n========================个性化安装============================"
    echoContent yellow "VLESS前置，默认安装0，如果只需要安装0，则只选择0即可"
    echoContent yellow "0.VLESS+TLS_Vision+TCP[推荐]"
    echoContent yellow "1.VLESS+TLS+WS[CDN]"
    echoContent yellow "2.Trojan+TLS+gRPC[CDN]"
    echoContent yellow "3.VMess+TLS+WS[CDN]"
    echoContent yellow "4.Trojan+TLS"
    echoContent yellow "5.VLESS+TLS+gRPC[CDN]"
    echoContent yellow "7.VLESS+Reality+uTLS+Vision[推荐]"
    #    echoContent yellow "8.VLESS+Reality+gRPC"
    read -r -p "请选择[多选]，[例如:123]:" selectCustomInstallType
    echoContent skyBlue "--------------------------------------------------------------"
    if [[ -z ${selectCustomInstallType} ]]; then
        echoContent red " ---> 不可为空"
        customXrayInstall
    elif [[ "${selectCustomInstallType}" =~ ^[0-7]+$ ]]; then

        if ! echo "${selectCustomInstallType}" | grep -q "0"; then
            selectCustomInstallType="0${selectCustomInstallType}"
        fi
        cleanUp v2rayClean
        checkBTPanel
        totalProgress=12
        installTools 1
        if [[ -n "${btDomain}" ]]; then
            echoContent skyBlue "\n进度  3/${totalProgress} : 检测到宝塔面板，跳过申请TLS步骤"
            handleXray stop
            customPortFunction
        else
            # 申请tls
            initTLSNginxConfig 2
            handleXray stop
            #            handleNginx start
            installTLS 3
        fi

        handleNginx stop
        # 随机path
        if echo "${selectCustomInstallType}" | grep -q 1 || echo "${selectCustomInstallType}" | grep -q 2 || echo "${selectCustomInstallType}" | grep -q 3 || echo "${selectCustomInstallType}" | grep -q 5; then
            randomPathFunction 4
            customCDNIP 5
        fi
        if [[ -n "${btDomain}" ]]; then
            echoContent skyBlue "\n进度  6/${totalProgress} : 检测到宝塔面板，跳过伪装网站"
            #            echoContent red "=============================================================="
            #            echoContent yellow "# 注意事项"
            #            echoContent yellow "会清空当前安装网站下面的静态目录，如已自定义安装过请选择 [n]\n"
            #            read -r -p "请选择[y/n]:" nginxBlogBTStatus
            #            if [[ "${nginxBlogBTStatus}" == "y" ]]; then
            #                nginxBlog 6
            #            fi
        else
            nginxBlog 6
        fi
        updateRedirectNginxConf
        handleNginx start

        # 安装V2Ray
        installXray 7 true
        installXrayService 8
        initXrayConfig custom 9
        cleanUp v2rayDel

        installCronTLS 10
        handleXray stop
        handleXray start
        # 生成账号
        checkGFWStatue 11
        showAccounts 12
    else
        echoContent red " ---> 输入不合法"
        customXrayInstall
    fi
}

# 选择核心安装---v2ray-core、xray-core
selectCoreInstall() {
    echoContent skyBlue "\n功能 1/${totalProgress} : 选择核心安装"
    echoContent red "\n=============================================================="
    echoContent yellow "1.Xray-core"
    echoContent yellow "2.v2ray-core"
    echoContent red "=============================================================="
    read -r -p "请选择:" selectCoreType
    case ${selectCoreType} in
    1)
        if [[ "${selectInstallType}" == "2" ]]; then
            customXrayInstall
        else
            xrayCoreInstall
        fi
        ;;
    2)
        v2rayCoreVersion=
        echoContent red " ---> 由于v2ray不支持很多新的特性，为了降低开发成本现停止维护，建议使用Xray-core、hysteria、Tuic"
        exit 0
        if [[ "${selectInstallType}" == "2" ]]; then
            customV2RayInstall
        else
            v2rayCoreInstall
        fi
        ;;
    3)
        v2rayCoreVersion=v4.32.1
        if [[ "${selectInstallType}" == "2" ]]; then
            customV2RayInstall
        else
            v2rayCoreInstall
        fi
        ;;
    *)
        echoContent red ' ---> 选择错误，重新选择'
        selectCoreInstall
        ;;
    esac
}

# v2ray-core 安装
v2rayCoreInstall() {
    cleanUp xrayClean
    checkBTPanel
    selectCustomInstallType=
    totalProgress=13
    installTools 2
    # 申请tls
    initTLSNginxConfig 3

    handleV2Ray stop
    handleNginx start

    installTLS 4
    handleNginx stop
    randomPathFunction 5
    # 安装V2Ray
    installV2Ray 6
    installV2RayService 7
    customCDNIP 8
    initV2RayConfig all 9
    cleanUp xrayDel
    installCronTLS 10
    nginxBlog 11
    updateRedirectNginxConf
    handleV2Ray stop
    sleep 2
    handleV2Ray start
    handleNginx start
    # 生成账号
    checkGFWStatue 12
    showAccounts 13
}

# xray-core 安装
xrayCoreInstall() {
    cleanUp v2rayClean
    checkBTPanel
    selectCustomInstallType=
    totalProgress=13
    installTools 2
    if [[ -n "${btDomain}" ]]; then
        echoContent skyBlue "\n进度  3/${totalProgress} : 检测到宝塔面板，跳过申请TLS步骤"
        handleXray stop
        customPortFunction
    else
        # 申请tls
        initTLSNginxConfig 3
        handleXray stop
        #        handleNginx start

        installTLS 4
    fi

    handleNginx stop
    randomPathFunction 5
    # 安装Xray
    installXray 6 true
    installXrayService 7
    customCDNIP 8
    initXrayConfig all 9
    cleanUp v2rayDel
    installCronTLS 10
    if [[ -n "${btDomain}" ]]; then
        echoContent skyBlue "\n进度  11/${totalProgress} : 检测到宝塔面板，跳过伪装网站"
        #        echoContent red "=============================================================="
        #        echoContent yellow "# 注意事项"
        #        echoContent yellow "会清空当前安装网站下面的静态目录，如已自定义安装过请选择 [n]\n"
        #        read -r -p "请选择[y/n]:" nginxBlogBTStatus
        #        if [[ "${nginxBlogBTStatus}" == "y" ]]; then
        #            nginxBlog 11
        #        fi
    else
        nginxBlog 11
    fi
    updateRedirectNginxConf
    handleXray stop
    sleep 2
    handleXray start

    handleNginx start
    # 生成账号
    checkGFWStatue 12
    showAccounts 13
}

# Hysteria安装
hysteriaCoreInstall() {
    if ! echo "${currentInstallProtocolType}" | grep -q "0" || [[ -z "${coreInstallType}" ]]; then
        echoContent red "\n ---> 由于环境依赖，如安装hysteria，请先安装Xray-core的VLESS_TCP_TLS_Vision"
        exit 0
    fi
    totalProgress=5
    installHysteria 1
    initHysteriaConfig 2
    installHysteriaService 3
    reloadCore
    showAccounts 4
}
# 卸载 hysteria
unInstallHysteriaCore() {

    if [[ -z "${hysteriaConfigPath}" ]]; then
        echoContent red "\n ---> 未安装"
        exit 0
    fi
    deleteHysteriaPortHoppingRules
    handleHysteria stop
    rm -rf /etc/v2ray-agent/hysteria/*
    rm ${configPath}02_socks_inbounds_hysteria.json
    rm -rf /etc/systemd/system/hysteria.service
    echoContent green " ---> 卸载完成"
}
# 卸载Tuic
unInstallTuicCore() {

    if [[ -z "${tuicConfigPath}" ]]; then
        echoContent red "\n ---> 未安装"
        exit 0
    fi
    handleTuic stop
    rm -rf /etc/v2ray-agent/tuic/*
    rm -rf /etc/systemd/system/tuic.service
    echoContent green " ---> 卸载完成"
}
unInstallXrayCoreReality() {

    if [[ -z "${realityStatus}" ]]; then
        echoContent red "\n ---> 未安装"
        exit 0
    fi
    echoContent skyBlue "\n功能 1/1 : reality卸载"
    echoContent red "\n=============================================================="
    echoContent yellow "# 仅删除VLESS Reality相关配置，不会删除其他内容。"
    echoContent yellow "# 如果需要卸载其他内容，请卸载脚本功能"
    handleXray stop
    rm /etc/v2ray-agent/xray/conf/07_VLESS_vision_reality_inbounds.json
    rm /etc/v2ray-agent/xray/conf/08_VLESS_reality_fallback_grpc_inbounds.json
    echoContent green " ---> 卸载完成"
}

# 核心管理
coreVersionManageMenu() {

    if [[ -z "${coreInstallType}" ]]; then
        echoContent red "\n >没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0
    fi
    if [[ "${coreInstallType}" == "1" ]]; then
        xrayVersionManageMenu 1
    elif [[ "${coreInstallType}" == "2" ]]; then
        v2rayCoreVersion=
        v2rayVersionManageMenu 1
    fi
}
# 定时任务检查
cronFunction() {
    if [[ "${cronName}" == "RenewTLS" ]]; then
        renewalTLS
        exit 0
    elif [[ "${cronName}" == "UpdateGeo" ]]; then
        updateGeoSite >>/etc/v2ray-agent/crontab_updateGeoSite.log
        echoContent green " ---> geo更新日期:$(date "+%F %H:%M:%S")" >>/etc/v2ray-agent/crontab_updateGeoSite.log
        exit 0
    fi
}
# 账号管理
manageAccount() {
    echoContent skyBlue "\n功能 1/${totalProgress} : 账号管理"
    if [[ -z "${configPath}" ]]; then
        echoContent red " ---> 未安装"
        exit 0
    fi

    echoContent red "\n=============================================================="
    echoContent yellow "# 添加单个用户时可自定义email和uuid"
    echoContent yellow "# 如安装了Hysteria或者Tuic，账号会同时添加到相应的类型下面\n"
    echoContent yellow "1.查看账号"
    echoContent yellow "2.查看订阅"
    echoContent yellow "3.添加订阅"
    echoContent yellow "4.添加用户"
    echoContent yellow "5.删除用户"
    echoContent red "=============================================================="
    read -r -p "请输入:" manageAccountStatus
    if [[ "${manageAccountStatus}" == "1" ]]; then
        showAccounts 1
    elif [[ "${manageAccountStatus}" == "2" ]]; then
        subscribe
    elif [[ "${manageAccountStatus}" == "3" ]]; then
        addSubscribeMenu 1
    elif [[ "${manageAccountStatus}" == "4" ]]; then
        addUserXray
    elif [[ "${manageAccountStatus}" == "5" ]]; then
        removeUser
    else
        echoContent red " ---> 选择错误"
    fi
}

# 添加订阅
addSubscribeMenu() {
    echoContent skyBlue "\n===================== 添加其他机器订阅 ======================="
    echoContent yellow "1.添加"
    echoContent yellow "2.移除"
    echoContent red "=============================================================="
    read -r -p "请选择:" addSubscribeStatus
    if [[ "${addSubscribeStatus}" == "1" ]]; then
        addOtherSubscribe
    elif [[ "${addSubscribeStatus}" == "2" ]]; then
        rm -rf /etc/v2ray-agent/subscribe_remote/clashMeta/*
        rm -rf /etc/v2ray-agent/subscribe_remote/default/*
        echo >/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl
        echoContent green " ---> 其他机器订阅删除成功"
        subscribe
    fi
}
# 添加其他机器clashMeta订阅
addOtherSubscribe() {
    echoContent yellow "#注意事项:"
    echoContent yellow "请仔细阅读以下文章： https://www.v2ray-agent.com/archives/1681804748677"
    echoContent skyBlue "录入示例：www.v2ray-agent.com:443:vps1\n"
    read -r -p "请输入域名 端口 机器别名:" remoteSubscribeUrl
    if [[ -z "${remoteSubscribeUrl}" ]]; then
        echoContent red " ---> 不可为空"
        addSubscribe
    elif ! echo "${remoteSubscribeUrl}" | grep -q ":"; then
        echoContent red " ---> 规则不合法"
    else
        echo "${remoteSubscribeUrl}" >>/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl
        local remoteUrl=
        remoteUrl=$(echo "${remoteSubscribeUrl}" | awk -F "[:]" '{print $1":"$2}')

        local serverAlias=
        serverAlias=$(echo "${remoteSubscribeUrl}" | awk -F "[:]" '{print $3}')

        if [[ -n $(ls /etc/v2ray-agent/subscribe/clashMeta/) || -n $(ls /etc/v2ray-agent/subscribe/default/) ]]; then
            find /etc/v2ray-agent/subscribe_local/default/* | while read -r email; do
                email=$(echo "${email}" | awk -F "[d][e][f][a][u][l][t][/]" '{print $2}')

                local emailMd5=
                emailMd5=$(echo -n "${email}$(cat "/etc/v2ray-agent/subscribe_local/subscribeSalt")"$'\n' | md5sum | awk '{print $1}')

                local clashMetaProxies=
                clashMetaProxies=$(curl -s -4 "https://${remoteUrl}/s/clashMeta/${emailMd5}" | sed '/proxies:/d' | sed "s/${email}/${email}_${serverAlias}/g")

                local default=
                default=$(curl -s -4 "https://${remoteUrl}/s/default/${emailMd5}" | base64 -d | sed "s/${email}/${email}_${serverAlias}/g")

                if echo "${default}" | grep -q "${email}"; then
                    echo "${default}" >>"/etc/v2ray-agent/subscribe/default/${emailMd5}"
                    echo "${default}" >>"/etc/v2ray-agent/subscribe_remote/default/${email}"

                    echoContent green " ---> 通用订阅 ${email} 添加成功"
                else
                    echoContent red " ---> 通用订阅 ${email} 不存在"
                fi

                if echo "${clashMetaProxies}" | grep -q "${email}"; then
                    echo "${clashMetaProxies}" >>"/etc/v2ray-agent/subscribe/clashMeta/${emailMd5}"
                    echo "${clashMetaProxies}" >>"/etc/v2ray-agent/subscribe_remote/clashMeta/${email}"

                    echoContent green " ---> clashMeta订阅 ${email} 添加成功"
                else
                    echoContent red " ---> clashMeta订阅 ${email}不存在"
                fi
            done
        else
            echoContent red " ---> 请先查看订阅，再进行添加订阅"
        fi
    fi
}
# clashMeta配置文件
clashMetaConfig() {
    local url=$1
    local id=$2
    cat <<EOF >"/etc/v2ray-agent/subscribe/clashMetaProfiles/${id}"
mixed-port: 7890
unified-delay: false
geodata-mode: true
tcp-concurrent: false
find-process-mode: strict
global-client-fingerprint: chrome

allow-lan: true
mode: rule
log-level: info
ipv6: true

external-controller: 127.0.0.1:9090

geox-url:
  geoip: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat"
  geosite: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
  mmdb: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country.mmdb"

profile:
  store-selected: true
  store-fake-ip: true

sniffer:
  enable: false
  sniff:
    TLS:
      ports: [443]
    HTTP:
      ports: [80]
      override-destination: true

tun:
  enable: true
  stack: system
  dns-hijack:
    - 'any:53'
  auto-route: true
  auto-detect-interface: true

dns:
  enable: true
  listen: 0.0.0.0:1053
  ipv6: true
  enhanced-mode: fake-ip
  fake-ip-range: 28.0.0.1/8
  fake-ip-filter:
    - '*'
    - '+.lan'
  default-nameserver:
    - 223.5.5.5
  nameserver:
    - 'tls://8.8.4.4#DNS_Proxy'
    - 'tls://1.0.0.1#DNS_Proxy'
  proxy-server-nameserver:
    - https://dns.alidns.com/dns-query#h3=true
  nameserver-policy:
    "geosite:cn,private":
      - 223.5.5.5
      - 114.114.114.114
      - https://dns.alidns.com/dns-query#h3=true

proxy-providers:
  ${subscribeSalt}_provider:
    type: http
    path: ./${subscribeSalt}_provider.yaml
    url: ${url}
    interval: 3600
    health-check:
      enable: false
      url: http://www.gstatic.com/generate_204
      interval: 300

proxy-groups:
  - name: 节点选择
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择
      - 故障转移
      - 负载均衡
      - DIRECT
  - name: 流媒体
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择
      - 故障转移
      - 负载均衡
      - DIRECT
  - name: 手动切换
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies: null
  - name: 自动选择
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 36000
    tolerance: 50
    use:
      - ${subscribeSalt}_provider
    proxies: null
  - name: 故障转移
    type: fallback
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 自动选择
  - name: 负载均衡
    type: load-balance
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - ${subscribeSalt}_provider
    proxies: null
  - name: 全球代理
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择
  - name: DNS_Proxy
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 自动选择
      - 节点选择
      - DIRECT

  - name: Telegram
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择

  - name: YouTube
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择
  - name: Netflix
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 流媒体
      - 节点选择
      - 自动选择
  - name: HBO
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 流媒体
      - 节点选择
      - 自动选择
  - name: Bing
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 节点选择
      - 自动选择
  - name: OpenAI
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 节点选择
      - 自动选择
  - name: Disney
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 流媒体
      - 节点选择
      - 自动选择
  - name: GitHub
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择
      - DIRECT
  - name: Spotify
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 流媒体
      - 手动切换
      - 自动选择
      - DIRECT
  - name: Google
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择
      - DIRECT
  - name: 国内媒体
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - DIRECT
  - name: 本地直连
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - DIRECT
      - 节点选择
      - 自动选择
  - name: 漏网之鱼
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - DIRECT
      - 节点选择
      - 手动切换
      - 自动选择
rule-providers:
  lan:
    type: http
    behavior: classical
    interval: 86400
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Lan/Lan.yaml
    path: ./Rules/lan.yaml
  reject:
    type: http
    behavior: domain
    url: https://ghproxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt
    path: ./ruleset/reject.yaml
    interval: 86400
  proxy:
    type: http
    behavior: domain
    url: https://ghproxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/proxy.txt
    path: ./ruleset/proxy.yaml
    interval: 86400
  direct:
    type: http
    behavior: domain
    url: https://ghproxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/direct.txt
    path: ./ruleset/direct.yaml
    interval: 86400
  private:
    type: http
    behavior: domain
    url: https://ghproxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/private.txt
    path: ./ruleset/private.yaml
    interval: 86400
  gfw:
    type: http
    behavior: domain
    url: https://ghproxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/gfw.txt
    path: ./ruleset/gfw.yaml
    interval: 86400
  greatfire:
    type: http
    behavior: domain
    url: https://ghproxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/greatfire.txt
    path: ./ruleset/greatfire.yaml
    interval: 86400
  tld-not-cn:
    type: http
    behavior: domain
    url: https://ghproxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/tld-not-cn.txt
    path: ./ruleset/tld-not-cn.yaml
    interval: 86400
  telegramcidr:
    type: http
    behavior: ipcidr
    url: https://ghproxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/telegramcidr.txt
    path: ./ruleset/telegramcidr.yaml
    interval: 86400
  applications:
    type: http
    behavior: classical
    url: https://ghproxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/applications.txt
    path: ./ruleset/applications.yaml
    interval: 86400
  Disney:
    type: http
    behavior: classical
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Disney/Disney.yaml
    path: ./ruleset/disney.yaml
    interval: 86400
  Netflix:
    type: http
    behavior: classical
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Netflix/Netflix.yaml
    path: ./ruleset/netflix.yaml
    interval: 86400
  YouTube:
    type: http
    behavior: classical
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/YouTube/YouTube.yaml
    path: ./ruleset/youtube.yaml
    interval: 86400
  HBO:
    type: http
    behavior: classical
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/HBO/HBO.yaml
    path: ./ruleset/hbo.yaml
    interval: 86400
  OpenAI:
    type: http
    behavior: classical
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/OpenAI/OpenAI.yaml
    path: ./ruleset/openai.yaml
    interval: 86400
  Bing:
    type: http
    behavior: classical
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Bing/Bing.yaml
    path: ./ruleset/bing.yaml
    interval: 86400
  Google:
    type: http
    behavior: classical
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Google/Google.yaml
    path: ./ruleset/google.yaml
    interval: 86400
  GitHub:
    type: http
    behavior: classical
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/GitHub/GitHub.yaml
    path: ./ruleset/github.yaml
    interval: 86400
  Spotify:
    type: http
    behavior: classical
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Spotify/Spotify.yaml
    path: ./ruleset/spotify.yaml
    interval: 86400
  ChinaMaxDomain:
    type: http
    behavior: domain
    interval: 86400
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaMax/ChinaMax_Domain.yaml
    path: ./Rules/ChinaMaxDomain.yaml
  ChinaMaxIPNoIPv6:
    type: http
    behavior: ipcidr
    interval: 86400
    url: https://ghproxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaMax/ChinaMax_IP_No_IPv6.yaml
    path: ./Rules/ChinaMaxIPNoIPv6.yaml
rules:
  - RULE-SET,YouTube,YouTube,no-resolve
  - RULE-SET,Google,Google,no-resolve
  - RULE-SET,GitHub,GitHub
  - RULE-SET,telegramcidr,Telegram,no-resolve
  - RULE-SET,Spotify,Spotify,no-resolve
  - RULE-SET,Netflix,Netflix
  - RULE-SET,HBO,HBO
  - RULE-SET,Bing,Bing
  - RULE-SET,OpenAI,OpenAI
  - RULE-SET,Disney,Disney
  - RULE-SET,proxy,全球代理
  - RULE-SET,gfw,全球代理
  - RULE-SET,applications,本地直连
  - RULE-SET,ChinaMaxDomain,本地直连
  - RULE-SET,ChinaMaxIPNoIPv6,本地直连,no-resolve
  - RULE-SET,lan,本地直连,no-resolve
  - GEOIP,CN,本地直连
  - MATCH,漏网之鱼
EOF

}
# 随机salt
initRandomSalt() {
    local chars="abcdefghijklmnopqrtuxyz"
    local initCustomPath=
    for i in {1..10}; do
        echo "${i}" >/dev/null
        initCustomPath+="${chars:RANDOM%${#chars}:1}"
    done
    echo "${initCustomPath}"
}
# 订阅
subscribe() {
    readInstallProtocolType

    if echo "${currentInstallProtocolType}" | grep -q 0 && [[ -n "${configPath}" ]]; then

        echoContent skyBlue "-------------------------备注---------------------------------"
        echoContent yellow "# 查看订阅会重新生成本地账号的订阅"
        echoContent yellow "# 添加账号或者修改账号需要重新查看订阅才会重新生成对外访问的订阅内容"
        echoContent red "# 需要手动输入md5加密的salt值，如果不了解使用随机即可"
        echoContent yellow "# 不影响已添加的远程订阅的内容\n"

        if [[ -f "/etc/v2ray-agent/subscribe_local/subscribeSalt" && -n $(cat "/etc/v2ray-agent/subscribe_local/subscribeSalt") ]]; then
            read -r -p "读取到上次安装设置的Salt，是否使用上次生成的Salt ？[y/n]:" historySaltStatus
            if [[ "${historySaltStatus}" == "y" ]]; then
                subscribeSalt=$(cat /etc/v2ray-agent/subscribe_local/subscribeSalt)
            else
                read -r -p "请输入salt值, [回车]使用随机:" subscribeSalt
            fi
        else
            read -r -p "请输入salt值, [回车]使用随机:" subscribeSalt
        fi

        if [[ -z "${subscribeSalt}" ]]; then
            subscribeSalt=$(initRandomSalt)
        fi
        echoContent yellow "\n ---> Salt: ${subscribeSalt}"

        echo "${subscribeSalt}" >/etc/v2ray-agent/subscribe_local/subscribeSalt

        rm -rf /etc/v2ray-agent/subscribe/default/*
        rm -rf /etc/v2ray-agent/subscribe/clashMeta/*
        rm -rf /etc/v2ray-agent/subscribe_local/default/*
        rm -rf /etc/v2ray-agent/subscribe_local/clashMeta/*
        showAccounts >/dev/null

        if [[ -n $(ls /etc/v2ray-agent/subscribe_local/default/) ]]; then
            find /etc/v2ray-agent/subscribe_local/default/* | while read -r email; do
                email=$(echo "${email}" | awk -F "[d][e][f][a][u][l][t][/]" '{print $2}')
                # md5加密
                local emailMd5=
                emailMd5=$(echo -n "${email}${subscribeSalt}"$'\n' | md5sum | awk '{print $1}')

                cat "/etc/v2ray-agent/subscribe_local/default/${email}" >>"/etc/v2ray-agent/subscribe/default/${emailMd5}"

                if [[ -f "/etc/v2ray-agent/subscribe_remote/default/${email}" ]]; then
                    echo >"/etc/v2ray-agent/subscribe_remote/default/${email}_tmp"
                    while read -r remoteUrl; do
                        updateRemoteSubscribe "${emailMd5}" "${email}" "${remoteUrl}" "default"
                    done < <(grep "VLESS_TCP/TLS_Vision" <"/etc/v2ray-agent/subscribe_remote/default/${email}" | awk -F "@" '{print $2}' | awk -F "?" '{print $1}')

                    echo >"/etc/v2ray-agent/subscribe_remote/default/${email}"
                    cat "/etc/v2ray-agent/subscribe_remote/default/${email}_tmp" >"/etc/v2ray-agent/subscribe_remote/default/${email}"
                    cat "/etc/v2ray-agent/subscribe_remote/default/${email}" >>"/etc/v2ray-agent/subscribe/default/${emailMd5}"
                fi

                local base64Result
                base64Result=$(base64 -w 0 "/etc/v2ray-agent/subscribe/default/${emailMd5}")
                echo "${base64Result}" >"/etc/v2ray-agent/subscribe/default/${emailMd5}"

                echoContent yellow "--------------------------------------------------------------"
                local currentDomain=${currentHost}

                if [[ -n "${currentDefaultPort}" && "${currentDefaultPort}" != "443" ]]; then
                    currentDomain="${currentHost}:${currentDefaultPort}"
                fi
                echoContent skyBlue "\n----------默认订阅----------\n"
                echoContent green "email:${email}\n"
                echoContent yellow "url:https://${currentDomain}/s/default/${emailMd5}\n"
                echoContent yellow "在线二维码:https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://${currentDomain}/s/default/${emailMd5}\n"
                echo "https://${currentDomain}/s/default/${emailMd5}" | qrencode -s 10 -m 1 -t UTF8

                # clashMeta
                if [[ -f "/etc/v2ray-agent/subscribe_local/clashMeta/${email}" ]]; then

                    cat "/etc/v2ray-agent/subscribe_local/clashMeta/${email}" >>"/etc/v2ray-agent/subscribe/clashMeta/${emailMd5}"

                    if [[ -f "/etc/v2ray-agent/subscribe_remote/clashMeta/${email}" ]]; then
                        echo >"/etc/v2ray-agent/subscribe_remote/clashMeta/${email}_tmp"
                        while read -r remoteUrl; do
                            updateRemoteSubscribe "${emailMd5}" "${email}" "${remoteUrl}" "ClashMeta"
                        done < <(grep -A3 "VLESS_TCP/TLS_Vision" <"/etc/v2ray-agent/subscribe_remote/clashMeta/${email}" | awk '/server:|port:/ {print $2}' | paste -d ':' - -)
                        echo >"/etc/v2ray-agent/subscribe_remote/clashMeta/${email}"
                        cat "/etc/v2ray-agent/subscribe_remote/clashMeta/${email}_tmp" >"/etc/v2ray-agent/subscribe_remote/clashMeta/${email}"
                        cat "/etc/v2ray-agent/subscribe_remote/clashMeta/${email}" >>"/etc/v2ray-agent/subscribe/clashMeta/${emailMd5}"
                    fi

                    sed -i '1i\proxies:' "/etc/v2ray-agent/subscribe/clashMeta/${emailMd5}"

                    local clashProxyUrl="https://${currentDomain}/s/clashMeta/${emailMd5}"
                    clashMetaConfig "${clashProxyUrl}" "${emailMd5}"
                    echoContent skyBlue "\n----------clashMeta订阅----------\n"
                    echoContent yellow "url:https://${currentDomain}/s/clashMetaProfiles/${emailMd5}\n"
                    echoContent yellow "在线二维码:https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://${currentDomain}/s/clashMetaProfiles/${emailMd5}\n"
                    echo "https://${currentDomain}/s/clashMetaProfiles/${emailMd5}" | qrencode -s 10 -m 1 -t UTF8
                fi

                echoContent skyBlue "--------------------------------------------------------------"
            done
        fi
    else
        echoContent red " ---> 未安装伪装站点，无法使用订阅服务"
    fi
}

# 更新远程订阅
updateRemoteSubscribe() {
    local emailMD5=$1
    local email=$2
    local remoteUrl=$3
    local type=$4
    local remoteDomain=
    remoteDomain=$(echo "${remoteUrl}" | awk -F ":" '{print $1}')
    local serverAlias=
    serverAlias=$(grep "${remoteDomain}" <"/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl" | awk -F ":" '{print $3}')

    if [[ "${type}" == "ClashMeta" ]]; then
        local clashMetaProxies=
        clashMetaProxies=$(curl -s -4 "https://${remoteUrl}/s/clashMeta/${emailMD5}" | sed '/proxies:/d' | sed "s/${email}/${email}_${serverAlias}/g")
        if echo "${clashMetaProxies}" | grep -q "${email}"; then
            echo "${clashMetaProxies}" >>"/etc/v2ray-agent/subscribe_remote/clashMeta/${email}_tmp"

            echoContent green " ---> clashMeta订阅 ${remoteDomain}:${email} 更新成功"
        else
            echoContent red " ---> clashMeta订阅 ${remoteDomain}:${email}不存在"
        fi
    elif [[ "${type}" == "default" ]]; then
        local default=
        default=$(curl -s -4 "https://${remoteUrl}/s/default/${emailMD5}" | base64 -d | sed "s/${email}/${email}_${serverAlias}/g")
        if echo "${default}" | grep -q "${email}"; then
            echo "${default}" >>"/etc/v2ray-agent/subscribe_remote/default/${email}_tmp"

            echoContent green " ---> 通用订阅 ${remoteDomain}:${email} 更新成功"
        else
            echoContent red " ---> 通用订阅 ${remoteDomain}:${email} 不存在"
        fi
    fi
}

# 切换alpn
switchAlpn() {
    echoContent skyBlue "\n功能 1/${totalProgress} : 切换alpn"
    if [[ -z ${currentAlpn} ]]; then
        echoContent red " ---> 无法读取alpn，请检查是否安装"
        exit 0
    fi

    echoContent red "\n=============================================================="
    echoContent green "当前alpn首位为:${currentAlpn}"
    echoContent yellow "  1.当http/1.1首位时，trojan可用，gRPC部分客户端可用【客户端支持手动选择alpn的可用】"
    echoContent yellow "  2.当h2首位时，gRPC可用，trojan部分客户端可用【客户端支持手动选择alpn的可用】"
    echoContent yellow "  3.如客户端不支持手动更换alpn，建议使用此功能更改服务端alpn顺序，来使用相应的协议"
    echoContent red "=============================================================="

    if [[ "${currentAlpn}" == "http/1.1" ]]; then
        echoContent yellow "1.切换alpn h2 首位"
    elif [[ "${currentAlpn}" == "h2" ]]; then
        echoContent yellow "1.切换alpn http/1.1 首位"
    else
        echoContent red '不符合'
    fi

    echoContent red "=============================================================="

    read -r -p "请选择:" selectSwitchAlpnType
    if [[ "${selectSwitchAlpnType}" == "1" && "${currentAlpn}" == "http/1.1" ]]; then

        local frontingTypeJSON
        frontingTypeJSON=$(jq -r ".inbounds[0].streamSettings.tlsSettings.alpn = [\"h2\",\"http/1.1\"]" ${configPath}${frontingType}.json)
        echo "${frontingTypeJSON}" | jq . >${configPath}${frontingType}.json

    elif [[ "${selectSwitchAlpnType}" == "1" && "${currentAlpn}" == "h2" ]]; then
        local frontingTypeJSON
        frontingTypeJSON=$(jq -r ".inbounds[0].streamSettings.tlsSettings.alpn =[\"http/1.1\",\"h2\"]" ${configPath}${frontingType}.json)
        echo "${frontingTypeJSON}" | jq . >${configPath}${frontingType}.json
    else
        echoContent red " ---> 选择错误"
        exit 0
    fi
    reloadCore
}

# 初始化realityKey
initRealityKey() {
    echoContent skyBlue "\n========================== 生成key ==========================\n"
    if [[ -n "${currentRealityPublicKey}" ]]; then
        read -r -p "读取到上次安装记录，是否使用上次安装时的PublicKey/PrivateKey ？[y/n]:" historyKeyStatus
        if [[ "${historyKeyStatus}" == "y" ]]; then
            realityPrivateKey=${currentRealityPrivateKey}
            realityPublicKey=${currentRealityPublicKey}
        fi
    fi
    if [[ -z "${realityPrivateKey}" ]]; then
        realityX25519Key=$(/etc/v2ray-agent/xray/xray x25519)
        realityPrivateKey=$(echo "${realityX25519Key}" | head -1 | awk '{print $3}')
        realityPublicKey=$(echo "${realityX25519Key}" | tail -n 1 | awk '{print $3}')
    fi
    echoContent green "\n privateKey:${realityPrivateKey}"
    echoContent green "\n publicKey:${realityPublicKey}"
}
# 检查reality域名是否符合
checkRealityDest() {
    local traceResult=
    traceResult=$(curl -s "https://$(echo "${realityDestDomain}" | cut -d ':' -f 1)/cdn-cgi/trace" | grep "visit_scheme=https")
    if [[ -n "${traceResult}" ]]; then
        echoContent red "\n ---> 检测到使用的域名，托管在cloudflare并开启了代理，使用此类型域名可能导致VPS流量被其他人使用[不建议使用]\n"
        read -r -p "是否继续 ？[y/n]" setRealityDestStatus
        if [[ "${setRealityDestStatus}" != 'y' ]]; then
            exit 0
        fi
        echoContent yellow "\n ---> 忽略风险，继续使用"
    fi
}

# 初始化reality dest
initRealityDest() {
    if [[ -n "${domain}" ]]; then
        realityDestDomain=${domain}:${port}
    else
        local realityDestDomainList=
        realityDestDomainList="gateway.icloud.com,itunes.apple.com,download-installer.cdn.mozilla.net,addons.mozilla.org,www.lovelive-anime.jp,swdist.apple.com,swcdn.apple.com,updates.cdn-apple.com,mensura.cdn-apple.com,osxapps.itunes.apple.com,aod.itunes.apple.com,s0.awsstatic.com,d1.awsstatic.com,images-na.ssl-images-amazon.com,m.media-amazon.com,player.live-video.net,www.yahoo.com,one-piece.com,lol.secure.dyn.riotcdn.net,addons.mozilla.org,gateway.icloud.com,itunes.apple.com,download-installer.cdn.mozilla.net,addons.mozilla.org,www.lovelive-anime.jp,swdist.apple.com,swcdn.apple.com,updates.cdn-apple.com,mensura.cdn-apple.com,osxapps.itunes.apple.com,aod.itunes.apple.com,s0.awsstatic.com,d1.awsstatic.com,images-na.ssl-images-amazon.com,m.media-amazon.com,player.live-video.net"

        echoContent skyBlue "\n===== 生成配置回落的域名 例如:[addons.mozilla.org:443] ======\n"
        echoContent green "回落域名列表：https://www.v2ray-agent.com/archives/1680104902581#heading-8\n"
        read -r -p "请输入[回车]使用随机:" realityDestDomain
        if [[ -z "${realityDestDomain}" ]]; then
            local randomNum=
            randomNum=$((RANDOM % 24 + 1))
            realityDestDomain=$(echo "${realityDestDomainList}" | awk -F ',' -v randomNum="$randomNum" '{print $randomNum":443"}')
        fi
        if ! echo "${realityDestDomain}" | grep -q ":"; then
            echoContent red "\n ---> 域名不合规范，请重新输入"
            initRealityDest
        else
            checkRealityDest
            echoContent yellow "\n ---> 回落域名: ${realityDestDomain}"
        fi
    fi
}
# 初始化客户端可用的ServersName
initRealityClientServersName() {
    if [[ -n "${domain}" ]]; then
        realityServerNames=\"${domain}\"
    elif [[ -n "${realityDestDomain}" ]]; then
        realityServerNames=$(echo "${realityDestDomain}" | cut -d ":" -f 1)

        realityServerNames=\"${realityServerNames//,/\",\"}\"
    else
        echoContent skyBlue "\n================ 配置客户端可用的serverNames ================\n"
        echoContent yellow "#注意事项"
        echoContent green "客户端可用的serverNames 列表：https://www.v2ray-agent.com/archives/1680104902581#heading-8\n"
        echoContent yellow "录入示例:addons.mozilla.org\n"
        read -r -p "请输入[回车]使用随机:" realityServerNames
        if [[ -z "${realityServerNames}" ]]; then
            realityServerNames=\"addons.mozilla.org\"
        else
            realityServerNames=\"${realityServerNames//,/\",\"}\"
        fi
    fi

    echoContent yellow "\n ---> 客户端可用域名: ${realityServerNames}\n"
}
# 初始化reality端口
initRealityPort() {
    if [[ -n "${currentRealityPort}" ]]; then
        read -r -p "读取到上次安装记录，是否使用上次安装时的端口 ？[y/n]:" historyRealityPortStatus
        if [[ "${historyRealityPortStatus}" == "y" ]]; then
            realityPort=${currentRealityPort}
        fi
    fi
    # todo 读取到VLESS_TLS_Vision端口，提示是否使用使用。这里可能有歧义
    if [[ -z "${realityPort}" ]]; then
        if [[ -n "${port}" ]]; then
            read -r -p "是否使用TLS+Vision端口 ？[y/n]:" realityPortTLSVisionStatus
            if [[ "${realityPortTLSVisionStatus}" == "y" ]]; then
                realityPort=${port}
            fi
        fi
        if [[ -z "${realityPort}" ]]; then
            echoContent yellow "请输入端口[回车随机10000-30000]"
            read -r -p "端口:" realityPort
            if [[ -z "${realityPort}" ]]; then
                realityPort=$((RANDOM % 20001 + 10000))
            fi
        fi
        if [[ -n "${realityPort}" && "${currentRealityPort}" == "${realityPort}" ]]; then
            handleXray stop
        else
            checkPort "${realityPort}"
            #            if [[ -n "${port}" && "${port}" == "${realityPort}" ]]; then
            #                echoContent red "  端口不可与Vision重复--->"
            #                echo
            #                realityPort=
            #            fi
        fi
    fi
    if [[ -z "${realityPort}" ]]; then
        initRealityPort
    else
        allowPort "${realityPort}"
        echoContent yellow "\n ---> 端口: ${realityPort}"
    fi

}
# 初始化 reality 配置
initXrayRealityConfig() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 初始化 Xray-core reality配置"
    initRealityPort
    initRealityKey
    initRealityDest
    initRealityClientServersName
}
# 修改reality域名端口等信息
updateXrayRealityConfig() {

    local realityVisionResult
    realityVisionResult=$(jq -r ".inbounds[0].port = ${realityPort}" ${configPath}07_VLESS_vision_reality_inbounds.json)
    realityVisionResult=$(echo "${realityVisionResult}" | jq -r ".inbounds[0].streamSettings.realitySettings.dest = \"${realityDestDomain}\"")
    realityVisionResult=$(echo "${realityVisionResult}" | jq -r ".inbounds[0].streamSettings.realitySettings.serverNames = [${realityServerNames}]")
    realityVisionResult=$(echo "${realityVisionResult}" | jq -r ".inbounds[0].streamSettings.realitySettings.privateKey = \"${realityPrivateKey}\"")
    realityVisionResult=$(echo "${realityVisionResult}" | jq -r ".inbounds[0].streamSettings.realitySettings.publicKey = \"${realityPublicKey}\"")
    echo "${realityVisionResult}" | jq . >${configPath}07_VLESS_vision_reality_inbounds.json
    reloadCore
    echoContent green " ---> 修改完成"
}
# xray-core Reality 安装
xrayCoreRealityInstall() {
    totalProgress=13
    installTools 2
    # 下载核心
    #    prereleaseStatus=true
    #    updateXray
    installXray 3 true
    # 生成 privateKey、配置回落地址、配置serverNames
    installXrayService 6
    # initXrayRealityConfig 5
    # 初始化配置
    initXrayConfig custom 7
    handleXray stop
    cleanUp v2rayClean
    sleep 2
    # 启动
    handleXray start
    # 生成账号
    showAccounts 8
}
# reality管理
manageReality() {

    echoContent skyBlue "\n进度  1/1 : reality管理"
    echoContent red "\n=============================================================="

    if [[ -n "${realityStatus}" ]]; then
        echoContent yellow "1.重新安装"
        echoContent yellow "2.卸载"
        echoContent yellow "3.更换配置"
    else
        echoContent yellow "1.安装"
    fi
    echoContent red "=============================================================="
    read -r -p "请选择:" installRealityStatus

    if [[ "${installRealityStatus}" == "1" ]]; then
        selectCustomInstallType="7"
        xrayCoreRealityInstall
    elif [[ "${installRealityStatus}" == "2" ]]; then
        unInstallXrayCoreReality
    elif [[ "${installRealityStatus}" == "3" ]]; then
        initXrayRealityConfig 1
        updateXrayRealityConfig
    fi
}

# hysteria管理
manageHysteria() {
    echoContent skyBlue "\n进度  1/1 : Hysteria管理"
    echoContent red "\n=============================================================="
    local hysteriaStatus=
    if [[ -n "${hysteriaConfigPath}" ]]; then
        echoContent yellow "1.重新安装"
        echoContent yellow "2.卸载"
        echoContent yellow "3.端口跳跃管理"
        echoContent yellow "4.core管理"
        echoContent yellow "5.查看日志"
        hysteriaStatus=true
    else
        echoContent yellow "1.安装"
    fi

    echoContent red "=============================================================="
    read -r -p "请选择:" installHysteriaStatus
    if [[ "${installHysteriaStatus}" == "1" ]]; then
        hysteriaCoreInstall
    elif [[ "${installHysteriaStatus}" == "2" && "${hysteriaStatus}" == "true" ]]; then
        unInstallHysteriaCore
    elif [[ "${installHysteriaStatus}" == "3" && "${hysteriaStatus}" == "true" ]]; then
        hysteriaPortHoppingMenu
    elif [[ "${installHysteriaStatus}" == "4" && "${hysteriaStatus}" == "true" ]]; then
        hysteriaVersionManageMenu 1
    elif [[ "${installHysteriaStatus}" == "5" && "${hysteriaStatus}" == "true" ]]; then
        journalctl -fu hysteria
    fi
}

# tuic管理
manageTuic() {
    echoContent skyBlue "\n进度  1/1 : Tuic管理"
    echoContent red "\n=============================================================="
    local tuicStatus=
    if [[ -n "${tuicConfigPath}" ]]; then
        echoContent yellow "1.重新安装"
        echoContent yellow "2.卸载"
        echoContent yellow "3.core管理"
        echoContent yellow "4.查看日志"
        tuicStatus=true
    else
        echoContent yellow "1.安装"
    fi

    echoContent red "=============================================================="
    read -r -p "请选择:" installTuicStatus
    if [[ "${installTuicStatus}" == "1" ]]; then
        tuicCoreInstall
    elif [[ "${installTuicStatus}" == "2" && "${tuicStatus}" == "true" ]]; then
        unInstallTuicCore
    elif [[ "${installTuicStatus}" == "3" && "${tuicStatus}" == "true" ]]; then
        tuicVersionManageMenu 1
    elif [[ "${installTuicStatus}" == "4" && "${tuicStatus}" == "true" ]]; then
        journalctl -fu tuic
    fi
}
# hysteria版本管理
hysteriaVersionManageMenu() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : Hysteria版本管理"
    if [[ ! -d "/etc/v2ray-agent/hysteria/" ]]; then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0
    fi
    echoContent red "\n=============================================================="
    echoContent yellow "1.升级Hysteria"
    echoContent yellow "2.关闭Hysteria"
    echoContent yellow "3.打开Hysteria"
    echoContent yellow "4.重启Hysteria"
    echoContent red "=============================================================="

    read -r -p "请选择:" selectHysteriaType
    if [[ "${selectHysteriaType}" == "1" ]]; then
        installHysteria 1
        handleHysteria start
    elif [[ "${selectHysteriaType}" == "2" ]]; then
        handleHysteria stop
    elif [[ "${selectHysteriaType}" == "3" ]]; then
        handleHysteria start
    elif [[ "${selectHysteriaType}" == "4" ]]; then
        handleHysteria stop
        handleHysteria start
    fi
}

# Tuic版本管理
tuicVersionManageMenu() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : Tuic版本管理"
    if [[ ! -d "/etc/v2ray-agent/tuic/" ]]; then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0
    fi
    echoContent red "\n=============================================================="
    echoContent yellow "1.升级Tuic"
    echoContent yellow "2.关闭Tuic"
    echoContent yellow "3.打开Tuic"
    echoContent yellow "4.重启Tuic"
    echoContent red "=============================================================="

    read -r -p "请选择:" selectTuicType
    if [[ "${selectTuicType}" == "1" ]]; then
        installTuic 1
        handleTuic start
    elif [[ "${selectTuicType}" == "2" ]]; then
        handleTuic stop
    elif [[ "${selectTuicType}" == "3" ]]; then
        handleTuic start
    elif [[ "${selectTuicType}" == "4" ]]; then
        handleTuic stop
        handleTuic start
    fi
}
# 主菜单
menu() {
    cd "$HOME" || exit
    echoContent red "\n=============================================================="
    echoContent green "作者：mack-a"
    echoContent green "当前版本：v2.10.13"
    echoContent green "Github：https://github.com/mack-a/v2ray-agent"
    echoContent green "描述：八合一共存脚本\c"
    showInstallStatus
    checkWgetShowProgress
    echoContent red "\n=========================== 推广区============================"
    echoContent red "                                              "
    echoContent green "推广请联系TG：@mackaff\n"
    echoContent green "VPS选购攻略：https://www.v2ray-agent.com/archives/1679975663984"
    echoContent green "年付10美金低价VPS AS4837：https://www.v2ray-agent.com/archives/racknerdtao-can-zheng-li-nian-fu-10mei-yuan"
    echoContent red "=============================================================="
    if [[ -n "${coreInstallType}" ]]; then
        echoContent yellow "1.重新安装"
    else
        echoContent yellow "1.安装"
    fi

    echoContent yellow "2.任意组合安装"
    if echo ${currentInstallProtocolType} | grep -q trojan; then
        echoContent yellow "3.切换VLESS[XTLS]"
    elif echo ${currentInstallProtocolType} | grep -q 0; then
        echoContent yellow "3.切换Trojan[XTLS]"
    fi

    echoContent yellow "4.Hysteria管理"
    echoContent yellow "5.REALITY管理"
    echoContent yellow "6.Tuic管理"
    echoContent skyBlue "-------------------------工具管理-----------------------------"
    echoContent yellow "7.账号管理"
    echoContent yellow "8.更换伪装站"
    echoContent yellow "9.更新证书"
    echoContent yellow "10.更换CDN节点"
    echoContent yellow "11.分流工具"
    echoContent yellow "12.添加新端口"
    echoContent yellow "13.BT下载管理"
    echoContent yellow "14.切换alpn"
    echoContent yellow "15.域名黑名单"
    echoContent skyBlue "-------------------------版本管理-----------------------------"
    echoContent yellow "16.core管理"
    echoContent yellow "17.更新脚本"
    echoContent yellow "18.安装BBR、DD脚本"
    echoContent skyBlue "-------------------------脚本管理-----------------------------"
    echoContent yellow "19.查看日志"
    echoContent yellow "20.卸载脚本"
    echoContent red "=============================================================="
    mkdirTools
    aliasInstall
    read -r -p "请选择:" selectInstallType
    case ${selectInstallType} in
    1)
        selectCoreInstall
        ;;
    2)
        selectCoreInstall
        ;;
    3)
        initXrayFrontingConfig 1
        ;;
    4)
        manageHysteria
        ;;
    5)
        manageReality 1
        ;;
    6)
        manageTuic
        ;;
    7)
        manageAccount 1
        ;;
    8)
        updateNginxBlog 1
        ;;
    9)
        renewalTLS 1
        ;;
    10)
        updateV2RayCDN 1
        ;;
    11)
        routingToolsMenu 1
        ;;
    12)
        addCorePort 1
        ;;
    13)
        btTools 1
        ;;
    14)
        switchAlpn 1
        ;;
    15)
        blacklist 1
        ;;
    16)
        coreVersionManageMenu 1
        ;;
    17)
        updateV2RayAgent 1
        ;;
    18)
        bbrInstall
        ;;
    19)
        checkLog 1
        ;;
    20)
        unInstall 1
        ;;
    esac
}
cronFunction
menu
