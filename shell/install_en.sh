#!/usr/bin/env bash
# Detection area
# -------------------------------------------------------------
# Inspection system
export LANG=en_US.UTF-8

echoContent() {
	case $1 in
	# Red
	"red")
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
		# yellow
	"yellow")
		${echoType} "\033[33m${printN}$2 \033[0m"
		;;
	esac
}
checkSystem() {
	if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
		mkdir -p /etc/yum.repos.d

		if [[ -f "/etc/centos-release" ]];then
			centosVersion=$(rpm -q centos-release | awk -F "[-]" '{print $3}' | awk -F "[.]" '{print $1}')

			if [[ -z "${centosVersion}" ]] && grep </etc/centos-release -q -i "release 8"; then
				centosVersion=8
			fi
		fi

		release="centos"
		installType='yum -y install'
		removeType='yum -y remove'
		upgrade="yum update -y --skip-broken"

	elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
		if grep </etc/issue -i "8"; then
			debianVersion=8
		fi
		release="debian"
		installType='apt -y install'
		upgrade="apt update"
		removeType='apt -y autoremove'

	elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
		release="ubuntu"
		installType='apt -y install'
		upgrade="apt update"
		removeType='apt -y autoremove'
		if grep </etc/issue -q -i "16.";then
			release=
		fi
	fi

	if [[ -z ${release} ]]; then
		echoContent red "\n This script does not support this system, please feed back the following logs to developers \ n"
		echoContent yellow "$(cat /etc/issue)"
		echoContent yellow "$(cat /proc/version)"
		exit 0
	fi
}

# Check the CPU provider
checkCPUVendor() {
	if [[ -n $(which uname) ]]; then
		if [[ "$(uname)" == "Linux" ]];then
			case "$(uname -m)" in
			'amd64' | 'x86_64')
				xrayCoreCPUVendor="Xray-linux-64"
				v2rayCoreCPUVendor="v2ray-linux-64"
				trojanGoCPUVendor="trojan-go-linux-amd64"
			;;
			'armv8' | 'aarch64')
        		xrayCoreCPUVendor="Xray-linux-arm64-v8a"
				v2rayCoreCPUVendor="v2ray-linux-arm64-v8a"
				trojanGoCPUVendor="trojan-go-linux-armv8"
        	;;
			*)
        		echo "  Does not support this CPU architecture --->"
        		exit 1
        	;;
    		esac
		fi
	else
		echoContent red "  Unable to recognize this CPU architecture, default AMD64, X86_64--->"
		xrayCoreCPUVendor="Xray-linux-64"
		v2rayCoreCPUVendor="v2ray-linux-64"
		trojanGoCPUVendor="trojan-go-linux-amd64"
	fi
}

# Initialization global variable
initVar() {
	installType='yum -y install'
	removeType='yum -y remove'
	upgrade="yum -y update"
	echoType='echo -e'

	# Core supported CPU version
	xrayCoreCPUVendor=""
	v2rayCoreCPUVendor=""
	trojanGoCPUVendor=""
	# domain name
	domain=

    # Cdn node Address
	add=

	# Total installation
	totalProgress=1

	# 1.xray-core Install
	# 2.v2ray-core Install
	# 3.v2ray-core[xtls] Install
	coreInstallType=

	# Core installation PATH
	# coreInstallPath=

	# v2ctl Path
	ctlPath=
	# 1.All installation
	# 2.Personalization installation
	# v2rayAgentInstallType=

	# Current personalization installation method 01234
	currentInstallProtocolType=

	# Pre-type
	frontingType=

	# Selected personalized installation method
	selectCustomInstallType=

	# v2ray-core、xray-core Path of the configuration file
	configPath=

	# Profile path
	currentPath=

	# Profile host
	currentHost=

	# Selected when installing core Types of
	selectCoreType=

	# Default Core version
	v2rayCoreVersion=

	# Random path
	customPath=

	# centos version
	centosVersion=

	# UUID
	currentUUID=

	# pingIPv6 pingIPv4
	# pingIPv4=
	pingIP=
	pingIPv6=
	localIP=

	# Integrated Update Certificate Logic No longer use separate scripts--RenewTLS
	renewTLS=$1

	# Number of attempts after a failed tls installation
	installTLSCount=
}

# Detection installation method
readInstallType() {
	coreInstallType=
	configPath=

	# 1.Detection installation directory
	if [[ -d "/etc/v2ray-agent" ]]; then
		# Detection installation method v2ray-core
		if [[ -d "/etc/v2ray-agent/v2ray" && -f "/etc/v2ray-agent/v2ray/v2ray" && -f "/etc/v2ray-agent/v2ray/v2ctl" ]]; then
			if [[ -d "/etc/v2ray-agent/v2ray/conf" && -f "/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json" ]]; then
				configPath=/etc/v2ray-agent/v2ray/conf/

				if ! grep </etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json -q xtls; then
					# V2ray without XTLS-core
					coreInstallType=2
					# coreInstallPath=/etc/v2ray-agent/v2ray/v2ray
					ctlPath=/etc/v2ray-agent/v2ray/v2ctl
				elif grep </etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json -q xtls; then
					# V2ray with XTLS-core
					# coreInstallPath=/etc/v2ray-agent/v2ray/v2ray
					ctlPath=/etc/v2ray-agent/v2ray/v2ctl
					coreInstallType=3
				fi
			fi
		fi

		if [[ -d "/etc/v2ray-agent/xray" && -f "/etc/v2ray-agent/xray/xray" ]]; then
			# Test Xray here-core
			if [[ -d "/etc/v2ray-agent/xray/conf" ]] && [[ -f "/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json" || -f "/etc/v2ray-agent/xray/conf/02_trojan_TCP_inbounds.json" ]]; then
				# xray-core
				configPath=/etc/v2ray-agent/xray/conf/
				# coreInstallPath=/etc/v2ray-agent/xray/xray
				ctlPath=/etc/v2ray-agent/xray/xray
				coreInstallType=1
			fi
		fi
	fi
}

# Read protocol type
readInstallProtocolType() {
	currentInstallProtocolType=

	while read -r row; do
		if echo ${row} | grep -q 02_trojan_TCP_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'trojan'
			frontingType=02_trojan_TCP_inbounds
		fi
		if echo ${row} | grep -q VLESS_TCP_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'0'
			frontingType=02_VLESS_TCP_inbounds
		fi
		if echo ${row} | grep -q VLESS_WS_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'1'
		fi
		if echo ${row} | grep -q trojan_gRPC_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'2'
		fi
		if echo ${row} | grep -q VMess_WS_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'3'
		fi
		if echo ${row} | grep -q 04_trojan_TCP_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'4'
		fi
		if echo ${row} | grep -q VLESS_gRPC_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'5'
		fi

	done < <(ls ${configPath} | grep inbounds.json | awk -F "[.]" '{print $1}')
}

# Check file directory and path path
readConfigHostPathUUID() {
	currentPath=
	currentUUID=
	currentHost=
	currentPort=
	currentAdd=
	# 读取path
	if [[ -n "${configPath}" ]]; then
		local fallback=$(jq -r -c '.inbounds[0].settings.fallbacks[]|select(.path)' ${configPath}${frontingType}.json|head -1)

		local path=$(echo "${fallback}"|jq -r .path|awk -F "[/]" '{print $2}')

		if [[ $(echo "${fallback}"|jq -r .dest) == 31297 ]]; then
			currentPath=$(echo "${path}" | awk -F "[w][s]" '{print $1}')
		elif [[ $(echo "${fallback}"|jq -r .dest) == 31298 ]]; then
			currentPath=$(echo "${path}" | awk -F "[t][c][p]" '{print $1}')
		elif [[ $(echo "${fallback}"|jq -r .dest) == 31299 ]]; then
			currentPath=$(echo "${path}" | awk -F "[v][w][s]" '{print $1}')
		fi
	fi

	if [[ "${coreInstallType}" == "1" ]]; then
		currentHost=$(jq -r .inbounds[0].streamSettings.xtlsSettings.certificates[0].certificateFile ${configPath}${frontingType}.json | awk -F '[t][l][s][/]' '{print $2}' | awk -F '[.][c][r][t]' '{print $1}')
		currentUUID=$(jq -r .inbounds[0].settings.clients[0].id ${configPath}${frontingType}.json)
		currentAdd=$(jq -r .inbounds[0].settings.clients[0].add ${configPath}${frontingType}.json)
		if [[ "${currentAdd}" == "null" ]];then
			currentAdd=${currentHost}
		fi
		currentPort=$(jq .inbounds[0].port ${configPath}${frontingType}.json)

	elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
		if [[ "${coreInstallType}" == "3" ]]; then
			currentHost=$(jq -r .inbounds[0].streamSettings.xtlsSettings.certificates[0].certificateFile ${configPath}${frontingType}.json | awk -F '[t][l][s][/]' '{print $2}' | awk -F '[.][c][r][t]' '{print $1}')
		else
			currentHost=$(jq -r .inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile ${configPath}${frontingType}.json | awk -F '[t][l][s][/]' '{print $2}' | awk -F '[.][c][r][t]' '{print $1}')
		fi
		currentAdd=$(jq -r .inbounds[0].settings.clients[0].add ${configPath}${frontingType}.json)

		if [[ "${currentAdd}" == "null" ]];then
			currentAdd=${currentHost}
		fi
		currentUUID=$(jq -r .inbounds[0].settings.clients[0].id ${configPath}${frontingType}.json)
		currentPort=$(jq .inbounds[0].port ${configPath}${frontingType}.json)
	fi
}

