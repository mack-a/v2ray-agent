#!/usr/bin/env bash
# detection area
# -------------------------------------------------- ------------
# check system
export LANG=en_US.UTF-8

echoContent() {
case $1 in
#red _
"red")
# shellcheck disable=SC2154
${echoType} "\033[31m${printN}$2 \033[0m"
;;
#skyblue _ _
"skyBlue")
${echoType} "\033[1;36m${printN}$2 \033[0m"
;;
#green _
"green")
${echoType} "\033[32m${printN}$2 \033[0m"
;;
#white _
"white")
${echoType} "\033[37m${printN}$2 \033[0m"
;;
"magenta")
${echoType} "\033[31m${printN}$2 \033[0m"
;;
#yellow _
"yellow")
${echoType} "\033[33m${printN}$2 \033[0m"
;;
esac
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

elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc /version" ]]; then
release="debian"
installType='apt -y install'
upgrade="apt update"
updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
removeType='apt -y autoremove'

elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc /version" ]]; then
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
echoContent red "\nThis script does not support this system , please feedback the log below to the developer \n"
echoContent yellow "$(cat /etc/issue)"
echoContent yellow "$(cat /proc/version)"
exit 0
fi
}

# check CPU provider
checkCPUVendor() {
if [[ -n $(which uname) ]]; then
if [[ "$(uname)" == "Linux" ]]; then
case "$(uname -m)" in
'amd64' | 'x86_64')
xrayCoreCPUVendor="Xray-linux-64"
v2rayCoreCPUVendor="v2ray-linux-64"
hysteriaCoreCPUVendor="hysteria-linux-amd64"
;;
'armv8' | 'aarch64')
xrayCoreCPUVendor="Xray-linux-arm64-v8a"
v2rayCoreCPUVendor="v2ray-linux-arm64-v8a"
hysteriaCoreCPUVendor="hysteria-linux-arm64"
;;
*)
echo " This CPU architecture is not supported --->"
exit 1
;;
esac
fi
else
echoContent red " This CPU architecture cannot be recognized , the default is amd64 , x86_64 --->"
xrayCoreCPUVendor="Xray-linux-64"
v2rayCoreCPUVendor="v2ray-linux-64"
fi
}

#Initialize global variables
initVar() {
installType='yum -y install'
removeType='yum -y remove'
upgrade="yum -y update"
echoType='echo -e'

#core supported cpu version
xrayCoreCPUVendor=""
v2rayCoreCPUVendor=""
hysteriaCoreCPUVendor=""

# domain name
domain=

address of the CDN node
add=

#Installation progress _
totalProgress=1

# 1.xray-core installation
# 2.v2ray-core installation
# 3.v2ray-core[xtls] installation
coreInstallType=

#core installation path
# coreInstallPath=

#v2ctl Path
ctlPath=
# 1. Install all
# 2. Personalized installation
#v2rayAgentInstallType=

#Current personalized installation method 01234
currentInstallProtocolType=

#The order of the current alpn
currentAlpn=

# pre- type
frontingType=

#Selected personalized installation method
selectCustomInstallType=

# The paths of v2ray-core and xray-core configuration files
configPath=

# Path to the hysteria configuration file
hysteriaConfigPath=

#path of the configuration file
currentPath=

#The host of the configuration file
currentHost=

#The core type selected during installation
selectCoreType=

#Default core version _
v2rayCoreVersion=

#random path
customPath=

# centos version
centosVersion=

# UUID
currentUUID=

# previousClients
previousClients=

localIP=

#Integrated update certificate logic no longer uses a separate script --RenewTLS
renewTLS=$1

# Number of attempts after tls installation failed
installTLSCount=

# BTPanel state
# 	BTPanelStatus=

# nginx configuration file path
nginxConfigPath=/etc/nginx/conf.d/

#Is it a preview version
prereleaseStatus=false

# ssl type
sslType=

# ssl mailbox
sslEmail=

# check days
sslRenewalDays=90

# dns ssl status
dnsSSLStatus=

# dns tls domain
dnsTLSDomain=

#Whether the domain name installs a wildcard certificate through dns
installDNSACMEStatus=

#custom port
customPort=

# hysteria port
hysteriaPort=

# hysteria protocol
hysteriaProtocol=

# hysteria delay
hysteriaLag=

# hysteria downlink speed
hysteriaClientDownloadSpeed=

# hysteria uplink speed
hysteriaClientUploadSpeed=

}

#Read tls certificate details
readAcmeTLS() {
if [[ -n "${currentHost}" ]]; then
dnsTLSDomain=$(echo "${currentHost}" | awk -F "[.]" '{print $(NF-1)"."$NF}')
fi
if [[ -d "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc" && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.key " && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.cer" ]]; then
installDNSACMEStatus=true
fi
}
#Read the default custom port
readCustomPort() {
if [[ -n "${configPath}" ]]; then
local port=
port=$(jq -r .inbounds[0].port "${configPath}${frontingType}.json")
if [[ "${port}" != "443" ]]; then
customPort=${port}
fi
fi
}
# detect installation method
readInstallType() {
coreInstallType=
configPath=
hysteriaConfigPath=

# 1. Detect installation directory
if [[ -d "/etc/v2ray-agent" ]]; then
#Detect installation method v2ray-core
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
#Detect xray-core here
if [[ -d "/etc/v2ray-agent/xray/conf" ]] && [[ -f "/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json" || -f "/etc/v2ray- agent/xray/conf/02_trojan_TCP_inbounds.json" ]]; then
#xray-core
configPath=/etc/v2ray-agent/xray/conf/
ctlPath=/etc/v2ray-agent/xray/xray
coreInstallType=1
fi
fi

if [[ -d "/etc/v2ray-agent/hysteria" && -f "/etc/v2ray-agent/hysteria/hysteria" ]]; then
#Check hysteria here
if [[ -d "/etc/v2ray-agent/hysteria/conf" ]] && [[ -f "/etc/v2ray-agent/hysteria/conf/config.json" ]] && [[ -f "/etc /v2ray-agent/hysteria/conf/client_network.json" ]]; then
hysteriaConfigPath=/etc/v2ray-agent/hysteria/conf/
fi
fi

fi
}

# read protocol type
readInstallProtocolType() {
currentInstallProtocolType=

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
done < <(find ${configPath} -name "*inbounds.json" | awk -F "[.]" '{print $1}')

if [[ -n "${hysteriaConfigPath}" ]]; then
currentInstallProtocolType=${currentInstallProtocolType}'6'
fi
}

#Check if pagoda is installed
checkBTPanel() {
if pgrep -f "BT-Panel"; then
nginxConfigPath=/www/server/panel/vhost/nginx/
# 		BTPanelStatus=true
fi
}
#Read the order of the current alpn
readInstallAlpn() {
if [[ -n ${currentInstallProtocolType} ]]; then
local alpn
alpn=$(jq -r .inbounds[0].streamSettings.tlsSettings.alpn[0] ${configPath}${frontingType}.json)
if [[ -n ${alpn} ]]; then
currentAlpn=${alpn}
fi
fi
}

# check firewall
allowPort() {
local type=$2
if [[ -z ${type} ]]; then
type=tcp
fi
#If firewall is enabled, add the corresponding open port
if systemctl status netfilter-persistent 2>/dev/null | grep -q "active (exited)"; then
local updateFirewalldStatus=
if ! iptables -L | grep -q "$1(mack-a)"; then
updateFirewalldStatus=true
iptables -I INPUT -p ${type} --dport "$1" -m comment --comment "allow $1(mack-a)" -j ACCEPT
fi

if echo "${updateFirewalldStatus}" | grep -q "true"; then
netfilter-persistent save
fi
elif systemctl status ufw 2>/dev/null | grep -q "active (exited)"; then
if ufw status | grep -q "Status: active"; then
if ! ufw status | grep -q "$1"; then
sudo ufw allow "$1/${type}"
checkUFWAllowPort "$1"
fi
fi

elif systemctl status firewalld 2>/dev/null | grep -q "active (running)"; then
local updateFirewalldStatus=
if ! firewall-cmd --list-ports --permanent | grep -qw "$1/${type}"; then
updateFirewalldStatus=true
firewall-cmd --zone=public --add-port="$1/${type}" --permanent
checkFirewalldAllowPort "$1"
fi

if echo "${updateFirewalldStatus}" | grep -q "true"; then
firewall-cmd --reload
fi
fi
}

#Check the occupancy of ports 80 and 443
checkPortUsedStatus() {
if lsof -i tcp:80 | grep -q LISTEN; then
echoContent red "\n ---> Port 80 is occupied, please close it manually and install it \n"
lsof -i tcp:80 | grep LISTEN
exit 0
fi

if lsof -i tcp:443 | grep -q LISTEN; then
echoContent red "\n ---> Port 443 is occupied, please close it manually and install it \n"
lsof -i tcp:80 | grep LISTEN
exit 0
fi
}

#Output ufw port open status
checkUFWAllowPort() {
if ufw status | grep -q "$1"; then
echoContent green " ---> $1 port successfully opened "
else
echoContent red " ---> Failed to open port $1 "
exit 0
fi
}

#Output firewall - cmd port open status
checkFirewalldAllowPort() {
if firewall-cmd --list-ports --permanent | grep -q "$1"; then
echoContent green " ---> $1 port successfully opened "
else
echoContent red " ---> Failed to open port $1 "
exit 0
fi
}

#Read hysteria network environment
readHysteriaConfig() {
if [[ -n "${hysteriaConfigPath}" ]]; then
hysteriaLag=$(jq -r .hysteriaLag <"${hysteriaConfigPath}client_network.json")
hysteriaClientDownloadSpeed=$(jq -r .hysteriaClientDownloadSpeed <"${hysteriaConfigPath}client_network.json")
hysteriaClientUploadSpeed=$(jq -r .hysteriaClientUploadSpeed <"${hysteriaConfigPath}client_network.json")
hysteriaPort=$(jq -r .listen <"${hysteriaConfigPath}config.json" | awk -F "[:]" '{print $2}')
hysteriaProtocol=$(jq -r .protocol <"${hysteriaConfigPath}config.json")
fi
}
#Check file directory and path path
readConfigHostPathUUID() {
currentPath=
currentDefaultPort=
currentUUID=
currentHost=
currentPort=
currentAdd=
#read path _
if [[ -n "${configPath}" ]]; then
local fallback
fallback=$(jq -r -c '.inbounds[0].settings.fallbacks[]|select(.path)' ${configPath}${frontingType}.json | head -1)

local path
path=$(echo "${fallback}" | jq -r .path | awk -F "[/]" '{print $2}')

if [[ $(echo "${fallback}" | jq -r .dest) == 31297 ]]; then
currentPath=$(echo "${path}" | awk -F "[w][s]" '{print $1}')
elif [[ $(echo "${fallback}" | jq -r .dest) == 31298 ]]; then
currentPath=$(echo "${path}" | awk -F "[t][c][p]" '{print $1}')
elif [[ $(echo "${fallback}" | jq -r .dest) == 31299 ]]; then
currentPath=$(echo "${path}" | awk -F "[v][w][s]" '{print $1}')
fi
#Try to read alpn h2 Path

if [[ -z "${currentPath}" ]]; then
dest=$(jq -r -c '.inbounds[0].settings.fallbacks[]|select(.alpn)|.dest' ${configPath}${frontingType}.json | head -1)
if [[ "${dest}" == "31302" || "${dest}" == "31304" ]]; then

if grep -q "trojangrpc {" <${nginxConfigPath}alone.conf; then
currentPath=$(grep "trojangrpc {" <${nginxConfigPath}alone.conf | awk -F "[/]" '{print $2}' | awk -F "[t][r][o][j][ a][n]" '{print $1}')
elif grep -q "grpc {" <${nginxConfigPath}alone.conf; then
currentPath=$(grep "grpc {" <${nginxConfigPath}alone.conf | head -1 | awk -F "[/]" '{print $2}' | awk -F "[g][r][p] [c]" '{print $1}')
fi
fi
fi

local defaultPortFile=
defaultPortFile=$(find ${configPath}* | grep "default")

if [[ -n "${defaultPortFile}" ]]; then
currentDefaultPort=$(echo "${defaultPortFile}" | awk -F [_] '{print $4}')
else
currentDefaultPort=$(jq -r .inbounds[0].port ${configPath}${frontingType}.json)
fi

fi
if [[ "${coreInstallType}" == "1" ]]; then
currentHost=$(jq -r .inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile ${configPath}${frontingType}.json | awk -F '[t][l][s][/] ' '{print $2}' | awk -F '[.][c][r][t]' '{print $1}')
currentUUID=$(jq -r .inbounds[0].settings.clients[0].id ${configPath}${frontingType}.json)
currentAdd=$(jq -r .inbounds[0].settings.clients[0].add ${configPath}${frontingType}.json)
if [[ "${currentAdd}" == "null" ]]; then
currentAdd=${currentHost}
fi
currentPort=$(jq .inbounds[0].port ${configPath}${frontingType}.json)

elif [[ "${coreInstallType}" == "2" ]]; then
currentHost=$(jq -r .inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile ${configPath}${frontingType}.json | awk -F '[t][l][s][/] ' '{print $2}' | awk -F '[.][c][r][t]' '{print $1}')
currentAdd=$(jq -r .inbounds[0].settings.clients[0].add ${configPath}${frontingType}.json)

if [[ "${currentAdd}" == "null" ]]; then
currentAdd=${currentHost}
fi
currentUUID=$(jq -r .inbounds[0].settings.clients[0].id ${configPath}${frontingType}.json)
currentPort=$(jq .inbounds[0].port ${configPath}${frontingType}.json)
fi
}

#Status display
showInstallStatus() {
if [[ -n "${coreInstallType}" ]]; then
if [[ "${coreInstallType}" == 1 ]]; then
if [[ -n $(pgrep -f xray/xray) ]]; then
echoContent yellow "\nCore : Xray-core[ running ] "
else
echoContent yellow "\nCore : Xray-core[ not running ] "
fi

elif [[ "${coreInstallType}" == 2 || "${coreInstallType}" == 3 ]]; then
if [[ -n $(pgrep -f v2ray/v2ray) ]]; then
echoContent yellow "\ ncore: v2ray- core [ running ]"
else
echoContent yellow "\ ncore: v2ray- core [ not running ]"
fi
fi
# read protocol type
readInstallProtocolType

if [[ -n ${currentInstallProtocolType} ]]; then
echoContent yellow " Protocol installed : \c"
fi
if echo ${currentInstallProtocolType} | grep -q 0; then
if [[ "${coreInstallType}" == 2 ]]; then
echoContent yellow "VLESS+TCP[TLS] \c"
else
echoContent yellow "VLESS+TCP[TLS/XTLS]\c"
fi
fi

if echo ${currentInstallProtocolType} | grep -q trojan; then
if [[ "${coreInstallType}" == 1 ]]; then
echoContent yellow "Trojan+TCP[TLS/XTLS] \c"
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
fi
}

# Clean up old residue
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
checkBTPanel
# -------------------------------------------------- ------------

# Initialize the installation directory
mkdirTools() {
mkdir -p /etc/v2ray-agent/tls
mkdir -p /etc/v2ray-agent/subscribe
mkdir -p /etc/v2ray-agent/subscribe_tmp
mkdir -p /etc/v2ray-agent/v2ray/conf
mkdir -p /etc/v2ray-agent/v2ray/tmp
mkdir -p /etc/v2ray-agent/xray/conf
mkdir -p /etc/v2ray-agent/xray/tmp
mkdir -p /etc/v2ray-agent/trojan
mkdir -p /etc/v2ray-agent/hysteria/conf
mkdir -p /etc/systemd/system/
mkdir -p /tmp/v2ray-agent-tls/
}

#Install toolkit
installTools() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Install tool "
#Fix ubuntu individual system problems
if [[ "${release}" == "ubuntu" ]]; then
dpkg --configure -a
fi

if [[ -n $(pgrep -f "apt") ]]; then
pgrep -f apt | xargs kill -9
fi

echoContent green " ---> Check and install updates【The new machine will be very slow, if there is no response for a long time, please stop it manually and execute it again】 "

${upgrade} >/etc/v2ray-agent/install.log 2>&1
if grep <"/etc/v2ray-agent/install.log" -q "changed"; then
${updateReleaseInfoChange} >/dev/null 2>&1
fi

if [[ "${release}" == "centos" ]]; then
rm -rf /var/run/yum.pid
${installType} epel-release >/dev/null 2>&1
fi

# 	[[ -z `find /usr/bin /usr/sbin |grep -v grep|grep -w curl` ]]

if ! find /usr/bin /usr/sbin | grep -q -w wget; then
echoContent green " ---> install wget"
${installType} wget >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w curl; then
echoContent green " ---> install curl"
${installType} curl >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w unzip; then
echoContent green " ---> install unzip"
${installType} unzip >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w socat; then
echoContent green " ---> install socat"
${installType} socat >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w tar; then
echoContent green " ---> install tar"
${installType} tar >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w cron; then
echoContent green " ---> install crontabs"
if [[ "${release}" == "ubuntu" ]] || [[ "${release}" == "debian" ]]; then
${installType} cron >/dev/null 2>&1
else
${installType} crontabs >/dev/null 2>&1
fi
fi
if ! find /usr/bin /usr/sbin | grep -q -w jq; then
echoContent green " ---> install jq"
${installType} jq >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w binutils; then
echoContent green " ---> install binutils"
${installType} binutils >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w ping6; then
echoContent green " ---> install ping6"
${installType} inetutils-ping >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w qrencode; then
echoContent green " ---> install qrencode"
${installType} qrencode >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w sudo; then
echoContent green " ---> install sudo"
${installType} sudo >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w lsb-release; then
echoContent green " ---> install lsb-release"
${installType} lsb-release >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w lsof; then
echoContent green " ---> install lsof"
${installType} lsof >/dev/null 2>&1
fi

if ! find /usr/bin /usr/sbin | grep -q -w dig; then
echoContent green " ---> install dig"
if echo "${installType}" | grep -q -w "apt"; then
${installType} dnsutils >/dev/null 2>&1
elif echo "${installType}" | grep -q -w "yum"; then
${installType} bind-utils >/dev/null 2>&1
fi
fi

#Detect the nginx version and provide the option to uninstall it

if ! find /usr/bin /usr/sbin | grep -q -w nginx; then
echoContent green "---> Install nginx"
installNginxTools
else
nginxVersion=$(nginx -v 2>&1)
nginxVersion=$(echo "${nginxVersion}" | awk -F "[n][g][i][n][x][/]" '{print $2}' | awk -F "[.]" '{print $2}')
if [[ ${nginxVersion} -lt 14 ]]; then
read -r -p " Read that the current Nginx version does not support gRPC , which will cause the installation to fail. Whether to uninstall Nginx and reinstall it ? [y/n]: " unInstallNginxStatus
if [[ "${unInstallNginxStatus}" == "y" ]]; then
${removeType} nginx >/dev/null 2>&1
echoContent yellow " ---> nginx uninstall complete "
echoContent green "---> Install nginx"
installNginxTools >/dev/null 2>&1
else
exit 0
fi
fi
fi
if ! find /usr/bin /usr/sbin | grep -q -w semanage; then
echoContent green " ---> install semanage"
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

if [[ ! -d "$HOME/.acme.sh" ]] || [[ -d "$HOME/.acme.sh" && -z $(find "$HOME/.acme.sh/acme.sh ") ]]; then
echoContent green " ---> install acme.sh"
curl -s https://get.acme.sh | sh >/etc/v2ray-agent/tls/acme.log 2>&1

