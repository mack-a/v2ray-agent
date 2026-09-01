#!/usr/bin/env bash
# -------------------------------------------------------------
# Detection area
#------------------------------------------------ ----------
# Check system
export LANG=en_US.UTF-8

echoContent() {
    case $1 in
    # red
    "red")
        # shellcheck disable=SC2154
        # shellcheck disable=SC2154
        ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        # sky blue
    "skyBlue")
        ${echoType} "\033[1;36m${printN}$2 \033[0m"
        ;;
        # green
    "green")
        ${echoType} "\033[32m${printN}$2 \033[0m"
        ;;
        # White
    "white")
        ${echoType} "\033[37m${printN}$2 \033[0m"
        ;;
    "magenta")
        ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        #yellow
    "yellow")
        ${echoType} "\033[33m${printN}$2 \033[0m"
        ;;
    esac
}
# Check SELinux status
checkCentosSELinux() {
    if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" == "Enforcing" ]; then
        echoContent yellow "# Notes"
        echoContent yellow "It is detected that SELinux is turned on. Please turn it off manually. The tutorial is as follows"
        echoContent yellow "https://www.v2ray-agent.com/archives/1684115970026#centos-%E5%85%B3%E9%97%ADselinux"
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
        #        upgrade="yum update -y --skip-broken"
        checkCentosSELinux
    elif { [[ -f "/etc/issue" ]] && grep -qi "Alpine" /etc/issue; } || { [[ -f "/proc/version" ]] && grep -qi "Alpine" /proc/version; }; then
        release="alpine"
        installType='apk add'
        upgrade="apk update"
        removeType='apk del'
        nginxConfigPath=/etc/nginx/http.d/
    elif { [[ -f "/etc/issue" ]] && grep -qi "debian" /etc/issue; } || { [[ -f "/proc/version" ]] && grep -qi "debian" /proc/version; } || { [[ -f "/etc/os-release" ]] && grep -qi "ID=debian" /etc/issue; }; then
        release="debian"
        installType='apt -y install'
        upgrade="apt update"
        updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
        removeType='apt -y autoremove'

    elif { [[ -f "/etc/issue" ]] && grep -qi "ubuntu" /etc/issue; } || { [[ -f "/proc/version" ]] && grep -qi "ubuntu" /proc/version; }; then
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
        echoContent red "\nThis script does not support this system, please feedback the following log to the developer\n"
        echoContent yellow "$(cat /etc/issue)"
        echoContent yellow "$(cat /proc/version)"
        exit 0
    fi
}

# Check CPU provider
checkCPUVendor() {
    if [[ -n $(which uname) ]]; then
        if [[ "$(uname)" == "Linux" ]]; then
            case "$(uname -m)" in
            'amd64' | 'x86_64')
                xrayCoreCPUVendor="Xray-linux-64"
                #                v2rayCoreCPUVendor="v2ray-linux-64"
                warpRegCoreCPUVendor="main-linux-amd64"
                singBoxCoreCPUVendor="-linux-amd64"
                ;;
            'armv8' | 'aarch64')
                cpuVendor="arm"
                xrayCoreCPUVendor="Xray-linux-arm64-v8a"
                #                v2rayCoreCPUVendor="v2ray-linux-arm64-v8a"
                warpRegCoreCPUVendor="main-linux-arm64"
                singBoxCoreCPUVendor="-linux-arm64"
                ;;
            *)
                echo "This CPU architecture is not supported --->"
                exit 1
                ;;
            esac
        fi
    else
        echoContent red "This CPU architecture cannot be recognized, the default is amd64, x86_64--->"
        xrayCoreCPUVendor="Xray-linux-64"
        #        v2rayCoreCPUVendor="v2ray-linux-64"
    fi
}

#Initialize global variables
initVar() {
    installType='yum -y install'
    removeType='yum -y remove'
    upgrade="yum -y update"
    echoType='echo -e'
    #    sudoCMD=""

    #CPU version supported by the core
    xrayCoreCPUVendor=""
    warpRegCoreCPUVendor=""
    cpuVendor=""

    # domain name
    domain=
    # Total installation progress
    totalProgress=1

    #1.xray-core installation
    #2.v2ray-core installation
    #3.v2ray-core[xtls] installation
    coreInstallType=

    # coreInstallPath=

    # v2ctl Path
    # Core installation path
    # coreInstallPath=

    # v2ctl Path
    ctlPath=
    # v2rayAgentInstallType=

    #1.Install all
    #2.Personalized installation
    # v2rayAgentInstallType=

    # Current personalized installation method 01234
    currentInstallProtocolType=

    # The order of the current alpn
    currentAlpn=

    # Prefix type
    frontingType=

    # Selected personalized installation method
    selectCustomInstallType=

    # Path to v2ray-core, xray-core configuration files
    configPath=

    # xray-core reality state
    realityStatus=

    singBoxConfigPath=


    singBoxVLESSVisionPort=
    singBoxVLESSRealityVisionPort=
    singBoxVLESSRealityGRPCPort=
    singBoxHysteria2Port=
    singBoxTrojanPort=
    singBoxTuicPort=
    singBoxNaivePort=
    singBoxVMessWSPort=
    singBoxVLESSWSPort=
    singBoxVMessHTTPUpgradePort=

    subscribePort=

    subscribeType=

    # sing-box reality serverName publicKey
    singBoxVLESSRealityGRPCServerName=
    singBoxVLESSRealityVisionServerName=
    singBoxVLESSRealityPublicKey=

    # xray-core reality serverName publicKey
    xrayVLESSRealityServerName=
    xrayVLESSRealityPort=
    xrayVLESSRealityVisionPort=
    xrayVLESSRealityXHTTPServerName=
    xrayVLESSRealityXHTTPort=
    #    xrayVLESSRealityPublicKey=

    #    interfaceName=
    # interfaceName=
    # Port hopping
    portHoppingStart=
    portHoppingEnd=
    portHopping=

    hysteria2PortHoppingStart=
    hysteria2PortHoppingEnd=
    hysteria2PortHopping=

    #    tuicPortHoppingStart=
    #    tuicPortHoppingEnd=
    #    tuicPortHopping=

    #    tuicConfigPath=
    tuicAlgorithm=
    tuicPort=

    # Path to configuration file
    currentPath=

    #Configuration file host
    currentHost=

    #The core type selected during installation
    selectCoreType=

    #    v2rayCoreVersion=

    # Random path
    customPath=

    # centos version
    # centos version
    centosVersion=

    # UUID
    #UUID
    currentUUID=

    # clients
    #clients
    currentClients=

    # previousClients
    #    previousClients=

    localIP=

    # Scheduled task execution task name RenewTLS-update certificate UpdateGeo-update geo file
    cronName=$1

    #Number of attempts after tls installation failure
    installTLSCount=

    #	BTPanelStatus=
    #BTPanel status
    # 	BTPanelStatus=
    # Pagoda domain name
    btDomain=
    # nginx configuration file path
    nginxConfigPath=/etc/nginx/conf.d/
    nginxStaticPath=/usr/share/nginx/html/

    # Is it a preview version?
    prereleaseStatus=false

    # ssl type
    sslType=
    # SSL CF API Token
    cfAPIToken=

    #sslmail
    sslEmail=

    # Check the number of days
    sslRenewalDays=90

    #    dnsSSLStatus=

    # dns tls domain
    # dns tls domain
    dnsTLSDomain=
    ipType=

    #    installDNSACMEStatus=

    # Custom port
    customPort=

    #hysteriaport
    hysteriaPort=

    #    hysteriaProtocol=

    #    hysteriaLag=

    hysteria2ClientDownloadSpeed=

    hysteria2ClientUploadSpeed=

    # Reality
    #Reality
    realityPrivateKey=
    realityServerName=
    realityDestDomain=

    #    isPortOpen=
    #    wildcardDomainStatus=
    #    nginxIPort=

    # wget show progress
    #Port status
    # isPortOpen=
    # Wildcard domain name status
    # wildcardDomainStatus=
    # Port checked by nginx
    #nginxIPort=

    # wget show progress
    wgetShowProgressStatus=

    # warp
    #warp
    reservedWarpReg=
    publicKeyWarpReg=
    addressWarpReg=
    secretKeyWarpReg=

    lastInstallationConfig=

}

# Read tls certificate details
readAcmeTLS() {
    local readAcmeDomain=
    if [[ -n "${currentHost}" ]]; then
        readAcmeDomain="${currentHost}"
    fi

    if [[ -n "${domain}" ]]; then
        readAcmeDomain="${domain}"
    fi

    dnsTLSDomain=$(echo "${readAcmeDomain}" | awk -F "." '{$1="";print $0}' | sed 's/^[[:space:]]*//' | sed 's/ /./g')
    if [[ -d "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc" && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.key" && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.cer" ]]; then
        installedDNSAPIStatus=true
    fi
}

# Read the default custom port
readCustomPort() {
    if [[ -n "${configPath}" && -z "${realityStatus}" && "${coreInstallType}" == "1" ]]; then
        local port=
        port=$(jq -r .inbounds[0].port "${configPath}${frontingType}.json")
        if [[ "${port}" != "443" ]]; then
            customPort=${port}
        fi
    fi
}

readNginxSubscribe() {
    subscribeType="https"
    if [[ -f "${nginxConfigPath}subscribe.conf" ]]; then
        if grep -q "sing-box" "${nginxConfigPath}subscribe.conf"; then
            subscribePort=$(grep "listen" "${nginxConfigPath}subscribe.conf" | awk '{print $2}')
            subscribeDomain=$(grep "server_name" "${nginxConfigPath}subscribe.conf" | awk '{print $2}')
            subscribeDomain=${subscribeDomain//;/}
            if [[ -n "${currentHost}" && "${subscribeDomain}" != "${currentHost}" ]]; then
                subscribePort=
                subscribeType=
            else
                if ! grep "listen" "${nginxConfigPath}subscribe.conf" | grep -q "ssl"; then
                    subscribeType="http"
                fi
            fi

        fi
    fi
}

# Detect installation method
readInstallType() {
    coreInstallType=
    configPath=
    singBoxConfigPath=

    #1.Detect the installation directory
    if [[ -d "/etc/v2ray-agent" ]]; then
        if [[ -f "/etc/v2ray-agent/xray/xray" ]]; then
            if [[ -d "/etc/v2ray-agent/xray/conf" ]] && [[ -f "/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json" || -f "/etc/v2ray-agent/xray/conf/02_trojan_TCP_inbounds.json" || -f "/etc/v2ray-agent/xray/conf/07_VLESS_vision_reality_inbounds.json" || -f "/etc/v2ray-agent/xray/conf/12_VLESS_XHTTP_inbounds.json" ]]; then
                # xray-core
                #xray-core
                configPath=/etc/v2ray-agent/xray/conf/
                ctlPath=/etc/v2ray-agent/xray/xray
                coreInstallType=1

                if [[ -f "${configPath}07_VLESS_vision_reality_inbounds.json" ]]; then
                    realityStatus=7
                fi
                if [[ -f "${configPath}12_VLESS_XHTTP_inbounds.json" ]]; then
                    realityStatus=12
                fi
                if [[ -f "/etc/v2ray-agent/sing-box/sing-box" ]] && [[ -f "/etc/v2ray-agent/sing-box/conf/config/06_hysteria2_inbounds.json" || -f "/etc/v2ray-agent/sing-box/conf/config/09_tuic_inbounds.json" || -f "/etc/v2ray-agent/sing-box/conf/config/20_socks5_inbounds.json" ]]; then
                    singBoxConfigPath=/etc/v2ray-agent/sing-box/conf/config/
                fi
            fi
        elif [[ -f "/etc/v2ray-agent/sing-box/sing-box" && -f "/etc/v2ray-agent/sing-box/conf/config.json" ]]; then
            ctlPath=/etc/v2ray-agent/sing-box/sing-box
            coreInstallType=2
            configPath=/etc/v2ray-agent/sing-box/conf/config/
            singBoxConfigPath=/etc/v2ray-agent/sing-box/conf/config/
        fi
    fi
}

#Read protocol type
readInstallProtocolType() {
    currentInstallProtocolType=
    frontingType=

    xrayVLESSRealityPort=
    xrayVLESSRealityVisionPort=
    xrayVLESSRealityServerName=

    xrayVLESSRealityXHTTPort=
    xrayVLESSRealityXHTTPServerName=

    #    currentRealityXHTTPPrivateKey=
    currentRealityXHTTPPublicKey=

    currentRealityPrivateKey=
    currentRealityPublicKey=

    currentRealityMldsa65Seed=
    currentRealityMldsa65Verify=

    singBoxVLESSVisionPort=
    singBoxHysteria2Port=
    singBoxTrojanPort=

    frontingTypeReality=
    singBoxVLESSRealityVisionPort=
    singBoxVLESSRealityVisionServerName=
    singBoxVLESSRealityGRPCPort=
    singBoxVLESSRealityGRPCServerName=
    singBoxAnyTLSPort=
    singBoxTuicPort=
    singBoxNaivePort=
    singBoxVMessWSPort=
    singBoxSocks5Port=

    while read -r row; do
        if echo "${row}" | grep -q VLESS_TCP_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}0,"
            frontingType=02_VLESS_TCP_inbounds
            if [[ "${coreInstallType}" == "2" ]]; then
                singBoxVLESSVisionPort=$(jq .inbounds[0].listen_port "${row}.json")
            fi
        fi
        if echo "${row}" | grep -q VLESS_WS_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}1,"
            if [[ "${coreInstallType}" == "2" ]]; then
                frontingType=03_VLESS_WS_inbounds
                singBoxVLESSWSPort=$(jq .inbounds[0].listen_port "${row}.json")
            fi
        fi
        if echo "${row}" | grep -q VLESS_XHTTP_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}12,"
            xrayVLESSRealityXHTTPort=$(jq -r .inbounds[0].port "${row}.json")

            xrayVLESSRealityXHTTPServerName=$(jq -r .inbounds[0].streamSettings.realitySettings.serverNames[0] "${row}.json")

            currentRealityXHTTPPublicKey=$(jq -r .inbounds[0].streamSettings.realitySettings.publicKey "${row}.json")
            currentRealityMldsa65Seed=$(jq -r '.inbounds[0].streamSettings.realitySettings.mldsa65Seed // empty' "${row}.json")
            currentRealityMldsa65Verify=$(jq -r '.inbounds[0].streamSettings.realitySettings.mldsa65Verify // empty' "${row}.json")
            #            currentRealityXHTTPPrivateKey=$(jq -r .inbounds[0].streamSettings.realitySettings.privateKey "${row}.json")

            #            if [[ "${coreInstallType}" == "2" ]]; then
            #                frontingType=03_VLESS_WS_inbounds
            #                singBoxVLESSWSPort=$(jq .inbounds[0].listen_port "${row}.json")
            #            fi
        fi

        if echo "${row}" | grep -q trojan_gRPC_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}2,"
        fi
        if echo "${row}" | grep -q VMess_WS_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}3,"
            if [[ "${coreInstallType}" == "2" ]]; then
                frontingType=05_VMess_WS_inbounds
                singBoxVMessWSPort=$(jq .inbounds[0].listen_port "${row}.json")
            fi
        fi
        if echo "${row}" | grep -q trojan_TCP_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}4,"
            if [[ "${coreInstallType}" == "2" ]]; then
                frontingType=04_trojan_TCP_inbounds
                singBoxTrojanPort=$(jq .inbounds[0].listen_port "${row}.json")
            fi
        fi
        if echo "${row}" | grep -q VLESS_gRPC_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}5,"
        fi
        if echo "${row}" | grep -q hysteria2_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}6,"
            if [[ "${coreInstallType}" == "2" ]]; then
                frontingType=06_hysteria2_inbounds
                singBoxHysteria2Port=$(jq .inbounds[0].listen_port "${row}.json")
            fi
        fi
        if echo "${row}" | grep -q VLESS_vision_reality_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}7,"
            if [[ "${coreInstallType}" == "1" ]]; then
                xrayVLESSRealityServerName=$(jq -r .inbounds[1].streamSettings.realitySettings.serverNames[0] "${row}.json")
                realityServerName=${xrayVLESSRealityServerName}
                xrayVLESSRealityPort=$(jq -r .inbounds[0].port "${row}.json")

                realityDomainPort=$(jq -r .inbounds[1].streamSettings.realitySettings.target "${row}.json" | awk -F '[:]' '{print $2}')

                currentRealityPublicKey=$(jq -r .inbounds[1].streamSettings.realitySettings.publicKey "${row}.json")
                currentRealityPrivateKey=$(jq -r .inbounds[1].streamSettings.realitySettings.privateKey "${row}.json")

                currentRealityMldsa65Seed=$(jq -r '.inbounds[1].streamSettings.realitySettings.mldsa65Seed // empty' "${row}.json")
                currentRealityMldsa65Verify=$(jq -r '.inbounds[1].streamSettings.realitySettings.mldsa65Verify // empty' "${row}.json")

                frontingTypeReality=07_VLESS_vision_reality_inbounds

            elif [[ "${coreInstallType}" == "2" ]]; then
                frontingTypeReality=07_VLESS_vision_reality_inbounds
                singBoxVLESSRealityVisionPort=$(jq -r .inbounds[0].listen_port "${row}.json")
                singBoxVLESSRealityVisionServerName=$(jq -r .inbounds[0].tls.server_name "${row}.json")
                realityDomainPort=$(jq -r .inbounds[0].tls.reality.handshake.server_port "${row}.json")

                realityServerName=${singBoxVLESSRealityVisionServerName}
                if [[ -f "${configPath}reality_key" ]]; then
                    singBoxVLESSRealityPublicKey=$(grep "publicKey" <"${configPath}reality_key" | awk -F "[:]" '{print $2}')

                    currentRealityPrivateKey=$(jq -r .inbounds[0].tls.reality.private_key "${row}.json")
                    currentRealityPublicKey=$(grep "publicKey" <"${configPath}reality_key" | awk -F "[:]" '{print $2}')
                fi
            fi
        fi
        if echo "${row}" | grep -q VLESS_vision_gRPC_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}8,"
            if [[ "${coreInstallType}" == "2" ]]; then
                frontingTypeReality=08_VLESS_vision_gRPC_inbounds
                singBoxVLESSRealityGRPCPort=$(jq -r .inbounds[0].listen_port "${row}.json")
                singBoxVLESSRealityGRPCServerName=$(jq -r .inbounds[0].tls.server_name "${row}.json")
                if [[ -f "${configPath}reality_key" ]]; then
                    singBoxVLESSRealityPublicKey=$(grep "publicKey" <"${configPath}reality_key" | awk -F "[:]" '{print $2}')
                fi
            fi
        fi
        if echo "${row}" | grep -q tuic_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}9,"
            if [[ "${coreInstallType}" == "2" ]]; then
                frontingType=09_tuic_inbounds
                singBoxTuicPort=$(jq .inbounds[0].listen_port "${row}.json")
            fi
        fi
        if echo "${row}" | grep -q naive_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}10,"
            if [[ "${coreInstallType}" == "2" ]]; then
                frontingType=10_naive_inbounds
                singBoxNaivePort=$(jq .inbounds[0].listen_port "${row}.json")
            fi
        fi
        if echo "${row}" | grep -q anytls_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}13,"
            if [[ "${coreInstallType}" == "2" ]]; then
                frontingType=13_anytls_inbounds
                singBoxAnyTLSPort=$(jq .inbounds[0].listen_port "${row}.json")
            fi
        fi
        if echo "${row}" | grep -q VMess_HTTPUpgrade_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}11,"
            if [[ "${coreInstallType}" == "2" ]]; then
                frontingType=11_VMess_HTTPUpgrade_inbounds
                singBoxVMessHTTPUpgradePort=$(grep 'listen' <${nginxConfigPath}sing_box_VMess_HTTPUpgrade.conf | awk '{print $2}')
            fi
        fi
        if echo "${row}" | grep -q socks5_inbounds; then
            currentInstallProtocolType="${currentInstallProtocolType}20,"
            singBoxSocks5Port=$(jq .inbounds[0].listen_port "${row}.json")
        fi

    done < <(find ${configPath} -name "*inbounds.json" | sort | awk -F "[.]" '{print $1}')

    if [[ "${coreInstallType}" == "1" && -n "${singBoxConfigPath}" ]]; then
        if [[ -f "${singBoxConfigPath}06_hysteria2_inbounds.json" ]]; then
            currentInstallProtocolType="${currentInstallProtocolType}6,"
            singBoxHysteria2Port=$(jq .inbounds[0].listen_port "${singBoxConfigPath}06_hysteria2_inbounds.json")
        fi
        if [[ -f "${singBoxConfigPath}09_tuic_inbounds.json" ]]; then
            currentInstallProtocolType="${currentInstallProtocolType}9,"
            singBoxTuicPort=$(jq .inbounds[0].listen_port "${singBoxConfigPath}09_tuic_inbounds.json")
        fi
    fi
    if [[ "${currentInstallProtocolType:0:1}" != "," ]]; then
        currentInstallProtocolType=",${currentInstallProtocolType}"
    fi
}

# Check whether pagoda is installed
checkBTPanel() {
    if [[ -n $(pgrep -f "BT-Panel") ]]; then
        # Read domain name
        if [[ -d '/www/server/panel/vhost/cert/' && -n $(find /www/server/panel/vhost/cert/*/fullchain.pem) ]]; then
            if [[ -z "${currentHost}" ]]; then
                echoContent skyBlue "\nRead pagoda configuration\n"

                find /www/server/panel/vhost/cert/*/fullchain.pem | awk -F "[/]" '{print $7}' | awk '{print NR""":"$0}'

                read -r -p "Please enter the number to select:" selectBTDomain
            else
                selectBTDomain=$(find /www/server/panel/vhost/cert/*/fullchain.pem | awk -F "[/]" '{print $7}' | awk '{print NR""":"$0}' | grep "${currentHost}" | cut -d ":" -f 1)
            fi

            if [[ -n "${selectBTDomain}" ]]; then
                btDomain=$(find /www/server/panel/vhost/cert/*/fullchain.pem | awk -F "[/]" '{print $7}' | awk '{print NR""":"$0}' | grep -e "^${selectBTDomain}:" | cut -d ":" -f 2)

                if [[ -z "${btDomain}" ]]; then
                    echoContent red " ---> Wrong selection, please select again"
                    checkBTPanel
                else
                    domain=${btDomain}
                    if [[ ! -f "/etc/v2ray-agent/tls/${btDomain}.crt" && ! -f "/etc/v2ray-agent/tls/${btDomain}.key" ]]; then
                        ln -s "/www/server/panel/vhost/cert/${btDomain}/fullchain.pem" "/etc/v2ray-agent/tls/${btDomain}.crt"
                        ln -s "/www/server/panel/vhost/cert/${btDomain}/privkey.pem" "/etc/v2ray-agent/tls/${btDomain}.key"
                    fi

                    nginxStaticPath="/www/wwwroot/${btDomain}/html/"

                    mkdir -p "/www/wwwroot/${btDomain}/html/"

                    if [[ -f "/www/wwwroot/${btDomain}/.user.ini" ]]; then
                        chattr -i "/www/wwwroot/${btDomain}/.user.ini"
                    fi
                    nginxConfigPath="/www/server/panel/vhost/nginx/"
                fi
            else
                echoContent red " ---> Wrong selection, please select again"
                checkBTPanel
            fi
        fi
    fi
}
check1Panel() {
    if [[ -n $(pgrep -f "1panel") ]]; then
        if [[ -d '/opt/1panel/apps/openresty/openresty/www/sites/' && -n $(find /opt/1panel/apps/openresty/openresty/www/sites/*/ssl/fullchain.pem) ]]; then
            if [[ -z "${currentHost}" ]]; then
    echoContent skyBlue "\nProgress$1/${totalProgress}: Installation tools"

                find /opt/1panel/apps/openresty/openresty/www/sites/*/ssl/fullchain.pem | awk -F "[/]" '{print $9}' | awk '{print NR""":"$0}'

                read -r -p "Enter the number:" selectBTDomain
            else
                selectBTDomain=$(find /opt/1panel/apps/openresty/openresty/www/sites/*/ssl/fullchain.pem | awk -F "[/]" '{print $9}' | awk '{print NR""":"$0}' | grep "${currentHost}" | cut -d ":" -f 1)
            fi

            if [[ -n "${selectBTDomain}" ]]; then
                btDomain=$(find /opt/1panel/apps/openresty/openresty/www/sites/*/ssl/fullchain.pem | awk -F "[/]" '{print $9}' | awk '{print NR""":"$0}' | grep "${selectBTDomain}:" | cut -d ":" -f 2)

                if [[ -z "${btDomain}" ]]; then
        echoContent red " ---> $1 port opening failed"
                    check1Panel
                else
                    domain=${btDomain}
                    if [[ ! -f "/etc/v2ray-agent/tls/${btDomain}.crt" && ! -f "/etc/v2ray-agent/tls/${btDomain}.key" ]]; then
                        ln -s "/opt/1panel/apps/openresty/openresty/www/sites/${btDomain}/ssl/fullchain.pem" "/etc/v2ray-agent/tls/${btDomain}.crt"
                        ln -s "/opt/1panel/apps/openresty/openresty/www/sites/${btDomain}/ssl/privkey.pem" "/etc/v2ray-agent/tls/${btDomain}.key"
                    fi

                    nginxStaticPath="/opt/1panel/apps/openresty/openresty/www/sites/${btDomain}/index/"
                fi
            else
        echoContent red " ---> $1 port opening failed"
                check1Panel
            fi
        fi
    fi
}

# Check firewall
allowPort() {
    local type=$2
    if [[ -z "${type}" ]]; then
        type=tcp
    fi
    if command -v dpkg >/dev/null 2>&1 && dpkg -l | grep -q "^[[:space:]]*ii[[:space:]]\+ufw"; then
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
            if echo "${firewallPort}" | grep -q ":"; then
                firewallPort=$(echo "${firewallPort}" | awk -F ":" '{print $1"-"$2}')
            fi
            firewall-cmd --zone=public --add-port="${firewallPort}/${type}" --permanent
            checkFirewalldAllowPort "${firewallPort}"
        fi

        if echo "${updateFirewalldStatus}" | grep -q "true"; then
            firewall-cmd --reload
        fi
    elif rc-update show 2>/dev/null | grep -q ufw; then
        if ufw status | grep -q "Status: active"; then
            if ! ufw status | grep -q "$1/${type}"; then
                sudo ufw allow "$1/${type}"
                checkUFWAllowPort "$1"
            fi
        fi
    elif dpkg -l | grep -q "^[[:space:]]*ii[[:space:]]\+netfilter-persistent" && systemctl status netfilter-persistent 2>/dev/null | grep -q "active (exited)"; then
        local updateFirewalldStatus=
        if ! iptables -L | grep -q "$1/${type}(mack-a)"; then
            updateFirewalldStatus=true
            iptables -I INPUT -p "${type}" --dport "$1" -m comment --comment "allow $1/${type}(mack-a)" -j ACCEPT
        fi

        if echo "${updateFirewalldStatus}" | grep -q "true"; then
            netfilter-persistent save
        fi
    fi
}
# Get public IP
getPublicIP() {
    local type=4
    if [[ -n "$1" ]]; then
        type=$1
    fi
    if [[ -n "${currentHost}" && -z "$1" ]] && [[ "${singBoxVLESSRealityVisionServerName}" == "${currentHost}" || "${singBoxVLESSRealityGRPCServerName}" == "${currentHost}" || "${xrayVLESSRealityServerName}" == "${currentHost}" ]]; then
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

# Output ufw port open status
checkUFWAllowPort() {
    if ufw status | grep -q "$1"; then
        echoContent green " ---> $1 port opened successfully"
    else
                echoContent red "acme installation failed--->"
        exit 0
    fi
}

# Output firewall-cmd port open status
checkFirewalldAllowPort() {
    if firewall-cmd --list-ports --permanent | grep -q "$1"; then
        echoContent green " ---> $1 port opened successfully"
    else
                echoContent red "1.Failed to obtain Github files. Please wait for Github to recover and try again. The recovery progress can be viewed [https://www.githubstatus.com/]"
        exit 0
    fi
}

readSingBoxConfig() {
    tuicPort=
    hysteriaPort=
    if [[ -n "${singBoxConfigPath}" ]]; then

        if [[ -f "${singBoxConfigPath}09_tuic_inbounds.json" ]]; then
            tuicPort=$(jq -r '.inbounds[0].listen_port' "${singBoxConfigPath}09_tuic_inbounds.json")
            tuicAlgorithm=$(jq -r '.inbounds[0].congestion_control' "${singBoxConfigPath}09_tuic_inbounds.json")
        fi
        if [[ -f "${singBoxConfigPath}06_hysteria2_inbounds.json" ]]; then
            hysteriaPort=$(jq -r '.inbounds[0].listen_port' "${singBoxConfigPath}06_hysteria2_inbounds.json")
            hysteria2ClientUploadSpeed=$(jq -r '.inbounds[0].down_mbps' "${singBoxConfigPath}06_hysteria2_inbounds.json")
            hysteria2ClientDownloadSpeed=$(jq -r '.inbounds[0].up_mbps' "${singBoxConfigPath}06_hysteria2_inbounds.json")
        fi
    fi
}

readLastInstallationConfig() {
    if [[ -n "${configPath}" ]]; then
        read -r -p "Previous installation configuration found. Use it? [y/n]:" lastInstallationConfigStatus
        if [[ "${lastInstallationConfigStatus}" == "y" ]]; then
            lastInstallationConfig=true
        fi
    fi
}
unInstallSingBox() {
    local type=$1
    if [[ -n "${singBoxConfigPath}" ]]; then
        if grep -q 'tuic' </etc/v2ray-agent/sing-box/conf/config.json && [[ "${type}" == "tuic" ]]; then
            rm "${singBoxConfigPath}09_tuic_inbounds.json"
    echoContent green " ---> Check and install updates [The new machine will be very slow. If there is no response for a long time, please stop it manually and then execute it again]"
        fi

        if grep -q 'hysteria2' </etc/v2ray-agent/sing-box/conf/config.json && [[ "${type}" == "hysteria2" ]]; then
            rm "${singBoxConfigPath}06_hysteria2_inbounds.json"
        echoContent green " ---> Install wget"
        fi
        rm "${singBoxConfigPath}config.json"
    fi

    readInstallType

    if [[ -n "${singBoxConfigPath}" ]]; then
        echoContent yellow "https://www.v2ray-agent.com/archives/1679931532764#heading-8 "
        handleSingBox stop
        handleSingBox start
    else
        handleSingBox stop
        rm /etc/systemd/system/sing-box.service
        rm -rf /etc/v2ray-agent/sing-box/*
        echoContent green " ---> Install curl"
    fi
}

# Check the file directory and path
readConfigHostPathUUID() {
    currentPath=
    currentDefaultPort=
    currentUUID=
    currentClients=
    currentHost=
    currentPort=
    currentCDNAddress=
    singBoxVMessWSPath=
    singBoxVLESSWSPath=
    singBoxVMessHTTPUpgradePath=

    if [[ "${coreInstallType}" == "1" ]]; then

        # Install
        if [[ -n "${frontingType}" ]]; then
            currentHost=$(jq -r .inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile ${configPath}${frontingType}.json | awk -F '[t][l][s][/]' '{print $2}' | awk -F '[.][c][r][t]' '{print $1}')

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
        if echo ${currentInstallProtocolType} | grep -q ",7,"; then

            currentClients=$(jq -r .inbounds[1].settings.clients ${configPath}07_VLESS_vision_reality_inbounds.json)
            currentUUID=$(jq -r .inbounds[1].settings.clients[0].id ${configPath}07_VLESS_vision_reality_inbounds.json)
            xrayVLESSRealityVisionPort=$(jq -r .inbounds[0].port ${configPath}07_VLESS_vision_reality_inbounds.json)
            if [[ "${currentPort}" == "${xrayVLESSRealityVisionPort}" ]]; then
                xrayVLESSRealityVisionPort="${currentDefaultPort}"
            fi
        fi
        # reality xhttp
        if echo ${currentInstallProtocolType} | grep -q ",12,"; then

            currentClients=$(jq -r .inbounds[0].settings.clients ${configPath}12_VLESS_XHTTP_inbounds.json)
            currentUUID=$(jq -r .inbounds[0].settings.clients[0].id ${configPath}12_VLESS_XHTTP_inbounds.json)
            xrayVLESSRealityXHTTPort=$(jq -r .inbounds[0].port ${configPath}12_VLESS_XHTTP_inbounds.json)
            if [[ "${currentPort}" == "${xrayVLESSRealityXHTTPort}" ]]; then
                xrayVLESSRealityXHTTPort="${currentDefaultPort}"
            fi
            currentPath=$(jq -r .inbounds[0].streamSettings.xhttpSettings.path ${configPath}12_VLESS_XHTTP_inbounds.json | awk -F "[/]" '{print $2}' | awk -F "[x][H][T][T][P]" '{print $1}')
        fi
    elif [[ "${coreInstallType}" == "2" ]]; then
        if [[ -n "${frontingType}" ]]; then
            currentHost=$(jq -r .inbounds[0].tls.server_name ${configPath}${frontingType}.json)
            if echo ${currentInstallProtocolType} | grep -q ",11," && [[ "${currentHost}" == "null" ]]; then
                currentHost=$(grep 'server_name' <${nginxConfigPath}sing_box_VMess_HTTPUpgrade.conf | awk '{print $2}')
                currentHost=${currentHost//;/}
            fi
            currentUUID=$(jq -r .inbounds[0].users[0].uuid ${configPath}${frontingType}.json)
            currentClients=$(jq -r .inbounds[0].users ${configPath}${frontingType}.json)
        else
            currentUUID=$(jq -r .inbounds[0].users[0].uuid ${configPath}${frontingTypeReality}.json)
            currentClients=$(jq -r .inbounds[0].users ${configPath}${frontingTypeReality}.json)
        fi
    fi

    #Read path
    if [[ -n "${configPath}" && -n "${frontingType}" ]]; then
        if [[ "${coreInstallType}" == "1" ]]; then
            local fallback
            fallback=$(jq -r -c '.inbounds[0].settings.fallbacks[]|select(.path)' ${configPath}${frontingType}.json | head -1)

            local path
            path=$(echo "${fallback}" | jq -r .path | awk -F "[/]" '{print $2}')

            if [[ $(echo "${fallback}" | jq -r .dest) == 31297 ]]; then
                currentPath=$(echo "${path}" | awk -F "[w][s]" '{print $1}')
            elif [[ $(echo "${fallback}" | jq -r .dest) == 31299 ]]; then
                currentPath=$(echo "${path}" | awk -F "[v][w][s]" '{print $1}')
            fi

        # Try to read alpn h2 Path
            if [[ -z "${currentPath}" ]]; then
                dest=$(jq -r -c '.inbounds[0].settings.fallbacks[]|select(.alpn)|.dest' ${configPath}${frontingType}.json | head -1)
                if [[ "${dest}" == "31302" || "${dest}" == "31304" ]]; then
                    # checkBTPanel
                    # check1Panel
                    if grep -q "trojangrpc {" <${nginxConfigPath}alone.conf; then
                        currentPath=$(grep "trojangrpc {" <${nginxConfigPath}alone.conf | awk -F "[/]" '{print $2}' | awk -F "[t][r][o][j][a][n]" '{print $1}')
                    elif grep -q "grpc {" <${nginxConfigPath}alone.conf; then
                        currentPath=$(grep "grpc {" <${nginxConfigPath}alone.conf | head -1 | awk -F "[/]" '{print $2}' | awk -F "[g][r][p][c]" '{print $1}')
                    fi
                fi
            fi
            if [[ -z "${currentPath}" && -f "${configPath}12_VLESS_XHTTP_inbounds.json" ]]; then
                currentPath=$(jq -r .inbounds[0].streamSettings.xhttpSettings.path "${configPath}12_VLESS_XHTTP_inbounds.json" | awk -F "[x][H][T][T][P]" '{print $1}' | awk -F "[/]" '{print $2}')
            fi
        elif [[ "${coreInstallType}" == "2" && -f "${singBoxConfigPath}05_VMess_WS_inbounds.json" ]]; then
            singBoxVMessWSPath=$(jq -r .inbounds[0].transport.path "${singBoxConfigPath}05_VMess_WS_inbounds.json")
            currentPath=$(jq -r .inbounds[0].transport.path "${singBoxConfigPath}05_VMess_WS_inbounds.json" | awk -F "[/]" '{print $2}')
        fi
        if [[ "${coreInstallType}" == "2" && -f "${singBoxConfigPath}03_VLESS_WS_inbounds.json" ]]; then
            singBoxVLESSWSPath=$(jq -r .inbounds[0].transport.path "${singBoxConfigPath}03_VLESS_WS_inbounds.json")
            currentPath=$(jq -r .inbounds[0].transport.path "${singBoxConfigPath}03_VLESS_WS_inbounds.json" | awk -F "[/]" '{print $2}')
            currentPath=${currentPath::-2}
        fi
        if [[ "${coreInstallType}" == "2" && -f "${singBoxConfigPath}11_VMess_HTTPUpgrade_inbounds.json" ]]; then
            singBoxVMessHTTPUpgradePath=$(jq -r .inbounds[0].transport.path "${singBoxConfigPath}11_VMess_HTTPUpgrade_inbounds.json")
            currentPath=$(jq -r .inbounds[0].transport.path "${singBoxConfigPath}11_VMess_HTTPUpgrade_inbounds.json" | awk -F "[/]" '{print $2}')
        fi
    fi
    if [[ -f "/etc/v2ray-agent/cdn" ]] && [[ -n "$(head -1 /etc/v2ray-agent/cdn)" ]]; then
        currentCDNAddress=$(head -1 /etc/v2ray-agent/cdn)
    else
        currentCDNAddress="${currentHost}"
    fi
}

# Status display
showInstallStatus() {
    if [[ -n "${coreInstallType}" ]]; then
        if [[ "${coreInstallType}" == 1 ]]; then
            if [[ -n $(pgrep -f "xray/xray") ]]; then
        echoContent yellow "$(cat /etc/issue)"
            else
        echoContent yellow "$(cat /proc/version)"
            fi

        elif [[ "${coreInstallType}" == 2 ]]; then
            if [[ -n $(pgrep -f "sing-box/sing-box") ]]; then
                echoContent yellow "\nCore: Xray-core[Running]"
            else
                echoContent yellow "\nCore: Xray-core[not running]"
            fi
        fi
        #Read protocol type
        readInstallProtocolType

        if [[ -n ${currentInstallProtocolType} ]]; then
                echoContent yellow "\nCore: v2ray-core[Running]"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",0,"; then
            echoContent yellow "VLESS+TCP[TLS_Vision] \c"
        fi

        if echo ${currentInstallProtocolType} | grep -q ",1,"; then
            echoContent yellow "VLESS+WS[TLS] \c"
        fi

        if echo ${currentInstallProtocolType} | grep -q ",2,"; then
            echoContent yellow "Trojan+gRPC[TLS] \c"
        fi

        if echo ${currentInstallProtocolType} | grep -q ",3,"; then
            echoContent yellow "VMess+WS[TLS] \c"
        fi

        if echo ${currentInstallProtocolType} | grep -q ",4,"; then
            echoContent yellow "Trojan+TCP[TLS] \c"
        fi

        if echo ${currentInstallProtocolType} | grep -q ",5,"; then
            echoContent yellow "VLESS+gRPC[TLS] \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",6,"; then
            echoContent yellow "Hysteria2 \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",7,"; then
            echoContent yellow "VLESS+Reality+Vision \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",8,"; then
            echoContent yellow "VLESS+Reality+gRPC \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",9,"; then
            echoContent yellow "Tuic \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",10,"; then
            echoContent yellow "Naive \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",11,"; then
            echoContent yellow "VMess+TLS+HTTPUpgrade \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",12,"; then
            echoContent yellow "VLESS+Reality+XHTTP \c"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",13,"; then
            echoContent yellow "AnyTLS \c"
        fi
    fi
}

# Clean up old residue
cleanUp() {
    if [[ "$1" == "xrayDel" ]]; then
        handleXray stop
        rm -rf /etc/v2ray-agent/xray/*
    elif [[ "$1" == "singBoxDel" ]]; then
        handleSingBox stop
        rm -rf /etc/v2ray-agent/sing-box/conf/config.json >/dev/null 2>&1
        rm -rf /etc/v2ray-agent/sing-box/conf/config/* >/dev/null 2>&1
    fi
}
initVar "$1"
checkSystem
checkCPUVendor

readInstallType
readInstallProtocolType
readConfigHostPathUUID
readCustomPort
readSingBoxConfig
# -------------------------------------------------------------

#------------------------------------------------ ----------

#Initialize the installation directory
mkdirTools() {
    mkdir -p /etc/v2ray-agent/tls
    mkdir -p /etc/v2ray-agent/subscribe_local/default
    mkdir -p /etc/v2ray-agent/subscribe_local/clashMeta

    mkdir -p /etc/v2ray-agent/subscribe_remote/default
    mkdir -p /etc/v2ray-agent/subscribe_remote/clashMeta

    mkdir -p /etc/v2ray-agent/subscribe/default
    mkdir -p /etc/v2ray-agent/subscribe/clashMetaProfiles
    mkdir -p /etc/v2ray-agent/subscribe/clashMeta

    mkdir -p /etc/v2ray-agent/subscribe/sing-box
    mkdir -p /etc/v2ray-agent/subscribe/sing-box_profiles
    mkdir -p /etc/v2ray-agent/subscribe_local/sing-box

    mkdir -p /etc/v2ray-agent/xray/conf
    mkdir -p /etc/v2ray-agent/xray/reality_scan
    mkdir -p /etc/v2ray-agent/xray/tmp
    mkdir -p /etc/systemd/system/
    mkdir -p /tmp/v2ray-agent-tls/

    mkdir -p /etc/v2ray-agent/warp

    mkdir -p /etc/v2ray-agent/sing-box/conf/config

    mkdir -p /usr/share/nginx/html/
}
checkRoot() {
    if [ "$(id -u)" -ne 0 ]; then
        #        sudoCMD="sudo"
        echo "${currentHost}"
    fi
}
# Install toolkit
installTools() {
                echoContent skyBlue "sed -i \"1i\\\nameserver 2001:67c:2b0::4\\\nnameserver 2a00:1098:2c::1\" /etc/resolv.conf"
    # Repair individual system problems in ubuntu
    if [[ "${release}" == "ubuntu" ]]; then
        dpkg --configure -a
    fi

    if [[ -n $(pgrep -f "apt") ]]; then
        pgrep -f apt | xargs kill -9
    fi

        echoContent green " ---> install unzip"

    if [[ "${release}" != "centos" ]]; then
        ${upgrade} >/etc/v2ray-agent/install.log 2>&1
    fi

    if grep <"/etc/v2ray-agent/install.log" -q "changed"; then
        ${updateReleaseInfoChange} >/dev/null 2>&1
    fi

    if [[ "${release}" == "centos" ]]; then
        rm -rf /var/run/yum.pid
        ${installType} epel-release >/dev/null 2>&1
    fi

    if ! sudo --version >/dev/null 2>&1; then
        echoContent green " ---> Install socat"
        ${installType} sudo >/dev/null 2>&1
    fi

    if ! wget --help >/dev/null 2>&1; then
        echoContent green " ---> Install tar"
        ${installType} wget >/dev/null 2>&1
    fi

    #    if ! command -v netfilter-persistent >/dev/null 2>&1; then
    #        if [[ "${release}" != "centos" ]]; then
    #            echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | sudo debconf-set-selections
    #            echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | sudo debconf-set-selections
    #            ${installType} iptables-persistent >/dev/null 2>&1
    #        fi
    #    fi

    if ! curl --help >/dev/null 2>&1; then
        echoContent green " ---> install crontabs"
        ${installType} curl >/dev/null 2>&1
    fi

    if ! unzip >/dev/null 2>&1; then
        echoContent green " ---> Install jq"
        ${installType} unzip >/dev/null 2>&1
    fi

    if ! socat -h >/dev/null 2>&1; then
        echoContent green " ---> Install binutils"
        ${installType} socat >/dev/null 2>&1
    fi

    if ! tar --help >/dev/null 2>&1; then
        echoContent green " ---> Install ping6"
        ${installType} tar >/dev/null 2>&1
    fi

    if ! crontab -l >/dev/null 2>&1; then
        echoContent green " ---> Install qrencode"
        if [[ "${release}" == "ubuntu" || "${release}" == "debian" ]]; then
            ${installType} cron >/dev/null 2>&1
        else
            ${installType} crontabs >/dev/null 2>&1
        fi
    fi
    if ! jq --help >/dev/null 2>&1; then
        echoContent green " ---> install sudo"
        ${installType} jq >/dev/null 2>&1
    fi

    if ! command -v ld >/dev/null 2>&1; then
        echoContent green " ---> install lsb-release"
        ${installType} binutils >/dev/null 2>&1
    fi

    if ! openssl help >/dev/null 2>&1; then
        echoContent green " ---> Install lsof"
        ${installType} openssl >/dev/null 2>&1
    fi

    if ! ping6 --help >/dev/null 2>&1; then
        echoContent green " ---> Install dig"
        ${installType} inetutils-ping >/dev/null 2>&1
    fi

    if ! qrencode --help >/dev/null 2>&1; then
        echoContent green " ---> Detected services that do not depend on Nginx, skip installation"
        ${installType} qrencode >/dev/null 2>&1
    fi

    if ! command -v lsb_release >/dev/null 2>&1; then
        if [[ "${release}" == "ubuntu" || "${release}" == "debian" ]]; then
            ${installType} lsb-release >/dev/null 2>&1
        elif [[ "${release}" == "centos" ]]; then
            ${installType} redhat-lsb-core >/dev/null 2>&1
        else
            ${installType} lsb-release >/dev/null 2>&1
        fi
    fi

    if ! lsof -h >/dev/null 2>&1; then
            echoContent green " ---> Install nginx"
        ${installType} lsof >/dev/null 2>&1
    fi

    if ! dig -h >/dev/null 2>&1; then
                    echoContent green " ---> Install nginx"
        if echo "${installType}" | grep -qw "apt"; then
            ${installType} dnsutils >/dev/null 2>&1
        elif echo "${installType}" | grep -qw "yum"; then
            ${installType} bind-utils >/dev/null 2>&1
        elif echo "${installType}" | grep -qw "apk"; then
            ${installType} bind-tools >/dev/null 2>&1
        fi
    fi

    if echo "${selectCustomInstallType}" | grep -qwE ",7,|,8,|,7,8,|,12,|,7,12,"; then
        echoContent green " ---> Install semanage"
    else
        if ! nginx >/dev/null 2>&1; then
        echoContent green " ---> Detected services that do not depend on certificates, skip installation"
            installNginxTools
        else
            nginxVersion=$(nginx -v 2>&1)
            nginxVersion=$(echo "${nginxVersion}" | awk -F "[n][g][i][n][x][/]" '{print $2}' | awk -F "[.]" '{print $2}')
            if [[ ${nginxVersion} -lt 14 ]]; then
                read -r -p "Read that the current Nginx version does not support gRPC, which will cause the installation to fail. Do you want to uninstall Nginx and reinstall it? [y/n]:" unInstallNginxStatus
                if [[ "${unInstallNginxStatus}" == "y" ]]; then
                    ${removeType} nginx >/dev/null 2>&1
                echoContent yellow "\nCore: v2ray-core[not running]"
            echoContent green " ---> Install acme.sh"
                    installNginxTools >/dev/null 2>&1
                else
                    exit 0
                fi
            fi
        fi
    fi

    #    if ! command -v semanage >/dev/null 2>&1 && [[ "${release}" == "centos" ]]; then
    #        if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" == "Enforcing" ]; then
    #            if [[ "${centosVersion}" == "7" ]]; then
    #                policyCoreUtils="policycoreutils-python"
    #            elif [[ "${centosVersion}" == "8" || "${centosVersion}" == "9" || "${centosVersion}" == "10" ]]; then
    #                policyCoreUtils="policycoreutils-python-utils"
    #            fi
    #
    #            if [[ -n "${policyCoreUtils}" ]]; then
    #                ${installType} bash-completion >/dev/null 2>&1
    #                ${installType} ${policyCoreUtils} >/dev/null 2>&1
    #            fi
    #            if [[ -n $(which semanage) ]]; then
    #                semanage port -a -t http_port_t -p tcp 31300
    #            fi
    #        fi
    #    fi

    # Detect nginx version and provide the option of uninstalling it
    if [[ "${selectCustomInstallType}" == "7" ]]; then
    echoContent green " ---> Install WARP"
    else
        if [[ ! -d "$HOME/.acme.sh" ]] || [[ -d "$HOME/.acme.sh" && -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
        echoContent green " ---> WARP started successfully"
            curl -s https://get.acme.sh | sh >/etc/v2ray-agent/tls/acme.log 2>&1

            if [[ ! -d "$HOME/.acme.sh" ]] || [[ -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
                echoContent red "2.There is a bug in the acme.sh script, please check [https://github.com/acmesh-official/acme.sh] issues"
                tail -n 100 /etc/v2ray-agent/tls/acme.log
            echoContent yellow "Installed protocol: \c"
                echoContent red "3.For pure IPv6 machines, please set up NAT64.You can execute the following command. If it still does not work after adding the following command, please try to change to another NAT64"
        echoContent red " ---> The official WARP client does not support ARM architecture"
        echoContent red " ---> Failed to install WARP"
                echoContent skyBlue "  sed -i \"1i\\\nameserver 2a00:1098:2b::1\\\nnameserver 2a00:1098:2c::1\\\nnameserver 2a01:4f8:c2c:123f::1\\\nnameserver 2a01:4f9:c010:3f02::1\" /etc/resolv.conf"
                exit 0
            fi
        fi
    fi

}
bootStartup() {
    local serviceName=$1
    if [[ "${release}" == "alpine" ]]; then
        rc-update add "${serviceName}" default
    else
        systemctl daemon-reload
        systemctl enable "${serviceName}"
    fi
}
# Install Nginx
installNginxTools() {

    if [[ "${release}" == "debian" ]]; then
        sudo apt install gnupg2 ca-certificates lsb-release -y >/dev/null 2>&1
        echo "deb http://nginx.org/packages/mainline/debian $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null 2>&1
        echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx >/dev/null 2>&1
        curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key >/dev/null 2>&1
        # gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
        # gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
        sudo mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc
        sudo apt update >/dev/null 2>&1

    elif [[ "${release}" == "ubuntu" ]]; then
        sudo apt install gnupg2 ca-certificates lsb-release -y >/dev/null 2>&1
        echo "deb http://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null 2>&1
        echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx >/dev/null 2>&1
        curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key >/dev/null 2>&1
        # gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
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
    elif [[ "${release}" == "alpine" ]]; then
        rm "${nginxConfigPath}default.conf"
    fi
    ${installType} nginx >/dev/null 2>&1
    bootStartup nginx
}

# Install warp
installWarp() {
    if [[ "${cpuVendor}" == "arm" ]]; then
        echoContent red " ---> Unable to obtain domain name IPv4 address through DNS"
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

        echoContent green " ---> Try to check the domain name IPv6 address"
    ${installType} cloudflare-warp >/dev/null 2>&1
    if [[ -z $(which warp-cli) ]]; then
            echoContent red " ---> Unable to obtain domain name IPv6 address through DNS, exit installation"
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
        echoContent green " ---> Current VPS IP: ${publicIP}"
    fi
}

# Check the IP of the domain name through dns
checkDNSIP() {
    local domain=$1
    local dnsIP=
    ipType=4
    dnsIP=$(dig @1.1.1.1 +time=2 +short "${domain}" | grep -E "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$")
    if [[ -z "${dnsIP}" ]]; then
        dnsIP=$(dig @8.8.8.8 +time=2 +short "${domain}" | grep -E "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$")
    fi
    if echo "${dnsIP}" | grep -q "timed out" || [[ -z "${dnsIP}" ]]; then
        echo
        echoContent red " ---> The domain name resolution IP is inconsistent with the current server IP\n"
        echoContent green " ---> DNS resolution IP: ${dnsIP}"
        dnsIP=$(dig @2606:4700:4700::1111 +time=2 aaaa +short "${domain}")
        ipType=6
        if echo "${dnsIP}" | grep -q "network unreachable" || [[ -z "${dnsIP}" ]]; then
                echoContent red " ---> Please check if there is a web firewall, such as Oracle and other cloud service providers"
            exit 0
        fi
    fi
    local publicIP=

    publicIP=$(getPublicIP "${ipType}")
    if [[ "${publicIP}" != "${dnsIP}" ]]; then
                echoContent red " ---> Check whether you have installed nginx and there are configuration conflicts. You can try DD pure system and try again"
                echoContent yellow "VLESS+TCP[TLS] \c"
        echoContent green " ---> Domain name IP verification passed"
        echoContent green " ---> Detected that ${port} port is open"
        exit 0
    else
        echoContent green " ---> No open ${port} port detected, exit installation"
    fi
}
# Check the actual open status of the port
checkPortOpen() {
    handleSingBox stop >/dev/null 2>&1
    handleXray stop >/dev/null 2>&1

    local port=$1
    local domain=$2
    local checkPortOpenResult=
                # open port
    allowPort "${port}"

    if [[ -z "${btDomain}" ]]; then

        # Change setting
        handleNginx stop
    #Initialize nginx configuration
        touch ${nginxConfigPath}checkPortOpen.conf
        local listenIPv6PortConfig=

        if [[ -n $(curl -s -6 -m 4 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2) ]]; then
            listenIPv6PortConfig="listen [::]:${port};"
        fi
        cat <<EOF >${nginxConfigPath}checkPortOpen.conf
server {
    listen ${port};
    ${listenIPv6PortConfig}
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
        checkPortOpenResult=$(curl -s -m 10 "http://${domain}:${port}/checkPort")
        localIP=$(curl -s -m 10 "http://${domain}:${port}/ip")
        rm "${nginxConfigPath}checkPortOpen.conf"
        handleNginx stop
        if [[ "${checkPortOpenResult}" == "fjkvymb6len" ]]; then
            echoContent green " ---> Delete Nginx default configuration"
        else
        echoContent green " ---> Check that the current domain name IP is correct"
            if echo "${checkPortOpenResult}" | grep -q "cloudflare"; then
                echoContent yellow "VLESS+TCP[TLS_Vision] \c"
            else
                if [[ -z "${checkPortOpenResult}" ]]; then
                echoContent red " ---> Error log: ${checkPortOpenResult}, please submit feedback on this error log through issues"
        echoContent red "Domain name cannot be empty--->"
                else
        echoContent red "\n ---> The ip of the current domain name was not detected"
                fi
            fi
            exit 0
        fi
        checkIP "${localIP}"
    fi
}

# Initialize Nginx application certificate configuration
initTLSNginxConfig() {
    handleNginx stop
    echoContent skyBlue "\nProgress $1/${totalProgress}: Initializing Nginx application certificate configuration"
    if [[ -n "${currentHost}" && -z "${lastInstallationConfig}" ]]; then
        echo
        read -r -p "Read the last installation record. Do you want to use the domain name from the last installation? [y/n]:" historyDomainStatus
        if [[ "${historyDomainStatus}" == "y" ]]; then
            domain=${currentHost}
                echoContent yellow "Trojan+TCP[TLS_Vision] \c"
        else
            echo
            echoContent yellow "VLESS+WS[TLS] \c"
            read -r -p "domain name:" domain
        fi
    elif [[ -n "${currentHost}" && -n "${lastInstallationConfig}" ]]; then
        domain=${currentHost}
    else
        echo
            echoContent yellow "Trojan+gRPC[TLS] \c"
        read -r -p "domain name:" domain
    fi

    if [[ -z ${domain} ]]; then
            echoContent red " ---> Exception result: ${localIP}"
    # Apply for tls
        initTLSNginxConfig 3
    else
        dnsTLSDomain=$(echo "${domain}" | awk -F "." '{$1="";print $0}' | sed 's/^[[:space:]]*//' | sed 's/ /./g')
        if [[ "${selectCoreType}" == "1" ]]; then
            customPortFunction
        fi
        handleNginx stop
    fi
}

# Delete nginx default configuration
removeNginxDefaultConf() {
    if [[ -f ${nginxConfigPath}default.conf ]]; then
        if [[ "$(grep -c "server_name" <${nginxConfigPath}default.conf)" == "1" ]] && [[ "$(grep -c "server_name  localhost;" <${nginxConfigPath}default.conf)" == "1" ]]; then
                echoContent green " ---> Added successfully"
            rm -rf ${nginxConfigPath}default.conf >/dev/null 2>&1
        fi
    fi
}
# Modify nginx redirection configuration
updateRedirectNginxConf() {
    local redirectDomain=
    redirectDomain=${domain}:${port}

    local nginxH2Conf=
    nginxH2Conf="listen 127.0.0.1:31302 http2 so_keepalive=on proxy_protocol;"
    nginxVersion=$(nginx -v 2>&1)

    if echo "${nginxVersion}" | grep -q "1.25" && [[ $(echo "${nginxVersion}" | awk -F "[.]" '{print $3}') -gt 0 ]] || [[ $(echo "${nginxVersion}" | awk -F "[.]" '{print $2}') -gt 25 ]]; then
        nginxH2Conf="listen 127.0.0.1:31302 so_keepalive=on proxy_protocol;http2 on;"
    fi

    cat <<EOF >${nginxConfigPath}alone.conf
    server {
    		listen 127.0.0.1:31300;
    		server_name _;
    		return 403;
    }
EOF

    if echo "${selectCustomInstallType}" | grep -qE ",2,|,5," || [[ -z "${selectCustomInstallType}" ]]; then

        cat <<EOF >>${nginxConfigPath}alone.conf
server {
	${nginxH2Conf}
	server_name ${domain};
	root ${nginxStaticPath};

    set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;

	client_header_timeout 1071906480m;
    keepalive_timeout 1071906480m;

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
    }
}
EOF
    elif echo "${selectCustomInstallType}" | grep -q ",5," || [[ -z "${selectCustomInstallType}" ]]; then
        cat <<EOF >>${nginxConfigPath}alone.conf
server {
	${nginxH2Conf}

	set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;

	server_name ${domain};
	root ${nginxStaticPath};

	location /${currentPath}grpc {
		client_max_body_size 0;
# 		keepalive_time 1071906480m;
		keepalive_requests 4294967296;
		client_body_timeout 1071906480m;
 		send_timeout 1071906480m;
 		lingering_close always;
 		grpc_read_timeout 1071906480m;
 		grpc_send_timeout 1071906480m;
		grpc_pass grpc://127.0.0.1:31301;
	}
	location / {
    }
}
EOF

    elif echo "${selectCustomInstallType}" | grep -q ",2," || [[ -z "${selectCustomInstallType}" ]]; then
        cat <<EOF >>${nginxConfigPath}alone.conf
server {
	${nginxH2Conf}

	set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;

    server_name ${domain};
	root ${nginxStaticPath};

	location /${currentPath}trojangrpc {
		client_max_body_size 0;
		# keepalive_time 1071906480m;
		# keepalive_time 1071906480m;
		keepalive_requests 4294967296;
		client_body_timeout 1071906480m;
 		send_timeout 1071906480m;
 		lingering_close always;
 		grpc_read_timeout 1071906480m;
 		grpc_send_timeout 1071906480m;
		grpc_pass grpc://127.0.0.1:31301;
	}
	location / {
    }
}
EOF
    else

        cat <<EOF >>${nginxConfigPath}alone.conf
server {
	${nginxH2Conf}

	set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;

	server_name ${domain};
	root ${nginxStaticPath};

	location / {
	}
}
EOF
    fi

    cat <<EOF >>${nginxConfigPath}alone.conf
server {
	listen 127.0.0.1:31300 proxy_protocol;
	server_name ${domain};

	set_real_ip_from 127.0.0.1;
	real_ip_header proxy_protocol;

	root ${nginxStaticPath};
	location / {
	}
}
EOF
    handleNginx stop
}
# singbox Nginx config
singBoxNginxConfig() {
    local type=$1
    local port=$2

    local nginxH2Conf=
    nginxH2Conf="listen ${port} http2 so_keepalive=on ssl;"
    nginxVersion=$(nginx -v 2>&1)

    local singBoxNginxSSL=
    singBoxNginxSSL="ssl_certificate /etc/v2ray-agent/tls/${domain}.crt;ssl_certificate_key /etc/v2ray-agent/tls/${domain}.key;"

    if echo "${nginxVersion}" | grep -q "1.25" && [[ $(echo "${nginxVersion}" | awk -F "[.]" '{print $3}') -gt 0 ]] || [[ $(echo "${nginxVersion}" | awk -F "[.]" '{print $2}') -gt 25 ]]; then
        nginxH2Conf="listen ${port} so_keepalive=on ssl;http2 on;"
    fi

    if echo "${selectCustomInstallType}" | grep -q ",11," || [[ "$1" == "all" ]]; then
        cat <<EOF >>${nginxConfigPath}sing_box_VMess_HTTPUpgrade.conf
server {
	${nginxH2Conf}

	server_name ${domain};
	root ${nginxStaticPath};
    ${singBoxNginxSSL}

    ssl_protocols              TLSv1.2 TLSv1.3;
    ssl_ciphers                TLS13_AES_128_GCM_SHA256:TLS13_AES_256_GCM_SHA384:TLS13_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers  on;

    resolver                   1.1.1.1 valid=60s;
    resolver_timeout           2s;
    client_max_body_size 100m;

    location /${currentPath} {
        if (\$http_upgrade != "websocket") {
            return 444;
        }

        proxy_pass                          http://127.0.0.1:31306;
        proxy_http_version                  1.1;
        proxy_set_header Upgrade            \$http_upgrade;
        proxy_set_header Connection         "upgrade";
        proxy_set_header X-Real-IP          \$remote_addr;
        proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header Host               \$host;
        proxy_redirect                      off;
	}
}
EOF
    fi
}

# check ip
checkIP() {
    echoContent skyBlue "\n ---> Check the domain name ip"
    local localIP=$1

    if [[ -z ${localIP} ]] || ! echo "${localIP}" | sed '1{s/[^(]*(//;s/).*//;q}' | grep -q '\.' && ! echo "${localIP}" | sed '1{s/[^(]*(//;s/).*//;q}' | grep -q ':'; then
            echoContent red "\n ---> Multiple IPs were detected, please confirm whether to turn off cloudflare"
        echoContent skyBlue " ---> Please perform the following checks in order"
            echoContent yellow "VMess+WS[TLS] \c"
            echoContent yellow "Trojan+TCP[TLS] \c"
            echoContent yellow "VLESS+gRPC[TLS] \c"
            echoContent yellow "VLESS+Reality+Vision \c"
        echo
        echoContent skyBlue " ---> If the above settings are correct, please reinstall a pure system and try again"

        if [[ -n ${localIP} ]]; then
            echoContent yellow "VLESS+Reality+gRPC \c"
        echoContent red "\n=============================================================="
        fi
        exit 0
    else
        if echo "${localIP}" | awk -F "[,]" '{print $2}' | grep -q "." || echo "${localIP}" | awk -F "[,]" '{print $2}' | grep -q ":"; then
        echoContent red "================================================== ==============="
                    echoContent yellow " ---> nginx uninstall completed"
                echoContent yellow "Error troubleshooting:"
            exit 0
        fi
            echoContent green " ---> Please add DNS TXT record manually"
    fi
}
# Custom email
customSSLEmail() {
    if echo "$1" | grep -q "validate email"; then
        read -r -p "Whether to re-enter the email address [y/n]:" sslEmailStatus
        if [[ "${sslEmailStatus}" == "y" ]]; then
            sed '/ACCOUNT_EMAIL/d' /root/.acme.sh/account.conf >/root/.acme.sh/account.conf_tmp && mv /root/.acme.sh/account.conf_tmp /root/.acme.sh/account.conf
        else
            exit 0
        fi
    fi

    if [[ -d "/root/.acme.sh" && -f "/root/.acme.sh/account.conf" ]]; then
        if ! grep -q "ACCOUNT_EMAIL" <"/root/.acme.sh/account.conf" && ! echo "${sslType}" | grep -q "letsencrypt"; then
            read -r -p "Please enter your email address:" sslEmail
            if echo "${sslEmail}" | grep -q "@"; then
                echo "ACCOUNT_EMAIL='${sslEmail}'" >>/root/.acme.sh/account.conf
            echoContent green " ---> name: _acme-challenge"
            else
        echoContent yellow " ---> Please check whether the domain name resolution is valid and correct"
                customSSLEmail
            fi
        fi
    fi

}
switchDNSAPI() {
        read -r -p "Use DNS API to issue the certificate [NAT supported]? [y/n]:" dnsAPIStatus
    if [[ "${dnsAPIStatus}" == "y" ]]; then
        echoContent red "\n=============================================================="
            echoContent yellow " ---> Please close the cloud and wait three minutes to try again"
        echoContent yellow "2.aliyun"
        echoContent red "=============================================================="
        read -r -p "Select [Enter for default]:" selectDNSAPIType
        case ${selectDNSAPIType} in
        1)
            dnsAPIType="cloudflare"
            ;;
        2)
            dnsAPIType="aliyun"
            ;;
        *)
            dnsAPIType="cloudflare"
            ;;
        esac
        initDNSAPIConfig "${dnsAPIType}"
    fi
}
initDNSAPIConfig() {
    if [[ "$1" == "cloudflare" ]]; then
            echoContent yellow "\n ---> Domain name: ${domain}"
        read -r -p "Enter API Token:" cfAPIToken
        if [[ -z "${cfAPIToken}" ]]; then
            echoContent red " ---> buypass does not support free wildcard certificates"
            initDNSAPIConfig "$1"
        else
            echo
            if ! echo "${dnsTLSDomain}" | grep -q "\." || [[ -z $(echo "${dnsTLSDomain}" | awk -F "[.]" '{print $1}') ]]; then
            echoContent green " ---> value: ${txtValue}"
                exit 0
            fi
            read -r -p "Use *.${dnsTLSDomain} to request a wildcard certificate via API? [y/n]:" dnsAPIStatus
        fi
    elif [[ "$1" == "aliyun" ]]; then
            read -r -p "Enter Ali Key:" aliKey
            read -r -p "Enter Ali Secret:" aliSecret
        if [[ -z "${aliKey}" || -z "${aliSecret}" ]]; then
                    echoContent red " ---> Verification failed, please wait 1-2 minutes and try again"
            initDNSAPIConfig "$1"
        else
            echo
            if ! echo "${dnsTLSDomain}" | grep -q "\." || [[ -z $(echo "${dnsTLSDomain}" | awk -F "[.]" '{print $1}') ]]; then
                    echoContent green " ---> TXT record verification passed"
                exit 0
            fi
            read -r -p "Use *.${dnsTLSDomain} to request a wildcard certificate via API? [y/n]:" dnsAPIStatus
        fi
    fi
}
#Select ssl installation type
switchSSLType() {
    if [[ -z "${sslType}" ]]; then
        echoContent red "\n=============================================================="
            echoContent yellow "Please enter the domain name to be configured: www.v2ray-agent.com --->"
        echoContent yellow "2.zerossl"
        echoContent yellow "Please enter the domain name to be configured: www.v2ray-agent.com --->"
        echoContent red "=============================================================="
        read -r -p "Please select [Enter] to use the default:" selectSSLType
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
        if [[ -n "${dnsAPIType}" && "${sslType}" == "buypass" ]]; then
                echoContent red " ---> Give up"
            exit 0
        fi
        echo "${sslType}" >/etc/v2ray-agent/tls/ssl_type
    fi
}

#Select acme installation certificate method
selectAcmeInstallSSL() {
    #    local sslIPv6=
    #    local currentIPType=
    if [[ "${ipType}" == "6" ]]; then
        sslIPv6="--listen-v6"
    fi
    #    currentIPType=$(curl -s "-${ipType}" http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)

    #    if [[ -z "${currentIPType}" ]]; then
    #                currentIPType=$(curl -s -6 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)
    #        if [[ -n "${currentIPType}" ]]; then
    #            sslIPv6="--listen-v6"
    #        fi
    #    fi

    acmeInstallSSL

    readAcmeTLS
}

# Install SSL certificate
acmeInstallSSL() {
    local dnsAPIDomain="${tlsDomain}"
    local dnsAPIExtraDomain="-d ${dnsTLSDomain}"
    if [[ "${dnsAPIStatus}" == "y" ]]; then
        dnsAPIDomain="*.${dnsTLSDomain}"
    else
        dnsAPIExtraDomain=""
    fi

    if [[ "${dnsAPIType}" == "cloudflare" ]]; then
                    echoContent green " ---> Generating certificate"
        sudo CF_Token="${cfAPIToken}" "$HOME/.acme.sh/acme.sh" --issue -d "${dnsAPIDomain}" ${dnsAPIExtraDomain} --dns dns_cf -k ec-256 --server "${sslType}" ${sslIPv6} 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
    elif [[ "${dnsAPIType}" == "aliyun" ]]; then
        echoContent green " ---> Generating certificate"
        sudo Ali_Key="${aliKey}" Ali_Secret="${aliSecret}" "$HOME/.acme.sh/acme.sh" --issue -d "${dnsAPIDomain}" ${dnsAPIExtraDomain} --dns dns_ali -k ec-256 --server "${sslType}" ${sslIPv6} 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
    else
        echoContent green " ---> Certificate detected"
        sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 --server "${sslType}" ${sslIPv6} 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
    fi
}
# Custom port
customPortFunction() {
    local historyCustomPortStatus=
    if [[ -n "${customPort}" || -n "${currentPort}" ]]; then
        echo
        if [[ -z "${lastInstallationConfig}" ]]; then
        read -r -p "Read the port from the last installation. Do you want to use the port from the last installation? [y/n]:" historyCustomPortStatus
            if [[ "${historyCustomPortStatus}" == "y" ]]; then
                port=${currentPort}
        echoContent yellow " --->1.Check whether the domain name is written correctly"
            fi
        elif [[ -n "${lastInstallationConfig}" ]]; then
            port=${currentPort}
        fi
    fi
    if [[ -z "${currentPort}" ]] || [[ "${historyCustomPortStatus}" == "n" ]]; then
        echo

        if [[ -n "${btDomain}" ]]; then
        echoContent yellow " --->2.Check whether the domain name dns resolution is correct"
            read -r -p "port:" port
            if [[ -z "${port}" ]]; then
                port=$((RANDOM % 20001 + 10000))
            fi
        else
            echo
        echoContent yellow " --->3.If the parsing is correct, please wait for the dns to take effect, which is expected to take effect within three minutes"
            read -r -p "port:" port
            if [[ -z "${port}" ]]; then
                port=443
            fi
            if [[ "${port}" == "${xrayVLESSRealityPort}" ]]; then
                handleXray stop
            fi
        fi

        if [[ -n "${port}" ]]; then
            if ((port >= 1 && port <= 65535)); then
                allowPort "${port}"
        echoContent yellow " --->4.If you report Nginx startup problems, please start nginx manually to check the errors. If you cannot handle it yourself, please submit issues"
                if [[ -z "${btDomain}" ]]; then
                    checkDNSIP "${domain}"
                    removeNginxDefaultConf
                    checkPortOpen "${port}" "${domain}"
                fi
            else
                echoContent red " ---> Port input error"
                exit 0
            fi
        else
            echoContent red " ---> Port cannot be empty"
            exit 0
        fi
    fi
}

# Check whether the port is occupied
checkPort() {
    if [[ -n "$1" ]] && lsof -i "tcp:$1" | grep -q LISTEN; then
        echoContent red "\n ---> $1 port is occupied, please close it manually and install\n"
        lsof -i "tcp:$1" | grep LISTEN
        exit 0
    fi
}

# Install TLS
installTLS() {
    echoContent skyBlue "\nProgress$1/${totalProgress}: Apply for TLS certificate\n"
    readAcmeTLS
    local tlsDomain=${domain}

    if [[ -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" && -f "/etc/v2ray-agent/tls/${tlsDomain}.key" && -n $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]] || [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]] || [[ "${installedDNSAPIStatus}" == "true" ]]; then
        echoContent green " ---> Install TLS certificate, need to rely on port 80"
        # checkTLStatus
        renewalTLS

        if [[ -z $(find /etc/v2ray-agent/tls/ -name "${tlsDomain}.crt") ]] || [[ -z $(find /etc/v2ray-agent/tls/ -name "${tlsDomain}.key") ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
            if [[ "${installedDNSAPIStatus}" == "true" ]]; then
                sudo "$HOME/.acme.sh/acme.sh" --installcert -d "*.${dnsTLSDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
            else
                sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
            fi

        else
            if [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]] || [[ "${installedDNSAPIStatus}" == "true" ]]; then
                if [[ -z "${lastInstallationConfig}" ]]; then
            echoContent yellow " ---> Detection of abnormal return value, it is recommended to manually uninstall nginx and re-execute the script"
            read -r -p "Reinstall? [y/n]:" reInstallStatus
                    if [[ "${reInstallStatus}" == "y" ]]; then
                        rm -rf /etc/v2ray-agent/tls/*
                        installTLS "$1"
                    fi
                fi
            fi
        fi

    elif [[ -d "$HOME/.acme.sh" ]] && [[ ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" || ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" ]]; then
        switchDNSAPI
        if [[ -z "${dnsAPIType}" ]]; then
            echoContent yellow " ---> Wait three minutes after closing the cloud and try again"
        echoContent green " ---> TLS generated successfully"
            allowPort 80
        fi

        switchSSLType
        customSSLEmail
        selectAcmeInstallSSL

        if [[ "${installedDNSAPIStatus}" == "true" ]]; then
            sudo "$HOME/.acme.sh/acme.sh" --installcert -d "*.${dnsTLSDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
        else
            sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
        fi

        if [[ ! -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" || ! -f "/etc/v2ray-agent/tls/${tlsDomain}.key" ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.key") || -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
            tail -n 10 /etc/v2ray-agent/tls/acme.log
            if [[ ${installTLSCount} == "1" ]]; then
                echoContent red " ---> TLS installation failed, please check the acme log"
                exit 0
            fi

            installTLSCount=1
            echo

            if tail -n 10 /etc/v2ray-agent/tls/acme.log | grep -q "Could not validate email address as valid"; then
                echoContent red " ---> The email cannot pass SSL vendor verification, please re-enter"
                echo
                customSSLEmail "validate email"
                installTLS "$1"
            else
                installTLS "$1"
            fi
        fi

        echoContent green " ---> Used successfully\n"
    else
            echoContent yellow " ---> The detected IP is as follows: [${localIP}]"
        exit 0
    fi
}

#Initialize random string
initRandomPath() {
    local chars="abcdefghijklmnopqrtuxyz"
    local initCustomPath=
    for i in {1..4}; do
        echo "${i}" >/dev/null
        initCustomPath+="${chars:RANDOM%${#chars}:1}"
    done
    customPath=${initCustomPath}
}

# Custom/random path
randomPathFunction() {
    if [[ -n $1 ]]; then
    echoContent skyBlue "\nProgress$1/${totalProgress}: Generate random path"
    else
    echoContent skyBlue "\n----------------------------"
    fi

    if [[ -n "${currentPath}" && -z "${lastInstallationConfig}" ]]; then
        echo
        read -r -p "Read the last installation record. Do you want to use the path from the last installation? [y/n]:" historyPathStatus
        echo
    elif [[ -n "${currentPath}" && -n "${lastInstallationConfig}" ]]; then
        historyPathStatus="y"
    fi

    if [[ "${historyPathStatus}" == "y" ]]; then
        customPath=${currentPath}
            echoContent green " ---> Added fake site successfully"
    else
                echoContent yellow "Please re-enter the correct email format [Example: username@example.com]"
        read -r -p 'path:' customPath
        if [[ -z "${customPath}" ]]; then
            initRandomPath
            currentPath=${customPath}
        else
            if [[ "${customPath: -2}" == "ws" ]]; then
                echo
                echoContent red " ---> The custom path cannot end with ws, otherwise the splitting path cannot be distinguished"
                randomPathFunction "$1"
            else
                currentPath=${customPath}
            fi
        fi
    fi
    echoContent yellow "\n path:${currentPath}"
    echoContent skyBlue "\n----------------------------"
}
randomNum() {
    if [[ "${release}" == "alpine" ]]; then
        local ranNum=
        ranNum="$(shuf -i "$1"-"$2" -n 1)"
        echo "${ranNum}"
    else
        echo $((RANDOM % $2 + $1))
    fi
}
# Nginx disguise blog
nginxBlog() {
    if [[ -n "$1" ]]; then
    echoContent skyBlue "\nProgress$1/${totalProgress}: Add fake site"
    else
        echoContent yellow "1.letsencrypt[default]"
    fi

    if [[ -d "${nginxStaticPath}" && -f "${nginxStaticPath}/check" ]]; then
        echo
        if [[ -z "${lastInstallationConfig}" ]]; then
        read -r -p "Detected installation of fake site, do you need to reinstall [y/n]:" nginxBlogInstallStatus
        else
            nginxBlogInstallStatus="n"
        fi

        if [[ "${nginxBlogInstallStatus}" == "y" ]]; then
            rm -rf "${nginxStaticPath}*"
            #  randomNum=$((RANDOM % 6 + 1))
            randomNum=$(randomNum 1 9)
            if [[ "${release}" == "alpine" ]]; then
                wget -q -P "${nginxStaticPath}" "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip"
            else
                wget -q "${wgetShowProgressStatus}" -P "${nginxStaticPath}" "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip"
            fi

            unzip -o "${nginxStaticPath}html${randomNum}.zip" -d "${nginxStaticPath}" >/dev/null
            rm -f "${nginxStaticPath}html${randomNum}.zip*"
        echoContent green " ---> Added fake site successfully"
        fi
    else
        randomNum=$(randomNum 1 9)
        #        randomNum=$((RANDOM % 6 + 1))
        rm -rf "${nginxStaticPath}*"

        if [[ "${release}" == "alpine" ]]; then
            wget -q -P "${nginxStaticPath}" "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip"
        else
            wget -q "${wgetShowProgressStatus}" -P "${nginxStaticPath}" "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip"
        fi

        unzip -o "${nginxStaticPath}html${randomNum}.zip" -d "${nginxStaticPath}" >/dev/null
        rm -f "${nginxStaticPath}html${randomNum}.zip*"
            echoContent green " ---> http_port_t 31300 port opened successfully"
    fi

}

# Modify http_port_t port
updateSELinuxHTTPPortT() {

    $(find /usr/bin /usr/sbin | grep -w journalctl) -xe >/etc/v2ray-agent/nginx_error.log 2>&1

    if find /usr/bin /usr/sbin | grep -q -w semanage && find /usr/bin /usr/sbin | grep -q -w getenforce && grep -E "31300|31302" </etc/v2ray-agent/nginx_error.log | grep -q "Permission denied"; then
        echoContent red " ---> Check if the SELinux port is open"
        if ! $(find /usr/bin /usr/sbin | grep -w semanage) port -l | grep http_port | grep -q 31300; then
            $(find /usr/bin /usr/sbin | grep -w semanage) port -a -t http_port_t -p tcp 31300
            echoContent green " ---> http_port_t 31302 port opened successfully"
        fi

        if ! $(find /usr/bin /usr/sbin | grep -w semanage) port -l | grep http_port | grep -q 31302; then
            $(find /usr/bin /usr/sbin | grep -w semanage) port -a -t http_port_t -p tcp 31302
            echoContent green " ---> Nginx started successfully"
        fi
        handleNginx start

    else
        exit 0
    fi
}

#Operation Nginx
handleNginx() {

    if ! echo "${selectCustomInstallType}" | grep -qwE ",7,|,8,|,7,8," && [[ -z $(pgrep -f "nginx") ]] && [[ "$1" == "start" ]]; then
        if [[ "${release}" == "alpine" ]]; then
            rc-service nginx start 2>/etc/v2ray-agent/nginx_error.log
        else
            systemctl start nginx 2>/etc/v2ray-agent/nginx_error.log
        fi

        sleep 0.5

        if [[ -z $(pgrep -f "nginx") ]]; then
            echoContent red " ---> Nginx failed to start"
            echoContent red " ---> Please try to install nginx manually and execute the script again"
            nginx
            if grep -q "journalctl -xe" </etc/v2ray-agent/nginx_error.log; then
                updateSELinuxHTTPPortT
            fi
        else
        echoContent green " ---> Nginx closed successfully"
        fi

    elif [[ -n $(pgrep -f "nginx") ]] && [[ "$1" == "stop" ]]; then

        if [[ "${release}" == "alpine" ]]; then
            rc-service nginx stop
        else
            systemctl stop nginx
        fi
        sleep 0.5

        if [[ -z ${btDomain} && -n $(pgrep -f "nginx") ]]; then
            pgrep -f "nginx" | xargs kill -9
        fi
        echoContent green "\n ---> Add scheduled maintenance certificate successfully"
    fi
}

# Scheduled task to update tls certificate
installCronTLS() {
    if [[ -z "${btDomain}" ]]; then
        echoContent skyBlue "\nProgress$1/${totalProgress}: Add scheduled maintenance certificate"
        crontab -l >/etc/v2ray-agent/backup_crontab.cron
        local historyCrontab
        historyCrontab=$(sed '/v2ray-agent/d;/acme.sh/d' /etc/v2ray-agent/backup_crontab.cron)
        echo "${historyCrontab}" >/etc/v2ray-agent/backup_crontab.cron
        echo "30 1 * * * /bin/bash /etc/v2ray-agent/install.sh RenewTLS >> /etc/v2ray-agent/crontab_tls.log 2>&1" >>/etc/v2ray-agent/backup_crontab.cron
        crontab /etc/v2ray-agent/backup_crontab.cron
        echoContent green "\n ---> Adding scheduled update geo file successfully"
    fi
}
# Scheduled tasks update geo files
installCronUpdateGeo() {
    if [[ "${coreInstallType}" == "1" ]]; then
        if crontab -l | grep -q "UpdateGeo"; then
            echoContent red "\n ---> The automatic update scheduled task has been added, please do not add it repeatedly"
            exit 0
        fi
        echoContent skyBlue "\nProgress 1/1: Add regularly updated geo files"
        crontab -l >/etc/v2ray-agent/backup_crontab.cron
        echo "35 1 * * * /bin/bash /etc/v2ray-agent/install.sh UpdateGeo >> /etc/v2ray-agent/crontab_tls.log 2>&1" >>/etc/v2ray-agent/backup_crontab.cron
        crontab /etc/v2ray-agent/backup_crontab.cron
            echoContent green " ---> The certificate is valid"
    fi
}

# Update certificate
renewalTLS() {

    if [[ -n $1 ]]; then
        echoContent skyBlue "\nProgress$1/1: Update certificate"
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
    if [[ -d "$HOME/.acme.sh/${domain}_ecc" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.key" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.cer" ]] || [[ "${installedDNSAPIStatus}" == "true" ]]; then
        modifyTime=

        if [[ "${installedDNSAPIStatus}" == "true" ]]; then
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
            tlsStatus="Expired"
        fi

        echoContent skyBlue " ---> Certificate check date:$(date "+%F %H:%M:%S")"
        echoContent skyBlue " ---> Certificate generation date: $(date -d @"${modifyTime}" +"%F %H:%M:%S")"
        echoContent skyBlue " ---> Certificate generation days: ${days}"
        echoContent skyBlue " ---> Number of days remaining on the certificate: "${tlsStatus}
        echoContent skyBlue " ---> The certificate will be automatically updated on the last day before it expires. If the update fails, please update manually"

        if [[ ${remainingDays} -le 1 ]]; then
        echoContent yellow "2.zerossl"
            handleNginx stop

            if [[ "${coreInstallType}" == "1" ]]; then
                handleXray stop
            elif [[ "${coreInstallType}" == "2" ]]; then
                handleSingBox stop
            fi

            sudo "$HOME/.acme.sh/acme.sh" --cron --home "$HOME/.acme.sh"
            sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${domain}" --fullchainpath /etc/v2ray-agent/tls/"${domain}.crt" --keypath /etc/v2ray-agent/tls/"${domain}.key" --ecc
            reloadCore
            handleNginx start
        else
        echoContent green " ---> v2ray-core version:${version}"
        fi
    elif [[ -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" && -f "/etc/v2ray-agent/tls/${tlsDomain}.key" && -n $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
        echoContent yellow "3.buypass[Does not support DNS application]"
    else
        echoContent red " ---> not installed"
    fi
}

installSingBox() {
    readInstallType
        echoContent skyBlue " ---> Certificate generation days: ${days}"

    if [[ ! -f "/etc/v2ray-agent/sing-box/sing-box" ]]; then

        if [[ "${prereleaseStatus}" == "true" ]]; then
            version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases?per_page=20" | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
        else
            version=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
        fi

            echoContent green " ---> Lock v2ray-core version to v4.32.1"

        if [[ "${release}" == "alpine" ]]; then
            wget -c -q -P /etc/v2ray-agent/sing-box/ "https://github.com/SagerNet/sing-box/releases/download/${version}/sing-box-${version/v/}${singBoxCoreCPUVendor}.tar.gz"
        else
            wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/sing-box/ "https://github.com/SagerNet/sing-box/releases/download/${version}/sing-box-${version/v/}${singBoxCoreCPUVendor}.tar.gz"
        fi

        if [[ ! -f "/etc/v2ray-agent/sing-box/sing-box-${version/v/}${singBoxCoreCPUVendor}.tar.gz" ]]; then
            read -r -p "Core download failed. Retry installation? [y/n]" downloadStatus
            if [[ "${downloadStatus}" == "y" ]]; then
                installSingBox "$1"
            fi
        else

            tar zxvf "/etc/v2ray-agent/sing-box/sing-box-${version/v/}${singBoxCoreCPUVendor}.tar.gz" -C "/etc/v2ray-agent/sing-box/" >/dev/null 2>&1

            mv "/etc/v2ray-agent/sing-box/sing-box-${version/v/}${singBoxCoreCPUVendor}/sing-box" /etc/v2ray-agent/sing-box/sing-box
            rm -rf /etc/v2ray-agent/sing-box/sing-box-*
            chmod 655 /etc/v2ray-agent/sing-box/sing-box
        fi
    else
        echoContent green " ---> Current version:v$(/etc/v2ray-agent/sing-box/sing-box version | grep "sing-box version" | awk '{print $3}')"

        if [[ "${prereleaseStatus}" == "true" ]]; then
            version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases?per_page=20" | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
        else
            version=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
        fi

            echoContent green " ---> v2ray-core version:$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"

        if [[ -z "${lastInstallationConfig}" ]]; then
            read -r -p "Update or upgrade? [y/n]:" reInstallSingBoxStatus
            if [[ "${reInstallSingBoxStatus}" == "y" ]]; then
                rm -f /etc/v2ray-agent/sing-box/sing-box
                installSingBox "$1"
            fi
        fi
    fi

}

# Check wget showProgress
checkWgetShowProgress() {
    if [[ "${release}" != "alpine" ]]; then
        if find /usr/bin /usr/sbin | grep -q "/wget" && wget --help | grep -q show-progress; then
            wgetShowProgressStatus="--show-progress"
        fi
    fi
}
# Install xray
installXray() {
    readInstallType
    local prereleaseStatus=false
    if [[ "$2" == "true" ]]; then
        prereleaseStatus=true
    fi

        echoContent skyBlue " ---> Number of days remaining on the certificate:${tlsStatus}"

    if [[ ! -f "/etc/v2ray-agent/xray/xray" ]]; then
        if [[ "${prereleaseStatus}" == "true" ]]; then
            version=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=5" | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
        else
            version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r .tag_name)
        fi

        echoContent green " ---> Hysteria version:${version}"
        if [[ "${release}" == "alpine" ]]; then
            wget -c -q -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
        else
            wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
        fi

        if [[ ! -f "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" ]]; then
            read -r -p "Core download failed. Retry installation? [y/n]" downloadStatus
            if [[ "${downloadStatus}" == "y" ]]; then
                installXray "$1"
            fi
        else
            unzip -o "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" -d /etc/v2ray-agent/xray >/dev/null
            rm -rf "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip"

            version=$(curl -s https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases?per_page=1 | jq -r '.[]|.tag_name')
            echoContent skyBlue "------------------------Version-------------------------------"
            echo "version:${version}"
            rm /etc/v2ray-agent/xray/geo* >/dev/null 2>&1

            if [[ "${release}" == "alpine" ]]; then
                wget -c -q -P /etc/v2ray-agent/xray/ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat"
                wget -c -q -P /etc/v2ray-agent/xray/ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat"
            else
                wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/xray/ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat"
                wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/xray/ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat"
            fi

            chmod 655 /etc/v2ray-agent/xray/xray
        fi
    else
        if [[ -z "${lastInstallationConfig}" ]]; then
        echoContent green " ---> Hysteria version:$(/etc/v2ray-agent/hysteria/hysteria --version | awk '{print $3}')"
        read -r -p "Would you like to update or upgrade? [y/n]:" reInstallXrayStatus
            if [[ "${reInstallXrayStatus}" == "y" ]]; then
                rm -f /etc/v2ray-agent/xray/xray
                installXray "$1" "$2"
            fi
        fi
    fi
}

# xray version management
xrayVersionManageMenu() {
    echoContent skyBlue "\nProgress$1/${totalProgress}: Install V2Ray"
    if [[ "${coreInstallType}" != "1" ]]; then
            echoContent red " ---> Core download failed, please try installation again"
        exit 0
    fi
    echoContent red "\n=============================================================="
            echoContent yellow " ---> Please refer to this tutorial for adding method, https://github.com/mack-a/v2ray-agent/blob/master/documents/dns_txt.md"
            echoContent yellow " ---> Just like installing wildcard certificates on multiple machines with the same domain name, please add multiple TXT records. There is no need to modify the previously added TXT records."
            echoContent yellow " ---> Please wait 1-2 minutes after the addition is completed"
            echoContent yellow "\n ---> Port: ${port}"
            echoContent yellow "Please enter the port [cannot be the same as the BT Panel port, press Enter to be random]"
            echoContent yellow "Please enter the port [default: 443], you can customize the port [press Enter to use the default]"
                echoContent yellow "\n ---> Port: ${port}"
            echoContent yellow " ---> If the certificate has not expired or is customized, please select [n]\n"
        echoContent yellow " ---> acme.sh is not installed"
    echoContent red "=============================================================="
    read -r -p "Please select:" selectXrayType
    if [[ "${selectXrayType}" == "1" ]]; then
        prereleaseStatus=false
        updateXray
    elif [[ "${selectXrayType}" == "2" ]]; then
        prereleaseStatus=true
        updateXray
    elif [[ "${selectXrayType}" == "3" ]]; then
        echoContent yellow "Please enter a custom path [eg: alone], no slash required, [Enter] random path"
    echoContent yellow "\n path:${currentPath}"
            echoContent yellow " ---> Regenerate certificate"
        echoContent skyBlue "------------------------Version-------------------------------"
        curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=5" | jq -r ".[]|select (.prerelease==false)|.tag_name" | awk '{print ""NR""":"$0}'
        echoContent skyBlue "--------------------------------------------------------------"
        read -r -p "Please enter the version you want to roll back:" selectXrayVersionType
        version=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=5" | jq -r ".[]|select (.prerelease==false)|.tag_name" | awk '{print ""NR""":"$0}' | grep "${selectXrayVersionType}:" | awk -F "[:]" '{print $2}')
        if [[ -n "${version}" ]]; then
            updateXray "${version}"
        else
        echoContent red " ---> The installation directory is not detected, please execute the script to install the content"
            xrayVersionManageMenu 1
        fi
    elif [[ "${selectXrayType}" == "4" ]]; then
        handleXray stop
    elif [[ "${selectXrayType}" == "5" ]]; then
    # start up
        handleXray start
    elif [[ "${selectXrayType}" == "6" ]]; then
        reloadCore
    elif [[ "${selectXrayType}" == "7" ]]; then
        updateGeoSite
    elif [[ "${selectXrayType}" == "8" ]]; then
        installCronUpdateGeo
    elif [[ "${selectXrayType}" == "9" ]]; then
        checkLog 1
    fi
}

# Update geosite
updateGeoSite() {
    echoContent yellow "1.Upgrade v2ray-core"

    version=$(curl -s https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases?per_page=1 | jq -r '.[]|.tag_name')
    echoContent skyBlue "------------------------Version-------------------------------"
    echo "version:${version}"
    rm ${configPath}../geo* >/dev/null

    if [[ "${release}" == "alpine" ]]; then
        wget -c -q -P ${configPath}../ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat"
        wget -c -q -P ${configPath}../ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat"
    else
        wget -c -q "${wgetShowProgressStatus}" -P ${configPath}../ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat"
        wget -c -q "${wgetShowProgressStatus}" -P ${configPath}../ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat"
    fi

    reloadCore
        echoContent green " ---> Tuic version:${version}"

}

# Update Xray
updateXray() {
    readInstallType

    if [[ -z "${coreInstallType}" || "${coreInstallType}" != "1" ]]; then

        if [[ "${prereleaseStatus}" == "true" ]]; then
            version=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=5" | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
        else
            version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r .tag_name)
        fi

        if [[ -n "$1" ]]; then
            version=$1
        fi

        echoContent green " ---> Tuic version:$(/etc/v2ray-agent/tuic/tuic -v)"

        if [[ "${release}" == "alpine" ]]; then
            wget -c -q -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
        else
            wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
        fi

        unzip -o "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" -d /etc/v2ray-agent/xray >/dev/null
        rm -rf "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip"
        chmod 655 /etc/v2ray-agent/xray/xray
        handleXray stop
        handleXray start
    else
        echoContent green " ---> Xray-core version:${version}"

        if [[ "${prereleaseStatus}" == "true" ]]; then
            remoteVersion=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=5" | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
        else
            remoteVersion=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r .tag_name)
        fi

        echoContent green " ---> Xray-core version:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"

        if [[ -n "$1" ]]; then
            version=$1
        else
            version=${remoteVersion}
        fi

        if [[ -n "$1" ]]; then
            read -r -p "The rollback version is ${version}, do you want to continue? [y/n]:" rollbackXrayStatus
            if [[ "${rollbackXrayStatus}" == "y" ]]; then
    echoContent green " ---> Update completed"

                handleXray stop
                rm -f /etc/v2ray-agent/xray/xray
                updateXray "${version}"
            else
        echoContent green " ---> v2ray-core version:${version}"
            fi
        elif [[ "${version}" == "v$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)" ]]; then
            read -r -p "The current version is the same as the latest version. Do you want to reinstall? [y/n]:" reInstallXrayStatus
            if [[ "${reInstallXrayStatus}" == "y" ]]; then
                handleXray stop
                rm -f /etc/v2ray-agent/xray/xray
                updateXray
            else
        echoContent green " ---> Current v2ray-core version: $(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"
            fi
        else
            read -r -p "The latest version is: ${version}, is it updated? [y/n]:" installXrayStatus
            if [[ "${installXrayStatus}" == "y" ]]; then
                rm /etc/v2ray-agent/xray/xray
                updateXray
            else
                    echoContent green " ---> Current v2ray-core version: $(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"
            fi

        fi
    fi
}

# Verify that the entire service is available
checkGFWStatue() {
    readInstallType
    echoContent skyBlue "\nProgress$1/${totalProgress}: Installing Hysteria"
    if [[ "${coreInstallType}" == "1" ]] && [[ -n $(pgrep -f "xray/xray") ]]; then
                    echoContent green " ---> Current Xray-core version: $(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"
    elif [[ "${coreInstallType}" == "2" ]] && [[ -n $(pgrep -f "sing-box/sing-box") ]]; then
                echoContent green " ---> Abandon the rollback version"
    else
    echoContent red "\n================================================ ================="
        exit 0
    fi
}

installAlpineStartup() {
    local serviceName=$1
    if [[ "${serviceName}" == "sing-box" ]]; then
        cat <<EOF >"/etc/init.d/${serviceName}"
#!/sbin/openrc-run

description="sing-box service"
command="/etc/v2ray-agent/sing-box/sing-box"
command_args="run -c /etc/v2ray-agent/sing-box/conf/config.json"
command_background=true
pidfile="/var/run/sing-box.pid"
EOF
    elif [[ "${serviceName}" == "xray" ]]; then
        cat <<EOF >"/etc/init.d/${serviceName}"
#!/sbin/openrc-run

description="xray service"
command="/etc/v2ray-agent/xray/xray"
command_args="run -confdir /etc/v2ray-agent/xray/conf"
command_background=true
pidfile="/var/run/xray.pid"
EOF
    fi

    chmod +x "/etc/init.d/${serviceName}"
}

installSingBoxService() {
    echoContent skyBlue "\nProgress$1/${totalProgress}: Install Tuic"
    execStart='/etc/v2ray-agent/sing-box/sing-box run -c /etc/v2ray-agent/sing-box/conf/config.json'

    if [[ -n $(find /bin /usr/bin -name "systemctl") && "${release}" != "alpine" ]]; then
        rm -rf /etc/systemd/system/sing-box.service
        touch /etc/systemd/system/sing-box.service
        cat <<EOF >/etc/systemd/system/sing-box.service
[Unit]
Description=Sing-Box Service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=${execStart}
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10
LimitNPROC=infinity
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
        bootStartup "sing-box.service"
    elif [[ "${release}" == "alpine" ]]; then
        installAlpineStartup "sing-box"
        bootStartup "sing-box"
    fi

                echoContent green " ---> Give up and reinstall"
}

# Xray starts automatically after booting
installXrayService() {
    echoContent skyBlue "\nProgress$1/${totalProgress}: Install Xray"
    execStart='/etc/v2ray-agent/xray/xray run -confdir /etc/v2ray-agent/xray/conf'
    if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
        rm -rf /etc/systemd/system/xray.service
        touch /etc/systemd/system/xray.service
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
LimitNPROC=infinity
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
        bootStartup "xray.service"
                echoContent green " ---> Abort update"
    elif [[ "${release}" == "alpine" ]]; then
        installAlpineStartup "xray"
        bootStartup "xray"
    fi
}

# Operation Hysteria
handleHysteria() {
    # shellcheck disable=SC2010
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
        echoContent green " ---> Xray-core version:${version}"
        else
    echoContent red "================================================== ==============="
            echoContent red "\n ---> Incorrect input, please re-enter"
            exit 0
        fi
    elif [[ "$1" == "stop" ]]; then
        if [[ -z $(pgrep -f "hysteria/hysteria") ]]; then
        echoContent green " ---> Current Xray-core version: $(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"
        else
        echoContent red " ---> The installation directory is not detected, please execute the script to install the content"
    echoContent red "\n================================================ ================="
            exit 0
        fi
    fi
}

handleSingBox() {
    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        if [[ -z $(pgrep -f "sing-box") ]] && [[ "$1" == "start" ]]; then
            singBoxMergeConfig
            systemctl start sing-box.service
        elif [[ -n $(pgrep -f "sing-box") ]] && [[ "$1" == "stop" ]]; then
            systemctl stop sing-box.service
        fi
    elif [[ -f "/etc/init.d/sing-box" ]]; then
        if [[ -z $(pgrep -f "sing-box") ]] && [[ "$1" == "start" ]]; then
            singBoxMergeConfig
            rc-service sing-box start
        elif [[ -n $(pgrep -f "sing-box") ]] && [[ "$1" == "stop" ]]; then
            rc-service sing-box stop
        fi
    fi
    sleep 1

    if [[ "$1" == "start" ]]; then
        if [[ -n $(pgrep -f "sing-box") ]]; then
                echoContent green " ---> Current Xray-core version: $(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"
        else
    echoContent red "================================================== ==============="
    echoContent yellow "2.Fallback v2ray-core"
            echo
    echoContent yellow "3.Close v2ray-core"
            exit 0
        fi
    elif [[ "$1" == "stop" ]]; then
        if [[ -z $(pgrep -f "sing-box") ]]; then
                echoContent green " ---> Abandon the rollback version"
        else
            echoContent red "\n ---> Incorrect input, please re-enter"
        echoContent red " ---> Service startup failed, please check if there are logs printed in the terminal"
            exit 0
        fi
    fi
}

# Manipulate xray
handleXray() {
    if [[ -n $(find /bin /usr/bin -name "systemctl") ]] && [[ -n $(find /etc/systemd/system/ -name "xray.service") ]]; then
        if [[ -z $(pgrep -f "xray/xray") ]] && [[ "$1" == "start" ]]; then
            systemctl start xray.service
        elif [[ -n $(pgrep -f "xray/xray") ]] && [[ "$1" == "stop" ]]; then
            systemctl stop xray.service
        fi
    elif [[ -f "/etc/init.d/xray" ]]; then
        if [[ -z $(pgrep -f "xray/xray") ]] && [[ "$1" == "start" ]]; then
            rc-service xray start
        elif [[ -n $(pgrep -f "xray/xray") ]] && [[ "$1" == "stop" ]]; then
            rc-service xray stop
        fi
    fi

    sleep 0.8

    if [[ "$1" == "start" ]]; then
        if [[ -n $(pgrep -f "xray/xray") ]]; then
                echoContent green " ---> Give up and reinstall"
        else
            echoContent red "V2Ray failed to start"
            echoContent red "Please manually execute [/etc/v2ray-agent/v2ray/v2ray -confdir /etc/v2ray-agent/v2ray/conf] and check the error log"
            exit 0
        fi
    elif [[ "$1" == "stop" ]]; then
        if [[ -z $(pgrep -f "xray/xray") ]]; then
                echoContent green " ---> Abort update"
        else
            echoContent red "V2Ray failed to close"
            echoContent red "Please execute manually [ps -ef|grep -v grep|grep v2ray|awk '{print \$2}'|xargs kill -9]"
            exit 0
        fi
    fi
}

# Read user data and initialize
initXrayClients() {
    local type=",$1,"
    local newUUID=$2
    local newEmail=$3
    if [[ -n "${newUUID}" ]]; then
        local newUser=
        newUser="{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-vision\",\"email\":\"${newEmail}-VLESS_TCP/TLS_Vision\"}"
        currentClients=$(echo "${currentClients}" | jq -r ". +=[${newUser}]")
    fi
    local users=
    users=[]
    while read -r user; do
        uuid=$(echo "${user}" | jq -r .id//.uuid)
        email=$(echo "${user}" | jq -r .email//.name | awk -F "[-]" '{print $1}')
        currentUser=
        if echo "${type}" | grep -q "0"; then
            currentUser="{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-vision\",\"email\":\"${email}-VLESS_TCP/TLS_Vision\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # VLESS WS
        if echo "${type}" | grep -q ",1,"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-VLESS_WS\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # VLESS XHTTP
        if echo "${type}" | grep -q ",12,"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-VLESS_Reality_XHTTP\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # trojan grpc
        if echo "${type}" | grep -q ",2,"; then
            currentUser="{\"password\":\"${uuid}\",\"email\":\"${email}-Trojan_gRPC\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # VMess WS
        if echo "${type}" | grep -q ",3,"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-VMess_WS\",\"alterId\": 0}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # trojan tcp
        if echo "${type}" | grep -q ",4,"; then
            currentUser="{\"password\":\"${uuid}\",\"email\":\"${email}-trojan_tcp\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # vless grpc
        if echo "${type}" | grep -q ",5,"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-vless_grpc\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # hysteria
        if echo "${type}" | grep -q ",6,"; then
            currentUser="{\"password\":\"${uuid}\",\"name\":\"${email}-singbox_hysteria2\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # vless reality vision
        if echo "${type}" | grep -q ",7,"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-vless_reality_vision\",\"flow\":\"xtls-rprx-vision\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # vless reality grpc
        if echo "${type}" | grep -q ",8,"; then
            currentUser="{\"id\":\"${uuid}\",\"email\":\"${email}-vless_reality_grpc\",\"flow\":\"\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # tuic
        if echo "${type}" | grep -q ",9,"; then
            currentUser="{\"uuid\":\"${uuid}\",\"password\":\"${uuid}\",\"name\":\"${email}-singbox_tuic\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

    done < <(echo "${currentClients}" | jq -c '.[]')
    echo "${users}"
}
initSingBoxClients() {
    local type=",$1,"
    local newUUID=$2
    local newName=$3

    if [[ -n "${newUUID}" ]]; then
        local newUser=
        newUser="{\"uuid\":\"${newUUID}\",\"flow\":\"xtls-rprx-vision\",\"name\":\"${newName}-VLESS_TCP/TLS_Vision\"}"
        currentClients=$(echo "${currentClients}" | jq -r ". +=[${newUser}]")
    fi
    local users=
    users=[]
    while read -r user; do
        uuid=$(echo "${user}" | jq -r .uuid//.id//.password)
        name=$(echo "${user}" | jq -r .name//.email//.username | awk -F "[-]" '{print $1}')
        currentUser=
        # VLESS Vision
        if echo "${type}" | grep -q ",0,"; then
            currentUser="{\"uuid\":\"${uuid}\",\"flow\":\"xtls-rprx-vision\",\"name\":\"${name}-VLESS_TCP/TLS_Vision\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # VLESS WS
        if echo "${type}" | grep -q ",1,"; then
            currentUser="{\"uuid\":\"${uuid}\",\"name\":\"${name}-VLESS_WS\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # VMess ws
        if echo "${type}" | grep -q ",3,"; then
            currentUser="{\"uuid\":\"${uuid}\",\"name\":\"${name}-VMess_WS\",\"alterId\": 0}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # trojan
        if echo "${type}" | grep -q ",4,"; then
            currentUser="{\"password\":\"${uuid}\",\"name\":\"${name}-Trojan_TCP\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # VLESS Reality Vision
        if echo "${type}" | grep -q ",7,"; then
            currentUser="{\"uuid\":\"${uuid}\",\"flow\":\"xtls-rprx-vision\",\"name\":\"${name}-VLESS_Reality_Vision\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # VLESS Reality gRPC
        if echo "${type}" | grep -q ",8,"; then
            currentUser="{\"uuid\":\"${uuid}\",\"name\":\"${name}-VLESS_Reality_gPRC\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # hysteria2
        if echo "${type}" | grep -q ",6,"; then
            currentUser="{\"password\":\"${uuid}\",\"name\":\"${name}-singbox_hysteria2\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # tuic
        if echo "${type}" | grep -q ",9,"; then
            currentUser="{\"uuid\":\"${uuid}\",\"password\":\"${uuid}\",\"name\":\"${name}-singbox_tuic\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        # naive
        if echo "${type}" | grep -q ",10,"; then
            currentUser="{\"password\":\"${uuid}\",\"username\":\"${name}-singbox_naive\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # VMess HTTPUpgrade
        if echo "${type}" | grep -q ",11,"; then
            currentUser="{\"uuid\":\"${uuid}\",\"name\":\"${name}-VMess_HTTPUpgrade\",\"alterId\": 0}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi
        # anytls
        if echo "${type}" | grep -q ",13,"; then
            currentUser="{\"password\":\"${uuid}\",\"name\":\"${name}-anytls\"}"
            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

        if echo "${type}" | grep -q ",20,"; then
            currentUser="{\"username\":\"${uuid}\",\"password\":\"${uuid}\"}"

            users=$(echo "${users}" | jq -r ". +=[${currentUser}]")
        fi

    done < <(echo "${currentClients}" | jq -c '.[]')
    echo "${users}"
}

#Initialize hysteria port
initHysteriaPort() {
    readSingBoxConfig
    if [[ -n "${hysteriaPort}" ]]; then
        read -r -p "Read the port from the last installation. Do you want to use the port from the last installation? [y/n]:" historyHysteriaPortStatus
        if [[ "${historyHysteriaPortStatus}" == "y" ]]; then
    echoContent yellow "4.Open v2ray-core"
        else
            hysteriaPort=
        fi
    fi

    if [[ -z "${hysteriaPort}" ]]; then
    echoContent yellow "5.Restart v2ray-core"
        read -r -p "Port:" hysteriaPort
        if [[ -z "${hysteriaPort}" ]]; then
            hysteriaPort=$((RANDOM % 20001 + 10000))
        fi
    fi
    if [[ -z ${hysteriaPort} ]]; then
            echoContent red "Hysteria startup failed"
        initHysteriaPort "$2"
    elif ((hysteriaPort < 1 || hysteriaPort > 65535)); then
            echoContent red "Please manually execute [/etc/v2ray-agent/hysteria/hysteria --log-level debug -c /etc/v2ray-agent/hysteria/conf/config.json server] to view the error log"
        initHysteriaPort "$2"
    fi
    allowPort "${hysteriaPort}"
    allowPort "${hysteriaPort}" "udp"
}

initHysteria2Network() {

    echoContent yellow "6.Update geosite, geoip"
    read -r -p "Download speed:" hysteria2ClientDownloadSpeed
    if [[ -z "${hysteria2ClientDownloadSpeed}" ]]; then
        hysteria2ClientDownloadSpeed=100
        echoContent green " ---> Service started successfully"
    fi

    echoContent yellow "7.Set up automatic update of geo files [updated every morning]"
    read -r -p "Upload speed:" hysteria2ClientUploadSpeed
    if [[ -z "${hysteria2ClientUploadSpeed}" ]]; then
        hysteria2ClientUploadSpeed=50
        echoContent green " ---> Service started successfully"
    fi
}

addFirewalldPortHopping() {

    local start=$1
    local end=$2
    local targetPort=$3
    for port in $(seq "$start" "$end"); do
        sudo firewall-cmd --permanent --add-forward-port=port="${port}":proto=udp:toport="${targetPort}"
    done
    sudo firewall-cmd --reload
}

addPortHopping() {
    local type=$1
    local targetPort=$2
    if [[ -n "${portHoppingStart}" || -n "${portHoppingEnd}" ]]; then
            echoContent red "Hysteria shutdown failed"
        exit 0
    fi
    if [[ "${release}" == "centos" ]]; then
        if ! systemctl status firewalld 2>/dev/null | grep -q "active (running)"; then
            echoContent red "Please execute manually [ps -ef|grep -v grep|grep hysteria|awk '{print \$2}'|xargs kill -9]"
            exit 0
        fi
    fi

        echoContent skyBlue "------------------------Version-------------------------------"
    echoContent red "\n=============================================================="
        echoContent yellow "\n1.Only the last five versions can be rolled back"
        echoContent yellow "2.There is no guarantee that it will be able to be used normally after the rollback"
        echoContent yellow "3.If the rolled-back version does not support the current config, it will be unable to connect, so operate with caution"
    echoContent yellow "1.Upgrade Xray-core"
    echoContent yellow "2.Upgrade Xray-core preview version"
    echoContent yellow "3.Fallback Xray-core"
    echoContent yellow "4.Close Xray-core"

    echoContent yellow "5.Open Xray-core"

    read -r -p "Range:" portHoppingRange
    if [[ -z "${portHoppingRange}" ]]; then
            echoContent red "Tuic startup failed"
        addPortHopping "${type}" "${targetPort}"
    elif echo "${portHoppingRange}" | grep -q "-"; then

        local portStart=
        local portEnd=
        portStart=$(echo "${portHoppingRange}" | awk -F '-' '{print $1}')
        portEnd=$(echo "${portHoppingRange}" | awk -F '-' '{print $2}')

        if [[ -z "${portStart}" || -z "${portEnd}" ]]; then
            echoContent red "Please manually execute [/etc/v2ray-agent/tuic/tuic -c /etc/v2ray-agent/tuic/conf/config.json] and check the error log"
            addPortHopping "${type}" "${targetPort}"
        elif ((portStart < 30000 || portStart > 40000 || portEnd < 30000 || portEnd > 40000 || portEnd < portStart)); then
            echoContent red "Tuic failed to close"
            addPortHopping "${type}" "${targetPort}"
        else
        echoContent green " ---> Configure V2Ray to start automatically at boot"
            if [[ "${release}" == "centos" ]]; then
                sudo firewall-cmd --permanent --add-masquerade
                sudo firewall-cmd --reload
                addFirewalldPortHopping "${portStart}" "${portEnd}" "${targetPort}"
                if ! sudo firewall-cmd --list-forward-ports | grep -q "toport=${targetPort}"; then
            echoContent red "Please execute manually [ps -ef|grep -v grep|grep tuic|awk '{print \$2}'|xargs kill -9]"
                    exit 0
                fi
            else
                iptables -t nat -A PREROUTING -p udp --dport "${portStart}:${portEnd}" -m comment --comment "mack-a_${type}_portHopping" -j DNAT --to-destination ":${targetPort}"
                sudo netfilter-persistent save
                if ! iptables-save | grep -q "mack-a_${type}_portHopping"; then
            echoContent red "Xray startup failed"
                    exit 0
                fi
            fi
            allowPort "${portStart}:${portEnd}" udp
        echoContent green " ---> Configure Hysteria to start automatically at boot"
        fi
    fi
}

readPortHopping() {
    local type=$1
    local targetPort=$2
    local portHoppingStart=
    local portHoppingEnd=

    if [[ "${release}" == "centos" ]]; then
        portHoppingStart=$(sudo firewall-cmd --list-forward-ports | grep "toport=${targetPort}" | head -1 | cut -d ":" -f 1 | cut -d "=" -f 2)
        portHoppingEnd=$(sudo firewall-cmd --list-forward-ports | grep "toport=${targetPort}" | tail -n 1 | cut -d ":" -f 1 | cut -d "=" -f 2)
    else
        if iptables-save | grep -q "mack-a_${type}_portHopping"; then
            local portHopping=
            portHopping=$(iptables-save | grep "mack-a_${type}_portHopping" | cut -d " " -f 8)

            portHoppingStart=$(echo "${portHopping}" | cut -d ":" -f 1)
            portHoppingEnd=$(echo "${portHopping}" | cut -d ":" -f 2)
        fi
    fi
    if [[ "${type}" == "hysteria2" ]]; then
        hysteria2PortHoppingStart="${portHoppingStart}"
        hysteria2PortHoppingEnd=${portHoppingEnd}
        hysteria2PortHopping="${portHoppingStart}-${portHoppingEnd}"
    elif [[ "${type}" == "tuic" ]]; then
        tuicPortHoppingStart="${portHoppingStart}"
        tuicPortHoppingEnd="${portHoppingEnd}"
        #        tuicPortHopping="${portHoppingStart}-${portHoppingEnd}"
    fi
}
deletePortHoppingRules() {
    local type=$1
    local start=$2
    local end=$3
    local targetPort=$4

    if [[ "${release}" == "centos" ]]; then
        for port in $(seq "${start}" "${end}"); do
            sudo firewall-cmd --permanent --remove-forward-port=port="${port}":proto=udp:toport="${targetPort}"
        done
        sudo firewall-cmd --reload
    else
        iptables -t nat -L PREROUTING --line-numbers | grep "mack-a_${type}_portHopping" | awk '{print $1}' | while read -r line; do
            iptables -t nat -D PREROUTING 1
            sudo netfilter-persistent save
        done
    fi
}

portHoppingMenu() {
    local type=$1
    # Determine whether iptables exists
    if ! find /usr/bin /usr/sbin | grep -q -w iptables; then
            echoContent red "Please manually execute the following command [/etc/v2ray-agent/xray/xray -confdir /etc/v2ray-agent/xray/conf] and feedback the error log"
        exit 0
    fi

    local targetPort=
    local portHoppingStart=
    local portHoppingEnd=

    if [[ "${type}" == "hysteria2" ]]; then
        readPortHopping "${type}" "${singBoxHysteria2Port}"
        targetPort=${singBoxHysteria2Port}
        portHoppingStart=${hysteria2PortHoppingStart}
        portHoppingEnd=${hysteria2PortHoppingEnd}
    elif [[ "${type}" == "tuic" ]]; then
        readPortHopping "${type}" "${singBoxTuicPort}"
        targetPort=${singBoxTuicPort}
        portHoppingStart=${tuicPortHoppingStart}
        portHoppingEnd=${tuicPortHoppingEnd}
    fi

    echoContent skyBlue "\nProgress$1/${totalProgress}: V2Ray version management"
    echoContent red "\n=============================================================="
    echoContent yellow "6.Restart Xray-core"
    echoContent yellow "7.Update geosite, geoip"
    echoContent yellow "8.Set up automatic update of geo files [updated every morning]"
    read -r -p "range:" selectPortHoppingStatus
    if [[ "${selectPortHoppingStatus}" == "1" ]]; then
        addPortHopping "${type}" "${targetPort}"
    elif [[ "${selectPortHoppingStatus}" == "2" ]]; then
        deletePortHoppingRules "${type}" "${portHoppingStart}" "${portHoppingEnd}" "${targetPort}"
        echoContent green " ---> Configuring Tuic to start automatically at boot"
    elif [[ "${selectPortHoppingStatus}" == "3" ]]; then
        if [[ -n "${portHoppingStart}" && -n "${portHoppingEnd}" ]]; then
        echoContent green " ---> Configure Xray to start automatically at boot"
        else
        echoContent yellow "\n1.Only the last five versions can be rolled back"
        fi
    else
        portHoppingMenu
    fi
}

#Initialize tuic port
initTuicPort() {
    readSingBoxConfig
    if [[ -n "${tuicPort}" ]]; then
        read -r -p "Read the port from the last installation. Do you want to use the port from the last installation? [y/n]:" historyTuicPortStatus
        if [[ "${historyTuicPortStatus}" == "y" ]]; then
        echoContent yellow "2.There is no guarantee that it will be able to be used normally after the rollback"
        else
            tuicPort=
        fi
    fi

    if [[ -z "${tuicPort}" ]]; then
        echoContent yellow "3.If the rolled-back version does not support the current config, it will be unable to connect, so operate with caution"
        read -r -p "Port:" tuicPort
        if [[ -z "${tuicPort}" ]]; then
            tuicPort=$((RANDOM % 20001 + 10000))
        fi
    fi
    if [[ -z ${tuicPort} ]]; then
            echoContent red "xray failed to close"
        initTuicPort "$2"
    elif ((tuicPort < 1 || tuicPort > 65535)); then
            echoContent red "Please execute manually [ps -ef|grep -v grep|grep xray|awk '{print \$2}'|xargs kill -9]"
        initTuicPort "$2"
    fi
            echoContent green " ---> V2Ray started successfully"
    allowPort "${tuicPort}"
    allowPort "${tuicPort}" "udp"
}

# Initialize tuic protocol
initTuicProtocol() {
    if [[ -n "${tuicAlgorithm}" && -z "${lastInstallationConfig}" ]]; then
        read -r -p "Previous algorithm found. Use it? [y/n]:" historyTuicAlgorithm
        if [[ "${historyTuicAlgorithm}" != "y" ]]; then
            tuicAlgorithm=
        else
    echoContent yellow "\nSource https://github.com/Loyalsoldier/v2ray-rules-dat"
        fi
    elif [[ -n "${tuicAlgorithm}" && -n "${lastInstallationConfig}" ]]; then
            echoContent yellow "The configuration file last installed for this protocol [${protocol}] was not read, and the first uuid of the configuration file was used"
    fi

    if [[ -z "${tuicAlgorithm}" ]]; then

        echoContent skyBlue "------------------------Version-------------------------------"
        echoContent red "=============================================================="
            echoContent yellow "\n ---> Port: ${hysteriaPort}"
        echoContent yellow "2.cubic"
        echoContent yellow "3.new_reno"
        echoContent red "=============================================================="
    read -r -p "Please select:" selectTuicAlgorithm
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
        echoContent yellow "Please enter the Hysteria port [enter random 10000-30000], cannot be repeated with other services"
    fi
}

#initTuicConfig() {
#
#    initTuicPort
#    initTuicProtocol
#    cat <<EOF >/etc/v2ray-agent/tuic/conf/config.json
#{
#    "server": "[::]:${tuicPort}",
#    "users": $(initXrayClients 9),
#    "certificate": "/etc/v2ray-agent/tls/${currentHost}.crt",
#    "private_key": "/etc/v2ray-agent/tls/${currentHost}.key",
#    "congestion_control":"${tuicAlgorithm}",
#    "alpn": ["h3"],
#    "log_level": "warn"
#}
#EOF
#}

addSingBoxRouteRule() {
    local outboundTag=$1
    local domainList=$2
    local routingName=$3
    if [[ -f "${singBoxConfigPath}${routingName}.json" ]]; then
        read -r -p "Previous configuration found. Keep it? [y/n]:" historyRouteStatus
        if [[ "${historyRouteStatus}" == "y" ]]; then
            domainList="${domainList},$(jq -rc .route.rules[0].rule_set[] "${singBoxConfigPath}${routingName}.json" | awk -F "[_]" '{print $1}' | paste -sd ',')"
            domainList="${domainList},$(jq -rc .route.rules[0].domain_regex[] "${singBoxConfigPath}${routingName}.json" | awk -F "[*]" '{print $2}' | paste -sd ',' | sed 's/\\//g')"
        fi

    fi
    local rules=
    rules=$(initSingBoxRules "${domainList}" "${routingName}")
    local domainRules=
    domainRules=$(echo "${rules}" | jq .domainRules)

    local ruleSet=
    ruleSet=$(echo "${rules}" | jq .ruleSet)

    local ruleSetTag=[]
    if [[ "$(echo "${ruleSet}" | jq '.|length')" != "0" ]]; then
        ruleSetTag=$(echo "${ruleSet}" | jq '.|map(.tag)')
    fi
    if [[ -n "${singBoxConfigPath}" ]]; then
        cat <<EOF >"${singBoxConfigPath}${routingName}.json"
{
  "route": {
    "rules": [
      {
        "rule_set":${ruleSetTag},
        "domain_regex":${domainRules},
        "outbound": "${outboundTag}"
      }
    ],
    "rule_set":${ruleSet}
  }
}
EOF
        jq 'if .route.rule_set == [] then del(.route.rule_set) else . end' "${singBoxConfigPath}${routingName}.json" >"${singBoxConfigPath}${routingName}_tmp.json" && mv "${singBoxConfigPath}${routingName}_tmp.json" "${singBoxConfigPath}${routingName}.json"
    fi

}

removeSingBoxRouteRule() {
    local outboundTag=$1
    local delRules
    if [[ -f "${singBoxConfigPath}${outboundTag}_route.json" ]]; then
        delRules=$(jq -r 'del(.route.rules[]|select(.outbound=="'"${outboundTag}"'"))' "${singBoxConfigPath}${outboundTag}_route.json")
        echo "${delRules}" >"${singBoxConfigPath}${outboundTag}_route.json"
    fi
}

addSingBoxOutbound() {
    local tag=$1
    local type="ipv4"
    local detour=$2
    if echo "${tag}" | grep -q "IPv6"; then
        type=ipv6
    fi
    if [[ -n "${detour}" ]]; then
        cat <<EOF >"${singBoxConfigPath}${tag}.json"
{
     "outbounds": [
        {
             "type": "direct",
             "tag": "${tag}",
             "detour": "${detour}",
             "domain_strategy": "${type}_only"
        }
    ]
}
EOF
    elif echo "${tag}" | grep -q "direct"; then

        cat <<EOF >"${singBoxConfigPath}${tag}.json"
{
     "outbounds": [
        {
             "type": "direct",
             "tag": "${tag}"
        }
    ]
}
EOF
    elif echo "${tag}" | grep -q "block"; then

        cat <<EOF >"${singBoxConfigPath}${tag}.json"
{
     "outbounds": [
        {
             "type": "block",
             "tag": "${tag}"
        }
    ]
}
EOF
    else
        cat <<EOF >"${singBoxConfigPath}${tag}.json"
{
     "outbounds": [
        {
             "type": "direct",
             "tag": "${tag}",
             "domain_strategy": "${type}_only"
        }
    ]
}
EOF
    fi
}

addXrayOutbound() {
    local tag=$1
    local domainStrategy=

    if echo "${tag}" | grep -q "IPv4"; then
        domainStrategy="ForceIPv4"
    elif echo "${tag}" | grep -q "IPv6"; then
        domainStrategy="ForceIPv6"
    fi

    if [[ -n "${domainStrategy}" ]]; then
        cat <<EOF >"/etc/v2ray-agent/xray/conf/${tag}.json"
{
    "outbounds":[
        {
            "protocol":"freedom",
            "settings":{
                "domainStrategy":"${domainStrategy}"
            },
            "tag":"${tag}"
        }
    ]
}
EOF
    fi
    # direct
    if echo "${tag}" | grep -q "direct"; then
        cat <<EOF >"/etc/v2ray-agent/xray/conf/${tag}.json"
{
    "outbounds":[
        {
            "protocol":"freedom",
            "settings": {
                "domainStrategy":"UseIP"
            },
            "tag":"${tag}"
        }
    ]
}
EOF
    fi
    # blackhole
    if echo "${tag}" | grep -q "blackhole"; then
        cat <<EOF >"/etc/v2ray-agent/xray/conf/${tag}.json"
{
    "outbounds":[
        {
            "protocol":"blackhole",
            "tag":"${tag}"
        }
    ]
}
EOF
    fi
    # socks5 outbound
    if echo "${tag}" | grep -q "socks5"; then
        cat <<EOF >"/etc/v2ray-agent/xray/conf/${tag}.json"
{
  "outbounds": [
    {
      "protocol": "socks",
      "tag": "${tag}",
      "settings": {
        "servers": [
          {
            "address": "${socks5RoutingOutboundIP}",
            "port": ${socks5RoutingOutboundPort},
            "users": [
              {
                "user": "${socks5RoutingOutboundUserName}",
                "pass": "${socks5RoutingOutboundPassword}"
              }
            ]
          }
        ]
      }
    }
  ]
}
EOF
    fi
    if echo "${tag}" | grep -q "wireguard_out_IPv4"; then
        cat <<EOF >"/etc/v2ray-agent/xray/conf/${tag}.json"
{
  "outbounds": [
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
      "tag": "${tag}"
    }
  ]
}
EOF
    fi
    if echo "${tag}" | grep -q "wireguard_out_IPv6"; then
        cat <<EOF >"/etc/v2ray-agent/xray/conf/${tag}.json"
{
  "outbounds": [
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
      "tag": "${tag}"
    }
  ]
}
EOF
    fi
    if echo "${tag}" | grep -q "vmess-out"; then
        cat <<EOF >"/etc/v2ray-agent/xray/conf/${tag}.json"
{
  "outbounds": [
    {
      "tag": "${tag}",
      "protocol": "vmess",
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {},
        "wsSettings": {
          "path": "${setVMessWSTLSPath}"
        }
      },
      "mux": {
        "enabled": true,
        "concurrency": 8
      },
      "settings": {
        "vnext": [
          {
            "address": "${setVMessWSTLSAddress}",
            "port": "${setVMessWSTLSPort}",
            "users": [
              {
                "id": "${setVMessWSTLSUUID}",
                "security": "auto",
                "alterId": 0
              }
            ]
          }
        ]
      }
    }
  ]
}
EOF
    fi
}

removeXrayOutbound() {
    local tag=$1
    if [[ -f "/etc/v2ray-agent/xray/conf/${tag}.json" ]]; then
        rm "/etc/v2ray-agent/xray/conf/${tag}.json" >/dev/null 2>&1
    fi
}
removeSingBoxConfig() {

    local tag=$1
    if [[ -f "${singBoxConfigPath}${tag}.json" ]]; then
        rm "${singBoxConfigPath}${tag}.json"
    fi
}

addSingBoxWireGuardEndpoints() {
    local type=$1

    readConfigWarpReg

    cat <<EOF >"${singBoxConfigPath}wireguard_endpoints_${type}.json"
{
     "endpoints": [
        {
            "type": "wireguard",
            "tag": "wireguard_endpoints_${type}",
            "address": [
                "${address}"
            ],
            "private_key": "${secretKeyWarpReg}",
            "peers": [
                {
                  "address": "162.159.192.1",
                  "port": 2408,
                  "public_key": "${publicKeyWarpReg}",
                  "reserved":${reservedWarpReg},
                  "allowed_ips": ["0.0.0.0/0","::/0"]
                }
            ]
        }
    ]
}
EOF
}

initSingBoxHysteria2Config() {
        echoContent skyBlue "------------------------------------------------- ---------------"

    initHysteriaPort
    initHysteria2Network

    cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/hysteria2.json
{
    "inbounds": [
        {
            "type": "hysteria2",
            "listen": "::",
            "listen_port": ${hysteriaPort},
            "users": $(initXrayClients 6),
            "up_mbps":${hysteria2ClientDownloadSpeed},
            "down_mbps":${hysteria2ClientUploadSpeed},
            "tls": {
                "enabled": true,
                "server_name":"${currentHost}",
                "alpn": [
                    "h3"
                ],
                "certificate_path": "/etc/v2ray-agent/tls/${currentHost}.crt",
                "key_path": "/etc/v2ray-agent/tls/${currentHost}.key"
            }
        }
    ]
}
EOF
}

singBoxTuicInstall() {
    if ! echo "${currentInstallProtocolType}" | grep -qE ",0,|,1,|,2,|,3,|,4,|,5,|,6,|,9,|,10,"; then
        echoContent red " ---> Port cannot be empty"
        exit 0
    fi

    totalProgress=5
    installSingBox 1
    selectCustomInstallType=",9,"
    initSingBoxConfig custom 2 true
    installSingBoxService 3
    reloadCore
    showAccounts 4
}

singBoxHysteria2Install() {
    if ! echo "${currentInstallProtocolType}" | grep -qE ",0,|,1,|,2,|,3,|,4,|,5,|,6,|,9,|,10,"; then
        echoContent red " ---> The port is illegal"
        exit 0
    fi

    totalProgress=5
    installSingBox 1
    selectCustomInstallType=",6,"
    initSingBoxConfig custom 2 true
    installSingBoxService 3
    reloadCore
    showAccounts 4
}

singBoxMergeConfig() {
    rm /etc/v2ray-agent/sing-box/conf/config.json >/dev/null 2>&1
    /etc/v2ray-agent/sing-box/sing-box merge config.json -C /etc/v2ray-agent/sing-box/conf/config/ -D /etc/v2ray-agent/sing-box/conf/ >/dev/null 2>&1
}

#initXrayFrontingConfig() {
#    if [[ -z "${configPath}" ]]; then
#        menu
#        exit 0
#    fi
#    if [[ "${coreInstallType}" != "1" ]]; then
#    fi
#    local xtlsType=
#    if echo ${currentInstallProtocolType} | grep -q trojan; then
#        xtlsType=VLESS
#    else
#        xtlsType=Trojan
#    fi
#
#    echoContent red "\n=============================================================="
#
#    echoContent red "=============================================================="
#    if [[ "${selectType}" == "1" ]]; then
#
#        if [[ "${xtlsType}" == "Trojan" ]]; then
#
#            local VLESSConfig
#            VLESSConfig=$(cat ${configPath}${frontingType}.json)
#            VLESSConfig=${VLESSConfig//"id"/"password"}
#            VLESSConfig=${VLESSConfig//VLESSTCP/TrojanTCPXTLS}
#            VLESSConfig=${VLESSConfig//VLESS/Trojan}
#            VLESSConfig=${VLESSConfig//"vless"/"trojan"}
#            VLESSConfig=${VLESSConfig//"id"/"password"}
#
#            echo "${VLESSConfig}" | jq . >${configPath}02_trojan_TCP_inbounds.json
#            rm ${configPath}${frontingType}.json
#        elif [[ "${xtlsType}" == "VLESS" ]]; then
#
#            local VLESSConfig
#            VLESSConfig=$(cat ${configPath}02_trojan_TCP_inbounds.json)
#            VLESSConfig=${VLESSConfig//"password"/"id"}
#            VLESSConfig=${VLESSConfig//TrojanTCPXTLS/VLESSTCP}
#            VLESSConfig=${VLESSConfig//Trojan/VLESS}
#            VLESSConfig=${VLESSConfig//"trojan"/"vless"}
#            VLESSConfig=${VLESSConfig//"password"/"id"}
#
#            echo "${VLESSConfig}" | jq . >${configPath}02_VLESS_TCP_inbounds.json
#            rm ${configPath}02_trojan_TCP_inbounds.json
#        fi
#        reloadCore
#    fi
#
#    exit 0
#}

initSingBoxPort() {
    local port=$1
    if [[ -n "${port}" && -z "${lastInstallationConfig}" ]]; then
        read -r -p "Previous port found. Use it? [y/n]:" historyPort
        if [[ "${historyPort}" != "y" ]]; then
            port=
        else
            echo "${port}"
        fi
    elif [[ -n "${port}" && -n "${lastInstallationConfig}" ]]; then
        echo "${port}"
    fi
    if [[ -z "${port}" ]]; then
        read -r -p 'Enter a custom port [must be valid and unique; Enter for random]:' port
        if [[ -z "${port}" ]]; then
            port=$((RANDOM % 50001 + 10000))
        fi
        if ((port >= 1 && port <= 65535)); then
            allowPort "${port}"
            allowPort "${port}" "udp"
            echo "${port}"
        else
    echoContent red "================================================== ==============="
            exit 0
        fi
    fi
}

#Initialize Xray configuration file
initXrayConfig() {
    echoContent skyBlue "\nProgress$1/${totalProgress}: Xray version management"
    echo
    local uuid=
    local addClientsStatus=
    if [[ -n "${currentUUID}" && -z "${lastInstallationConfig}" ]]; then
        read -r -p "Read the last installation record. Do you want to use the UUID from the last installation? [y/n]:" historyUUIDStatus
        if [[ "${historyUUIDStatus}" == "y" ]]; then
            addClientsStatus=true
            echoContent green " ---> V2Ray closed successfully"
        fi
    elif [[ -n "${currentUUID}" && -n "${lastInstallationConfig}" ]]; then
        addClientsStatus=true
    fi

    if [[ -z "${addClientsStatus}" ]]; then
    echoContent yellow "1.udp(QUIC)(default)"
        read -r -p 'UUID:' customUUID

        if [[ -n ${customUUID} ]]; then
            uuid=${customUUID}
        else
            uuid=$(/etc/v2ray-agent/xray/xray uuid)
        fi

    echoContent yellow "2.faketcp"
        read -r -p 'Username:' customEmail
        if [[ -z ${customEmail} ]]; then
            customEmail="$(echo "${uuid}" | cut -d "-" -f 1)-VLESS_TCP/TLS_Vision"
        fi
    fi

    if [[ -z "${addClientsStatus}" && -z "${uuid}" ]]; then
        addClientsStatus=
    echoContent red "================================================== ==============="
        uuid=$(/etc/v2ray-agent/xray/xray uuid)
    fi

    if [[ -n "${uuid}" ]]; then
        currentClients='[{"id":"'${uuid}'","add":"'${add}'","flow":"xtls-rprx-vision","email":"'${customEmail}'"}]'
        echoContent green "\n ${customEmail}:${uuid}"
        echo
    fi

    # log
    #log
    if [[ ! -f "/etc/v2ray-agent/xray/conf/00_log.json" ]]; then

        cat <<EOF >/etc/v2ray-agent/xray/conf/00_log.json
{
  "log": {
    "error": "/etc/v2ray-agent/xray/error.log",
    "loglevel": "warning",
    "dnsLog": false
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

    addXrayOutbound "z_direct_outbound"
    # dns
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
    cat <<EOF >/etc/v2ray-agent/xray/conf/09_routing.json
{
  "routing": {
    "rules": [
      {
        "type": "field",
        "domain": [
          "domain:gstatic.com",
          "domain:googleapis.com",
	  "domain:googleapis.cn"
        ],
        "outboundTag": "z_direct_outbound"
      }
    ]
  }
}
EOF
    # VLESS_TCP_TLS_Vision
    local fallbacksList='{"dest":31300,"xver":1},{"alpn":"h2","dest":31302,"xver":1}'

    # trojan
    if echo "${selectCustomInstallType}" | grep -q ",4," || [[ "$1" == "all" ]]; then
        fallbacksList='{"dest":31296,"xver":1},{"alpn":"h2","dest":31302,"xver":1}'
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
			{
			    "dest":"31300",
			    "xver":1
			}
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
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/xray/conf/04_trojan_TCP_inbounds.json >/dev/null 2>&1
    fi

    # VLESS_WS_TLS
    if echo "${selectCustomInstallType}" | grep -q ",1," || [[ "$1" == "all" ]]; then
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
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/xray/conf/03_VLESS_WS_inbounds.json >/dev/null 2>&1
    fi
    # VLESS_Reality_XHTTP_TLS
    if echo "${selectCustomInstallType}" | grep -q ",12," || [[ "$1" == "all" ]]; then
        initXrayXHTTPort
        initRealityClientServersName
        initRealityKey
        initRealityMldsa65
        cat <<EOF >/etc/v2ray-agent/xray/conf/12_VLESS_XHTTP_inbounds.json
{
"inbounds":[
    {
	  "port": ${xHTTPort},
	  "listen": "0.0.0.0",
	  "protocol": "vless",
	  "tag":"VLESSRealityXHTTP",
	  "settings": {
		"clients": $(initXrayClients 12),
		"decryption": "none"
	  },
	  "streamSettings": {
		"network": "xhttp",
		"security": "reality",
		"realitySettings": {
            "show": false,
            "target": "${realityServerName}:${realityDomainPort}",
            "xver": 0,
            "serverNames": [
                "${realityServerName}"
            ],
            "privateKey": "${realityPrivateKey}",
            "publicKey": "${realityPublicKey}",
            "mldsa65Seed": "${realityMldsa65Seed}",
            "mldsa65Verify": "${realityMldsa65Verify}",
            "minClientVer": "1.8.2",
            "maxTimeDiff": 70000,
            "shortIds": [
                "",
                "6ba85179e30d4fc2"
            ]
        },
        "xhttpSettings": {
            "host": "${realityServerName}",
            "path": "/${customPath}xHTTP",
            "mode": "auto"
        }
	  }
	}
]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/xray/conf/12_VLESS_XHTTP_inbounds.json >/dev/null 2>&1
    fi
    if echo "${selectCustomInstallType}" | grep -q ",3," || [[ "$1" == "all" ]]; then
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
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/xray/conf/05_VMess_WS_inbounds.json >/dev/null 2>&1
    fi
    # VLESS_gRPC
    #    if echo "${selectCustomInstallType}" | grep -q ",5," || [[ "$1" == "all" ]]; then
    #        cat <<EOF >/etc/v2ray-agent/xray/conf/06_VLESS_gRPC_inbounds.json
    #{
    #    "inbounds":[
    #        {
    #            "port": 31301,
    #            "listen": "127.0.0.1",
    #            "protocol": "vless",
    #            "tag":"VLESSGRPC",
    #            "settings": {
    #                "clients": $(initXrayClients 5),
    #                "decryption": "none"
    #            },
    #            "streamSettings": {
    #                "network": "grpc",
    #                "grpcSettings": {
    #                    "serviceName": "${customPath}grpc"
    #                }
    #            }
    #        }
    #    ]
    #}
    #EOF
    #    elif [[ -z "$3" ]]; then
    #        rm /etc/v2ray-agent/xray/conf/06_VLESS_gRPC_inbounds.json >/dev/null 2>&1
    #    fi

    # VLESS Vision
    if echo "${selectCustomInstallType}" | grep -q ",0," || [[ "$1" == "all" ]]; then

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
              "rejectUnknownSni": true,
              "minVersion": "1.2",
              "certificates": [
                {
                  "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
                  "keyFile": "/etc/v2ray-agent/tls/${domain}.key",
                  "ocspStapling": 3600
                }
              ]
            }
          }
        }
    ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json >/dev/null 2>&1
    fi

    # VLESS_TCP/reality
    if echo "${selectCustomInstallType}" | grep -q ",7," || [[ "$1" == "all" ]]; then
        echoContent skyBlue "------------------------Version-------------------------------"

        initXrayRealityPort
        initRealityClientServersName
        initRealityKey
        initRealityMldsa65
        cat <<EOF >/etc/v2ray-agent/xray/conf/07_VLESS_vision_reality_inbounds.json
{
  "inbounds": [
    {
      "tag": "dokodemo-in-VLESSReality",
      "port": ${realityPort},
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1",
        "port": 45987,
        "network": "tcp"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "tls"
        ],
        "routeOnly": true
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 45987,
      "protocol": "vless",
      "settings": {
        "clients": $(initXrayClients 7),
        "decryption": "none",
        "fallbacks":[
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "${realityServerName}:${realityDomainPort}",
          "xver": 0,
          "serverNames": [
            "${realityServerName}"
          ],
          "privateKey": "${realityPrivateKey}",
          "publicKey": "${realityPublicKey}",
          "mldsa65Seed": "${realityMldsa65Seed}",
          "mldsa65Verify": "${realityMldsa65Verify}",
          "minClientVer": "1.8.2",
          "maxTimeDiff": 70000,
          "shortIds": [
            "",
            "6ba85179e30d4fc2"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ],
        "routeOnly": true
      }
    }
  ],
  "routing": {
    "rules": [
      {
        "inboundTag": [
          "dokodemo-in"
        ],
        "domain": [
          "${realityServerName}"
        ],
        "outboundTag": "z_direct_outbound"
      },
      {
        "inboundTag": [
          "dokodemo-in"
        ],
        "outboundTag": "blackhole_out"
      }
    ]
  }
}
EOF
        #        cat <<EOF >/etc/v2ray-agent/xray/conf/08_VLESS_vision_gRPC_inbounds.json
        #{
        #  "inbounds": [
        #    {
        #      "port": 31305,
        #      "listen": "127.0.0.1",
        #      "protocol": "vless",
        #      "tag": "VLESSRealityGRPC",
        #      "settings": {
        #        "clients": $(initXrayClients 8),
        #        "decryption": "none"
        #      },
        #      "streamSettings": {
        #            "network": "grpc",
        #            "grpcSettings": {
        #                "serviceName": "grpc",
        #                "multiMode": true
        #            },
        #            "sockopt": {
        #                "acceptProxyProtocol": true
        #            }
        #      }
        #    }
        #  ]
        #}
        #EOF

    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/xray/conf/07_VLESS_vision_reality_inbounds.json >/dev/null 2>&1
        rm /etc/v2ray-agent/xray/conf/08_VLESS_vision_gRPC_inbounds.json >/dev/null 2>&1
    fi
    installSniffing
    if [[ -z "$3" ]]; then
        removeXrayOutbound wireguard_out_IPv4_route
        removeXrayOutbound wireguard_out_IPv6_route
        removeXrayOutbound wireguard_outbound
        removeXrayOutbound IPv4_out
        removeXrayOutbound IPv6_out
        removeXrayOutbound socks5_outbound
        removeXrayOutbound blackhole_out
        removeXrayOutbound wireguard_out_IPv6
        removeXrayOutbound wireguard_out_IPv4
        addXrayOutbound z_direct_outbound
        addXrayOutbound blackhole_out
    fi
}

initTCPBrutal() {
        echoContent skyBlue "------------------------------------------------- ---------------"
    read -r -p "Use TCP_Brutal? [y/n]:" tcpBrutalStatus
    if [[ "${tcpBrutalStatus}" == "y" ]]; then
        read -r -p "Enter local peak download speed (default: 100 Mbps):" tcpBrutalClientDownloadSpeed
        if [[ -z "${tcpBrutalClientDownloadSpeed}" ]]; then
            tcpBrutalClientDownloadSpeed=100
        fi

        read -r -p "Enter local peak upload speed (default: 50 Mbps):" tcpBrutalClientUploadSpeed
        if [[ -z "${tcpBrutalClientUploadSpeed}" ]]; then
            tcpBrutalClientUploadSpeed=50
        fi
    fi
}
initSingBoxConfig() {
    echoContent skyBlue "------------------------Version-------------------------------"

    echo
    local uuid=
    local addClientsStatus=
    local sslDomain=
    if [[ -n "${domain}" ]]; then
        sslDomain="${domain}"
    elif [[ -n "${currentHost}" ]]; then
        sslDomain="${currentHost}"
    fi
    if [[ -n "${currentUUID}" && -z "${lastInstallationConfig}" ]]; then
        read -r -p "Read the last user configuration. Do you want to use the last installed configuration? [y/n]:" historyUUIDStatus
        if [[ "${historyUUIDStatus}" == "y" ]]; then
            addClientsStatus=true
            echoContent green " ---> Hysteria started successfully"
        fi
    elif [[ -n "${currentUUID}" && -n "${lastInstallationConfig}" ]]; then
        addClientsStatus=true
    fi

    if [[ -z "${addClientsStatus}" ]]; then
    echoContent yellow "3.wechat-video"
        read -r -p 'UUID:' customUUID

        if [[ -n ${customUUID} ]]; then
            uuid=${customUUID}
        else
            uuid=$(/etc/v2ray-agent/sing-box/sing-box generate uuid)
        fi

    echoContent yellow "\n ---> Protocol: ${hysteriaProtocol}\n"
        read -r -p 'Username:' customEmail
        if [[ -z ${customEmail} ]]; then
            customEmail="$(echo "${uuid}" | cut -d "-" -f 1)-VLESS_TCP/TLS_Vision"
        fi
    fi

    if [[ -z "${addClientsStatus}" && -z "${uuid}" ]]; then
        addClientsStatus=
        echoContent red " ---> Already added, cannot be added repeatedly, can be deleted and re-added"
        uuid=$(/etc/v2ray-agent/sing-box/sing-box generate uuid)
    fi

    if [[ -n "${uuid}" ]]; then
        currentClients='[{"uuid":"'${uuid}'","flow":"xtls-rprx-vision","name":"'${customEmail}'"}]'
        echoContent yellow "\n ${customEmail}:${uuid}"
    fi

    # VLESS Vision
    if echo "${selectCustomInstallType}" | grep -q ",0," || [[ "$1" == "all" ]]; then
    echoContent yellow "Please enter the average delay from local to server, please fill it in according to the actual situation (default: 180, unit: ms)"
    echoContent skyBlue "\nProgress$1/${totalProgress}: Verify service startup status"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxVLESSVisionPort}")
            echoContent green " ---> Hysteria closed successfully"

        checkDNSIP "${domain}"
        removeNginxDefaultConf
        handleSingBox stop

        checkPortOpen "${result[-1]}" "${domain}"
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/02_VLESS_TCP_inbounds.json
{
    "inbounds":[
        {
          "type": "vless",
          "listen":"::",
          "listen_port":${result[-1]},
          "tag":"VLESSTCP",
          "users":$(initSingBoxClients 0),
          "tls":{
            "server_name": "${sslDomain}",
            "enabled": true,
            "certificate_path": "/etc/v2ray-agent/tls/${sslDomain}.crt",
            "key_path": "/etc/v2ray-agent/tls/${sslDomain}.key"
          }
        }
    ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/02_VLESS_TCP_inbounds.json >/dev/null 2>&1
    fi

    if echo "${selectCustomInstallType}" | grep -q ",1," || [[ "$1" == "all" ]]; then
        echoContent yellow "\n ---> Delay: ${hysteriaLag}\n"
    echoContent skyBlue "\nProgress$1/${totalProgress}: Configure V2Ray to start automatically at boot"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxVLESSWSPort}")
            echoContent green " ---> Tuic started successfully"

        checkDNSIP "${domain}"
        removeNginxDefaultConf
        handleSingBox stop
        randomPathFunction
        checkPortOpen "${result[-1]}" "${domain}"
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/03_VLESS_WS_inbounds.json
{
    "inbounds":[
        {
          "type": "vless",
          "listen":"::",
          "listen_port":${result[-1]},
          "tag":"VLESSWS",
          "users":$(initSingBoxClients 1),
          "tls":{
            "server_name": "${sslDomain}",
            "enabled": true,
            "certificate_path": "/etc/v2ray-agent/tls/${sslDomain}.crt",
            "key_path": "/etc/v2ray-agent/tls/${sslDomain}.key"
          },
          "transport": {
            "type": "ws",
            "path": "/${currentPath}ws",
            "max_early_data": 2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
          }
        }
    ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/03_VLESS_WS_inbounds.json >/dev/null 2>&1
    fi

    if echo "${selectCustomInstallType}" | grep -q ",3," || [[ "$1" == "all" ]]; then
    echoContent yellow "Please enter the local bandwidth peak downstream speed (default: 100, unit: Mbps)"
    echoContent skyBlue "\nProgress$1/${totalProgress}: Configure Hysteria to start automatically at boot"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxVMessWSPort}")
            echoContent green " ---> Tuic closed successfully"

        checkDNSIP "${domain}"
        removeNginxDefaultConf
        handleSingBox stop
        randomPathFunction
        checkPortOpen "${result[-1]}" "${domain}"
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/05_VMess_WS_inbounds.json
{
    "inbounds":[
        {
          "type": "vmess",
          "listen":"::",
          "listen_port":${result[-1]},
          "tag":"VMessWS",
          "users":$(initSingBoxClients 3),
          "tls":{
            "server_name": "${sslDomain}",
            "enabled": true,
            "certificate_path": "/etc/v2ray-agent/tls/${sslDomain}.crt",
            "key_path": "/etc/v2ray-agent/tls/${sslDomain}.key"
          },
          "transport": {
            "type": "ws",
            "path": "/${currentPath}",
            "max_early_data": 2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
          }
        }
    ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/05_VMess_WS_inbounds.json >/dev/null 2>&1
    fi

    # VLESS_Reality_Vision
    if echo "${selectCustomInstallType}" | grep -q ",7," || [[ "$1" == "all" ]]; then
        echoContent yellow "\n --->Download speed: ${hysteriaClientDownloadSpeed}\n"
        initRealityClientServersName
        initRealityKey
    echoContent skyBlue "\nProgress$1/${totalProgress}: Configure Tuic to start automatically at boot"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxVLESSRealityVisionPort}")
            echoContent green " ---> Xray started successfully"
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/07_VLESS_vision_reality_inbounds.json
{
  "inbounds": [
    {
      "type": "vless",
      "listen":"::",
      "listen_port":${result[-1]},
      "tag": "VLESSReality",
      "users":$(initSingBoxClients 7),
      "tls": {
        "enabled": true,
        "server_name": "${realityServerName}",
        "reality": {
            "enabled": true,
            "handshake":{
                "server": "${realityServerName}",
                "server_port":${realityDomainPort}
            },
            "private_key": "${realityPrivateKey}",
            "short_id": [
                "",
                "6ba85179e30d4fc2"
            ]
        }
      }
    }
  ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/07_VLESS_vision_reality_inbounds.json >/dev/null 2>&1
    fi

    if echo "${selectCustomInstallType}" | grep -q ",8," || [[ "$1" == "all" ]]; then
    echoContent yellow "Please enter the local bandwidth peak uplink speed (default: 50, unit: Mbps)"
        initRealityClientServersName
        initRealityKey
    echoContent skyBlue "\nProgress$1/${totalProgress}: Configure Xray to start automatically at boot"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxVLESSRealityGRPCPort}")
            echoContent green " ---> Xray closed successfully"
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/08_VLESS_vision_gRPC_inbounds.json
{
  "inbounds": [
    {
      "type": "vless",
      "listen":"::",
      "listen_port":${result[-1]},
      "users":$(initSingBoxClients 8),
      "tag": "VLESSRealityGRPC",
      "tls": {
        "enabled": true,
        "server_name": "${realityServerName}",
        "reality": {
            "enabled": true,
            "handshake":{
                "server":"${realityServerName}",
                "server_port":${realityDomainPort}
            },
            "private_key": "${realityPrivateKey}",
            "short_id": [
                "",
                "6ba85179e30d4fc2"
            ]
        }
      },
      "transport": {
          "type": "grpc",
          "service_name": "grpc"
      }
    }
  ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/08_VLESS_vision_gRPC_inbounds.json >/dev/null 2>&1
    fi

    if echo "${selectCustomInstallType}" | grep -q ",6," || [[ "$1" == "all" ]]; then
        echoContent yellow "\n ---> Upload speed: ${hysteriaClientUploadSpeed}\n"
    echoContent skyBlue "\nPlease select the protocol type"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxHysteria2Port}")
            echoContent green "\nPort range: ${hysteriaPortHoppingRange}\n"
        initHysteria2Network
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/06_hysteria2_inbounds.json
{
    "inbounds": [
        {
            "type": "hysteria2",
            "listen": "::",
            "listen_port": ${result[-1]},
            "users": $(initSingBoxClients 6),
            "up_mbps":${hysteria2ClientDownloadSpeed},
            "down_mbps":${hysteria2ClientUploadSpeed},
            "tls": {
                "enabled": true,
                "server_name":"${sslDomain}",
                "alpn": [
                    "h3"
                ],
                "certificate_path": "/etc/v2ray-agent/tls/${sslDomain}.crt",
                "key_path": "/etc/v2ray-agent/tls/${sslDomain}.key"
            }
        }
    ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/06_hysteria2_inbounds.json >/dev/null 2>&1
    fi

    if echo "${selectCustomInstallType}" | grep -q ",4," || [[ "$1" == "all" ]]; then
    echoContent yellow "# Notes\n"
    echoContent skyBlue "\nProgress 1/1: Port jump"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxTrojanPort}")
                echoContent green " ---> Port hopping added successfully"
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/04_trojan_TCP_inbounds.json
{
    "inbounds": [
        {
            "type": "trojan",
            "listen": "::",
            "listen_port": ${result[-1]},
            "users": $(initSingBoxClients 4),
            "tls": {
                "enabled": true,
                "server_name":"${sslDomain}",
                "certificate_path": "/etc/v2ray-agent/tls/${sslDomain}.crt",
                "key_path": "/etc/v2ray-agent/tls/${sslDomain}.key"
            }
        }
    ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/04_trojan_TCP_inbounds.json >/dev/null 2>&1
    fi

    if echo "${selectCustomInstallType}" | grep -q ",9," || [[ "$1" == "all" ]]; then
    echoContent yellow "Only supports UDP"
    echoContent skyBlue "\nProgress 1/1: Port jump"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxTuicPort}")
            echoContent green " ---> Deletion successful"
        initTuicProtocol
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/09_tuic_inbounds.json
{
     "inbounds": [
        {
            "type": "tuic",
            "listen": "::",
            "tag": "singbox-tuic-in",
            "listen_port": ${result[-1]},
            "users": $(initSingBoxClients 9),
            "congestion_control": "${tuicAlgorithm}",
            "tls": {
                "enabled": true,
                "server_name":"${sslDomain}",
                "alpn": [
                    "h3"
                ],
                "certificate_path": "/etc/v2ray-agent/tls/${sslDomain}.crt",
                "key_path": "/etc/v2ray-agent/tls/${sslDomain}.key"
            }
        }
    ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/09_tuic_inbounds.json >/dev/null 2>&1
    fi

    if echo "${selectCustomInstallType}" | grep -q ",10," || [[ "$1" == "all" ]]; then
    echoContent yellow "The starting position of port jumping is 30000"
    echoContent skyBlue "\nProgress$1/${totalProgress}: Initializing Hysteria configuration"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxNaivePort}")
        echoContent green " ---> The current port hopping range is: ${portHoppingStart}-${portHoppingEnd}"
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/10_naive_inbounds.json
{
     "inbounds": [
        {
            "type": "naive",
            "listen": "::",
            "tag": "singbox-naive-in",
            "listen_port": ${result[-1]},
            "users": $(initSingBoxClients 10),
            "tls": {
                "enabled": true,
                "server_name":"${sslDomain}",
                "certificate_path": "/etc/v2ray-agent/tls/${sslDomain}.crt",
                "key_path": "/etc/v2ray-agent/tls/${sslDomain}.key"
            }
        }
    ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/10_naive_inbounds.json >/dev/null 2>&1
    fi
    if echo "${selectCustomInstallType}" | grep -q ",11," || [[ "$1" == "all" ]]; then
    echoContent yellow "The end position of port jumping is 60000"
    echoContent skyBlue "\nPlease select the algorithm type"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxVMessHTTPUpgradePort}")
    echoContent green "\n ---> Port: ${tuicPort}"

        checkDNSIP "${domain}"
        removeNginxDefaultConf
        handleSingBox stop
        randomPathFunction
        rm -rf "${nginxConfigPath}sing_box_VMess_HTTPUpgrade.conf" >/dev/null 2>&1
        checkPortOpen "${result[-1]}" "${domain}"
        singBoxNginxConfig "$1" "${result[-1]}"
        bootStartup nginx
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/11_VMess_HTTPUpgrade_inbounds.json
{
    "inbounds":[
        {
          "type": "vmess",
          "listen":"127.0.0.1",
          "listen_port":31306,
          "tag":"VMessHTTPUpgrade",
          "users":$(initSingBoxClients 11),
          "transport": {
            "type": "httpupgrade",
            "path": "/${currentPath}"
          }
        }
    ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/11_VMess_HTTPUpgrade_inbounds.json >/dev/null 2>&1
    fi

    if echo "${selectCustomInstallType}" | grep -q ",13," || [[ "$1" == "all" ]]; then
    echoContent yellow "You can choose a segment in the range of 30000-60000"
    echoContent skyBlue "\nProgress$1/${totalProgress}: Initializing Tuic configuration"
        echo
        mapfile -t result < <(initSingBoxPort "${singBoxAnyTLSPort}")
            echoContent green "\n ---> Used successfully"
        cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/13_anytls_inbounds.json
{
    "inbounds": [
        {
            "type": "anytls",
            "listen": "::",
            "tag":"anytls",
            "listen_port": ${result[-1]},
            "users": $(initSingBoxClients 13),
            "tls": {
                "enabled": true,
                "server_name":"${sslDomain}",
                "certificate_path": "/etc/v2ray-agent/tls/${sslDomain}.crt",
                "key_path": "/etc/v2ray-agent/tls/${sslDomain}.key"
            }
        }
    ]
}
EOF
    elif [[ -z "$3" ]]; then
        rm /etc/v2ray-agent/sing-box/conf/config/13_anytls_inbounds.json >/dev/null 2>&1
    fi

    if [[ -z "$3" ]]; then
        removeSingBoxConfig wireguard_endpoints_IPv4_route
        removeSingBoxConfig wireguard_endpoints_IPv6_route
        removeSingBoxConfig wireguard_endpoints_IPv4
        removeSingBoxConfig wireguard_endpoints_IPv6

        removeSingBoxConfig IPv4_out
        removeSingBoxConfig IPv6_out
        removeSingBoxConfig IPv6_route
        removeSingBoxConfig block
        removeSingBoxConfig cn_block_outbound
        removeSingBoxConfig cn_block_route
        removeSingBoxConfig 01_direct_outbound
        removeSingBoxConfig socks5_outbound.json
        removeSingBoxConfig block_domain_outbound
        removeSingBoxConfig dns
    fi

    setSniffRouting
}
initSubscribeLocalConfig() {
    rm -rf /etc/v2ray-agent/subscribe_local/sing-box/*
}
# General
defaultBase64Code() {
    local type=$1
    local port=$2
    local email=$3
    local id=$4
    local add=$5
    local path=$6
    local user=
    user=$(echo "${email}" | awk -F "[-]" '{print $1}')
    if [[ ! -f "/etc/v2ray-agent/subscribe_local/sing-box/${user}" ]]; then
        echo [] >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"
    fi
    local singBoxSubscribeLocalConfig=
    if [[ "${type}" == "vlesstcp" ]]; then

    echoContent yellow "Recommend about 1000"
        echoContent green "    vless://${id}@${currentHost}:${port}?encryption=none&security=tls&fp=chrome&type=tcp&host=${currentHost}&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision#${email}\n"

    echoContent yellow "Please enter the port jumping range, for example [30000-31000]"
            echoContent green " vless://${id}@${currentHost}:${currentDefaultPort}?encryption=none&security=tls&fp=chrome&type=tcp&host=${currentHost}&headerType=none&sni=${currentHost}&flow=xtls-rprx- vision#${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@${currentHost}:${port}?encryption=none&security=tls&type=tcp&host=${currentHost}&fp=chrome&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: ${currentHost}
    port: ${port}
    uuid: ${id}
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    client-fingerprint: chrome
EOF
        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\":\"vless\",\"server\":\"${currentHost}\",\"server_port\":${port},\"uuid\":\"${id}\",\"flow\":\"xtls-rprx-vision\",\"tls\":{\"enabled\":true,\"server_name\":\"${currentHost}\",\"utls\":{\"enabled\":true,\"fingerprint\":\"chrome\"}},\"packet_encoding\":\"xudp\"}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")
        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

    echoContent yellow "1.Add port hopping"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${currentHost}%3A${port}%3Fencryption%3Dnone%26fp%3Dchrome%26security%3Dtls%26type%3Dtcp%26${currentHost}%3D${currentHost}%26headerType%3Dnone%26sni%3D${currentHost}%26flow%3Dxtls-rprx-vision%23${email}\n"

    elif [[ "${type}" == "vmessws" ]]; then
        qrCodeBase64Default=$(echo -n "{\"port\":${port},\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${currentHost}\",\"type\":\"none\",\"path\":\"${path}\",\"net\":\"ws\",\"add\":\"${add}\",\"method\":\"none\",\"peer\":\"${currentHost}\",\"sni\":\"${currentHost}\"}" | base64 -w 0)
        qrCodeBase64Default="${qrCodeBase64Default// /}"

    echoContent yellow "2.Delete port hopping"
        echoContent green "    {\"port\":${port},\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${currentHost}\",\"type\":\"none\",\"path\":\"${path}\",\"net\":\"ws\",\"add\":\"${add}\",\"method\":\"none\",\"peer\":\"${currentHost}\",\"sni\":\"${currentHost}\"}\n"
    echoContent yellow "3.Check port jumping"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
            echoContent yellow "\n ---> Port: ${tuicPort}"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vmess://${qrCodeBase64Default}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vmess
    server: ${add}
    port: ${port}
    uuid: ${id}
    alterId: 0
    cipher: none
    udp: true
    tls: true
    client-fingerprint: chrome
    servername: ${currentHost}
    network: ws
    ws-opts:
      path: ${path}
      headers:
        Host: ${currentHost}
EOF
        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\":\"vmess\",\"server\":\"${add}\",\"server_port\":${port},\"uuid\":\"${id}\",\"alter_id\":0,\"tls\":{\"enabled\":true,\"server_name\":\"${currentHost}\",\"utls\":{\"enabled\":true,\"fingerprint\":\"chrome\"}},\"packet_encoding\":\"packetaddr\",\"transport\":{\"type\":\"ws\",\"path\":\"${path}\",\"max_early_data\":2048,\"early_data_header_name\":\"Sec-WebSocket-Protocol\"}}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")

        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

    elif [[ "${type}" == "vlessws" ]]; then

        echoContent yellow "Please enter the Tuic port [enter random 10000-30000], cannot be repeated with other services"
        echoContent green "    vless://${id}@${add}:${port}?encryption=none&security=tls&type=ws&host=${currentHost}&sni=${currentHost}&fp=chrome&path=${path}#${email}\n"

    echoContent yellow "1.bbr(default)"
            echoContent green "Protocol type: VLESS, address: ${currentHost}, port: ${currentDefaultPort}, user ID: ${id}, security: tls, client-fingerprint: chrome, transmission method: tcp, flow: xtls-rprx -vision, account name:${email}\n"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@${add}:${port}?encryption=none&security=tls&type=ws&host=${currentHost}&sni=${currentHost}&fp=chrome&path=${path}#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: ${add}
    port: ${port}
    uuid: ${id}
    udp: true
    tls: true
    network: ws
    client-fingerprint: chrome
    servername: ${currentHost}
    ws-opts:
      path: ${path}
      headers:
        Host: ${currentHost}
EOF

        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\":\"vless\",\"server\":\"${add}\",\"server_port\":${port},\"uuid\":\"${id}\",\"tls\":{\"enabled\":true,\"server_name\":\"${currentHost}\",\"utls\":{\"enabled\":true,\"fingerprint\":\"chrome\"}},\"multiplex\":{\"enabled\":false,\"protocol\":\"smux\",\"max_streams\":32},\"packet_encoding\":\"xudp\",\"transport\":{\"type\":\"ws\",\"path\":\"${path}\",\"headers\":{\"Host\":\"${currentHost}\"}}}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")
        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

    echoContent yellow "2.cubic"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${port}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dws%26host%3D${currentHost}%26fp%3Dchrome%26sni%3D${currentHost}%26path%3D${path}%23${email}"

    elif [[ "${type}" == "vlessXHTTP" ]]; then

        local xhttpMldsa65Param=
        local xhttpMldsa65ParamEncoded=
        if [[ -n "${currentRealityMldsa65Verify}" && "${currentRealityMldsa65Verify}" != "null" ]]; then
            xhttpMldsa65Param="&pqv=${currentRealityMldsa65Verify}"
            xhttpMldsa65ParamEncoded="%26pqv%3D${currentRealityMldsa65Verify}"
        fi

    echoContent yellow "3.new_reno"
        echoContent green "    vless://${id}@${add}:${port}?encryption=none&security=reality${xhttpMldsa65Param}&type=xhttp&sni=${xrayVLESSRealityXHTTPServerName}&host=${xrayVLESSRealityXHTTPServerName}&fp=chrome&path=${path}&pbk=${currentRealityXHTTPPublicKey}&sid=6ba85179e30d4fc2#${email}\n"

    echoContent yellow "\n ---> Algorithm: ${tuicAlgorithm}\n"
            echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${currentHost}%3A${currentDefaultPort}%3Fencryption%3Dnone%26fp%3Dchrome%26security%3Dtls%26type%3Dtcp%26${currentHost}%3D${currentHost}%26headerType%3Dnone%26sni%3D${currentHost}%26flow%3Dxtls-rprx-vision%23${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@${add}:${port}?encryption=none&security=reality${xhttpMldsa65Param}&type=xhttp&sni=${xrayVLESSRealityXHTTPServerName}&fp=chrome&path=${path}&pbk=${currentRealityXHTTPPublicKey}&sid=6ba85179e30d4fc2#${email}
EOF

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: ${add}
    port: ${port}
    uuid: ${id}
    udp: true
    tls: true
    network: xhttp
    client-fingerprint: chrome
    alpn:
      - h2
    servername: ${xrayVLESSRealityXHTTPServerName}
    xhttp-opts:
      path: ${path}
      host: ${xrayVLESSRealityXHTTPServerName}
    reality-opts:
      public-key: ${currentRealityXHTTPPublicKey}
      short-id: 6ba85179e30d4fc2
EOF

    echoContent yellow "# Notes\n"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${port}%3Fencryption%3Dnone%26security%3Dreality${xhttpMldsa65ParamEncoded}%26type%3Dxhttp%26sni%3D${xrayVLESSRealityXHTTPServerName}%26fp%3Dchrome%26path%3D${path}%26host%3D${xrayVLESSRealityXHTTPServerName}%26pbk%3D${currentRealityXHTTPPublicKey}%26sid%3D6ba85179e30d4fc2%23${email}\n"

    elif
        [[ "${type}" == "vlessgrpc" ]]
    then

    echoContent yellow "will replace the prefix with ${xtlsType}"
        echoContent green "    vless://${id}@${add}:${port}?encryption=none&security=tls&type=grpc&host=${currentHost}&path=${currentPath}grpc&fp=chrome&serviceName=${currentPath}grpc&alpn=h2&sni=${currentHost}#${email}\n"

    echoContent yellow "If the prefix is Trojan, two Trojan protocol nodes will appear when viewing the account, and one of them is unavailable xtls"
            echoContent green "    vless://${id}@${currentHost}:${currentDefaultPort}?security=tls&encryption=none&host=${currentHost}&fp=chrome&headerType=none&type=tcp#${email}\n"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@${add}:${port}?encryption=none&security=tls&type=grpc&host=${currentHost}&path=${currentPath}grpc&serviceName=${currentPath}grpc&fp=chrome&alpn=h2&sni=${currentHost}#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: ${add}
    port: ${port}
    uuid: ${id}
    udp: true
    tls: true
    network: grpc
    client-fingerprint: chrome
    servername: ${currentHost}
    grpc-opts:
      grpc-service-name: ${currentPath}grpc
EOF

        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\": \"vless\",\"server\": \"${add}\",\"server_port\": ${port},\"uuid\": \"${id}\",\"tls\": {  \"enabled\": true,  \"server_name\": \"${currentHost}\",  \"utls\": {    \"enabled\": true,    \"fingerprint\": \"chrome\"  }},\"packet_encoding\": \"xudp\",\"transport\": {  \"type\": \"grpc\",  \"service_name\": \"${currentPath}grpc\"}}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")
        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

    echoContent yellow "Execute again to switch to the last prefix\n"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${port}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dgrpc%26host%3D${currentHost}%26serviceName%3D${currentPath}grpc%26fp%3Dchrome%26path%3D${currentPath}grpc%26sni%3D${currentHost}%26alpn%3Dh2%23${email}"

    elif [[ "${type}" == "trojan" ]]; then
        # URLEncode
        # URLEncode
        echoContent yellow " ---> Trojan(TLS)"
        echoContent green "    trojan://${id}@${currentHost}:${port}?peer=${currentHost}&fp=chrome&sni=${currentHost}&alpn=http/1.1#${currentHost}_Trojan\n"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
trojan://${id}@${currentHost}:${port}?peer=${currentHost}&fp=chrome&sni=${currentHost}&alpn=http/1.1#${email}_Trojan
EOF

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: trojan
    server: ${currentHost}
    port: ${port}
    password: ${id}
    client-fingerprint: chrome
    udp: true
    sni: ${currentHost}
EOF
        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\":\"trojan\",\"server\":\"${currentHost}\",\"server_port\":${port},\"password\":\"${id}\",\"tls\":{\"alpn\":[\"http/1.1\"],\"enabled\":true,\"server_name\":\"${currentHost}\",\"utls\":{\"enabled\":true,\"fingerprint\":\"chrome\"}}}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")
        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

    echoContent yellow "1.Switch to ${xtlsType}"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${currentHost}%3a${port}%3fpeer%3d${currentHost}%26fp%3Dchrome%26sni%3d${currentHost}%26alpn%3Dhttp/1.1%23${email}\n"

    elif [[ "${type}" == "trojangrpc" ]]; then
        # URLEncode

        # URLEncode

        echoContent yellow " ---> Trojan gRPC(TLS)"
        echoContent green "    trojan://${id}@${add}:${port}?encryption=none&peer=${currentHost}&fp=chrome&security=tls&type=grpc&sni=${currentHost}&alpn=h2&path=${currentPath}trojangrpc&serviceName=${currentPath}trojangrpc#${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
trojan://${id}@${add}:${port}?encryption=none&peer=${currentHost}&security=tls&type=grpc&fp=chrome&sni=${currentHost}&alpn=h2&path=${currentPath}trojangrpc&serviceName=${currentPath}trojangrpc#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    server: ${add}
    port: ${port}
    type: trojan
    password: ${id}
    network: grpc
    sni: ${currentHost}
    udp: true
    grpc-opts:
      grpc-service-name: ${currentPath}trojangrpc
EOF

        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\":\"trojan\",\"server\":\"${add}\",\"server_port\":${port},\"password\":\"${id}\",\"tls\":{\"enabled\":true,\"server_name\":\"${currentHost}\",\"insecure\":true,\"utls\":{\"enabled\":true,\"fingerprint\":\"chrome\"}},\"transport\":{\"type\":\"grpc\",\"service_name\":\"${currentPath}trojangrpc\",\"idle_timeout\":\"15s\",\"ping_timeout\":\"15s\",\"permit_without_stream\":false},\"multiplex\":{\"enabled\":false,\"protocol\":\"smux\",\"max_streams\":32}}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")
        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

        echoContent yellow "Please enter custom UUID [need to be legal], [Enter] random UUID"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${add}%3a${port}%3Fencryption%3Dnone%26fp%3Dchrome%26security%3Dtls%26peer%3d${currentHost}%26type%3Dgrpc%26sni%3d${currentHost}%26path%3D${currentPath}trojangrpc%26alpn%3Dh2%26serviceName%3D${currentPath}trojangrpc%23${email}\n"

    elif [[ "${type}" == "hysteria" ]]; then
        echoContent yellow " ---> Hysteria(TLS)"
        local clashMetaPortContent="port: ${port}"
        local multiPort=
        local multiPortEncode
        if echo "${port}" | grep -q "-"; then
            clashMetaPortContent="ports: ${port}"
            multiPort="mport=${port}&"
            multiPortEncode="mport%3D${port}%26"
        fi

        echoContent green "    hysteria2://${id}@${currentHost}:${singBoxHysteria2Port}?${multiPort}peer=${currentHost}&insecure=0&sni=${currentHost}&alpn=h3#${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
hysteria2://${id}@${currentHost}:${singBoxHysteria2Port}?${multiPort}peer=${currentHost}&insecure=0&sni=${currentHost}&alpn=h3#${email}
EOF
        echoContent yellow " ---> v2rayN(hysteria+TLS)"
        echo "{\"server\": \"${currentHost}:${port}\",\"socks5\": { \"listen\": \"127.0.0.1:7798\", \"timeout\": 300},\"auth\":\"${id}\",\"tls\":{\"sni\":\"${currentHost}\"}}" | jq

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: hysteria2
    server: ${currentHost}
    ${clashMetaPortContent}
    password: ${id}
    alpn:
        - h3
    sni: ${currentHost}
    up: "${hysteria2ClientUploadSpeed} Mbps"
    down: "${hysteria2ClientDownloadSpeed} Mbps"
EOF

        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\":\"hysteria2\",\"server\":\"${currentHost}\",\"server_port\":${singBoxHysteria2Port},\"up_mbps\":${hysteria2ClientUploadSpeed},\"down_mbps\":${hysteria2ClientDownloadSpeed},\"password\":\"${id}\",\"tls\":{\"enabled\":true,\"server_name\":\"${currentHost}\",\"alpn\":[\"h3\"]}}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")
        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

        echoContent yellow "\n ${uuid}"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=hysteria2%3A%2F%2F${id}%40${currentHost}%3A${singBoxHysteria2Port}%3F${multiPortEncode}peer%3D${currentHost}%26insecure%3D0%26sni%3D${currentHost}%26alpn%3Dh3%23${email}\n"

    elif [[ "${type}" == "vlessReality" ]]; then
        local realityServerName=${xrayVLESSRealityServerName}
        local publicKey=${currentRealityPublicKey}
        local realityMldsa65Verify=${currentRealityMldsa65Verify}

        if [[ "${coreInstallType}" == "2" ]]; then
            realityServerName=${singBoxVLESSRealityVisionServerName}
            publicKey=${singBoxVLESSRealityPublicKey}
        fi
    echoContent yellow "# Notes"
        echoContent green "    vless://${id}@$(getPublicIP):${port}?encryption=none&security=reality&pqv=${realityMldsa65Verify}&type=tcp&sni=${realityServerName}&fp=chrome&pbk=${publicKey}&sid=6ba85179e30d4fc2&flow=xtls-rprx-vision#${email}\n"

    echoContent yellow "\nTutorial address:"
            echoContent green "Protocol type: VLESS, address: ${currentHost}, port: ${currentDefaultPort}, user ID: ${id}, security: tls, client-fingerprint: chrome, transmission method: tcp, account name: ${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@$(getPublicIP):${port}?encryption=none&security=reality&pqv=${realityMldsa65Verify}&type=tcp&sni=${realityServerName}&fp=chrome&pbk=${publicKey}&sid=6ba85179e30d4fc2&flow=xtls-rprx-vision#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: $(getPublicIP)
    port: ${port}
    uuid: ${id}
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: ${realityServerName}
    reality-opts:
      public-key: ${publicKey}
      short-id: 6ba85179e30d4fc2
    client-fingerprint: chrome
EOF

        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\":\"vless\",\"server\":\"$(getPublicIP)\",\"server_port\":${port},\"uuid\":\"${id}\",\"flow\":\"xtls-rprx-vision\",\"tls\":{\"enabled\":true,\"server_name\":\"${realityServerName}\",\"utls\":{\"enabled\":true,\"fingerprint\":\"chrome\"},\"reality\":{\"enabled\":true,\"public_key\":\"${publicKey}\",\"short_id\":\"6ba85179e30d4fc2\"}},\"packet_encoding\":\"xudp\"}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")
        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

    echoContent yellow "\n1.CNAME www.digitalocean.com"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40$(getPublicIP)%3A${port}%3Fencryption%3Dnone%26security%3Dreality%26type%3Dtcp%26sni%3D${realityServerName}%26fp%3Dchrome%26pbk%3D${publicKey}%26sid%3D6ba85179e30d4fc2%26flow%3Dxtls-rprx-vision%23${email}\n"

    elif [[ "${type}" == "vlessRealityGRPC" ]]; then
        local realityServerName=${xrayVLESSRealityServerName}
        local publicKey=${currentRealityPublicKey}
        local realityMldsa65Verify=${currentRealityMldsa65Verify}

        if [[ "${coreInstallType}" == "2" ]]; then
            realityServerName=${singBoxVLESSRealityGRPCServerName}
            publicKey=${singBoxVLESSRealityPublicKey}
        fi

    echoContent yellow "2.CNAME who.int"
        # pqv=${realityMldsa65Verify}&
        echoContent green "    vless://${id}@$(getPublicIP):${port}?encryption=none&security=reality&type=grpc&sni=${realityServerName}&fp=chrome&pbk=${publicKey}&sid=6ba85179e30d4fc2&path=grpc&serviceName=grpc#${email}\n"

    echoContent yellow "3.CNAME blog.hostmonit.com"
        # pqv=${realityMldsa65Verify}，
            echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3a%2f%2f${id}%40${currentHost}%3a${currentDefaultPort}%3fsecurity%3dtls%26encryption%3dnone%26fp%3Dchrome%26host%3d${currentHost}%26headerType%3dnone%26type%3dtcp%23${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
vless://${id}@$(getPublicIP):${port}?encryption=none&security=reality&pqv=${realityMldsa65Verify}&type=grpc&sni=${realityServerName}&fp=chrome&pbk=${publicKey}&sid=6ba85179e30d4fc2&path=grpc&serviceName=grpc#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vless
    server: $(getPublicIP)
    port: ${port}
    uuid: ${id}
    network: grpc
    tls: true
    udp: true
    servername: ${realityServerName}
    reality-opts:
      public-key: ${publicKey}
      short-id: 6ba85179e30d4fc2
    grpc-opts:
      grpc-service-name: "grpc"
    client-fingerprint: chrome
EOF

        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\":\"vless\",\"server\":\"$(getPublicIP)\",\"server_port\":${port},\"uuid\":\"${id}\",\"tls\":{\"enabled\":true,\"server_name\":\"${realityServerName}\",\"utls\":{\"enabled\":true,\"fingerprint\":\"chrome\"},\"reality\":{\"enabled\":true,\"public_key\":\"${publicKey}\",\"short_id\":\"6ba85179e30d4fc2\"}},\"packet_encoding\":\"xudp\",\"transport\":{\"type\":\"grpc\",\"service_name\":\"grpc\"}}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")
        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

        echoContent yellow "\n ---> Not used"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40$(getPublicIP)%3A${port}%3Fencryption%3Dnone%26security%3Dreality%26type%3Dgrpc%26sni%3D${realityServerName}%26fp%3Dchrome%26pbk%3D${publicKey}%26sid%3D6ba85179e30d4fc2%26path%3Dgrpc%26serviceName%3Dgrpc%23${email}\n"
    elif [[ "${type}" == "tuic" ]]; then
        local tuicUUID=
        tuicUUID=$(echo "${id}" | awk -F "[_]" '{print $1}')

        local tuicPassword=
        tuicPassword=$(echo "${id}" | awk -F "[_]" '{print $2}')

        if [[ -z "${email}" ]]; then
    echoContent red "\n================================================ ================="
            exit 0
        fi

            echoContent yellow " ---> Universal format (VLESS+TCP+TLS_Vision)"
        echoContent green "    trojan://${id}@${currentHost}:${currentDefaultPort}?encryption=none&security=xtls&type=tcp&host=${currentHost}&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision#${email}\n"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
tuic://${tuicUUID}:${tuicPassword}@${currentHost}:${port}?congestion_control=${tuicAlgorithm}&alpn=h3&sni=${currentHost}&udp_relay_mode=quic&allow_insecure=0#${email}
EOF
        echoContent yellow " ---> v2rayN(Tuic+TLS)"
        echo "{\"relay\": {\"server\": \"${currentHost}:${port}\",\"uuid\": \"${tuicUUID}\",\"password\": \"${tuicPassword}\",\"ip\": \"${currentHost}\",\"congestion_control\": \"${tuicAlgorithm}\",\"alpn\": [\"h3\"]},\"local\": {\"server\": \"127.0.0.1:7798\"},\"log_level\": \"warn\"}" | jq

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    server: ${currentHost}
    type: tuic
    port: ${port}
    uuid: ${tuicUUID}
    password: ${tuicPassword}
    alpn:
     - h3
    congestion-controller: ${tuicAlgorithm}
    disable-sni: true
    reduce-rtt: true
    sni: ${email}
EOF

        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\": \"tuic\",\"server\": \"${currentHost}\",\"server_port\": ${port},\"uuid\": \"${tuicUUID}\",\"password\": \"${tuicPassword}\",\"congestion_control\": \"${tuicAlgorithm}\",\"tls\": {\"enabled\": true,\"server_name\": \"${currentHost}\",\"alpn\": [\"h3\"]}}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")
        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

            echoContent yellow " ---> Formatted plain text (VLESS+TCP+TLS_Vision)"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=tuic%3A%2F%2F${tuicUUID}%3A${tuicPassword}%40${currentHost}%3A${tuicPort}%3Fcongestion_control%3D${tuicAlgorithm}%26alpn%3Dh3%26sni%3D${currentHost}%26udp_relay_mode%3Dquic%26allow_insecure%3D0%23${email}\n"
    elif [[ "${type}" == "naive" ]]; then
        echoContent yellow " ---> Naive(TLS)"

        echoContent green "    naive+https://${email}:${id}@${currentHost}:${port}?padding=true#${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
naive+https://${email}:${id}@${currentHost}:${port}?padding=true#${email}
EOF
            echoContent yellow " ---> QR code VLESS(VLESS+TCP+TLS_Vision)"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=naive%2Bhttps%3A%2F%2F${email}%3A${id}%40${currentHost}%3A${port}%3Fpadding%3Dtrue%23${email}\n"
    elif [[ "${type}" == "vmessHTTPUpgrade" ]]; then
        qrCodeBase64Default=$(echo -n "{\"port\":${port},\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${currentHost}\",\"type\":\"none\",\"path\":\"${path}\",\"net\":\"httpupgrade\",\"add\":\"${add}\",\"method\":\"none\",\"peer\":\"${currentHost}\",\"sni\":\"${currentHost}\"}" | base64 -w 0)
        qrCodeBase64Default="${qrCodeBase64Default// /}"

            echoContent yellow " ---> Universal format (VLESS+TCP+TLS)"
        echoContent green "    {\"port\":${port},\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${currentHost}\",\"type\":\"none\",\"path\":\"${path}\",\"net\":\"httpupgrade\",\"add\":\"${add}\",\"method\":\"none\",\"peer\":\"${currentHost}\",\"sni\":\"${currentHost}\"}\n"
            echoContent yellow " ---> Formatted plain text (VLESS+TCP+TLS)"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
            echoContent yellow " ---> QR code VLESS(VLESS+TCP+TLS)"

        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
   vmess://${qrCodeBase64Default}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: vmess
    server: ${add}
    port: ${port}
    uuid: ${id}
    alterId: 0
    cipher: auto
    udp: true
    tls: true
    client-fingerprint: chrome
    servername: ${currentHost}
    network: ws
    ws-opts:
     path: ${path}
     headers:
       Host: ${currentHost}
     v2ray-http-upgrade: true
EOF
        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\":\"vmess\",\"server\":\"${add}\",\"server_port\":${port},\"uuid\":\"${id}\",\"security\":\"auto\",\"alter_id\":0,\"tls\":{\"enabled\":true,\"server_name\":\"${currentHost}\",\"utls\":{\"enabled\":true,\"fingerprint\":\"chrome\"}},\"packet_encoding\":\"packetaddr\",\"transport\":{\"type\":\"httpupgrade\",\"path\":\"${path}\"}}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")

        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

    elif [[ "${type}" == "anytls" ]]; then
        echoContent yellow " ---> AnyTLS"

        echoContent yellow " ---> Common format (Trojan+TCP+TLS_Vision)"
        echoContent green "Protocol type: Trojan, address: ${currentHost}, port: ${currentDefaultPort}, user ID: ${id}, security: xtls, transmission method: tcp, flow: xtls-rprx-vision, account name: ${email}\n"

        echoContent green "    anytls://${id}@${currentHost}:${singBoxAnyTLSPort}?peer=${currentHost}&insecure=0&sni=${currentHost}#${email}\n"
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/default/${user}"
anytls://${id}@${currentHost}:${singBoxAnyTLSPort}?peer=${currentHost}&insecure=0&sni=${currentHost}#${email}
EOF
        cat <<EOF >>"/etc/v2ray-agent/subscribe_local/clashMeta/${user}"
  - name: "${email}"
    type: anytls
    port: ${singBoxAnyTLSPort}
    server: ${currentHost}
    password: ${id}
    client-fingerprint: chrome
    udp: true
    sni: ${currentHost}
    alpn:
      - h2
      - http/1.1
EOF

        singBoxSubscribeLocalConfig=$(jq -r ". += [{\"tag\":\"${email}\",\"type\":\"anytls\",\"server\":\"${currentHost}\",\"server_port\":${singBoxAnyTLSPort},\"password\":\"${id}\",\"tls\":{\"enabled\":true,\"server_name\":\"${currentHost}\"}}]" "/etc/v2ray-agent/subscribe_local/sing-box/${user}")
        echo "${singBoxSubscribeLocalConfig}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${user}"

        echoContent yellow " ---> Formatted plain text (Trojan+TCP+TLS_Vision)"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=anytls%3A%2F%2F${id}%40${currentHost}%3A${singBoxAnyTLSPort}%3Fpeer%3D${currentHost}%26insecure%3D0%26sni%3D${currentHost}%23${email}\n"
    fi

}

# Get Reality subscription port
getRealitySubscriptionPort() {
    local protocol=$1
    if [[ "${coreInstallType}" == "2" ]]; then
        if [[ "${protocol}" == "grpc" ]]; then
            printf '%s\n' "${singBoxVLESSRealityGRPCPort}"
        else
            printf '%s\n' "${singBoxVLESSRealityVisionPort}"
        fi
    else
        printf '%s\n' "${xrayVLESSRealityVisionPort}"
    fi
}

# account
showAccounts() {
    readInstallType
    readInstallProtocolType
    readConfigHostPathUUID
    readSingBoxConfig

    echo
    echoContent skyBlue "\nProgress$2/${totalProgress}: Initializing V2Ray configuration"

    initSubscribeLocalConfig
    # VLESS TCP
    if echo ${currentInstallProtocolType} | grep -q ",0,"; then

    echoContent skyBlue "\nFunction 1/${totalProgress}: Switch to ${xtlsType}"
        jq .inbounds[0].settings.clients//.inbounds[0].users ${configPath}02_VLESS_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email//.name)

    echoContent skyBlue "\nProgress$2/${totalProgress}: Initializing Xray configuration"
            echo
            defaultBase64Code vlesstcp "${currentDefaultPort}${singBoxVLESSVisionPort}" "${email}" "$(echo "${user}" | jq -r .id//.uuid)"
        done
    fi

    # VLESS WS
    if echo ${currentInstallProtocolType} | grep -q ",1,"; then
        echoContent skyBlue "\n===================== Configure VLESS+Reality ==================== =\n"

        jq .inbounds[0].settings.clients//.inbounds[0].users ${configPath}03_VLESS_WS_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email//.name)

            local vlessWSPort=${currentDefaultPort}
            if [[ "${coreInstallType}" == "2" ]]; then
                vlessWSPort="${singBoxVLESSWSPort}"
            fi
            echo
            local path="${currentPath}ws"

            if [[ ${coreInstallType} == "1" ]]; then
                path="/${currentPath}ws"
            elif [[ "${coreInstallType}" == "2" ]]; then
                path="${singBoxVLESSWSPath}"
            fi

            local count=
            while read -r line; do
    echoContent skyBlue "\nProgress$1/${totalProgress}: Add cloudflare custom CNAME"
                if [[ -n "${line}" ]]; then
                    defaultBase64Code vlessws "${vlessWSPort}" "${email}${count}" "$(echo "${user}" | jq -r .id//.uuid)" "${line}" "${path}"
                    count=$((count + 1))
                    echo
                fi
            done < <(echo "${currentCDNAddress}" | tr ',' '\n')
        done
    fi
    # trojan grpc
    if echo ${currentInstallProtocolType} | grep -q ",2,"; then
    echoContent skyBlue "https://www.v2ray-agent.com/archives/cloudflarezi-xuan-ip"
        jq .inbounds[0].settings.clients ${configPath}04_trojan_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email)
            local count=
            while read -r line; do
    echoContent skyBlue "----------------------------"
                echo
                if [[ -n "${line}" ]]; then
                    defaultBase64Code trojangrpc "${currentDefaultPort}" "${email}${count}" "$(echo "${user}" | jq -r .password)" "${line}"
                    count=$((count + 1))
                fi
            done < <(echo "${currentCDNAddress}" | tr ',' '\n')

        done
    fi
    # VMess WS
    if echo ${currentInstallProtocolType} | grep -q ",3,"; then
    echoContent skyBlue "\nProgress$1/${totalProgress}: account"
        local path="${currentPath}vws"
        if [[ ${coreInstallType} == "1" ]]; then
            path="/${currentPath}vws"
        elif [[ "${coreInstallType}" == "2" ]]; then
            path="${singBoxVMessWSPath}"
        fi
        jq .inbounds[0].settings.clients//.inbounds[0].users ${configPath}05_VMess_WS_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email//.name)

            local vmessPort=${currentDefaultPort}
            if [[ "${coreInstallType}" == "2" ]]; then
                vmessPort="${singBoxVMessWSPort}"
            fi

            local count=
            while read -r line; do
        echoContent skyBlue "===================== Trojan TCP TLS_Vision ======================\n"
                echo
                if [[ -n "${line}" ]]; then
                    defaultBase64Code vmessws "${vmessPort}" "${email}${count}" "$(echo "${user}" | jq -r .id//.uuid)" "${line}" "${path}"
                    count=$((count + 1))
                fi
            done < <(echo "${currentCDNAddress}" | tr ',' '\n')
        done
    fi

    # trojan tcp
    if echo ${currentInstallProtocolType} | grep -q ",4,"; then
            echoContent skyBlue "\n --->Account:${email}"
        jq .inbounds[0].settings.clients//.inbounds[0].users ${configPath}04_trojan_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email//.name)
        echoContent skyBlue "============================= VLESS TCP TLS_Vision ==============================\n"

            defaultBase64Code trojan "${currentDefaultPort}${singBoxTrojanPort}" "${email}" "$(echo "${user}" | jq -r .password)"
        done
    fi
    # VLESS grpc
    if echo ${currentInstallProtocolType} | grep -q ",5,"; then
            echoContent skyBlue "\n --->Account:${email}"
        jq .inbounds[0].settings.clients ${configPath}06_VLESS_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do

            local email=
            email=$(echo "${user}" | jq -r .email)

            local count=
            while read -r line; do
        echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================\n"
                echo
                if [[ -n "${line}" ]]; then
                    defaultBase64Code vlessgrpc "${currentDefaultPort}" "${email}${count}" "$(echo "${user}" | jq -r .id)" "${line}"
                    count=$((count + 1))
                fi
            done < <(echo "${currentCDNAddress}" | tr ',' '\n')

        done
    fi
    # hysteria2
    if echo ${currentInstallProtocolType} | grep -q ",6," || [[ -n "${hysteriaPort}" ]]; then
        readPortHopping "hysteria2" "${singBoxHysteria2Port}"
            echoContent skyBlue "\n --->Account:${email}"
        local path="${configPath}"
        if [[ "${coreInstallType}" == "1" ]]; then
            path="${singBoxConfigPath}"
        fi
        local hysteria2DefaultPort=
        if [[ -n "${hysteria2PortHoppingStart}" && -n "${hysteria2PortHoppingEnd}" ]]; then
            hysteria2DefaultPort="${hysteria2PortHopping}"
        else
            hysteria2DefaultPort=${singBoxHysteria2Port}
        fi

        jq -r -c '.inbounds[]|.users[]' "${path}06_hysteria2_inbounds.json" | while read -r user; do
            echoContent skyBlue "\n ---> Account:$(echo "${user}" | jq -r .name)"
            echo
            defaultBase64Code hysteria "${hysteria2DefaultPort}" "$(echo "${user}" | jq -r .name)" "$(echo "${user}" | jq -r .password)"
        done

    fi

    # VLESS reality vision
    if echo ${currentInstallProtocolType} | grep -q ",7,"; then
        echoContent skyBlue "\n=============================== VLESS gRPC TLS CDN ===============================\n"
        jq .inbounds[1].settings.clients//.inbounds[0].users ${configPath}07_VLESS_vision_reality_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email//.name)

            echoContent skyBlue "\n --->Account:${email}"
            echo
            defaultBase64Code vlessReality "$(getRealitySubscriptionPort vision)" "${email}" "$(echo "${user}" | jq -r .id//.uuid)"
        done
    fi
    # VLESS reality gRPC
    if echo ${currentInstallProtocolType} | grep -q ",8,"; then
        echoContent skyBlue "\n================================ VMess WS TLS CDN ================================\n"
        jq .inbounds[0].settings.clients//.inbounds[0].users ${configPath}08_VLESS_vision_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email//.name)

            echoContent skyBlue "\n --->Account:${email}"
            echo
            defaultBase64Code vlessRealityGRPC "$(getRealitySubscriptionPort grpc)" "${email}" "$(echo "${user}" | jq -r .id//.uuid)"
        done
    fi
    # tuic
    if echo ${currentInstallProtocolType} | grep -q ",9," || [[ -n "${tuicPort}" ]]; then
        echoContent skyBlue "\n==================================  Trojan TLS  ==================================\n"
        local path="${configPath}"
        if [[ "${coreInstallType}" == "1" ]]; then
            path="${singBoxConfigPath}"
        fi
        jq -r -c '.inbounds[].users[]' "${path}09_tuic_inbounds.json" | while read -r user; do
            echoContent skyBlue "\n ---> Account:$(echo "${user}" | jq -r .name)"
            echo
            defaultBase64Code tuic "${singBoxTuicPort}" "$(echo "${user}" | jq -r .name)" "$(echo "${user}" | jq -r .uuid)_$(echo "${user}" | jq -r .password)"
        done

    fi
    # naive
    if echo ${currentInstallProtocolType} | grep -q ",10," || [[ -n "${singBoxNaivePort}" ]]; then
            echoContent skyBlue "\n --->Account:${email}"

        jq -r -c '.inbounds[]|.users[]' "${configPath}10_naive_inbounds.json" | while read -r user; do
            echoContent skyBlue "\n ---> Account:$(echo "${user}" | jq -r .username)"
            echo
            defaultBase64Code naive "${singBoxNaivePort}" "$(echo "${user}" | jq -r .username)" "$(echo "${user}" | jq -r .password)"
        done

    fi
    # VMess HTTPUpgrade
    if echo ${currentInstallProtocolType} | grep -q ",11,"; then
        echoContent skyBlue "\n================================  Trojan gRPC TLS  ================================\n"
        local path="${currentPath}vws"
        if [[ ${coreInstallType} == "1" ]]; then
            path="/${currentPath}vws"
        elif [[ "${coreInstallType}" == "2" ]]; then
            path="${singBoxVMessHTTPUpgradePath}"
        fi
        jq .inbounds[0].settings.clients//.inbounds[0].users ${configPath}11_VMess_HTTPUpgrade_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email//.name)

            local vmessHTTPUpgradePort=${currentDefaultPort}
            if [[ "${coreInstallType}" == "2" ]]; then
                vmessHTTPUpgradePort="${singBoxVMessHTTPUpgradePort}"
            fi

            local count=
            while read -r line; do
            echoContent skyBlue "\n --->Account:${email}"
                echo
                if [[ -n "${line}" ]]; then
                    defaultBase64Code vmessHTTPUpgrade "${vmessHTTPUpgradePort}" "${email}${count}" "$(echo "${user}" | jq -r .id//.uuid)" "${line}" "${path}"
                    count=$((count + 1))
                fi
            done < <(echo "${currentCDNAddress}" | tr ',' '\n')
        done
    fi
    # VLESS Reality XHTTP
    if echo ${currentInstallProtocolType} | grep -q ",12,"; then
        echoContent skyBlue "\n================================  Hysteria TLS  ================================\n"

        jq .inbounds[0].settings.clients//.inbounds[0].users ${configPath}12_VLESS_XHTTP_inbounds.json | jq -c '.[]' | while read -r user; do
            local email=
            email=$(echo "${user}" | jq -r .email//.name)
            echo
            local path="${currentPath}xHTTP"

            local count=
            while read -r line; do
        echoContent skyBlue "============================= VLESS reality_vision  ==============================\n"
                if [[ -z "${line}" ]]; then
                    line=$(getPublicIP)
                fi
                if [[ -n "${line}" ]]; then
                    defaultBase64Code vlessXHTTP "${xrayVLESSRealityXHTTPort}" "${email}${count}" "$(echo "${user}" | jq -r .id//.uuid)" "${line}" "${path}"
                    count=$((count + 1))
                    echo
                fi
            done < <(echo "${currentCDNAddress}" | tr ',' '\n')
        done
    fi
    # AnyTLS
    if echo ${currentInstallProtocolType} | grep -q ",13,"; then
        echoContent skyBlue "\n================================  AnyTLS ================================\n"

        jq -r -c '.inbounds[]|.users[]' "${configPath}13_anytls_inbounds.json" | while read -r user; do
            echoContent skyBlue "\n ---> Account:$(echo "${user}" | jq -r .name)"
            echo
            defaultBase64Code anytls "${singBoxAnyTLSPort}" "$(echo "${user}" | jq -r .name)" "$(echo "${user}" | jq -r .password)"
        done

    fi
}
# Remove nginx302 configuration
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

# Check if 302 is successful
checkNginx302() {
    local domain302Status=
    domain302Status=$(curl -s "https://${currentHost}:${currentPort}")
    if echo "${domain302Status}" | grep -q "302"; then
        #        local domain302Result=
        #        domain302Result=$(curl -L -s "https://${currentHost}:${currentPort}")
        #        if [[ -n "${domain302Result}" ]]; then
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3A%2F%2F${id}%40${currentHost}%3A${currentDefaultPort}%3Fencryption%3Dnone%26security%3Dxtls%26type%3Dtcp%26${currentHost}%3D${currentHost}%26headerType%3Dnone%26sni%3D${currentHost}%26flow%3Dxtls-rprx-vision%23${email}\n"
        exit 0
        #        fi
    fi
        echoContent red " ---> Range cannot be empty"
    backupNginxConfig restoreBackup
}

# Backup and restore nginx files
backupNginxConfig() {
    if [[ "$1" == "backup" ]]; then
        cp ${nginxConfigPath}alone.conf /etc/v2ray-agent/alone_backup.conf
        echoContent green "    {\"port\":${currentDefaultPort},\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${currentHost}\",\"type\":\"none\",\"path\":\"/${currentPath}vws\",\"net\":\"ws\",\"add\":\"${add}\",\"allowInsecure\":0,\"method\":\"none\",\"peer\":\"${currentHost}\",\"sni\":\"${currentHost}\"}\n"
    fi

    if [[ "$1" == "restoreBackup" ]] && [[ -f "/etc/v2ray-agent/alone_backup.conf" ]]; then
        cp /etc/v2ray-agent/alone_backup.conf ${nginxConfigPath}alone.conf
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        rm /etc/v2ray-agent/alone_backup.conf
    fi

}
# Add 302 configuration
addNginx302() {

    # 	local line302Result=
    # 	line302Result=$(| tail -n 1)
    local count=1
    grep -n "location / {" <"${nginxConfigPath}alone.conf" | while read -r line; do
        if [[ -n "${line}" ]]; then
            local insertIndex=
            insertIndex="$(echo "${line}" | awk -F "[:]" '{print $1}')"
            insertIndex=$((insertIndex + count))
            sed "${insertIndex}i return 302 '$1';" ${nginxConfigPath}alone.conf >${nginxConfigPath}tmpfile && mv ${nginxConfigPath}tmpfile ${nginxConfigPath}alone.conf
            count=$((count + 1))
        else
            echoContent red " ---> The range is illegal"
            backupNginxConfig restoreBackup
        fi

    done
}

# Update camouflage station
updateNginxBlog() {
    if [[ "${coreInstallType}" == "2" ]]; then
            echoContent red " ---> The range is illegal"
        exit 0
    fi

            echoContent skyBlue "\n --->Account:${email}"

    if ! echo "${currentInstallProtocolType}" | grep -q ",0," || [[ -z "${coreInstallType}" ]]; then
                echoContent red " ---> Failed to add port hopping"
        exit 0
    fi
    echoContent red "=============================================================="
        echoContent yellow " ---> QR code Trojan(Trojan+TCP+TLS_Vision)"
        echoContent yellow " ---> Universal json(VMess+WS+TLS)"
        echoContent yellow " ---> Universal vmess (VMess+WS+TLS) link"
        echoContent yellow " ---> QR code vmess(VMess+WS+TLS)"
        echoContent yellow " ---> Universal format (VLESS+WS+TLS)"
        echoContent yellow " ---> Formatted plain text (VLESS+WS+TLS)"
    echoContent yellow "6.mikutap[https://github.com/HFIProgramming/mikutap]"
        echoContent yellow " ---> QR code VLESS(VLESS+WS+TLS)"
        echoContent yellow " ---> Universal format (VLESS+gRPC+TLS)"
        echoContent yellow " ---> Formatted plain text (VLESS+gRPC+TLS)"
        echoContent yellow " ---> QR code VLESS(VLESS+gRPC+TLS)"
    echoContent red "=============================================================="
    read -r -p "Please select:" selectInstallNginxBlogType

    if [[ "${selectInstallNginxBlogType}" == "10" ]]; then
        if [[ "${coreInstallType}" == "2" ]]; then
        echoContent red " ---> Unable to recognize iptables tool, unable to use port jump, exit installation"
            exit 0
        fi
        echoContent red "\n=============================================================="
        echoContent yellow " ---> Trojan(TLS)"
        echoContent yellow " ---> QR code Trojan(TLS)"
        echoContent yellow " ---> Trojan gRPC(TLS)"
        echoContent yellow " ---> QR code Trojan gRPC(TLS)"
        echoContent red "=============================================================="
        read -r -p "Please select:" redirectStatus

        if [[ "${redirectStatus}" == "1" ]]; then
            backupNginxConfig backup
            read -r -p "Please enter the domain name to be redirected, for example https://www.baidu.com:" redirectDomain
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
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"
            exit 0
        fi
    fi
    if [[ "${selectInstallNginxBlogType}" =~ ^[1-9]$ ]]; then
        rm -rf "${nginxStaticPath}*"

        if [[ "${release}" == "alpine" ]]; then
            wget -q -P "${nginxStaticPath}" "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${selectInstallNginxBlogType}.zip"
        else
            wget -q "${wgetShowProgressStatus}" -P "${nginxStaticPath}" "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${selectInstallNginxBlogType}.zip"
        fi

        unzip -o "${nginxStaticPath}html${selectInstallNginxBlogType}.zip" -d "${nginxStaticPath}" >/dev/null
        rm -f "${nginxStaticPath}html${selectInstallNginxBlogType}.zip*"
        echoContent green " vless://${id}@${add}:${currentDefaultPort}?encryption=none&security=tls&type=ws&host=${currentHost}&sni=${currentHost}&fp=chrome&path=/${currentPath}ws #${email}\n"
    else
    echoContent red "\n================================================ ================="
        updateNginxBlog
    fi
}

#Add new port
addCorePort() {

    if [[ "${coreInstallType}" == "2" ]]; then
        echoContent red " ---> Port cannot be empty"
        exit 0
    fi

        echoContent skyBlue "============================== VLESS reality_gRPC  ===============================\n"
    echoContent red "\n=============================================================="
        echoContent yellow " ---> Hysteria(TLS)"
        echoContent yellow " ---> v2rayN(hysteria+TLS)"
        echoContent yellow " ---> QR code Hysteria(TLS)"
        echoContent yellow " ---> Universal format (VLESS+reality+uTLS+Vision)"
        echoContent yellow " ---> Formatted plain text (VLESS+reality+uTLS+Vision)"
        echoContent yellow " ---> QR code VLESS(VLESS+reality+uTLS+Vision)"
        echoContent yellow " ---> Universal format (VLESS+reality+uTLS+gRPC)"

        echoContent yellow " ---> Formatted plain text (VLESS+reality+uTLS+gRPC)"
        echoContent yellow " ---> QR code VLESS(VLESS+reality+uTLS+gRPC)"
        echoContent yellow " ---> Formatted plain text (Tuic+TLS)"
    echoContent red "=============================================================="
    read -r -p "Please select:" selectNewPortType
    if [[ "${selectNewPortType}" == "1" ]]; then
        find ${configPath} -name "*dokodemodoor*" | grep -v "hysteria" | awk -F "[c][o][n][f][/]" '{print $2}' | awk -F "[_]" '{print $4}' | awk -F "[.]" '{print ""NR""":"$1}'
        exit 0
    elif [[ "${selectNewPortType}" == "2" ]]; then
        read -r -p "Please enter the port number:" newPort
        read -r -p "Please enter the default port number. The subscription port and node port will be changed at the same time. [Enter] Default 443:" defaultPort

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

        echoContent green "Protocol type: VLESS, address: ${add}, disguised domain name/SNI: ${currentHost}, port: ${currentDefaultPort}, client-fingerprint: chrome, user ID: ${id}, security: tls, Transmission method: ws, path: /${currentPath}ws, account name: ${email}\n"
            reloadCore
            addCorePort
        fi
    elif [[ "${selectNewPortType}" == "3" ]]; then
        find ${configPath} -name "*dokodemodoor*" | grep -v "hysteria" | awk -F "[c][o][n][f][/]" '{print $2}' | awk -F "[_]" '{print $4}' | awk -F "[.]" '{print ""NR""":"$1}'
        read -r -p "Please enter the port number to be deleted:" portIndex
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
        echoContent yellow " ---> v2rayN(Tuic+TLS)"
            addCorePort
        fi
    fi
}

# Uninstall script
unInstall() {
    read -r -p "Are you sure you want to uninstall the installation content? [y/n]:" unInstallStatus
    if [[ "${unInstallStatus}" != "y" ]]; then
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${currentDefaultPort}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dws%26host%3D${currentHost}%26fp%3Dchrome%26sni%3D${currentHost}%26path%3D%252f${currentPath}ws%23${email}"
        menu
        exit 0
    fi
    # checkBTPanel
        echoContent yellow "\n --->Tuic will be warmer and may have a smoother user experience than Hysteria."
    handleNginx stop
    if [[ -z $(pgrep -f "nginx") ]]; then
        echoContent green "    vless://${id}@${add}:${currentDefaultPort}?encryption=none&security=tls&type=grpc&host=${currentHost}&path=${currentPath}grpc&fp=chrome&serviceName=${currentPath}grpc&alpn=h2&sni=${currentHost}#${email}\n"
    fi
    if [[ "${release}" == "alpine" ]]; then
        if [[ "${coreInstallType}" == "1" ]]; then
            handleXray stop
            rc-update del xray default
            rm -rf /etc/init.d/xray
        echoContent green "Protocol type: VLESS, address: ${add}, disguised domain name/SNI: ${currentHost}, port: ${currentDefaultPort}, user ID: ${id}, security: tls, transmission method: gRPC, alpn :h2, client-fingerprint: chrome, serviceName: ${currentPath}grpc, account name: ${email}\n"
        fi
        if [[ "${coreInstallType}" == "2" || -n "${singBoxConfigPath}" ]]; then
            handleSingBox stop
            rc-update del sing-box default
            rm -rf /etc/init.d/sing-box
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${currentDefaultPort}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dgrpc%26host%3D${currentHost}%26serviceName%3D${currentPath}grpc%26fp%3Dchrome%26path%3D${currentPath}grpc%26sni%3D${currentHost}%26alpn%3Dh2%23${email}"
        fi
    else
        if [[ "${coreInstallType}" == "1" ]]; then
            handleXray stop
            rm -rf /etc/systemd/system/xray.service
        echoContent green "    trojan://${id}@${currentHost}:${currentDefaultPort}?peer=${currentHost}&fp=chrome&sni=${currentHost}&alpn=http/1.1#${currentHost}_Trojan\n"
        fi
        if [[ "${coreInstallType}" == "2" || -n "${singBoxConfigPath}" ]]; then
            handleSingBox stop
            rm -rf /etc/systemd/system/sing-box.service
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${currentHost}%3a${port}%3fpeer%3d${currentHost}%26fp%3Dchrome%26sni%3d${currentHost}%26alpn%3Dhttp/1.1%23${email}\n"
        fi
    fi

    # if [[ -f "/root/.acme.sh/acme.sh.env" ]] && grep -q 'acme.sh.env' </root/.bashrc; then
    # sed -i 's/. "\/root\/.acme.sh\/acme.sh.env"//g' "$(grep '. "/root/.acme.sh/acme.sh.env "' -rl /root/.bashrc)"
    #fi
    # rm -rf /root/.acme.sh

    #rm -rf /tmp/v2ray-agent-tls/*
    # if [[ -d "/etc/v2ray-agent/tls" ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.key") ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.crt") ]]; then
    # mv /etc/v2ray-agent/tls /tmp/v2ray-agent-tls
    # if [[ -n $(find /tmp/v2ray-agent-tls -name '*.key') ]]; then
    # echoContent yellow " ---> Backup certificate successful, please save it. [/tmp/v2ray-agent-tls]"
    #fi
    #fi

    rm -rf /etc/v2ray-agent
    rm -rf ${nginxConfigPath}alone.conf
    rm -rf ${nginxConfigPath}checkPortOpen.conf >/dev/null 2>&1
    rm -rf "${nginxConfigPath}sing_box_VMess_HTTPUpgrade.conf" >/dev/null 2>&1
    rm -rf ${nginxConfigPath}checkPortOpen.conf >/dev/null 2>&1

    unInstallSubscribe

    if [[ -d "${nginxStaticPath}" && -f "${nginxStaticPath}/check" ]]; then
        rm -rf "${nginxStaticPath}"
        echoContent green "    trojan://${id}@${add}:${currentDefaultPort}?encryption=none&peer=${currentHost}&fp=chrome&security=tls&type=grpc&sni=${currentHost}&alpn=h2&path=${currentPath}trojangrpc&serviceName=${currentPath}trojangrpc#${email}\n"
    fi

    rm -rf /usr/bin/vasma
    rm -rf /usr/sbin/vasma
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${add}%3a${currentDefaultPort}%3Fencryption%3Dnone%26fp%3Dchrome%26security%3Dtls%26peer%3d${currentHost}%26type%3Dgrpc%26sni%3d${currentHost}%26path%3D${currentPath}trojangrpc%26alpn%3Dh2%26serviceName%3D${currentPath}trojangrpc%23${email}\n"
        echoContent green "    hysteria://${currentHost}:${hysteriaPort}?${mport}protocol=${hysteriaProtocol}&auth=${id}&peer=${currentHost}&insecure=0&alpn=h3&upmbps=${hysteriaClientUploadSpeed}&downmbps=${hysteriaClientDownloadSpeed}#${hysteriaEmail}\n"
}

manageCDN() {
            echoContent skyBlue "\n --->Account:${email}"
    local setCDNDomain=

    if echo "${currentInstallProtocolType}" | grep -qE ",1,|,2,|,3,|,5,|,11,"; then
        echoContent red "=============================================================="
    echoContent yellow "# If you need to customize, please manually copy the template file to ${nginxStaticPath} \n"
    echoContent yellow "1.Newbie guide"
        echoContent skyBlue "https://www.v2ray-agent.com/archives/cloudflarezi-xuan-ip"
        echoContent red " ---> The port is illegal"

        echoContent yellow "1.CNAME www.digitalocean.com"
        echoContent yellow "2.CNAME who.int"
        echoContent yellow "3.CNAME blog.hostmonit.com"
        echoContent yellow "4.CNAME www.visa.com.hk"
    echoContent yellow "2.Game website"
    echoContent yellow "3.Personal blog 01"
        echoContent red "=============================================================="
        read -r -p "Please select:" selectCDNType
        case ${selectCDNType} in
        1)
            setCDNDomain="www.digitalocean.com"
            ;;
        2)
            setCDNDomain="who.int"
            ;;
        3)
            setCDNDomain="blog.hostmonit.com"
            ;;
        4)
            setCDNDomain="www.visa.com.hk"
            ;;
        5)
        read -r -p "Enter the custom CDN IP or domain:" setCDNDomain
            ;;
        6)
            echo >/etc/v2ray-agent/cdn
        echoContent green "${v2rayNConf}\n"
            exit 0
            ;;
        esac

        if [[ -n "${setCDNDomain}" ]]; then
            echo >/etc/v2ray-agent/cdn
            echo "${setCDNDomain}" >"/etc/v2ray-agent/cdn"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=hysteria%3A%2F%2F${currentHost}%3A${hysteriaPort}%3F${mport}protocol%3D${hysteriaProtocol}%26auth%3D${id}%26peer%3D${currentHost}%26insecure%3D0%26alpn%3Dh3%26upmbps%3D${hysteriaClientUploadSpeed}%26downmbps%3D${hysteriaClientDownloadSpeed}%23${hysteriaEmail}\n"
            subscribe false false
        else
    echoContent red "================================================== ==============="
            manageCDN 1
        fi
    else
    echoContent yellow "4.Enterprise Station"
        echoContent skyBlue "https://www.v2ray-agent.com/archives/cloudflarezi-xuan-ip\n"
    echoContent red "================================================== =========== ===="
    fi
}
# Custom uuid
customUUID() {
        read -r -p "Please enter a valid UUID:" currentCustomUUID
    echo
    if [[ -z "${currentCustomUUID}" ]]; then
        if [[ "${selectInstallType}" == "1" || "${coreInstallType}" == "1" ]]; then
            currentCustomUUID=$(${ctlPath} uuid)
        elif [[ "${selectInstallType}" == "2" || "${coreInstallType}" == "2" ]]; then
            currentCustomUUID=$(${ctlPath} generate uuid)
        fi

        echoContent yellow "uuid：${currentCustomUUID}\n"

    else
        local checkUUID=
        if [[ "${coreInstallType}" == "1" ]]; then
            checkUUID=$(jq -r --arg currentUUID "$currentCustomUUID" "(.inbounds[0].settings.clients // .inbounds[1].settings.clients)[]? | select(.id == \$currentUUID) | .email" ${configPath}${frontingType:-$frontingTypeReality}.json)
        elif [[ "${coreInstallType}" == "2" ]]; then
            checkUUID=$(jq -r --arg currentUUID "$currentCustomUUID" ".inbounds[0].users[] | select(.uuid == \$currentUUID) | .name//.username" ${configPath}${frontingType}.json)
        fi

        if [[ -n "${checkUUID}" ]]; then
        echoContent red "\n ---> Due to environmental dependencies, if you install Tuic, please install Xray-core's VLESS_TCP_TLS_Vision first"
            exit 0
        fi
    fi
}

# Custom email
customUserEmail() {
    read -r -p "Please enter a valid email, [Enter] random email:" currentCustomEmail
    echo
    if [[ -z "${currentCustomEmail}" ]]; then
        currentCustomEmail="${currentCustomUUID}"
        echoContent yellow "email: ${currentCustomEmail}\n"
    else
        local checkEmail=
        if [[ "${coreInstallType}" == "1" ]]; then
            local frontingTypeConfig="${frontingType}"
            if [[ "${currentInstallProtocolType}" == ",7,8," ]]; then
                frontingTypeConfig="07_VLESS_vision_reality_inbounds"
            fi

            checkEmail=$(jq -r --arg currentEmail "$currentCustomEmail" "(.inbounds[0].settings.clients // .inbounds[1].settings.clients)[]? | select(.email == \$currentEmail) | .email" ${configPath}${frontingTypeConfig:-$frontingTypeReality}.json)
        elif
            [[ "${coreInstallType}" == "2" ]]
        then
            checkEmail=$(jq -r --arg currentEmail "$currentCustomEmail" ".inbounds[0].users[] | select(.name == \$currentEmail) | .name" ${configPath}${frontingType}.json)
        fi

        if [[ -n "${checkEmail}" ]]; then
        echoContent red "\n ---> uuid reading error, regenerate"
            exit 0
        fi
    fi
}

# Add user
addUser() {
    read -r -p "Please enter the number of users to add:" userNum
    echo
    if [[ -z ${userNum} || ${userNum} -le 0 ]]; then
    echoContent red " ---> Trojan does not currently support xtls-rprx-vision"
        exit 0
    fi
    local userConfig=
    if [[ "${coreInstallType}" == "1" ]]; then
        userConfig=".inbounds[0].settings.clients"
    elif [[ "${coreInstallType}" == "2" ]]; then
        userConfig=".inbounds[0].users"
    fi

    while [[ ${userNum} -gt 0 ]]; do
        readConfigHostPathUUID
        local users=
        ((userNum--)) || true

        customUUID
        customUserEmail

        uuid=${currentCustomUUID}
        email=${currentCustomEmail}

        # VLESS TCP
        if echo "${currentInstallProtocolType}" | grep -q ",0,"; then
            local clients=
            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 0 "${uuid}" "${email}")
            elif [[ "${coreInstallType}" == "2" ]]; then
                clients=$(initSingBoxClients 0 "${uuid}" "${email}")
            fi
            clients=$(jq -r "${userConfig} = ${clients}" ${configPath}02_VLESS_TCP_inbounds.json)
            echo "${clients}" | jq . >${configPath}02_VLESS_TCP_inbounds.json
        fi

        # VLESS WS
        if echo "${currentInstallProtocolType}" | grep -q ",1,"; then
            local clients=
            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 1 "${uuid}" "${email}")
            elif [[ "${coreInstallType}" == "2" ]]; then
                clients=$(initSingBoxClients 1 "${uuid}" "${email}")
            fi

            clients=$(jq -r "${userConfig} = ${clients}" ${configPath}03_VLESS_WS_inbounds.json)
            echo "${clients}" | jq . >${configPath}03_VLESS_WS_inbounds.json
        fi

        # trojan grpc
        if echo "${currentInstallProtocolType}" | grep -q ",2,"; then
            local clients=
            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 2 "${uuid}" "${email}")
            elif [[ "${coreInstallType}" == "2" ]]; then
                clients=$(initSingBoxClients 2 "${uuid}" "${email}")
            fi

            clients=$(jq -r "${userConfig} = ${clients}" ${configPath}04_trojan_gRPC_inbounds.json)
            echo "${clients}" | jq . >${configPath}04_trojan_gRPC_inbounds.json
        fi
        # VMess WS
        if echo "${currentInstallProtocolType}" | grep -q ",3,"; then
            local clients=
            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 3 "${uuid}" "${email}")
            elif [[ "${coreInstallType}" == "2" ]]; then
                clients=$(initSingBoxClients 3 "${uuid}" "${email}")
            fi

            clients=$(jq -r "${userConfig} = ${clients}" ${configPath}05_VMess_WS_inbounds.json)
            echo "${clients}" | jq . >${configPath}05_VMess_WS_inbounds.json
        fi
        # trojan tcp
        if echo "${currentInstallProtocolType}" | grep -q ",4,"; then
            local clients=
            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 4 "${uuid}" "${email}")
            elif [[ "${coreInstallType}" == "2" ]]; then
                clients=$(initSingBoxClients 4 "${uuid}" "${email}")
            fi
            clients=$(jq -r "${userConfig} = ${clients}" ${configPath}04_trojan_TCP_inbounds.json)
            echo "${clients}" | jq . >${configPath}04_trojan_TCP_inbounds.json
        fi

        # vless grpc
        if echo "${currentInstallProtocolType}" | grep -q ",5,"; then
            local clients=
            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 5 "${uuid}" "${email}")
            elif [[ "${coreInstallType}" == "2" ]]; then
                clients=$(initSingBoxClients 5 "${uuid}" "${email}")
            fi
            clients=$(jq -r "${userConfig} = ${clients}" ${configPath}06_VLESS_gRPC_inbounds.json)
            echo "${clients}" | jq . >${configPath}06_VLESS_gRPC_inbounds.json
        fi

        # vless reality vision
        if echo "${currentInstallProtocolType}" | grep -q ",7,"; then
            local clients=
            local realityUserConfig=
            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 7 "${uuid}" "${email}")
                realityUserConfig=".inbounds[1].settings.clients"
            elif [[ "${coreInstallType}" == "2" ]]; then
                clients=$(initSingBoxClients 7 "${uuid}" "${email}")
                realityUserConfig=".inbounds[0].users"
            fi
            clients=$(jq -r "${realityUserConfig} = ${clients}" ${configPath}07_VLESS_vision_reality_inbounds.json)
            echo "${clients}" | jq . >${configPath}07_VLESS_vision_reality_inbounds.json
        fi

        # vless reality grpc
        if echo "${currentInstallProtocolType}" | grep -q ",8,"; then
            local clients=
            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 8 "${uuid}" "${email}")
            elif [[ "${coreInstallType}" == "2" ]]; then
                clients=$(initSingBoxClients 8 "${uuid}" "${email}")
            fi
            clients=$(jq -r "${userConfig} = ${clients}" ${configPath}08_VLESS_vision_gRPC_inbounds.json)
            echo "${clients}" | jq . >${configPath}08_VLESS_vision_gRPC_inbounds.json
        fi

        # hysteria2
        if echo ${currentInstallProtocolType} | grep -q ",6,"; then
            local clients=

            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 6 "${uuid}" "${email}")
            elif [[ -n "${singBoxConfigPath}" ]]; then
                clients=$(initSingBoxClients 6 "${uuid}" "${email}")
            fi

            clients=$(jq -r ".inbounds[0].users = ${clients}" "${singBoxConfigPath}06_hysteria2_inbounds.json")
            echo "${clients}" | jq . >"${singBoxConfigPath}06_hysteria2_inbounds.json"
        fi

        # tuic
        if echo ${currentInstallProtocolType} | grep -q ",9,"; then
            local clients=
            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 9 "${uuid}" "${email}")
            elif [[ "${coreInstallType}" == "2" ]]; then
                clients=$(initSingBoxClients 9 "${uuid}" "${email}")
            fi

            clients=$(jq -r ".inbounds[0].users = ${clients}" "${singBoxConfigPath}09_tuic_inbounds.json")

            echo "${clients}" | jq . >"${singBoxConfigPath}09_tuic_inbounds.json"
        fi
        # naive
        if echo ${currentInstallProtocolType} | grep -q ",10,"; then
            local clients=
            clients=$(initSingBoxClients 10 "${uuid}" "${email}")
            clients=$(jq -r ".inbounds[0].users = ${clients}" "${singBoxConfigPath}10_naive_inbounds.json")

            echo "${clients}" | jq . >"${singBoxConfigPath}10_naive_inbounds.json"
        fi
        # VMess WS
        if echo "${currentInstallProtocolType}" | grep -q ",11,"; then
            local clients=
            if [[ "${coreInstallType}" == "1" ]]; then
                clients=$(initXrayClients 11 "${uuid}" "${email}")
            elif [[ "${coreInstallType}" == "2" ]]; then
                clients=$(initSingBoxClients 11 "${uuid}" "${email}")
            fi

            clients=$(jq -r "${userConfig} = ${clients}" ${configPath}11_VMess_HTTPUpgrade_inbounds.json)
            echo "${clients}" | jq . >${configPath}11_VMess_HTTPUpgrade_inbounds.json
        fi
        # anytls
        if echo "${currentInstallProtocolType}" | grep -q ",13,"; then
            local clients=
            clients=$(initSingBoxClients 13 "${uuid}" "${email}")

            clients=$(jq -r "${userConfig} = ${clients}" ${configPath}13_anytls_inbounds.json)
            echo "${clients}" | jq . >${configPath}13_anytls_inbounds.json
        fi
    done
    reloadCore
        echoContent green "    vless://${id}@$(getPublicIP):${currentRealityPort}?encryption=none&security=reality&type=tcp&sni=${currentRealityServerNames}&fp=chrome&pbk=${currentRealityPublicKey}&sid=6ba85179e30d4fc2&flow=xtls-rprx-vision#${email}\n"
    readNginxSubscribe
    if [[ -n "${subscribePort}" ]]; then
        subscribe false
    fi
    manageAccount 1
}
# Remove user
removeUser() {

    local uuid=
    if [[ "${coreInstallType}" == "1" ]]; then
        jq -r -c '(.inbounds[0].settings.clients // .inbounds[1].settings.clients)[]?|.email' ${configPath}${frontingType:-$frontingTypeReality}.json | awk '{print NR""":"$0}'
        read -r -p "Please select the user number to delete [only supports single deletion]:" delUserIndex
        if [[ $(jq -r '(.inbounds[0].settings.clients // .inbounds[1].settings.clients)?|length' ${configPath}${frontingType:-$frontingTypeReality}.json) -lt ${delUserIndex} ]]; then
        echoContent red " ---> Not installed, please use script to install"
        else
            delUserIndex=$((delUserIndex - 1))
        fi
    elif [[ "${coreInstallType}" == "2" ]]; then
        jq -r -c .inbounds[0].users[].name//.inbounds[0].users[].username ${configPath}${frontingType:-$frontingTypeReality}.json | awk '{print NR""":"$0}'
        read -r -p "Please select the user number to delete [only supports single deletion]:" delUserIndex
        if [[ $(jq -r '.inbounds[0].users|length' ${configPath}${frontingType:-$frontingTypeReality}.json) -lt ${delUserIndex} ]]; then
        echoContent red " ---> Available types are not installed"
        else
            delUserIndex=$((delUserIndex - 1))
        fi
    fi

    if [[ -n "${delUserIndex}" ]]; then

        if echo ${currentInstallProtocolType} | grep -q ",0,"; then
            local vlessVision
            vlessVision=$(jq -r 'del(.inbounds[0].settings.clients['"${delUserIndex}"']//.inbounds[0].users['"${delUserIndex}"'])' ${configPath}02_VLESS_TCP_inbounds.json)
            echo "${vlessVision}" | jq . >${configPath}02_VLESS_TCP_inbounds.json
        fi
        if echo ${currentInstallProtocolType} | grep -q ",1,"; then
            local vlessWSResult
            vlessWSResult=$(jq -r 'del(.inbounds[0].settings.clients['"${delUserIndex}"']//.inbounds[0].users['"${delUserIndex}"'])' ${configPath}03_VLESS_WS_inbounds.json)
            echo "${vlessWSResult}" | jq . >${configPath}03_VLESS_WS_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q ",2,"; then
            local trojangRPCUsers
            trojangRPCUsers=$(jq -r 'del(.inbounds[0].settings.clients['"${delUserIndex}"']//.inbounds[0].users['"${delUserIndex}"')' ${configPath}04_trojan_gRPC_inbounds.json)
            echo "${trojangRPCUsers}" | jq . >${configPath}04_trojan_gRPC_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q ",3,"; then
            local vmessWSResult
            vmessWSResult=$(jq -r 'del(.inbounds[0].settings.clients['"${delUserIndex}"']//.inbounds[0].users['"${delUserIndex}"'])' ${configPath}05_VMess_WS_inbounds.json)
            echo "${vmessWSResult}" | jq . >${configPath}05_VMess_WS_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q ",5,"; then
            local vlessGRPCResult
            vlessGRPCResult=$(jq -r 'del(.inbounds[0].settings.clients['"${delUserIndex}"']//.inbounds[0].users['"${delUserIndex}"'])' ${configPath}06_VLESS_gRPC_inbounds.json)
            echo "${vlessGRPCResult}" | jq . >${configPath}06_VLESS_gRPC_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q ",4,"; then
            local trojanTCPResult
            trojanTCPResult=$(jq -r 'del(.inbounds[0].settings.clients['"${delUserIndex}"']//.inbounds[0].users['"${delUserIndex}"'])' ${configPath}04_trojan_TCP_inbounds.json)
            echo "${trojanTCPResult}" | jq . >${configPath}04_trojan_TCP_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q ",6,"; then
            local hysteriaResult
            hysteriaResult=$(jq -r 'del(.inbounds[0].users['"${delUserIndex}"'])' "${singBoxConfigPath}06_hysteria2_inbounds.json")
            echo "${hysteriaResult}" | jq . >"${singBoxConfigPath}06_hysteria2_inbounds.json"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",7,"; then
            local vlessRealityResult
            vlessRealityResult=$(jq -r 'del(.inbounds[1].settings.clients['"${delUserIndex}"']//.inbounds[0].users['"${delUserIndex}"'])' ${configPath}07_VLESS_vision_reality_inbounds.json)
            echo "${vlessRealityResult}" | jq . >${configPath}07_VLESS_vision_reality_inbounds.json
        fi
        if echo ${currentInstallProtocolType} | grep -q ",8,"; then
            local vlessRealityGRPCResult
            vlessRealityGRPCResult=$(jq -r 'del(.inbounds[0].settings.clients['"${delUserIndex}"']//.inbounds[0].users['"${delUserIndex}"'])' ${configPath}08_VLESS_vision_gRPC_inbounds.json)
            echo "${vlessRealityGRPCResult}" | jq . >${configPath}08_VLESS_vision_gRPC_inbounds.json
        fi

        if echo ${currentInstallProtocolType} | grep -q ",9,"; then
            local tuicResult
            tuicResult=$(jq -r 'del(.inbounds[0].users['"${delUserIndex}"'])' "${singBoxConfigPath}09_tuic_inbounds.json")
            echo "${tuicResult}" | jq . >"${singBoxConfigPath}09_tuic_inbounds.json"
        fi
        if echo ${currentInstallProtocolType} | grep -q ",10,"; then
            local naiveResult
            naiveResult=$(jq -r 'del(.inbounds[0].users['"${delUserIndex}"'])' "${singBoxConfigPath}10_naive_inbounds.json")
            echo "${naiveResult}" | jq . >"${singBoxConfigPath}10_naive_inbounds.json"
        fi
        # VMess HTTPUpgrade
        if echo ${currentInstallProtocolType} | grep -q ",11,"; then
            local vmessHTTPUpgradeResult
            vmessHTTPUpgradeResult=$(jq -r 'del(.inbounds[0].users['"${delUserIndex}"'])' "${singBoxConfigPath}11_VMess_HTTPUpgrade_inbounds.json")
            echo "${vmessHTTPUpgradeResult}" | jq . >"${singBoxConfigPath}11_VMess_HTTPUpgrade_inbounds.json"
            echo "${vmessHTTPUpgradeResult}" | jq . >${configPath}11_VMess_HTTPUpgrade_inbounds.json
        fi
        # AnyTLS
        if echo ${currentInstallProtocolType} | grep -q ",13,"; then
            local anyTLSResult
            anyTLSResult=$(jq -r 'del(.inbounds[0].users['"${delUserIndex}"'])' "${singBoxConfigPath}13_anytls_inbounds.json")
            echo "${anyTLSResult}" | jq . >"${singBoxConfigPath}13_anytls_inbounds.json"
        fi
        reloadCore
        readNginxSubscribe
        if [[ -n "${subscribePort}" ]]; then
            subscribe false
        fi
    fi
    manageAccount 1
}
# update script
updateV2RayAgent() {
        echoContent skyBlue "\n================================  Tuic TLS  ================================\n"
    rm -rf /etc/v2ray-agent/install.sh
    if [[ "${release}" == "alpine" ]]; then
        wget -c -q -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
    else
    # if wget --help | grep -q show-progress; then
        wget -c -q "${wgetShowProgressStatus}" -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
    fi

    #else
    # wget -c -q -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
    #fi

    sudo chmod 700 /etc/v2ray-agent/install.sh
    local version
    version=$(grep 'Current version: v' "/etc/v2ray-agent/install.sh" | awk -F "[v]" '{print $2}' | tail -n +2 | head -n 1 | awk -F "[\"]" '{print $1}')

        echoContent green "Protocol type: VLESS reality, address: $(getPublicIP), publicKey: ${currentRealityPublicKey}, shortId: 6ba85179e30d4fc2, serverNames: ${currentRealityServerNames}, port: ${currentRealityPort}, user ID: ${id}, transmission Method: tcp, account name: ${email}\n"
    echoContent yellow "5.Unlock encrypted music file template [https://github.com/ix64/unlock-music]"
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40$(getPublicIP)%3A${currentRealityPort}%3Fencryption%3Dnone%26security%3Dreality%26type%3Dtcp%26sni%3D${currentRealityServerNames}%26fp%3Dchrome%26pbk%3D${currentRealityPublicKey}%26pbk%3D6ba85179e30d4fc2%26flow%3Dxtls-rprx-vision%23${email}\n"
    echoContent yellow "6.mikutap[https://github.com/HFIProgramming/mikutap]"
    echoContent skyBlue "wget -P /root -N --no-check-certificate https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh && chmod 700 /root/install.sh && /root/install.sh"
    echo
    exit 0
}

# firewall
handleFirewall() {
    if systemctl status ufw 2>/dev/null | grep -q "active (exited)" && [[ "$1" == "stop" ]]; then
        systemctl stop ufw >/dev/null 2>&1
        systemctl disable ufw >/dev/null 2>&1
        echoContent green "    vless://${id}@$(getPublicIP):${currentRealityPort}?encryption=none&security=reality&type=grpc&sni=${currentRealityServerNames}&fp=chrome&pbk=${currentRealityPublicKey}&sid=6ba85179e30d4fc2&path=grpc&serviceName=grpc#${email}\n"

    fi

    if systemctl status firewalld 2>/dev/null | grep -q "active (running)" && [[ "$1" == "stop" ]]; then
        systemctl stop firewalld >/dev/null 2>&1
        systemctl disable firewalld >/dev/null 2>&1
        echoContent green "Protocol type: VLESS reality, serviceName: grpc, address: $(getPublicIP), publicKey: ${currentRealityPublicKey}, shortId: 6ba85179e30d4fc2, serverNames: ${currentRealityServerNames}, port: ${currentRealityPort}, user ID: ${id}, transmission method: gRPC, client-fingerprint: chrome, account name: ${email}\n"
    fi
}

# Install BBR
bbrInstall() {
    echoContent red "\n=============================================================="
        echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40$(getPublicIP)%3A${currentRealityPort}%3Fencryption%3Dnone%26security%3Dreality%26type%3Dgrpc%26sni%3D${currentRealityServerNames}%26fp%3Dchrome%26pbk%3D${currentRealityPublicKey}%26pbk%3D6ba85179e30d4fc2%26path%3Dgrpc%26serviceName%3Dgrpc%23${email}\n"
    echoContent yellow "7.Enterprise Station 02"
    echoContent yellow "8.Personal blog 02"
    echoContent red "=============================================================="
    read -r -p "Please select:" installBBRStatus
    if [[ "${installBBRStatus}" == "1" ]]; then
        wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh
    else
        menu
    fi
}

# View and check logs
checkLog() {
    if [[ "${coreInstallType}" == "2" ]]; then
    echoContent red "\n================================================ ================="
        exit 0
    fi
    if [[ -z "${configPath}" && -z "${realityStatus}" ]]; then
    echoContent red "================================================== ==============="
        exit 0
    fi
    local realityLogShow=
    local logStatus=false
    if grep -q "access" ${configPath}00_log.json; then
        logStatus=true
    fi

                echoContent skyBlue "\n --->Account:${tuicEmail}_tuic"
    echoContent red "\n=============================================================="
    echoContent yellow "9.404 automatically jumps to baidu"

    if [[ "${logStatus}" == "false" ]]; then
    echoContent yellow "10.302 redirect website"
    else
        echoContent yellow "Redirect has a higher priority. If you change the camouflage site after configuring 302, the camouflage site under the root route will not work."
    fi

        echoContent yellow "If you want to disguise the site to achieve the function, you need to delete the 302 redirect configuration\n"
        echoContent yellow "1.Add"
        echoContent yellow "2.Delete"
    echoContent yellow "# Notes\n"
    echoContent yellow "Support batch addition"
    echoContent red "=============================================================="

    read -r -p "Please select:" selectAccessLogType
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

        if [[ ${realityStatus} == "7" ]]; then
            local vlessVisionRealityInbounds
            vlessVisionRealityInbounds=$(jq -r ".inbounds[0].streamSettings.realitySettings.show=${realityLogShow}" ${configPath}07_VLESS_vision_reality_inbounds.json)
            echo "${vlessVisionRealityInbounds}" | jq . >${configPath}07_VLESS_vision_reality_inbounds.json
        fi
        if [[ ${realityStatus} == "12" ]]; then
            local vlessVisionRealityXHTTPInbounds
            vlessVisionRealityXHTTPInbounds=$(jq -r ".inbounds[0].streamSettings.realitySettings.show=${realityLogShow}" ${configPath}12_VLESS_XHTTP_inbounds.json)
            echo "${vlessVisionRealityXHTTPInbounds}" | jq . >${configPath}12_VLESS_XHTTP_inbounds.json
        fi
        reloadCore
        checkLog 1
        ;;
    2)
        tail -f "${configPathLog}access.log"
        ;;
    3)
        tail -f "${configPathLog}error.log"
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
        echo >"${configPathLog}access.log"
        echo >"${configPathLog}error.log"
        ;;
    esac
}

# Script shortcut
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
        echoContent green "Protocol type: Tuic, address: ${currentHost}, port: ${tuicPort}, uuid: ${id}, password: ${id}, congestion-controller:${tuicAlgorithm}, alpn: h3, account Name:${email}_tuic\n"
        fi
    fi
}

# Check ipv6, ipv4
checkIPv6() {
    currentIPv6IP=$(curl -s -6 -m 4 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)

    if [[ -z "${currentIPv6IP}" ]]; then
        echoContent red "\n ---> uuid reading error, randomly generated"
        exit 0
    fi
}

# ipv6 offload
ipv6Routing() {
    if [[ -z "${configPath}" ]]; then
    echoContent red "\n================================================ ================="
        menu
        exit 0
    fi

    checkIPv6
    echoContent skyBlue "\nProgress$1/${totalProgress}: Change disguise site"
    echoContent red "\n=============================================================="
    echoContent yellow "Does not affect the use of the default port"
    echoContent yellow "When viewing accounts, only accounts with default ports will be displayed"
    echoContent yellow "No special characters allowed, pay attention to the comma format"
    echoContent yellow "If hysteria is already installed, a new hysteria port will be installed at the same time"
    echoContent red "=============================================================="
    read -r -p "Please select:" ipv6Status
    if [[ "${ipv6Status}" == "1" ]]; then
        showIPv6Routing
        exit 0
    elif [[ "${ipv6Status}" == "2" ]]; then
        echoContent red "=============================================================="
    echoContent yellow "Input example:2053,2083,2087\n"
    echoContent yellow "1.Check the added port"
    echoContent yellow "2.Add port"

        read -r -p "Please enter the domain name according to the above example:" domainList
        if [[ "${coreInstallType}" == "1" ]]; then
            addXrayRouting IPv6_out outboundTag "${domainList}"
            addXrayOutbound IPv6_out
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then
            addSingBoxRouteRule "IPv6_out" "${domainList}" "IPv6_route"
            addSingBoxOutbound 01_direct_outbound
            addSingBoxOutbound IPv6_out
            addSingBoxOutbound IPv4_out
        fi

        echoContent green "${v2rayNConf}"

    elif [[ "${ipv6Status}" == "3" ]]; then

        echoContent red "=============================================================="
    echoContent yellow "3.Delete port"
            echoContent yellow "\n ---> The number entered is wrong, please choose again"
    echoContent yellow " ---> The script will not delete acme related configurations. To delete, please execute manually [rm -rf /root/.acme.sh]"
        read -r -p "Confirm settings? [y/n]:" IPv6OutStatus

        if [[ "${IPv6OutStatus}" == "y" ]]; then
            if [[ "${coreInstallType}" == "1" ]]; then
                addXrayOutbound IPv6_out
                removeXrayOutbound IPv4_out
                removeXrayOutbound z_direct_outbound
                removeXrayOutbound blackhole_out
                removeXrayOutbound wireguard_out_IPv4
                removeXrayOutbound wireguard_out_IPv6
                removeXrayOutbound socks5_outbound

                rm ${configPath}09_routing.json >/dev/null 2>&1
            fi
            if [[ -n "${singBoxConfigPath}" ]]; then

                removeSingBoxConfig IPv4_out

                removeSingBoxConfig wireguard_endpoints_IPv4_route
                removeSingBoxConfig wireguard_endpoints_IPv6_route
                removeSingBoxConfig wireguard_endpoints_IPv4
                removeSingBoxConfig wireguard_endpoints_IPv6

                removeSingBoxConfig socks5_02_inbound_route

                removeSingBoxConfig IPv6_route

                removeSingBoxConfig 01_direct_outbound

                addSingBoxOutbound IPv6_out

            fi

            echoContent green " ---> 302 redirection set up successfully"
        else

        echoContent green " ---> nginx configuration file backup successful"
            exit 0
        fi

    elif [[ "${ipv6Status}" == "4" ]]; then
        if [[ "${coreInstallType}" == "1" ]]; then
            unInstallRouting IPv6_out outboundTag

            removeXrayOutbound IPv6_out
            addXrayOutbound "z_direct_outbound"
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then
            removeSingBoxConfig IPv6_out
            removeSingBoxConfig "IPv6_route"
            addSingBoxOutbound "01_direct_outbound"
        fi

        echoContent green " ---> nginx configuration file restoration backup successful"
    else
    echoContent red "\nIf you don't understand Cloudflare optimization, please do not use it"
        exit 0
    fi

    reloadCore
}

showIPv6Routing() {
    if [[ "${coreInstallType}" == "1" ]]; then
        if [[ -f "${configPath}09_routing.json" ]]; then
            echoContent yellow "Xray-core："
            jq -r -c '.routing.rules[]|select (.outboundTag=="IPv6_out")|.domain' ${configPath}09_routing.json | jq -r
        elif [[ ! -f "${configPath}09_routing.json" && -f "${configPath}IPv6_out.json" ]]; then
            echoContent yellow "Xray-core"
            echoContent green " ---> Removed 302 redirect successfully"
        else
        echoContent yellow "1.CNAME www.digitalocean.com"
        fi

    fi
    if [[ -n "${singBoxConfigPath}" ]]; then
        if [[ -f "${singBoxConfigPath}IPv6_route.json" ]]; then
            echoContent yellow "sing-box"
            jq -r -c '.route.rules[]|select (.outbound=="IPv6_out")' "${singBoxConfigPath}IPv6_route.json" | jq -r
        elif [[ ! -f "${singBoxConfigPath}IPv6_route.json" && -f "${singBoxConfigPath}IPv6_out.json" ]]; then
            echoContent yellow "sing-box"
        echoContent green " ---> Pseudo site replaced successfully"
        else
        echoContent yellow "2.CNAME who.int"
        fi
    fi
}
# bt download management
btTools() {
    if [[ "${coreInstallType}" == "2" ]]; then
            echoContent red " ---> Failed to read configuration, please reinstall"
        exit 0
    fi
    if [[ -z "${configPath}" ]]; then
        echoContent red "\n --->Hysteria speed depends on the local network environment. If it is used by QoS, the experience will be very poor. IDC may also consider it an attack, please use it with caution"
        menu
        exit 0
    fi

    echoContent skyBlue "\nFunction 1/${totalProgress}: Add new port"
    echoContent red "\n=============================================================="

    if [[ -f ${configPath}09_routing.json ]] && grep -q bittorrent <${configPath}09_routing.json; then
        echoContent yellow "3.CNAME blog.hostmonit.com"
    else
        echoContent yellow "4.Manual input [can enter multiple, such as:1.1.1.1,1.1.2.2, cloudflare.com separated by commas]"
    fi

        echoContent yellow "5.Remove CDN node"
    echoContent yellow "1.Add user"
    echoContent red "=============================================================="
    read -r -p "Please select:" btStatus
    if [[ "${btStatus}" == "1" ]]; then

        if [[ -f "${configPath}09_routing.json" ]]; then

            unInstallRouting blackhole_out outboundTag bittorrent

            routing=$(jq -r '.routing.rules += [{"type":"field","outboundTag":"blackhole_out","protocol":["bittorrent"]}]' ${configPath}09_routing.json)

            echo "${routing}" | jq . >${configPath}09_routing.json

        else
            cat <<EOF >${configPath}09_routing.json
{
    "routing":{
        "domainStrategy": "IPOnDemand",
        "rules": [
          {
            "type": "field",
            "outboundTag": "blackhole_out",
            "protocol": [ "bittorrent" ]
          }
        ]
  }
}
EOF
        fi

        installSniffing
        removeXrayOutbound blackhole_out
        addXrayOutbound blackhole_out

            echoContent green " ---> Added successfully"

    elif [[ "${btStatus}" == "2" ]]; then

        unInstallSniffing

        unInstallRouting blackhole_out outboundTag bittorrent

        echoContent green " ---> Give up uninstalling"
    else
        echoContent red " ---> not installed"
        exit 0
    fi

    reloadCore
}

# Domain name blacklist
blacklist() {
    if [[ -z "${configPath}" ]]; then
    echoContent red " ---> 302 redirection setting failed, please double check whether it is the same as the example"
        menu
        exit 0
    fi

    echoContent skyBlue "\nProgress$1/${totalProgress}: Modify CDN node"
    echoContent red "\n=============================================================="
    echoContent yellow "2.Delete user"
        echoContent yellow "uuid：${currentCustomUUID}\n"
        echoContent yellow "email: ${currentCustomEmail}\n"
    echoContent yellow "After adding a new user, you need to check the subscription again"
    echoContent yellow " ---> Please manually execute [vasma] to open the script"
    echoContent yellow "If the update fails, please manually execute the following command\n"
    echoContent red "=============================================================="

    read -r -p "Please select:" blacklistStatus
    if [[ "${blacklistStatus}" == "1" ]]; then
        jq -r -c '.routing.rules[]|select (.outboundTag=="blackhole_out")|.domain' ${configPath}09_routing.json | jq -r
        exit 0
    elif [[ "${blacklistStatus}" == "2" ]]; then
        echoContent red "=============================================================="
    echoContent yellow "1.Installation script [recommended original BBR+FQ]"
    echoContent yellow "2.Return to the home directory"
    echoContent yellow "# It is recommended to only open the access log during debugging\n"
        echoContent yellow "1.Open access log"
        echoContent yellow "1.Close access log"
    echoContent yellow "2.Monitor access log"
        read -r -p "Please enter the domain name according to the above example:" domainList
        if [[ "${coreInstallType}" == "1" ]]; then
            addXrayRouting blackhole_out outboundTag "${domainList}"
            addXrayOutbound blackhole_out
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then
            addSingBoxRouteRule "block_domain_outbound" "${domainList}" "block_domain_route"
            addSingBoxOutbound "block_domain_outbound"
            addSingBoxOutbound "01_direct_outbound"
        fi
        echoContent green " ---> Stop Nginx successfully"

    elif [[ "${blacklistStatus}" == "3" ]]; then
        local allowDomainList="googleplay.com,play.google.com,play.googleapis.com,play-lh.googleusercontent.com,play-games.googleusercontent.com,play-fe.googleapis.com,dl.google.com,apple.com,apple-pki,apple-tvplus,apple-update,itunes,icloud,beats,bing.com,microsoft.com,gstatic,xn--ngstr-lra8j.com,googleapis.com,googleapis.cn"

        if [[ "${coreInstallType}" == "1" ]]; then
            unInstallRouting blackhole_out outboundTag
            unInstallRouting blackhole_ip_out outboundTag

            addXrayRouting blackhole_out outboundTag "cn"
            addXrayIPRouting blackhole_ip_out outboundTag "cn"
            addXrayRouting allow_domain_direct_outbound outboundTag "${allowDomainList}" "top"

            addXrayOutbound blackhole_out
            addXrayOutbound blackhole_ip_out
            addXrayOutbound allow_domain_direct_outbound
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then

            addSingBoxRouteRule "cn_block_outbound" "cn" "cn_block_route"
            addSingBoxGeoIPRouteRule "block_ip_outbound" "cn" "cn_block_ip_route"
            addSingBoxRouteRule "01_direct_outbound" "${allowDomainList}" "00_allow_domain_route"

            addSingBoxOutbound "cn_block_outbound"
            addSingBoxOutbound "block_ip_outbound"
            addSingBoxOutbound "01_direct_outbound"
        fi

        echoContent green " ---> Delete Xray and it will start automatically after booting"

    elif [[ "${blacklistStatus}" == "4" ]]; then
        if [[ "${coreInstallType}" == "1" ]]; then
            unInstallRouting blackhole_out outboundTag
            unInstallRouting blackhole_ip_out outboundTag
            unInstallRouting allow_domain_direct_outbound outboundTag

            removeXrayOutbound blackhole_ip_out
            removeXrayOutbound allow_domain_direct_outbound
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then
            removeSingBoxConfig "cn_block_route"
            removeSingBoxConfig "cn_block_outbound"
            removeSingBoxConfig "cn_block_ip_route"
            removeSingBoxConfig "block_ip_route"
            removeSingBoxConfig "block_ip_outbound"

            removeSingBoxConfig "cn_01_google_play_route"
            removeSingBoxConfig "00_allow_domain_route"

            removeSingBoxConfig "block_domain_route"
            removeSingBoxConfig "block_domain_outbound"
        fi
        echoContent green " ---> Delete V2Ray and it will start automatically after booting"
    elif [[ "${blacklistStatus}" == "5" ]]; then
        echoContent red "=============================================================="
    echoContent yellow "3.Monitor error log"
        read -r -p "Please enter the blocked IP list:" ipList
        if [[ -z "${ipList}" ]]; then
            echoContent red " ---> 302 Add failed"
            exit 0
        fi

        if [[ "${coreInstallType}" == "1" ]]; then
            addXrayIPRouting blackhole_ip_out outboundTag "${ipList}"
            addXrayOutbound blackhole_ip_out
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then
            addSingBoxIPRouteRule "block_ip_outbound" "${ipList}" "block_ip_route"
            addSingBoxOutbound "block_ip_outbound"
        fi
        echoContent green " ---> Delete Hysteria and it will start automatically after booting"
    elif [[ "${blacklistStatus}" == "6" ]]; then
        echoContent red "=============================================================="
    echoContent yellow "4.View certificate scheduled task log"
        read -r -p "Please enter whitelist domains:" allowDomainList
        if [[ -z "${allowDomainList}" ]]; then
        echoContent red "\n ---> Due to environmental dependencies, please install Xray-core's VLESS_TCP_TLS_Vision first"
            exit 0
        fi

        if [[ "${coreInstallType}" == "1" ]]; then
            addXrayRouting allow_domain_direct_outbound outboundTag "${allowDomainList}" "top"
            addXrayOutbound allow_domain_direct_outbound
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then
            addSingBoxRouteRule "01_direct_outbound" "${allowDomainList}" "00_allow_domain_route"
            addSingBoxOutbound "01_direct_outbound"
        fi
        echoContent green " ---> Delete Tuic and start automatically after booting"
    else
    echoContent red "================================================== =========== ===="
        exit 0
    fi
    reloadCore
}
# Download dlc.dat_plain.yml into core directory
downloadDLCPlainYAML() {
    local corePath=$1
    local dlcFilePath="${corePath}/dlc.dat_plain.yml"
    local tmpFilePath="${dlcFilePath}.tmp"

    if [[ -z "${corePath}" ]]; then
        return 1
    fi

    mkdir -p "${corePath}" >/dev/null 2>&1
    if [[ -s "${dlcFilePath}" ]]; then
        return 0
    fi
    local dlcDownloadURL="https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat_plain.yml"
    if [[ "${release}" == "alpine" ]]; then
        wget -c -O "${tmpFilePath}" "${dlcDownloadURL}" >/dev/null 2>&1
    else
        wget -c "${wgetShowProgressStatus}" -O "${tmpFilePath}" "${dlcDownloadURL}" >/dev/null 2>&1
    fi

    # shellcheck disable=SC2181
    if [[ "$?" -ne 0 || ! -s "${tmpFilePath}" ]]; then
        rm -f "${tmpFilePath}" >/dev/null 2>&1
        return 1
    fi

    mv "${tmpFilePath}" "${dlcFilePath}" >/dev/null 2>&1
}

# Escape grep/regex pattern meta characters
escapeDLCRegexPattern() {
    # shellcheck disable=SC2016
    # shellcheck disable=SC2001
    echo "$1" | sed -e 's/[.[\*^$()+?{|]/\\&/g'
}

# Resolve nearest upper name by matched rule line
getDLCNameByRuleLine() {
    local ruleLine=$1
    local dlcFilePath=$2
    awk -v targetLine="${ruleLine}" '
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
        line = $0
        sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", line)
        currentName = line
    }
    NR == targetLine {
        print currentName
        exit
    }' "${dlcFilePath}"
}

isDomainFormat() {
    local target=$1
    [[ "${target}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z0-9-]{2,63}$ ]]
}

# Resolve geosite name from dlc.dat_plain.yml by input domain
getDLCGeositeName() {
    local inputRule=$1
    local corePath=$2
    local dlcFilePath="${corePath}/dlc.dat_plain.yml"

    if [[ -z "${inputRule}" || -z "${corePath}" ]]; then
        echo ""
        return
    fi

    local normalizedInput
    normalizedInput=$(echo "${inputRule}" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    normalizedInput=${normalizedInput#domain:}
    normalizedInput=${normalizedInput#full:}
    normalizedInput=${normalizedInput#keyword:}

    if [[ -z "${normalizedInput}" ]]; then
        echo ""
        return
    fi

    if isDomainFormat "${normalizedInput}"; then
        return
    fi

    if ! downloadDLCPlainYAML "${corePath}"; then
        echo ""
        return
    fi

    local escapedInput=
    escapedInput=$(escapeDLCRegexPattern "${normalizedInput}")

    local matchedLine=
    matchedLine=$(grep -n -m1 -E "^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"?${escapedInput}\"?[[:space:]]*$" "${dlcFilePath}")
    if [[ -n "${matchedLine}" ]]; then
        echo "${normalizedInput}"
    fi
}

# Build final rule value: prefer geosite, fallback to domain
getDLCMatchedRuleValue() {
    local inputRule=$1
    local corePath=$2
    local normalizedInput=
    normalizedInput=$(echo "${inputRule}" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if isDomainFormat "${normalizedInput}"; then
        local escapedDomain=
        escapedDomain=$(escapeDLCRegexPattern "${normalizedInput}")
        echo "regexp:.*${escapedDomain}.*"
        return
    fi

    local matchedRuleName=
    matchedRuleName=$(getDLCGeositeName "${normalizedInput}" "${corePath}")
    if [[ -n "${matchedRuleName}" ]]; then
        echo "geosite:${matchedRuleName}"
    else
        echo "domain:${normalizedInput}"
    fi
}

addXrayRouting() {

    local tag=$1    # warp-socks
    local type=$2   # outboundTag/inboundTag
    local domain=$3 # domain
    local rulePosition=$4

    if [[ -z "${tag}" || -z "${type}" || -z "${domain}" ]]; then
    echoContent red "================================================== ==============="
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
    routingRule=$(jq -r ".routing.rules[]|select(.outboundTag==\"${tag}\" and (.protocol == null))" ${configPath}09_routing.json)

    if [[ -z "${routingRule}" ]]; then
        routingRule="{\"type\": \"field\",\"domain\": [],\"outboundTag\": \"${tag}\"}"
    fi

    while read -r line; do
        if echo "${routingRule}" | grep -q "${line}"; then
    echoContent yellow "5.View certificate installation log"
        else
            local matchedRuleValue
            matchedRuleValue=$(getDLCMatchedRuleValue "${line}" "/etc/v2ray-agent/xray")
            routingRule=$(echo "${routingRule}" | jq -r --arg rule "${matchedRuleValue}" '.domain += [$rule]')
        fi
    done < <(echo "${domain}" | tr ',' '\n')

    unInstallRouting "${tag}" "${type}"
    if ! grep -q "gstatic.com" ${configPath}09_routing.json && [[ "${tag}" == "blackhole_out" ]]; then
        local routing=
        routing=$(jq -r ".routing.rules += [{\"type\": \"field\",\"domain\": [\"domain:gstatic.com\"],\"outboundTag\": \"allow_domain_direct_outbound\"}]" ${configPath}09_routing.json)
        echo "${routing}" | jq . >${configPath}09_routing.json
        addXrayOutbound allow_domain_direct_outbound
    fi

    if [[ "${rulePosition}" == "top" ]]; then
        routing=$(jq -r ".routing.rules = [${routingRule}] + .routing.rules" ${configPath}09_routing.json)
    else
        routing=$(jq -r ".routing.rules += [${routingRule}]" ${configPath}09_routing.json)
    fi
    echo "${routing}" | jq . >${configPath}09_routing.json
}

addXrayIPRouting() {

    local tag=$1
    local type=$2
    local ipList=$3

    if [[ -z "${tag}" || -z "${type}" || -z "${ipList}" ]]; then
        echoContent red "\n================================================ ================="
        exit 0
    fi

    if [[ ! -f "${configPath}09_routing.json" ]]; then
        cat <<EOF >${configPath}09_routing.json
{
    "routing":{
        "type": "field",
        "rules": []
    }
}
EOF
    fi

    local routingRule=
    routingRule=$(jq -r ".routing.rules[]|select(.outboundTag==\"${tag}\" and (.protocol == null) and (.ip != null))" ${configPath}09_routing.json)
    if [[ -z "${routingRule}" ]]; then
        routingRule="{\"type\": \"field\",\"ip\": [],\"outboundTag\": \"${tag}\"}"
    fi

    while read -r line; do
        line=$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "${line}" ]]; then
            continue
        fi

        local ipRuleValue=${line}
        if [[ "${line}" == "cn" ]]; then
            ipRuleValue="geoip:cn"
        fi

        if echo "${routingRule}" | grep -q "${ipRuleValue}"; then
    echoContent yellow "6.Clear the log"
        else
            routingRule=$(echo "${routingRule}" | jq -r '.ip += ["'"${ipRuleValue}"'"]')
        fi
    done < <(echo "${ipList}" | tr ',' '\n')

    unInstallRouting "${tag}" "${type}"
    local routing=
    routing=$(jq -r ".routing.rules += [${routingRule}]" ${configPath}09_routing.json)
    echo "${routing}" | jq . >${configPath}09_routing.json
}

addSingBoxIPRouteRule() {
    local outboundTag=$1
    local ipList=$2
    local routingName=$3

    local historyIPs=
    if [[ -f "${singBoxConfigPath}${routingName}.json" ]]; then
        historyIPs=$(jq -r '.route.rules[0].ip_cidr[]?' "${singBoxConfigPath}${routingName}.json" | paste -sd ',')
    fi

    if [[ -n "${historyIPs}" ]]; then
        ipList="${ipList},${historyIPs}"
    fi

    local ipCIDR=[]
    ipCIDR=$(echo "${ipList}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -n | uniq | jq -R . | jq -s .)

    cat <<EOF >"${singBoxConfigPath}${routingName}.json"
{
  "route": {
    "rules": [
      {
        "ip_cidr": ${ipCIDR},
        "outbound": "${outboundTag}"
      }
    ]
  }
}
EOF
}

addSingBoxGeoIPRouteRule() {
    local outboundTag=$1
    local geoipCode=$2
    local routingName=$3

    cat <<EOF >"${singBoxConfigPath}${routingName}.json"
{
  "route": {
    "rules": [
      {
        "rule_set": [
          "geoip_${geoipCode}_${routingName}"
        ],
        "outbound": "${outboundTag}"
      }
    ],
    "rule_set": [
      {
        "tag": "geoip_${geoipCode}_${routingName}",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-${geoipCode}.srs",
        "http_client": "rule_set_http"
      }
    ]
  }
}
EOF
}
# Uninstall Routing based on tag
unInstallRouting() {
    local tag=$1
    local type=$2
    local protocol=$3

    if [[ -f "${configPath}09_routing.json" ]]; then
        local routing=
        if [[ -n "${protocol}" ]]; then
            routing=$(jq -r "del(.routing.rules[] | select(.${type} == \"${tag}\" and (.protocol | index(\"${protocol}\"))))" ${configPath}09_routing.json)
            echo "${routing}" | jq . >${configPath}09_routing.json
        else
            routing=$(jq -r "del(.routing.rules[] | select(.${type} == \"${tag}\" and (.protocol == null )))" ${configPath}09_routing.json)
            echo "${routing}" | jq . >${configPath}09_routing.json
        fi
    fi
}

# Uninstall sniffing
unInstallSniffing() {

    find ${configPath} -name "*inbounds.json*" | awk -F "[c][o][n][f][/]" '{print $2}' | while read -r inbound; do
        if grep -q "destOverride" <"${configPath}${inbound}"; then
            sniffing=$(jq -r 'del(.inbounds[0].sniffing)' "${configPath}${inbound}")
            echo "${sniffing}" | jq . >"${configPath}${inbound}"
        fi
    done

}

# Install sniffing
installSniffing() {
    readInstallType
    if [[ "${coreInstallType}" == "1" ]]; then
        if [[ -f "${configPath}02_VLESS_TCP_inbounds.json" ]]; then
            if ! grep -q "destOverride" <"${configPath}02_VLESS_TCP_inbounds.json"; then
                sniffing=$(jq -r '.inbounds[0].sniffing = {"enabled":true,"destOverride":["http","tls","quic"]}' "${configPath}02_VLESS_TCP_inbounds.json")
                echo "${sniffing}" | jq . >"${configPath}02_VLESS_TCP_inbounds.json"
            fi
        fi
    fi
}

# Read third-party warp configuration
readConfigWarpReg() {
    if [[ ! -f "/etc/v2ray-agent/warp/config" ]]; then
        /etc/v2ray-agent/warp/warp-reg >/etc/v2ray-agent/warp/config
    fi

    secretKeyWarpReg=$(grep <"/etc/v2ray-agent/warp/config" private_key | awk '{print $2}')

    addressWarpReg=$(grep <"/etc/v2ray-agent/warp/config" v6 | awk '{print $2}')

    publicKeyWarpReg=$(grep <"/etc/v2ray-agent/warp/config" public_key | awk '{print $2}')

    reservedWarpReg=$(grep <"/etc/v2ray-agent/warp/config" reserved | awk -F "[:]" '{print $2}')

}
installWarpReg() {
    if [[ ! -f "/etc/v2ray-agent/warp/warp-reg" ]]; then
        echo
    echoContent yellow "1.View the diverted domain name"
    echoContent yellow "2.Add domain name"
    echoContent yellow "3.Set IPv6 global"

        read -r -p "warp-reg is not installed, do you want to install it? [y/n]:" installWarpRegStatus

        if [[ "${installWarpRegStatus}" == "y" ]]; then

            curl -sLo /etc/v2ray-agent/warp/warp-reg "https://github.com/badafans/warp-reg/releases/download/v1.0/${warpRegCoreCPUVendor}"
            chmod 655 /etc/v2ray-agent/warp/warp-reg

        else
    echoContent yellow "4.Uninstall IPv6 offloading"
            exit 0
        fi
    fi
}

showWireGuardDomain() {
    local type=$1
    # xray
    if [[ "${coreInstallType}" == "1" ]]; then
        if [[ -f "${configPath}09_routing.json" ]]; then
            echoContent yellow "Xray-core"
            jq -r -c '.routing.rules[]|select (.outboundTag=="wireguard_out_'"${type}"'")|.domain' ${configPath}09_routing.json | jq -r
        elif [[ ! -f "${configPath}09_routing.json" && -f "${configPath}wireguard_out_${type}.json" ]]; then
            echoContent yellow "Xray-core"
        echoContent green " ---> Deletion of fake website completed"
        else
        echoContent yellow "# Notes\n"
        fi
    fi

    # sing-box
    if [[ -n "${singBoxConfigPath}" ]]; then
        if [[ -f "${singBoxConfigPath}wireguard_endpoints_${type}_route.json" ]]; then
            echoContent yellow "sing-box"
            jq -r -c '.route.rules[]' "${singBoxConfigPath}wireguard_endpoints_${type}_route.json" | jq -r
        elif [[ ! -f "${singBoxConfigPath}wireguard_endpoints_${type}_route.json" && -f "${singBoxConfigPath}wireguard_endpoints_${type}.json" ]]; then
            echoContent yellow "sing-box"
    echoContent green " ---> Uninstallation of shortcut completed"
        else
        echoContent yellow "# Notes"
        fi
    fi

}

addWireGuardRoute() {
    local type=$1
    local tag=$2
    local domainList=$3
    # xray
    if [[ "${coreInstallType}" == "1" ]]; then

        addXrayRouting "wireguard_out_${type}" "${tag}" "${domainList}"
        addXrayOutbound "wireguard_out_${type}"
    fi
    # sing-box
    if [[ -n "${singBoxConfigPath}" ]]; then

        # rule
        addSingBoxRouteRule "wireguard_endpoints_${type}" "${domainList}" "wireguard_endpoints_${type}_route"
        # addSingBoxOutbound "wireguard_out_${type}" "wireguard_out"
        if [[ -n "${domainList}" ]]; then
            addSingBoxOutbound "01_direct_outbound"
        fi

        # outbound
        addSingBoxWireGuardEndpoints "${type}"
    fi
}

unInstallWireGuard() {
    local type=$1
    if [[ "${coreInstallType}" == "1" ]]; then

        if [[ "${type}" == "IPv4" ]]; then
            if [[ ! -f "${configPath}wireguard_out_IPv6.json" ]]; then
                rm -rf /etc/v2ray-agent/warp/config >/dev/null 2>&1
            fi
        elif [[ "${type}" == "IPv6" ]]; then
            if [[ ! -f "${configPath}wireguard_out_IPv4.json" ]]; then
                rm -rf /etc/v2ray-agent/warp/config >/dev/null 2>&1
            fi
        fi
    fi

    if [[ -n "${singBoxConfigPath}" ]]; then
        if [[ ! -f "${singBoxConfigPath}wireguard_endpoints_IPv6_route.json" && ! -f "${singBoxConfigPath}wireguard_endpoints_IPv4_route.json" ]]; then
            rm "${singBoxConfigPath}wireguard_outbound.json" >/dev/null 2>&1
            rm -rf /etc/v2ray-agent/warp/config >/dev/null 2>&1
        fi
    fi
}
removeWireGuardRoute() {
    local type=$1
    if [[ "${coreInstallType}" == "1" ]]; then

        unInstallRouting wireguard_out_"${type}" outboundTag

        removeXrayOutbound "wireguard_out_${type}"
        if [[ ! -f "${configPath}IPv4_out.json" ]]; then
            addXrayOutbound IPv4_out
        fi
    fi

    # sing-box
    if [[ -n "${singBoxConfigPath}" ]]; then
        removeSingBoxRouteRule "wireguard_endpoints_${type}"
    fi

    unInstallWireGuard "${type}"
}
# warp offload-third-party IPv4
warpRoutingReg() {
    local type=$2
    echoContent skyBlue "\nProgress$1/${totalProgress}: Multi-user management"
    echoContent red "=============================================================="

        echoContent yellow "# Tutorial: https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"
        echoContent yellow "# Notes\n"
        echoContent yellow "1.All diversion rules set will be deleted"
        echoContent yellow "2.All outbound rules except IPv6 will be deleted"
    echoContent red "=============================================================="
    read -r -p "Please select:" warpStatus
    installWarpReg
    readConfigWarpReg
    local address=
    if [[ ${type} == "IPv4" ]]; then
        address="172.16.0.2/32"
    elif [[ ${type} == "IPv6" ]]; then
        address="${addressWarpReg}/128"
    else
        echoContent red "================================================== ==============="
    fi

    if [[ "${warpStatus}" == "1" ]]; then
        showWireGuardDomain "${type}"
        exit 0
    elif [[ "${warpStatus}" == "2" ]]; then
        echoContent yellow "Current status: disabled"
        echoContent yellow "Current status: not disabled"
    echoContent yellow "1.Disable"

        read -r -p "Please enter the domain name according to the above example:" domainList
        addWireGuardRoute "${type}" outboundTag "${domainList}"
    echoContent green " ---> Uninstall v2ray-agent script completed"

    elif [[ "${warpStatus}" == "3" ]]; then

        echoContent red "=============================================================="
    echoContent yellow "2.Open"
    echoContent yellow "1.View blocked domain names"
    echoContent yellow "2.Add domain name"
        read -r -p "Confirm settings? [y/n]:" warpOutStatus

        if [[ "${warpOutStatus}" == "y" ]]; then
            readConfigWarpReg
            if [[ "${coreInstallType}" == "1" ]]; then
                addXrayOutbound "wireguard_out_${type}"
                if [[ "${type}" == "IPv4" ]]; then
                    removeXrayOutbound "wireguard_out_IPv6"
                elif [[ "${type}" == "IPv6" ]]; then
                    removeXrayOutbound "wireguard_out_IPv4"
                fi

                removeXrayOutbound IPv4_out
                removeXrayOutbound IPv6_out
                removeXrayOutbound z_direct_outbound
                removeXrayOutbound blackhole_out
                removeXrayOutbound socks5_outbound

                rm ${configPath}09_routing.json >/dev/null 2>&1
            fi

            if [[ -n "${singBoxConfigPath}" ]]; then

                removeSingBoxConfig IPv4_out
                removeSingBoxConfig IPv6_out
                removeSingBoxConfig 01_direct_outbound

                removeSingBoxConfig wireguard_endpoints_IPv4_route
                removeSingBoxConfig wireguard_endpoints_IPv6_route

                removeSingBoxConfig IPv6_route
                removeSingBoxConfig socks5_02_inbound_route

                addSingBoxWireGuardEndpoints "${type}"
                addWireGuardRoute "${type}" outboundTag ""
                if [[ "${type}" == "IPv4" ]]; then
                    removeSingBoxConfig wireguard_endpoints_IPv6
                else
                    removeSingBoxConfig wireguard_endpoints_IPv4
                fi

                # outbound
                # addSingBoxOutbound "wireguard_out_${type}" "wireguard_out"

            fi

            echoContent green " ---> CDN modified successfully"
        else
    echoContent green " ---> Adding completed"
            exit 0
        fi

    elif [[ "${warpStatus}" == "4" ]]; then
        if [[ "${coreInstallType}" == "1" ]]; then
            unInstallRouting "wireguard_out_${type}" outboundTag

            removeXrayOutbound "wireguard_out_${type}"
            addXrayOutbound "z_direct_outbound"
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then
            removeSingBoxConfig "wireguard_endpoints_${type}_route"

            removeSingBoxConfig "wireguard_endpoints_${type}"
            addSingBoxOutbound "01_direct_outbound"
        fi

    echoContent green " ---> Adding completed"
    else

        echoContent red " ---> Wrong selection, please select again"
        exit 0
    fi
    reloadCore
}

# Diversion tool
routingToolsMenu() {
    echoContent skyBlue "------------------------------------------------- ------"
    echoContent red "\n=============================================================="
    echoContent yellow "3.Block domestic domain names + IP"
    echoContent yellow "4.Delete blacklist/whitelist"

    echoContent yellow "5.Add blocked IP"
    echoContent yellow "6.Add domain whitelist"
        echoContent yellow "# Notes\n"
        echoContent yellow "1.Rules support predefined domain name list [https://github.com/v2fly/domain-list-community]"
        echoContent yellow "2.Rules support custom domain names"
        echoContent yellow "3.Input example: speedtest, facebook, cn, example.com"

    read -r -p "Please select:" selectType

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
        socks5Routing
        ;;
    5)
        dnsRouting 1
        ;;
        #    6)
        #        if [[ -n "${singBoxConfigPath}" ]]; then
        #        fi
        #        vmessWSRouting 1
        #        ;;
    7)
        if [[ -n "${singBoxConfigPath}" ]]; then
    echoContent red "\n================================================ ================="
        fi
        sniRouting 1
        ;;
    esac

}

# VMess+WS+TLS offload
vmessWSRouting() {
    echoContent skyBlue "------------------------------------------------- ------"
    echoContent red "\n=============================================================="
        echoContent yellow "4.If the domain name exists in the predefined domain name list, use geosite:xx. If it does not exist, the entered domain name will be used by default."
        echoContent yellow "5.Add rules as incremental configuration and will not delete previously set content\n"

        echoContent yellow "Input example:1.1.1.1,8.8.8.8,1.1.1.0/24,2400:3200::/32\n"
        echoContent yellow "Input example:speedtest,openai,google.com\n"
    read -r -p "Please select:" selectType

    case ${selectType} in
    1)
        setVMessWSRoutingOutbounds
        ;;
    2)
        removeVMessWSRouting
        ;;
    esac
}
socks5Routing() {
    if [[ -z "${coreInstallType}" ]]; then
    echoContent red "================================================== ==============="
        exit 0
    fi
    echoContent skyBlue "\nProgress$1/${totalProgress}: Update v2ray-agent script"
    echoContent red "\n=============================================================="
        echoContent red "================================================== ==============="
            echoContent yellow " ---> ${line} already exists, skip"

            echoContent yellow " ---> ${ipRuleValue} already exists, skip"
            echoContent yellow " ---> Abort installation"

    echoContent yellow "1.View the diverted domain name"
    echoContent yellow "2.Add domain name"
    echoContent yellow "3.Set WARP global"
    read -r -p "Please select:" selectType

    case ${selectType} in
    1)
        socks5OutboundRoutingMenu
        ;;
    2)
        socks5InboundRoutingMenu
        ;;
    3)
        removeSocks5Routing
        ;;
    esac
}
socks5InboundRoutingMenu() {
    readInstallType
    echoContent skyBlue "wget -P /root -N --no-check-certificate https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh && chmod 700 /root/install.sh && /root/install.sh"
    echoContent red "\n=============================================================="

    echoContent yellow "4.Uninstall WARP distribution"
        echoContent yellow "# Notes"
        echoContent yellow "# Tutorial: https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"
        echoContent yellow "# Notes\n"
    read -r -p "Please select:" selectType
    case ${selectType} in
    1)
        totalProgress=1
        installSingBox 1
        installSingBoxService 1
        setSocks5Inbound
        setSocks5InboundRouting
        reloadCore
        socks5InboundRoutingMenu
        ;;
    2)
        showSingBoxRoutingRules socks5_02_inbound_route
        socks5InboundRoutingMenu
        ;;
    3)
        setSocks5InboundRouting addRules
        reloadCore
        socks5InboundRoutingMenu
        ;;
    4)
        if [[ -f "${singBoxConfigPath}20_socks5_inbounds.json" ]]; then
        echoContent yellow "1.All diversion rules set will be deleted"
    echoContent green "\n ---> Update completed"
    echoContent green " ---> Current version: ${version}\n"
        echoContent green " ---> ufw closed successfully"
        else
        echoContent red "================================================== ==============="
            socks5InboundRoutingMenu
        fi
        ;;
    esac

}

socks5OutboundRoutingMenu() {
    echoContent skyBlue "\nFunction$1/${totalProgress}: View log"
    echoContent red "\n=============================================================="

        echoContent yellow "2.All outbound rules except WARP will be deleted"
        echoContent yellow "# Notes"
        echoContent yellow "# relies on third-party programs, please be aware of the risks"
        echoContent yellow "# Project address: https://github.com/badafans/warp-reg \n"
    read -r -p "Please select:" selectType
    case ${selectType} in
    1)
        setSocks5Outbound
        setSocks5OutboundRouting
        reloadCore
        socks5OutboundRoutingMenu
        ;;
    2)
        setSocks5Outbound
        setSocks5OutboundRoutingAll
        reloadCore
        socks5OutboundRoutingMenu
        ;;
    3)
        showSingBoxRoutingRules socks5_01_outbound_route
        showXrayRoutingRules socks5_outbound
        socks5OutboundRoutingMenu
        ;;
    4)
        setSocks5OutboundRouting addRules
        reloadCore
        socks5OutboundRoutingMenu
        ;;
    esac

}

setSocks5OutboundRoutingAll() {

    echoContent red "=============================================================="
            echoContent yellow " ---> Abort installation"
    echoContent yellow "1.View the diverted domain name"
    echoContent yellow "2.Add domain name"
    read -r -p "Confirm this setting? [y/n]:" socksOutStatus

    if [[ "${socksOutStatus}" == "y" ]]; then
        if [[ "${coreInstallType}" == "1" ]]; then
            removeXrayOutbound IPv4_out
            removeXrayOutbound IPv6_out
            removeXrayOutbound z_direct_outbound
            removeXrayOutbound blackhole_out
            removeXrayOutbound wireguard_out_IPv4
            removeXrayOutbound wireguard_out_IPv6

            rm ${configPath}09_routing.json >/dev/null 2>&1
        fi
        if [[ -n "${singBoxConfigPath}" ]]; then

            removeSingBoxConfig IPv4_out
            removeSingBoxConfig IPv6_out

            removeSingBoxConfig wireguard_endpoints_IPv4_route
            removeSingBoxConfig wireguard_endpoints_IPv6_route
            removeSingBoxConfig wireguard_endpoints_IPv4
            removeSingBoxConfig wireguard_endpoints_IPv6

            removeSingBoxConfig socks5_01_outbound_route
            removeSingBoxConfig 01_direct_outbound
        fi

        echoContent green " ---> firewalld closed successfully"
    fi
}
showSingBoxRoutingRules() {
    if [[ -n "${singBoxConfigPath}" ]]; then
        if [[ -f "${singBoxConfigPath}$1.json" ]]; then
            jq .route.rules "${singBoxConfigPath}$1.json"
        elif [[ "$1" == "socks5_01_outbound_route" && -f "${singBoxConfigPath}socks5_outbound.json" ]]; then
    echoContent yellow "3.Set WARP global"
    echoContent yellow "4.Uninstall WARP distribution"
            echoContent skyBlue "$(jq .outbounds[0] ${singBoxConfigPath}socks5_outbound.json)"
        elif [[ "$1" == "socks5_02_inbound_route" && -f "${singBoxConfigPath}20_socks5_inbounds.json" ]]; then
        echoContent yellow "# Notes"
        echoContent yellow "# Tutorial: https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"
            echoContent skyBlue "$(jq .outbounds[0] ${singBoxConfigPath}socks5_outbound.json)"
        fi
    fi
}

showXrayRoutingRules() {
    if [[ "${coreInstallType}" == "1" ]]; then
        if [[ -f "${configPath}09_routing.json" ]]; then
            jq ".routing.rules[]|select(.outboundTag==\"$1\")" "${configPath}09_routing.json"

        echoContent yellow "# Notes\n"
        echoContent yellow "1.All diversion rules set will be deleted"
            echoContent skyBlue "$(jq .outbounds[0].settings.servers[0] ${configPath}socks5_outbound.json)"

        elif [[ "$1" == "socks5_outbound" && -f "${configPath}socks5_outbound.json" ]]; then
        echoContent yellow "2.All outbound rules except WARP [third party] will be deleted"
    echoContent yellow "1.WARP diversion [Third-party IPv4]"
            echoContent skyBlue "$(jq .outbounds[0].settings.servers[0] ${configPath}socks5_outbound.json)"
        fi
    fi
}

removeSocks5Routing() {
    echoContent skyBlue "\nFunction 1/${totalProgress}: IPv6 offload"
    echoContent red "\n=============================================================="

    echoContent yellow "2.WARP diversion [Third-party IPv6]"
    echoContent yellow "3.IPv6 offload"
    echoContent yellow "4.Any door diversion"
    read -r -p "Select:" unInstallSocks5RoutingStatus
    if [[ "${unInstallSocks5RoutingStatus}" == "1" ]]; then
        if [[ "${coreInstallType}" == "1" ]]; then
            removeXrayOutbound socks5_outbound
            unInstallRouting socks5_outbound outboundTag

            addXrayOutbound z_direct_outbound
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then
            removeSingBoxConfig socks5_outbound
            removeSingBoxConfig socks5_01_outbound_route
            addSingBoxOutbound 01_direct_outbound
        fi

    elif [[ "${unInstallSocks5RoutingStatus}" == "2" ]]; then

        removeSingBoxConfig 20_socks5_inbounds
        removeSingBoxConfig socks5_02_inbound_route
        removeSingBoxConfig sniff_socks5_inbound
        removeSingBoxConfig "strategy_ipv4_only_socks5_inbound"
        removeSingBoxConfig "strategy_ipv6_only_socks5_inbound"

        handleSingBox stop
    elif [[ "${unInstallSocks5RoutingStatus}" == "3" ]]; then
        if [[ "${coreInstallType}" == "1" ]]; then
            removeXrayOutbound socks5_outbound
            unInstallRouting socks5_outbound outboundTag
            addXrayOutbound z_direct_outbound
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then
            removeSingBoxConfig socks5_outbound
            removeSingBoxConfig socks5_01_outbound_route
            removeSingBoxConfig 20_socks5_inbounds
            removeSingBoxConfig socks5_02_inbound_route
            removeSingBoxConfig sniff_socks5_inbound
            removeSingBoxConfig "strategy_ipv4_only_socks5_inbound"
            removeSingBoxConfig "strategy_ipv6_only_socks5_inbound"

            addSingBoxOutbound 01_direct_outbound
        fi

        handleSingBox stop
    else
        echoContent red " ---> Available types are not installed"
        exit 0
    fi
    echoContent green "The mature works of [ylx2016] used for BBR and DD scripts, the address [https://github.com/ylx2016/Linux-NetSpeed], please be familiar with it"
    reloadCore
}
setSocks5Inbound() {

    echoContent yellow "5.DNS divert"
    echoContent skyBlue "\nFunction 1/${totalProgress}: bt download management"
    echo
    mapfile -t result < <(initSingBoxPort "${singBoxSocks5Port}")
            echoContent green "The shortcut is created successfully, you can execute [vasma] to reopen the script"
        echoContent green " ---> Added successfully"

    echoContent yellow "6.VMess+WS+TLS offload"
    read -r -p 'UUID:' socks5RoutingUUID
    if [[ -z "${socks5RoutingUUID}" ]]; then
        if [[ "${coreInstallType}" == "1" ]]; then
            socks5RoutingUUID=$(/etc/v2ray-agent/xray/xray uuid)
        elif [[ -n "${singBoxConfigPath}" ]]; then
            socks5RoutingUUID=$(/etc/v2ray-agent/sing-box/sing-box generate uuid)
        fi
    fi
    echo
            echoContent green " ---> IPv6 global outbound setting successful"
            echoContent green " ---> Abandon settings"

    echoContent yellow "7.SNI reverse proxy offload"
    echoContent yellow "1.Any door floor machine unlocks streaming media"
    echoContent yellow "2.DNS unlock streaming media"
    echoContent yellow "2.IPv6"

    read -r -p 'IP type:' socks5InboundDomainStrategyStatus
    local domainStrategy=
    if [[ -z "${socks5InboundDomainStrategyStatus}" || "${socks5InboundDomainStrategyStatus}" == "1" ]]; then
        domainStrategy="ipv4_only"
    elif [[ "${socks5InboundDomainStrategyStatus}" == "2" ]]; then
        domainStrategy="ipv6_only"
    else
        echoContent red " ---> Wrong selection"
        exit 0
    fi
    cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/20_socks5_inbounds.json
{
    "inbounds":[
        {
          "type": "socks",
          "listen":"::",
          "listen_port":${result[-1]},
          "tag":"socks5_inbound",
          "users":[
            {
                  "username": "${socks5RoutingUUID}",
                  "password": "${socks5RoutingUUID}"
            }
          ]
        }
    ]
}
EOF
    setStrategyRouting socks5_inbound "${domainStrategy}"
}

initSingBoxRules() {
    local domainRules=[]
    local ruleSet=[]
    while read -r line; do
        local normalizedLine=
        normalizedLine=$(echo "${line}" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if isDomainFormat "${normalizedLine}"; then
            local escapedDomain=
            escapedDomain=${normalizedLine//./\\.}
            domainRules=$(echo "${domainRules}" | jq -r --arg reg ".*${escapedDomain}.*" '. += [$reg]')
        else
            local matchedRuleName
            matchedRuleName=$(getDLCGeositeName "${normalizedLine}" "/etc/v2ray-agent/sing-box")

            if [[ -n "${matchedRuleName}" ]]; then
                ruleSet=$(echo "${ruleSet}" | jq -r ". += [{\"tag\":\"${matchedRuleName}_$2\",\"type\":\"remote\",\"format\":\"binary\",\"url\":\"https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-${matchedRuleName}.srs\",\"http_client\":\"rule_set_http\"}]")
            else
                domainRules=$(echo "${domainRules}" | jq -r --arg reg "^([a-zA-Z0-9_-]+\\.)*${normalizedLine//./\\.}" '. += [$reg]')
            fi
        fi
    done < <(echo "$1" | tr ',' '\n' | grep -v '^$' | sort -n | uniq | paste -sd ',' | tr ',' '\n')
    echo "{ \"domainRules\":${domainRules},\"ruleSet\":${ruleSet}}"
}

setSocks5InboundRouting() {

    singBoxConfigPath=/etc/v2ray-agent/sing-box/conf/config/

    if [[ "$1" == "addRules" && ! -f "${singBoxConfigPath}socks5_02_inbound_route.json" && ! -f "${configPath}09_routing.json" ]]; then
            echoContent red " ---> UUID cannot be repeated"
            echoContent red " ---> email cannot be repeated"
        exit 0
    fi
    local socks5InboundRoutingIPs=
    if [[ "$1" == "addRules" ]]; then
        socks5InboundRoutingIPs=$(jq .route.rules[0].source_ip_cidr "${singBoxConfigPath}socks5_02_inbound_route.json")
    else
        echoContent red "=============================================================="
    echoContent skyBlue "\nProgress$1/${totalProgress}: Domain name blacklist"
        read -r -p "IP:" socks5InboundRoutingIPs

        if [[ -z "${socks5InboundRoutingIPs}" ]]; then
        echoContent red " ---> Incorrect input, please re-enter"
            exit 0
        fi
        socks5InboundRoutingIPs=$(echo "\"${socks5InboundRoutingIPs}"\" | jq -c '.|split(",")')
    fi

    echoContent red "=============================================================="
    echoContent skyBlue "\nProgress$1/${totalProgress}: WARP offload"
    echoContent yellow "3.VMess+WS+TLS to unlock streaming media"
    echoContent yellow "# Notes"
    echoContent yellow "# Tutorial: https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"
    echoContent yellow "1.Add outbound"

    read -r -p "Allow all websites? Select [y/n]:" socks5InboundRoutingDomainStatus
    if [[ "${socks5InboundRoutingDomainStatus}" == "y" ]]; then
        addSingBoxRouteRule "01_direct_outbound" "" "socks5_02_inbound_route"
        local route=
        route=$(jq ".route.rules[0].inbound = [\"socks5_inbound\"]" "${singBoxConfigPath}socks5_02_inbound_route.json")
        route=$(echo "${route}" | jq ".route.rules[0].source_ip_cidr=${socks5InboundRoutingIPs}")
        echo "${route}" | jq . >"${singBoxConfigPath}socks5_02_inbound_route.json"

        addSingBoxOutbound block
        addSingBoxOutbound "01_direct_outbound"
    else
    echoContent yellow "2.Add inbound"
        read -r -p "Domain:" socks5InboundRoutingDomain
        if [[ -z "${socks5InboundRoutingDomain}" ]]; then
        echoContent red " ---> Incorrect input, please re-enter"
            exit 0
        fi
        addSingBoxRouteRule "01_direct_outbound" "${socks5InboundRoutingDomain}" "socks5_02_inbound_route"
        local route=
        route=$(jq ".route.rules[0].inbound = [\"socks5_inbound\"]" "${singBoxConfigPath}socks5_02_inbound_route.json")
        route=$(echo "${route}" | jq ".route.rules[0].source_ip_cidr=${socks5InboundRoutingIPs}")
        echo "${route}" | jq . >"${singBoxConfigPath}socks5_02_inbound_route.json"

        addSingBoxOutbound block
        addSingBoxOutbound "01_direct_outbound"
    fi

}

setSniffRouting() {
    local singBoxDNSConfigPath="/etc/v2ray-agent/sing-box/conf/config/dns.json"
    if [[ -f "${singBoxDNSConfigPath}" ]]; then
        jq '
          .dns.servers = (.dns.servers // [])
          | if any(.dns.servers[]?; .tag == "local") then .
            elif any(.dns.servers[]?; .type == "local" and ((.tag // "") == "")) then
              .dns.servers |= map(if .type == "local" and ((.tag // "") == "") then .tag = "local" else . end)
            else
              .dns.servers += [{"tag": "local", "type": "local"}]
            end
        ' "${singBoxDNSConfigPath}" >"${singBoxDNSConfigPath}.tmp" && mv "${singBoxDNSConfigPath}.tmp" "${singBoxDNSConfigPath}"
    else
        cat <<EOF >"${singBoxDNSConfigPath}"
{
    "dns": {
        "servers": [
            {
                "tag": "local",
                "type": "local"
            }
        ]
    }
}
EOF
    fi

    cat <<EOF >"/etc/v2ray-agent/sing-box/conf/config/sniff.json"
{
    "route":{
        "default_domain_resolver": "local",
        "rules":[
          {
            "action": "sniff",
            "timeout": "1s"
          },
          {
            "protocol": "dns",
            "action": "hijack-dns"
          }
        ]
    }
}
EOF
}

setStrategyRouting() {
    local tag=$1
    local strategy=$2
    cat <<EOF >"/etc/v2ray-agent/sing-box/conf/config/strategy_${strategy}_${tag}.json"
{
    "route":{
        "rules":[
          {
            "inbound": "${tag}",
            "action": "resolve",
            "strategy": "${strategy}"
          }
        ]
    }
}
EOF
}
setSocks5Outbound() {

    echoContent yellow "3.Uninstall"
    echo
    read -r -p "Enter the landing server IP address:" socks5RoutingOutboundIP
    if [[ -z "${socks5RoutingOutboundIP}" ]]; then
            echoContent red " ---> Wrong selection"
        exit 0
    fi
    echo
    read -r -p "Enter the landing server port:" socks5RoutingOutboundPort
    if [[ -z "${socks5RoutingOutboundPort}" ]]; then
            echoContent red " ---> Wrong selection"
        exit 0
    fi
    echo
    read -r -p "Enter username:" socks5RoutingOutboundUserName
    if [[ -z "${socks5RoutingOutboundUserName}" ]]; then
    echoContent red "\n================================================ ================="
        exit 0
    fi
    echo
    read -r -p "Enter password:" socks5RoutingOutboundPassword
    if [[ -z "${socks5RoutingOutboundPassword}" ]]; then
    echoContent red "================================================== ==============="
        exit 0
    fi
    echo
    if [[ -n "${singBoxConfigPath}" ]]; then
        cat <<EOF >"${singBoxConfigPath}socks5_outbound.json"
{
    "outbounds":[
        {
          "type": "socks",
          "tag":"socks5_outbound",
          "server": "${socks5RoutingOutboundIP}",
          "server_port": ${socks5RoutingOutboundPort},
          "version": "5",
          "username":"${socks5RoutingOutboundUserName}",
          "password":"${socks5RoutingOutboundPassword}"
        }
    ]
}
EOF
    fi
    if [[ "${coreInstallType}" == "1" ]]; then
        addXrayOutbound socks5_outbound
    fi
}

setSocks5OutboundRouting() {

    if [[ "$1" == "addRules" && ! -f "${singBoxConfigPath}socks5_01_outbound_route.json" && ! -f "${configPath}09_routing.json" ]]; then
        echoContent red " ---> The installation directory is not detected, please execute the script to install the content"
        exit 0
    fi

    echoContent red "=============================================================="
    echoContent skyBlue "\nProgress$1/${totalProgress}: WARP offload [third party]"
    echoContent yellow "# Notes"
    echoContent yellow "# Tutorial: https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"
    echoContent yellow "1.Add outbound"
    echoContent yellow "2.Uninstall"
    echoContent yellow "Input example:netflix,openai\n"
    read -r -p "Domain:" socks5RoutingOutboundDomain
    if [[ -z "${socks5RoutingOutboundDomain}" ]]; then
    echoContent red "\n================================================ ================="
        exit 0
    fi
    addSingBoxRouteRule "socks5_outbound" "${socks5RoutingOutboundDomain}" "socks5_01_outbound_route"
    addSingBoxOutbound "01_direct_outbound"

    if [[ "${coreInstallType}" == "1" ]]; then

        unInstallRouting "socks5_outbound" "outboundTag"
        local domainRules=[]
        while read -r line; do
            if echo "${routingRule}" | grep -q "${line}"; then
    echoContent yellow "Input example:netflix,openai\n"
            else
                local matchedRuleValue
                matchedRuleValue=$(getDLCMatchedRuleValue "${line}" "/etc/v2ray-agent/xray")
                domainRules=$(echo "${domainRules}" | jq -r --arg rule "${matchedRuleValue}" '. += [$rule]')
            fi
        done < <(echo "${socks5RoutingOutboundDomain}" | tr ',' '\n')
        if [[ ! -f "${configPath}09_routing.json" ]]; then
            cat <<EOF >${configPath}09_routing.json
{
    "routing":{
        "rules": []
  }
}
EOF
        fi
        routing=$(jq -r ".routing.rules += [{\"type\": \"field\",\"domain\": ${domainRules},\"outboundTag\": \"socks5_outbound\"}]" ${configPath}09_routing.json)
        echo "${routing}" | jq . >${configPath}09_routing.json
    fi
}

# Set VMess+WS+TLS [outbound only]
setVMessWSRoutingOutbounds() {
    read -r -p "Please enter the address of VMess+WS+TLS:" setVMessWSTLSAddress
    echoContent red "=============================================================="
    echoContent yellow "ip entry example:1.1.1.1,1.1.1.2"
        read -r -p "Please enter the domain name according to the above example:" domainList

    if [[ -z ${domainList} ]]; then
    echoContent red "================================================== ==============="
        setVMessWSRoutingOutbounds
    fi

    if [[ -n "${setVMessWSTLSAddress}" ]]; then
        removeXrayOutbound VMess-out

        echo
        read -r -p "Please enter the port of VMess+WS+TLS:" setVMessWSTLSPort
        echo
        if [[ -z "${setVMessWSTLSPort}" ]]; then
        echoContent red " ---> does not support ipv6"
        fi

        read -r -p "Please enter the UUID of VMess+WS+TLS:" setVMessWSTLSUUID
        echo
        if [[ -z "${setVMessWSTLSUUID}" ]]; then
        echoContent red " ---> Not installed, please use script to install"
        fi

        read -r -p "Please enter the Path of VMess+WS+TLS:" setVMessWSTLSPath
        echo
        if [[ -z "${setVMessWSTLSPath}" ]]; then
    echoContent red "\n================================================ ============ ====="
        elif ! echo "${setVMessWSTLSPath}" | grep -q "/"; then
            setVMessWSTLSPath="/${setVMessWSTLSPath}"
        fi
        addXrayOutbound "VMess-out"
        addXrayRouting VMess-out outboundTag "${domainList}"
        reloadCore
        echoContent green " ---> IPv6 offload uninstall successful"
        exit 0
    fi
    echoContent red "================================================== ==============="
    setVMessWSRoutingOutbounds
}

# Remove VMess+WS+TLS shunt
removeVMessWSRouting() {

    removeXrayOutbound VMess-out
    unInstallRouting VMess-out outboundTag

    reloadCore
        echoContent green " ---> BT download disabled successfully"
}

# Restart core
reloadCore() {
    readInstallType

    if [[ "${coreInstallType}" == "1" ]]; then
        handleXray stop
        handleXray start
    fi
    if echo "${currentInstallProtocolType}" | grep -q ",20," || [[ "${coreInstallType}" == "2" || -n "${singBoxConfigPath}" ]]; then
        handleSingBox stop
        handleSingBox start
    fi
}

# dns divert
dnsRouting() {

    if [[ -z "${configPath}" ]]; then
        echoContent red "================================================== ==============="
        menu
        exit 0
    fi
    echoContent skyBlue "\nFunction 1/${totalProgress}: Diversion tool"
    echoContent red "\n=============================================================="
    echoContent yellow "The domain name below must be consistent with the outbound vps"
    echoContent yellow "Example of domain name entry: netflix,openai\n"

    echoContent yellow "# Notes"
    echoContent yellow "# Tutorial: https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"
    read -r -p "Please select:" selectType

    case ${selectType} in
    1)
        setUnlockDNS
        ;;
    2)
        removeUnlockDNS
        ;;
    esac
}

# SNI reverse proxy offload
sniRouting() {

    if [[ -z "${configPath}" ]]; then
        echoContent red "================================================== ==============="
        menu
        exit 0
    fi
    echoContent skyBlue "\nFunction 1/${totalProgress}: Streaming Media Toolbox"
    echoContent red "\n=============================================================="
    echoContent yellow "1.Add"
    echoContent yellow "2.Uninstall"
    echoContent yellow "# Notes"

    echoContent yellow "# Tutorial: https://www.v2ray-agent.com/archives/ba-he-yi-jiao-ben-yu-ming-fen-liu-jiao-cheng \n"
    echoContent yellow "1.Add"
    read -r -p "Please select:" selectType

    case ${selectType} in
    1)
        setUnlockSNI
        ;;
    2)
        removeUnlockSNI
        ;;
    esac
}
# Set up SNI offloading
setUnlockSNI() {
    read -r -p "Please enter the SNI IP of the offload:" setSNIP
    if [[ -n ${setSNIP} ]]; then
        echoContent red "=============================================================="

        if [[ "${coreInstallType}" == 1 ]]; then
    echoContent yellow "2.Uninstall"
            read -r -p "Enter domains using the example above:" xrayDomainList
            local hosts={}
            while read -r domain; do
                local matchedRuleValue
                matchedRuleValue=$(getDLCMatchedRuleValue "${domain}" "/etc/v2ray-agent/xray")
                hosts=$(echo "${hosts}" | jq -r --arg key "${matchedRuleValue}" --arg value "${setSNIP}" '. + {($key):$value}')
            done < <(echo "${xrayDomainList}" | tr ',' '\n')
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
        fi
        if [[ -n "${singBoxConfigPath}" ]]; then
        echoContent yellow "Input example: netflix, disney, hulu"
            read -r -p "Enter domains using the example above:" singboxDomainList
            addSingBoxDNSConfig "${setSNIP}" "${singboxDomainList}" "predefined"
        fi
        echoContent yellow "Input example: netflix, disney, hulu"
        reloadCore
    else
        echoContent red " ---> Wrong selection"
    fi
    exit 0
}

addXrayDNSConfig() {
    local ip=$1
    local domainList=$2
    local domains=[]
    while read -r line; do
        local matchedRuleValue
        matchedRuleValue=$(getDLCMatchedRuleValue "${line}" "/etc/v2ray-agent/xray")
        domains=$(echo "${domains}" | jq -r --arg rule "${matchedRuleValue}" '. += [$rule]')
    done < <(echo "${domainList}" | tr ',' '\n')

    if [[ "${coreInstallType}" == "1" ]]; then

        cat <<EOF >${configPath}11_dns.json
{
    "dns": {
        "servers": [
            {
                "address": "${ip}",
                "port": 53,
                "domains": ${domains}
            },
        "localhost"
        ]
    }
}
EOF
    fi
}

addSingBoxDNSConfig() {
    local ip=$1
    local domainList=$2
    local actionType=$3

    local rules=
    rules=$(initSingBoxRules "${domainList}" "dns")
    local domainRules=
    domainRules=$(echo "${rules}" | jq .domainRules)

    local ruleSet=
    ruleSet=$(echo "${rules}" | jq .ruleSet)

    local ruleSetTag=[]
    if [[ "$(echo "${ruleSet}" | jq '.|length')" != "0" ]]; then
        ruleSetTag=$(echo "${ruleSet}" | jq '.|map(.tag)')
    fi
    if [[ -n "${singBoxConfigPath}" ]]; then
        if [[ "${actionType}" == "predefined" ]]; then
            local predefined={}
            while read -r line; do
                predefined=$(echo "${predefined}" | jq ".\"${line}\"=\"${ip}\"")
            done < <(echo "${domainList}" | tr ',' '\n' | grep -v '^$' | sort -n | uniq | paste -sd ',' | tr ',' '\n')

            cat <<EOF >"${singBoxConfigPath}dns.json"
{
  "dns": {
    "servers": [
        {
            "tag": "local",
            "type": "local"
        },
        {
            "tag": "hosts",
            "type": "hosts",
            "predefined": ${predefined}
        }
    ],
    "rules": [
        {
            "domain_regex":${domainRules},
            "server":"hosts"
        }
    ]
  }
}
EOF
        else
            cat <<EOF >"${singBoxConfigPath}dns.json"
{
  "dns": {
    "servers": [
      {
        "tag": "local",
        "type": "local"
      },
      {
        "tag": "dnsRouting",
        "type": "udp",
        "server": "${ip}"
      }
    ],
    "rules": [
      {
        "rule_set": ${ruleSetTag},
        "domain_regex": ${domainRules},
        "server":"dnsRouting"
      }
    ]
  },
  "route":{
    "rule_set":${ruleSet}
  }
}
EOF
        fi
    fi
}
# Set dns
setUnlockDNS() {
    read -r -p "Please enter the diverted DNS:" setDNS
    if [[ -n ${setDNS} ]]; then
        echoContent red "=============================================================="
        echoContent yellow "Please enter 1 for the default scheme. The default scheme includes the following content"
    read -r -p "Please enter the domain name according to the above example:" domainList

        if [[ "${coreInstallType}" == "1" ]]; then
            addXrayDNSConfig "${setDNS}" "${domainList}"
        fi

        if [[ -n "${singBoxConfigPath}" ]]; then
            addSingBoxOutbound 01_direct_outbound
            addSingBoxDNSConfig "${setDNS}" "${domainList}"
        fi

        reloadCore

        echoContent yellow "netflix,bahamut,hulu,hbo,disney,bbc,4chan,fox,abema,dmm,niconico,pixiv,bilibili,viu"
        echoContent yellow "\n ---> If you still can't watch, you can try the following two solutions"
        echoContent yellow "1.Restart vps"
    else
        echoContent red " ---> Not installed, please use script to install"
    fi
    exit 0
}

# Remove DNS offloading
removeUnlockDNS() {
    if [[ "${coreInstallType}" == "1" && -f "${configPath}11_dns.json" ]]; then
        cat <<EOF >${configPath}11_dns.json
{
	"dns": {
		"servers": [
			"localhost"
		]
	}
}
EOF
    fi

    if [[ "${coreInstallType}" == "2" && -f "${singBoxConfigPath}dns.json" ]]; then
        cat <<EOF >${singBoxConfigPath}dns.json
{
    "dns": {
        "servers":[
            {
                "tag":"local",
                "type":"local"
            }
        ]
    }
}
EOF
    fi

    reloadCore

        echoContent green " ---> BT download opened successfully"

    exit 0
}

# Remove SNI shunt
removeUnlockSNI() {
    if [[ "${coreInstallType}" == 1 ]]; then
        cat <<EOF >${configPath}11_dns.json
{
    "dns": {
        "servers": [
            "localhost"
        ]
    }
}
EOF
    fi

    if [[ "${coreInstallType}" == "2" && -f "${singBoxConfigPath}dns.json" ]]; then
        cat <<EOF >${singBoxConfigPath}dns.json
{
    "dns": {
        "servers":[
            {
                "type":"local"
            }
        ]
    }
}
EOF
    fi

    reloadCore
        echoContent green " ---> Added successfully"

    exit 0
}

customSingBoxInstall() {
    echoContent skyBlue "\nFunction 1/${totalProgress}: any door diversion"
    echoContent yellow "0.VLESS+Vision+TCP"
        echoContent yellow "2.After uninstalling dns unlocking, modify the local [/etc/resolv.conf] DNS settings and restart vps\n"
    echoContent yellow "VLESS is prefixed and 0 is installed by default. If you only need to install 0, just select 0"
    echoContent yellow "0.VLESS+TLS_Vision+TCP"
    echoContent yellow "6.Hysteria2"
    echoContent yellow "7.VLESS+Reality+Vision"
    echoContent yellow "8.VLESS+Reality+gRPC"
    echoContent yellow "9.Tuic"
    echoContent yellow "10.Naive"
    echoContent yellow "11.VMess+TLS+HTTPUpgrade"
    echoContent yellow "13.anytls"

    read -r -p "Please select [multiple selection], [for example: 123]:" selectCustomInstallType
    echoContent skyBlue "--------------------------------------------------------------"
    if echo "${selectCustomInstallType}" | grep -q "，"; then
    echoContent red "\n================================================ ================="
        exit 0
    fi
    if [[ "${selectCustomInstallType}" != "10" ]] && [[ "${selectCustomInstallType}" != "11" ]] && [[ "${selectCustomInstallType}" != "13" ]] && ((${#selectCustomInstallType} >= 2)) && ! echo "${selectCustomInstallType}" | grep -q ","; then
    echoContent red "================================================== ==============="
        exit 0
    fi
    if [[ "${selectCustomInstallType: -1}" != "," ]]; then
        selectCustomInstallType="${selectCustomInstallType},"
    fi
    if [[ "${selectCustomInstallType:0:1}" != "," ]]; then
        selectCustomInstallType=",${selectCustomInstallType},"
    fi

    if [[ "${selectCustomInstallType//,/}" =~ ^[0-9]+$ ]]; then
        readLastInstallationConfig
        unInstallSubscribe
        totalProgress=9
        installTools 1
        if echo "${selectCustomInstallType}" | grep -q -E ",0,|,1,|,3,|,4,|,6,|,9,|,10,|,11,|,13,"; then
        # Apply for tls
            initTLSNginxConfig 2
            # handleNginx start
            installTLS 3
            handleNginx stop
        fi

        installSingBox 4
        installSingBoxService 5
        initSingBoxConfig custom 6
        cleanUp xrayDel
        installCronTLS 7
        handleSingBox stop
        handleSingBox start
        handleNginx stop
        handleNginx start
        checkGFWStatue 8
        showAccounts 9
    else
        echoContent red " ---> Wrong selection"
        customSingBoxInstall
    fi
}

installXrayReality() {
    selectCustomInstallType=",7,"
    readLastInstallationConfig
    unInstallSubscribe
    totalProgress=6
    installTools 1

    handleNginx stop

    installXray 2 false
    installXrayService 3
    initXrayConfig custom 4
    cleanUp singBoxDel

    handleXray stop
    handleXray start
    checkGFWStatue 5
    showAccounts 6
}
installSingBoxReality() {

    selectCustomInstallType=",7,"
    readLastInstallationConfig
    unInstallSubscribe
    totalProgress=6
    installTools 1

    installSingBox 2
    installSingBoxService 3
    initSingBoxConfig custom 4
    cleanUp xrayDel
    handleSingBox stop
    handleSingBox start
    checkGFWStatue 5
    showAccounts 6
}
# Xray-core personalized installation
customXrayInstall() {
    echoContent skyBlue "\nFunction 1/${totalProgress}: VMess+WS+TLS offload"
    echoContent yellow "1.VLESS+TLS+WS[CDN]"
    echoContent yellow "2.Trojan+TLS+gRPC[CDN]"
    echoContent yellow "3.VMess+TLS+WS[CDN]"
    echoContent yellow "4.Trojan+TLS"
    echoContent yellow "5.VLESS+TLS+gRPC[CDN]"
    echoContent yellow "VLESS is prefixed and 0 is installed by default. If you only need to install 0, just select 0"
    # echoContent yellow "8.VLESS+Reality+gRPC"
    echoContent yellow "0.VLESS+TLS_Vision+TCP[recommended]"
    read -r -p "Please select [multiple selection], [for example: 123]:" selectCustomInstallType
    echoContent skyBlue "--------------------------------------------------------------"
    if echo "${selectCustomInstallType}" | grep -q "，"; then
        echoContent red " ---> Not installed, please use script to install"
        exit 0
    fi
    if [[ "${selectCustomInstallType}" != "12" ]] && ((${#selectCustomInstallType} >= 2)) && ! echo "${selectCustomInstallType}" | grep -q ","; then
    echoContent red "\n================================================ ================="
        exit 0
    fi
    if echo "${selectCustomInstallType}" | grep -qE '^(7|7,12|12)$'; then
        selectCustomInstallType=",${selectCustomInstallType},"
    else
        if ! echo "${selectCustomInstallType}" | grep -q "0,"; then
            selectCustomInstallType=",0,${selectCustomInstallType},"
        else
            selectCustomInstallType=",${selectCustomInstallType},"
        fi
    fi
    if [[ "${selectCustomInstallType:0:1}" != "," ]]; then
        selectCustomInstallType=",${selectCustomInstallType},"
    fi
    if [[ "${selectCustomInstallType//,/}" =~ ^[0-7]+$ ]]; then
        readLastInstallationConfig
        unInstallSubscribe
        # checkBTPanel
        # check1Panel
        totalProgress=12
        installTools 1
        if [[ -n "${btDomain}" ]]; then
    echoContent skyBlue "\nFunction 1/${totalProgress}: Add inbound at any door"
            handleXray stop
            if [[ "${selectCustomInstallType}" != ",7," ]]; then
                customPortFunction
            fi
        else
            if ! echo "${selectCustomInstallType}" | grep -qE '^(,7,|,7,12,|,12,)$'; then
            # Apply for tls
                initTLSNginxConfig 2
                handleXray stop
                installTLS 3
            else
    echoContent skyBlue "\nFunction 1/${totalProgress}: DNS offloading"
            fi
        fi

        handleNginx stop
        if echo "${selectCustomInstallType}" | grep -qE ",1,|,2,|,3,|,5,|,12,"; then
            randomPathFunction 4
        fi
        if [[ -n "${btDomain}" ]]; then
    echoContent skyBlue "\nFunction 1/${totalProgress}: SNI reverse proxy offload"
        else
            nginxBlog 6
        fi
        if ! echo "${selectCustomInstallType}" | grep -qE '^(,7,|,7,12,|,12,)$'; then
            updateRedirectNginxConf
            handleNginx start
        fi

        # Install Xray
        installXray 7 false
        installXrayService 8
        initXrayConfig custom 9
        cleanUp singBoxDel
        if ! echo "${selectCustomInstallType}" | grep -qE '^(,7,|,7,12,|,12,)$'; then
            installCronTLS 10
        fi

        handleXray stop
        handleXray start
        # Generate account
        checkGFWStatue 11
        showAccounts 12
    else
    echoContent red "================================================== ==============="
        customXrayInstall
    fi
}

# Select core installation---v2ray-core, xray-core
selectCoreInstall() {
    echoContent skyBlue "\n========================Personalized installation================== =========="
    echoContent red "\n=============================================================="
    echoContent yellow "1.Xray-core"
    echoContent yellow "2.sing-box"
    echoContent red "=============================================================="
    read -r -p "Please select:" selectCoreType
    case ${selectCoreType} in
    1)
        if [[ "${selectInstallType}" == "1" ]]; then
            xrayCoreInstall
        elif [[ "${selectInstallType}" == "2" ]]; then
            customXrayInstall
        elif [[ "${selectInstallType}" == "3" ]]; then
            installXrayReality
        fi
        ;;
    2)
        if [[ "${selectInstallType}" == "1" ]]; then
            singBoxInstall
        elif [[ "${selectInstallType}" == "2" ]]; then
            customSingBoxInstall
        elif [[ "${selectInstallType}" == "3" ]]; then
            installSingBoxReality
        fi
        ;;
    *)
        echoContent red "================================================== ==============="
        selectCoreInstall
        ;;
    esac
}

# xray-core installation
xrayCoreInstall() {
    readLastInstallationConfig
    unInstallSubscribe
    # checkBTPanel
    # check1Panel
    selectCustomInstallType=
    totalProgress=12
    installTools 2
    if [[ -n "${btDomain}" ]]; then
    echoContent skyBlue "------------------------------------------------- ---------------"
        handleXray stop
        customPortFunction
    else
        # Apply for tls
        initTLSNginxConfig 3
        handleXray stop
        # handleNginx start

        installTLS 4
    fi

    handleNginx stop
    randomPathFunction 5

    # Install Xray
    installXray 6 false
    installXrayService 7
    initXrayConfig all 8
    cleanUp singBoxDel
    installCronTLS 9
    if [[ -n "${btDomain}" ]]; then
    echoContent skyBlue "\n========================Personalized installation================== =========="
    else
        nginxBlog 10
    fi
    updateRedirectNginxConf
    handleXray stop
    sleep 2
    handleXray start

    handleNginx start
    checkGFWStatue 11
    showAccounts 12
}

singBoxInstall() {
    readLastInstallationConfig
    unInstallSubscribe
    # checkBTPanel
    # check1Panel
    selectCustomInstallType=
    totalProgress=8
    installTools 2

    if [[ -n "${btDomain}" ]]; then
    echoContent skyBlue "------------------------------------------------- --------- ------"
        handleXray stop
        customPortFunction
    else
        initTLSNginxConfig 3
        handleXray stop
        installTLS 4
    fi

    handleNginx stop

    installSingBox 5
    installSingBoxService 6
    initSingBoxConfig all 7

    cleanUp xrayDel
    installCronTLS 8

    handleSingBox stop
    handleSingBox start
    handleNginx stop
    handleNginx start
    showAccounts 9
}

# Core Management
coreVersionManageMenu() {

    if [[ -z "${coreInstallType}" ]]; then
            echoContent red " ---> ip cannot be empty"
        menu
        exit 0
    fi
            echoContent skyBlue "\nProgress 3/${totalProgress}: Pagoda panel detected, skip applying for TLS"
    echoContent red "\n=============================================================="
    echoContent yellow "1.Xray-core"
    echoContent yellow "2.sing-box"
    echoContent red "=============================================================="
    read -r -p "Enter selection:" selectCore

    if [[ "${selectCore}" == "1" ]]; then
        xrayVersionManageMenu 1
    elif [[ "${selectCore}" == "2" ]]; then
        singBoxVersionManageMenu 1
    fi
}
# Scheduled task check
cronFunction() {
    if [[ "${cronName}" == "RenewTLS" ]]; then
        renewalTLS
        exit 0
    elif [[ "${cronName}" == "UpdateGeo" ]]; then
        updateGeoSite >>/etc/v2ray-agent/crontab_updateGeoSite.log
        echoContent green " ---> geo update date: $(date "+%F %H:%M:%S")" >>/etc/v2ray-agent/crontab_updateGeoSite.log
        exit 0
    fi
}
#Account management
manageAccount() {
            echoContent skyBlue "\nProgress 6/${totalProgress}: Pagoda panel detected, skipping disguised website"
    if [[ -z "${configPath}" ]]; then
            echoContent red " ---> domain cannot be empty"
        exit 0
    fi

    echoContent red "\n=============================================================="
    echoContent yellow "1.VLESS+TLS+WS[CDN]"
    echoContent yellow "2.Trojan+TLS+gRPC[CDN]"
    echoContent yellow "3.VMess+TLS+WS[CDN]"
    echoContent yellow "4.Trojan+TLS"
    echoContent yellow "5.VLESS+TLS+gRPC[CDN]"
    echoContent yellow "7.VLESS+Reality+uTLS+Vision[recommended]"
    echoContent yellow "1.Xray-core"
    echoContent red "=============================================================="
    read -r -p "Please enter:" manageAccountStatus
    if [[ "${manageAccountStatus}" == "1" ]]; then
        showAccounts 1
    elif [[ "${manageAccountStatus}" == "2" ]]; then
        subscribe
    elif [[ "${manageAccountStatus}" == "3" ]]; then
        addSubscribeMenu 1
    elif [[ "${manageAccountStatus}" == "4" ]]; then
        addUser
    elif [[ "${manageAccountStatus}" == "5" ]]; then
        removeUser
    else
        echoContent red " ---> Wrong selection"
    fi
}

installSubscribe() {
    readNginxSubscribe
    local nginxSubscribeListen=
    local nginxSubscribeSSL=
    local serverName=
    local SSLType=
    local listenIPv6=
    if [[ -z "${subscribePort}" ]]; then

        nginxVersion=$(nginx -v 2>&1)

        if echo "${nginxVersion}" | grep -q "not found" || [[ -z "${nginxVersion}" ]]; then
    echoContent yellow "2.v2ray-core"
            read -r -p "Install [y/n]?" installNginxStatus
            if [[ "${installNginxStatus}" == "y" ]]; then
                installNginxTools
            else
        echoContent red " ---> Parameter error"
                exit 0
            fi
        fi
    echoContent yellow "# Only delete VLESS Reality related configurations, other content will not be deleted."

        mapfile -t result < <(initSingBoxPort "${subscribePort}")
        echo
    echoContent yellow "# If you need to uninstall other content, please uninstall the script function"
        nginxBlog
        echo
        local httpSubscribeStatus=

        if ! echo "${selectCustomInstallType}" | grep -qE ",0,|,1,|,2,|,3,|,4,|,5,|,6,|,9,|,10,|,11,|,13," && ! echo "${currentInstallProtocolType}" | grep -qE ",0,|,1,|,2,|,3,|,4,|,5,|,6,|,9,|,10,|,11,|,13," && [[ -z "${domain}" ]]; then
            httpSubscribeStatus=true
        fi

        if [[ "${httpSubscribeStatus}" == "true" ]]; then

    echoContent yellow "# You can customize email and uuid when adding a single user"
            echo
            read -r -p "Use HTTP subscription [y/n]?" addNginxSubscribeStatus
            echo
            if [[ "${addNginxSubscribeStatus}" != "y" ]]; then
    echoContent yellow "# If Hysteria or Tuic is installed, the account will be added to the corresponding type at the same time\n"
                exit
            fi
        else
            local subscribeServerName=
            if [[ -n "${currentHost}" ]]; then
                subscribeServerName="${currentHost}"
            else
                subscribeServerName="${domain}"
            fi

            SSLType="ssl"
            serverName="server_name ${subscribeServerName};"
            nginxSubscribeSSL="ssl_certificate /etc/v2ray-agent/tls/${subscribeServerName}.crt;ssl_certificate_key /etc/v2ray-agent/tls/${subscribeServerName}.key;"
        fi
        if [[ -n "$(curl --connect-timeout 2 -s -6 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)" ]]; then
            listenIPv6="listen [::]:${result[-1]} ${SSLType};"
        fi
        if echo "${nginxVersion}" | grep -q "1.25" && [[ $(echo "${nginxVersion}" | awk -F "[.]" '{print $3}') -gt 0 ]] || [[ $(echo "${nginxVersion}" | awk -F "[.]" '{print $2}') -gt 25 ]]; then
            nginxSubscribeListen="listen ${result[-1]} ${SSLType} so_keepalive=on;http2 on;${listenIPv6}"
        else
            nginxSubscribeListen="listen ${result[-1]} ${SSLType} so_keepalive=on;${listenIPv6}"
        fi

        cat <<EOF >${nginxConfigPath}subscribe.conf
server {
    ${nginxSubscribeListen}
    ${serverName}
    ${nginxSubscribeSSL}
    ssl_protocols              TLSv1.2 TLSv1.3;
    ssl_ciphers                TLS13_AES_128_GCM_SHA256:TLS13_AES_256_GCM_SHA384:TLS13_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers  on;

    resolver                   1.1.1.1 valid=60s;
    resolver_timeout           2s;
    client_max_body_size 100m;
    root ${nginxStaticPath};
    location ~ ^/s/(clashMeta|default|clashMetaProfiles|sing-box|sing-box_profiles)/(.*) {
        default_type 'text/plain; charset=utf-8';
        alias /etc/v2ray-agent/subscribe/\$1/\$2;
    }
    location / {
    }
}
EOF
        bootStartup nginx
        handleNginx stop
        handleNginx start
    fi
    if [[ -z $(pgrep -f "nginx") ]]; then
        handleNginx start
    fi
}
unInstallSubscribe() {
    rm -rf ${nginxConfigPath}subscribe.conf >/dev/null 2>&1
}

#Add subscription
addSubscribeMenu() {
    echoContent skyBlue "\nFunction 1/${totalProgress}: Select core installation"
    echoContent yellow "1.Check account"
    echoContent yellow "2.View subscription"
    echoContent red "=============================================================="
    read -r -p "Please select:" addSubscribeStatus
    if [[ "${addSubscribeStatus}" == "1" ]]; then
        addOtherSubscribe
    elif [[ "${addSubscribeStatus}" == "2" ]]; then
        if [[ ! -f "/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl" ]]; then
        echoContent green " ---> Domestic domain name + IP blocked successfully"
            exit 0
        fi
        grep -v '^$' "/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl" | awk '{print NR""":"$0}'
        read -r -p "Select the subscription number to delete [single selection only]:" delSubscribeIndex
        if [[ -z "${delSubscribeIndex}" ]]; then
        echoContent green " ---> Domain blacklist/whitelist deleted successfully"
            exit 0
        fi

        sed -i "$((delSubscribeIndex))d" "/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl" >/dev/null 2>&1

        echoContent green " ---> Blocked IP added successfully"
        subscribe
    fi
}
# Add other machines to clashMeta subscription
addOtherSubscribe() {
    echoContent yellow "3.Add subscription"
    echoContent yellow "4.Add user"
        echoContent skyBlue "\nProgress 3/${totalProgress}: Pagoda panel detected, skip applying for TLS"
    read -r -p "Please enter the domain name, port and machine alias:" remoteSubscribeUrl
    if [[ -z "${remoteSubscribeUrl}" ]]; then
        echoContent red " ---> Parameter error"
        addOtherSubscribe
    elif ! echo "${remoteSubscribeUrl}" | grep -q ":"; then
    echoContent red "=============================================================="
    else

        if [[ -f "/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl" ]] && grep -q "${remoteSubscribeUrl}" /etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl; then
    echoContent red "\n================================================ ================="
            exit 0
        fi
        echo
        read -r -p "Is this an HTTP subscription? [y/n]" httpSubscribeStatus
        if [[ "${httpSubscribeStatus}" == "y" ]]; then
            remoteSubscribeUrl="${remoteSubscribeUrl}:http"
        fi
        echo "${remoteSubscribeUrl}" >>/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl
        subscribe
    fi
}
# clashMeta configuration file
clashMetaConfig() {
    local url=$1
    local id=$2
    cat <<EOF >"/etc/v2ray-agent/subscribe/clashMetaProfiles/${id}"
log-level: debug
mode: rule
ipv6: true
mixed-port: 7890
allow-lan: true
bind-address: "*"
lan-allowed-ips:
  - 0.0.0.0/0
  - ::/0
find-process-mode: strict
external-controller: 0.0.0.0:9090

geox-url:
  geoip: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat"
  geosite: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
  mmdb: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.metadb"
geo-auto-update: true
geo-update-interval: 24

external-controller-cors:
  allow-private-network: true

global-client-fingerprint: chrome

profile:
  store-selected: true
  store-fake-ip: true

sniffer:
  enable: true
  override-destination: false
  sniff:
    QUIC:
      ports: [ 443 ]
    TLS:
      ports: [ 443 ]
    HTTP:
      ports: [80]


dns:
  enable: true
  prefer-h3: false
  listen: 0.0.0.0:1053
  ipv6: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - '*.lan'
    - '*.local'
    - 'dns.google'
    - "localhost.ptlogin2.qq.com"
  use-hosts: true
  nameserver:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
    - 1.1.1.1
    - 8.8.8.8
  proxy-server-nameserver:
    - https://223.5.5.5/dns-query
    - https://1.12.12.12/dns-query
  nameserver-policy:
    "geosite:cn,private":
      - https://doh.pub/dns-query
      - https://dns.alidns.com/dns-query

proxy-providers:
  ${subscribeSalt}_provider:
    type: http
    path: ./${subscribeSalt}_provider.yaml
    url: ${url}
    interval: 3600
    proxy: DIRECT
    health-check:
      enable: true
      url: https://cp.cloudflare.com/generate_204
      interval: 300

proxy-groups:
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

  - name: 全球代理
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择

  - name: 流媒体
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择
      - DIRECT
  - name: DNS_Proxy
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 自动选择
      - 手动切换
      - DIRECT

  - name: Telegram
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择
  - name: Google
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择
      - DIRECT
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
      - 手动切换
      - 自动选择
  - name: Spotify
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 流媒体
      - 手动切换
      - 自动选择
      - DIRECT
  - name: HBO
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 流媒体
      - 手动切换
      - 自动选择
  - name: Bing
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择


  - name: OpenAI
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择

  - name: ClaudeAI
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 手动切换
      - 自动选择

  - name: Disney
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - 流媒体
      - 手动切换
      - 自动选择
  - name: GitHub
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
      - 自动选择
  - name: 漏网之鱼
    type: select
    use:
      - ${subscribeSalt}_provider
    proxies:
      - DIRECT
      - 手动切换
      - 自动选择
rule-providers:
  lan:
    type: http
    behavior: classical
    interval: 86400
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Lan/Lan.yaml
    path: ./Rules/lan.yaml
  reject:
    type: http
    behavior: domain
    url: https://gh-proxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt
    path: ./ruleset/reject.yaml
    interval: 86400
  proxy:
    type: http
    behavior: domain
    url: https://gh-proxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/proxy.txt
    path: ./ruleset/proxy.yaml
    interval: 86400
  direct:
    type: http
    behavior: domain
    url: https://gh-proxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/direct.txt
    path: ./ruleset/direct.yaml
    interval: 86400
  private:
    type: http
    behavior: domain
    url: https://gh-proxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/private.txt
    path: ./ruleset/private.yaml
    interval: 86400
  gfw:
    type: http
    behavior: domain
    url: https://gh-proxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/gfw.txt
    path: ./ruleset/gfw.yaml
    interval: 86400
  greatfire:
    type: http
    behavior: domain
    url: https://gh-proxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/greatfire.txt
    path: ./ruleset/greatfire.yaml
    interval: 86400
  tld-not-cn:
    type: http
    behavior: domain
    url: https://gh-proxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/tld-not-cn.txt
    path: ./ruleset/tld-not-cn.yaml
    interval: 86400
  telegramcidr:
    type: http
    behavior: ipcidr
    url: https://gh-proxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/telegramcidr.txt
    path: ./ruleset/telegramcidr.yaml
    interval: 86400
  applications:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/applications.txt
    path: ./ruleset/applications.yaml
    interval: 86400
  Disney:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Disney/Disney.yaml
    path: ./ruleset/disney.yaml
    interval: 86400
  Netflix:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Netflix/Netflix.yaml
    path: ./ruleset/netflix.yaml
    interval: 86400
  YouTube:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/YouTube/YouTube.yaml
    path: ./ruleset/youtube.yaml
    interval: 86400
  HBO:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/HBO/HBO.yaml
    path: ./ruleset/hbo.yaml
    interval: 86400
  OpenAI:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/OpenAI/OpenAI.yaml
    path: ./ruleset/openai.yaml
    interval: 86400
  ClaudeAI:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Claude/Claude.yaml
    path: ./ruleset/claudeai.yaml
    interval: 86400
  Bing:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Bing/Bing.yaml
    path: ./ruleset/bing.yaml
    interval: 86400
  Google:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Google/Google.yaml
    path: ./ruleset/google.yaml
    interval: 86400
  GitHub:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/GitHub/GitHub.yaml
    path: ./ruleset/github.yaml
    interval: 86400
  Spotify:
    type: http
    behavior: classical
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Spotify/Spotify.yaml
    path: ./ruleset/spotify.yaml
    interval: 86400
  ChinaMaxDomain:
    type: http
    behavior: domain
    interval: 86400
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaMax/ChinaMax_Domain.yaml
    path: ./Rules/ChinaMaxDomain.yaml
  ChinaMaxIPNoIPv6:
    type: http
    behavior: ipcidr
    interval: 86400
    url: https://gh-proxy.com/https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaMax/ChinaMax_IP_No_IPv6.yaml
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
  - RULE-SET,ClaudeAI,ClaudeAI
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
# Random salt
initRandomSalt() {
    local chars="abcdefghijklmnopqrtuxyz"
    local initCustomPath=
    for i in {1..10}; do
        echo "${i}" >/dev/null
        initCustomPath+="${chars:RANDOM%${#chars}:1}"
    done
    echo "${initCustomPath}"
}
# Subscribe
subscribe() {
    readInstallProtocolType
    installSubscribe

    readNginxSubscribe
    local renewSalt=$1
    local showStatus=$2
    if [[ "${coreInstallType}" == "1" || "${coreInstallType}" == "2" ]]; then

        echoContent skyBlue "\nProgress 11/${totalProgress}: Pagoda panel detected, skipping disguised website"
    echoContent yellow "5.Delete user"
    echoContent red "================================================== ==============="
    echoContent yellow "1.Add"

        if [[ -f "/etc/v2ray-agent/subscribe_local/subscribeSalt" && -n $(cat "/etc/v2ray-agent/subscribe_local/subscribeSalt") ]]; then
            if [[ -z "${renewSalt}" ]]; then
            read -r -p "Read the Salt set by the last installation. Do you want to use the Salt generated last time? [y/n]:" historySaltStatus
                if [[ "${historySaltStatus}" == "y" ]]; then
                    subscribeSalt=$(cat /etc/v2ray-agent/subscribe_local/subscribeSalt)
                else
                read -r -p "Please enter the salt value, [Enter] use random:" subscribeSalt
                fi
            else
                subscribeSalt=$(cat /etc/v2ray-agent/subscribe_local/subscribeSalt)
            fi
        else
            read -r -p "Please enter the salt value, [Enter] use random:" subscribeSalt
            showStatus=
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
        rm -rf /etc/v2ray-agent/subscribe_local/sing-box/*
        showAccounts >/dev/null
        if [[ -n $(ls /etc/v2ray-agent/subscribe_local/default/) ]]; then
            if [[ -f "/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl" && -n $(cat "/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl") ]]; then
                if [[ -z "${renewSalt}" ]]; then
                    read -r -p "Other subscriptions found. Update them? [y/n]" updateOtherSubscribeStatus
                else
                    updateOtherSubscribeStatus=y
                fi
            fi
            local subscribePortLocal="${subscribePort}"
            find /etc/v2ray-agent/subscribe_local/default/* | while read -r email; do
                email=$(echo "${email}" | awk -F "[d][e][f][a][u][l][t][/]" '{print $2}')

                # md5 encryption
                local emailMd5=
                emailMd5=$(echo -n "${email}${subscribeSalt}"$'\n' | md5sum | awk '{print $1}')

                cat "/etc/v2ray-agent/subscribe_local/default/${email}" >>"/etc/v2ray-agent/subscribe/default/${emailMd5}"
                if [[ "${updateOtherSubscribeStatus}" == "y" ]]; then
                    updateRemoteSubscribe "${emailMd5}" "${email}"
                fi
                local base64Result
                base64Result=$(base64 -w 0 "/etc/v2ray-agent/subscribe/default/${emailMd5}")
                echo "${base64Result}" >"/etc/v2ray-agent/subscribe/default/${emailMd5}"
                echoContent yellow "--------------------------------------------------------------"
                local currentDomain=${currentHost}

                if [[ -n "${currentDefaultPort}" && "${currentDefaultPort}" != "443" ]]; then
                    currentDomain="${currentHost}:${currentDefaultPort}"
                fi
                if [[ -n "${subscribePortLocal}" ]]; then
                    if [[ "${subscribeType}" == "http" ]]; then
                        currentDomain="$(getPublicIP):${subscribePort}"
                    else
                        currentDomain="${currentHost}:${subscribePort}"
                    fi
                fi
                if [[ -z "${showStatus}" ]]; then
    echoContent skyBlue "\nFunction 1/1: reality uninstall"
                    echoContent green "email:${email}\n"
                    echoContent yellow "url:${subscribeType}://${currentDomain}/s/default/${emailMd5}\n"
    echoContent yellow "2.Remove"
                    if [[ "${release}" != "alpine" ]]; then
                        echo "${subscribeType}://${currentDomain}/s/default/${emailMd5}" | qrencode -s 10 -m 1 -t UTF8
                    fi

                    # clashMeta
                #clashMeta
                    if [[ -f "/etc/v2ray-agent/subscribe_local/clashMeta/${email}" ]]; then

                        cat "/etc/v2ray-agent/subscribe_local/clashMeta/${email}" >>"/etc/v2ray-agent/subscribe/clashMeta/${emailMd5}"

                        sed -i '1i\proxies:' "/etc/v2ray-agent/subscribe/clashMeta/${emailMd5}"

                        local clashProxyUrl="${subscribeType}://${currentDomain}/s/clashMeta/${emailMd5}"
                        clashMetaConfig "${clashProxyUrl}" "${emailMd5}"
    echoContent skyBlue "\nFunction 1/${totalProgress}: Account Management"
                        echoContent yellow "url:${subscribeType}://${currentDomain}/s/clashMetaProfiles/${emailMd5}\n"
    echoContent yellow "#Notes:"
                        if [[ "${release}" != "alpine" ]]; then
                            echo "${subscribeType}://${currentDomain}/s/clashMetaProfiles/${emailMd5}" | qrencode -s 10 -m 1 -t UTF8
                        fi

                    fi
                    # sing-box
                    if [[ -f "/etc/v2ray-agent/subscribe_local/sing-box/${email}" ]]; then
                        cp "/etc/v2ray-agent/subscribe_local/sing-box/${email}" "/etc/v2ray-agent/subscribe/sing-box_profiles/${emailMd5}"

    echoContent skyBlue "\n====================== Add other machine subscriptions==================== ==="
                        if [[ "${release}" == "alpine" ]]; then
                            wget -O "/etc/v2ray-agent/subscribe/sing-box/${emailMd5}" -q "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/documents/sing-box.json"
                        else
                            wget -O "/etc/v2ray-agent/subscribe/sing-box/${emailMd5}" -q "${wgetShowProgressStatus}" "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/documents/sing-box.json"
                        fi

                        jq ".outbounds=$(jq ".outbounds|map(if has(\"outbounds\") then .outbounds += $(jq ".|map(.tag)" "/etc/v2ray-agent/subscribe_local/sing-box/${email}") else . end)" "/etc/v2ray-agent/subscribe/sing-box/${emailMd5}")" "/etc/v2ray-agent/subscribe/sing-box/${emailMd5}" >"/etc/v2ray-agent/subscribe/sing-box/${emailMd5}_tmp" && mv "/etc/v2ray-agent/subscribe/sing-box/${emailMd5}_tmp" "/etc/v2ray-agent/subscribe/sing-box/${emailMd5}"
                        jq ".outbounds += $(jq '.' "/etc/v2ray-agent/subscribe_local/sing-box/${email}")" "/etc/v2ray-agent/subscribe/sing-box/${emailMd5}" >"/etc/v2ray-agent/subscribe/sing-box/${emailMd5}_tmp" && mv "/etc/v2ray-agent/subscribe/sing-box/${emailMd5}_tmp" "/etc/v2ray-agent/subscribe/sing-box/${emailMd5}"

    echoContent skyBlue "Input example: www.v2ray-agent.com:443:vps1\n"
                        echoContent yellow "url:${subscribeType}://${currentDomain}/s/sing-box/${emailMd5}\n"
    echoContent yellow "Please read the following article carefully: https://www.v2ray-agent.com/archives/1681804748677"
                        if [[ "${release}" != "alpine" ]]; then
                            echo "${subscribeType}://${currentDomain}/s/sing-box/${emailMd5}" | qrencode -s 10 -m 1 -t UTF8
                        fi

                    fi

                    echoContent skyBlue "--------------------------------------------------------------"
                else
        echoContent green " ---> Domain whitelist added successfully"
                fi

            done
        fi
    else
        echoContent red "================================================== ==============="
    fi
}

# Update remote subscription
updateRemoteSubscribe() {

    local emailMD5=$1
    local email=$2
    while read -r line; do
        local subscribeType=
        subscribeType="https"

        local serverAlias=
        serverAlias=$(echo "${line}" | awk -F "[:]" '{print $3}')

        local remoteUrl=
        remoteUrl=$(echo "${line}" | awk -F "[:]" '{print $1":"$2}')

        local subscribeTypeRemote=
        subscribeTypeRemote=$(echo "${line}" | awk -F "[:]" '{print $4}')

        if [[ -n "${subscribeTypeRemote}" ]]; then
            subscribeType="${subscribeTypeRemote}"
        fi
        local clashMetaProxies=

        clashMetaProxies=$(curl -s "${subscribeType}://${remoteUrl}/s/clashMeta/${emailMD5}" | sed '/proxies:/d' | sed "s/\"${email}/\"${email}_${serverAlias}/g")

        if ! echo "${clashMetaProxies}" | grep -q "nginx" && [[ -n "${clashMetaProxies}" ]]; then
            echo "${clashMetaProxies}" >>"/etc/v2ray-agent/subscribe/clashMeta/${emailMD5}"
        echoContent green " ---> Added successfully"
        else
        echoContent red " ---> Wrong selection"
        fi

        local default=
        default=$(curl -s "${subscribeType}://${remoteUrl}/s/default/${emailMD5}")

        if ! echo "${default}" | grep -q "nginx" && [[ -n "${default}" ]]; then
            default=$(echo "${default}" | base64 -d | sed "s/#${email}/#${email}_${serverAlias}/g")
            echo "${default}" >>"/etc/v2ray-agent/subscribe/default/${emailMD5}"

            echoContent green " ---> WARP global outbound setting successful"
        else
    echoContent red "================================================== ==============="
        fi

        local singBoxSubscribe=
        singBoxSubscribe=$(curl -s "${subscribeType}://${remoteUrl}/s/sing-box_profiles/${emailMD5}")

        if ! echo "${singBoxSubscribe}" | grep -q "nginx" && [[ -n "${singBoxSubscribe}" ]]; then
            singBoxSubscribe=${singBoxSubscribe//tag\": \"${email}/tag\": \"${email}_${serverAlias}}
            singBoxSubscribe=$(jq ". +=${singBoxSubscribe}" "/etc/v2ray-agent/subscribe_local/sing-box/${email}")
            echo "${singBoxSubscribe}" | jq . >"/etc/v2ray-agent/subscribe_local/sing-box/${email}"

            echoContent green " ---> Abandon settings"
        else
    echoContent red "\n================================================ ================="
        fi

    done < <(grep -v '^$' <"/etc/v2ray-agent/subscribe_remote/remoteSubscribeUrl")
}

# switch alpn
switchAlpn() {
        echoContent skyBlue "-------------------------Remarks--------------------- ----------"
    if [[ -z ${currentAlpn} ]]; then
    echoContent red "================================================== ==============="
        exit 0
    fi

    echoContent red "\n=============================================================="
        echoContent green " ---> WARP offload uninstall successful"
        echoContent yellow "# Viewing subscriptions will regenerate local account subscriptions"
        echoContent yellow "# When adding an account or modifying an account, you need to re-check the subscription before the subscription content for external access will be regenerated"
        echoContent yellow "# Does not affect the content of added remote subscriptions\n"
    echoContent red "=============================================================="

    if [[ "${currentAlpn}" == "http/1.1" ]]; then
        echoContent yellow "\n ---> Salt: ${subscribeSalt}"
    elif [[ "${currentAlpn}" == "h2" ]]; then
                echoContent yellow "--------------------------------------------------------------"
    else
        echoContent red " ---> IP acquisition failed, exit installation"
    fi

    echoContent red "=============================================================="

    read -r -p "Please select:" selectSwitchAlpnType
    if [[ "${selectSwitchAlpnType}" == "1" && "${currentAlpn}" == "http/1.1" ]]; then

        local frontingTypeJSON
        frontingTypeJSON=$(jq -r ".inbounds[0].streamSettings.tlsSettings.alpn = [\"h2\",\"http/1.1\"]" ${configPath}${frontingType}.json)
        echo "${frontingTypeJSON}" | jq . >${configPath}${frontingType}.json

    elif [[ "${selectSwitchAlpnType}" == "1" && "${currentAlpn}" == "h2" ]]; then
        local frontingTypeJSON
        frontingTypeJSON=$(jq -r ".inbounds[0].streamSettings.tlsSettings.alpn =[\"http/1.1\",\"h2\"]" ${configPath}${frontingType}.json)
        echo "${frontingTypeJSON}" | jq . >${configPath}${frontingType}.json
    else
        echoContent red "================================================== ==============="
        exit 0
    fi
    reloadCore
}

#Initialize realityKey
initRealityKey() {
                echoContent skyBlue "\n----------Default subscription----------\n"
    if [[ -n "${currentRealityPublicKey}" && -z "${lastInstallationConfig}" ]]; then
        read -r -p "Read the last installation record. Do you want to use the PublicKey/PrivateKey from the last installation? [y/n]:" historyKeyStatus
        if [[ "${historyKeyStatus}" == "y" ]]; then
            realityPrivateKey=${currentRealityPrivateKey}
            realityPublicKey=${currentRealityPublicKey}
        fi
    elif [[ -n "${currentRealityPublicKey}" && -n "${lastInstallationConfig}" ]]; then
        realityPrivateKey=${currentRealityPrivateKey}
        realityPublicKey=${currentRealityPublicKey}
    fi
    if [[ -z "${realityPrivateKey}" ]]; then
        if [[ "${selectCoreType}" == "2" || "${coreInstallType}" == "2" ]]; then
            realityX25519Key=$(/etc/v2ray-agent/sing-box/sing-box generate reality-keypair)
            realityPrivateKey=$(echo "${realityX25519Key}" | head -1 | awk '{print $2}')
            realityPublicKey=$(echo "${realityX25519Key}" | tail -n 1 | awk '{print $2}')
            echo "publicKey:${realityPublicKey}" >/etc/v2ray-agent/sing-box/conf/config/reality_key
        else
            read -r -p "Enter Private Key [Enter to generate automatically]:" historyPrivateKey
            if [[ -n "${historyPrivateKey}" ]]; then
                realityX25519Key=$(/etc/v2ray-agent/xray/xray x25519 -i "${historyPrivateKey}")
            else
                realityX25519Key=$(/etc/v2ray-agent/xray/xray x25519)
            fi
            realityPrivateKey=$(echo "${realityX25519Key}" | grep "PrivateKey" | awk '{print $2}')
            realityPublicKey=$(echo "${realityX25519Key}" | grep "Password" | awk '{print $3}')
            if [[ -z "${realityPrivateKey}" ]]; then
        echoContent red " ---> Wrong selection"
                initRealityKey
            else
                echoContent green "\n privateKey:${realityPrivateKey}"
                echoContent green "\n publicKey:${realityPublicKey}"
            fi
        fi
    fi
}
initRealityMldsa65() {
                    echoContent skyBlue "\n----------clashMeta subscription----------\n"
    if /etc/v2ray-agent/xray/xray tls ping "${realityServerName}:${realityDomainPort}" 2>/dev/null | grep -q "X25519MLKEM768"; then
        length=$(/etc/v2ray-agent/xray/xray tls ping "${realityServerName}:${realityDomainPort}" | grep "Certificate chain's total length:" | awk '{print $5}' | head -1)

        if [ "$length" -gt 3500 ]; then
            if [[ -n "${currentRealityMldsa65Seed}" && -z "${lastInstallationConfig}" ]]; then
                read -r -p "Previous Seed/Verify values found. Use them? [y/n]:" historyMldsa65Status
                if [[ "${historyMldsa65Status}" == "y" ]]; then
                    realityMldsa65Seed=${currentRealityMldsa65Seed}
                    realityMldsa65Verify=${currentRealityMldsa65Verify}
                fi
            elif [[ -n "${currentRealityMldsa65Seed}" && -n "${lastInstallationConfig}" ]]; then
                realityMldsa65Seed=${currentRealityMldsa65Seed}
                realityMldsa65Verify=${currentRealityMldsa65Verify}
            fi
            if [[ -z "${realityMldsa65Seed}" ]]; then
                #        if [[ "${selectCoreType}" == "2" || "${coreInstallType}" == "2" ]]; then
                #            realityX25519Key=$(/etc/v2ray-agent/sing-box/sing-box generate reality-keypair)
                #            realityPrivateKey=$(echo "${realityX25519Key}" | head -1 | awk '{print $2}')
                #            realityPublicKey=$(echo "${realityX25519Key}" | tail -n 1 | awk '{print $2}')
                #            echo "publicKey:${realityPublicKey}" >/etc/v2ray-agent/sing-box/conf/config/reality_key
                #        else
                realityMldsa65=$(/etc/v2ray-agent/xray/xray mldsa65)
                realityMldsa65Seed=$(echo "${realityMldsa65}" | head -1 | awk '{print $2}')
                realityMldsa65Verify=$(echo "${realityMldsa65}" | tail -n 1 | awk '{print $2}')
                #        fi
            fi
            #    echoContent green "\n Seed:${realityMldsa65Seed}"
            #    echoContent green "\n Verify:${realityMldsa65Verify}"
        else
        echoContent green " ---> Added successfully"
        fi
    else
            echoContent green " ---> WARP global outbound setting successful"
    fi
}
# Check whether the reality domain name matches
checkRealityDest() {
    local traceResult=
    traceResult=$(curl -s "https://$(echo "${realityDestDomain}" | cut -d ':' -f 1)/cdn-cgi/trace" | grep "visit_scheme=https")
    if [[ -n "${traceResult}" ]]; then
    echoContent red "\n================================================ ================="
        read -r -p "Continue? [y/n]" setRealityDestStatus
        if [[ "${setRealityDestStatus}" != 'y' ]]; then
            exit 0
        fi
                echoContent yellow "url:https://${currentDomain}/s/default/${emailMd5}\n"
    fi
}

# Initialize the ServersName available to the client
initRealityClientServersName() {
    local realityDestDomainList=
    if [[ "${coreInstallType}" == "1" || "${selectCoreType}" == "1" ]]; then
        realityDestDomainList="download-installer.cdn.mozilla.net,addons.mozilla.org,s0.awsstatic.com,d1.awsstatic.com,images-na.ssl-images-amazon.com,m.media-amazon.com,player.live-video.net,one-piece.com,lol.secure.dyn.riotcdn.net,www.lovelive-anime.jp,academy.nvidia.com,dl.google.com,www.google-analytics.com,www.caltech.edu,www.calstatela.edu,www.suny.edu,www.suffolk.edu,www.python.org,vuejs-jp.org,vuejs.org,zh-hk.vuejs.org,react.dev,www.java.com,www.oracle.com,www.mysql.com,www.mongodb.com,redis.io,cname.vercel-dns.com,vercel-dns.com,www.swift.com,academy.nvidia.com,www.swift.com,www.cisco.com,www.asus.com,www.samsung.com,www.amd.com,www.umcg.nl,www.fom-international.com,www.u-can.co.jp,github.io"
    elif [[ "${coreInstallType}" == "2" || "${selectCoreType}" == "2" ]]; then
        realityDestDomainList="download-installer.cdn.mozilla.net,addons.mozilla.org,s0.awsstatic.com,d1.awsstatic.com,images-na.ssl-images-amazon.com,m.media-amazon.com,player.live-video.net,one-piece.com,www.lovelive-anime.jp,academy.nvidia.com,dl.google.com,www.google-analytics.com,www.python.org,vuejs-jp.org,vuejs.org,zh-hk.vuejs.org,react.dev,www.oracle.com,www.mysql.com,www.mongodb.com,cname.vercel-dns.com,vercel-dns.com,www.swift.com,academy.nvidia.com,www.swift.com,www.cisco.com,www.asus.com,www.samsung.com,www.amd.com,www.fom-international.com,github.io"
    fi
    if [[ -n "${realityServerName}" && -z "${lastInstallationConfig}" ]]; then
        if echo ${realityDestDomainList} | grep -q "${realityServerName}"; then
            read -r -p "Previous Reality server name found. Use it? [y/n]:" realityServerNameStatus
            if [[ "${realityServerNameStatus}" != "y" ]]; then
                realityServerName=
                realityDomainPort=
            fi
        else
            realityServerName=
            realityDomainPort=
        fi
    elif [[ -n "${realityServerName}" && -z "${lastInstallationConfig}" ]]; then
        realityServerName=
        realityDomainPort=
    fi

    if [[ -z "${realityServerName}" ]]; then
        if [[ -n "${domain}" ]]; then
            echo
            read -r -p "Use ${domain} as the Reality target domain? [y/n]:" realityServerNameCurrentDomainStatus
            if [[ "${realityServerNameCurrentDomainStatus}" == "y" ]]; then
                realityServerName="${domain}"
                if [[ "${selectCoreType}" == "1" ]]; then
                    if [[ -z "${subscribePort}" ]]; then
                        echo
                        installSubscribe
                        readNginxSubscribe
                        realityDomainPort="${subscribePort}"
                    else
                        realityDomainPort="${subscribePort}"
                    fi
                fi
                if [[ "${selectCoreType}" == "2" ]]; then
                    if [[ -z "${subscribePort}" ]]; then
                        echo
                        installSubscribe
                        readNginxSubscribe
                        realityDomainPort="${subscribePort}"
                    else
                        realityDomainPort="${subscribePort}"
                    fi
                fi
            fi
        fi
        if [[ -z "${realityServerName}" ]]; then
            realityDomainPort=443
                echoContent skyBlue "------------------------------------------------- ---------------"
                echoContent yellow "Online QR code: https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://${currentDomain}/s/default/${emailMd5}\n "
            echoContent green " ---> Abandon settings"
                    echoContent yellow "url:https://${currentDomain}/s/clashMetaProfiles/${emailMd5}\n"
            read -r -p "Enter target domain [Enter for random; default port 443]:" realityServerName
            if [[ -z "${realityServerName}" ]]; then
                count=$(echo ${realityDestDomainList} | awk -F',' '{print NF}')
                randomNum=$(randomNum 1 "${count}")

                realityServerName=$(echo "${realityDestDomainList}" | awk -F ',' -v randomNum="$randomNum" '{print $randomNum}')
            fi
            if echo "${realityServerName}" | grep -q ":"; then
                realityDomainPort=$(echo "${realityServerName}" | awk -F "[:]" '{print $2}')
                realityServerName=$(echo "${realityServerName}" | awk -F "[:]" '{print $1}')
            fi
        fi
    fi

    realityDestDomain="${realityServerName}:${realityDomainPort}"
    checkRealityDest
                    echoContent yellow "Online QR code: https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://${currentDomain}/s/clashMetaProfiles/${emailMd5}\n "
}
initXrayRealityPort() {
    if [[ -n "${xrayVLESSRealityPort}" && -z "${lastInstallationConfig}" ]]; then
        read -r -p "Read the last installation record. Do you want to use the port from the last installation? [y/n]:" historyRealityPortStatus
        if [[ "${historyRealityPortStatus}" == "y" ]]; then
            realityPort=${xrayVLESSRealityPort}
        fi
    elif [[ -n "${xrayVLESSRealityPort}" && -n "${lastInstallationConfig}" ]]; then
        realityPort=${xrayVLESSRealityPort}
    fi

    # todo Read the VLESS_TLS_Vision port and prompt whether to use it. There may be ambiguity here
    if [[ -z "${realityPort}" ]]; then
        #        if [[ -n "${port}" ]]; then
        #            if [[ "${realityPortTLSVisionStatus}" == "y" ]]; then
        #                realityPort=${port}
        #            fi
        #        fi
        #        if [[ -z "${realityPort}" ]]; then
    echoContent yellow "1.When http/1.1 is the first, trojan is available, and some gRPC clients are available [the client supports manual selection of alpn]"

            read -r -p "port:" realityPort
        if [[ -z "${realityPort}" ]]; then
            realityPort=$((RANDOM % 20001 + 10000))
        fi
        #        fi
        if [[ -n "${realityPort}" && "${xrayVLESSRealityPort}" == "${realityPort}" ]]; then
            handleXray stop
        else
            checkPort "${realityPort}"
        fi
    fi
    if [[ -z "${realityPort}" ]]; then
        initXrayRealityPort
    else
        allowPort "${realityPort}"
    echoContent yellow "2.When h2 is the first, gRPC is available, and some trojan clients are available [the client supports manual selection of alpn]"
    fi

}
initXrayXHTTPort() {
    if [[ -n "${xrayVLESSRealityXHTTPort}" && -z "${lastInstallationConfig}" ]]; then
        read -r -p "Previous installation port found. Use it? [y/n]:" historyXHTTPortStatus
        if [[ "${historyXHTTPortStatus}" == "y" ]]; then
            xHTTPort=${xrayVLESSRealityXHTTPort}
        fi
    elif [[ -n "${xrayVLESSRealityXHTTPort}" && -n "${lastInstallationConfig}" ]]; then
        xHTTPort=${xrayVLESSRealityXHTTPort}
    fi

    if [[ -z "${xHTTPort}" ]]; then

    echoContent yellow "3.If the client does not support manual alpn replacement, it is recommended to use this function to change the server alpn order to use the corresponding protocol"
        read -r -p "Port:" xHTTPort
        if [[ -z "${xHTTPort}" ]]; then
            xHTTPort=$((RANDOM % 20001 + 10000))
        fi
        if [[ -n "${xHTTPort}" && "${xrayVLESSRealityXHTTPort}" == "${xHTTPort}" ]]; then
            handleXray stop
        else
            checkPort "${xHTTPort}"
        fi
    fi
    if [[ -z "${xHTTPort}" ]]; then
        initXrayXHTTPort
    else
        allowPort "${xHTTPort}"
        allowPort "${xHTTPort}" "udp"
        echoContent yellow "1.Switch alpn h2 first"
    fi
}

#realitymanagement
manageReality() {
    readInstallProtocolType
    readConfigHostPathUUID
    readCustomPort
    readSingBoxConfig

    if ! echo "${currentInstallProtocolType}" | grep -q -E "7,|8," || [[ -z "${coreInstallType}" ]]; then
    echoContent red "\n================================================ ============ ====="
        exit 0
    fi

    if [[ "${coreInstallType}" == "1" ]]; then
        selectCustomInstallType=",7,"
        initXrayConfig custom 1 true
    elif [[ "${coreInstallType}" == "2" ]]; then
        if echo "${currentInstallProtocolType}" | grep -q ",7,"; then
            selectCustomInstallType=",7,"
        fi
        if echo "${currentInstallProtocolType}" | grep -q ",8,"; then
            selectCustomInstallType="${selectCustomInstallType},8,"
        fi
        initSingBoxConfig custom 1 true
    fi

    reloadCore
    subscribe false
}

installRealityScanner() {
    if [[ ! -f "/etc/v2ray-agent/xray/reality_scan/RealiTLScanner-linux-64" ]]; then
        version=$(curl -s https://api.github.com/repos/XTLS/RealiTLScanner/releases?per_page=1 | jq -r '.[]|.tag_name')
        wget -c -q -P /etc/v2ray-agent/xray/reality_scan/ "https://github.com/XTLS/RealiTLScanner/releases/download/${version}/RealiTLScanner-linux-64"
        chmod 655 /etc/v2ray-agent/xray/reality_scan/RealiTLScanner-linux-64
    fi
}
# reality scanner
realityScanner() {
    echoContent skyBlue "\nFunction 1/${totalProgress}: switch alpn"
    echoContent red "\n=============================================================="
        echoContent yellow "1.Switch alpn http/1.1 first"
        echoContent yellow "\n --->Ignore the risks and continue using"
    echoContent red "\n================================================ ================="
            echoContent yellow "\n ---> Fallback domain name: ${realityDestDomain}"
        echoContent yellow "#Notes"
    echoContent red "=============================================================="
    read -r -p "Select:" realityScannerStatus
    local type=
    if [[ "${realityScannerStatus}" == "1" ]]; then
        type=4
    elif [[ "${realityScannerStatus}" == "2" ]]; then
        type=6
    fi

        read -r -p "Some providers disallow scanning (for example Bandwagon). Continue at your own risk? [y/n]:" scanStatus

    if [[ "${scanStatus}" != "y" ]]; then
        exit 0
    fi

    publicIP=$(getPublicIP "${type}")
    echoContent yellow "IP:${publicIP}"
    if [[ -z "${publicIP}" ]]; then
    echoContent red "\n================================================ ================="
        exit 0
    fi

        read -r -p "Is the IP address correct? [y/n]:" ipStatus
    if [[ "${ipStatus}" == "y" ]]; then
        echoContent yellow "Input example: addons.mozilla.org\n"
        /etc/v2ray-agent/xray/reality_scan/RealiTLScanner-linux-64 -addr "${publicIP}" | tee /etc/v2ray-agent/xray/reality_scan/result.log
    else
    echoContent red "================================================== ==============="
    fi
}
# hysteriaadmin
manageHysteria() {
    echoContent skyBlue "\n========================== Generate key ================= =========\n"
    echoContent red "\n=============================================================="
    local hysteria2Status=
    if [[ -n "${singBoxConfigPath}" ]] && [[ -f "/etc/v2ray-agent/sing-box/conf/config/06_hysteria2_inbounds.json" ]]; then
    echoContent yellow "\n ---> Available client domain names: ${realityServerNames}\n"
            echoContent yellow "Please enter the port [Enter random 10000-30000]"
        echoContent yellow "\n ---> Port: ${realityPort}"
        echoContent yellow "1.Reinstall"
        hysteria2Status=true
    else
        echoContent yellow "2.Uninstall"
        echoContent yellow "3.Change configuration"
    fi

    echoContent red "=============================================================="
        read -r -p "Select:" installHysteria2Status
    if [[ "${installHysteria2Status}" == "1" ]]; then
        singBoxHysteria2Install
    elif [[ "${installHysteria2Status}" == "2" && "${hysteria2Status}" == "true" ]]; then
        unInstallSingBox hysteria2
    elif [[ "${installHysteria2Status}" == "3" && "${hysteria2Status}" == "true" ]]; then
        portHoppingMenu hysteria2
    fi
}

#tuicadmin
manageTuic() {
        echoContent skyBlue "\n====== Generate a domain name with fallback configuration , for example : [addons.mozilla.org:443] ======\n"
    echoContent red "\n=============================================================="
    local tuicStatus=
    if [[ -n "${singBoxConfigPath}" ]] && [[ -f "/etc/v2ray-agent/sing-box/conf/config/09_tuic_inbounds.json" ]]; then
        echoContent yellow "1.Installation"
        echoContent yellow "1.Reinstall"
        echoContent yellow "2.Uninstall"
        echoContent yellow "3.Port jump management"
        tuicStatus=true
    else
        echoContent yellow "4.core management"
        echoContent yellow "5.View log"
    fi

    echoContent red "=============================================================="
    read -r -p "Please select:" installTuicStatus
    if [[ "${installTuicStatus}" == "1" ]]; then
        singBoxTuicInstall
    elif [[ "${installTuicStatus}" == "2" && "${tuicStatus}" == "true" ]]; then
        unInstallSingBox tuic
    elif [[ "${installTuicStatus}" == "3" && "${tuicStatus}" == "true" ]]; then
        portHoppingMenu tuic
    fi
}
singBoxLog() {
    cat <<EOF >/etc/v2ray-agent/sing-box/conf/config/log.json
{
  "log": {
    "disabled": $1,
    "level": "debug",
    "output": "/etc/v2ray-agent/sing-box/conf/box.log",
    "timestamp": true
  }
}
EOF

    handleSingBox stop
    handleSingBox start
}

singBoxVersionManageMenu() {
        echoContent skyBlue "\n================ Configure serverNames available to the client ================\n"
    if [[ -z "${singBoxConfigPath}" ]]; then
        echoContent red " ---> Domain name cannot be empty"
        menu
        exit 0
    fi
    echoContent red "\n=============================================================="
        echoContent yellow "1.Installation"
        echoContent yellow "1.Reinstall"
        echoContent yellow "2.Uninstall"
        echoContent yellow "3.core management"
    echoContent yellow "=============================================================="
    local logStatus=
    if [[ -n "${singBoxConfigPath}" && -f "${singBoxConfigPath}log.json" && "$(jq -r .log.disabled "${singBoxConfigPath}log.json")" == "false" ]]; then
        echoContent yellow "4.View log"
        logStatus=true
    else
        echoContent yellow "1.Installation"
        logStatus=false
    fi

    echoContent yellow "1.Upgrade Hysteria"
    echoContent red "=============================================================="

        read -r -p "Select:" selectSingBoxType
    if [[ ! -f "${singBoxConfigPath}../box.log" ]]; then
        touch "${singBoxConfigPath}../box.log" >/dev/null 2>&1
    fi
    if [[ "${selectSingBoxType}" == "1" ]]; then
        installSingBox 1
        handleSingBox stop
        handleSingBox start
    elif [[ "${selectSingBoxType}" == "2" ]]; then
        handleSingBox stop
    elif [[ "${selectSingBoxType}" == "3" ]]; then
        handleSingBox start
    elif [[ "${selectSingBoxType}" == "4" ]]; then
        handleSingBox stop
        handleSingBox start
    elif [[ "${selectSingBoxType}" == "5" ]]; then
        singBoxLog ${logStatus}
        if [[ "${logStatus}" == "false" ]]; then
            tail -f "${singBoxConfigPath}../box.log"
        fi
    elif [[ "${selectSingBoxType}" == "6" ]]; then
        tail -f "${singBoxConfigPath}../box.log"
    fi
}

# main menu
menu() {
    cd "$HOME" || exit
    echoContent red "\n=============================================================="
        echoContent green " ---> WARP offload uninstall successful"
        echoContent green " ---> Added shunt successfully"
    echoContent green "Github：https://github.com/mack-a/v2ray-agent"
        echoContent green " ---> Add any door to divert successfully"
    showInstallStatus
    checkWgetShowProgress
            echoContent red " ---> Port cannot be empty"
    echoContent red "                                              "
    echoContent yellow "2.Close Hysteria"
    echoContent green "https://www.v2ray-agent.com/archives/1679975663984"
    echoContent yellow "3.Open Hysteria"
    echoContent green "https://www.v2ray-agent.com/archives/racknerdtao-can-zheng-li-nian-fu-10mei-yuan"
    echoContent yellow "4.Restart Hysteria"
    echoContent green "https://www.v2ray-agent.com/archives/186cee7b-9459-4e57-b9b2-b07a4f36931c"
    echoContent yellow "1.Upgrade Tuic"
    echoContent red "                                              "
    echoContent red "=============================================================="
    if [[ -n "${coreInstallType}" ]]; then
    echoContent yellow "2.Close Tuic"
    else
    echoContent yellow "3.Open Tuic"
    fi

    echoContent yellow "4.Restart Tuic"
        echoContent yellow "1.Reinstall"
        echoContent yellow "1.Installation"
    echoContent yellow "2.Install in any combination"
        echoContent yellow "3.Switch VLESS[XTLS]"

    echoContent skyBlue "\nProgress$1/${totalProgress}: Initializing Xray-core reality configuration"
        echoContent yellow "3.Switch Trojan[XTLS]"
    echoContent yellow "4.Hysteria Management"
    echoContent yellow "5.REALITY Management"
    echoContent yellow "6.Tuic Management"
    echoContent yellow "7.Account management"
    echoContent yellow "8.Change the camouflage station"
    echoContent yellow "9.Update certificate"
    echoContent yellow "10.Change CDN node"
    echoContent skyBlue "\nProgress 1/1: reality management"
    echoContent yellow "11.Diversion tool"
    echoContent yellow "12.Add new port"
    echoContent yellow "13.BT download management"
    echoContent skyBlue "\nProgress 1/1: Hysteria Management"
    echoContent yellow "14.Switch alpn"
    echoContent red "=============================================================="
    mkdirTools
    aliasInstall
    read -r -p "Please select:" selectInstallType
    case ${selectInstallType} in
    1)
        selectCoreInstall
        ;;
    2)
        selectCoreInstall
        ;;
    3)
        selectCoreInstall
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
        manageCDN 1
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
    20)
        unInstall 1
        ;;
    esac
}
cronFunction
menu