# Status display
showInstallStatus() {
	if [[ -n "${coreInstallType}" ]]; then
		if [[ "${coreInstallType}" == 1 ]]; then
			if [[ -n $(pgrep -f xray/xray) ]]; then
				echoContent yellow "\n core: xray-core[Run in operation]"
			else
				echoContent yellow "\n core: xray-core[Not running]"
			fi

		elif [[ "${coreInstallType}" == 2 || "${coreInstallType}" == 3 ]]; then
			if [[ -n $(pgrep -f v2ray/v2ray) ]]; then
				echoContent yellow "\n core: v2ray-core[Run in operation]"
			else
				echoContent yellow "\n core: v2ray-core[Not running]"
			fi
		fi
		# Read protocol type
		readInstallProtocolType

		if [[ -n ${currentInstallProtocolType} ]]; then
			echoContent yellow "Installed protocol:\c"
		fi
		if echo ${currentInstallProtocolType} | grep -q 0; then
			if [[ "${coreInstallType}" == 2 ]]; then
				echoContent yellow "VLESS+TCP[TLS] \c"
			else
				echoContent yellow "VLESS+TCP[TLS/XTLS] \c"
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

initVar $1
checkSystem
checkCPUVendor
readInstallType
readInstallProtocolType
readConfigHostPathUUID

# -------------------------------------------------------------

# Initialization installation directory
mkdirTools() {
	mkdir -p /etc/v2ray-agent/tls
	mkdir -p /etc/v2ray-agent/subscribe
	mkdir -p /etc/v2ray-agent/subscribe_tmp
	mkdir -p /etc/v2ray-agent/v2ray/conf
	mkdir -p /etc/v2ray-agent/xray/conf
	mkdir -p /etc/v2ray-agent/trojan
	mkdir -p /etc/systemd/system/
	mkdir -p /tmp/v2ray-agent-tls/
}

# Installation kit
installTools() {
	echo 'Installation tool'
	echoContent skyBlue "\n progress  $1/${totalProgress} : Installation tool"
	# Repair Ubuntu Individual System Issues
	if [[ "${release}" == "ubuntu" ]]; then
		dpkg --configure -a
	fi

	if [[ -n $(pgrep -f "apt") ]]; then
		pgrep -f apt | xargs kill -9
	fi

	echoContent green " ---> Check, installation update [new machine will be very slow, if there is no response for a long time, please re-execute it manually]"

	${upgrade} >/dev/null 2>&1
	if [[ "${release}" == "centos" ]]; then
		rm -rf /var/run/yum.pid
		${installType} epel-release >/dev/null 2>&1
	fi

	#	[[ -z `find /usr/bin /usr/sbin |grep -v grep|grep -w curl` ]]

	if ! find /usr/bin /usr/sbin | grep -q -w wget; then
		echoContent green " ---> Install wget"
		${installType} wget >/dev/null 2>&1
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w curl; then
		echoContent green " ---> Install CURL"
		${installType} curl >/dev/null 2>&1
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w unzip; then
		echoContent green " ---> Install unzip"
		${installType} unzip >/dev/null 2>&1
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w socat; then
		echoContent green " ---> Install SOCAT"
		${installType} socat >/dev/null 2>&1
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w tar; then
		echoContent green " ---> Install tar"
		${installType} tar >/dev/null 2>&1
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w cron; then
		echoContent green " ---> Install crontabs"
		if [[ "${release}" == "ubuntu" ]] || [[ "${release}" == "debian" ]]; then
			${installType} cron >/dev/null 2>&1
		else
			${installType} crontabs >/dev/null 2>&1
		fi
	fi
	if ! find /usr/bin /usr/sbin | grep -q -w jq; then
		echoContent green " ---> Install JQ"
		${installType} jq >/dev/null 2>&1
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w binutils; then
		echoContent green " ---> Install binutils"
		${installType} binutils >/dev/null 2>&1
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w ping6; then
		echoContent green " ---> Install PING6"
		${installType} inetutils-ping >/dev/null 2>&1
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w qrencode; then
		echoContent green " ---> Install QRencode"
		${installType} qrencode >/dev/null 2>&1
	fi

    if ! find /usr/bin /usr/sbin | grep -q -w sudo; then
		echoContent green " ---> Cheap Sudo"
		${installType} sudo >/dev/null 2>&1
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w lsb-release; then
		echoContent green " ---> Install LSB-RELEASE"
		${installType} lsb-release >/dev/null 2>&1
	fi

	# Detect the NGINX version and provide options to be uninstalled

	if ! find /usr/bin /usr/sbin | grep -q -w nginx; then
		echoContent green " ---> Install nginx"
		installNginxTools
	else
		nginxVersion=$(nginx -v 2>&1)
		nginxVersion=$(echo "${nginxVersion}" | awk -F "[n][g][i][n][x][/]" '{print $2}' | awk -F "[.]" '{print $2}')
		if [[ ${nginxVersion} -lt 14 ]]; then
			read -r -p "Reading to the current NGINX version does not support GRPC, resulting in failure, whether to uninstall NGINX, reinstall ？[y/n]:" unInstallNginxStatus
			if [[ "${unInstallNginxStatus}" == "y" ]]; then
				${removeType} nginx >/dev/null 2>&1
				echoContent yellow " ---> Nginx uninstalled completion"
				echoContent green " ---> Install nginx"
				installNginxTools >/dev/null 2>&1
			else
				exit 0
			fi
		fi
	fi
	if ! find /usr/bin /usr/sbin | grep -q -w semanage; then
		echoContent green " ---> Install semanage"
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

	if [[ ! -d "$HOME/.acme.sh" ]] || [[ -d "$HOME/.acme.sh" && -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
		echoContent green " ---> Install acme.sh"
		curl -s https://get.acme.sh | sh -s >/etc/v2ray-agent/tls/acme.log 2>&1
		if [[ ! -d "$HOME/.acme.sh" ]] || [[ -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
			echoContent red "  acme installation failed--->"
			tail -n 100 /etc/v2ray-agent/tls/acme.log
			echoContent yellow "Error investigation:"
			echoContent red "  1.Get the github file failed, please wait for Gitub to restore, try, recover progress to view [https://www.githubstatus.com/]"
			echoContent red "  2.acme.the sh script has bugs, you can view[https://github.com/acmesh-official/acme.sh] issues"
			exit 0
		fi
	fi
}

# Install nginx
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

# Install WARP
installWarp(){
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
		sudo rpm -ivh http://pkg.cloudflareclient.com/cloudflare-release-el${centosVersion}.rpm >/dev/null 2>&1
	fi

	echoContent green " ---> Install WARP"
	${installType} cloudflare-warp >/dev/null 2>&1
	if [[ -z $(which warp-cli) ]];then
        echoContent red " ---> Install WARP failed"
        exit 0;
	fi
	systemctl enable warp-svc
	warp-cli --accept-tos register
	warp-cli --accept-tos set-mode proxy
	warp-cli --accept-tos set-proxy-port 31303
	warp-cli --accept-tos connect
#	if [[]];then
#	fi
    # todo curl --socks5 127.0.0.1:31303 https://www.cloudflare.com/cdn-cgi/trace
	# systemctl daemon-reload
	# systemctl enable cloudflare-warp
}
# Initialization Nginx application certificate configuration
initTLSNginxConfig() {
	handleNginx stop
	echoContent skyBlue "\n progress  $1/${totalProgress} : Initialization Nginx application certificate configuration"
	if [[ -n "${currentHost}" ]]; then
		echo
		read -r -p "Read it to the last installation record, whether the domain name when the last installation is used ？[y/n]:" historyDomainStatus
		if [[ "${historyDomainStatus}" == "y" ]]; then
			domain=${currentHost}
			echoContent yellow "\n ---> domain name:${domain}"
		else
			echo
			echoContent yellow "Please enter the domain name to configure：www.v2ray-agent.com --->"
			read -r -p "domain name:" domain
		fi
	else
		echo
		echoContent yellow "Please enter the domain name you want to configure example：www.v2ray-agent.com --->"
		read -r -p "domain name:" domain
	fi

	if [[ -z ${domain} ]]; then
		echoContent red "  Domain name--->"
		initTLSNginxConfig
	else
		# update config
		touch /etc/nginx/conf.d/alone.conf
		cat <<EOF >/etc/nginx/conf.d/alone.conf
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    root /usr/share/nginx/html;
    location ~ /.well-known {
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
		# start nginx
		handleNginx start
		checkIP
	fi
}

# Modify NGINX redirection configuration
updateRedirectNginxConf() {

	cat <<EOF >/etc/nginx/conf.d/alone.conf
server {
	listen 80;
	listen [::]:80;
	server_name ${domain};
	# shellcheck disable=SC2154
	return 301 https://${domain}$request_uri;
}
server {
		listen 127.0.0.1:31300;
		server_name _;
		return 403;
}
EOF
if [[ -n $(echo "${selectCustomInstallType}" |grep 2) && -n $(echo "${selectCustomInstallType}" |grep 5) ]] || [[ -z "${selectCustomInstallType}" ]];then

		cat <<EOF >>/etc/nginx/conf.d/alone.conf
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
#		keepalive_time 1071906480m;
		keepalive_requests 4294967296;
		client_body_timeout 1071906480m;
 		send_timeout 1071906480m;
 		lingering_close always;
 		grpc_read_timeout 1071906480m;
 		grpc_send_timeout 1071906480m;
		grpc_pass grpc://127.0.0.1:31301;
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
		grpc_pass grpc://127.0.0.1:31304;
	}
}
EOF
	elif echo "${selectCustomInstallType}" |grep -q 5 || [[ -z "${selectCustomInstallType}" ]]; then
		cat <<EOF >>/etc/nginx/conf.d/alone.conf
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

	elif echo "${selectCustomInstallType}" |grep -q 2 || [[ -z "${selectCustomInstallType}" ]];then

		cat <<EOF >>/etc/nginx/conf.d/alone.conf
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

		cat <<EOF >>/etc/nginx/conf.d/alone.conf
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

	cat <<EOF >>/etc/nginx/conf.d/alone.conf
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

# Check IP
checkIP() {
	echoContent skyBlue "\n ---> Check the domain name IP address"
	localIP=$(curl -s -m 2 "${domain}/ip")
	handleNginx stop
	if [[ -z ${localIP} ]] || ! echo "${localIP}"|sed '1{s/[^(]*(//;s/).*//;q}'|grep -q '\.' && ! echo "${localIP}"|sed '1{s/[^(]*(//;s/).*//;q}'|grep -q ':';then
		echoContent red "\n ---> The ip of the current domain name is not detected"
		echoContent yellow " ---> Please check if the domain name is written correctly"
		echoContent yellow " ---> Please check whether the domain name dns resolution is correct"
		echoContent yellow " ---> If the resolution is correct, please wait for the dns to take effect, it is expected to take effect within three minutes"
		echoContent yellow " ---> If the above settings are correct, please try again after reinstalling the pure system"
		if [[ -n ${localIP} ]];then
			echoContent yellow " ---> Detecting return value exceptions"
		fi
		echoContent red " ---> Please check if the firewall is closed\n"
		read -r -p "Whether to turn off the firewall via script？[y/n]:" disableFirewallStatus
		if [[ ${disableFirewallStatus} == "y" ]];then
			handleFirewall stop
		fi

		exit 0;
	fi

	if echo "${localIP}"|awk -F "[,]" '{print $2}'|grep -q "." || echo "${localIP}"|awk -F "[,]" '{print $2}'|grep -q ":";then
		echoContent red "\n ---> Multiple ip detected, please confirm whether to turn off the cloudflare proxy"
		echoContent yellow " ---> Close the cloudflare proxy and wait three minutes before retrying"
		echoContent yellow " ---> The detected ip is as follows：[${localIP}]"
		exit 0;
	fi

	echoContent green " ---> Current domain ip is：[${localIP}]"
}
# Install TLS
installTLS() {
	echoContent skyBlue "\n progress  $1/${totalProgress} : Apply for a TLS certificate\n"
	local tlsDomain=${domain}
	# Install TLS
	if [[ -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" && -f "/etc/v2ray-agent/tls/${tlsDomain}.key" && -n $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]] || [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
		# Have a certificate
		echoContent green " ---> Certificate"
		checkTLStatus "${tlsDomain}"
		if [[ "${tlsStatus}" == "expired" ]]; then
			rm -rf $HOME/.acme.sh/${tlsDomain}_ecc/*
			rm -rf /etc/v2ray-agent/tls/${tlsDomain}*
			installTLS "$1"
		else
			echoContent green " ---> Certificate is valid"

			if ! ls /etc/v2ray-agent/tls/ | grep -q "${tlsDomain}.crt" || ! ls /etc/v2ray-agent/tls/ | grep -q "${tlsDomain}.key" || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
				sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
			else
				echoContent yellow " ---> If you have not expired, please choose[n]\n"
				read -r -p "Do you reinstall?[y/n]:" reInstallStatus
				if [[ "${reInstallStatus}" == "y" ]]; then
					rm -rf /etc/v2ray-agent/tls/*
					installTLS "$1"
				fi
			fi
		fi
	elif [[ -d "$HOME/.acme.sh" ]] && [[ ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" || ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" ]]; then
		echoContent green " ---> Install TLS certificate"
		if [[ -n "${pingIPv6}" ]]; then
			sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 --server letsencrypt --listen-v6 >> /etc/v2ray-agent/tls/acme.log
		else
			sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 --server letsencrypt >> /etc/v2ray-agent/tls/acme.log
		fi

		if [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
			sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
		fi

		if [[ ! -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" || ! -f "/etc/v2ray-agent/tls/${tlsDomain}.key"  ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.key") || -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
			tail -n 10 /etc/v2ray-agent/tls/acme.log
			if [[ ${installTLSCount} == "1" ]];then
				echoContent red " ---> TLS installation failed, please check acme logs"
				exit 0
			fi
			echoContent red " ---> TLS installation failed, check the firewall in"
			handleFirewall stop
			echoContent yellow " ---> Retry to install the TLS certificate"
			installTLSCount=1
			installTLS "$1"
		fi
		echoContent green " ---> TLS generation success"
	else
		echoContent yellow " ---> No acme is installed"
		exit 0
	fi
}
# Configure a camouflage blog
initNginxConfig() {
	echoContent skyBlue "\n progress  $1/${totalProgress} : Configuring nginx"

	cat <<EOF >/etc/nginx/conf.d/alone.conf
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    root /usr/share/nginx/html;
    location ~ /.well-known {allow all;}
    location /test {return 200 'fjkvymb6len';}
}
EOF
}

# customize/Random path
randomPathFunction() {
	echoContent skyBlue "\n progress  $1/${totalProgress} : Generate a random path"

	if [[ -n "${currentPath}" ]]; then
		echo
		read -r -p "Read to the last installation record, use the PATH path when the last installation is installed ？[y/n]:" historyPathStatus
		echo
	fi

	if [[ "${historyPathStatus}" == "y" ]]; then
		customPath=${currentPath}
		echoContent green " ---> Successful use\n"
	else
		echoContent yellow "Please enter a custom path[example: alone] path should be without slash. empty means random"
		read -r -p 'path:' customPath

		if [[ -z "${customPath}" ]]; then
			customPath=$(head -n 50 /dev/urandom | sed 's/[^a-z]//g' | strings -n 4 | tr 'A-Z' 'a-z' | head -1)
			currentPath=${customPath:0:4}
			customPath=${currentPath}
		else
			currentPath=${customPath}
		fi

	fi
	echoContent yellow "\n path：${currentPath}"
	echoContent skyBlue "\n----------------------------"
}
# Nginx camouflage blog
nginxBlog() {
	echoContent skyBlue "\n progress $1/${totalProgress} : Add a camouflage site"
	if [[ -d "/usr/share/nginx/html" && -f "/usr/share/nginx/html/check" ]]; then
		echo
		read -r -p "Detecting the installation camouflage site, do you need to reinstall?[y/n]：" nginxBlogInstallStatus
		if [[ "${nginxBlogInstallStatus}" == "y" ]]; then
			rm -rf /usr/share/nginx/html
			randomNum=$((RANDOM%6+1))
			wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip >/dev/null
			unzip -o /usr/share/nginx/html${randomNum}.zip -d /usr/share/nginx/html >/dev/null
			rm -f /usr/share/nginx/html${randomNum}.zip*
			echoContent green " ---> Add a camouflage site successfully"
		fi
	else
		randomNum=$((RANDOM%6+1))
		rm -rf /usr/share/nginx/html
		wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip >/dev/null
		unzip -o /usr/share/nginx/html${randomNum}.zip -d /usr/share/nginx/html >/dev/null
		rm -f /usr/share/nginx/html${randomNum}.zip*
		echoContent green " ---> Add a camouflage site successfully"
	fi

}
# Operation Nginx
handleNginx() {

	if [[ -z $(pgrep -f "nginx") ]] && [[ "$1" == "start" ]]; then
		nginx
		sleep 0.5
		if ! ps -ef | grep -v grep | grep -q nginx; then
			echoContent red " ---> Nginx start failed"
			echoContent red " ---> Please manually try NGINX, execute the script again"
			exit 0
		fi
	elif [[ "$1" == "stop" ]] && [[ -n $(pgrep -f "nginx") ]]; then
		nginx -s stop >/dev/null 2>&1
		sleep 0.5
		if [[ -n $(pgrep -f "nginx") ]]; then
			pgrep -f "nginx" | xargs kill -9
		fi
	fi
}

# Timed task update TLS certificate
installCronTLS() {
	echoContent skyBlue "\n progress $1/${totalProgress} : Add tls certificate"
	crontab -l >/etc/v2ray-agent/backup_crontab.cron
	local historyCrontab=$(sed '/v2ray-agent/d;/acme.sh/d' /etc/v2ray-agent/backup_crontab.cron)
	echo "${historyCrontab}" >/etc/v2ray-agent/backup_crontab.cron
	echo "30 1 * * * /bin/bash /etc/v2ray-agent/install.sh RenewTLS >> /etc/v2ray-agent/crontab_tls.log 2>&1" >>/etc/v2ray-agent/backup_crontab.cron
	crontab /etc/v2ray-agent/backup_crontab.cron
	echoContent green "\n ---> Adding tls success"
}

# Update certificate
renewalTLS() {
	echoContent skyBlue "\n progress  1/1 : Update certificate"

	if [[ -d "$HOME/.acme.sh/${currentHost}_ecc" ]] && [[ -f "$HOME/.acme.sh/${currentHost}_ecc/${currentHost}.key" ]] && [[ -f "$HOME/.acme.sh/${currentHost}_ecc/${currentHost}.cer" ]]; then
		modifyTime=$(stat $HOME/.acme.sh/${currentHost}_ecc/${currentHost}.cer | sed -n '7,6p' | awk '{print $2" "$3" "$4" "$5}')

		modifyTime=$(date +%s -d "${modifyTime}")
		currentTime=$(date +%s)
		stampDiff=$(expr ${currentTime} - ${modifyTime})
		days=$(expr ${stampDiff} / 86400)
		remainingDays=$(expr 90 - ${days})
		tlsStatus=${remainingDays}
		if [[ ${remainingDays} -le 0 ]]; then
			tlsStatus="expired"
		fi

		echoContent skyBlue " ---> Certificate check dates:$(date "+%F %H:%M:%S")"
		echoContent skyBlue " ---> Certificate generation date:$(date -d @"${modifyTime}" +"%F %H:%M:%S")"
		echoContent skyBlue " ---> Certificate generation days:${days}"
		echoContent skyBlue " ---> Certificate remaining days:"${tlsStatus}
		echoContent skyBlue " ---> Automatic update before the certificate expires, such as update failure, please update manually"

		if [[ ${remainingDays} -le 1 ]]; then
			echoContent yellow " ---> Regeneration certificate"
			handleNginx stop
			sudo "$HOME/.acme.sh/acme.sh" --cron --home "$HOME/.acme.sh"
			sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${currentHost}" --fullchainpath /etc/v2ray-agent/tls/"${currentHost}.crt" --keypath /etc/v2ray-agent/tls/"${currentHost}.key" --ecc
			reloadCore
		else
			echoContent green " ---> Certificate is valid"
		fi
	else
		echoContent red " ---> Not Installed"
	fi
}
# View the status of the TLS certificate
checkTLStatus() {

	if [[ -n "$1" ]]; then
		if [[ -d "$HOME/.acme.sh/$1_ecc" ]] && [[ -f "$HOME/.acme.sh/$1_ecc/$1.key" ]] && [[ -f "$HOME/.acme.sh/$1_ecc/$1.cer" ]]; then
			modifyTime=$(stat $HOME/.acme.sh/$1_ecc/$1.key | sed -n '7,6p' | awk '{print $2" "$3" "$4" "$5}')

			modifyTime=$(date +%s -d "${modifyTime}")
			currentTime=$(date +%s)
			stampDiff=$(expr ${currentTime} - ${modifyTime})
			days=$(expr ${stampDiff} / 86400)
			remainingDays=$(expr 90 - ${days})
			tlsStatus=${remainingDays}
			if [[ ${remainingDays} -le 0 ]]; then
				tlsStatus="expired"
			fi
			echoContent skyBlue " ---> Certificate generation date:$(date -d "@${modifyTime}" +"%F %H:%M:%S")"
			echoContent skyBlue " ---> Certificate generation days:${days}"
			echoContent skyBlue " ---> Certificate remaining days:${tlsStatus}"
		fi
	fi
}

# Install v2ray, specify version
installV2Ray() {
	readInstallType
	echoContent skyBlue "\n progress  $1/${totalProgress} : Install v2ray"

	if [[ "${coreInstallType}" != "2" && "${coreInstallType}" != "3" ]]; then
		if [[ "${selectCoreType}" == "2" ]]; then

			version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r .[].tag_name|head -1)
		else
			version=${v2rayCoreVersion}
		fi

		echoContent green " ---> v2ray-core version:${version}"
		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip"
		else
			wget -c -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip" >/dev/null 2>&1
		fi

		unzip -o /etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip -d /etc/v2ray-agent/v2ray >/dev/null
		rm -rf /etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip
	else
		if [[ "${selectCoreType}" == "3" ]]; then
			echoContent green " ---> lock v2ray-core version is v4.32.1"
			rm -f /etc/v2ray-agent/v2ray/v2ray
			rm -f /etc/v2ray-agent/v2ray/v2ctl
			installV2Ray "$1"
		else
			echoContent green " ---> v2ray-core version:$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"
			read -r -p "Is it updated, upgrade?[y/n]:" reInstallV2RayStatus
			if [[ "${reInstallV2RayStatus}" == "y" ]]; then
				rm -f /etc/v2ray-agent/v2ray/v2ray
				rm -f /etc/v2ray-agent/v2ray/v2ctl
				installV2Ray "$1"
			fi
		fi
	fi
}

# Install XRay
installXray() {
	readInstallType
	echoContent skyBlue "\n progress  $1/${totalProgress} : Install XRay"

	if [[ "${coreInstallType}" != "1" ]]; then

		version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r .[].tag_name|head -1)

		echoContent green " ---> Xray-core version:${version}"
		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
		else
			wget -c -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip" >/dev/null 2>&1
		fi

		unzip -o /etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip -d /etc/v2ray-agent/xray >/dev/null
		rm -rf /etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip
		chmod 655 /etc/v2ray-agent/xray/xray
	else
		echoContent green " ---> Xray-core version:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"
		read -r -p "Is it updated, upgrade?[y/n]:" reInstallXrayStatus
		if [[ "${reInstallXrayStatus}" == "y" ]]; then
			rm -f /etc/v2ray-agent/xray/xray
			installXray "$1"
		fi
	fi
}

# Install Trojan-go
installTrojanGo() {
	echoContent skyBlue "\n progress  $1/${totalProgress} : Install Trojan-Go"

	if ! ls /etc/v2ray-agent/trojan/ | grep -q trojan-go; then

		version=$(curl -s https://api.github.com/repos/p4gefau1t/trojan-go/releases | jq -r .[0].tag_name)
		echoContent green " ---> Trojan-Go version:${version}"
		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/trojan/ "https://github.com/p4gefau1t/trojan-go/releases/download/${version}/${trojanGoCPUVendor}.zip"
		else
			wget -c -P /etc/v2ray-agent/trojan/ "https://github.com/p4gefau1t/trojan-go/releases/download/${version}/${trojanGoCPUVendor}.zip" >/dev/null 2>&1
		fi
		unzip -o /etc/v2ray-agent/trojan/${trojanGoCPUVendor}.zip -d /etc/v2ray-agent/trojan >/dev/null
		rm -rf /etc/v2ray-agent/trojan/${trojanGoCPUVendor}.zip
	else
		echoContent green " ---> Trojan-Go version:$(/etc/v2ray-agent/trojan/trojan-go --version | awk '{print $2}' | head -1)"

		read -r -p "Do you reinstall?[y/n]:" reInstallTrojanStatus
		if [[ "${reInstallTrojanStatus}" == "y" ]]; then
			rm -rf /etc/v2ray-agent/trojan/trojan-go*
			installTrojanGo "$1"
		fi
	fi
}

# V2Ray version management
v2rayVersionManageMenu() {
	echoContent skyBlue "\n progress  $1/${totalProgress} : V2Ray version management"
	if [[ ! -d "/etc/v2ray-agent/v2ray/" ]]; then
		echoContent red " ---> No installation directory is detected, please perform script installation content"
		menu
		exit 0
	fi
	echoContent red "\n=============================================================="
	echoContent yellow "1.upgrade"
	echoContent yellow "2.go back"
	echoContent yellow "3.Close V2ray-core"
	echoContent yellow "4.Open v2ray-core"
	echoContent yellow "5.Restart V2Ray-core"
	echoContent red "=============================================================="
	read -r -p "please choose:" selectV2RayType
	if [[ "${selectV2RayType}" == "1" ]]; then
		updateV2Ray
	elif [[ "${selectV2RayType}" == "2" ]]; then
		echoContent yellow "\n1.Can only fall back to the most recent version"
		echoContent yellow "2.Do not guarantee that you must use it normally after the fallback"
		echoContent yellow "3.If the version of the rollback does not support the current config, it will not be able to connect, careful"
		echoContent skyBlue "------------------------Version-------------------------------"
		curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r .[].tag_name| head -5| awk '{print ""NR""":"$0}'

		echoContent skyBlue "--------------------------------------------------------------"
		read -r -p "Please enter the version you want to fall back:" selectV2rayVersionType
		version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r .[].tag_name| head -5| awk '{print ""NR""":"$0}' | grep "${selectV2rayVersionType}:" | awk -F "[:]" '{print $2}')
		if [[ -n "${version}" ]]; then
			updateV2Ray ${version}
		else
			echoContent red "\n ---> Enter is incorrect, please re-enter"
			v2rayVersionManageMenu 1
		fi
	elif [[ "${selectXrayType}" == "3" ]]; then
		handleV2Ray stop
	elif [[ "${selectXrayType}" == "4" ]]; then
		handleV2Ray start
	elif [[ "${selectXrayType}" == "5" ]]; then
		reloadCore
	fi
}

# XRay version management
xrayVersionManageMenu() {
	echoContent skyBlue "\n progress  $1/${totalProgress} : XRay version management"
	if [[ ! -d "/etc/v2ray-agent/xray/" ]]; then
		echoContent red " ---> No installation directory is detected, please perform script installation content"
		menu
		exit 0
	fi
	echoContent red "\n=============================================================="
	echoContent yellow "1.upgrade"
	echoContent yellow "2.go back"
	echoContent yellow "3.Close xray-core"
	echoContent yellow "4.Open xray-core"
	echoContent yellow "5.Restart XRAY-core"
	echoContent red "=============================================================="
	read -r -p "please choose:" selectXrayType
	if [[ "${selectXrayType}" == "1" ]]; then
		updateXray
	elif [[ "${selectXrayType}" == "2" ]]; then
		echoContent yellow "\n1.Due to XRay-Core frequently updated, only two recent versions"
		echoContent yellow "2.Do not guarantee that you must use it normally after the fallback"
		echoContent yellow "3.If the version of the rollback does not support the current config, it will not be able to connect, careful"
		echoContent skyBlue "------------------------Version-------------------------------"
		curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r .[].tag_name| head -2 | awk '{print ""NR""":"$0}'
		echoContent skyBlue "--------------------------------------------------------------"
		read -r -p "Please enter the version you want to fall back:" selectXrayVersionType
		version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r .[].tag_name| head -2 | awk '{print ""NR""":"$0}' | grep "${selectXrayVersionType}:" | awk -F "[:]" '{print $2}')
		if [[ -n "${version}" ]]; then
			updateXray "${version}"
		else
			echoContent red "\n ---> Enter is incorrect, please re-enter"
			xrayVersionManageMenu 1
		fi
	elif [[ "${selectXrayType}" == "3" ]]; then
		handleXray stop
	elif [[ "${selectXrayType}" == "4" ]]; then
		handleXray start
	elif [[ "${selectXrayType}" == "5" ]]; then
		reloadCore
	fi

}
# Update V2ray
updateV2Ray() {
	readInstallType
	if [[ -z "${coreInstallType}" ]]; then

		if [[ -n "$1" ]]; then
			version=$1
		else
			version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r .[0].tag_name)
		fi
		# Use the locked version
		if [[ -n "${v2rayCoreVersion}" ]]; then
			version=${v2rayCoreVersion}
		fi
		echoContent green " ---> v2ray-Core version:${version}"

		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip"
		else
			wget -c -P "/etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip" >/dev/null 2>&1
		fi

		unzip -o /etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip -d /etc/v2ray-agent/v2ray >/dev/null
		rm -rf /etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip
		handleV2Ray stop
		handleV2Ray start
	else
		echoContent green " ---> Current v2ray-Core version:$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"

		if [[ -n "$1" ]]; then
			version=$1
		else
			version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r .[0].tag_name)
		fi

		if [[ -n "${v2rayCoreVersion}" ]]; then
			version=${v2rayCoreVersion}
		fi
		if [[ -n "$1" ]]; then
			read -r -p "Retreat${version},Whether to continue?[y/n]:" rollbackV2RayStatus
			if [[ "${rollbackV2RayStatus}" == "y" ]]; then
				if [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
					echoContent green " ---> Current v2ray-Core version:$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"
				elif [[ "${coreInstallType}" == "1" ]]; then
					echoContent green " ---> Current Xray-Core version:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"
				fi

				handleV2Ray stop
				rm -f /etc/v2ray-agent/v2ray/v2ray
				rm -f /etc/v2ray-agent/v2ray/v2ctl
				updateV2Ray "${version}"
			else
				echoContent green " ---> Abandon the retreat version"
			fi
		elif [[ "${version}" == "v$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)" ]]; then
			read -r -p "The current version is the same as the latest version, is it reinstalled?[y/n]:" reInstallV2RayStatus
			if [[ "${reInstallV2RayStatus}" == "y" ]]; then
				handleV2Ray stop
				rm -f /etc/v2ray-agent/v2ray/v2ray
				rm -f /etc/v2ray-agent/v2ray/v2ctl
				updateV2Ray
			else
				echoContent green " ---> Abandon reinstall"
			fi
		else
			read -r -p "The latest version is:${version}Is it updated?[y/n]：" installV2RayStatus
			if [[ "${installV2RayStatus}" == "y" ]]; then
				rm -f /etc/v2ray-agent/v2ray/v2ray
				rm -f /etc/v2ray-agent/v2ray/v2ctl
				updateV2Ray
			else
				echoContent green " ---> Give up update"
			fi

		fi
	fi
}

# Update xray
updateXray() {
	readInstallType
	if [[ -z "${coreInstallType}" ]]; then
		if [[ -n "$1" ]]; then
			version=$1
		else
			version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r .[0].tag_name)
		fi

		echoContent green " ---> Xray-Core version:${version}"

		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
		else
			wget -c -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip" >/dev/null 2>&1
		fi

		unzip -o /etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip -d /etc/v2ray-agent/xray >/dev/null
		rm -rf /etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip
		chmod 655 /etc/v2ray-agent/xray/xray
		handleXray stop
		handleXray start
	else
		echoContent green " ---> Current Xray-Core version:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"

		if [[ -n "$1" ]]; then
			version=$1
		else
			version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r .[0].tag_name)
		fi

		if [[ -n "$1" ]]; then
			read -r -p "Retreat${version},Whether to continue?[y/n]:" rollbackXrayStatus
			if [[ "${rollbackXrayStatus}" == "y" ]]; then
				echoContent green " ---> Current Xray-Core version:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"

				handleXray stop
				rm -f /etc/v2ray-agent/xray/xray
				updateXray "${version}"
			else
				echoContent green " ---> Abandon the retreat version"
			fi
		elif [[ "${version}" == "v$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)" ]]; then
			read -r -p "The current version is the same as the latest version, is it reinstalled?[y/n]:" reInstallXrayStatus
			if [[ "${reInstallXrayStatus}" == "y" ]]; then
				handleXray stop
				rm -f /etc/v2ray-agent/xray/xray
				rm -f /etc/v2ray-agent/xray/xray
				updateXray
			else
				echoContent green " ---> Abandon reinstall"
			fi
		else
			read -r -p "The latest version is:${version}Is it updated?[y/n]：" installXrayStatus
			if [[ "${installXrayStatus}" == "y" ]]; then
				rm -f /etc/v2ray-agent/xray/xray
				updateXray
			else
				echoContent green " ---> Give up update"
			fi

		fi
	fi
}

# Verify that the entire service is available
checkGFWStatue() {
	readInstallType
	echoContent skyBlue "\n progress $1/${totalProgress} : Verify service startup status"
	if [[ "${coreInstallType}" == "1" ]] && [[ -n $(pgrep -f xray/xray) ]]; then
		echoContent green " ---> Service starts success"
	elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]] && [[ -n $(pgrep -f v2ray/v2ray) ]]; then
		echoContent green " ---> Service starts success"
	else
		echoContent red " ---> Service startup failed, please check if the terminal has a log printing"
		exit 0
	fi

}

# V2RAY boot
installV2RayService() {
	echoContent skyBlue "\n progress  $1/${totalProgress} : Configuring V2RAY boot"
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


[Install]
WantedBy=multi-user.target
EOF
		systemctl daemon-reload
		systemctl enable v2ray.service
		echoContent green " ---> Configuring V2RAY boot self-start"
	fi
}

# XRay boot
installXrayService() {
	echoContent skyBlue "\n progress  $1/${totalProgress} : Configuring XRAY boot self-start"
	if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
		rm -rf /etc/systemd/system/xray.service
		touch /etc/systemd/system/xray.service
		execStart='/etc/v2ray-agent/xray/xray run -confdir /etc/v2ray-agent/xray/conf'
		cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray - A unified platform for anti-censorship
# Documentation=https://v2ray.com https://guide.v2fly.org
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


[Install]
WantedBy=multi-user.target
EOF
		systemctl daemon-reload
		systemctl enable xray.service
		echoContent green " ---> Configuring XRAY boot self-start"
	fi
}
# Trojan boot self-start
installTrojanService() {
	echoContent skyBlue "\n progress  $1/${totalProgress} : Configuring Trojan boot self-start"
	if [[ -n $(find /bin /usr/bin -name "systemctl") ]]; then
		rm -rf /etc/systemd/system/trojan-go.service
		touch /etc/systemd/system/trojan-go.service

		cat <<EOF >/etc/systemd/system/trojan-go.service
[Unit]
Description=Trojan-Go - A unified platform for anti-censorship
Documentation=Trojan-Go
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=yes
ExecStart=/etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json
Restart=on-failure
RestartPreventExitStatus=23


[Install]
WantedBy=multi-user.target
EOF
		systemctl daemon-reload
		systemctl enable trojan-go.service
		echoContent green " ---> Configuring Trojan boot self-starting"
	fi
}
# Operation v2ray
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
			echoContent green " ---> V2Ray starts success"
		else
			echoContent red "V2Ray starts failed"
			echoContent red "Please manually【/etc/v2ray-agent/v2ray/v2ray -confdir /etc/v2ray-agent/v2ray/conf】，View the error log"
			exit 0
		fi
	elif [[ "$1" == "stop" ]]; then
		if [[ -z $(pgrep -f "v2ray/v2ray") ]]; then
			echoContent green " ---> V2RAY is successful"
		else
			echoContent red "V2Ray Close failed"
			echoContent red "Please manually【ps -ef|grep -v grep|grep v2ray|awk '{print \$2}'|xargs kill -9】"
			exit 0
		fi
	fi
}
# Operation XRAY
handleXray() {
	if [[ -n $(find /bin /usr/bin -name "systemctl") ]] && ls /etc/systemd/system/ | grep -q xray.service; then
		if [[ -z $(pgrep -f "xray/xray") ]] && [[ "$1" == "start" ]]; then
			systemctl start xray.service
		elif [[ -n $(pgrep -f "xray/xray") ]] && [[ "$1" == "stop" ]]; then
			systemctl stop xray.service
		fi
	fi

	sleep 0.8

	if [[ "$1" == "start" ]]; then
		if [[ -n $(pgrep -f "xray/xray") ]]; then
			echoContent green " ---> Xray started successfully"
		else
			echoContent red "XRay start failed"
			echoContent red "Please manually【/etc/v2ray-agent/xray/xray -confdir /etc/v2ray-agent/xray/conf】，View the error log"
			exit 0
		fi
	elif [[ "$1" == "stop" ]]; then
		if [[ -z $(pgrep -f "xray/xray") ]]; then
			echoContent green " ---> XRay close success"
		else
			echoContent red "XRay Close failed"
			echoContent red "Please manually【ps -ef|grep -v grep|grep xray|awk '{print \$2}'|xargs kill -9】"
			exit 0
		fi
	fi
}

# Operation Trojan-Go
handleTrojanGo() {
	if [[ -n $(find /bin /usr/bin -name "systemctl") ]] && ls /etc/systemd/system/ | grep -q trojan-go.service; then
		if [[ -z $(pgrep -f "trojan-go") ]] && [[ "$1" == "start" ]]; then
			systemctl start trojan-go.service
		elif [[ -n $(pgrep -f "trojan-go") ]] && [[ "$1" == "stop" ]]; then
			systemctl stop trojan-go.service
		fi
	fi

	sleep 0.5
	if [[ "$1" == "start" ]]; then
		if [[ -n $(pgrep -f "trojan-go") ]]; then
			echoContent green " ---> Trojan-GO starts success"
		else
			echoContent red "Trojan-Go failed to start"
			echoContent red "Please manually【/etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json】，View the error log"
			exit 0
		fi
	elif [[ "$1" == "stop" ]]; then
		if [[ -z $(pgrep -f "trojan-go") ]]; then
			echoContent green " ---> Trojan-GO close success"
		else
			echoContent red "Trojan-GO close failed"
			echoContent red "Please manually【ps -ef|grep -v grep|grep trojan-go|awk '{print \$2}'|xargs kill -9】"
			exit 0
		fi
	fi
}

# Initialize V2RAY configuration file
initV2RayConfig() {
	echoContent skyBlue "\n schedule $2/${totalProgress} : Initialize V2RAY configuration"
	echo

	read -r -p "Whether it is customized UUID ？[y/n]:" customUUIDStatus
	echo
	if [[ "${customUUIDStatus}" == "y" ]]; then
		read -r -p "Please enter legal UUID:" currentCustomUUID
		if [[ -n "${currentCustomUUID}" ]]; then
			uuid=${currentCustomUUID}
		fi
	fi

	if [[ -n "${currentUUID}" && -z "${uuid}" ]]; then
		read -r -p "Read to the last installation record，Whether to use the last installation UUID ？[y/n]:" historyUUIDStatus
		if [[ "${historyUUIDStatus}" == "y" ]]; then
			uuid=${currentUUID}
		else
			uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
		fi
	elif [[ -z "${uuid}" ]]; then
		uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
	fi

	if [[ -z "${uuid}" ]]; then
		echoContent red "\n ---> uuid Read error，regenerate"
		uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
	fi

	rm -rf /etc/v2ray-agent/v2ray/conf/*
	rm -rf /etc/v2ray-agent/v2ray/config_full.json

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
	# VLESS_TCP_TLS/XTLS
	# Fall back nginx
	local fallbacksList='{"dest":31300,"xver":0},{"alpn":"h2","dest":31302,"xver":0}'

if [[ -n $(echo "${selectCustomInstallType}" | grep 4) || "$1" == "all" ]]; then
		fallbacksList='{"dest":31296,"xver":1},{"alpn":"h2","dest":31302,"xver":0}'
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
			"email": "${domain}_trojan_tcp"
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
	fi

	# VLESS_WS_TLS
	if echo "${selectCustomInstallType}" | grep -q 1 || [[ "$1" == "all" ]]; then
		fallbacksList=${fallbacksList}',{"path":"/'${customPath}'ws","dest":31297,"xver":1}'
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
        "email": "${domain}_VLESS_WS"
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
	fi


	# VMess_WS
	if echo "${selectCustomInstallType}" | grep -q 3 || [[ "$1" == "all" ]]; then
		fallbacksList=${fallbacksList}',{"path":"/'${customPath}'vws","dest":31299,"xver":1}'
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
        "email": "${domain}_vmess_ws"
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
	fi
	# VLESS gRPC
	if echo "${selectCustomInstallType}" | grep -q 5 || [[ "$1" == "all" ]]; then
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
        			"email": "${domain}_VLESS_gRPC"
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
	fi

	# VLESS_TCP
	if [[ "${selectCoreType}" == "2" ]]; then
		cat <<EOF >/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json
{
  "inbounds":[
    {
      "port": 443,
      "protocol": "vless",
      "tag":"VLESSTCP",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "add": "${add}",
            "email": "${domain}_VLESS_TLS_TCP"
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
          "alpn": [
            "http/1.1",
            "h2"
          ],
          "certificates": [
            {
              "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
              "keyFile": "/etc/v2ray-agent/tls/${domain}.key"
            }
          ]
        }
      }
    }
  ]
}
EOF
	elif [[ "${selectCoreType}" == "3" ]]; then
		cat <<EOF >/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json
{
"inbounds":[
{
  "port": 443,
  "protocol": "vless",
  "tag":"VLESSTCP",
  "settings": {
    "clients": [
     {
        "id": "${uuid}",
        "add":"${add}",
        "flow":"xtls-rprx-direct",
        "email": "${domain}_VLESS_XTLS/TLS-direct_TCP"
      }
    ],
    "decryption": "none",
    "fallbacks": [
        ${fallbacksList}
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "xtls",
    "xtlsSettings": {
      "alpn": [
        "http/1.1"
      ],
      "certificates": [
        {
          "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
          "keyFile": "/etc/v2ray-agent/tls/${domain}.key"
        }
      ]
    }
  }
}
]
}
EOF
	fi
}

# initializationXray Trojan XTLS config
initXrayFrontingConfig(){
	if [[ -z "${configPath}" ]]; then
		echoContent red " ---> Not installed, please use the script installation"
		menu
		exit 0
	fi
	if [[ "${coreInstallType}" != "1" ]];then
		echoContent red " ---> No available types"
	fi
	local xtlsType=
	if echo ${currentInstallProtocolType} | grep -q trojan; then
		xtlsType=VLESS
	else
		xtlsType=Trojan

	fi

	echoContent skyBlue "\n function 1/${totalProgress} : Pre-switching${xtlsType}"
	echoContent red "\n=============================================================="
	echoContent yellow "# Precautions \n"
	echoContent yellow "Alternative to${xtlsType}"
	echoContent yellow "If the front is Trojan, two Trojan protocols have nodes, there is an unavailable XTLS"
	echoContent yellow "Execute it again to switch to the previous front \n"

	echoContent yellow "1.Switch to${xtlsType}"
	echoContent red "=============================================================="
	read -r -p "please choose:" selectType
	if [[ "${selectType}" == "1" ]]; then

		if [[ "${xtlsType}" == "Trojan" ]];then

			local VLESSConfig=$(cat ${configPath}${frontingType}.json)
			VLESSConfig=${VLESSConfig//"id"/"password"}
			VLESSConfig=${VLESSConfig//VLESSTCP/TrojanTCPXTLS}
			VLESSConfig=${VLESSConfig//VLESS/Trojan}
			VLESSConfig=${VLESSConfig//"vless"/"trojan"}
			VLESSConfig=${VLESSConfig//"id"/"password"}

			echo "${VLESSConfig}" | jq . >${configPath}02_trojan_TCP_inbounds.json
			rm  ${configPath}${frontingType}.json
		elif [[ "${xtlsType}" == "VLESS" ]]; then

			local VLESSConfig=$(cat ${configPath}02_trojan_TCP_inbounds.json)
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

	exit 0;
}

# Initialize XRAY profile
initXrayConfig() {
	echoContent skyBlue "\n progress $2/${totalProgress} : Initialize XRAY configuration"
	echo
	local uuid=
	if [[ -n "${currentUUID}" ]]; then
		read -r -p "Read to the last installation record, is it used in the last installation? UUID ？[y/n]:" historyUUIDStatus
		if [[ "${historyUUIDStatus}" == "y" ]]; then
			uuid=${currentUUID}
			echoContent green "\n ---> 使用成功"
		else
			uuid=$(/etc/v2ray-agent/xray/xray uuid)
		fi
	fi

	if [[ -z "${uuid}" ]];then
		echoContent yellow "Please enter custom UUID [need to legal], [Enter] Random UUID"
		read -r -p 'UUID:' customUUID

		if [[ -n ${customUUID} ]];then
			uuid=${customUUID}
		else
			uuid=$(/etc/v2ray-agent/xray/xray uuid)
		fi

	fi

	if [[ -z "${uuid}" ]]; then
		echoContent red "\n ---> UUID read error, regenerate"
		uuid=$(/etc/v2ray-agent/xray/xray uuid)
	fi

	echoContent yellow "\n ${uuid}"

	rm -rf /etc/v2ray-agent/xray/conf/*

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
            "protocol":"blackhole",
            "tag":"blackhole-out"
        }
    ]
}
EOF
	fi


	# dns
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
	# 回落nginx
	local fallbacksList='{"dest":31300,"xver":0},{"alpn":"h2","dest":31302,"xver":0}'

	# trojan
	if [[ -n $(echo "${selectCustomInstallType}" | grep 4) || "$1" == "all" ]]; then
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
		"clients": [
		  {
			"password": "${uuid}",
			"email": "${domain}_trojan_tcp"
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
    "clients": [
      {
        "id": "${uuid}",
        "email": "${domain}_VLESS_WS"
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
	fi


	# trojan_grpc
	if echo ${selectCustomInstallType} | grep -q 2 || [[ "$1" == "all" ]]; then
		if ! echo ${selectCustomInstallType} | grep -q 5 && [[ -n ${selectCustomInstallType} ]];then
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
                "clients": [
                    {
                        "password": "${uuid}",
                        "email": "${domain}_trojan_gRPC"
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
    "clients": [
      {
        "id": "${uuid}",
        "alterId": 0,
        "add": "${add}",
        "email": "${domain}_vmess_ws"
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
            "clients": [
                {
                    "id": "${uuid}",
                    "add": "${add}",
                    "email": "${domain}_VLESS_gRPC"
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
	fi

	# VLESS_TCP
	cat <<EOF >/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json
{
"inbounds":[
{
  "port": 443,
  "protocol": "vless",
  "tag":"VLESSTCP",
  "settings": {
    "clients": [
     {
        "id": "${uuid}",
        "add":"${add}",
        "flow":"xtls-rprx-direct",
        "email": "${domain}_VLESS_XTLS/TLS-direct_TCP"
      }
    ],
    "decryption": "none",
    "fallbacks": [
        ${fallbacksList}
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "xtls",
    "xtlsSettings": {
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
}

# initialization Trojan-Go Configure
initTrojanGoConfig() {

	echoContent skyBlue "\n schedule $1/${totalProgress} : Initialization Trojan configuration"
	cat <<EOF >/etc/v2ray-agent/trojan/config_full.json
{
    "run_type": "server",
    "local_addr": "127.0.0.1",
    "local_port": 31296,
    "remote_addr": "127.0.0.1",
    "remote_port": 31300,
    "disable_http_check":true,
    "log_level":3,
    "log_file":"/etc/v2ray-agent/trojan/trojan.log",
    "password": [
        "${uuid}"
    ],
    "dns":[
        "localhost"
    ],
    "transport_plugin":{
        "enabled":true,
        "type":"plaintext"
    },
    "websocket": {
        "enabled": true,
        "path": "/${customPath}tws",
        "host": "${domain}",
        "add":"${add}"
    },
    "router": {
        "enabled": false
    }
}
EOF
}

# customizeCDN IP
customCDNIP() {
	echoContent skyBlue "\n progress $1/${totalProgress} : Add cloudflare self-selecting CNAME"
	echoContent red "\n=============================================================="
	echoContent yellow "# Cautions"
	echoContent yellow "\n Tutorial Address:"
	echoContent skyBlue "https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md"
	echoContent red "\n If you do not know about Cloudflare optimization, please do not use"
	echoContent yellow "\n 1.china Mobile:104.16.123.96"
	echoContent yellow " 2.china Unicom:www.cloudflare.com"
	echoContent yellow " 3.china Telecom:www.digitalocean.com"
	echoContent skyBlue "----------------------------"
	read -r -p "Please choose[Carriage return not used]:" selectCloudflareType
    case ${selectCloudflareType} in
    1)
        add="104.16.123.96"
        ;;
    2)
        add="www.cloudflare.com"
        ;;
    3)
        add="www.digitalocean.com"
        ;;
    *)
		add="${domain}"
		echoContent yellow "\n ---> No use"
		;;
    esac
}
# 通用
defaultBase64Code() {
	local type=$1
	local email=$2
	local id=$3
	local hostPort=$4
	local host=
	local port=
	if echo "${hostPort}" | grep -q ":"; then
		host=$(echo "${hostPort}" | awk -F "[:]" '{print $1}')
		port=$(echo "${hostPort}" | awk -F "[:]" '{print $2}')
	else
		host=${hostPort}
		port=443
	fi

	local path=$5
	local add=$6

	local subAccount=${currentHost}_$(echo "${id}_currentHost" | md5sum | awk '{print $1}')
	if [[ "${type}" == "vlesstcp" ]]; then

		if [[ "${coreInstallType}" == "1" ]] && echo ${currentInstallProtocolType} | grep -q 0; then
			echoContent yellow " ---> General format(VLESS+TCP+TLS/xtls-rprx-direct)"
			echoContent green "    vless://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-direct#${email}\n"

			echoContent yellow " ---> Format clear text(VLESS+TCP+TLS/xtls-rprx-direct)"
			echoContent green "agreement type：VLESS，address：${host}，port：${port}，user ID：${id}，Safety：xtls，transfer method：tcp，flow：xtls-rprx-direct，account name:${email}\n"
			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-direct#${email}
EOF
			echoContent yellow " ---> QR code VLESS(VLESS+TCP+TLS/xtls-rprx-direct)"
			echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${host}%3A${port}%3F${encryption}%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26sni%3D${host}%26flow%3Dxtls-rprx-direct%23${email}\n"

			echoContent skyBlue "----------------------------------------------------------------------------------"

			echoContent yellow " ---> General format(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    vless://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-splice#${email}\n"

			echoContent yellow " ---> Format clear text(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    agreement type：VLESS，address：${host}，port：${port}，user ID：${id}，Safety：xtls，transfer method：tcp，flow：xtls-rprx-splice，account name:${email}\n"
			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-splice#${email}
EOF
			echoContent yellow " ---> QR code VLESS(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${host}%3A${port}%3F${encryption}%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26sni%3D${host}%26flow%3Dxtls-rprx-splice%23${email}\n"

		elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
			echoContent yellow " ---> General format(VLESS+TCP+TLS)"
			echoContent green "    vless://${id}@${host}:${port}?security=tls&encryption=none&host=${host}&headerType=none&type=tcp#${email}\n"

			echoContent yellow " ---> Format clear text(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    agreement type：VLESS，address：${host}，port：${port}，user ID：${id}, Safety: TLS, Transmission mode: TCP, account name:${email}\n"

			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${host}:${port}?security=tls&encryption=none&host=${host}&headerType=none&type=tcp#${email}
EOF
			echoContent yellow " ---> QR code VLESS(VLESS+TCP+TLS)"
			echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3a%2f%2f${id}%40${host}%3a${port}%3fsecurity%3dtls%26encryption%3dnone%26host%3d${host}%26headerType%3dnone%26type%3dtcp%23${email}\n"
		fi

	elif [[ "${type}" == "trojanTCPXTLS" ]]; then
			echoContent yellow " ---> General format(Trojan+TCP+TLS/xtls-rprx-direct)"
			echoContent green "    trojan://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-direct#${email}\n"

			echoContent yellow " ---> Format clear text(Trojan+TCP+TLS/xtls-rprx-direct)"
			echoContent green "Type: Trojan, address：${host}，port：${port}，user ID：${id}，Safety：xtls，transfer method：tcp，flow：xtls-rprx-direct，account name:${email}\n"
			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-direct#${email}
EOF
			echoContent yellow " ---> QR code Trojan(Trojan+TCP+TLS/xtls-rprx-direct)"
			echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3A%2F%2F${id}%40${host}%3A${port}%3Fencryption%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26sni%3D${host}%26flow%3Dxtls-rprx-direct%23${email}\n"

			echoContent skyBlue "----------------------------------------------------------------------------------"

			echoContent yellow " ---> General format(Trojan+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    trojan://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-splice#${email}\n"

			echoContent yellow " ---> Format clear text(Trojan+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    agreement type：VLESS，address：${host}，port：${port}，user ID：${id}，Safety：xtls，transfer method：tcp，flow：xtls-rprx-splice，account name:${email}\n"
			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-splice#${email}
EOF
			echoContent yellow " ---> QR code Trojan(Trojan+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3A%2F%2F${id}%40${host}%3A${port}%3Fencryption%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26sni%3D${host}%26flow%3Dxtls-rprx-splice%23${email}\n"


	elif [[ "${type}" == "vmessws" ]]; then

		qrCodeBase64Default=$(echo -n '{"port":"'${port}'","ps":'\"${email}\"',"tls":"tls","id":'\"${id}\"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":"/'${path}'","net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'","sni":"'${host}'"}' | sed 's#/#\\\/#g' | base64)
		qrCodeBase64Default=$(echo ${qrCodeBase64Default} | sed 's/ //g')

		echoContent yellow " ---> Universal json(VMess+WS+TLS)"
		echoContent green '    {"port":"'${port}'","ps":'\"${ps}\"',"tls":"tls","id":'\"${id}\"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":"/'${path}'","net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'","sni":"'${host}'"}\n'
		echoContent yellow " ---> Universal vmess(VMess+WS+TLS)Link"
		echoContent green "    vmess://${qrCodeBase64Default}\n"
		echoContent yellow " ---> QR code vmess(VMess+WS+TLS)"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vmess://${qrCodeBase64Default}
EOF
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

	elif [[ "${type}" == "vmesstcp" ]]; then

#		echoContent yellow " ---> 通用格式[新版，推荐]"
#
#		echoContent green "    vmess://tcp+tls:2e6257c5-1402-41a6-a96d-1e0bdad78159-0@vu3.s83h.xyz:443/?type=http&tlsServerName=vu3.s83h.xyz#vu3.s83h.xyz_vmess_tcp"
#		echoContent green "    vmess://tcp+tls:${id//\"/}-0@${add}:${port}/?type=http&path=/${path}&tlsServerName=${host}&alpn=http1.1#${ps//\"/}\n"
#
#		echoContent yellow " ---> 格式化明文(vmess+http+tls)"
#		echoContent green "协议类型：vmess，地址：${host}，端口：${port}，用户ID：${id}，安全：tls，传输方式：http，账户名:${ps}\n"
#		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
#vmess://http+tls:${id}-0@${add}:${port}/?path=/${path}&tlsServerName=${host}&alpn=http1.1#${ps}
#EOF
#		echoContent yellow " ---> 二维码 vmess(http+tls)"
#		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess%3A%2F%2Fhttp%2Btls%3A${id}-0%40add%3A${port}%2F%3Fpath%3D%2F${path}%26tlsServerName%3D${host}%26alpn%3Dhttp1.1%23%24%7B${ps}%7D\n"

		echoContent red path:${path}
		qrCodeBase64Default=$(echo -n '{"add":"'${add}'","aid":"0","host":"'${host}'","id":'"${id}"',"net":"tcp","path":"/'${path}'","port":"'${port}'","ps":'${ps}',"scy":"none","sni":"'${host}'","tls":"tls","v":"2","type":"http","allowInsecure":0,"peer":"'${host}'","obfs":"http","obfsParam":"'${host}'"}'  | base64)
		qrCodeBase64Default=$(echo ${qrCodeBase64Default} | sed 's/ //g')

		echoContent yellow " ---> Universal json(VMess+TCP+TLS)"
		echoContent green '    {"port":"'${port}'","ps":'${ps}',"tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"http","path":"/'${path}'","net":"http","add":"'${add}'","allowInsecure":0,"method":"post","peer":"'${host}'","obfs":"http","obfsParam":"'${host}'"}\n'
		echoContent yellow " ---> Universalvmess(VMess+TCP+TLS)Link"
		echoContent green "    vmess://${qrCodeBase64Default}\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vmess://${qrCodeBase64Default}
EOF
		echoContent yellow " ---> QR code vmess(VMess+TCP+TLS)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

	elif [[ "${type}" == "vlessws" ]]; then

		echoContent yellow " ---> General format(VLESS+WS+TLS)"
		echoContent green "    vless://${id}@${add}:${port}?encryption=none&security=tls&type=ws&host=${host}&sni=${host}&path=%2f${path}#${email}\n"

		echoContent yellow " ---> Format clear text(VLESS+WS+TLS)"
		echoContent green "    agreement type：VLESS，address：${add}，Camouflage domain name/SNI：${host}，port：${port}，user ID：${id}，Safety：tls，transfer method：ws，path:/${path}，account name:${email}\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${add}:${port}?encryption=none&security=tls&type=ws&host=${host}&sni=${host}&path=%2f${path}#${email}
EOF

		echoContent yellow " ---> QR code VLESS(VLESS+TCP+TLS/XTLS)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${port}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dws%26host%3D${host}%26sni%3D${host}%26path%3D%252f${path}%23${email}"

	elif [[ "${type}" == "vlessgrpc" ]]; then

		echoContent yellow " ---> General format(VLESS+gRPC+TLS)"
		echoContent green "    vless://${id}@${add}:${port}?encryption=none&security=tls&type=grpc&host=${host}&path=${path}&serviceName=${path}&alpn=h2&sni=${host}#${email}\n"

		echoContent yellow " ---> Format clear text(VLESS+gRPC+TLS)"
		echoContent green "    agreement type：VLESS，address：${add}，Camouflage domain name/SNI：${host}，port：${port}，user ID：${id}，Safety：tls，transfer method：gRPC，alpn：h2，serviceName:${path}，account name:${email}\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${add}:${port}?encryption=none&security=tls&type=grpc&host=${host}&path=${path}&serviceName=${path}&alpn=h2&sni=${host}#${email}
EOF
		echoContent yellow " ---> QR code VLESS(VLESS+gRPC+TLS)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${port}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dgrpc%26host%3D${host}%26serviceName%3D${path}%26path%3D${path}%26sni%3D${host}%26alpn%3Dh2%23${email}"

	elif [[ "${type}" == "trojan" ]]; then
		# URLEncode
		echoContent yellow " ---> Trojan(TLS)"
		echoContent green "    trojan://${id}@${host}:${port}?peer=${host}&sni=${host}&alpn=http1.1#${host}_Trojan\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${host}:${port}?peer=${host}&sni=${host}&alpn=http1.1#${host}_Trojan
EOF
		echoContent yellow " ---> QR code Trojan(TLS)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${host}%3a${port}%3fpeer%3d${host}%26sni%3d${host}%26alpn%3Dhttp1.1%23${host}_Trojan\n"

	elif [[ "${type}" == "trojangrpc" ]]; then
		# URLEncode

		echoContent yellow " ---> Trojan gRPC(TLS)"
		echoContent green "    trojan://${id}@${host}:${port}?encryption=none&peer=${host}&security=tls&type=grpc&sni=${host}&alpn=h2&path=${path}&serviceName=${path}#${host}_Trojan_gRPC\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${host}:${port}?encryption=none&peer=${host}&security=tls&type=grpc&sni=${host}&alpn=h2&path=${path}&serviceName=${path}#${host}_Trojan_gRPC
EOF
		echoContent yellow " ---> QR code Trojan gRPC(TLS)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${host}%3a${port}%3Fencryption%3Dnone%26security%3Dtls%26peer%3d${host}%26type%3Dgrpc%26sni%3d${host}%26path%3D${path}%26alpn%3D=h2%26serviceName%3D${path}%23${host}_Trojan_gRPC\n"

	elif [[ "${type}" == "trojangows" ]]; then
		# URLEncode
		echoContent yellow " ---> Trojan-Go(WS+TLS) Shadowrocket"
		echoContent green "    trojan://${id}@${add}:${port}?allowInsecure=0&&peer=${host}&sni=${host}&plugin=obfs-local;obfs=websocket;obfs-host=${host};obfs-uri=${path}#${host}_Trojan_ws\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${add}:${port}?allowInsecure=0&&peer=${host}&sni=${host}&plugin=obfs-local;obfs=websocket;obfs-host=${host};obfs-uri=${path}#${host}_Trojan_ws
EOF
		echoContent yellow " ---> QR code Trojan-Go(WS+TLS) Shadowrocket"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${add}%3a${port}%3fallowInsecure%3d0%26peer%3d${host}%26plugin%3dobfs-local%3bobfs%3dwebsocket%3bobfs-host%3d${host}%3bobfs-uri%3d${path}%23${host}_Trojan_ws\n"

		path=$(echo "${path}" | awk -F "[/]" '{print $2}')
		echoContent yellow " ---> Trojan-Go(WS+TLS) QV2ray"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan-go://${id}@${add}:${port}?sni=${host}&type=ws&host=${host}&path=%2F${path}#${host}_Trojan_ws
EOF

		echoContent green "    trojan-go://${id}@${add}:${port}?sni=${host}&type=ws&host=${host}&path=%2F${path}#${host}_Trojan_ws\n"

	fi
}
# account
showAccounts() {
	readInstallType
	readInstallProtocolType
	readConfigHostPathUUID
	echoContent skyBlue "\n schedule $1/${totalProgress} : account"
	local show
	# VLESS TCP
	if [[ -n "${configPath}" ]]; then
		show=1
		if  echo "${currentInstallProtocolType}" | grep -q trojan ;then
			echoContent skyBlue "===================== Trojan TCP TLS/XTLS-direct/XTLS-splice ======================\n"
			# cat ${configPath}02_VLESS_TCP_inbounds.json | jq .inbounds[0].settings.clients | jq -c '.[]'
			jq .inbounds[0].settings.clients ${configPath}02_trojan_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
				echoContent skyBlue "\n ---> account number：$(echo "${user}" | jq -r .email )_$(echo "${user}" | jq -r .password)"
				echo
				defaultBase64Code trojanTCPXTLS $(echo "${user}" | jq -r .email) $(echo "${user}" | jq -r .password) "${currentHost}:${currentPort}" ${currentHost}
			done

		else
			echoContent skyBlue "===================== VLESS TCP TLS/XTLS-direct/XTLS-splice ======================\n"
			# cat ${configPath}02_VLESS_TCP_inbounds.json | jq .inbounds[0].settings.clients | jq -c '.[]'
			jq .inbounds[0].settings.clients ${configPath}02_VLESS_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
				echoContent skyBlue "\n ---> account number：$(echo "${user}" | jq -r .email )_$(echo "${user}" | jq -r .id)"
				echo
				defaultBase64Code vlesstcp $(echo "${user}" | jq -r .email) $(echo "${user}" | jq -r .id) "${currentHost}:${currentPort}" ${currentHost}
			done
		fi


		# VLESS WS
		if echo ${currentInstallProtocolType} | grep -q 1; then
			echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================\n"

			# cat ${configPath}03_VLESS_WS_inbounds.json | jq .inbounds[0].settings.clients | jq -c '.[]'
			jq .inbounds[0].settings.clients ${configPath}03_VLESS_WS_inbounds.json | jq -c '.[]' | while read -r user; do
				echoContent skyBlue "\n ---> account number：$(echo "${user}" | jq -r .email )_$(echo "${user}" | jq -r .id)"
				echo
				local path="${currentPath}ws"
				if [[ ${coreInstallType} == "1" ]]; then
					echoContent yellow "Xrayof0-RTT path Will there be? ED = 2048, is not compatible with clients with V2Ray as the core, please manually delete? ED = 2048 after use\n"
					path="${currentPath}ws?ed=2048"
				fi
				defaultBase64Code vlessws $(echo "${user}" | jq -r .email) $(echo "${user}" | jq -r .id) "${currentHost}:${currentPort}" ${path} ${currentAdd}
			done
		fi

		# VMess WS
		if echo ${currentInstallProtocolType} | grep -q 3; then
			echoContent skyBlue "\n================================ VMess WS TLS CDN ================================\n"
			local path="${currentPath}vws"
			if [[ ${coreInstallType} == "1" ]]; then
				path="${currentPath}vws?ed=2048"
			fi
			jq .inbounds[0].settings.clients ${configPath}05_VMess_WS_inbounds.json | jq -c '.[]' | while read -r user; do
				echoContent skyBlue "\n ---> 帐号：$(echo "${user}" | jq -r .email )_$(echo "${user}" | jq -r .id)"
				echo
				defaultBase64Code vmessws $(echo "${user}" | jq -r .email) $(echo "${user}" | jq -r .id) "${currentHost}:${currentPort}" ${path} ${currentAdd}
			done
		fi

		# VLESS grpc
		if echo ${currentInstallProtocolType} | grep -q 5; then
			echoContent skyBlue "\n=============================== VLESS gRPC TLS CDN ===============================\n"
			echoContent red "\n --->gRPC Currently in the test phase, it may not be compatible with the client you use, if you can't use it, please ignore"
			local serviceName=$(jq -r .inbounds[0].streamSettings.grpcSettings.serviceName ${configPath}06_VLESS_gRPC_inbounds.json)
			jq .inbounds[0].settings.clients ${configPath}06_VLESS_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do
				echoContent skyBlue "\n ---> account number：$(echo "${user}" | jq -r .email )_$(echo "${user}" | jq -r .id)"
				echo
				defaultBase64Code vlessgrpc $(echo "${user}" | jq -r .email) $(echo "${user}" | jq -r .id) "${currentHost}:${currentPort}" ${serviceName} ${currentAdd}
			done
		fi
	fi

	# trojan tcp
	if echo ${currentInstallProtocolType} | grep -q 4; then
		echoContent skyBlue "\n==================================  Trojan TLS  ==================================\n"
		jq .inbounds[0].settings.clients ${configPath}04_trojan_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
			echoContent skyBlue "\n ---> account number：$(echo "${user}" | jq -r .email )_$(echo "${user}" | jq -r .password)"
			echo
			defaultBase64Code trojan trojan $(echo "${user}" | jq -r .password) ${currentHost}
		done
	fi

	if echo ${currentInstallProtocolType} | grep -q 2; then
		echoContent skyBlue "\n================================  Trojan gRPC TLS  ================================\n"
		echoContent red "\n --->gRPC Currently in the test phase, it may not be compatible with the client you use, if you can't use it, please ignore"
		local serviceName=$(jq -r .inbounds[0].streamSettings.grpcSettings.serviceName ${configPath}04_trojan_gRPC_inbounds.json)
		jq .inbounds[0].settings.clients ${configPath}04_trojan_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do
			echoContent skyBlue "\n ---> account number：$(echo "${user}" | jq -r .email )_$(echo "${user}" | jq -r .password)"
			echo
			defaultBase64Code trojangrpc $(echo "${user}" | jq -r .email) $(echo "${user}" | jq -r .password) "${currentHost}:${currentPort}" ${serviceName} ${currentAdd}
		done
	fi

	if [[ -z ${show} ]]; then
		echoContent red " ---> Not Installed"
	fi
}

# Update camouflage station
updateNginxBlog() {
	echoContent skyBlue "\n schedule$1/${totalProgress} : Replace the camouflage site"
	echoContent red "=============================================================="
	echoContent yellow "# To customize, manually copy the template file to /usr/share/nginx/html \n"
	echoContent yellow "1.Beginner's guide"
	echoContent yellow "2.Game website"
	echoContent yellow "3.personal blog01"
	echoContent yellow "4.Businesses"
	echoContent yellow "5.Unlock the encrypted music file template[https://github.com/ix64/unlock-music]"
	echoContent yellow "6.mikutap[https://github.com/HFIProgramming/mikutap]"
	echoContent yellow "7.Enterprise station 02"
	echoContent yellow "8.Personal blog 02"
	echoContent yellow "9.404 Automatic jump Baidu"
	echoContent red "=============================================================="
	read -r -p "please choose：" selectInstallNginxBlogType

	if [[ "${selectInstallNginxBlogType}" =~ ^[1-9]$ ]]; then
#		rm -rf /usr/share/nginx/html
		rm -rf /usr/share/nginx/*
		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /usr/share/nginx "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${selectInstallNginxBlogType}.zip" >/dev/null
		else
			wget -c -P /usr/share/nginx "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${selectInstallNginxBlogType}.zip" >/dev/null
		fi

		unzip -o "/usr/share/nginx/html${selectInstallNginxBlogType}.zip" -d /usr/share/nginx/html >/dev/null
		rm -f "/usr/share/nginx/html${selectInstallNginxBlogType}.zip*"
		echoContent green " ---> Replace the pseudo-station success"
	else
		echoContent red " ---> Select an error, please re-select"
		updateNginxBlog
	fi
}

# Add a new port
addCorePort() {
	echoContent skyBlue "\n Function 1/${totalProgress} : Add a new port"
	echoContent red "\n=============================================================="
	echoContent yellow "# Precautions\n"
	echoContent yellow "Support quantity added"
	echoContent yellow "Does not affect the use of 443 ports"
	echoContent yellow "When you view your account, you will only show the account number of the default port 443."
	echoContent yellow "Do not allow special characters, pay attention to the format of comma"
	echoContent yellow "Entry example: 2053, 2083, 2087\n"

	echoContent yellow "1.Adding ports"
	echoContent yellow "2.Delete port"
	echoContent red "=============================================================="
	read -r -p "please choose:" selectNewPortType
	if [[ "${selectNewPortType}" == "1" ]]; then
		read -r -p "Please enter the port number:" newPort
		if [[ -n "${newPort}" ]]; then

			while read -r port; do
				cat <<EOF >${configPath}02_dokodemodoor_inbounds_${port}.json
{
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${port},
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1",
        "port": 443,
        "network": "tcp",
        "followRedirect": false
      },
      "tag": "dokodemo-door-newPort-${port}"
    }
  ]
}
EOF
			done < <(echo "${newPort}" | tr ',' '\n')

			echoContent green " ---> Added successfully"
			reloadCore
		fi
	elif [[ "${selectNewPortType}" == "2" ]]; then

		ls ${configPath} | grep dokodemodoor | awk -F "[_]" '{print $4}' | awk -F "[.]" '{print ""NR""":"$1}'
		read -r -p "Please enter the port number you want to delete:" portIndex

		local dokoConfig=$(ls ${configPath} | grep dokodemodoor | awk '{print ""NR""":"$1}' | grep ${portIndex}":")
		if [[ -n "${dokoConfig}" ]]; then
			rm ${configPath}/$(echo "${dokoConfig}" | awk -F "[:]" '{print $2}')
			reloadCore
		else
			echoContent yellow "\n ---> Number Enter an error, please re-select"
			addCorePort
		fi
	fi
}

# Uninstall
unInstall() {
	read -r -p "Do you confirm that uninstall installation content?[y/n]:" unInstallStatus
	if [[ "${unInstallStatus}" != "y" ]]; then
		echoContent green " ---> Abandon unload"
		menu
		exit 0
	fi

	handleNginx stop
	if [[ -z $(pgrep -f "nginx") ]]; then
		echoContent green " ---> Stop Nginx success"
	fi

	handleV2Ray stop
#	handleTrojanGo stop
	rm -rf /root/.acme.sh
	echoContent green " ---> Delete acme.sh complete"
	rm -rf /etc/systemd/system/v2ray.service
	echoContent green " ---> Delete V2RAY boot self-start"

	rm -rf /etc/systemd/system/trojan-go.service
	echoContent green " ---> Delete Trojan-GO boot self-start"
	rm -rf /tmp/v2ray-agent-tls/*
	if [[ -d "/etc/v2ray-agent/tls" ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.key") ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.crt") ]]; then
		mv /etc/v2ray-agent/tls /tmp/v2ray-agent-tls
		if [[ -n $(find /tmp/v2ray-agent-tls -name '*.key') ]]; then
			echoContent yellow " ---> Keep paying attention to the backup certificate.[/tmp/v2ray-agent-tls]"
		fi
	fi

	rm -rf /etc/v2ray-agent
	rm -rf /etc/nginx/conf.d/alone.conf
	rm -rf /usr/bin/vasma
	rm -rf /usr/sbin/vasma
	echoContent green " ---> Uninstall shortcut"
	echoContent green " ---> Uninstall V2RAY-Agent script completion"
}

# Modify V2RAY CDN node
updateV2RayCDN() {

	# todo Reconstruct this method
	echoContent skyBlue "\n progress $1/${totalProgress} : Modify CDN node"

	if [[ -n ${currentAdd} ]]; then
		echoContent red "=============================================================="
		echoContent yellow "1.CNAME www.digitalocean.com"
		echoContent yellow "2.CNAME www.cloudflare.com"
		echoContent yellow "3.CNAME hostmonit.com"
		echoContent yellow "4.Manual input"
		echoContent red "=============================================================="
		read -r -p "please choose:" selectCDNType
		case ${selectCDNType} in
		1)
			setDomain="www.digitalocean.com"
			;;
		2)
			setDomain="www.cloudflare.com"
			;;
		3)
			setDomain="hostmonit.com"
			;;
		4)
			read -r -p "Please enter you want to customize CDN IP or domain name:" setDomain
			;;
		esac

		if [[ -n ${setDomain} ]]; then
			if [[ -n ${currentAdd} ]]; then
				sed -i "s/\"${currentAdd}\"/\"${setDomain}\"/g" $(grep "${currentAdd}" -rl ${configPath}${frontingType}.json)
			fi
			if [[ $(jq -r .inbounds[0].settings.clients[0].add ${configPath}${frontingType}.json) == ${setDomain} ]]; then
				echoContent green " ---> CDN is successful"
				reloadCore
			else
				echoContent red " ---> Modify CDN failure"
			fi
		fi
	else
		echoContent red " ---> No available types"
	fi
}

# manageUser User Management
manageUser() {
	echoContent skyBlue "\n progress $1/${totalProgress} : Multi-user management"
	echoContent skyBlue "-----------------------------------------------------"
	echoContent yellow "1.Add user"
	echoContent yellow "2.delete users"
	echoContent skyBlue "-----------------------------------------------------"
	read -r -p "please choose:" manageUserType
	if [[ "${manageUserType}" == "1" ]]; then
		addUser
	elif [[ "${manageUserType}" == "2" ]]; then
		removeUser
	else
		echoContent red " ---> wrong selection"
	fi
}

# Customize UUID
customUUID() {
	read -r -p "Whether to customize UUID ？[y/n]:" customUUIDStatus
	echo
	if [[ "${customUUIDStatus}" == "y" ]]; then
		read -r -p "Please enter the legal UUID:" currentCustomUUID
		echo
		if [[ -z "${currentCustomUUID}" ]]; then
			echoContent red " ---> UUID can not be empty"
		else
			local repeat=
			jq -r -c '.inbounds[0].settings.clients[].id' ${configPath}${frontingType}.json | while read -r line; do
				if [[ "${line}" == "${currentCustomUUID}" ]]; then
					echo repeat >/tmp/v2ray-agent
				fi
			done
			if [[ -f "/tmp/v2ray-agent" && -n $(cat /tmp/v2ray-agent) ]]; then
				echoContent red " ---> UUID is not repeatable"
				rm /tmp/v2ray-agent
				exit 0
			fi
		fi
	fi
}

# Custom Email
customUserEmail() {
	read -r -p "Whether to customize Email ？[y/n]:" customEmailStatus
	echo
	if [[ "${customEmailStatus}" == "y" ]]; then
		read -r -p "Please enter legitimate Email:" currentCustomEmail
		echo
		if [[ -z "${currentCustomEmail}" ]]; then
			echoContent red " ---> Email is not empty"
		else
			local repeat=
			jq -r -c '.inbounds[0].settings.clients[].email' ${configPath}${frontingType}.json | while read -r line; do
				if [[ "${line}" == "${currentCustomEmail}" ]]; then
					echo repeat >/tmp/v2ray-agent
				fi
			done
			if [[ -f "/tmp/v2ray-agent" && -n $(cat /tmp/v2ray-agent) ]]; then
				echoContent red " ---> Email is not repeatable"
				rm /tmp/v2ray-agent
				exit 0
			fi
		fi
	fi
}

# Add user
addUser() {

	echoContent yellow "After adding new users, you need to re-view subscriptions."
	read -r -p "Please enter the number of users you want to add:" userNum
	echo
	if [[ -z ${userNum} || ${userNum} -le 0 ]]; then
		echoContent red " ---> Enter is incorrect, please re-enter"
		exit 0
	fi

	# Generate users
	local users=
	local trojanGoUsers=
	if [[ "${userNum}" == "1" ]]; then
		customUUID
		customUserEmail
	fi

	while [[ ${userNum} -gt 0 ]]; do

		((userNum--)) || true
		if [[ -n "${currentCustomUUID}" ]]; then
			uuid=${currentCustomUUID}
		else
			uuid=$(${ctlPath} uuid)
		fi
		if [[ -n "${currentCustomEmail}" ]]; then
			email=${currentCustomEmail}
		else
			email=${currentHost}_${uuid}
		fi

		if [[ ${userNum} == 0 ]]; then

			users=${users}{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-direct\",\"email\":\"${email}\",\"alterId\":0}

			if echo ${currentInstallProtocolType} | grep -q 4; then
				trojanGoUsers=${trojanGoUsers}\"${uuid}\"
			fi
		else
			users=${users}{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-direct\",\"email\":\"${email}\",\"alterId\":0},

			if echo ${currentInstallProtocolType} | grep -q 4; then
				trojanGoUsers=${trojanGoUsers}\"${uuid}\",
			fi
		fi
	done

	#	Compatible with V2Ray-core
	if [[ "${coreInstallType}" == "2" ]]; then
		#  | sed 's/"flow":"xtls-rprx-direct",/"alterId":1,/g')
		users="${users//\"flow\":\"xtls-rprx-direct\"\,/}"
	fi

	if echo ${currentInstallProtocolType} | grep -q 0; then
		local vlessUsers="${users//\,\"alterId\":0/}"

		local vlessTcpResult
		vlessTcpResult=$(jq -r '.inbounds[0].settings.clients += ['${vlessUsers}']' ${configPath}${frontingType}.json)
		echo "${vlessTcpResult}" | jq . >${configPath}${frontingType}.json
	fi

	if echo ${currentInstallProtocolType} | grep -q trojan; then
		local trojanXTLSUsers="${users//\,\"alterId\":0/}"
		trojanXTLSUsers=${trojanXTLSUsers//"id"/"password"}
		echo trojanXTLSUsers:${trojanXTLSUsers}
		local trojanXTLSResult
		trojanXTLSResult=$(jq -r '.inbounds[0].settings.clients += ['${trojanXTLSUsers}']' ${configPath}${frontingType}.json)
		echo "${trojanXTLSResult}" | jq . >${configPath}${frontingType}.json
	fi

	#	users="${users//"flow":"xtls-rprx-direct",/"alterId":1,}"

	if echo ${currentInstallProtocolType} | grep -q 1; then
		local vlessUsers="${users//\,\"alterId\":0/}"
		vlessUsers="${vlessUsers//\"flow\":\"xtls-rprx-direct\"\,/}"
		local vlessWsResult
		vlessWsResult=$(jq -r '.inbounds[0].settings.clients += ['${vlessUsers}']' ${configPath}03_VLESS_WS_inbounds.json)
		echo "${vlessWsResult}" | jq . >${configPath}03_VLESS_WS_inbounds.json
	fi

	if echo ${currentInstallProtocolType} | grep -q 2; then
		local trojangRPCUsers="${users//\"flow\":\"xtls-rprx-direct\"\,/}"
		trojangRPCUsers="${trojangRPCUsers//\,\"alterId\":0/}"
		trojangRPCUsers=${trojangRPCUsers//"id"/"password"}

		local trojangRPCResult
		trojangRPCResult=$(jq -r '.inbounds[0].settings.clients += ['${trojangRPCUsers}']' ${configPath}04_trojan_gRPC_inbounds.json)
		echo "${trojangRPCResult}" | jq . >${configPath}04_trojan_gRPC_inbounds.json
	fi

	if echo ${currentInstallProtocolType} | grep -q 3; then
		local vmessUsers="${users//\"flow\":\"xtls-rprx-direct\"\,/}"

		local vmessWsResult
		vmessWsResult=$(jq -r '.inbounds[0].settings.clients += ['${vmessUsers}']' ${configPath}05_VMess_WS_inbounds.json)
		echo "${vmessWsResult}" | jq . >${configPath}05_VMess_WS_inbounds.json
	fi

	if echo ${currentInstallProtocolType} | grep -q 5; then
		local vlessGRPCUsers="${users//\"flow\":\"xtls-rprx-direct\"\,/}"
		vlessGRPCUsers="${vlessGRPCUsers//\,\"alterId\":0/}"

		local vlessGRPCResult
		vlessGRPCResult=$(jq -r '.inbounds[0].settings.clients += ['${vlessGRPCUsers}']' ${configPath}06_VLESS_gRPC_inbounds.json)
		echo "${vlessGRPCResult}" | jq . >${configPath}06_VLESS_gRPC_inbounds.json
	fi

	if echo ${currentInstallProtocolType} | grep -q 4; then
		local trojanUsers="${users//\"flow\":\"xtls-rprx-direct\"\,/}"
		trojanUsers="${trojanUsers//id/password}"
		trojanUsers="${trojanUsers//\,\"alterId\":0/}"


		local trojanTCPResult
		trojanTCPResult=$(jq -r '.inbounds[0].settings.clients += ['${trojanUsers}']' ${configPath}04_trojan_TCP_inbounds.json)
		echo "${trojanTCPResult}" | jq . >${configPath}04_trojan_TCP_inbounds.json
	fi

#	if echo ${currentInstallProtocolType} | grep -q 4; then
#		local trojanResult
#		trojanResult=$(jq -r '.password += ['${trojanGoUsers}']' ${configPath}../../trojan/config_full.json)
#		echo "${trojanResult}" | jq . >${configPath}../../trojan/config_full.json
#		handleTrojanGo stop
#		handleTrojanGo start
#	fi

	reloadCore
	echoContent green " ---> Add completion"
	showAccounts 1
}

# Remove user
removeUser() {

	if echo ${currentInstallProtocolType} | grep -q 0 || echo ${currentInstallProtocolType} | grep -q trojan ; then
		jq -r -c .inbounds[0].settings.clients[].email ${configPath}${frontingType}.json | awk '{print NR""":"$0}'
		read -r -p "Please select the user number you want to delete[Also supports single deletion]:" delUserIndex
		if [[ $(jq -r '.inbounds[0].settings.clients|length' ${configPath}${frontingType}.json) -lt ${delUserIndex} ]]; then
			echoContent red " ---> wrong selection"
		else
			delUserIndex=$((${delUserIndex} - 1))
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

		reloadCore
	fi
}
# Update script
updateV2RayAgent() {
	echoContent skyBlue "\n progress  $1/${totalProgress} : Update V2RAY-Agent script"
	rm -rf /etc/v2ray-agent/install.sh
	if wget --help | grep -q show-progress; then
		wget -c -q --show-progress -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
	else
		wget -c -q -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
	fi

	sudo chmod 700 /etc/v2ray-agent/install.sh
	local version=$(cat /etc/v2ray-agent/install.sh | grep 'Current version: v' | awk -F "[v]" '{print $2}' | tail -n +2 | head -n 1 | awk -F "[\"]" '{print $1}')

	echoContent green "\n ---> update completed"
	echoContent yellow " ---> Please manually[vasma]Open script"
	echoContent green " ---> current version:${version}\n"
	echoContent yellow "If the update is unsuccessful, please manually perform the following command.\n"
	echoContent skyBlue "wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh"
	echo
	exit 0
}

# Firewall
handleFirewall(){
	if systemctl status ufw 2>/dev/null|grep -q "active (exited)" && [[ "$1" == "stop" ]]; then
		systemctl stop ufw >/dev/null 2>&1
		systemctl disable ufw >/dev/null 2>&1
		echoContent green " ---> ufw Close successfully"

	fi

	if systemctl status firewalld 2>/dev/null|grep -q "active (running)" && [[ "$1" == "stop" ]]; then
		systemctl stop firewalld >/dev/null 2>&1
		systemctl disable firewalld >/dev/null 2>&1
		echoContent green " ---> firewalld Close successfully"
	fi
}

# install BBR
bbrInstall() {
	echoContent red "\n=============================================================="
	echoContent green "BBR、DDMature works for [YLX2016] with scripts, address [https://github.com/ylx2016/linux-netspeed], please be familiar"
	echoContent yellow "1.Installation script【Recommended original BBR+FQ】"
	echoContent yellow "2.Return the rendering"
	echoContent red "=============================================================="
	read -r -p "please choose:" installBBRStatus
	if [[ "${installBBRStatus}" == "1" ]]; then
		wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
	else
		menu
	fi
}

# View, check the log
checkLog() {
	if [[ -z ${configPath} ]]; then
		echoContent red " ---> No installation directory is detected, please perform script installation content"
	fi
	local logStatus=false
	if [[ -n $(cat ${configPath}00_log.json | grep access) ]]; then
		logStatus=true
	fi

	echoContent skyBlue "\n function $1/${totalProgress} : View log"
	echoContent red "\n=============================================================="
	echoContent yellow "# It is recommended to open the Access log when you debug it.\n"

	if [[ "${logStatus}" == "false" ]]; then
		echoContent yellow "1.Open Access log"
	else
		echoContent yellow "1.Close Access log"
	fi

	echoContent yellow "2.Monitor Access Log"
	echoContent yellow "3.Monitor Error log"
	echoContent yellow "4.View certificate timing task log"
	echoContent yellow "5.View certificate installation log"
	echoContent yellow "6.Empty log"
	echoContent red "=============================================================="

	read -r -p "please choose:" selectAccessLogType
	local configPathLog=${configPath//conf\//}

	case ${selectAccessLogType} in
	1)
		if [[ "${logStatus}" == "false" ]]; then
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

# Script shortcut
aliasInstall() {

	if [[ -f "$HOME/install.sh" ]] && [[ -d "/etc/v2ray-agent" ]] && grep <$HOME/install.sh -q "author：mack-a"; then
		mv "$HOME/install.sh" /etc/v2ray-agent/install.sh
		local vasmaType=
		if [[ -d "/usr/bin/" ]] ; then
			if [[ ! -f "/usr/bin/vasma" ]];then
				ln -s /etc/v2ray-agent/install.sh /usr/bin/vasma
				chmod 700 /usr/bin/vasma
				vasmaType=true
			fi

			rm -rf "$HOME/install.sh"
		elif [[ -d "/usr/sbin" ]] ; then
			if [[ ! -f "/usr/sbin/vasma" ]];then
				ln -s /etc/v2ray-agent/install.sh /usr/sbin/vasma
				chmod 700 /usr/sbin/vasma
				vasmaType=true
			fi
			rm -rf "$HOME/install.sh"
		fi
		if [[ "${vasmaType}" == "true" ]];then
			echoContent green "Quick way to create success, executable[vasma]Re-opening the script"
		fi
	fi
}

# Check IPv6, IPv4
checkIPv6() {
	pingIPv6=$(ping6 -c 1 www.google.com | sed '2{s/[^(]*(//;s/).*//;q;}' | tail -n +2)
	if [[ -z "${pingIPv6}" ]]; then
		echoContent red " ---> IPv6 does not support"
		exit 0
	fi
}

# ipv6 Divert
ipv6Routing() {
	if [[ -z "${configPath}" ]]; then
		echoContent red " ---> Not installed, please use the script installation"
		menu
		exit 0
	fi

	checkIPv6
	echoContent skyBlue "\n function 1/${totalProgress} : IPv6 diversion"
	echoContent red "\n=============================================================="
	echoContent yellow "1.Add domain name"
	echoContent yellow "2.Uninstall IPv6 diversion"
	echoContent red "=============================================================="
	read -r -p "please choose:" ipv6Status
	if [[ "${ipv6Status}" == "1" ]]; then
		echoContent red "=============================================================="
		echoContent yellow "# Precautions\n"
		echoContent yellow "1.Rules only support a predefined domain name list[https://github.com/v2fly/domain-list-community]"
		echoContent yellow "2.Detailed documentation[https://www.v2fly.org/config/routing.html]"
		echoContent yellow "3.If the kernel starts fail, check the domain name and re-add domain name."
		echoContent yellow "4.Do not allow special characters, pay attention to the format of comma"
		echoContent yellow "5.Every time you add it, it is re-added, and the last domain name will not be retained."
		echoContent yellow "6.Enride example:google,youtube,facebook\n"
		read -r -p "Please follow the example name of the above:" domainList

		if [[ -f "${configPath}09_routing.json" ]];then

			unInstallRouting IPv6-out

			routing=$(jq -r '.routing.rules += [{"type":"field","domain":["geosite:'${domainList//,/\",\"geosite:}'"],"outboundTag":"IPv6-out"}]' ${configPath}09_routing.json)

			echo "${routing}"|jq . >${configPath}09_routing.json

		else
			cat <<EOF >${configPath}09_routing.json
{
    "routing":{
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

		outbounds=$(jq -r '.outbounds += [{"protocol":"freedom","settings":{"domainStrategy":"UseIPv6"},"tag":"IPv6-out"}]' ${configPath}10_ipv4_outbounds.json)

		echo "${outbounds}"|jq . >${configPath}10_ipv4_outbounds.json

		echoContent green " ---> Added successfully"

	elif [[ "${ipv6Status}" == "2" ]]; then

		unInstallRouting IPv6-out

		unInstallOutbounds IPv6-out

		echoContent green " ---> IPv6 shunt uninstallation is successful"
	else
		echoContent red " ---> wrong selection"
		exit 0
	fi

	reloadCore
}

# BT download management
btTools() {
	if [[ -z "${configPath}" ]]; then
		echoContent red " ---> Not installed, please use the script installation"
		menu
		exit 0
	fi

	echoContent skyBlue "\n function 1/${totalProgress} : BT download management"
	echoContent red "\n=============================================================="

	if [[ -f ${configPath}09_routing.json ]] && grep -q bittorrent < ${configPath}09_routing.json;then
		echoContent yellow "Current status: Disabled"
	else
		echoContent yellow "Current status: not disabled"
	fi

	echoContent yellow "1.Disable"
	echoContent yellow "2.Open"
	echoContent red "=============================================================="
	read -r -p "please choose:" btStatus
	if [[ "${btStatus}" == "1" ]]; then

		if [[ -f "${configPath}09_routing.json" ]];then

			unInstallRouting blackhole-out

			routing=$(jq -r '.routing.rules += [{"type":"field","outboundTag":"blackhole-out","protocol":["bittorrent"]}]' ${configPath}09_routing.json)

			echo "${routing}"|jq . >${configPath}09_routing.json

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

		echo "${outbounds}"|jq . >${configPath}10_ipv4_outbounds.json



		echoContent green " ---> BT download disabled"

	elif [[ "${btStatus}" == "2" ]]; then

		unInstallSniffing

		unInstallRouting blackhole-out

		unInstallOutbounds blackhole-out

		echoContent green " ---> BT download is successful"
	else
		echoContent red " ---> wrong selection"
		exit 0
	fi

	reloadCore
}

# Uninstall Routing according to TAG
unInstallRouting(){
	local tag=$1

	if [[ -f "${configPath}09_routing.json" ]];then
		local routing=
		if grep -q "${tag}" ${configPath}09_routing.json;then
			local index=$(jq .routing.rules[].outboundTag ${configPath}09_routing.json|awk '{print ""NR""":"$0}'|grep "${tag}"|awk -F "[:]" '{print $1}'|head -1)
			if [[ ${index} -gt 0 ]];then
				routing=$(jq -r 'del(.routing.rules['$(expr ${index} - 1)'])' ${configPath}09_routing.json)
				echo "${routing}" |jq . >${configPath}09_routing.json
			fi
		fi
	fi
}

# Uninstalling station according to TAG
unInstallOutbounds(){
	local tag=$1

	if grep -q "${tag}" ${configPath}10_ipv4_outbounds.json;then
		local ipv6OutIndex=$(jq .outbounds[].tag ${configPath}10_ipv4_outbounds.json|awk '{print ""NR""":"$0}'|grep "${tag}"|awk -F "[:]" '{print $1}'|head -1)
		if [[ ${ipv6OutIndex} -gt 0 ]];then
			routing=$(jq -r 'del(.outbounds['$(expr ${ipv6OutIndex} - 1)'])' ${configPath}10_ipv4_outbounds.json)
			echo "${routing}" |jq . >${configPath}10_ipv4_outbounds.json
		fi
	fi

}

# Uninstall
unInstallSniffing(){
	ls ${configPath}|grep inbounds.json|while read -r inbound;do
		sniffing=$(jq -r 'del(.inbounds[0].sniffing)' ${configPath}${inbound})
		echo "${sniffing}" |jq . >${configPath}${inbound}
	done
}

# Install a sniff
installSniffing(){
	ls ${configPath}|grep inbounds.json|while read -r inbound;do
		sniffing=$(jq -r '.inbounds[0].sniffing = {"enabled":true,"destOverride":["http","tls"]}' ${configPath}${inbound})
		echo "${sniffing}" |jq . >${configPath}${inbound}
	done
}

# WARP diversion
warpRouting(){
	echoContent skyBlue "\n   $1/${totalProgress} : WARP diversion"
	echoContent red "=============================================================="
	echoContent yellow "# Cautions\n"
	echoContent yellow "1.The official warp has a bug after several rounds of testing, rebooting will cause warp to fail and not start, there is also a possibility of CPU usage spike"
	echoContent yellow "2.It can be used normally without rebooting the machine, if you have to use the official warp, it is recommended not to reboot the machine"
	echoContent yellow "3.Some machines still work normally after reboot"
	echoContent yellow "4.Uninstall and reinstall if you can't use it after reboot"
	# Install WARP
	if [[ -z $(which warp-cli) ]];then
		echo
		read -r -p "WARP not installed, installed or not ？[y/n]:" installCloudflareWarpStatus
		if [[ "${installCloudflareWarpStatus}" == "y" ]];then
			installWarp
		else
			echoContent yellow " ---> Abandonment of installation"
			exit 0
		fi
	fi

	echoContent red "\n=============================================================="
	echoContent yellow "1.Add Domain"
	echoContent yellow "2.Uninstall the WARP diversion"
	echoContent red "=============================================================="
	read -r -p "please choose:" warpStatus
	if [[ "${warpStatus}" == "1" ]]; then
		echoContent red "=============================================================="
		echoContent yellow "# Cautions\n"
		echoContent yellow "1.Rules only support predefined domain lists[https://github.com/v2fly/domain-list-community]"
		echoContent yellow "2.Detailed documentation[https://www.v2fly.org/config/routing.html]"
		echoContent yellow "3.You can only divert traffic to warp, you cannot specify ipv4 or ipv6"
		echoContent yellow "4.If the kernel fails to start, please check the domain name and add it again"
		echoContent yellow "5.No special characters allowed, note the comma format"
		echoContent yellow "6.Each time you add it, it is re-added and will not keep the last domain name"
		echoContent yellow "7.Entry Example:google,youtube,facebook\n"
		read -r -p "Please enter the domain name according to the example above：" domainList

		if [[ -f "${configPath}09_routing.json" ]];then
			unInstallRouting warp-socks-out

			routing=$(jq -r '.routing.rules += [{"type":"field","domain":["geosite:'${domainList//,/\",\"geosite:}'"],"outboundTag":"warp-socks-out"}]' ${configPath}09_routing.json)

			echo "${routing}"|jq . >${configPath}09_routing.json

		else
			cat <<EOF >${configPath}09_routing.json
{
    "routing":{
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

		local outbounds=$(jq -r '.outbounds += [{"protocol":"socks","settings":{"servers":[{"address":"127.0.0.1","port":31303}]},"tag":"warp-socks-out"}]' ${configPath}10_ipv4_outbounds.json)

		echo "${outbounds}"|jq . >${configPath}10_ipv4_outbounds.json

		echoContent green " ---> Added successfully"

	elif [[ "${warpStatus}" == "2" ]]; then

		${removeType} cloudflare-warp >/dev/null 2>&1

		unInstallRouting warp-socks-out

		unInstallOutbounds warp-socks-out

		echoContent green " ---> WARP shunt uninstall success"
	else
		echoContent red " ---> wrong selection"
		exit 0
	fi
	reloadCore
}
# Streaming media toolbox
streamingToolbox() {
	echoContent skyBlue "\n function 1/${totalProgress} : Streaming media toolbox"
	echoContent red "\n=============================================================="
#   echoContent yellow "1.Netflix detection"
	echoContent yellow "1.Any door floor machine unlock Netflix"
	echoContent yellow "2.DNS unlock stream"
	read -r -p "please choose:" selectType

	case ${selectType} in
#	1)
#		checkNetflix
#		;;
	1)
		checkNetflix
		;;
	1)
		dokodemoDoorUnblockNetflix
		;;
	2)
		dnsUnlockNetflix
		;;
	esac

}

# Any door unlock Netflix
dokodemoDoorUnblockNetflix() {
	echoContent skyBlue "\n function 1/${totalProgress} : Any door floor machine unlock Netflix"
	echoContent red "\n=============================================================="
	echoContent yellow "# Precautions"
	echoContent yellow "Any door unlock detailed, please check this article[https://github.com/mack-a/v2ray-agent/blob/master/documents/netflix/dokodemo-unblock_netflix.md]\n"

	echoContent yellow "1.Add an outbound"
	echoContent yellow "2.Adding a station"
	echoContent yellow "3.Uninstall"
	read -r -p "please choose:" selectType

	case ${selectType} in
	1)
		setDokodemoDoorUnblockNetflixOutbounds
		;;
	2)
		setDokodemoDoorUnblockNetflixInbounds
		;;
	3)
		removeDokodemoDoorUnblockNetflix
		;;
	esac
}

# Set any door unlock Netflix@ outbound]
setDokodemoDoorUnblockNetflixOutbounds() {
	read -r -p "Please enter unlock Netflix VPS IP:" setIP
	if [[ -n "${setIP}" ]]; then

		unInstallOutbounds netflix-80
		unInstallOutbounds netflix-443

		outbounds=$(jq -r '.outbounds += [{"tag":"netflix-80","protocol":"freedom","settings":{"domainStrategy":"AsIs","redirect":"'${setIP}':22387"}},{"tag":"netflix-443","protocol":"freedom","settings":{"domainStrategy":"AsIs","redirect":"'${setIP}':22388"}}]' ${configPath}10_ipv4_outbounds.json)

		echo "${outbounds}"|jq . >${configPath}10_ipv4_outbounds.json

		if [[ -f "${configPath}09_routing.json" ]] ;then
			unInstallRouting netflix-80
			unInstallRouting netflix-443

			local routing=$(jq -r '.routing.rules += [{"type":"field","port":80,"domain":["ip.sb","geosite:netflix"],"outboundTag":"netflix-80"},{"type":"field","port":443,"domain":["ip.sb","geosite:netflix"],"outboundTag":"netflix-443"}]' ${configPath}09_routing.json)
			echo "${routing}"|jq . >${configPath}09_routing.json
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
          "geosite:netflix"
        ],
        "outboundTag": "netflix-80"
      },
      {
        "type": "field",
        "port": 443,
        "domain": [
          "ip.sb",
          "geosite:netflix"
        ],
        "outboundTag": "netflix-443"
      }
    ]
  }
}
EOF
		fi
		reloadCore
		echoContent green " ---> Add Netflix to unlock successfully"
#		echoContent yellow " ---> Trojan related nodes do not support"
		exit 0
	fi
	echoContent red " ---> IP cannot be empty"
}

# Set up any door unlock Netflix [inbound]
setDokodemoDoorUnblockNetflixInbounds() {

	echoContent skyBlue "\n function 1/${totalProgress} : Any door to add station"
	echoContent red "\n=============================================================="
	echoContent yellow "# Precautions\n"
	echoContent yellow "Support quantity added"
	echoContent yellow "Do not allow special characters, pay attention to the format of comma"
	echoContent yellow "Enride example:1.1.1.1,1.1.1.2\n"
	read -r -p "Please enter the allowed access to the unlock Netflix VPS IP:" setIPs
	if [[ -n "${setIPs}" ]]; then
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
      "tag": "unblock-80"
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
      "tag": "unblock-443"
    }
  ]
}
EOF

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

		cat <<EOF >${configPath}09_routing.json
{
  "routing": {
    "rules": [
      {
        "source": [],
        "type": "field",
        "inboundTag": [
          "unblock-80",
          "unblock-443"
        ],
        "outboundTag": "direct"
      },
      {
        "domains": [
        	"geosite:netflix"
        ],
        "type": "field",
        "inboundTag": [
          "unblock-80",
          "unblock-443"
        ],
        "outboundTag": "blackhole-out"
      }
    ]
  }
}
EOF
		local ips=
		while read -r ip; do
			if [[ -z ${ips} ]];then
				ips=\"${ip}\"
			else
				ips=${ips},\"${ip}\"
			fi
		done< <(echo ${setIPs}|tr ',' '\n')

		local routing=$(jq -r '.routing.rules[0].source += ['${ips}']' ${configPath}09_routing.json)
		echo "${routing}" | jq . >${configPath}09_routing.json
		reloadCore
		echoContent green " ---> Add a landing machine entry to unlock Netflix success"
		exit 0
	fi
	echoContent red " ---> IP cannot be empty"
}