if [[ ! -d "$HOME/.acme.sh" ]] || [[ -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
echoContent red "acme installation failed --->"
tail -n 100 /etc/v2ray-agent/tls/acme.log
echoContent yellow " Troubleshooting :"
echoContent red " 1. Failed to get the Github file , please wait for Github to recover and try again, the recovery progress can be viewed at [https://www.githubstatus.com/]"
echoContent red "2.acme.sh script has a bug , please check [https://github.com/acmesh-official/acme.sh] issues"
echoContent red " 3. For a pure IPv6 machine, please set up NAT64 and execute the following command "
echoContent skyBlue "echo -e \"nameserver 2001:67c:2b0::4\\\nnameserver 2001:67c:2b0::6\" >> /etc/resolv.conf"
exit 0
fi
fi
}

#Install Nginx _
installNginxTools() {

if [[ "${release}" == "debian" ]]; then
sudo apt install gnupg2 ca-certificates lsb-release -y >/dev/null 2>&1
echo "deb http://nginx.org/packages/mainline/debian $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null 2>&1
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx >/dev/null 2> &1
curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key >/dev/null 2>&1
# gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
sudo mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc
sudo apt update >/dev/null 2>&1

elif [[ "${release}" == "ubuntu" ]]; then
sudo apt install gnupg2 ca-certificates lsb-release -y >/dev/null 2>&1
echo "deb http://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null 2>&1
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx >/dev/null 2> &1
curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key >/dev/null 2>&1
# gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
sudo mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc
sudo apt update >/dev/null 2>&1

elif [[ "${release}" == "centos" ]]; then
${installType} yum-utils >/dev/null 2>&1
cat <<EOF>/etc/yum.repos.d/nginx.repo
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

#install warp _
installWarp() {
${installType} gnupg2 -y >/dev/null 2>&1
if [[ "${release}" == "debian" ]]; then
curl -s https://pkg.cloudflareclient.com/pubkey.gpg | sudo apt-key add ->/dev/null 2>&1
echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null 2>&1
sudo apt update >/dev/null 2>&1

elif [[ "${release}" == "ubuntu" ]]; then
curl -s https://pkg.cloudflareclient.com/pubkey.gpg | sudo apt-key add ->/dev/null 2>&1
echo "deb http://pkg.cloudflareclient.com/ focal main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null 2>&1
sudo apt update >/dev/null 2>&1

elif [[ "${release}" == "centos" ]]; then
${installType} yum-utils >/dev/null 2>&1
sudo rpm -ivh "http://pkg.cloudflareclient.com/cloudflare-release-el${centosVersion}.rpm" >/dev/null 2>&1
fi

echoContent green "---> Install WARP"
${installType} cloudflare-warp >/dev/null 2>&1
if [[ -z $(which warp-cli) ]]; then
echoContent red "---> Failed to install WARP "
exit 0
fi
systemctl enable warp-svc
warp-cli --accept-tos register
warp-cli --accept-tos set-mode proxy
warp-cli --accept-tos set-proxy-port 31303
warp-cli --accept-tos connect
warp-cli --accept-tos enable-always-on

# 	if [[]];then
#fi 	_
# todo curl --socks5 127.0.0.1:31303 https://www.cloudflare.com/cdn-cgi/trace
# systemctl daemon-reload
# systemctl enable cloudflare-warp
}
#Initialize Nginx application certificate configuration
initTLSNginxConfig() {
handle Nginx stop
echoContent skyBlue "\nProgress $ 1/${totalProgress}: Initialize Nginx application certificate configuration "
if [[ -n "${currentHost}" ]]; then
echo
read -r -p " read the last installation record, whether to use the domain name of the last installation ? [y/n]: "historyDomainStatus
if [[ "${historyDomainStatus}" == "y" ]]; then
domain=${currentHost}
echoContent yellow "\n ---> domain name : ${domain}"
else
echo
echoContent yellow " Please enter the domain name to be configured Example : www.v2ray-agent.com --->"
read -r -p " domain name :" domain
fi
else
echo
echoContent yellow " Please enter the domain name to be configured Example : www.v2ray-agent.com --->"
read -r -p " domain name :" domain
fi

if [[ -z ${domain} ]]; then
echoContent red "The domain name cannot be empty --->"
initTLSNginxConfig 3
else
dnsTLSDomain=$(echo "${domain}" | awk -F "[.]" '{print $(NF-1)"."$NF}')
customPortFunction
local port=80
if [[ -n "${customPort}" ]]; then
port=${customPort}
fi

#Modify configuration
touch ${nginxConfigPath}alone.conf
cat <<EOF >${nginxConfigPath}alone.conf
server {
listen ${port};
listen [::]:${port};
server_name ${domain};
root /usr/share/nginx/html;
location ~/.well-known {
    	allow all;
}
location /test {
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
fi

readAcmeTLS
}

#Modify nginx redirection configuration
updateRedirectNginxConf() {

# 	if [[ ${BTPanelStatus} == "true" ]]; then
#
# 		cat <<EOF >${nginxConfigPath}alone.conf
# server {
# 		listen 127.0.0.1:31300;
# 		server_name_;
# 		return 403;
# }
#EOF
#
# 	elif [[ -n "${customPort}" ]]; then
# 		cat <<EOF >${nginxConfigPath}alone.conf
# server {
# 		listen 127.0.0.1:31300;
# 		server_name_;
# 		return 403;
# }
#EOF
#fi 	_
local redirectDomain=${domain}
if [[ -n "${customPort}" ]]; then
redirectDomain=${domain}:${customPort}
fi
cat <<EOF >${nginxConfigPath}alone.conf
server {
	listen 80;
	server_name ${domain};
	return 302 https://${redirectDomain};
}
server {
		listen 127.0.0.1:31300;
		server_name_;
		return 403;
}
EOF

if echo "${selectCustomInstallType}" | grep -q 2 && echo "${selectCustomInstallType}" | grep -q 5 || [[ -z "${selectCustomInstallType}" ]]; then

cat <<EOF >>${nginxConfigPath}alone.conf
server {
	listen 127.0.0.1:31302 http2 so_keepalive=on;
	server_name ${domain};
	root /usr/share/nginx/html;

	client_header_timeout 1071906480m;
keepalive_timeout 1071906480m;

	location /s/ {
    	add_header Content-Type text/plain;
    	alias /etc/v2ray-agent/subscribe/;
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
	root /usr/share/nginx/html;
	location /s/ {
    		add_header Content-Type text/plain;
    		alias /etc/v2ray-agent/subscribe/;
}
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
}
EOF

elif echo "${selectCustomInstallType}" | grep -q 2 || [[ -z "${selectCustomInstallType}" ]]; then

cat <<EOF >>${nginxConfigPath}alone.conf
server {
	listen 127.0.0.1:31302 http2;
	server_name ${domain};
	root /usr/share/nginx/html;
	location /s/ {
    		add_header Content-Type text/plain;
    		alias /etc/v2ray-agent/subscribe/;
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
	root /usr/share/nginx/html;
	location /s/ {
    		add_header Content-Type text/plain;
    		alias /etc/v2ray-agent/subscribe/;
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
	root /usr/share/nginx/html;
	location /s/ {
		add_header Content-Type text/plain;
		alias /etc/v2ray-agent/subscribe/;
	}
	location / {
		add_header Strict-Transport-Security "max-age=15552000; preload" always;
	}
}
EOF

}

# check ip
checkIP() {
echoContent skyBlue "\n ---> check the domain name ip "
local checkDomain=${domain}
if [[ -n "${customPort}" ]]; then
checkDomain="http://${domain}:${customPort}"
fi
localIP=$(curl -s -m 2 "${checkDomain}/ip")

handle Nginx stop
if [[ -z ${localIP} ]] || ! echo "${localIP}" | sed '1{s/[^(]*(//;s/).*//;q}' | grep -q '\.' && ! echo "${localIP}" | sed '1{s/[^(]*(//;s/).*//;q}' | grep -q ':'; then
echoContent red "\n ---> The ip of the current domain name is not detected "
echoContent skyBlue " ---> Please perform the following checks in order "
echoContent yellow " ---> 1. Check whether the domain name is written correctly "
echoContent yellow " ---> 2. Check whether the dns resolution of the domain name is correct "
echoContent yellow " ---> 3. If the resolution is correct , please wait for dns to take effect, which is expected to take effect within three minutes "
echoContent yellow " ---> 4. If there is a problem with starting Nginx , please start nginx manually to check the error. If you can't handle it, please file issues"
echoContent yellow " ---> 5. Error log : ${localIP}"
echo
echoContent skyBlue " ---> If the above settings are correct, please reinstall the pure system and try again "

if [[ -n ${localIP} ]]; then
echoContent yellow " ---> Check the return value is abnormal, it is recommended to manually uninstall nginx and re- execute the script "
fi
local portFirewallPortStatus="443 , 80"

if [[ -n "${customPort}" ]]; then
portFirewallPortStatus="${customPort}"
fi
echoContent red " ---> Please check whether firewall rules are open ${portFirewallPortStatus}\n"
read -r -p " Do you want to open ${portFirewallPortStatus} port by modifying firewall rules through script? [y/n]:" allPortFirewallStatus

if [[ ${allPortFirewallStatus} == "y" ]]; then
if [[ -n "${customPort}" ]]; then
allowPort "${customPort}"
else
allowPort 80
allowPort 443
fi

handle Nginx start
checkIP
else
exit 0
fi
else
if echo "${localIP}" | awk -F "[,]" '{print $2}' | grep -q "." || echo "${localIP}" | awk -F "[,]" '{ print $2}' | grep -q ":"; then
echoContent red "\n ---> Multiple IPs detected , please confirm whether to close cloudflare 's cloud "
echoContent yellow " ---> close the cloud and wait for three minutes and try again "
echoContent yellow " ---> The detected ip is as follows : [${localIP}]"
exit 0
fi
echoContent green " ---> The current domain name ip is : [${localIP}]"
fi

}
#custom email _
customSSLEmail() {
if echo "$1" | grep -q "validate email"; then
read -r -p " Do you want to re- enter the email address [y/n]:" sslEmailStatus
if [[ "${sslEmailStatus}" == "y" ]]; then
sed '/ACCOUNT_EMAIL/d' /root/.acme.sh/account.conf >/root/.acme.sh/account.conf_tmp && mv /root/.acme.sh/account.conf_tmp /root/.acme.sh /account.conf
else
exit 0
fi
fi

if [[ -d "/root/.acme.sh" && -f "/root/.acme.sh/account.conf" ]]; then
if ! grep -q "ACCOUNT_EMAIL" <"/root/.acme.sh/account.conf" && ! echo "${sslType}" | grep -q "letsencrypt"; then
read -r -p " Please enter your email address :" sslEmail
if echo "${sslEmail}" | grep -q "@"; then
echo "ACCOUNT_EMAIL='${sslEmail}'" >>/root/.acme.sh/account.conf
echoContent green "---> Added successfully "
else
echoContent yellow " Please re-enter the correct email format [ example : username@example.com]"
customSSLEmail
fi
fi
fi

}
#Select ssl installation type _
switchSSLType() {
if [[ -z "${sslType}" ]]; then
echoContent red "\n=============================================== =================="
echoContent yellow "1.letsencrypt[ default ]"
echoContent yellow "2.zerossl"
echoContent yellow "3.buypass[ Does not support DNS application ]"
echoContent red "================================================ ================"
read -r -p " Please select [ Enter ] to use the default :" selectSSLType
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

#Select the acme installation certificate method
selectAcmeInstallSSL() {
local installSSLIPv6=
if echo "${localIP}" | grep -q ":"; then
installSSLIPv6="--listen-v6"
fi
echo
if [[ -n "${customPort}" ]]; then
if [[ "${selectSSLType}" == "3" ]]; then
echoContent red " ---> buypass does not support free wildcard certificates "
echo
exit
fi
dnsSSLStatus=true
else
if [[ -z "${dnsSSLStatus}" ]]; then
read -r -p " Whether to use DNS to apply for a certificate, if you will not use DNS to apply for a certificate, please enter n[y/n]:" installSSLDNStatus

if [[ ${installSSLDNStatus} == 'y' ]]; then
dnsSSLStatus=true
else
dnsSSLStatus=false
fi
fi

fi
acmeInstallSSL

readAcmeTLS
}

#Install the SSL certificate
acmeInstallSSL() {
if [[ "${dnsSSLStatus}" == "true" ]]; then

sudo "$HOME/.acme.sh/acme.sh" --issue -d "*.${dnsTLSDomain}" -d "${dnsTLSDomain}" --dns --yes-I-know-dns-manual- mode-enough-go-ahead-please -k ec-256 --server "${sslType}" ${installSSLIPv6} 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/ null

local txtValue=
txtValue=$(tail -n 10 /etc/v2ray-agent/tls/acme.log | grep "TXT value" | awk -F "'" '{print $2}')
if [[ -n "${txtValue}" ]]; then
echoContent green "---> Please add DNS TXT record manually "
echoContent yellow " ---> Please refer to this tutorial for how to add , https://github.com/mack-a/v2ray-agent/blob/master/documents/dns_txt.md"
echoContent yellow " ---> Install wildcard certificates on multiple machines with one domain name , please add multiple TXT records, no need to modify previously added TXT records "
echoContent green " ---> name : _acme-challenge"
echoContent green " ---> value : ${txtValue}"
echoContent yellow " ---> Please wait for 1-2 minutes after the addition is complete "
echo
read -r -p " Is the addition completed [y/n]:" addDNSTXTRecordStatus
if [[ "${addDNSTXTRecordStatus}" == "y" ]]; then
local txtAnswer=
txtAnswer=$(dig @1.1.1.1 +nocmd "_acme-challenge.${dnsTLSDomain}" txt +noall +answer | awk -F "[\"]" '{print $2}')
if echo "${txtAnswer}" | grep -q "^${txtValue}"; then
echoContent green " ---> TXT record verification passed "
echoContent green "---> Certificate generation "
if [[ -n "${installSSLIPv6}" ]]; then
sudo "$HOME/.acme.sh/acme.sh" --renew -d "*.${dnsTLSDomain}" -d "${dnsTLSDomain}" --yes-I-know-dns-manual-mode-enough -go-ahead-please --ecc --server "${sslType}" ${installSSLIPv6} 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
else
sudo "$HOME/.acme.sh/acme.sh" --renew -d "*.${dnsTLSDomain}" -d "${dnsTLSDomain}" --yes-I-know-dns-manual-mode-enough -go-ahead-please --ecc --server "${sslType}" 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
fi
else
echoContent red "---> Authentication failed, please wait 1-2 minutes and try again "
acmeInstallSSL
fi
else
echoContent red " ---> give up "
exit 0
fi
fi
else
echoContent green "---> Certificate generation "
sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 --server "${sslType}" ${installSSLIPv6} 2>&1 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
fi
}
#custom port
customPortFunction() {
local historyCustomPortStatus=
local showPort=
if [[ -n "${customPort}" || -n "${currentPort}" ]]; then
echo
read -r -p " Read the port of the last installation, use the port of the last installation? [y/n]:" historyCustomPortStatus
if [[ "${historyCustomPortStatus}" == "y" ]]; then
showPort="${currentPort}"
if [[ -n "${customPort}" ]]; then
showPort="${customPort}"
fi
echoContent yellow "\n ---> Port : ${showPort}"
fi
fi

if [[ -z "${currentPort}" && -z "${customPort}" ]] || [[ "${historyCustomPortStatus}" == "n" ]]; then
echo
echoContent yellow " Please enter the port [ default : 443] , such as a custom port, only allowed to use DNS to apply for a certificate [ press Enter to use the default ]"
read -r -p " Port :" customPort
if [[ -n "${customPort}" && "${customPort}" != "443" ]]; then
if ((customPort >= 1 && customPort <= 65535)); then
checkCustomPort
allowPort "${customPort}"
else
echoContent red "---> Port input error "
exit
fi
else
customPort=
echoContent yellow "\n ---> Port : 443"
fi
fi
}

# Check if the port is occupied
checkCustomPort() {
if lsof -i "tcp:${customPort}" | grep -q LISTEN; then
echoContent red "\n ---> ${customPort} port is occupied, please close it manually and install it \n"
lsof -i tcp:80 | grep LISTEN
exit 0
fi
}

# install TLS
installTLS() {
echoContent skyBlue "\nProgress $ 1/${totalProgress}: apply for TLS certificate \n"
local tlsDomain=${domain}

# install tls
if [[ -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" && -f "/etc/v2ray-agent/tls/${tlsDomain}.key" && -n $(cat "/ etc/v2ray-agent/tls/${tlsDomain}.crt") ]] || [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh /${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
echoContent green "---> Certificate detected "
# checkTLStatus
renewalTLS

if [[ -z $(find /etc/v2ray-agent/tls/ -name "${tlsDomain}.crt") ]] || [[ -z $(find /etc/v2ray-agent/tls/ -name "${tlsDomain}.key") ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/ etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
else
echoContent yellow " ---> If the certificate has not expired or is a custom certificate, please select [n]\n"
read -r -p " Reinstall? [y/n]:" reInstallStatus
if [[ "${reInstallStatus}" == "y" ]]; then
rm -rf /etc/v2ray-agent/tls/*
installTLS "$1"
fi
fi

elif [[ -d "$HOME/.acme.sh" ]] && [[ ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" || ! -f " $HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" ]]; then
echoContent green " ---> Install TLS certificate "

if [[ "${installDNSACMEStatus}" != "true" ]]; then
switchSSLType
customSSLEmail
selectAcmeInstallSSL
else
echoContent green "---> Wildcard certificate has been detected and is being automatically generated "
fi
if [[ "${installDNSACMEStatus}" == "true" ]]; then
echo
if [[ -d "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc" && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.key " && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.cer" ]]; then
sudo "$HOME/.acme.sh/acme.sh" --installcert -d "*.${dnsTLSDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
fi

elif [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$ HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/ etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
fi

if [[ ! -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" || ! -f "/etc/v2ray-agent/tls/${tlsDomain}.key" ]] || [ [ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.key") || -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ] ]; then
tail -n 10 /etc/v2ray-agent/tls/acme.log
if [[ ${installTLSCount} == "1" ]]; then
echoContent red " ---> TLS installation failed , please check the acme log "
exit 0
fi

installTLSCount=1
echo
if [[ -z "${customPort}" ]]; then
echoContent red " ---> TLS installation failed , checking whether ports 80 and 443 are open "
allowPort 80
allowPort 443
fi

echoContent yellow "---> Retry to install TLS certificate "

if tail -n 10 /etc/v2ray-agent/tls/acme.log | grep -q "Could not validate email address as valid"; then
echoContent red "--->The mailbox cannot pass the SSL vendor verification, please re-enter "
echo
customSSLEmail "validate email"
installTLS "$1"
else
installTLS "$1"
fi

fi

echoContent green " ---> TLS generated successfully "
else
echoContent yellow " ---> acme.sh is not installed "
exit 0
fi
}
#Configure masquerade blog
initNginxConfig() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Configure Nginx"

cat <<EOF >${nginxConfigPath}alone.conf
server {
listen 80;
listen [::]:80;
server_name ${domain};
root /usr/share/nginx/html;
location ~/.well-known {allow all;}
location /test {return 200 'fjkvymb6len';}
}
EOF
}

# custom / random path
randomPathFunction() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : generate a random path "

if [[ -n "${currentPath}" ]]; then
echo
read -r -p " read the last installation record, whether to use the path path of the last installation ? [y/n]: "historyPathStatus
echo
fi

if [[ "${historyPathStatus}" == "y" ]]; then
customPath=${currentPath}
echoContent green " ---> used successfully \n"
else
echoContent yellow " Please enter a custom path [ Example : alone] , no slashes required, [ Enter ] a random path "
read -r -p ' path :' customPath

if [[ -z "${customPath}" ]]; then
customPath=$(head -n 50 /dev/urandom | sed 's/[^az]//g' | strings -n 4 | tr '[:upper:]' '[:lower:]' | head -1 )
currentPath=${customPath:0:4}
customPath=${currentPath}
else
currentPath=${customPath}
fi

fi
echoContent yellow "\n path:${currentPath}"
echoContent skyBlue "\n----------------------------"
}
# Nginx Pretend Blog
nginxBlog() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Add fake site "
if [[ -d "/usr/share/nginx/html" && -f "/usr/share/nginx/html/check" ]]; then
echo
read -r -p " A fake site has been detected, do you need to reinstall [y/n]:" nginxBlogInstallStatus
if [[ "${nginxBlogInstallStatus}" == "y" ]]; then
rm -rf /usr/share/nginx/html
randomNum=$((RANDOM % 6 + 1))
wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip >/dev/null
unzip -o /usr/share/nginx/html${randomNum}.zip -d /usr/share/nginx/html >/dev/null
rm -f /usr/share/nginx/html${randomNum}.zip*
echoContent green " ---> Added fake site successfully "
fi
else
randomNum=$((RANDOM % 6 + 1))
rm -rf /usr/share/nginx/html
wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip >/dev/null
unzip -o /usr/share/nginx/html${randomNum}.zip -d /usr/share/nginx/html >/dev/null
rm -f /usr/share/nginx/html${randomNum}.zip*
echoContent green " ---> Added fake site successfully "
fi

}

#Modify http_port_t port _
updateSELinuxHTTPPortT() {

$(find /usr/bin /usr/sbin | grep -w journalctl) -xe >/etc/v2ray-agent/nginx_error.log 2>&1

if find /usr/bin /usr/sbin | grep -q -w semanage && find /usr/bin /usr/sbin | grep -q -w getenforce && grep -E "31300|31302" </etc/v2ray-agent /nginx_error.log | grep -q "Permission denied"; then
echoContent red " ---> Check if the SELinux port is open "
if ! $(find /usr/bin /usr/sbin | grep -w semanage) port -l | grep http_port | grep -q 31300; then
$(find /usr/bin /usr/sbin | grep -w semanage) port -a -t http_port_t -p tcp 31300
echoContent green " ---> http_port_t 31300 port successfully opened "
fi

if ! $(find /usr/bin /usr/sbin | grep -w semanage) port -l | grep http_port | grep -q 31302; then
$(find /usr/bin /usr/sbin | grep -w semanage) port -a -t http_port_t -p tcp 31302
echoContent green " ---> http_port_t 31302 port successfully opened "
fi
handle Nginx start

else
exit 0
fi
}

#Operate Nginx _
handleNginx() {

if [[ -z $(pgrep -f "nginx") ]] && [[ "$1" == "start" ]]; then
systemctl start nginx 2>/etc/v2ray-agent/nginx_error.log

sleep 0.5

if [[ -z $(pgrep -f nginx) ]]; then
echoContent red "---> Nginx failed to start "
echoContent red " ---> Please try to install nginx manually and execute the script again "

if grep -q "journalctl -xe" </etc/v2ray-agent/nginx_error.log; then
updateSELinuxHTTPPortT
fi

# exit 0
else
echoContent green "---> Nginx started successfully "
fi

elif [[ -n $(pgrep -f "nginx") ]] && [[ "$1" == "stop" ]]; then
systemctl stop nginx
sleep 0.5
if [[ -n $(pgrep -f "nginx") ]]; then
pgrep -f "nginx" | xargs kill -9
fi
echoContent green " ---> Nginx closed successfully "
fi
}

#Timed task update tls certificate
installCronTLS() {
echoContent skyBlue "\nProgress $ 1/${totalProgress}: add regular maintenance certificate "
crontab -l >/etc/v2ray-agent/backup_crontab.cron
local historyCrontab
historyCrontab=$(sed '/v2ray-agent/d;/acme.sh/d' /etc/v2ray-agent/backup_crontab.cron)
echo "${historyCrontab}" >/etc/v2ray-agent/backup_crontab.cron
echo "30 1 * * * /bin/bash /etc/v2ray-agent/install.sh RenewTLS >> /etc/v2ray-agent/crontab_tls.log 2>&1" >>/etc/v2ray-agent/backup_crontab.cron
crontab /etc/v2ray-agent/backup_crontab.cron
echoContent green "\n ---> Added regular maintenance certificate successfully "
}

# update certificate
renewalTLS() {

if [[ -n $1 ]]; then
echoContent skyBlue "\nprogress $ 1/1: update certificate "
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
if [[ -d "$HOME/.acme.sh/${domain}_ecc" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.key" && -f "$ HOME/.acme.sh/${domain}_ecc/${domain}.cer" ]] || [[ "${installDNSACMEStatus}" == "true" ]]; then
modifyTime=

if [[ "${installDNSACMEStatus}" == "true" ]]; then
modifyTime=$(stat "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.cer" | sed -n '7,6p' | awk '{print $2" "$3" "$4" "$5}')
else
modifyTime=$(stat "$HOME/.acme.sh/${domain}_ecc/${domain}.cer" | sed -n '7,6p' | awk '{print $2" "$3" "$4" " $5}')
fi

modifyTime=$(date +%s -d "${modifyTime}")
currentTime=$(date +%s)
((stampDiff = currentTime - modifyTime))
((days = stampDiff / 86400))
((remainingDays = sslRenewalDays - days))

tlsStatus=${remainingDays}
if [[ ${remainingDays} -le 0 ]]; then
tlsStatus= " Expired "
fi

echoContent skyBlue " ---> certificate check date : $(date "+%F %H:%M:%S")"
echoContent skyBlue " ---> certificate generation date : $(date -d @"${modifyTime}" +"%F %H:%M:%S")"
echoContent skyBlue "---> Certificate generation days : ${days}"
echoContent skyBlue " ---> remaining days of the certificate : "${tlsStatus}
echoContent skyBlue " ---> The last day before the certificate expires will be automatically updated. If the update fails, please update manually "

if [[ ${remainingDays} -le 1 ]]; then
echoContent yellow "---> Regenerate certificate "
handle Nginx stop
sudo "$HOME/.acme.sh/acme.sh" --cron --home "$HOME/.acme.sh"
sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${domain}" --fullchainpath /etc/v2ray-agent/tls/"${domain}.crt" --keypath /etc /v2ray-agent/tls/"${domain}.key" --ecc
reloadCore
handle Nginx start
else
echoContent green "---> Certificate is valid "
fi
else
echoContent red "---> not installed "
fi
}
#Check the status of the TLS certificate
checkTLStatus() {

if [[ -d "$HOME/.acme.sh/${currentHost}_ecc" ]] && [[ -f "$HOME/.acme.sh/${currentHost}_ecc/${currentHost}.key" ] ] && [[ -f "$HOME/.acme.sh/${currentHost}_ecc/${currentHost}.cer" ]]; then
modifyTime=$(stat "$HOME/.acme.sh/${currentHost}_ecc/${currentHost}.cer" | sed -n '7,6p' | awk '{print $2" "$3" "$4" " $5}')

modifyTime=$(date +%s -d "${modifyTime}")
currentTime=$(date +%s)
((stampDiff = currentTime - modifyTime))
((days = stampDiff / 86400))
((remainingDays = sslRenewalDays - days))

tlsStatus=${remainingDays}
if [[ ${remainingDays} -le 0 ]]; then
tlsStatus= " Expired "
fi

echoContent skyBlue " ---> certificate generation date : $(date -d "@${modifyTime}" +"%F %H:%M:%S")"
echoContent skyBlue "---> Certificate generation days : ${days}"
echoContent skyBlue " ---> remaining days of the certificate : ${tlsStatus}"
fi
}

#Install V2Ray , specified version
installV2Ray() {
readInstallType
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Install V2Ray"

if [[ "${coreInstallType}" != "2" && "${coreInstallType}" != "3" ]]; then
if [[ "${selectCoreType}" == "2" ]]; then

version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep - v 'v5' | head -1)
else
version=${v2rayCoreVersion}
fi

echoContent green " ---> v2ray-core version : ${version}"
if wget --help | grep -q show-progress; then
wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}. zip"
else
wget -c -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip" >/dev/null 2>&1
fi

unzip -o "/etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip" -d /etc/v2ray-agent/v2ray >/dev/null
rm -rf "/etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip"
else
if [[ "${selectCoreType}" == "3" ]]; then
echoContent green "---> lock v2ray-core version to v4.32.1"
rm -f /etc/v2ray-agent/v2ray/v2ray
rm -f /etc/v2ray-agent/v2ray/v2ctl
installV2Ray "$1"
else
echoContent green " ---> v2ray-core version :$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"
read -r -p " Update, upgrade ? [y/n]:" reInstallV2RayStatus
if [[ "${reInstallV2RayStatus}" == "y" ]]; then
rm -f /etc/v2ray-agent/v2ray/v2ray
rm -f /etc/v2ray-agent/v2ray/v2ctl
installV2Ray "$1"
fi
fi
fi
}

# install hysteria
installHysteria() {
readInstallType
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Install Hysteria"

if [[ -z "${hysteriaConfigPath}" ]]; then

version=$(curl -s https://api.github.com/repos/apernet/hysteria/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | head -1)

echoContent green " ---> Hysteria version : ${version}"
if wget --help | grep -q show-progress; then
wget -c -q --show-progress -P /etc/v2ray-agent/hysteria/ "https://github.com/apernet/hysteria/releases/download/${version}/${hysteriaCoreCPUVendor}"
else
wget -c -P /etc/v2ray-agent/hysteria/ "https://github.com/apernet/hysteria/releases/download/${version}/${hysteriaCoreCPUVendor}" >/dev/null 2>&1
fi
mv "/etc/v2ray-agent/hysteria/${hysteriaCoreCPUVendor}" /etc/v2ray-agent/hysteria/hysteria
chmod 655 /etc/v2ray-agent/hysteria/hysteria
else
echoContent green " ---> Hysteria version :$(/etc/v2ray-agent/hysteria/hysteria --version | awk '{print $3}')"
read -r -p " Update, upgrade ? [y/n]:" reInstallHysteriaStatus
if [[ "${reInstallHysteriaStatus}" == "y" ]]; then
rm -f /etc/v2ray-agent/hysteria/hysteria
install Hysteria "$1"
fi
fi

}
# install xray
installXray() {
readInstallType
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Install Xray"

if [[ "${coreInstallType}" != "1" ]]; then

version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | head - 1)

echoContent green " ---> Xray-core version : ${version}"
if wget --help | grep -q show-progress; then
wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}. zip"
else
wget -c -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip" >/dev/null 2>&1
fi

unzip -o "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" -d /etc/v2ray-agent/xray >/dev/null
rm -rf "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip"
chmod 655 /etc/v2ray-agent/xray/xray
else
echoContent green " ---> Xray-core version :$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"
read -r -p " Update, upgrade ? [y/n]:" reInstallXrayStatus
if [[ "${reInstallXrayStatus}" == "y" ]]; then
rm -f /etc/v2ray-agent/xray/xray
installXray "$1"
fi
fi
}

# v2ray version management
v2rayVersionManageMenu() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : V2Ray version management "
if [[ ! -d "/etc/v2ray-agent/v2ray/" ]]; then
echoContent red "--->The installation directory is not detected, please execute the script to install the content "
menu
exit 0
fi
echoContent red "\n=============================================== =================="
echoContent yellow "1. Upgrade v2ray-core"
echoContent yellow "2. Roll back v2ray-core"
echoContent yellow "3. Close v2ray-core"
echoContent yellow "4. Open v2ray-core"
echoContent yellow "5. Restart v2ray-core"
echoContent yellow "6. update geosite , geoip"
echoContent red "================================================ ================"
read -r -p " Please select :" selectV2RayType
if [[ "${selectV2RayType}" == "1" ]]; then
updateV2Ray
elif [[ "${selectV2RayType}" == "2" ]]; then
echoContent yellow "\n1. Only the last five versions can be rolled back "
echoContent yellow "2. There is no guarantee that it can be used normally after rollback "
echoContent yellow "3. If the rolled back version does not support the current config , it will fail to connect, please proceed with caution "
echoContent skyBlue "------------------------Version---------------------- ---------"
curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep -v 'v5' | head -5 | awk '{print ""NR""":"$0}'

echoContent skyBlue "----------------------------------------------- ---------------"
read -r -p " Please enter the version to roll back :" selectV2rayVersionType
version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep - v 'v5' | head -5 | awk '{print ""NR""":"$0}' | grep "${selectV2rayVersionType}:" | awk -F "[:]" '{print $2}')
if [[ -n "${version}" ]]; then
updateV2Ray "${version}"
else
echoContent red "\n ---> input error, please re-enter "
v2rayVersionManageMenu1
fi
elif [[ "${selectV2RayType}" == "3" ]]; then
handleV2Ray stop
elif [[ "${selectV2RayType}" == "4" ]]; then
handleV2Ray start
elif [[ "${selectV2RayType}" == "5" ]]; then
reloadCore
elif [[ "${selectXrayType}" == "6" ]]; then
updateGeoSite
fi
}

# xray version management
xrayVersionManageMenu() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Xray version management "
if [[ ! -d "/etc/v2ray-agent/xray/" ]]; then
echoContent red "--->The installation directory is not detected, please execute the script to install the content "
menu
exit 0
fi
echoContent red "\n=============================================== =================="
echoContent yellow "1. Upgrade Xray-core"
echoContent yellow "2. Upgrade Xray-core preview version "
echoContent yellow "3. Roll back Xray-core"
echoContent yellow "4. Close Xray-core"
echoContent yellow "5. Open Xray-core"
echoContent yellow "6. Restart Xray-core"
echoContent yellow "7. update geosite , geoip, IRAN database included"
echoContent red "================================================ ================"
read -r -p " Please select :" selectXrayType
if [[ "${selectXrayType}" == "1" ]]; then
updateXray
elif [[ "${selectXrayType}" == "2" ]]; then

prereleaseStatus=true
updateXray

elif [[ "${selectXrayType}" == "3" ]]; then
echoContent yellow "\n1. Only the last five versions can be rolled back "
echoContent yellow "2. There is no guarantee that it can be used normally after rollback "
echoContent yellow "3. If the rolled back version does not support the current config , it will fail to connect, please proceed with caution "
echoContent skyBlue "------------------------Version---------------------- ---------"
curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | head -5 | awk ' {print ""NR""":"$0}'
echoContent skyBlue "----------------------------------------------- ---------------"
read -r -p " Please enter the version to roll back :" selectXrayVersionType
version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | head - 5 | awk '{print ""NR""":"$0}' | grep "${selectXrayVersionType}:" | awk -F "[:]" '{print $2}')
if [[ -n "${version}" ]]; then
updateXray "${version}"
else
echoContent red "\n ---> input error, please re-enter "
xrayVersionManageMenu1
fi
elif [[ "${selectXrayType}" == "4" ]]; then
handle Xray stop
elif [[ "${selectXrayType}" == "5" ]]; then
handle Xray start
elif [[ "${selectXrayType}" == "6" ]]; then
reloadCore
elif [[ "${selectXrayType}" == "7" ]]; then
updateGeoSite
fi

}

#update geosite _
updateGeoSite() {
echoContent yellow "\nSource https://github.com/Loyalsoldier/v2ray-rules-dat "

version=$(curl -s https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases | jq -r '.[]|.tag_name' | head -1)
echoContent skyBlue "------------------------Version---------------------- ---------"
echo "version:${version}"
wget -c -q --show-progress -P ${configPath}../ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat"
wget -c -q --show-progress -P ${configPath}../ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat"
wget -c -q --show-progress -P ${configPath}../ "https://github.com/bootmortis/iran-hosted-domains/releases/latest/download/iran.dat"
wget -c -q --show-progress -P ${configPath}../ "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"
reloadCore
echoContent green " ---> updated "

}
#Update V2Ray _
updateV2Ray() {
readInstallType
if [[ -z "${coreInstallType}" ]]; then

if [[ -n "$1" ]]; then
version=$1
else
version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep - v 'v5' | head -1)
fi
# use locked version
if [[ -n "${v2rayCoreVersion}" ]]; then
version=${v2rayCoreVersion}
fi
echoContent green " ---> v2ray-core version : ${version}"

if wget --help | grep -q show-progress; then
wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}. zip"
else
wget -c -P "/etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip" >/dev/null 2>&1
fi

unzip -o "/etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip" -d /etc/v2ray-agent/v2ray >/dev/null
rm -rf "/etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip"
handleV2Ray stop
handleV2Ray start
else
echoContent green " ---> current v2ray-core version : $(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"

if [[ -n "$1" ]]; then
version=$1
else
version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r '.[]|select (.prerelease==false)|.tag_name' | grep - v 'v5' | head -1)
fi

if [[ -n "${v2rayCoreVersion}" ]]; then
version=${v2rayCoreVersion}
fi
if [[ -n "$1" ]]; then
read -r -p "The rollback version is ${version} , continue? [y/n]:" rollbackV2RayStatus
if [[ "${rollbackV2RayStatus}" == "y" ]]; then
if [[ "${coreInstallType}" == "2" ]]; then
echoContent green " ---> current v2ray-core version : $(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"
elif [[ "${coreInstallType}" == "1" ]]; then
echoContent green " ---> current Xray-core version : $(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"
fi

handleV2Ray stop
rm -f /etc/v2ray-agent/v2ray/v2ray
rm -f /etc/v2ray-agent/v2ray/v2ctl
updateV2Ray "${version}"
else
echoContent green "---> Discard fallback version "
fi
elif [[ "${version}" == "v$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)" ]]; then
read -r -p "The current version is the same as the latest version, do you want to reinstall? [y/n]:" reInstallV2RayStatus
if [[ "${reInstallV2RayStatus}" == "y" ]]; then
handleV2Ray stop
rm -f /etc/v2ray-agent/v2ray/v2ray
rm -f /etc/v2ray-agent/v2ray/v2ctl
updateV2Ray
else
echoContent green " ---> give up reinstallation "
fi
else
read -r -p "The latest version is : ${version} , is it updated? [y/n]:" installV2RayStatus
if [[ "${installV2RayStatus}" == "y" ]]; then
rm -f /etc/v2ray-agent/v2ray/v2ray
rm -f /etc/v2ray-agent/v2ray/v2ctl
updateV2Ray
else
echoContent green " ---> give up update "
fi

fi
fi
}

#updateXray _ _
updateXray() {
readInstallType
if [[ -z "${coreInstallType}" ]]; then
if [[ -n "$1" ]]; then
version=$1
else
version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
fi

echoContent green " ---> Xray-core version : ${version}"

if wget --help | grep -q show-progress; then
wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}. zip"
else
wget -c -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip " >/dev/null 2>&1
fi

unzip -o "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" -d /etc/v2ray-agent/xray >/dev/null
rm -rf "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip"
chmod 655 /etc/v2ray-agent/xray/xray
handle Xray stop
handle Xray start
else
echoContent green " ---> current Xray-core version : $(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"

if [[ -n "$1" ]]; then
version=$1
else
version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
fi

if [[ -n "$1" ]]; then
read -r -p "The rollback version is ${version} , continue? [y/n]:" rollbackXrayStatus
if [[ "${rollbackXrayStatus}" == "y" ]]; then
echoContent green " ---> current Xray-core version : $(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"

handle Xray stop
rm -f /etc/v2ray-agent/xray/xray
updateXray "${version}"
else
echoContent green "---> Discard fallback version "
fi
elif [[ "${version}" == "v$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)" ]]; then
read -r -p "The current version is the same as the latest version, do you want to reinstall? [y/n]:" reInstallXrayStatus
if [[ "${reInstallXrayStatus}" == "y" ]]; then
handle Xray stop
rm -f /etc/v2ray-agent/xray/xray
rm -f /etc/v2ray-agent/xray/xray
updateXray
else
echoContent green " ---> give up reinstallation "
fi
else
read -r -p "The latest version is : ${version} , is it updated? [y/n]:" installXrayStatus
if [[ "${installXrayStatus}" == "y" ]]; then
rm -f /etc/v2ray-agent/xray/xray
updateXray
else
echoContent green " ---> give up update "
fi

fi
fi
}

# Verify that the entire service is available
checkGFWStatue() {
readInstallType
echoContent skyBlue "\nProgress $ 1/${totalProgress} : verify service startup status "
if [[ "${coreInstallType}" == "1" ]] && [[ -n $(pgrep -f xray/xray) ]]; then
echoContent green "---> service started successfully "
elif [[ "${coreInstallType}" == "2" ]] && [[ -n $(pgrep -f v2ray/v2ray) ]]; then
echoContent green "---> service started successfully "
else
echoContent red " ---> The service failed to start, please check whether there is a log print on the terminal "
exit 0
fi

}

# V2Ray starts automatically
installV2RayService() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Configure V2Ray to start automatically "
if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
rm -rf /etc/systemd/system/v2ray.service
touch /etc/systemd/system/v2ray.service
execStart='/etc/v2ray-agent/v2ray/v2ray-confdir /etc/v2ray-agent/v2ray/conf'
cat <<EOF >/etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray - A unified platform for anti-censorship
Documentation=https://v2ray.comhttps://guide.v2fly.org
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICECAP_NET_RAW
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
echoContent green "---> Configure V2Ray to boot and start successfully "
fi
}

#Install hysteria boot up
installHysteriaService() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : configure Hysteria to boot automatically "
if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
rm -rf /etc/systemd/system/hysteria.service
touch /etc/systemd/system/hysteria.service
execStart='/etc/v2ray-agent/hysteria/hysteria --log-level info -c /etc/v2ray-agent/hysteria/conf/config.json server'
cat <<EOF >/etc/systemd/system/hysteria.service
[Unit]
Description=Hysteria Service
Documentation=https://github.com/apernet/hysteria/wiki
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICECAP_NET_RAW
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
systemctl enable hysteria.service
echoContent green " ---> Configure Hysteria to boot up successfully "
fi
}
# Xray boots automatically
installXrayService() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Configure Xray to start automatically "
if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
rm -rf /etc/systemd/system/xray.service
touch /etc/systemd/system/xray.service
execStart='/etc/v2ray-agent/xray/xray run -confdir /etc/v2ray-agent/xray/conf'
cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICECAP_NET_RAW
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
systemctl enable xray.service
echoContent green "---> Configure Xray to start automatically at boot "
fi
}

#Operate V2Ray _
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
echoContent green " ---> V2Ray started successfully "
else
echoContent red "V2Ray failed to start "
echoContent red " Please manually execute [ /etc/v2ray-agent/v2ray/v2ray -confdir /etc/v2ray-agent/v2ray/conf ], check the error log "
exit 0
fi
elif [[ "$1" == "stop" ]]; then
if [[ -z $(pgrep -f "v2ray/v2ray") ]]; then
echoContent green " ---> V2Ray closed successfully "
else
echoContent red "V2Ray shutdown failed "
echoContent red " Please manually execute 【 ps -ef|grep -v grep|grep v2ray|awk '{print \$2}'|xargs kill -9 】 "
exit 0
fi
fi
}

#Operate Hysteria _
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
echoContent green " ---> Hysteria started successfully "
else
echoContent red "Hysteria failed to start "
echoContent red " Please manually execute 【 /etc/v2ray-agent/hysteria/hysteria --log-level debug -c /etc/v2ray-agent/hysteria/conf/config.json server 】to view the error log "
exit 0
fi
elif [[ "$1" == "stop" ]]; then
if [[ -z $(pgrep -f "hysteria/hysteria") ]]; then
echoContent green " ---> Hysteria closed successfully "
else
echoContent red "Hysteria shutdown failed "
echoContent red " Please manually execute【 ps -ef|grep -v grep|grep hysteria|awk '{print \$2}'|xargs kill -9 】 "
exit 0
fi
fi
}
#Operate xray _
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
echoContent green " ---> Xray started successfully "
else
echoContent red "Xray failed to start "
echoContent red " Please manually execute [ /etc/v2ray-agent/xray/xray -confdir /etc/v2ray-agent/xray/conf ], check the error log "
exit 0
fi
elif [[ "$1" == "stop" ]]; then
if [[ -z $(pgrep -f "xray/xray") ]]; then
echoContent green " ---> Xray closed successfully "
else
echoContent red "failed to close xray "
echoContent red " Please manually execute 【 ps -ef|grep -v grep|grep xray|awk '{print \$2}'|xargs kill -9 】 "
exit 0
fi
fi
}
#Get clients configuration _
getClients() {
local path=$1

local addClientsStatus=$2
previousClients=
if [[ ${addClientsStatus} == "true" ]]; then
if [[ ! -f "${path}" ]]; then
echo
local protocol
protocol=$(echo "${path}" | awk -F "[_]" '{print $2 $3}')
echoContent yellow " The configuration file installed last time for this protocol [${protocol}] was not read , first uuid of the configuration file is used"
else
previousClients=$(jq -r ".inbounds[0].settings.clients" "${path}")
fi

fi
}

#Add client configuration _
addClients() {
local path=$1
local addClientsStatus=$2
if [[ ${addClientsStatus} == "true" && -n "${previousClients}" ]]; then
config=$(jq -r ".inbounds[0].settings.clients = ${previousClients}" "${path}")
echo "${config}" | jq . > "${path}"
fi
}
#Add hysteria configuration _
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
echo "${config}" | jq . > "${path}"
fi
}

#Initialize the hysteria port
initHysteriaPort() {
readHysteriaConfig
if [[ -n "${hysteriaPort}" ]]; then
read -r -p " Read the port of the last installation, use the port of the last installation? [y/n]:" historyHysteriaPortStatus
if [[ "${historyHysteriaPortStatus}" == "y" ]]; then
echoContent yellow "\n ---> Port : ${hysteriaPort}"
else
hysteriaPort=
fi
fi

if [[ -z "${hysteriaPort}" ]]; then
echoContent yellow " Please enter the Hysteria port [ example : 10000] , which cannot be duplicated with other services "
read -r -p " Port :" hysteriaPort
fi
if [[ -z ${hysteriaPort} ]]; then
echoContent red "--->The port cannot be empty "
initHysteriaPort "$2"
elif ((hysteriaPort < 1 || hysteriaPort > 65535)); then
echoContent red " --->The port is invalid "
initHysteriaPort "$2"
fi
allowPort "${hysteriaPort}"
}

#Initialize hysteria 's protocol _
initHysteriaProtocol() {
echoContent skyBlue "\nPlease select the protocol type "
echoContent red "================================================ ================"
echoContent yellow "1.udp(QUIC)( default )"
echoContent yellow "2. faketcp"
echoContent yellow "3.wechat-video"
echoContent red "================================================ ================"
read -r -p " Please select :" selectHysteriaProtocol
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
echoContent yellow "\n ---> Protocol : ${hysteriaProtocol}\n"
}

#Initialize hysteria network information
initHysteriaNetwork() {

echoContent yellow " Please enter the average delay from the local to the server, please fill in according to the real situation (default: 180 , unit: ms ) "
read -r -p " Delay :" hysteriaLag
if [[ -z "${hysteriaLag}" ]]; then
hysteriaLag=180
echoContent yellow "\n ---> Delay : ${hysteriaLag}\n"
fi

echoContent yellow " Please enter the downlink speed of the peak local bandwidth (default: 100 , unit: Mbps ) "
read -r -p " Download Speed :" hysteriaClientDownloadSpeed
if [[ -z "${hysteriaClientDownloadSpeed}" ]]; then
hysteriaClientDownloadSpeed=100
echoContent yellow "\n --->Download Speed : ${hysteriaClientDownloadSpeed}\n"
fi

echoContent yellow " Please enter the upstream speed of the peak local bandwidth (default: 50 , unit: Mbps ) "
read -r -p " uplink speed :" hysteriaClientUploadSpeed
if [[ -z "${hysteriaClientUploadSpeed}" ]]; then
hysteriaClientUploadSpeed=50
echoContent yellow "\n --->Upload speed : ${hysteriaClientUploadSpeed}\n"
fi

cat <<EOF>/etc/v2ray-agent/hysteria/conf/client_network.json
{
	"hysteriaLag": "${hysteriaLag}",
	"hysteriaClientUploadSpeed": "${hysteriaClientUploadSpeed}",
	"hysteriaClientDownloadSpeed": "${hysteriaClientDownloadSpeed}"
}
EOF

}
#Initialize Hysteria configuration _
initHysteriaConfig() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Initialize Hysteria configuration "

initHysteriaPort
initHysteriaProtocol
initHysteriaNetwork

getClients "${configPath}${frontingType}.json" true
cat <<EOF>/etc/v2ray-agent/hysteria/conf/config.json
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
}

#Initialize V2Ray configuration file
initV2RayConfig() {
echoContent skyBlue "\nProgress $ 2/${totalProgress} : Initialize V2Ray configuration "
echo

read -r -p " Do you want to customize UUID ? [y/n]:" customUUIDStatus
echo
if [[ "${customUUIDStatus}" == "y" ]]; then
read -r -p " Please enter a valid UUID:" currentCustomUUID
if [[ -n "${currentCustomUUID}" ]]; then
uuid=${currentCustomUUID}
fi
fi
local addClientsStatus=
if [[ -n "${currentUUID}" && -z "${uuid}" ]]; then
read -r -p " Read the last installation record, whether to use the UUID of the last installation ? [y/n]:" historyUUIDStatus
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
echoContent red "\n ---> uuid read error, regenerate "
uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
fi

movePreviousConfig
# log
cat <<EOF>/etc/v2ray-agent/v2ray/conf/00_log.json
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
"protocol": "freedom",
"settings": {
"domainStrategy": "UseIPv4"
},
"tag": "IPv4-out"
},
{
"protocol": "freedom",
"settings": {
"domainStrategy": "UseIPv6"
},
"tag": "IPv6-out"
},
{
"protocol": "blackhole",
"tag": "blackhole-out"
}
]
}
EOF
fi

#dns
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
# fall back nginx
local fallbacksList='{"dest":31300,"xver":0},{"alpn":"h2","dest":31302,"xver":0}'

#trojan
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
	"tag": "trojanTCP",
	"settings": {
		"clients": [
		{
			"password": "${uuid}",
			"email": "default_Trojan_TCP"
		}
		],
		"fallbacks": [
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
	"tag": "VLESSWS",
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

#trojan_grpc
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

#VMess_WS
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
"tag": "VMessWS",
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
"tag": "VLESSGRPC",
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
"tag": "VLESSTCP",
"settings": {
"clients": [
{
"id": "${uuid}",
"add": "${add}",
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
"usage": "encipherment"
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

#Initialize the Xray Trojan XTLS configuration file
initXrayFrontingConfig() {
echoContent red " ---> Trojan does not support xtls-rprx-vision"
exit 0
if [[ -z "${configPath}" ]]; then
echoContent red " ---> not installed, please use the script to install "
menu
exit 0
fi
if [[ "${coreInstallType}" != "1" ]]; then
echoContent red "---> Available type not installed "
fi
local xtlsType=
if echo ${currentInstallProtocolType} | grep -q trojan; then
xtlsType=VLESS
else
xtlsType=Trojan

fi

echoContent skyBlue "\nFunction 1 /${totalProgress}: switch to ${xtlsType}"
echoContent red "\n=============================================== =================="
echoContent yellow "#notes \ n"
echoContent yellow " will replace prefix with ${xtlsType}"
echoContent yellow " If the front is Trojan , when you view the account, there will be two Trojan protocol nodes, one of which is unavailable xtls"
echoContent yellow " Execute again to switch to the previous front \n"

echoContent yellow "1. Switch to ${xtlsType}"
echoContent red "================================================ ================"
read -r -p " Please select :" selectType
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

#Move the last configuration file to a temporary file
movePreviousConfig() {
if [[ -n "${configPath}" ]] && [[ -f "${configPath}02_VLESS_TCP_inbounds.json" ]]; then
rm -rf ${configPath}../tmp/*
mv ${configPath}* ${configPath}../tmp/
fi

}

#Initialize the Xray configuration file
initXrayConfig() {
echoContent skyBlue "\nProgress $ 2/${totalProgress} : Initialize Xray configuration "
echo
local uuid=
local addClientsStatus=
if [[ -n "${currentUUID}" ]]; then
read -r -p " Read the last installation record, whether to use the UUID of the last installation ? [y/n]:" historyUUIDStatus
if [[ "${historyUUIDStatus}" == "y" ]]; then
addClientsStatus=true
uuid=${currentUUID}
echoContent green "\n ---> used successfully "
fi
fi

if [[ -z "${uuid}" ]]; then
echoContent yellow " Please enter a custom UUID [ must be legal ] , [ Enter ] a random UUID"
read -r -p 'UUID:' customUUID

if [[ -n ${customUUID} ]]; then
uuid=${customUUID}
else
uuid=$(/etc/v2ray-agent/xray/xray uuid)
fi

fi

if [[ -z "${uuid}" ]]; then
addClientsStatus=
echoContent red "\n ---> uuid read error , regenerate "
uuid=$(/etc/v2ray-agent/xray/xray uuid)
fi

echoContent yellow "\n ${uuid}"

movePreviousConfig

# log
cat <<EOF >/etc/v2ray-agent/xray/conf/00_log.json
{
"log": {
"error": "/etc/v2ray-agent/xray/error.log",
"loglevel": "warning"
}
}
EOF

# outbounds
if [[ -n "${pingIPv6}" ]]; then
cat <<EOF>/etc/v2ray-agent/xray/conf/10_ipv6_outbounds.json
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
cat <<EOF>/etc/v2ray-agent/xray/conf/10_ipv4_outbounds.json
{
"outbounds":[
{
"protocol": "freedom",
"settings": {
"domainStrategy": "UseIPv4"
},
"tag": "IPv4-out"
},
{
"protocol": "freedom",
"settings": {
"domainStrategy": "UseIPv6"
},
"tag": "IPv6-out"
},
{
"protocol": "blackhole",
"tag": "blackhole-out"
}
]
}
EOF
fi

#dns
cat <<EOF >/etc/v2ray-agent/xray/conf/11_dns.json
{
"dns": {
"servers": [
"localhost"
]
}
}
EOF

# VLESS_TCP_TLS/XTLS
# fall back nginx
local fallbacksList='{"dest":31300,"xver":0},{"alpn":"h2","dest":31302,"xver":0}'

#trojan
if echo "${selectCustomInstallType}" | grep -q 4 || [[ "$1" == "all" ]]; then
fallbacksList='{"dest":31296,"xver":1},{"alpn":"h2","dest":31302,"xver":0}'
getClients "${configPath}../tmp/04_trojan_TCP_inbounds.json" "${addClientsStatus}"

cat <<EOF >/etc/v2ray-agent/xray/conf/04_trojan_TCP_inbounds.json
{
"inbounds":[
	{
	"port": 31296,
	"listen": "127.0.0.1",
	"protocol": "trojan",
	"tag": "trojanTCP",
	"settings": {
		"clients": [
		{
			"password": "${uuid}",
			"email": "default_Trojan_TCP"
		}
		],
		"fallbacks": [
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
addClients "/etc/v2ray-agent/xray/conf/04_trojan_TCP_inbounds.json" "${addClientsStatus}"
fi

# VLESS_WS_TLS
if echo "${selectCustomInstallType}" | grep -q 1 || [[ "$1" == "all" ]]; then
fallbacksList=${fallbacksList}',{"path":"/'${customPath}'ws","dest":31297,"xver":1}'
getClients "${configPath}../tmp/03_VLESS_WS_inbounds.json" "${addClientsStatus}"
cat <<EOF>/etc/v2ray-agent/xray/conf/03_VLESS_WS_inbounds.json
{
"inbounds":[
{
	"port": 31297,
	"listen": "127.0.0.1",
	"protocol": "vless",
	"tag": "VLESSWS",
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
addClients "/etc/v2ray-agent/xray/conf/03_VLESS_WS_inbounds.json" "${addClientsStatus}"
fi

#trojan_grpc
if echo "${selectCustomInstallType}" | grep -q 2 || [[ "$1" == "all" ]]; then
if ! echo "${selectCustomInstallType}" | grep -q 5 && [[ -n ${selectCustomInstallType} ]]; then
fallbacksList=${fallbacksList//31302/31304}
fi
getClients "${configPath}../tmp/04_trojan_gRPC_inbounds.json" "${addClientsStatus}"
cat <<EOF >/etc/v2ray-agent/xray/conf/04_trojan_gRPC_inbounds.json
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
addClients "/etc/v2ray-agent/xray/conf/04_trojan_gRPC_inbounds.json" "${addClientsStatus}"
fi

#VMess_WS
if echo "${selectCustomInstallType}" | grep -q 3 || [[ "$1" == "all" ]]; then
fallbacksList=${fallbacksList}',{"path":"/'${customPath}'vws","dest":31299,"xver":1}'
getClients "${configPath}../tmp/05_VMess_WS_inbounds.json" "${addClientsStatus}"
cat <<EOF>/etc/v2ray-agent/xray/conf/05_VMess_WS_inbounds.json
{
"inbounds":[
{
"listen": "127.0.0.1",
"port": 31299,
"protocol": "vmess",
"tag": "VMessWS",
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
addClients "/etc/v2ray-agent/xray/conf/05_VMess_WS_inbounds.json" "${addClientsStatus}"
fi

if echo "${selectCustomInstallType}" | grep -q 5 || [[ "$1" == "all" ]]; then
getClients "${configPath}../tmp/06_VLESS_gRPC_inbounds.json" "${addClientsStatus}"
cat <<EOF >/etc/v2ray-agent/xray/conf/06_VLESS_gRPC_inbounds.json
{
"inbounds":[
{
"port": 31301,
"listen": "127.0.0.1",
"protocol": "vless",
"tag": "VLESSGRPC",
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
addClients "/etc/v2ray-agent/xray/conf/06_VLESS_gRPC_inbounds.json" "${addClientsStatus}"
fi

# VLESS_TCP
getClients "${configPath}../tmp/02_VLESS_TCP_inbounds.json" "${addClientsStatus}"
local defaultPort=443
if [[ -n "${customPort}" ]]; then
defaultPort=${customPort}
fi

cat <<EOF >/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json
{
"inbounds":[
{
"port": ${defaultPort},
"protocol": "vless",
"tag": "VLESSTCP",
"settings": {
"clients": [
{
"id": "${uuid}",
"add": "${add}",
"flow": "xtls-rprx-vision,none",
"email": "default_VLESS_TCP/XTLS"
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
"usage": "encipherment"
}
]
}
}
}
]
}
EOF
addClients "/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json" "${addClientsStatus}"
}

#Initialize Trojan -Go configuration
initTrojanGoConfig() {

echoContent skyBlue "\nProgress $ 1/${totalProgress} : Initialize Trojan configuration "
cat <<EOF>/etc/v2ray-agent/trojan/config_full.json
{
"run_type": "server",
"local_addr": "127.0.0.1",
"local_port": 31296,
"remote_addr": "127.0.0.1",
"remote_port": 31300,
"disable_http_check": true,
"log_level": 3,
"log_file": "/etc/v2ray-agent/trojan/trojan.log",
"password": [
"${uuid}"
],
"dns":[
"localhost"
],
"transport_plugin": {
"enabled": true,
"type": "plaintext"
},
"websocket": {
"enabled": true,
"path": "/${customPath}tws",
"host": "${domain}",
"add": "${add}"
},
"router": {
"enabled": false
}
}
EOF
}

#Custom CDN IP
customCDNIP() {
echoContent skyBlue "\nProgress $ 1/${totalProgress}: add cloudflare optional CNAME"
echoContent red "\n=============================================== =================="
echoContent yellow " #Notes "
echoContent yellow "\nTutorial address :"
echoContent skyBlue "https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md"
echoContent red "\nIf you don't understand Cloudflare optimization, please do not use "
echoContent yellow "\n 1.CNAME www.digitalocean.com"
echoContent yellow "2.CNAME who.int"
echoContent yellow "3.CNAME blog.hostmonit.com"

echoContent skyBlue "----------------------------"
read -r -p " Please select [ Enter is not used ]:" selectCloudflareType
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
echoContent yellow "\n ---> not used "
;;
esac
}
#universal _
defaultBase64Code() {
local type=$1
local email=$2
local id=$3

port=${currentDefaultPort}

local subAccount
subAccount=$(echo "${email}" | awk -F "[_]" '{print $1}')_$(echo "${id}_currentHost" | md5sum | awk '{print $1}')
if [[ "${type}" == "vlesstcp" ]]; then

if [[ "${coreInstallType}" == "1" ]] && echo "${currentInstallProtocolType}" | grep -q 0; then
echoContent yellow " ---> General format (VLESS+TCP+TLS/xtls-rprx-vision)"
echoContent green " vless://${id}@${currentHost}:${currentDefaultPort}?encryption=none&security=tls&type=tcp&host=${currentHost}&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision# ${email}\n"

echoContent yellow " ---> formatted plaintext (VLESS+TCP+TLS/xtls-rprx-vision)"
echoContent green " Protocol type : VLESS , address : ${currentHost} , port : ${currentDefaultPort} , user ID: ${id} , security : tls , transmission method : tcp , flow: xtls-rprx-vision , account name :${email}\n"
cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${currentHost}:${currentDefaultPort}?encryption=none&security=tls&type=tcp&host=${currentHost}&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision#${email }
EOF
echoContent yellow " ---> QR code VLESS(VLESS+TCP+TLS/xtls-rprx-vision)"
echoContent green " https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${currentHost}%3A${currentDefaultPort}% 3Fencryption%3Dnone%26security%3Dtls%26type%3Dtcp%26${currentHost}%3D${currentHost}%26headerType%3Dnone%26sni%3D${currentHost}%26flow%3Dxtls-rprx-vision%23${email}\ n"

echoContent skyBlue "----------------------------------------------- --------------------------------------"

elif [[ "${coreInstallType}" == 2 ]]; then
echoContent yellow " ---> General format (VLESS+TCP+TLS)"
echoContent green "vless://${id}@${currentHost}:${currentDefaultPort}?security=tls&encryption=none&host=${currentHost}&headerType=none&type=tcp#${email}\n"

echoContent yellow " ---> formatted plaintext (VLESS+TCP+TLS)"
echoContent green " Protocol type : VLESS , address : ${currentHost} , port : ${currentDefaultPort} , user ID: ${id} , security : tls , transmission method : tcp , account name : ${email}\n"

cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${currentHost}:${currentDefaultPort}?security=tls&encryption=none&host=${currentHost}&headerType=none&type=tcp#${email}
EOF
echoContent yellow " ---> QR code VLESS(VLESS+TCP+TLS)"
echoContent green " https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3a%2f%2f${id}%40${currentHost}%3a${currentDefaultPort}% 3fsecurity%3dtls%26encryption%3dnone%26host%3d${currentHost}%26headerType%3dnone%26type%3dtcp%23${email}\n"
fi

elif [[ "${type}" == "trojanTCPXTLS" ]]; then
echoContent yellow " ---> General format (Trojan+TCP+TLS/xtls-rprx-vision)"
echoContent green " trojan://${id}@${currentHost}:${currentDefaultPort}?encryption=none&security=xtls&type=tcp&host=${currentHost}&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision# ${email}\n"

echoContent yellow " ---> format plaintext (Trojan+TCP+TLS/xtls-rprx-vision)"
echoContent green " Protocol type : Trojan , address : ${currentHost} , port : ${currentDefaultPort} , user ID: ${id} , security : xtls , transmission method : tcp , flow: xtls-rprx-vision , account name :${email}\n"
cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${currentHost}:${currentDefaultPort}?encryption=none&security=xtls&type=tcp&host=${currentHost}&headerType=none&sni=${currentHost}&flow=xtls-rprx-vision#${email }
EOF
echoContent yellow " ---> QR code Trojan(Trojan+TCP+TLS/xtls-rprx-vision)"
echoContent green " https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3A%2F%2F${id}%40${currentHost}%3A${currentDefaultPort}% 3Fencryption%3Dnone%26security%3Dxtls%26type%3Dtcp%26${currentHost}%3D${currentHost}%26headerType%3Dnone%26sni%3D${currentHost}%26flow%3Dxtls-rprx-vision%23${email}\ n"

elif [[ "${type}" == "vmessws" ]]; then
qrCodeBase64Default=$(echo -n "{\"port\":${currentDefaultPort},\"ps\":\"${email}\",\"tls\":\"tls\",\"id \":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${currentHost}\",\"type\":\" "none\",\"path\":\"/${currentPath}vws\",\"net\":\"ws\",\"add\":\"${currentAdd}\",\ "allowInsecure\":0,\"method\":\"none\",\"peer\":\"${currentHost}\",\"sni\":\"${currentHost}\"}" | base64 -w 0)
qrCodeBase64Default="${qrCodeBase64Default// /}"

echoContent yellow " ---> Generic json(VMess+WS+TLS)"
echoContent green " {\"port\":${currentDefaultPort},\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\" ${id}\",\"aid\":0,\"v\":2,\"host\":\"${currentHost}\",\"type\":\"none\", \"path\":\"/${currentPath}vws\",\"net\":\"ws\",\"add\":\"${currentAdd}\",\"allowInsecure\": 0,\"method\":\"none\",\"peer\":\"${currentHost}\",\"sni\":\"${currentHost}\"}\n"
echoContent yellow "---> General vmess(VMess+WS+TLS) link "
echoContent green "vmess://${qrCodeBase64Default}\n"
echoContent yellow " ---> QR code vmess(VMess+WS+TLS)"

cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vmess://${qrCodeBase64Default}
EOF
echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

elif [[ "${type}" == "vlessws" ]]; then

echoContent yellow " ---> General format (VLESS+WS+TLS)"
echoContent green " vless://${id}@${currentAdd}:${currentDefaultPort}?encryption=none&security=tls&type=ws&host=${currentHost}&sni=${currentHost}&path=/${currentPath}ws#$ {email}\n"

echoContent yellow " ---> formatted plaintext (VLESS+WS+TLS)"
echoContent green " Protocol type : VLESS , address : ${currentAdd} , masquerade domain name /SNI: ${currentHost} , port : ${currentDefaultPort} , user ID: ${id} , security : tls , transmission method : ws , Path : /${currentPath}ws , account name : ${email}\n"

cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${currentAdd}:${currentDefaultPort}?encryption=none&security=tls&type=ws&host=${currentHost}&sni=${currentHost}&path=/${currentPath}ws#${email}
EOF

echoContent yellow " ---> QR code VLESS(VLESS+WS+TLS)"
echoContent green " https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${currentAdd}%3A${currentDefaultPort}% 3Fencryption%3Dnone%26security%3Dtls%26type%3Dws%26host%3D${currentHost}%26sni%3D${currentHost}%26path%3D%252f${currentPath}ws%23${email}"

elif [[ "${type}" == "vlessgrpc" ]]; then

echoContent yellow " ---> General format (VLESS+gRPC+TLS)"
echoContent green " vless://${id}@${currentAdd}:${currentDefaultPort}?encryption=none&secure =tls&type=grpc&host=${currentHost}&path=${currentPath}grpc&serviceName=${currentPath}grpc&alpn=h2&sni =${currentHost}#${email}\n"

echoContent yellow " ---> formatted plaintext (VLESS+gRPC+TLS)"
echoContent green " Protocol type : VLESS , address : ${currentAdd} , masquerade domain name /SNI: ${currentHost} , port : ${currentDefaultPort} , user ID: ${id} , security : tls , transmission method : gRPC , alpn:h2 , serviceName:${currentPath}grpc , account name : ${email}\n"

cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${currentAdd}:${currentDefaultPort}?encryption=none&security=tls&type=grpc&host=${currentHost}&path=${currentPath}grpc&serviceName=${currentPath}grpc&alpn=h2&sni=${currentHost }#${email}
EOF
echoContent yellow " ---> QR code VLESS(VLESS+gRPC+TLS)"
echoContent green " https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${currentAdd}%3A${currentDefaultPort}% 3Fencryption%3Dnone%26security%3Dtls%26type%3Dgrpc%26host%3D${currentHost}%26serviceName%3D${currentPath}grpc%26path%3D${currentPath}grpc%26sni%3D${currentHost}%26alpn%3Dh2% 23${email}"

elif [[ "${type}" == "trojan" ]]; then
#URLEncode
echoContent yellow " ---> Trojan(TLS)"
echoContent green "trojan://${id}@${currentHost}:${currentDefaultPort}?peer=${currentHost}&sni=${currentHost}&alpn=http/1.1#${currentHost}_Trojan\n"

cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${currentHost}:${currentDefaultPort}?peer=${currentHost}&sni=${currentHost}&alpn=http/1.1#${email}_Trojan
EOF
echoContent yellow " ---> QR code Trojan(TLS)"
echoContent green " https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${currentHost}%3a${port}% 3fpeer%3d${currentHost}%26sni%3d${currentHost}%26alpn%3Dhttp/1.1%23${email}\n"

elif [[ "${type}" == "trojangrpc" ]]; then
#URLEncode

echoContent yellow " ---> Trojan gRPC(TLS)"
echoContent green " trojan://${id}@${currentAdd}:${currentDefaultPort}?encryption=none&peer=${currentHost}&security=tls&type=grpc&sni=${currentHost}&alpn=h2&path=${currentPath}trojangrpc&serviceName= ${currentPath}trojangrpc#${email}\n"
cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${currentAdd}:${currentDefaultPort}?encryption=none&peer=${currentHost}&security=tls&type=grpc&sni=${currentHost}&alpn=h2&path=${currentPath}trojangrpc&serviceName=${currentPath }trojangrpc#${email}
EOF
echoContent yellow " ---> QR code Trojan gRPC(TLS)"
echoContent green " https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${currentAdd}%3a${currentDefaultPort}% 3Fencryption%3Dnone%26security%3Dtls%26peer%3d${currentHost}%26type%3Dgrpc%26sni%3d${currentHost}%26path%3D${currentPath}trojangrpc%26alpn%3Dh2%26serviceName%3D${currentPath}trojangrpc% 23${email}\n"

elif [[ "${type}" == "hysteria" ]]; then
echoContent yellow " ---> Hysteria(TLS)"
echoContent green " hysteria://${currentHost}:${hysteriaPort}?protocol=${hysteriaProtocol}&auth=${id}&peer=${currentHost}&insecure=0&alpn=h3&upmbps=${hysteriaClientUploadSpeed}&downmbps=${hysteriaClientDownloadSpeed }#${email}\n"
cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
hysteria://${currentHost}:${hysteriaPort}?protocol=${hysteriaProtocol}&auth=${id}&peer=${currentHost}&insecure=0&alpn=h3&upmbps=${hysteriaClientUploadSpeed}&downmbps=${hysteriaClientDownloadSpeed}#$ {email}
EOF
echoContent yellow " ---> QR code Hysteria(TLS)"
echoContent green " https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=hysteria%3A%2F%2F${currentHost}%3A${hysteriaPort}%3Fprotocol%3D${hysteriaProtocol }%26auth%3D${id}%26peer%3D${currentHost}%26insecure%3D0%26alpn%3Dh3%26upmbps%3D${hysteriaClientUploadSpeed}%26downmbps%3D${hysteriaClientDownloadSpeed}%23${email}\n"
fi

}

#account _
showAccounts() {
readInstallType
readInstallProtocolType
readConfigHostPathUUID
readHysteriaConfig
echoContent skyBlue "\nProgress $ 1/${totalProgress} : account "
local show
# VLESS TCP
if [[ -n "${configPath}" ]]; then
show=1
if echo "${currentInstallProtocolType}" | grep -q trojan; then
echoContent skyBlue "======================= Trojan TCP TLS/XTLS-vision ===================== ===\n"
jq .inbounds[0].settings.clients ${configPath}02_trojan_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
local email=
email=$(echo "${user}" | jq -r .email)
echoContent skyBlue "\n ---> Account :${email}"
defaultBase64Code trojanTCPXTLS "${email}" "$(echo "${user}" | jq -r .password)"
done

else
echoContent skyBlue "====================== VLESS TCP TLS/XTLS-vision ==================== ===\n"
echoContent red "\n ---> If the client does not support vision , it will use the default VLESS TCP TLS . Vision can effectively avoid port blocking. Non- vision does not have this function. Please confirm before using it "
jq .inbounds[0].settings.clients ${configPath}02_VLESS_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
local email=
email=$(echo "${user}" | jq -r .email)

echoContent skyBlue "\n ---> Account :${email}"
echo
defaultBase64Code vlesstcp "${email}" "$(echo "${user}" | jq -r .id)"
done
fi

# VLESS WS
if echo ${currentInstallProtocolType} | grep -q 1; then
echoContent skyBlue "\n================================== VLESS WS TLS CDN ========= ============================\n"

jq .inbounds[0].settings.clients ${configPath}03_VLESS_WS_inbounds.json | jq -c '.[]' | while read -r user; do
local email=
email=$(echo "${user}" | jq -r .email)

echoContent skyBlue "\n ---> Account :${email}"
echo
local path="${currentPath}ws"
# 	if [[ ${coreInstallType} == "1" ]]; then
# 		echoContent yellow " There will be after the 0-RTT path of Xray , it is not compatible with the client with v2ray as the core, please delete it manually \n"
# 		path="${currentPath}ws"
#fi 	_
defaultBase64Code vlessws "${email}" "$(echo "${user}" | jq -r .id)"
done
fi

# VMess WS
if echo ${currentInstallProtocolType} | grep -q 3; then
echoContent skyBlue "\n=================================== VMess WS TLS CDN ========= ============================\n"
local path="${currentPath}vws"
if [[ ${coreInstallType} == "1" ]]; then
path="${currentPath}vws"
fi
jq .inbounds[0].settings.clients ${configPath}05_VMess_WS_inbounds.json | jq -c '.[]' | while read -r user; do
local email=
email=$(echo "${user}" | jq -r .email)

echoContent skyBlue "\n ---> Account :${email}"
echo
defaultBase64Code vmessws "${email}" "$(echo "${user}" | jq -r .id)"
done
fi

# VLESS grpc
if echo ${currentInstallProtocolType} | grep -q 5; then
echoContent skyBlue "\n================================= VLESS gRPC TLS CDN ========== ========================\n"
echoContent red "\n --->gRPC is in beta stage and may not be compatible with the client you use, please ignore if it cannot be used "
# 			local serviceName
# 			serviceName=$(jq -r .inbounds[0].streamSettings.grpcSettings.serviceName ${configPath}06_VLESS_gRPC_inbounds.json)
jq .inbounds[0].settings.clients ${configPath}06_VLESS_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do

local email=
email=$(echo "${user}" | jq -r .email)

echoContent skyBlue "\n ---> Account :${email}"
echo
defaultBase64Code vlessgrpc "${email}" "$(echo "${user}" | jq -r .id)"
done
fi
fi

# trojan tcp
if echo ${currentInstallProtocolType} | grep -q 4; then
echoContent skyBlue "\n===================================== Trojan TLS ========== ==============================\n"
jq .inbounds[0].settings.clients ${configPath}04_trojan_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
local email=
email=$(echo "${user}" | jq -r .email)
echoContent skyBlue "\n ---> Account :${email}"

defaultBase64Code trojan "${email}" "$(echo "${user}" | jq -r .password)"
done
fi

if echo ${currentInstallProtocolType} | grep -q 2; then
echoContent skyBlue "\n=================================== Trojan gRPC TLS =========== ==========================\n"
echoContent red "\n --->gRPC is in beta stage and may not be compatible with the client you use, please ignore if it cannot be used "
jq .inbounds[0].settings.clients ${configPath}04_trojan_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do
local email=
email=$(echo "${user}" | jq -r .email)

echoContent skyBlue "\n ---> Account :${email}"
echo
defaultBase64Code trojangrpc "${email}" "$(echo "${user}" | jq -r .password)"
done
fi
if echo ${currentInstallProtocolType} | grep -q 6; then
echoContent skyBlue "\n================================== Hysteria TLS ============ ========================\n"
echoContent red "\n ---> The speed of Hysteria depends on the local network environment. If it is used by QoS , the experience will be very poor. IDC may also consider it an attack, please use it with caution "

jq .auth.config ${hysteriaConfigPath}config.json | jq -r '.[]' | while read -r user; do
local defaultUser=
local uuidType=
uuidType=".id"

if [[ "${frontingType}" == "02_trojan_TCP_inbounds" ]]; then
uuidType=".password"
fi

defaultUser=$(jq '.inbounds[0].settings.clients[]|select('${uuidType}'=="'"${user}"'")' ${configPath}${frontingType}.json )
local email=
email=$(echo "${defaultUser}" | jq -r .email)

if [[ -n ${defaultUser} ]]; then
echoContent skyBlue "\n ---> Account :${email}"
echo
defaultBase64Code hysteria "${email}" "${user}"
fi

done

fi

if [[ -z ${show} ]]; then
echoContent red "---> not installed "
fi
}
#Remove nginx302 configuration _
removeNginx302() {
local count=0
grep -n "return 302" <"/etc/nginx/conf.d/alone.conf" | while read -r line; do

if ! echo "${line}" | grep -q "request_uri"; then
local removeIndex=
removeIndex=$(echo "${line}" | awk -F "[:]" '{print $1}')
removeIndex=$((removeIndex + count))
sed -i "${removeIndex}d" /etc/nginx/conf.d/alone.conf
count=$((count - 1))
fi
done
}

#Check if 302 is successful
checkNginx302() {
local domain302Status=
domain302Status=$(curl -s "https://${currentHost}")
if echo "${domain302Status}" | grep -q "302"; then
local domain302Result=
domain302Result=$(curl -L -s "https://${currentHost}")
if [[ -n "${domain302Result}" ]]; then
echoContent green " ---> 302 redirect successfully set "
exit 0
fi
fi
echoContent red "---> 302 redirection setting failed, please double check whether it is the same as the example "
backupNginxConfig restoreBackup
}

#Backup and restore nginx files
backupNginxConfig() {
if [[ "$1" == "backup" ]]; then
cp /etc/nginx/conf.d/alone.conf /etc/v2ray-agent/alone_backup.conf
echoContent green " ---> nginx configuration file backed up successfully "
fi

if [[ "$1" == "restoreBackup" ]] && [[ -f "/etc/v2ray-agent/alone_backup.conf" ]]; then
cp /etc/v2ray-agent/alone_backup.conf /etc/nginx/conf.d/alone.conf
echoContent green " ---> nginx configuration file recovery backup succeeded "
rm /etc/v2ray-agent/alone_backup.conf
fi

}
#Add 302 configuration _
addNginx302() {
# 	local line302Result=
# 	line302Result=$(| tail -n 1)
local count=1
grep -n "Strict-Transport-Security" <"/etc/nginx/conf.d/alone.conf" | while read -r line; do
if [[ -n "${line}" ]]; then
local insertIndex=
insertIndex="$(echo "${line}" | awk -F "[:]" '{print $1}')"
insertIndex=$((insertIndex + count))
sed "${insertIndex}i return 302 '$1';" /etc/nginx/conf.d/alone.conf >/etc/nginx/conf.d/tmpfile && mv /etc/nginx/conf.d/tmpfile / etc/nginx/conf.d/alone.conf
count=$((count + 1))
else
echoContent red " ---> 302 Failed to add "
backupNginxConfig restoreBackup
fi

done
}

#update camouflage station
updateNginxBlog() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : Replace the masquerade site "
echoContent red "================================================ ================"
echoContent yellow "#If you need to customize , please manually copy the template file to /usr/share/nginx/html \n"
echoContent yellow "1. Novice guide "
echoContent yellow "2. Game website "
echoContent yellow "3. Personal blog 01"
echoContent yellow "4.Enterprise site "
echoContent yellow "5. Unlock the encrypted music file template [https://github.com/ix64/unlock-music]"
echoContent yellow "6.mikutap[https://github.com/HFIProgramming/mikutap]"
echoContent yellow "7.Enterprise station 02"
echoContent yellow "8. Personal blog 02"
echoContent yellow "9.404 automatically jump to baidu"
echoContent yellow "10.302 redirection site "
echoContent red "================================================ ================"
read -r -p " Please select :" selectInstallNginxBlogType

if [[ "${selectInstallNginxBlogType}" == "10" ]]; then
echoContent red "\n=============================================== =================="
echoContent yellow " Redirection has a higher priority . If you change the fake site after configuring 302 , the fake site under the root route will not work "
echoContent yellow " If you want to fake the site to realize the function, you need to delete the 302 redirection configuration \n"
echoContent yellow " 1.Add "
echoContent yellow " 2.Delete "
echoContent red "================================================ ================"
read -r -p " Please select :" redirectStatus

if [[ "${redirectStatus}" == "1" ]]; then
backupNginxConfig backup
read -r -p " Please enter the domain name to be redirected , such as https://www.baidu.com:" redirectDomain
removeNginx302
addNginx302 "${redirectDomain}"
handle Nginx stop
handle Nginx start
if [[ -z $(pgrep -f nginx) ]]; then
backupNginxConfig restoreBackup
handle Nginx start
exit 0
fi
checkNginx302
exit 0
fi
if [[ "${redirectStatus}" == "2" ]]; then
removeNginx302
echoContent green "---> removed 302 redirect successfully "
exit 0
fi
fi
if [[ "${selectInstallNginxBlogType}" =~ ^[1-9]$ ]]; then
rm -rf /usr/share/nginx/*
if wget --help | grep -q show-progress; then
wget -c -q --show-progress -P /usr/share/nginx "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${selectInstallNginxBlogType} .zip" >/dev/null
else
wget -c -P /usr/share/nginx "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${selectInstallNginxBlogType}.zip" >/dev/ null
fi

unzip -o "/usr/share/nginx/html${selectInstallNginxBlogType}.zip" -d /usr/share/nginx/html >/dev/null
rm -f "/usr/share/nginx/html${selectInstallNginxBlogType}.zip*"
echoContent green " ---> Changing fake site successfully "
else
echoContent red " ---> wrong selection, please re-select "
updateNginxBlog
fi
}

#Add a new port
addCorePort() {
readHysteriaConfig
echoContent skyBlue "\nFunction 1 /${totalProgress} : Add new port "
echoContent red "\n=============================================== =================="
echoContent yellow "#notes \ n"
echoContent yellow " Support batch adding "
echoContent yellow " Does not affect the use of the default port "
echoContent yellow " When viewing the account, only the account with the default port will be displayed "
echoContent yellow " Special characters are not allowed , pay attention to the comma format "
echoContent yellow " If hysteria is already installed , a new port of hysteria will be installed at the same time "
echoContent yellow " Entry example : 2053,2083,2087\n"

echoContent yellow "1.Add port "
echoContent yellow "2. Delete port "
echoContent red "================================================ ================"
read -r -p " Please select :" selectNewPortType
if [[ "${selectNewPortType}" == "1" ]]; then
read -r -p " Please enter the port number :" newPort
read -r -p " Please enter the default port number, and the subscription port and node port will be changed at the same time, [ Enter ] default 443:" defaultPort

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

# open ports
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

echoContent green "---> Added successfully "
reloadCore
addCorePort
fi
elif [[ "${selectNewPortType}" == "2" ]]; then

find ${configPath} -name "*dokodemodoor*" | awk -F "[c][o][n][f][/]" '{print ""NR""":"$2}'
read -r -p " Please enter the port number to delete :" portIndex
local dokoConfig
dokoConfig=$(find ${configPath} -name "*dokodemodoor*" | awk -F "[c][o][n][f][/]" '{print ""NR""":"$2} ' | grep "${portIndex}:")
if [[ -n "${dokoConfig}" ]]; then
rm "${configPath}/$(echo "${dokoConfig}" | awk -F "[:]" '{print $2}')"
reloadCore
addCorePort
else
echoContent yellow "\n --->The input number is wrong, please choose again "
addCorePort
fi
fi
}

#uninstall script
unInstall() {
read -r -p " Are you sure to uninstall the installation content? [y/n]:" unInstallStatus
if [[ "${unInstallStatus}" != "y" ]]; then
echoContent green " ---> give up uninstall "
menu
exit 0
fi

handle Nginx stop
if [[ -z $(pgrep -f "nginx") ]]; then
echoContent green "---> stop Nginx successfully "
fi

if [[ "${coreInstallType}" == "1" ]]; then
handle Xray stop
rm -rf /etc/systemd/system/xray.service
echoContent green "---> Delete Xray start-up complete "

elif [[ "${coreInstallType}" == "2" ]]; then

handleV2Ray stop
rm -rf /etc/systemd/system/v2ray.service
echoContent green "---> Delete V2Ray boot self-start complete "

fi

if [[ -z "${hysteriaConfigPath}" ]]; then
handle Hysteria stop
rm -rf /etc/systemd/system/hysteria.service
echoContent green "---> Delete Hysteria boot self-start complete "
fi

if [[ -f "/root/.acme.sh/acme.sh.env" ]] && grep -q 'acme.sh.env' </root/.bashrc; then
sed -i 's/. "\/root\/.acme.sh\/acme.sh.env"//g' "$(grep '. "/root/.acme.sh/acme.sh.env" ' -rl /root/.bashrc)"
fi
rm -rf /root/.acme.sh
echoContent green "---> delete acme.sh done "

rm -rf /tmp/v2ray-agent-tls/*
if [[ -d "/etc/v2ray-agent/tls" ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.key") ]] && [[ -n $ (find /etc/v2ray-agent/tls/ -name "*.crt") ]]; then
mv /etc/v2ray-agent/tls /tmp/v2ray-agent-tls
if [[ -n $(find /tmp/v2ray-agent-tls -name '*.key') ]]; then
echoContent yellow " ---> The backup certificate is successful, please keep it. [/tmp/v2ray-agent-tls]"
fi
fi

rm -rf /etc/v2ray-agent
rm -rf ${nginxConfigPath}alone.conf

if [[ -d "/usr/share/nginx/html" && -f "/usr/share/nginx/html/check" ]]; then
rm -rf /usr/share/nginx/html
echoContent green " ---> Delete fake website completed "
fi

rm -rf /usr/bin/vasma
rm -rf /usr/sbin/vasma
echoContent green " ---> uninstall shortcut completed "
echoContent green "---> uninstall v2ray-agent script completed "
}

#updateGeoSite

#Modify V2Ray CDN node
updateV2RayCDN() {

# todo refactor this method
echoContent skyBlue "\nProgress $ 1/${totalProgress}: Modify CDN node "

if [[ -n "${currentAdd}" ]]; then
echoContent red "================================================ ================"
echoContent yellow "1.CNAME www.digitalocean.com"
echoContent yellow "2.CNAME who.int"
echoContent yellow "3.CNAME blog.hostmonit.com"
echoContent yellow "4. Manual input "
echoContent red "================================================ ================"
read -r -p " Please select :" selectCDNType
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
read -r -p " Please enter the CDN IP or domain name you want to customize :" setDomain
;;
esac

if [[ -n ${setDomain} ]]; then
if [[ -n "${currentAdd}" ]]; then
sed -i "s/\"${currentAdd}\"/\"${setDomain}\"/g" "$(grep "${currentAdd}" -rl ${configPath}${frontingType}.json)"
fi
if [[ $(jq -r .inbounds[0].settings.clients[0].add ${configPath}${frontingType}.json) == "${setDomain}" ]]; then
echoContent green " ---> CDN modified successfully "
reloadCore
else
echoContent red "---> Failed to modify CDN "
fi
fi
else
echoContent red "---> Available type not installed "
fi
}

# manageUser user management
manageUser() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : multi- user management "
echoContent skyBlue "----------------------------------------------- ------"
echoContent yellow "1.Add user "
echoContent yellow "2. Delete user "
echoContent skyBlue "----------------------------------------------- ------"
read -r -p " Please select :" manageUserType
if [[ "${manageUserType}" == "1" ]]; then
addUser
elif [[ "${manageUserType}" == "2" ]]; then
removeUser
else
echoContent red " ---> wrong choice "
fi
}

#custom uuid _
customUUID() {
# 	read -r -p " Do you want to customize UUID ? [y/n]:" customUUIDStatus
# 	echo
# 	if [[ "${customUUIDStatus}" == "y" ]]; then
read -r -p " Please enter a legal UUID , [ Enter ] Random UUID:" currentCustomUUID
echo
if [[ -z "${currentCustomUUID}" ]]; then
# echoContent red " ---> UUID cannot be empty "
currentCustomUUID=$(${ctlPath} uuid)
echoContent yellow "uuid:${currentCustomUUID}\n"

else
jq -r -c '.inbounds[0].settings.clients[].id' ${configPath}${frontingType}.json | while read -r line; do
if [[ "${line}" == "${currentCustomUUID}" ]]; then
echo >/tmp/v2ray-agent
fi
done
if [[ -f "/tmp/v2ray-agent" && -n $(cat /tmp/v2ray-agent) ]]; then
echoContent red " ---> UUID cannot be repeated "
rm /tmp/v2ray-agent
exit 0
fi
fi
#fi 	_
}

#custom email _
customUserEmail() {
# 	read -r -p " Do you want to customize email ? [y/n]:" customEmailStatus
# 	echo
# 	if [[ "${customEmailStatus}" == "y" ]]; then
read -r -p " Please enter a legal email , [ Enter ] random email:" currentCustomEmail
echo
if [[ -z "${currentCustomEmail}" ]]; then
currentCustomEmail="${currentCustomUUID}"
echoContent yellow "email: ${currentCustomEmail}\n"
else
jq -r -c '.inbounds[0].settings.clients[].email' ${configPath}${frontingType}.json | while read -r line; do
if [[ "${line}" == "${currentCustomEmail}" ]]; then
echo >/tmp/v2ray-agent
fi
done
if [[ -f "/tmp/v2ray-agent" && -n $(cat /tmp/v2ray-agent) ]]; then
echoContent red " ---> email cannot be repeated "
rm /tmp/v2ray-agent
exit 0
fi
fi
#fi 	_
}

#add user
addUser() {

echoContent yellow " After adding a new user , you need to check the subscription again "
read -r -p " Please enter the number of users to add :" userNum
echo
if [[ -z ${userNum} || ${userNum} -le 0 ]]; then
echoContent red "---> Input error, please re-enter "
exit 0
fi

# generate user
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

#Compatible 	with v2ray-core
users="{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-vision,none\",\"email\":\"${email}\ ",\"alterId\":0}"

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
local trojanXTLUsers="${users//\,\"alterId\":0/}"
trojanXTLUsers="${trojanXTLUsers//${email}/${email}_Trojan_TCP}"
trojanXTLUsers=${trojanXTLUsers//"id"/"password"}

local trojanXTLSResult
trojanXTLSResult=$(jq -r ".inbounds[0].settings.clients += [${trojanXTLSUsers}]" ${configPath}${frontingType}.json)
echo "${trojanXTLSResult}" | jq . >${configPath}${frontingType}.json
fi

if echo ${currentInstallProtocolType} | grep -q 1; then
local vlessUsers="${users//\,\"alterId\":0/}"
vlessUsers="${vlessUsers//${email}/${email}_VLESS_TCP}"
vlessUsers="${vlessUsers//\"flow\":\"xtls-rprx-vision,none\"\,/}"
local vlessWsResult
vlessWsResult=$(jq -r ".inbounds[0].settings.clients += [${vlessUsers}]" ${configPath}03_VLESS_WS_inbounds.json)
echo "${vlessWsResult}" | jq . >${configPath}03_VLESS_WS_inbounds.json
fi

if echo ${currentInstallProtocolType} | grep -q 2; then
local trojangRPCUsers="${users//\"flow\":\"xtls-rprx-vision,none\"\,/}"
trojangRPUsers="${trojangRPUsers//${email}/${email}_Trojan_gRPC}"
trojangRPUsers="${trojangRPUsers//\,\"alterId\":0/}"
trojangRPUsers=${trojangRPUsers//"id"/"password"}

local trojangRPCResult
trojangRPCResult=$(jq -r ".inbounds[0].settings.clients += [${trojangRPCUsers}]" ${configPath}04_trojan_gRPC_inbounds.json)
echo "${trojangRPCResult}" | jq . >${configPath}04_trojan_gRPC_inbounds.json
fi

if echo ${currentInstallProtocolType} | grep -q 3; then
local vmessUsers="${users//\"flow\":\"xtls-rprx-vision,none\"\,/}"
vmessUsers="${vmessUsers//${email}/${email}_VMess_TCP}"
local vmessWsResult
vmessWsResult=$(jq -r ".inbounds[0].settings.clients += [${vmessUsers}]" ${configPath}05_VMess_WS_inbounds.json)
echo "${vmessWsResult}" | jq . >${configPath}05_VMess_WS_inbounds.json
fi

if echo ${currentInstallProtocolType} | grep -q 5; then
local vlessGRPCUsers="${users//\"flow\":\"xtls-rprx-vision,none\"\,/}"
vlessGRPCUsers="${vlessGRPCUsers//\,\"alterId\":0/}"
vlessGRPCUsers="${vlessGRPCUsers//${email}/${email}_VLESS_gRPC}"
local vlessGRPCResult
vlessGRPCResult=$(jq -r ".inbounds[0].settings.clients += [${vlessGRPCUsers}]" ${configPath}06_VLESS_gRPC_inbounds.json)
echo "${vlessGRPCResult}" | jq . >${configPath}06_VLESS_gRPC_inbounds.json
fi

if echo ${currentInstallProtocolType} | grep -q 4; then
local trojanUsers="${users//\"flow\":\"xtls-rprx-vision,none\"\,/}"
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
echoContent green " ---> Add completed "
manageAccount 1
}

# remove user
removeUser() {

if echo ${currentInstallProtocolType} | grep -q 0 || echo ${currentInstallProtocolType} | grep -q trojan; then
jq -r -c .inbounds[0].settings.clients[].email ${configPath}${frontingType}.json | awk '{print NR""":"$0}'
read -r -p " Please select the user number to delete [ only supports single deletion ]:" delUserIndex
if [[ $(jq -r '.inbounds[0].settings.clients|length' ${configPath}${frontingType}.json) -lt ${delUserIndex} ]]; then
echoContent red " ---> wrong choice "
else
delUserIndex=$((delUserIndex - 1))
local vlessTcpResult
vlessTcpResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}${frontingType}.json)
echo "${vlessTcpResult}" | jq . >${configPath}${frontingType}.json
fi
fi
if [[ -n "${delUserIndex}" ]]; then
if echo ${currentInstallProtocolType} | grep -q 1; then
local vlessWSResult
vlessWSResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}03_VLESS_WS_inbounds.json)
echo "${vlessWSResult}" | jq . >${configPath}03_VLESS_WS_inbounds.json
fi

if echo ${currentInstallProtocolType} | grep -q 2; then
local trojang RPC Users
trojangRPCUrs=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}04_trojan_gRPC_inbounds.json)
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

reloadCore
fi
manageAccount 1
}
#update script
updateV2RayAgent() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : update v2ray-agent script "
rm -rf /etc/v2ray-agent/install.sh
if wget --help | grep -q show-progress; then
wget -c -q --show-progress -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install .sh"
else
wget -c -q -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
fi

sudo chmod 700 /etc/v2ray-agent/install.sh
local version
version=$(grep ' current version : v' "/etc/v2ray-agent/install.sh" | awk -F "[v]" '{print $2}' | tail -n +2 | head -n 1 | awk -F "[\"]" '{print $1}')

echoContent green "\n ---> updated "
echoContent yellow " ---> Please manually execute [vasma] to open the script "
echoContent green " ---> current version : ${version}\n"
echoContent yellow " If the update is unsuccessful, please manually execute the following command \n"
echoContent skyBlue "wget -P /root -N --no-check-certificate https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh && chmod 700 /root/install.sh && /root/install.sh"
echo
exit 0
}

#firewall _
handleFirewall() {
if systemctl status ufw 2>/dev/null | grep -q "active (exited)" && [[ "$1" == "stop" ]]; then
systemctl stop ufw >/dev/null 2>&1
systemctl disable ufw >/dev/null 2>&1
echoContent green " ---> ufw closed successfully "

fi

if systemctl status firewalld 2>/dev/null | grep -q "active (running)" && [[ "$1" == "stop" ]]; then
systemctl stop firewalld >/dev/null 2>&1
systemctl disable firewalld >/dev/null 2>&1
echoContent green " ---> firewalld closed successfully "
fi
}

# install bbr
bbrInstall() {
echoContent red "\n=============================================== =================="
echoContent green " The mature works of [ylx2016] for BBR and DD scripts , the address [https://github.com/ylx2016/Linux-NetSpeed] , please familiarize yourself "
echoContent yellow "1. Installation script【recommended original BBR+FQ 】 "
echoContent yellow "2. Rollback home directory "
echoContent red "================================================ ================"
read -r -p " Please select :" installBBRStatus
if [[ "${installBBRStatus}" == "1" ]]; then
wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
else
menu
fi
}

#View , check log
checkLog() {
if [[ -z ${configPath} ]]; then
echoContent red "--->The installation directory is not detected, please execute the script to install the content "
fi
local logStatus=false
if grep -q "access" ${configPath}00_log.json; then
logStatus=true
fi

echoContent skyBlue "\nFunction $ 1/${totalProgress} : view log "
echoContent red "\n=============================================== =================="
echoContent yellow "#It is recommended to open the access log only when debugging \n"

if [[ "${logStatus}" == "false" ]]; then
echoContent yellow "1. Open access log "
else
echoContent yellow "1. Close access log "
fi

echoContent yellow "2. Listen to access logs "
echoContent yellow "3. Listening to error logs "
echoContent yellow "4. Check the certificate scheduled task log "
echoContent yellow "5. Check the certificate installation log "
echoContent yellow "6. Clear the log "
echoContent red "================================================ ================"

read -r -p " Please select :" selectAccessLogType
local configPathLog=${configPath//conf\//}

case ${selectAccessLogType} in
1)
if [[ "${logStatus}" == "false" ]]; then
cat <<EOF >${configPath}00_log.json
{
"log": {
  	"access": "${configPathLog}access.log",
"error": "${configPathLog}error.log",
"loglevel": "debug"
}
}
EOF
elif [[ "${logStatus}" == "true" ]]; then
cat <<EOF >${configPath}00_log.json
{
"log": {
"error": "${configPathLog}error.log",
"loglevel": "warning"
}
}
EOF
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

# script shortcut
aliasInstall() {

if [[ -f "$HOME/install.sh" ]] && [[ -d "/etc/v2ray-agent" ]] && grep <"$HOME/install.sh" -q " author :mack-a" ; then
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
echoContent green " Shortcut created successfully, you can execute [vasma] to reopen the script "
fi
fi
}

#check ipv6 , ipv4 _
checkIPv6() {
# pingIPv6=$(ping6 -c 1 www.google.com | sed '2{s/[^(]*(//;s/).*//;q;}' | tail -n +2)
pingIPv6=$(ping6 -c 1 www.google.com | sed -n '1p' | sed 's/.*(//g;s/).*//g')

if [[ -z "${pingIPv6}" ]]; then
echoContent red " ---> does not support ipv6"
exit 0
fi
}

# ipv6 shunt
ipv6Routing() {
if [[ -z "${configPath}" ]]; then
echoContent red " ---> not installed, please use the script to install "
menu
exit 0
fi

checkIPv6
echoContent skyBlue "\nFunction 1 /${totalProgress} : IPv6 streaming "
echoContent red "\n=============================================== =================="
echoContent yellow "1. Add domain name "
echoContent yellow "2. Offload IPv6 traffic "
echoContent red "================================================ ================"
read -r -p " Please select :" ipv6Status
if [[ "${ipv6Status}" == "1" ]]; then
echoContent red "================================================ ================"
echoContent yellow "#notes \ n"
echoContent yellow "1. The rule only supports the predefined domain name list [https://github.com/v2fly/domain-list-community]"
echoContent yellow "2. Detailed documentation [https://www.v2fly.org/config/routing.html]"
echoContent yellow "3. If the kernel fails to start , please check the domain name and add the domain name again "
echoContent yellow "4. Special characters are not allowed , pay attention to the comma format "
echoContent yellow "5. Each addition is re-added, and the last domain name will not be retained "
echoContent yellow "6. It is strongly recommended to block domestic websites, enter [ cn ] below to block "
echoContent yellow "7. Input example : google, youtube, facebook, cn\n"
read -r -p " Please enter the domain name according to the above example :" domainList

if [[ -f "${configPath}09_routing.json" ]]; then

unInstallRouting IPv6-out outboundTag

routing=$(jq -r ".routing.rules += [{\"type\":\"field\",\"domain\":[\"geosite:${domainList//,/\",\ "geosite:}\"],\"outboundTag\":\"IPv6-out\"}]" ${configPath}09_routing.json)

echo "${routing}" | jq . >${configPath}09_routing.json

else
cat <<EOF >"${configPath}09_routing.json"
{
"routing": {
"domainStrategy": "IPOnDemand",
"rules": [
{
"type": "field",
"domain": [
            	"geosite:${domainList//,/\",\"geosite:}"
],
"outboundTag": "IPv6-out"
}
]
}
}
EOF
fi

unInstallOutbounds IPv6-out

outbounds=$(jq -r '.outbounds += [{"protocol":"freedom","settings":{"domainStrategy":"UseIPv6"},"tag":"IPv6-out"}]' ${ configPath}10_ipv4_outbounds.json)

echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

echoContent green "---> Added successfully "

elif [[ "${ipv6Status}" == "2" ]]; then

unInstallRouting IPv6-out outboundTag

unInstallOutbounds IPv6-out

echoContent green " ---> IPv6 offloading successfully "
else
echoContent red " ---> wrong choice "
exit 0
fi

reloadCore
}

# bt download management
btTools() {
if [[ -z "${configPath}" ]]; then
echoContent red " ---> not installed, please use the script to install "
menu
exit 0
fi

echoContent skyBlue "\nFunction 1 /${totalProgress} : bt download management "
echoContent red "\n=============================================== =================="

if [[ -f ${configPath}09_routing.json ]] && grep -q bittorrent <${configPath}09_routing.json; then
echoContent yellow " Current Status : Disabled "
else
echoContent yellow " current state : not disabled "
fi

echoContent yellow "1. Disabled "
echoContent yellow " 2.Open "
echoContent red "================================================ ================"
read -r -p " Please select :" btStatus
if [[ "${btStatus}" == "1" ]]; then

if [[ -f "${configPath}09_routing.json" ]]; then

unInstallRouting blackhole-out outboundTag

routing=$(jq -r '.routing.rules += [{"type":"field","outboundTag":"blackhole-out","protocol":["bittorrent"]}]' ${configPath} 09_routing.json)

echo "${routing}" | jq . >${configPath}09_routing.json

else
cat <<EOF >${configPath}09_routing.json
{
"routing": {
"domainStrategy": "IPOnDemand",
"rules": [
{
"type": "field",
"outboundTag": "blackhole-out",
"protocol": ["bittorrent"]
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

echoContent green " ---> BT download disabled successfully "

elif [[ "${btStatus}" == "2" ]]; then

unInstallSniffing

unInstallRouting blackhole-out outboundTag bittorrent

# 		unInstallOutbounds blackhole-out

echoContent green " ---> BT download opened successfully "
else
echoContent red " ---> wrong choice "
exit 0
fi

reloadCore
}

#Domain Blacklist
blacklist() {
if [[ -z "${configPath}" ]]; then
echoContent red " ---> not installed, please use the script to install "
menu
exit 0
fi

echoContent skyBlue "\nProgress $ 1/${totalProgress} : domain name blacklist "
echoContent red "\n=============================================== =================="
echoContent yellow "1. Add domain name "
echoContent yellow "2. Delete blacklist "
echoContent red "================================================ ================"
read -r -p " Please select :" blacklistStatus
if [[ "${blacklistStatus}" == "1" ]]; then
echoContent red "================================================ ================"
echoContent yellow "#notes \ n"
echoContent yellow "1. The rule only supports the predefined domain name list [https://github.com/v2fly/domain-list-community]"
echoContent yellow "2. Detailed documentation [https://www.v2fly.org/config/routing.html]"
echoContent yellow "3. If the kernel fails to start , please check the domain name and add the domain name again "
echoContent yellow "4. Special characters are not allowed , pay attention to the comma format "
echoContent yellow "5. Each addition is re-added, and the last domain name will not be retained "
echoContent yellow "6. Input example : speedtest,facebook,cn\n"
read -r -p " Please enter the domain name according to the above example :" domainList

if [[ -f "${configPath}09_routing.json" ]]; then
unInstallRouting blackhole-out outboundTag

routing=$(jq -r ".routing.rules += [{\"type\":\"field\",\"domain\":[\"geosite:${domainList//,/\",\ "geosite:}\"],\"outboundTag\":\"blackhole-out\"}]" ${configPath}09_routing.json)

echo "${routing}" | jq . >${configPath}09_routing.json

else
cat <<EOF >${configPath}09_routing.json
{
"routing": {
"domainStrategy": "IPOnDemand",
"rules": [
{
"type": "field",
"domain": [
            	"geosite:${domainList//,/\",\"geosite:}"
],
"outboundTag": "blackhole-out"
}
]
}
}
EOF
fi

echoContent green "---> Added successfully "

elif [[ "${blacklistStatus}" == "2" ]]; then

unInstallRouting blackhole-out outboundTag

echoContent green "---> Domain name blacklist deleted successfully "
else
echoContent red " ---> wrong choice "
exit 0
fi
reloadCore
}

#Uninstall Routing according to tag
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
routing=$(jq -r 'del(.routing.rules['"$(("${index}" - 1))"'])' ${configPath}09_routing.json)
echo "${routing}" | jq . >${configPath}09_routing.json
fi
done
fi
fi
}

#Unload outbound according to tag
unInstallOutbounds() {
local tag=$1

if grep -q "${tag}" ${configPath}10_ipv4_outbounds.json; then
local ipv6OutIndex
ipv6OutIndex=$(jq .outbounds[].tag ${configPath}10_ipv4_outbounds.json | awk '{print ""NR""":"$0}' | grep "${tag}" | awk -F "[:] " '{print $1}' | head -1)
if [[ ${ipv6OutIndex} -gt 0 ]]; then
routing=$(jq -r 'del(.outbounds['$(("${ipv6OutIndex}" - 1))'])' ${configPath}10_ipv4_outbounds.json)
echo "${routing}" | jq . >${configPath}10_ipv4_outbounds.json
fi
fi

}

# uninstall sniffing
unInstallSniffing() {

find ${configPath} -name "*inbounds.json*" | awk -F "[c][o][n][f][/]" '{print $2}' | while read -r inbound; do
sniffing=$(jq -r 'del(.inbounds[0].sniffing)' "${configPath}${inbound}")
echo "${sniffing}" | jq . > "${configPath}${inbound}"
done
}

# Install sniffing
installSniffing() {

find ${configPath} -name "*inbounds.json*" | awk -F "[c][o][n][f][/]" '{print $2}' | while read -r inbound; do
sniffing=$(jq -r '.inbounds[0].sniffing = {"enabled":true,"destOverride":["http","tls"]}' "${configPath}${inbound}")
echo "${sniffing}" | jq . > "${configPath}${inbound}"
done
}

# warp split
warpRouting() {
echoContent skyBlue "\nProgress $ 1/${totalProgress} : WARP split "
echoContent red "================================================ ================"
# 	echoContent yellow "#Notes \ n"
# 	echoContent yellow "1. The official warp has bugs after several rounds of testing . Restarting will cause the warp to fail and fail to start , and the CPU usage may skyrocket "
# 	echoContent yellow "2. It can be used normally without restarting the machine. If you must use the official warp , it is recommended not to restart the machine "
# 	echoContent yellow "3. Some machines still work normally after restarting "
# 	echoContent yellow "4. It cannot be used after restarting , and it can also be uninstalled and reinstalled "
#install warp _
if [[ -z $(which warp-cli) ]]; then
echo
read -r -p "WARP is not installed, is it installed ? [y/n]: "installCloudflareWarpStatus
if [[ "${installCloudflareWarpStatus}" == "y" ]]; then
installWarp
else
echoContent yellow " ---> give up installation "
exit 0
fi
fi

echoContent red "\n=============================================== =================="
echoContent yellow "1. Add domain name "
echoContent yellow "2. Uninstall WARP shunt "
echoContent red "================================================ ================"
read -r -p " Please select :" warpStatus
if [[ "${warpStatus}" == "1" ]]; then
echoContent red "================================================ ================"
echoContent yellow "#notes \ n"
echoContent yellow "1. The rule only supports the predefined domain name list [https://github.com/v2fly/domain-list-community]"
echoContent yellow "2. Detailed documentation [https://www.v2fly.org/config/routing.html]"
echoContent yellow "3. You can only divert traffic to warp , and you cannot specify ipv4 or ipv6"
echoContent yellow "4. If the kernel fails to start , please check the domain name and add the domain name again "
echoContent yellow "5. Special characters are not allowed , pay attention to the comma format "
echoContent yellow "6. Each addition is a new addition, and the last domain name will not be retained "
echoContent yellow "7. Input example : google, youtube, facebook\n"
read -r -p " Please enter the domain name according to the above example :" domainList

if [[ -f "${configPath}09_routing.json" ]]; then
unInstallRouting warp-socks-out outboundTag

routing=$(jq -r ".routing.rules += [{\"type\":\"field\",\"domain\":[\"geosite:${domainList//,/\",\ "geosite:}\"],\"outboundTag\":\"warp-socks-out\"}]" ${configPath}09_routing.json)

echo "${routing}" | jq . >${configPath}09_routing.json

else
cat <<EOF >${configPath}09_routing.json
{
"routing": {
"domainStrategy": "IPOnDemand",
"rules": [
{
"type": "field",
"domain": [
            	"geosite:${domainList//,/\",\"geosite:}"
],
"outboundTag": "warp-socks-out"
}
]
}
}
EOF
fi
unInstallOutbounds warp-socks-out

local outbounds
outbounds=$(jq -r '.outbounds += [{"protocol":"socks","settings":{"servers":[{"address":"127.0.0.1","port":31303}] },"tag":"warp-socks-out"}]' ${configPath}10_ipv4_outbounds.json)

echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

echoContent green "---> Added successfully "

elif [[ "${warpStatus}" == "2" ]]; then

${removeType} cloudflare-warp >/dev/null 2>&1

unInstallRouting warp-socks-out outboundTag

unInstallOutbounds warp-socks-out

echoContent green " ---> WARP shunt unloading succeeded "
else
echoContent red " ---> wrong choice "
exit 0
fi
reloadCore
}
#Streaming Toolbox
streamingToolbox() {
echoContent skyBlue "\nFunction 1 /${totalProgress} : Streaming Media Toolbox "
echoContent red "\n=============================================== =================="
# 	echoContent yellow "1.Netflix detection "
echoContent yellow "1. Any door landing machine unlocks streaming media "
echoContent yellow "2.DNS unlock streaming media "
echoContent yellow "3.VMess+WS+TLS to unlock streaming media "
read -r -p " Please select :" selectType

case ${selectType} in
1)
dokodemoDoorUnblockStreamingMedia
;;
2)
dnsUnlock Netflix
;;
3)
unblockVMessWSTLSStreamingMedia
;;
esac

}

#anydoor unlock streaming
dokodemoDoorUnblockStreamingMedia() {
echoContent skyBlue "\nFunction 1 /${totalProgress} : Unlock streaming media on any floor machine "
echoContent red "\n=============================================== =================="
echoContent yellow " #Notes "
echoContent yellow " For details on unlocking any door, please check this article [https://github.com/mack-a/v2ray-agent/blob/master/documents/netflix/dokodemo-unblock_netflix.md]\n"

echoContent yellow "1. Add outbound "
echoContent yellow "2. Add inbound "
echoContent yellow "3. Uninstall "
read -r -p " Please select :" selectType

case ${selectType} in
1)
setDokodemoDoorUnblockStreamingMediaOutbounds
;;
2)
setDokodemoDoorUnblockStreamingMediaInbounds
;;
3)
removeDokodemoDoorUnblockStreamingMedia
;;
esac
}

# VMess+WS+TLS play to unlock streaming media [outbound only]
unblockVMessWSTLSStreamingMedia() {
echoContent skyBlue "\nFunction 1 /${totalProgress} : VMess+WS+TLS outbound unlock streaming media "
echoContent red "\n=============================================== =================="
echoContent yellow " #Notes "
echoContent yellow " Suitable for VMess unlocking services provided by other service providers \n"

echoContent yellow "1. Add outbound "
echoContent yellow "2. Uninstall "
read -r -p " Please select :" selectType

case ${selectType} in
1)
setVMessWSTLSUnblockStreamingMediaOutbounds
;;
2)
removeVMessWSTLSUnblockStreamingMedia
;;
esac
}

#Set VMess +WS+TLS to unlock Netflix [ outbound only]
setVMessWSTLSUnblockStreamingMediaOutbounds() {
read -r -p " Please enter the address to unlock the streaming media VMess+WS+TLS :" setVMessWSTLSAddress
echoContent red "================================================ ================"
echoContent yellow "#notes \ n"
echoContent yellow "1. The rule only supports the predefined domain name list [https://github.com/v2fly/domain-list-community]"
echoContent yellow "2. Detailed documentation [https://www.v2fly.org/config/routing.html]"
echoContent yellow "3. If the kernel fails to start , please check the domain name and add the domain name again "
echoContent yellow "4. Special characters are not allowed , pay attention to the comma format "
echoContent yellow "5. Each addition is re-added, and the last domain name will not be retained "
echoContent yellow "6. Input example : netflix, disney, hulu\n"
read -r -p " Please enter the domain name according to the above example :" domainList

if [[ -z ${domainList} ]]; then
echoContent red " --->The domain name cannot be empty "
setVMessWSTLSUnblockStreamingMediaOutbounds
fi

if [[ -n "${setVMessWSTLSAddress}" ]]; then

unInstallOutbounds VMess-out

echo
read -r -p " Please enter the port of VMess+WS+TLS :" setVMessWSTLSPort
echo
if [[ -z "${setVMessWSTLSPort}" ]]; then
echoContent red "--->The port cannot be empty "
fi

read -r -p " Please enter the UUID of VMess+WS+TLS :" setVMessWSTLSUUID
echo
if [[ -z "${setVMessWSTLSUUID}" ]]; then
echoContent red " ---> UUID cannot be empty "
fi

read -r -p " Please enter the Path of VMess +WS+TLS :" setVMessWSTLSPath
echo
if [[ -z "${setVMessWSTLSPath}" ]]; then
echoContent red " ---> path cannot be empty "
fi

outbounds=$(jq -r ".outbounds += [{\"tag\":\"VMess-out\",\"protocol\":\"vmess\",\"streamSettings\":{\"network \":\"ws\",\"security\":\"tls\",\"tlsSettings\":{\"allowInsecure\":false},\"wsSettings\":{\"path\": \"${setVMessWSTLSPath}\"}},\"mux\":{\"enabled\":true,\"concurrency\":8},\"settings\":{\"vnext\":[{ \"address\":\"${setVMessWSTLSAddress}\",\"port\":${setVMessWSTLSPort},\"users\":[{\"id\":\"${setVMessWSTLSUUID}\",\ "security\":\"auto\",\"alterId\":0}]}]}}]" ${configPath}10_ipv4_outbounds.json)

echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

if [[ -f "${configPath}09_routing.json" ]]; then
unInstallRouting VMess-out outboundTag

local routing

routing=$(jq -r ".routing.rules += [{\"type\":\"field\",\"domain\":[\"ip.sb\",\"geosite:${domainList //,/\",\"geosite:}\"],\"outboundTag\":\"VMess-out\"}]" ${configPath}09_routing.json)

echo "${routing}" | jq . >${configPath}09_routing.json
else
cat <<EOF >${configPath}09_routing.json
{
"routing": {
"rules": [
{
"type": "field",
"domain": [
"ip.sb",
"geosite:${domainList//,/\",\"geosite:}"
],
"outboundTag": "VMess-out"
}
]
}
}
EOF
fi
reloadCore
echoContent green " ---> Added outbound unlock successfully "
exit 0
fi
echoContent red "---> Address cannot be empty "
setVMessWSTLSUnblockStreamingMediaOutbounds
}

#Set any door to unlock Netflix 【Outbound】
setDokodemoDoorUnblockStreamingMediaOutbounds() {
read -r -p " Please enter the IP to unlock the streaming vps :" setIP
echoContent red "================================================ ================"
echoContent yellow "#notes \ n"
echoContent yellow "1. The rule only supports the predefined domain name list [https://github.com/v2fly/domain-list-community]"
echoContent yellow "2. Detailed documentation [https://www.v2fly.org/config/routing.html]"
echoContent yellow "3. If the kernel fails to start , please check the domain name and add the domain name again "
echoContent yellow "4. Special characters are not allowed , pay attention to the comma format "
echoContent yellow "5. Each addition is re-added, and the last domain name will not be retained "
echoContent yellow "6. Input example : netflix, disney, hulu\n"
read -r -p " Please enter the domain name according to the above example :" domainList

if [[ -z ${domainList} ]]; then
echoContent red " --->The domain name cannot be empty "
setDokodemoDoorUnblockStreamingMediaOutbounds
fi

if [[ -n "${setIP}" ]]; then

unInstallOutbounds streamingMedia-80
unInstallOutbounds streamingMedia-443

outbounds=$(jq -r ".outbounds += [{\"tag\":\"streamingMedia-80\",\"protocol\":\"freedom\",\"settings\":{\"domainStrategy \":\"AsIs\",\"redirect\":\"${setIP}:22387\"}},{\"tag\":\"streamingMedia-443\",\"protocol\":\ "freedom\",\"settings\":{\"domainStrategy\":\"AsIs\",\"redirect\":\"${setIP}:22388\"}}]" ${configPath}10_ipv4_outbounds. json)

echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

if [[ -f "${configPath}09_routing.json" ]]; then
unInstallRouting streamingMedia-80 outboundTag
unInstallRouting streamingMedia-443 outboundTag

local routing

routing=$(jq -r ".routing.rules += [{\"type\":\"field\",\"port\":80,\"domain\":[\"ip.sb\" ,\"geosite:${domainList//,/\",\"geosite:}\"],\"outboundTag\":\"streamingMedia-80\"},{\"type\":\"field\ ",\"port\":443,\"domain\":[\"ip.sb\",\"geosite:${domainList//,/\",\"geosite:}\"],\" outboundTag\":\"streamingMedia-443\"}]" ${configPath}09_routing.json)

echo "${routing}" | jq . >${configPath}09_routing.json
else
cat <<EOF >${configPath}09_routing.json
{
"routing": {
"domainStrategy": "AsIs",
"rules": [
{
"type": "field",
"port": 80,
"domain": [
"ip.sb",
"geosite:${domainList//,/\",\"geosite:}"
],
"outboundTag": "streamingMedia-80"
},
{
"type": "field",
"port": 443,
"domain": [
"ip.sb",
"geosite:${domainList//,/\",\"geosite:}"
],
"outboundTag": "streamingMedia-443"
}
]
}
}
EOF
fi
reloadCore
echoContent green " ---> Added outbound unlock successfully "
exit 0
fi
echoContent red " ---> ip cannot be empty "
}

#Set any door to unlock Netflix 【Inbound】
setDokodemoDoorUnblockStreamingMediaInbounds() {

echoContent skyBlue "\nFunction 1 /${totalProgress} : Any door added inbound "
echoContent red "\n=============================================== =================="
echoContent yellow "#notes \ n"
echoContent yellow "1. The rule only supports the predefined domain name list [https://github.com/v2fly/domain-list-community]"
echoContent yellow "2. Detailed documentation [https://www.v2fly.org/config/routing.html]"
echoContent yellow "3. If the kernel fails to start , please check the domain name and add the domain name again "
echoContent yellow "4. Special characters are not allowed , pay attention to the comma format "
echoContent yellow "5. Each addition is re-added, and the last domain name will not be retained "
echoContent yellow "6.ip entry example : 1.1.1.1,1.1.1.2"
echoContent yellow "7. The domain name below must be consistent with the outgoing vps "
# 	echoContent yellow "8. If there is a firewall , please manually open ports 22387 and 22388 "
echoContent yellow "8. Example of domain name entry : netflix, disney, hulu\n"
read -r -p " Please enter the IP that is allowed to access the unlocked vps :" setIPs
if [[ -n "${setIPs}" ]]; then
read -r -p " Please enter the domain name according to the above example :" domainList
allowPort 22387
allowPort 22388

cat <<EOF >${configPath}01_netflix_inbounds.json
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
"tag": "streamingMedia-80"
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
"tag": "streamingMedia-443"
}
]
}
EOF

cat <<EOF >${configPath}10_ipv4_outbounds.json
{
"outbounds":[
{
"protocol": "freedom",
"settings": {
"domainStrategy": "UseIPv4"
},
"tag": "IPv4-out"
},
{
"protocol": "freedom",
"settings": {
"domainStrategy": "UseIPv6"
},
"tag": "IPv6-out"
},
{
"protocol": "blackhole",
"tag": "blackhole-out"
}
]
}
EOF

if [[ -f "${configPath}09_routing.json" ]]; then
unInstallRouting streamingMedia-80 inboundTag
unInstallRouting streamingMedia-443 inboundTag

local routing
routing=$(jq -r ".routing.rules += [{\"source\":[\"${setIPs//,/\",\"}\"],\"type\":\" field\",\"inboundTag\":[\"streamingMedia-80\",\"streamingMedia-443\"],\"outboundTag\":\"direct\"},{\"domains\":[\ "geosite:${domainList//,/\",\"geosite:}\"],\"type\":\"field\",\"inboundTag\":[\"streamingMedia-80\",\ "streamingMedia-443\"],\"outboundTag\":\"blackhole-out\"}]" ${configPath}09_routing.json)
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
"type": "field",
"inboundTag": [
"streamingMedia-80",
"streamingMedia-443"
],
"outboundTag": "direct"
},
{
"domains": [
                    	"geosite:${domainList//,/\",\"geosite:}"
],
"type": "field",
"inboundTag": [
"streamingMedia-80",
"streamingMedia-443"
],
"outboundTag": "blackhole-out"
}
]
}
}
EOF

fi

reloadCore
echoContent green " ---> Add landing machine inbound and unlock successfully "
exit 0
fi
echoContent red " ---> ip cannot be empty "
}

#Remove any door to unlock Netflix
removeDokodemoDoorUnblockStreamingMedia() {

unInstallOutbounds streamingMedia-80
unInstallOutbounds streamingMedia-443

unInstallRouting streamingMedia-80 inboundTag
unInstallRouting streamingMedia-443 inboundTag

unInstallRouting streamingMedia-80 outboundTag
unInstallRouting streamingMedia-443 outboundTag

rm -rf ${configPath}01_netflix_inbounds.json

reloadCore
echoContent green " ---> uninstalled successfully "
}

#Remove VMess +WS+TLS to unlock streaming media
removeVMessWSTLSUnblockStreamingMedia() {

unInstallOutbounds VMess-out

unInstallRouting VMess-out outboundTag

reloadCore
echoContent green " ---> uninstalled successfully "
}

# restart core
reloadCore() {
if [[ "${coreInstallType}" == "1" ]]; then
handle Xray stop
handle Xray start
elif [[ "${coreInstallType}" == "2" ]]; then
handleV2Ray stop
handleV2Ray start
fi

if [[ -n "${hysteriaConfigPath}" ]]; then
handle Hysteria stop
handle Hysteria start
fi
}