# Remove any door unlock Netflix
removeDokodemoDoorUnblockNetflix() {

	unInstallOutbounds netflix-80
	unInstallOutbounds netflix-443
	unInstallRouting netflix-80
	unInstallRouting netflix-443
	rm -rf ${configPath}01_netflix_inbounds.json

	reloadCore
	echoContent green " ---> Uninstall success"
}

# Restart the core
reloadCore() {
	if [[ "${coreInstallType}" == "1" ]]; then
		handleXray stop
		handleXray start
	elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
		handleV2Ray stop
		handleV2Ray start
	fi
}

# an examination Does VPS support Netflix
checkNetflix() {
	echoContent red "\n precautions"
	echoContent yellow " 1.Only if the VPS can support Netflix"
	echoContent yellow " 2.Netflix supports Netflix after the agent is not detecting the agent configuration DNS unlock"
	echoContent yellow " 3.Can detect VPS configuration DNS unlocking Netflix\n"
	echoContent skyBlue " ---> checking"
	netflixResult=$(curl -s -m 2 https://www.netflix.com | grep "Not Available")
	if [[ -n ${netflixResult} ]]; then
		echoContent red " ---> Netflix is not available"
		exit 0
	fi

	netflixResult=$(curl -s -m 2 https://www.netflix.com | grep "NSEZ-403")
	if [[ -n ${netflixResult} ]]; then
		echoContent red " ---> Netflix is not available"
		exit 0
	fi

	echoContent skyBlue " ---> Detect whether the desperate poisoning teacher can play"
	result=$(curl -s -m 2 https://www.netflix.com/title/70143836 | grep "page-404")
	if [[ -n ${result} ]]; then
		echoContent green " ---> Only"
		exit 0
	fi
	echoContent green " ---> Netflix unlocked"
	exit 0
}

# DNS unlock Netflix
dnsUnlockNetflix() {
	echoContent skyBlue "\n function 1/${totalProgress} : DNS unlock Netflix"
	echoContent red "\n=============================================================="
	echoContent yellow "1.Add to"
	echoContent yellow "2.Uninstall"
	read -r -p "please choose:" selectType

	case ${selectType} in
	1)
		setUnlockDNS
		;;
	2)
		removeUnlockDNS
		;;
	esac
}

# Set DNS
setUnlockDNS() {
	read -r -p "Please enter the DNS unlocked Netflix:" setDNS
	if [[ -n ${setDNS} ]]; then
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
		reloadCore

		echoContent green "\n ---> DNS unlocks add success, this setting is invalid for Trojan-Go"
		echoContent yellow "\n ---> If you can't watch it, you can try the following two programs."
		echoContent yellow " 1.Restart VPS"
		echoContent yellow " 2.After uninstalling the DNS unlock, modify the local [/etc/resolv.conf]DNs settings and restart VPS \ N)"
	else
		echoContent red " ---> DNS cannot be empty"
	fi
	exit 0
}

# Remove Netflix unlock
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

	echoContent green " ---> Uninstall success"

	exit 0
}