# dns unblock Netflix
dnsUnlockNetflix() {
if [[ -z "${configPath}" ]]; then
echoContent red " ---> not installed, please use the script to install "
menu
exit 0
fi
echoContent skyBlue "\nFunction 1 /${totalProgress} : DNS unblock streaming "
echoContent red "\n=============================================== =================="
echoContent yellow " 1.Add "
echoContent yellow "2. Uninstall "
read -r -p " Please select :" selectType

case ${selectType} in
1)
setUnlockDNS
;;
2)
removeUnlockDNS
;;
esac
}

#Set dns _
setUnlockDNS() {
read -r -p " Please enter to unlock streaming DNS:" setDNS
if [[ -n ${setDNS} ]]; then
echoContent red "================================================ ================"
echoContent yellow "#notes \ n"
echoContent yellow "1. The rule only supports the predefined domain name list [https://github.com/v2fly/domain-list-community]"
echoContent yellow "2. Detailed documentation [https://www.v2fly.org/config/routing.html]"
echoContent yellow "3. If the kernel fails to start , please check the domain name and add the domain name again "
echoContent yellow "4. Special characters are not allowed , pay attention to the comma format "
echoContent yellow "5. Each addition is re-added, and the last domain name will not be retained "
echoContent yellow "6. Input example : netflix, disney, hulu"
echoContent yellow "7. Please enter 1 for the default scheme. The default scheme includes the following content "
echoContent yellow "netflix,bahamut,hulu,hbo,disney,bbc,4chan,fox,abema,dmm,niconico,pixiv,bilibili,viu"
read -r -p " Please enter the domain name according to the above example :" domainList
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

echoContent yellow "\n ---> If you still can't watch it, you can try the following two solutions "
echoContent yellow " 1. Restart vps"
echoContent yellow " 2. After uninstalling dns to unlock , modify the local [/etc/resolv.conf]DNS settings and restart the vps\n"
else
echoContent red " ---> dns cannot be empty "
fi
exit 0
}

# remove Netflix unblock
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

echoContent green " ---> uninstalled successfully "

exit 0
}

# v2ray-core personalized installation
customV2RayInstall() {
echoContent skyBlue "\n========================== Personalized installation ==================== ==========="
echoContent yellow "VLESS front, 0 is installed by default , if you only need to install 0 , just select 0 "
echoContent yellow "0.VLESS+TLS/XTLS+TCP"
echoContent yellow "1.VLESS+TLS+WS[CDN]"
echoContent yellow "2.Trojan+TLS+gRPC[CDN]"
echoContent yellow "3.VMess+TLS+WS[CDN]"
echoContent yellow "4.Trojan+TLS"
echoContent yellow "5.VLESS+TLS+gRPC[CDN]"
read -r -p " Please select [ multiple choices ] , [ eg : 123]:" selectCustomInstallType
echoContent skyBlue "----------------------------------------------- ---------------"
if [[ -z ${selectCustomInstallType} ]]; then
selectCustomInstallType=0
fi
if [[ "${selectCustomInstallType}" =~ ^[0-5]+$ ]]; then
cleanUp xrayClean
totalProgress=17
installTools1
#apply for tls
initTLSNginxConfig 2
installTLS 3
handle Nginx stop
#random path _
if echo ${selectCustomInstallType} | grep -q 1 || echo ${selectCustomInstallType} | grep -q 3 || echo ${selectCustomInstallType} | grep -q 4; then
randomPathFunction 5
customCDNIP 6
fi
nginxBlog 7
updateRedirectNginxConf
handle Nginx start

#Install V2Ray _
installV2Ray 8
installV2RayService 9
initV2RayConfig custom 10
cleanUp xrayDel
install CronTLS 14
handleV2Ray stop
handleV2Ray start
# generate account
checkGFWStatue 15
showAccounts 16
else
echoContent red " --->Invalid input "
customV2RayInstall
fi
}