# v2ray-Core Personalization
customV2RayInstall() {
	echoContent skyBlue "\n========================Personalization installation============================"
	echoContent yellow "Vless front, you must install 0, if you only need to install 0, enter"
	if [[ "${selectCoreType}" == "2" ]]; then
		echoContent yellow "0.VLESS+TLS+TCP"
	else
		echoContent yellow "0.VLESS+TLS/XTLS+TCP"
	fi

	echoContent yellow "1.VLESS+TLS+WS[CDN]"
	echoContent yellow "2.VMess+TLS+TCP"
	echoContent yellow "3.VMess+TLS+WS[CDN]"
#	echoContent yellow "4.Trojan、Trojan+WS[CDN]"
	echoContent yellow "4.Trojan"
	echoContent yellow "5.VLESS+TLS+gRPC[CDN]"
	read -r -p "Please select [Multiple Select], [for example: 123]:" selectCustomInstallType
	echoContent skyBlue "--------------------------------------------------------------"
	if [[ -z ${selectCustomInstallType} ]]; then
		selectCustomInstallType=0
	fi
	if [[ "${selectCustomInstallType}" =~ ^[0-5]+$ ]]; then
		cleanUp xrayClean
		totalProgress=17
		installTools 1
		# Apply for TLS
		initTLSNginxConfig 2
		installTLS 3
		handleNginx stop
		if echo ${selectCustomInstallType} | grep -q 1 || echo ${selectCustomInstallType} | grep -q 3 || echo ${selectCustomInstallType} | grep -q 4; then
			randomPathFunction 5
			customCDNIP 6
		fi
		nginxBlog 7
		updateRedirectNginxConf
		handleNginx start

		# Install v2ray
		installV2Ray 8
		installV2RayService 9
		initV2RayConfig custom 10
		cleanUp xrayDel
		installCronTLS 14
		handleV2Ray stop
		handleV2Ray start
		# Account
		checkGFWStatue 15
		showAccounts 16
	else
		echoContent red " ---> Input is not legal"
		customV2RayInstall
	fi
}

# Xray-core Personalization installation
customXrayInstall() {
	echoContent skyBlue "\n========================Personalization installation============================"
	echoContent yellow "Vless front, default installation 0, if only 0 is required, only 0 can be selected"
	echoContent yellow "0.VLESS+TLS/XTLS+TCP"
	echoContent yellow "1.VLESS+TLS+WS[CDN]"
	echoContent yellow "2.Trojan+TLS+gRPC[CDN]"
	echoContent yellow "3.VMess+TLS+WS[CDN]"
	# echoContent yellow "4.Trojan、Trojan+WS[CDN]"
	echoContent yellow "4.Trojan"
	echoContent yellow "5.VLESS+TLS+gRPC[CDN]"
	read -r -p "Please select [Multiple Select], [for example: 123]:" selectCustomInstallType
	echoContent skyBlue "--------------------------------------------------------------"
	if [[ -z ${selectCustomInstallType} ]]; then
		echoContent red " ---> Cannot be empty"
		customXrayInstall
	elif [[ "${selectCustomInstallType}" =~ ^[0-5]+$ ]]; then
		cleanUp v2rayClean
		totalProgress=17
		installTools 1
		# Apply for TLS
		initTLSNginxConfig 2
		installTLS 3
		handleNginx stop

		if echo "${selectCustomInstallType}" | grep -q 1 || echo "${selectCustomInstallType}" | grep -q 2 || echo "${selectCustomInstallType}" | grep -q 3 || echo "${selectCustomInstallType}" | grep -q 5; then
			randomPathFunction 5
			customCDNIP 6
		fi
		nginxBlog 7
		updateRedirectNginxConf
		handleNginx start

		# Install v2ray
		installXray 8
		installXrayService 9
		initXrayConfig custom 10
		cleanUp v2rayDel

		installCronTLS 14
		handleXray stop
		handleXray start
		# Account
		checkGFWStatue 15
		showAccounts 16
	else
		echoContent red " ---> Input is not legal"
		customXrayInstall
	fi
}