# Xray-core personalized installation
customXrayInstall() {
echoContent skyBlue "\n========================== Personalized installation ==================== ==========="
echoContent yellow "VLESS front, 0 is installed by default , if you only need to install 0 , just select 0 "
echoContent yellow "0.VLESS+TLS/XTLS+TCP"
echoContent yellow "1.VLESS+TLS+WS[CDN]"
echoContent yellow "2.Trojan+TLS+gRPC[CDN]"
echoContent yellow "3.VMess+TLS+WS[CDN]"
echoContent yellow "4.Trojan+TLS"
echoContent yellow "5.VLESS+TLS+gRPC[CDN]"
read -r -p " Please select [ multiple choices ] , [ eg : 123]:" selectCustomInstallType
echoContent skyBlue "----------------------------------------------- ---------------"
if [[ -z ${selectCustomInstallType} ]]; then
echoContent red " ---> cannot be empty "
customXrayInstall
elif [[ "${selectCustomInstallType}" =~ ^[0-5]+$ ]]; then
cleanUp v2rayClean
totalProgress=17
installTools1
#apply for tls
initTLSNginxConfig 2
handle Xray stop
handle Nginx start
checkIP

installTLS 3
handle Nginx stop
#random path _
if echo "${selectCustomInstallType}" | grep -q 1 || echo "${selectCustomInstallType}" | grep -q 2 || echo "${selectCustomInstallType}" | grep -q 3 || echo "${selectCustomInstallType}" | grep -q 5; then
randomPathFunction 5
customCDNIP 6
fi
nginxBlog 7
updateRedirectNginxConf
handle Nginx start

#Install V2Ray _
installXray8
installXrayService9
initXrayConfig custom 10
cleanUp v2rayDel

install CronTLS 14
handle Xray stop
handle Xray start
# generate account
checkGFWStatue 15
showAccounts 16
else
echoContent red " --->Invalid input "
customXrayInstall
fi
}