# Select the core installation --- v2ray-core, xray-core, lock version of V2RAY-CORE [XTLS]
selectCoreInstall() {
	echoContent skyBlue "\n function 1/${totalProgress} : Select core installation"
	echoContent red "\n=============================================================="
	echoContent yellow "1.Xray-core"
	echoContent yellow "2.v2ray-core"
	echoContent red "=============================================================="
	read -r -p "please choose:" selectCoreType
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
		echoContent red ' ---> Select an error, reselect'
		selectCoreInstall
		;;
	esac
}

# v2ray-core Install
v2rayCoreInstall() {
	cleanUp xrayClean
	selectCustomInstallType=
	totalProgress=13
	installTools 2
	# Apply for tls
	initTLSNginxConfig 3
	installTLS 4
	handleNginx stop
    # initNginxConfig 5
	randomPathFunction 5
	# Installing V2Ray
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
	# Generate account
	checkGFWStatue 12
	showAccounts 13
}

# xray-core Install
xrayCoreInstall() {
	cleanUp v2rayClean
	selectCustomInstallType=
	totalProgress=13
	installTools 2
	# Apply for tls
	initTLSNginxConfig 3
	installTLS 4
	handleNginx stop
	randomPathFunction 5
	# Installing Xray
	handleV2Ray stop
	installXray 6
	installXrayService 7
	customCDNIP 8
	initXrayConfig all 9
	cleanUp v2rayDel
	installCronTLS 10
	nginxBlog 11
	updateRedirectNginxConf
	handleXray stop
	sleep 2
	handleXray start

	handleNginx start
	# Generate account
	checkGFWStatue 12
	showAccounts 13
}

# Core management
coreVersionManageMenu() {

	if [[ -z "${coreInstallType}" ]]; then
		echoContent red "\n ---> No installation directory is detected, please perform script installation content"
		menu
		exit 0
	fi
	if [[ "${coreInstallType}" == "1" ]]; then
		xrayVersionManageMenu 1
	elif [[ "${coreInstallType}" == "2" ]]; then
		v2rayCoreVersion=
		v2rayVersionManageMenu 1

	elif [[ "${coreInstallType}" == "3" ]]; then
		v2rayCoreVersion=v4.32.1
		v2rayVersionManageMenu 1
	fi
}
# Timing task check certificate
cronRenewTLS() {
	if [[ "${renewTLS}" == "RenewTLS" ]]; then
		renewalTLS
		exit 0
	fi
}
# Account management
manageAccount() {
	echoContent skyBlue "\n function 1/${totalProgress} : Account management"
	echoContent red "\n=============================================================="
	echoContent yellow "# Every time you delete, after adding an account, you need to re-view subscription generation subscriptions.\n"
	echoContent yellow "1.View account"
	echoContent yellow "2.View subscriptions"
	echoContent yellow "3.Add user"
	echoContent yellow "4.delete users"
	echoContent red "=============================================================="
	read -r -p "please enter:" manageAccountStatus
	if [[ "${manageAccountStatus}" == "1" ]]; then
		showAccounts 1
	elif [[ "${manageAccountStatus}" == "2" ]]; then
		subscribe 1
	elif [[ "${manageAccountStatus}" == "3" ]]; then
		addUser
	elif [[ "${manageAccountStatus}" == "4" ]]; then
		removeUser
	else
		echoContent red " ---> wrong selection"
	fi
}