#Select core installation --- v2ray-core , xray-core
selectCoreInstall() {
echoContent skyBlue "\nFeature 1 /${totalProgress} : select core installation "
echoContent red "\n=============================================== =================="
echoContent yellow "1.Xray-core"
echoContent yellow "2.v2ray-core"
echoContent red "================================================ ================"
read -r -p " Please select :" selectCoreType
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
echoContent red ' ---> selection error, re-select '
selectCoreInstall
;;
esac
}

#v2ray- coreinstallation
v2rayCoreInstall() {
cleanUp xrayClean
selectCustomInstallType=
totalProgress=13
installTools2
#apply for tls
initTLSNginxConfig 3

handleV2Ray stop
handle Nginx start
checkIP

installTLS 4
handle Nginx stop
#initNginxConfig 	5
randomPathFunction 5
#Install V2Ray _
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
handle Nginx start
# generate account
checkGFWStatue 12
showAccounts 13
}

- coreinstallation
xrayCoreInstall() {
cleanUp v2rayClean
selectCustomInstallType=
totalProgress=13
installTools2
#apply for tls
initTLSNginxConfig 3

handle Xray stop
handle Nginx start
checkIP

installTLS 4
handle Nginx stop
randomPathFunction 5
#installXray _ _
# handleV2Ray stop
installXray6
installXrayService7
customCDNIP 8
initXrayConfig all 9
cleanUp v2rayDel
installCronTLS 10
nginxBlog 11
updateRedirectNginxConf
handle Xray stop
sleep 2
handle Xray start

handle Nginx start
# generate account
checkGFWStatue 12
showAccounts 13
}
#HysteriaInstall _
hysteriaCoreInstall() {
if [[ -z "${coreInstallType}" ]]; then
echoContent red "\n ---> Because of environmental dependence, if you install hysteria , please install Xray/V2ray first"
menu
exit 0
fi
totalProgress=5
install Hysteria 1
initHysteriaConfig2
install HysteriaService 3
handle Hysteria stop
handle Hysteria start
showAccounts 5
}
#uninstall hysteria _
unInstallHysteriaCore() {

if [[ -z "${hysteriaConfigPath}" ]]; then
echoContent red "\n ---> not installed "
exit 0
fi
handle Hysteria stop
rm -rf /etc/v2ray-agent/hysteria/*
rm -rf /etc/systemd/system/hysteria.service
echoContent green "---> Uninstall complete "
}

#core management
coreVersionManageMenu() {

if [[ -z "${coreInstallType}" ]]; then
echoContent red "\n ---> The installation directory is not detected, please execute the script to install the content "
menu
exit 0
fi
if [[ "${coreInstallType}" == "1" ]]; then
xrayVersionManageMenu1
elif [[ "${coreInstallType}" == "2" ]]; then
v2rayCoreVersion=
v2rayVersionManageMenu1
fi
}
#Timed task check certificate
cronRenewTLS() {
if [[ "${renewTLS}" == "RenewTLS" ]]; then
renewalTLS
exit 0
fi
}
#Account management
manageAccount() {
echoContent skyBlue "\nFunction 1 /${totalProgress}: account management "
echoContent red "\n=============================================== =================="
echoContent yellow "#Every time you delete or add an account, you need to re-check the subscription to generate a subscription "
echoContent yellow "#Customize email and uuid when adding a single user "
echoContent yellow "#If Hysteria is installed , the account will be added to Hysteria\n"
echoContent yellow "1. View account "
echoContent yellow "2. View subscription "
echoContent yellow "3. Add user "
echoContent yellow "4. Delete user "
echoContent red "================================================ ================"
read -r -p " Please enter :" manageAccountStatus
if [[ "${manageAccountStatus}" == "1" ]]; then
showAccounts1
elif [[ "${manageAccountStatus}" == "2" ]]; then
subscribe 1
elif [[ "${manageAccountStatus}" == "3" ]]; then
addUser
elif [[ "${manageAccountStatus}" == "4" ]]; then
removeUser
else
echoContent red " ---> wrong choice "
fi
}

#subscribe _
subscribe() {
if [[ -n "${configPath}" ]]; then
echoContent skyBlue "------------------------- Note --------------------- ------------"
echoContent yellow "#The subscription will be regenerated when viewing the subscription "
echoContent yellow "#Every time you add or delete an account, you need to check the subscription again "
rm -rf /etc/v2ray-agent/subscribe/*
rm -rf /etc/v2ray-agent/subscribe_tmp/*
showAccounts >/dev/null
mv /etc/v2ray-agent/subscribe_tmp/* /etc/v2ray-agent/subscribe/

if [[ -n $(ls /etc/v2ray-agent/subscribe/) ]]; then
find /etc/v2ray-agent/subscribe/* | while read -r email; do
email=$(echo "${email}" | awk -F "[b][e][/]" '{print $2}')

local base64Result
base64Result=$(base64 -w 0 "/etc/v2ray-agent/subscribe/${email}")
echo "${base64Result}" > "/etc/v2ray-agent/subscribe/${email}"
echoContent skyBlue "----------------------------------------------- ---------------"
echoContent yellow "email:${email}\n"
local currentDomain=${currentHost}

if [[ -n "${currentDefaultPort}" && "${currentDefaultPort}" != "443" ]]; then
currentDomain="${currentHost}:${currentDefaultPort}"
fi

echoContent yellow "url:https://${currentDomain}/s/${email}\n"
echoContent yellow " Online QR code : https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://${currentDomain}/s/${email}\n"
echo "https://${currentDomain}/s/${email}" | qrencode -s 10 -m 1 -t UTF8
echoContent skyBlue "----------------------------------------------- ---------------"
done
fi
else
echoContent red "---> not installed "
fi
}

# switch alpn
switchAlpn() {
echoContent skyBlue "\nFunction 1 /${totalProgress} : switch alpn"
if [[ -z ${currentAlpn} ]]; then
echoContent red " ---> cannot read alpn , please check whether it is installed "
exit 0
fi

echoContent red "\n=============================================== =================="
echoContent green "The current alpn first is : ${currentAlpn}"
echoContent yellow " 1. When http/1.1 is first , trojan is available, and some gRPC clients are available [the client supports manual selection of alpn available] "
echoContent yellow " 2. When h2 is first , gRPC is available, and some clients of trojan are available [the client supports manual selection of alpn available] "
echoContent yellow " 3. If the client does not support changing the alpn manually , it is recommended to use this function to change the alpn order of the server to use the corresponding protocol "
echoContent red "================================================ ================"

if [[ "${currentAlpn}" == "http/1.1" ]]; then
echoContent yellow "1. Switch alpn h2 first "
elif [[ "${currentAlpn}" == "h2" ]]; then
echoContent yellow "1. Switch alpn http/1.1 first "
else
echoContent red ' does not match '
fi

echoContent red "================================================ ================"

read -r -p " Please select :" selectSwitchAlpnType
if [[ "${selectSwitchAlpnType}" == "1" && "${currentAlpn}" == "http/1.1" ]]; then

local frontingTypeJSON
frontingTypeJSON=$(jq -r ".inbounds[0].streamSettings.tlsSettings.alpn = [\"h2\",\"http/1.1\"]" ${configPath}${frontingType}.json)
echo "${frontingTypeJSON}" | jq . >${configPath}${frontingType}.json

elif [[ "${selectSwitchAlpnType}" == "1" && "${currentAlpn}" == "h2" ]]; then
local frontingTypeJSON
frontingTypeJSON=$(jq -r ".inbounds[0].streamSettings.tlsSettings.alpn =[\"http/1.1\",\"h2\"]" ${configPath}${frontingType}.json)
echo "${frontingTypeJSON}" | jq . >${configPath}${frontingType}.json
else
echoContent red " ---> wrong choice "
exit 0
fi
reloadCore
}

# hysteria management
manageHysteria() {

echoContent skyBlue "\nProgress 1/1 : Hysteria Management "
echoContent red "\n=============================================== =================="
local hysteriaStatus=
if [[ -n "${hysteriaConfigPath}" ]]; then
echoContent yellow "1. Reinstall "
echoContent yellow "2. Uninstall "
echoContent yellow "3. Update core"
echoContent yellow "4. View logs "
hysteriaStatus=true
else
echoContent yellow "1. Install "
fi

echoContent red "================================================ ================"
read -r -p " Please select :" installHysteriaStatus
if [[ "${installHysteriaStatus}" == "1" ]]; then
hysteriaCoreInstall
elif [[ "${installHysteriaStatus}" == "2" && "${hysteriaStatus}" == "true" ]]; then
unInstallHysteriaCore
elif [[ "${installHysteriaStatus}" == "3" && "${hysteriaStatus}" == "true" ]]; then
install Hysteria 1
handle Hysteria start
elif [[ "${installHysteriaStatus}" == "4" && "${hysteriaStatus}" == "true" ]]; then
journalctl -fu hysteria
fi
}

geoIRAN() {
echoContent red "TEST, PERSONAL USAGE"
echoContent green "/etc/v2ray-agent/xray/conf/09_routing.json will be replaced with custom one"
cd /etc/v2ray-agent/xray/conf/
rm routing.json
curl -O https://raw.githubusercontent.com/ExtremeDot/vpn_setups/master/09_routing.json
sleep 2
cp /etc/v2ray-agent/xray/conf/09_routing.json /etc/v2ray-agent/v2ray/conf/09_routing.json
cp /etc/v2ray-agent/xray/conf/09_routing.json /etc/v2ray-agent/trojan/conf/09_routing.json
sleep 2
reloadCore
}


#main menu
menu() {
cd "$HOME" || exit
echoContent red "\n=============================================== =================="
echoContent green " Author :mack-a"
echoContent green " Current version : v2.6.25"
echoContent green "Github:https://github.com/mack-a/v2ray-agent"
echoContent green " Description : 8-in-1 coexistence script \c"
showInstallStatus
echoContent red "\n=============================================== =================="
echoContent red " promotion area "
echoContent green "AFF donation : https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md\n"
echoContent red "================================================ ================"
if [[ -n "${coreInstallType}" ]]; then
echoContent yellow "1. Reinstall "
else
echoContent yellow "1. Install "
fi

echoContent yellow "2. Install in any combination "
if echo ${currentInstallProtocolType} | grep -q trojan; then
echoContent yellow "3. Switch VLESS[XTLS]"
elif echo ${currentInstallProtocolType} | grep -q 0; then
echoContent yellow "3. Toggle Trojan[XTLS]"
fi

echoContent yellow "4.Hysteria management "
echoContent skyBlue "----------------------- tool management ------------------- ---------"
echoContent yellow "5. Account Management "
echoContent yellow "6. Replace camouflage station "
echoContent yellow "7. Update certificate "
echoContent yellow "8. Replace CDN node "
echoContent yellow "9. IPv6 diversion "
echoContent yellow "10. WARP diversion "
echoContent yellow "11. Streaming media tools "
echoContent yellow "12. Add new port "
echoContent yellow "13. BT download management "
echoContent yellow "14. Switch alpn"
echoContent yellow "15. Domain name blacklist "
echoContent skyBlue "-------------------------- version management -------------------- ---------"
echoContent yellow "16.core management "
echoContent yellow "17. Update script "
echoContent yellow "18. Install BBR and DD scripts "
echoContent skyBlue "----------------------- script management ------------------- ---------"
echoContent yellow "19. View logs "
echoContent yellow "20. Uninstall script "
echoContent yellow "21. Updating Routing and Geo For IRAN "
echoContent red "================================================ ================"
mkdirTools
alias Install
read -r -p " Please select :" selectInstallType
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
manage Hysteria
;;
5)
manageAccount 1
;;
6)
updateNginxBlog 1
;;
7)
renewal TLS 1
;;
8)
updateV2RayCDN 1
;;
9)
ipv6Routing 1
;;
10)
warpRouting 1
;;
11)
streaming Toolbox 1
;;
12)
addCorePort 1
;;
13)
btTools 1
;;
14)
switch Alpn 1
;;
15)
blacklist 1
;;
16)
coreVersionManageMenu1
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
21)
geoIRAN
;;
esac
}
cronRenewTLS
menu