# subscription
subscribe() {
	if [[ -n "${configPath}" ]]; then
		echoContent skyBlue "-------------------------Remark---------------------------------"
		echoContent yellow "# When you check the subscription, you will regenerate your subscription."
		echoContent yellow "# Each time you add, delete your account needs to reserve subscriptions"
		rm -rf /etc/v2ray-agent/subscribe/*
		rm -rf /etc/v2ray-agent/subscribe_tmp/*
		showAccounts >/dev/null
		mv /etc/v2ray-agent/subscribe_tmp/* /etc/v2ray-agent/subscribe/

		if [[ -n $(ls /etc/v2ray-agent/subscribe) ]]; then
			ls /etc/v2ray-agent/subscribe | while read -r email; do
				local base64Result=$(base64 -w 0 /etc/v2ray-agent/subscribe/${email})
				echo ${base64Result} >"/etc/v2ray-agent/subscribe/${email}"
				echoContent skyBlue "--------------------------------------------------------------"
				echoContent yellow "email：$(echo "${email}" | awk -F "[_]" '{print $1}')\n"
				echoContent yellow "url：https://${currentHost}/s/${email}\n"
				echoContent yellow "Online QR code：https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://${currentHost}/s/${email}\n"
				echo "https://${currentHost}/s/${email}" | qrencode -s 10 -m 1 -t UTF8
				echoContent skyBlue "--------------------------------------------------------------"
			done
		fi
	else
		echoContent red " ---> Not Installed"
	fi
}

# main menu
menu() {
	cd "$HOME" || exit
	echoContent red "\n=============================================================="
	echoContent green "author：mack-a"
	echoContent green "current version：v2.5.28"
	echoContent green "Github：https://github.com/mack-a/v2ray-agent"
	echoContent green "describe：Eight-in-one copy script\c"
	showInstallStatus
	echoContent red "\n=============================================================="
	if [[ -n "${coreInstallType}" ]]; then
		echoContent yellow "1.re-install"
	else
		echoContent yellow "1.Install"
	fi

	echoContent yellow "2.Arbitrary combination installation"
	if echo ${currentInstallProtocolType} | grep -q trojan; then
		echoContent yellow "3.Switch VLESS[XTLS]"
	elif echo ${currentInstallProtocolType} | grep -q 0;then
		echoContent yellow "3.Switch Trojan[XTLS]"
	fi
	echoContent skyBlue "-------------------------Tool management-----------------------------"
	echoContent yellow "4.Account management"
	echoContent yellow "5.Replace the camouflage station"
	echoContent yellow "6.Update certificate"
	echoContent yellow "7.Replace CDN node"
	echoContent yellow "8.IPv6 Divert"
	echoContent yellow "9.WARP diversion"
	echoContent yellow "10.Stream media tool"
	echoContent yellow "11.Add a new port"
	echoContent yellow "12.BT download management"
	echoContent skyBlue "-------------------------Version management-----------------------------"
	echoContent yellow "13.Core Management"
	echoContent yellow "14.Update script"
	echoContent yellow "15.Install BBR, DD script"
	echoContent skyBlue "-------------------------Scripting management-----------------------------"
	echoContent yellow "16.View log"
	echoContent yellow "17.Uninstall"
	echoContent red "=============================================================="
	mkdirTools
	aliasInstall
	read -r -p "please choose:" selectInstallType
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
		manageAccount 1
		;;
	5)
		updateNginxBlog 1
		;;
	6)
		renewalTLS 1
		;;
	7)
		updateV2RayCDN 1
		;;
	8)
		ipv6Routing 1
		;;
	9)
		warpRouting 1
		;;
	10)
		streamingToolbox 1
		;;
	11)
		addCorePort 1
		;;
	12)
		btTools 1
		;;
	13)
		coreVersionManageMenu 1
		;;
	14)
		updateV2RayAgent 1
		;;
	15)
		bbrInstall
		;;
	16)
		checkLog 1
		;;
	17)
		unInstall 1
		;;
	esac
}
cronRenewTLS
menu
