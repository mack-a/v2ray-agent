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

	elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
		release="debian"
		installType='apt -y install'
		upgrade="apt update"
		updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
		removeType='apt -y autoremove'

	elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
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
				;;
			'armv8' | 'aarch64')
				xrayCoreCPUVendor="Xray-linux-arm64-v8a"
				v2rayCoreCPUVendor="v2ray-linux-arm64-v8a"
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

	localIP=

	# 集成更新证书逻辑不再使用单独的脚本--RenewTLS
	renewTLS=$1

	# tls安装失败后尝试的次数
	installTLSCount=

	# BTPanel状态
	BTPanelStatus=

	# nginx配置文件路径
	nginxConfigPath=/etc/nginx/conf.d/
}

# 检测安装方式
readInstallType() {
	coreInstallType=
	configPath=

	# 1.检测安装目录
	if [[ -d "/etc/v2ray-agent" ]]; then
		# 检测安装方式 v2ray-core
		if [[ -d "/etc/v2ray-agent/v2ray" && -f "/etc/v2ray-agent/v2ray/v2ray" && -f "/etc/v2ray-agent/v2ray/v2ctl" ]]; then
			if [[ -d "/etc/v2ray-agent/v2ray/conf" && -f "/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json" ]]; then
				configPath=/etc/v2ray-agent/v2ray/conf/

				if ! grep </etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json -q xtls; then
					# 不带XTLS的v2ray-core
					coreInstallType=2
					ctlPath=/etc/v2ray-agent/v2ray/v2ctl
				elif grep </etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json -q xtls; then
					# 带XTLS的v2ray-core
					ctlPath=/etc/v2ray-agent/v2ray/v2ctl
					coreInstallType=3
				fi
			fi
		fi

		if [[ -d "/etc/v2ray-agent/xray" && -f "/etc/v2ray-agent/xray/xray" ]]; then
			# 这里检测xray-core
			if [[ -d "/etc/v2ray-agent/xray/conf" ]] && [[ -f "/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json" || -f "/etc/v2ray-agent/xray/conf/02_trojan_TCP_inbounds.json" ]]; then
				# xray-core
				configPath=/etc/v2ray-agent/xray/conf/
				ctlPath=/etc/v2ray-agent/xray/xray
				coreInstallType=1
			fi
		fi
	fi
}

# 读取协议类型
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
}

# 检查是否安装宝塔
checkBTPanel() {
	if pgrep -f "BT-Panel"; then
		nginxConfigPath=/www/server/panel/vhost/nginx/
		BTPanelStatus=true
	fi
}
# 读取当前alpn的顺序
readInstallAlpn() {
	if [[ -n ${currentInstallProtocolType} ]]; then
		local alpn
		alpn=$(jq -r .inbounds[0].streamSettings.xtlsSettings.alpn[0] ${configPath}${frontingType}.json)
		if [[ -n ${alpn} ]]; then
			currentAlpn=${alpn}
		fi
	fi
}

# 检查防火墙
allowPort() {
	# 如果防火墙启动状态则添加相应的开放端口
	if systemctl status netfilter-persistent 2>/dev/null | grep -q "active (exited)"; then
		local updateFirewalldStatus=
		if ! iptables -L | grep -q "http(mack-a)"; then
			updateFirewalldStatus=true
			iptables -I INPUT -p tcp --dport 80 -m comment --comment "allow http(mack-a)" -j ACCEPT
		fi

		if ! iptables -L | grep -q "https(mack-a)"; then
			updateFirewalldStatus=true
			iptables -I INPUT -p tcp --dport 443 -m comment --comment "allow https(mack-a)" -j ACCEPT
		fi

		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			netfilter-persistent save
		fi
	elif systemctl status ufw 2>/dev/null | grep -q "active (exited)"; then
		if ! ufw status | grep -q 443; then
			sudo ufw allow https
			checkUFWAllowPort 443
		fi

		if ! ufw status | grep -q 80; then
			sudo ufw allow 80
			checkUFWAllowPort 80
		fi
	elif systemctl status firewalld 2>/dev/null | grep -q "active (running)"; then
		local updateFirewalldStatus=
		if ! firewall-cmd --list-ports --permanent | grep -qw "80/tcp"; then
			updateFirewalldStatus=true
			firewall-cmd --zone=public --add-port=80/tcp --permanent
			checkFirewalldAllowPort 80
		fi

		if ! firewall-cmd --list-ports --permanent | grep -qw "443/tcp"; then
			updateFirewalldStatus=true
			firewall-cmd --zone=public --add-port=443/tcp --permanent
			checkFirewalldAllowPort 443
		fi
		if echo "${updateFirewalldStatus}" | grep -q "true"; then
			firewall-cmd --reload
		fi
	fi
}

# 检查80、443端口占用情况
checkPortUsedStatus() {
	if lsof -i tcp:80 | grep -q LISTEN; then
		echoContent red "\n ---> 80端口被占用，请手动关闭后安装\n"
		lsof -i tcp:80 | grep LISTEN
		exit 0
	fi

	if lsof -i tcp:443 | grep -q LISTEN; then
		echoContent red "\n ---> 443端口被占用，请手动关闭后安装\n"
		lsof -i tcp:80 | grep LISTEN
		exit 0
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

# 输出ufw端口开放状态
checkFirewalldAllowPort() {
	if firewall-cmd --list-ports --permanent | grep -q "$1"; then
		echoContent green " ---> $1端口开放成功"
	else
		echoContent red " ---> $1端口开放失败"
		exit 0
	fi
}
# 检查文件目录以及path路径
readConfigHostPathUUID() {
	currentPath=
	currentUUID=
	currentHost=
	currentPort=
	currentAdd=
	# 读取path
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
	fi

	if [[ "${coreInstallType}" == "1" ]]; then
		currentHost=$(jq -r .inbounds[0].streamSettings.xtlsSettings.certificates[0].certificateFile ${configPath}${frontingType}.json | awk -F '[t][l][s][/]' '{print $2}' | awk -F '[.][c][r][t]' '{print $1}')
		currentUUID=$(jq -r .inbounds[0].settings.clients[0].id ${configPath}${frontingType}.json)
		currentAdd=$(jq -r .inbounds[0].settings.clients[0].add ${configPath}${frontingType}.json)
		if [[ "${currentAdd}" == "null" ]]; then
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

		if [[ "${currentAdd}" == "null" ]]; then
			currentAdd=${currentHost}
		fi
		currentUUID=$(jq -r .inbounds[0].settings.clients[0].id ${configPath}${frontingType}.json)
		currentPort=$(jq .inbounds[0].port ${configPath}${frontingType}.json)
	fi
}

# 状态展示
showInstallStatus() {
	if [[ -n "${coreInstallType}" ]]; then
		if [[ "${coreInstallType}" == 1 ]]; then
			if [[ -n $(pgrep -f xray/xray) ]]; then
				echoContent yellow "\n核心：Xray-core[运行中]"
			else
				echoContent yellow "\n核心：Xray-core[未运行]"
			fi

		elif [[ "${coreInstallType}" == 2 || "${coreInstallType}" == 3 ]]; then
			if [[ -n $(pgrep -f v2ray/v2ray) ]]; then
				echoContent yellow "\n核心：v2ray-core[运行中]"
			else
				echoContent yellow "\n核心：v2ray-core[未运行]"
			fi
		fi
		# 读取协议类型
		readInstallProtocolType

		if [[ -n ${currentInstallProtocolType} ]]; then
			echoContent yellow "已安装协议：\c"
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
checkBTPanel

# -------------------------------------------------------------

# 初始化安装目录
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

# 安装工具包
installTools() {
	echo '安装工具'
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

	# 检测nginx版本，并提供是否卸载的选项

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

	if [[ ! -d "$HOME/.acme.sh" ]] || [[ -d "$HOME/.acme.sh" && -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
		echoContent green " ---> 安装acme.sh"
		curl -s https://get.acme.sh | sh -s >/etc/v2ray-agent/tls/acme.log 2>&1
		if [[ ! -d "$HOME/.acme.sh" ]] || [[ -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
			echoContent red "  acme安装失败--->"
			tail -n 100 /etc/v2ray-agent/tls/acme.log
			echoContent yellow "错误排查："
			echoContent red "  1.获取Github文件失败，请等待Gitub恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
			echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
			exit 0
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
	#	if [[]];then
	#	fi
	# todo curl --socks5 127.0.0.1:31303 https://www.cloudflare.com/cdn-cgi/trace
	# systemctl daemon-reload
	# systemctl enable cloudflare-warp
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
			echoContent yellow "\n ---> 域名：${domain}"
		else
			echo
			echoContent yellow "请输入要配置的域名 例：www.v2ray-agent.com --->"
			read -r -p "域名:" domain
		fi
	else
		echo
		echoContent yellow "请输入要配置的域名 例：www.v2ray-agent.com --->"
		read -r -p "域名:" domain
	fi

	if [[ -z ${domain} ]]; then
		echoContent red "  域名不可为空--->"
		initTLSNginxConfig
	else
		# 修改配置
		touch ${nginxConfigPath}alone.conf
		cat <<EOF >${nginxConfigPath}alone.conf
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
		# 启动nginx
		handleNginx start
		checkIP
	fi
}

# 修改nginx重定向配置
updateRedirectNginxConf() {

	if [[ ${BTPanelStatus} = "true" ]]; then

		cat <<EOF >${nginxConfigPath}alone.conf
        server {
        		listen 127.0.0.1:31300;
        		server_name _;
        		return 403;
        }
EOF

	else
		cat <<EOF >${nginxConfigPath}alone.conf
        server {
        	listen 80;
        	listen [::]:80;
        	server_name ${domain};
        	# shellcheck disable=SC2154
        	return 301 https://${domain}\${request_uri};
        }
        server {
        		listen 127.0.0.1:31300;
        		server_name _;
        		return 403;
        }
EOF
	fi

	if echo "${selectCustomInstallType}" | grep -q 2 && echo "${selectCustomInstallType}" | grep -q 5 || [[ -z "${selectCustomInstallType}" ]]; then

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

# 检查ip
checkIP() {
	echoContent skyBlue "\n ---> 检查域名ip中"
	localIP=$(curl -s -m 2 "${domain}/ip")
	handleNginx stop
	if [[ -z ${localIP} ]] || ! echo "${localIP}" | sed '1{s/[^(]*(//;s/).*//;q}' | grep -q '\.' && ! echo "${localIP}" | sed '1{s/[^(]*(//;s/).*//;q}' | grep -q ':'; then
		echoContent red "\n ---> 未检测到当前域名的ip"
		echoContent yellow " ---> 请检查域名是否书写正确"
		echoContent yellow " ---> 请检查域名dns解析是否正确"
		echoContent yellow " ---> 如解析正确，请等待dns生效，预计三分钟内生效"
		echoContent yellow " ---> 如以上设置都正确，请重新安装纯净系统后再次尝试"
		if [[ -n ${localIP} ]]; then
			echoContent yellow " ---> 检测返回值异常，建议手动卸载nginx后重新执行脚本"
		fi
		echoContent red " ---> 请检查防火墙规则是否开放443、80\n"
		read -r -p "是否通过脚本修改防火墙规则开放443、80端口？[y/n]:" allPortFirewallStatus
		if [[ ${allPortFirewallStatus} == "y" ]]; then
			allowPort
			handleNginx start
			checkIP
		else
			exit 0
		fi
	else
		if echo "${localIP}" | awk -F "[,]" '{print $2}' | grep -q "." || echo "${localIP}" | awk -F "[,]" '{print $2}' | grep -q ":"; then
			echoContent red "\n ---> 检测到多个ip，请确认是否关闭cloudflare的云朵"
			echoContent yellow " ---> 关闭云朵后等待三分钟后重试"
			echoContent yellow " ---> 检测到的ip如下：[${localIP}]"
			exit 0
		fi
		echoContent green " ---> 当前域名ip为：[${localIP}]"
	fi

}
# 安装TLS
installTLS() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : 申请TLS证书\n"
	local tlsDomain=${domain}
	# 安装tls
	if [[ -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" && -f "/etc/v2ray-agent/tls/${tlsDomain}.key" && -n $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]] || [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
		echoContent green " ---> 检测到证书"
		#		checkTLStatus
		renewalTLS

		if [[ -z $(find /etc/v2ray-agent/tls/ -name "${tlsDomain}.crt") ]] || [[ -z $(find /etc/v2ray-agent/tls/ -name "${tlsDomain}.key") ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
			sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
		else
			echoContent yellow " ---> 如未过期请选择[n]\n"
			read -r -p "是否重新安装？[y/n]:" reInstallStatus
			if [[ "${reInstallStatus}" == "y" ]]; then
				rm -rf /etc/v2ray-agent/tls/*
				installTLS "$1"
			fi
		fi

	elif [[ -d "$HOME/.acme.sh" ]] && [[ ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" || ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" ]]; then
		echoContent green " ---> 安装TLS证书"
		if echo "${localIP}" | grep -q ":"; then
			sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 --server letsencrypt --listen-v6 | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
		else
			sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 --server letsencrypt | tee -a /etc/v2ray-agent/tls/acme.log >/dev/null
		fi

		if [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
			sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
		fi
		if [[ ! -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" || ! -f "/etc/v2ray-agent/tls/${tlsDomain}.key" ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.key") || -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
			tail -n 10 /etc/v2ray-agent/tls/acme.log
			if [[ ${installTLSCount} == "1" ]]; then
				echoContent red " ---> TLS安装失败，请检查acme日志"
				exit 0
			fi
			echoContent red " ---> TLS安装失败，正在检查80、443端口是否开放"
			allowPort
			echoContent yellow " ---> 重新尝试安装TLS证书"
			installTLSCount=1
			installTLS "$1"
		fi
		echoContent green " ---> TLS生成成功"
	else
		echoContent yellow " ---> 未安装acme.sh"
		exit 0
	fi
}
# 配置伪装博客
initNginxConfig() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : 配置Nginx"

	cat <<EOF >${nginxConfigPath}alone.conf
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
			customPath=$(head -n 50 /dev/urandom | sed 's/[^a-z]//g' | strings -n 4 | tr '[:upper:]' '[:lower:]' | head -1)
			currentPath=${customPath:0:4}
			customPath=${currentPath}
		else
			currentPath=${customPath}
		fi

	fi
	echoContent yellow "\n path：${currentPath}"
	echoContent skyBlue "\n----------------------------"
}
# Nginx伪装博客
nginxBlog() {
	echoContent skyBlue "\n进度 $1/${totalProgress} : 添加伪装站点"
	if [[ -d "/usr/share/nginx/html" && -f "/usr/share/nginx/html/check" ]]; then
		echo
		read -r -p "检测到安装伪装站点，是否需要重新安装[y/n]：" nginxBlogInstallStatus
		if [[ "${nginxBlogInstallStatus}" == "y" ]]; then
			rm -rf /usr/share/nginx/html
			randomNum=$((RANDOM % 6 + 1))
			wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip >/dev/null
			unzip -o /usr/share/nginx/html${randomNum}.zip -d /usr/share/nginx/html >/dev/null
			rm -f /usr/share/nginx/html${randomNum}.zip*
			echoContent green " ---> 添加伪装站点成功"
		fi
	else
		randomNum=$((RANDOM % 6 + 1))
		rm -rf /usr/share/nginx/html
		wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip >/dev/null
		unzip -o /usr/share/nginx/html${randomNum}.zip -d /usr/share/nginx/html >/dev/null
		rm -f /usr/share/nginx/html${randomNum}.zip*
		echoContent green " ---> 添加伪装站点成功"
	fi

}
# 操作Nginx
handleNginx() {

	if [[ -z $(pgrep -f "nginx") ]] && [[ "$1" == "start" ]]; then
		systemctl start nginx
		sleep 0.5

		if [[ -z $(pgrep -f nginx) ]]; then
			echoContent red " ---> Nginx启动失败"
			echoContent red " ---> 请手动尝试安装nginx后，再次执行脚本"
			exit 0
		fi
	elif [[ -n $(pgrep -f "nginx") ]] && [[ "$1" == "stop" ]]; then
		systemctl stop nginx
		sleep 0.5
		if [[ -n $(pgrep -f "nginx") ]]; then
			pgrep -f "nginx" | xargs kill -9
		fi
	fi
}

# 定时任务更新tls证书
installCronTLS() {
	echoContent skyBlue "\n进度 $1/${totalProgress} : 添加定时维护证书"
	crontab -l >/etc/v2ray-agent/backup_crontab.cron
	local historyCrontab
	historyCrontab=$(sed '/v2ray-agent/d;/acme.sh/d' /etc/v2ray-agent/backup_crontab.cron)
	echo "${historyCrontab}" >/etc/v2ray-agent/backup_crontab.cron
	echo "30 1 * * * /bin/bash /etc/v2ray-agent/install.sh RenewTLS >> /etc/v2ray-agent/crontab_tls.log 2>&1" >>/etc/v2ray-agent/backup_crontab.cron
	crontab /etc/v2ray-agent/backup_crontab.cron
	echoContent green "\n ---> 添加定时维护证书成功"
}

# 更新证书
renewalTLS() {
	if [[ -n $1 ]]; then
		echoContent skyBlue "\n进度  $1/1 : 更新证书"
	fi
	local domain=${currentHost}
	if [[ -z "${currentHost}" && -n "${tlsDomain}" ]]; then
		domain=${tlsDomain}
	fi

	if [[ -d "$HOME/.acme.sh/${domain}_ecc" ]] && [[ -f "$HOME/.acme.sh/${domain}_ecc/${domain}.key" ]] && [[ -f "$HOME/.acme.sh/${domain}_ecc/${domain}.cer" ]]; then
		modifyTime=$(stat "$HOME/.acme.sh/${domain}_ecc/${domain}.cer" | sed -n '7,6p' | awk '{print $2" "$3" "$4" "$5}')

		modifyTime=$(date +%s -d "${modifyTime}")
		currentTime=$(date +%s)
		((stampDiff = currentTime - modifyTime))
		((days = stampDiff / 86400))
		((remainingDays = 90 - days))

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
		((remainingDays = 90 - days))

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

			version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r .[].tag_name | head -1)
		else
			version=${v2rayCoreVersion}
		fi

		echoContent green " ---> v2ray-core版本:${version}"
		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip"
		else
			wget -c -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip" >/dev/null 2>&1
		fi

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

# 安装xray
installXray() {
	readInstallType
	echoContent skyBlue "\n进度  $1/${totalProgress} : 安装Xray"

	if [[ "${coreInstallType}" != "1" ]]; then

		version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r .[].tag_name | head -1)

		echoContent green " ---> Xray-core版本:${version}"
		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
		else
			wget -c -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip" >/dev/null 2>&1
		fi

		unzip -o "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" -d /etc/v2ray-agent/xray >/dev/null
		rm -rf "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip"
		chmod 655 /etc/v2ray-agent/xray/xray
	else
		echoContent green " ---> Xray-core版本:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"
		read -r -p "是否更新、升级？[y/n]:" reInstallXrayStatus
		if [[ "${reInstallXrayStatus}" == "y" ]]; then
			rm -f /etc/v2ray-agent/xray/xray
			installXray "$1"
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
	echoContent yellow "1.升级"
	echoContent yellow "2.回退"
	echoContent yellow "3.关闭v2ray-core"
	echoContent yellow "4.打开v2ray-core"
	echoContent yellow "5.重启v2ray-core"
	echoContent red "=============================================================="
	read -r -p "请选择:" selectV2RayType
	if [[ "${selectV2RayType}" == "1" ]]; then
		updateV2Ray
	elif [[ "${selectV2RayType}" == "2" ]]; then
		echoContent yellow "\n1.只可以回退最近的五个版本"
		echoContent yellow "2.不保证回退后一定可以正常使用"
		echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
		echoContent skyBlue "------------------------Version-------------------------------"
		curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r .[].tag_name | head -5 | awk '{print ""NR""":"$0}'

		echoContent skyBlue "--------------------------------------------------------------"
		read -r -p "请输入要回退的版本：" selectV2rayVersionType
		version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r .[].tag_name | head -5 | awk '{print ""NR""":"$0}' | grep "${selectV2rayVersionType}:" | awk -F "[:]" '{print $2}')
		if [[ -n "${version}" ]]; then
			updateV2Ray "${version}"
		else
			echoContent red "\n ---> 输入有误，请重新输入"
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

# xray版本管理
xrayVersionManageMenu() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : Xray版本管理"
	if [[ ! -d "/etc/v2ray-agent/xray/" ]]; then
		echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
		menu
		exit 0
	fi
	echoContent red "\n=============================================================="
	echoContent yellow "1.升级"
	echoContent yellow "2.回退"
	echoContent yellow "3.关闭Xray-core"
	echoContent yellow "4.打开Xray-core"
	echoContent yellow "5.重启Xray-core"
	echoContent red "=============================================================="
	read -r -p "请选择:" selectXrayType
	if [[ "${selectXrayType}" == "1" ]]; then
		updateXray
	elif [[ "${selectXrayType}" == "2" ]]; then
		echoContent yellow "\n1.由于Xray-core频繁更新，只可以回退最近的两个版本"
		echoContent yellow "2.不保证回退后一定可以正常使用"
		echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
		echoContent skyBlue "------------------------Version-------------------------------"
		curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r .[].tag_name | head -2 | awk '{print ""NR""":"$0}'
		echoContent skyBlue "--------------------------------------------------------------"
		read -r -p "请输入要回退的版本：" selectXrayVersionType
		version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r .[].tag_name | head -2 | awk '{print ""NR""":"$0}' | grep "${selectXrayVersionType}:" | awk -F "[:]" '{print $2}')
		if [[ -n "${version}" ]]; then
			updateXray "${version}"
		else
			echoContent red "\n ---> 输入有误，请重新输入"
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
# 更新V2Ray
updateV2Ray() {
	readInstallType
	if [[ -z "${coreInstallType}" ]]; then

		if [[ -n "$1" ]]; then
			version=$1
		else
			version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r .[0].tag_name)
		fi
		# 使用锁定的版本
		if [[ -n "${v2rayCoreVersion}" ]]; then
			version=${v2rayCoreVersion}
		fi
		echoContent green " ---> v2ray-core版本:${version}"

		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip"
		else
			wget -c -P "/etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/${v2rayCoreCPUVendor}.zip" >/dev/null 2>&1
		fi

		unzip -o "/etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip" -d /etc/v2ray-agent/v2ray >/dev/null
		rm -rf "/etc/v2ray-agent/v2ray/${v2rayCoreCPUVendor}.zip"
		handleV2Ray stop
		handleV2Ray start
	else
		echoContent green " ---> 当前v2ray-core版本:$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"

		if [[ -n "$1" ]]; then
			version=$1
		else
			version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases | jq -r .[0].tag_name)
		fi

		if [[ -n "${v2rayCoreVersion}" ]]; then
			version=${v2rayCoreVersion}
		fi
		if [[ -n "$1" ]]; then
			read -r -p "回退版本为${version}，是否继续？[y/n]:" rollbackV2RayStatus
			if [[ "${rollbackV2RayStatus}" == "y" ]]; then
				if [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
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
			read -r -p "最新版本为：${version}，是否更新？[y/n]：" installV2RayStatus
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
			version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r .[0].tag_name)
		fi

		echoContent green " ---> Xray-core版本:${version}"

		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
		else
			wget -c -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip" >/dev/null 2>&1
		fi

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
			version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | jq -r .[0].tag_name)
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
			read -r -p "最新版本为：${version}，是否更新？[y/n]：" installXrayStatus
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
	if [[ "${coreInstallType}" == "1" ]] && [[ -n $(pgrep -f xray/xray) ]]; then
		echoContent green " ---> 服务启动成功"
	elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]] && [[ -n $(pgrep -f v2ray/v2ray) ]]; then
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


[Install]
WantedBy=multi-user.target
EOF
		systemctl daemon-reload
		systemctl enable v2ray.service
		echoContent green " ---> 配置V2Ray开机自启成功"
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
			echoContent red "xray启动失败"
			echoContent red "请手动执行【/etc/v2ray-agent/xray/xray -confdir /etc/v2ray-agent/xray/conf】，查看错误日志"
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

	if [[ -n "${currentUUID}" && -z "${uuid}" ]]; then
		read -r -p "读取到上次安装记录，是否使用上次安装时的UUID ？[y/n]:" historyUUIDStatus
		if [[ "${historyUUIDStatus}" == "y" ]]; then
			uuid=${currentUUID}
		else
			uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
		fi
	elif [[ -z "${uuid}" ]]; then
		uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
	fi

	if [[ -z "${uuid}" ]]; then
		echoContent red "\n ---> uuid读取错误，重新生成"
		uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
	fi

	rm -rf /etc/v2ray-agent/v2ray/conf/*
	rm -rf /etc/v2ray-agent/v2ray/config_full.json

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

	# trojan_grpc
	if echo "${selectCustomInstallType}" | grep -q 2 || [[ "$1" == "all" ]]; then
		if ! echo "${selectCustomInstallType}" | grep -q 5 && [[ -n ${selectCustomInstallType} ]]; then
			fallbacksList=${fallbacksList//31302/31304}
		fi

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
        "email": "${domain}_VLESS_TLS-direct_TCP"
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

}

# 初始化Xray Trojan XTLS 配置文件
initXrayFrontingConfig() {
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
	echoContent yellow "如果前置是Trojan，查看帐号时则会出现两个Trojan协议的节点，有一个不可用xtls"
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

# 初始化Xray 配置文件
initXrayConfig() {
	echoContent skyBlue "\n进度 $2/${totalProgress} : 初始化Xray配置"
	echo
	local uuid=
	if [[ -n "${currentUUID}" ]]; then
		read -r -p "读取到上次安装记录，是否使用上次安装时的UUID ？[y/n]:" historyUUIDStatus
		if [[ "${historyUUIDStatus}" == "y" ]]; then
			uuid=${currentUUID}
			echoContent green "\n ---> 使用成功"
		else
			uuid=$(/etc/v2ray-agent/xray/xray uuid)
		fi
	fi

	if [[ -z "${uuid}" ]]; then
		echoContent yellow "请输入自定义UUID[需合法]，[回车]随机UUID"
		read -r -p 'UUID:' customUUID

		if [[ -n ${customUUID} ]]; then
			uuid=${customUUID}
		else
			uuid=$(/etc/v2ray-agent/xray/xray uuid)
		fi

	fi

	if [[ -z "${uuid}" ]]; then
		echoContent red "\n ---> uuid读取错误，重新生成"
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

# 初始化Trojan-Go配置
initTrojanGoConfig() {

	echoContent skyBlue "\n进度 $1/${totalProgress} : 初始化Trojan配置"
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

# 自定义CDN IP
customCDNIP() {
	echoContent skyBlue "\n进度 $1/${totalProgress} : 添加cloudflare自选CNAME"
	echoContent red "\n=============================================================="
	echoContent yellow "# 注意事项"
	echoContent yellow "\n教程地址:"
	echoContent skyBlue "https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md"
	echoContent red "\n如对Cloudflare优化不了解，请不要使用"
	echoContent yellow "\n 1.移动:104.16.123.96"
	echoContent yellow " 2.联通:www.cloudflare.com"
	echoContent yellow " 3.电信:www.digitalocean.com"
	echoContent skyBlue "----------------------------"
	read -r -p "请选择[回车不使用]:" selectCloudflareType
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
		echoContent yellow "\n ---> 不使用"
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

	local subAccount
	subAccount=${currentHost}_$(echo "${id}_currentHost" | md5sum | awk '{print $1}')

	if [[ "${type}" == "vlesstcp" ]]; then

		if [[ "${coreInstallType}" == "1" ]] && echo "${currentInstallProtocolType}" | grep -q 0; then
			echoContent yellow " ---> 通用格式(VLESS+TCP+TLS/xtls-rprx-direct)"
			echoContent green "    vless://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-direct#${email}\n"

			echoContent yellow " ---> 格式化明文(VLESS+TCP+TLS/xtls-rprx-direct)"
			echoContent green "协议类型：VLESS，地址：${host}，端口：${port}，用户ID：${id}，安全：xtls，传输方式：tcp，flow：xtls-rprx-direct，账户名:${email}\n"
			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-direct#${email}
EOF
			echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS/xtls-rprx-direct)"
			echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${host}%3A${port}%3Fencryption%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26sni%3D${host}%26flow%3Dxtls-rprx-direct%23${email}\n"

			echoContent skyBlue "----------------------------------------------------------------------------------"

			echoContent yellow " ---> 通用格式(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    vless://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-splice#${email/direct/splice}\n"

			echoContent yellow " ---> 格式化明文(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    协议类型：VLESS，地址：${host}，端口：${port}，用户ID：${id}，安全：xtls，传输方式：tcp，flow：xtls-rprx-splice，账户名:${email/direct/splice}\n"
			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-splice#${email/direct/splice}
EOF
			echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${host}%3A${port}%3Fencryption%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26sni%3D${host}%26flow%3Dxtls-rprx-splice%23${email/direct/splice}\n"

		elif [[ "${coreInstallType}" == 2 || "${coreInstallType}" == "3" ]]; then
			echoContent yellow " ---> 通用格式(VLESS+TCP+TLS)"
			echoContent green "    vless://${id}@${host}:${port}?security=tls&encryption=none&host=${host}&headerType=none&type=tcp#${email}\n"

			echoContent yellow " ---> 格式化明文(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    协议类型：VLESS，地址：${host}，端口：${port}，用户ID：${id}，安全：tls，传输方式：tcp，账户名:${email/direct/splice}\n"

			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${host}:${port}?security=tls&encryption=none&host=${host}&headerType=none&type=tcp#${email}
EOF
			echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS)"
			echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3a%2f%2f${id}%40${host}%3a${port}%3fsecurity%3dtls%26encryption%3dnone%26host%3d${host}%26headerType%3dnone%26type%3dtcp%23${email}\n"
		fi

	elif [[ "${type}" == "trojanTCPXTLS" ]]; then
		echoContent yellow " ---> 通用格式(Trojan+TCP+TLS/xtls-rprx-direct)"
		echoContent green "    trojan://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-direct#${email}\n"

		echoContent yellow " ---> 格式化明文(Trojan+TCP+TLS/xtls-rprx-direct)"
		echoContent green "协议类型：Trojan，地址：${host}，端口：${port}，用户ID：${id}，安全：xtls，传输方式：tcp，flow：xtls-rprx-direct，账户名:${email}\n"
		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-direct#${email}
EOF
		echoContent yellow " ---> 二维码 Trojan(Trojan+TCP+TLS/xtls-rprx-direct)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3A%2F%2F${id}%40${host}%3A${port}%3Fencryption%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26sni%3D${host}%26flow%3Dxtls-rprx-direct%23${email}\n"

		echoContent skyBlue "----------------------------------------------------------------------------------"

		echoContent yellow " ---> 通用格式(Trojan+TCP+TLS/xtls-rprx-splice)"
		echoContent green "    trojan://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-splice#${email/direct/splice}\n"

		echoContent yellow " ---> 格式化明文(Trojan+TCP+TLS/xtls-rprx-splice)"
		echoContent green "    协议类型：VLESS，地址：${host}，端口：${port}，用户ID：${id}，安全：xtls，传输方式：tcp，flow：xtls-rprx-splice，账户名:${email/direct/splice}\n"
		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&sni=${host}&flow=xtls-rprx-splice#${email/direct/splice}
EOF
		echoContent yellow " ---> 二维码 Trojan(Trojan+TCP+TLS/xtls-rprx-splice)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3A%2F%2F${id}%40${host}%3A${port}%3Fencryption%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26sni%3D${host}%26flow%3Dxtls-rprx-splice%23${email/direct/splice}\n"

	elif [[ "${type}" == "vmessws" ]]; then
		qrCodeBase64Default=$(echo -n "{\"port\":${port},\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${host}\",\"type\":\"none\",\"path\":\"/${path}\",\"net\":\"ws\",\"add\":\"${add}\",\"allowInsecure\":0,\"method\":\"none\",\"peer\":\"${host}\",\"sni\":\"${host}\"}" | base64 -w 0)
		qrCodeBase64Default="${qrCodeBase64Default// /}"

		echoContent yellow " ---> 通用json(VMess+WS+TLS)"
		echoContent green "    {\"port\":${port},\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${host}\",\"type\":\"none\",\"path\":\"${path}\",\"net\":\"ws\",\"add\":\"${add}\",\"allowInsecure\":0,\"method\":\"none\",\"peer\":\"${host}\",\"sni\":\"${host}\"}\n"
		echoContent yellow " ---> 通用vmess(VMess+WS+TLS)链接"
		echoContent green "    vmess://${qrCodeBase64Default}\n"
		echoContent yellow " ---> 二维码 vmess(VMess+WS+TLS)"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vmess://${qrCodeBase64Default}
EOF
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

	elif [[ "${type}" == "vmesstcp" ]]; then

		echoContent red "path:${path}"
		qrCodeBase64Default=$(echo -n "{\"add\":\"${add}\",\"aid\":0,\"host\":\"${host}\",\"id\":\"${id}\",\"net\":\"tcp\",\"path\":\"${path}\",\"port\":${port},\"ps\":\"${email}\",\"scy\":\"none\",\"sni\":\"${host}\",\"tls\":\"tls\",\"v\":2,\"type\":\"http\",\"allowInsecure\":0,\"peer\":\"${host}\",\"obfs\":\"http\",\"obfsParam\":\"${host}\"}" | base64)
		qrCodeBase64Default="${qrCodeBase64Default// /}"

		echoContent yellow " ---> 通用json(VMess+TCP+TLS)"
		echoContent green "    {\"port\":'${port}',\"ps\":\"${email}\",\"tls\":\"tls\",\"id\":\"${id}\",\"aid\":0,\"v\":2,\"host\":\"${host}\",\"type\":\"http\",\"path\":\"${path}\",\"net\":\"http\",\"add\":\"${add}\",\"allowInsecure\":0,\"method\":\"post\",\"peer\":\"${host}\",\"obfs\":\"http\",\"obfsParam\":\"${host}\"}\n"
		echoContent yellow " ---> 通用vmess(VMess+TCP+TLS)链接"
		echoContent green "    vmess://${qrCodeBase64Default}\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vmess://${qrCodeBase64Default}
EOF
		echoContent yellow " ---> 二维码 vmess(VMess+TCP+TLS)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

	elif [[ "${type}" == "vlessws" ]]; then

		echoContent yellow " ---> 通用格式(VLESS+WS+TLS)"
		echoContent green "    vless://${id}@${add}:${port}?encryption=none&security=tls&type=ws&host=${host}&sni=${host}&path=%2f${path}#${email}\n"

		echoContent yellow " ---> 格式化明文(VLESS+WS+TLS)"
		echoContent green "    协议类型：VLESS，地址：${add}，伪装域名/SNI：${host}，端口：${port}，用户ID：${id}，安全：tls，传输方式：ws，路径:/${path}，账户名:${email}\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${add}:${port}?encryption=none&security=tls&type=ws&host=${host}&sni=${host}&path=%2f${path}#${email}
EOF

		echoContent yellow " ---> 二维码 VLESS(VLESS+WS+TLS)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${port}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dws%26host%3D${host}%26sni%3D${host}%26path%3D%252f${path}%23${email}"

	elif [[ "${type}" == "vlessgrpc" ]]; then

		echoContent yellow " ---> 通用格式(VLESS+gRPC+TLS)"
		echoContent green "    vless://${id}@${add}:${port}?encryption=none&security=tls&type=grpc&host=${host}&path=${path}&serviceName=${path}&alpn=h2&sni=${host}#${email}\n"

		echoContent yellow " ---> 格式化明文(VLESS+gRPC+TLS)"
		echoContent green "    协议类型：VLESS，地址：${add}，伪装域名/SNI：${host}，端口：${port}，用户ID：${id}，安全：tls，传输方式：gRPC，alpn：h2，serviceName:${path}，账户名:${email}\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${id}@${add}:${port}?encryption=none&security=tls&type=grpc&host=${host}&path=${path}&serviceName=${path}&alpn=h2&sni=${host}#${email}
EOF
		echoContent yellow " ---> 二维码 VLESS(VLESS+gRPC+TLS)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${id}%40${add}%3A${port}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dgrpc%26host%3D${host}%26serviceName%3D${path}%26path%3D${path}%26sni%3D${host}%26alpn%3Dh2%23${email}"

	elif [[ "${type}" == "trojan" ]]; then
		# URLEncode
		echoContent yellow " ---> Trojan(TLS)"
		echoContent green "    trojan://${id}@${host}:${port}?peer=${host}&sni=${host}&alpn=http1.1#${host}_Trojan\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${host}:${port}?peer=${host}&sni=${host}&alpn=http1.1#${host}_Trojan
EOF
		echoContent yellow " ---> 二维码 Trojan(TLS)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${host}%3a${port}%3fpeer%3d${host}%26sni%3d${host}%26alpn%3Dhttp1.1%23${host}_Trojan\n"

	elif [[ "${type}" == "trojangrpc" ]]; then
		# URLEncode

		echoContent yellow " ---> Trojan gRPC(TLS)"
		echoContent green "    trojan://${id}@${host}:${port}?encryption=none&peer=${host}&security=tls&type=grpc&sni=${host}&alpn=h2&path=${path}&serviceName=${path}#${host}_Trojan_gRPC\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${host}:${port}?encryption=none&peer=${host}&security=tls&type=grpc&sni=${host}&alpn=h2&path=${path}&serviceName=${path}#${host}_Trojan_gRPC
EOF
		echoContent yellow " ---> 二维码 Trojan gRPC(TLS)"
		echoContent green "    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${host}%3a${port}%3Fencryption%3Dnone%26security%3Dtls%26peer%3d${host}%26type%3Dgrpc%26sni%3d${host}%26path%3D${path}%26alpn%3D=h2%26serviceName%3D${path}%23${host}_Trojan_gRPC\n"
	fi

}

# 账号
showAccounts() {
	readInstallType
	readInstallProtocolType
	readConfigHostPathUUID
	echoContent skyBlue "\n进度 $1/${totalProgress} : 账号"
	local show
	# VLESS TCP
	if [[ -n "${configPath}" ]]; then
		show=1
		if echo "${currentInstallProtocolType}" | grep -q trojan; then
			echoContent skyBlue "===================== Trojan TCP TLS/XTLS-direct/XTLS-splice ======================\n"
			jq .inbounds[0].settings.clients ${configPath}02_trojan_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
				echoContent skyBlue "\n ---> 帐号：$(echo "${user}" | jq -r .email)_$(echo "${user}" | jq -r .password)"
				echo
				defaultBase64Code trojanTCPXTLS "$(echo "${user}" | jq -r .email)" "$(echo "${user}" | jq -r .password)" "${currentHost}:${currentPort}" "${currentHost}"
			done

		else
			echoContent skyBlue "===================== VLESS TCP TLS/XTLS-direct/XTLS-splice ======================\n"
			jq .inbounds[0].settings.clients ${configPath}02_VLESS_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
				echoContent skyBlue "\n ---> 帐号：$(echo "${user}" | jq -r .email)_$(echo "${user}" | jq -r .id)"
				echo
				defaultBase64Code vlesstcp "$(echo "${user}" | jq -r .email)" "$(echo "${user}" | jq -r .id)" "${currentHost}:${currentPort}" "${currentHost}"
			done
		fi

		# VLESS WS
		if echo ${currentInstallProtocolType} | grep -q 1; then
			echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================\n"

			jq .inbounds[0].settings.clients ${configPath}03_VLESS_WS_inbounds.json | jq -c '.[]' | while read -r user; do
				echoContent skyBlue "\n ---> 帐号：$(echo "${user}" | jq -r .email)_$(echo "${user}" | jq -r .id)"
				echo
				local path="${currentPath}ws"
				#				if [[ ${coreInstallType} == "1" ]]; then
				#					echoContent yellow "Xray的0-RTT path后面会有，不兼容以v2ray为核心的客户端，请手动删除后使用\n"
				#					path="${currentPath}ws"
				#				fi
				defaultBase64Code vlessws "$(echo "${user}" | jq -r .email)" "$(echo "${user}" | jq -r .id)" "${currentHost}:${currentPort}" "${path}" "${currentAdd}"
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
				echoContent skyBlue "\n ---> 帐号：$(echo "${user}" | jq -r .email)_$(echo "${user}" | jq -r .id)"
				echo
				defaultBase64Code vmessws "$(echo "${user}" | jq -r .email)" "$(echo "${user}" | jq -r .id)" "${currentHost}:${currentPort}" "${path}" "${currentAdd}"
			done
		fi

		# VLESS grpc
		if echo ${currentInstallProtocolType} | grep -q 5; then
			echoContent skyBlue "\n=============================== VLESS gRPC TLS CDN ===============================\n"
			echoContent red "\n --->gRPC处于测试阶段，可能对你使用的客户端不兼容，如不能使用请忽略"
			local serviceName
			serviceName=$(jq -r .inbounds[0].streamSettings.grpcSettings.serviceName ${configPath}06_VLESS_gRPC_inbounds.json)
			jq .inbounds[0].settings.clients ${configPath}06_VLESS_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do
				echoContent skyBlue "\n ---> 帐号：$(echo "${user}" | jq -r .email)_$(echo "${user}" | jq -r .id)"
				echo
				defaultBase64Code vlessgrpc "$(echo "${user}" | jq -r .email)" "$(echo "${user}" | jq -r .id)" "${currentHost}:${currentPort}" "${serviceName}" "${currentAdd}"
			done
		fi
	fi

	# trojan tcp
	if echo ${currentInstallProtocolType} | grep -q 4; then
		echoContent skyBlue "\n==================================  Trojan TLS  ==================================\n"
		jq .inbounds[0].settings.clients ${configPath}04_trojan_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
			echoContent skyBlue "\n ---> 帐号：$(echo "${user}" | jq -r .email)_$(echo "${user}" | jq -r .password)"
			echo
			defaultBase64Code trojan trojan "$(echo "${user}" | jq -r .password)" "${currentHost}"
		done
	fi

	if echo ${currentInstallProtocolType} | grep -q 2; then
		echoContent skyBlue "\n================================  Trojan gRPC TLS  ================================\n"
		echoContent red "\n --->gRPC处于测试阶段，可能对你使用的客户端不兼容，如不能使用请忽略"
		local serviceName=
		serviceName=$(jq -r .inbounds[0].streamSettings.grpcSettings.serviceName ${configPath}04_trojan_gRPC_inbounds.json)
		jq .inbounds[0].settings.clients ${configPath}04_trojan_gRPC_inbounds.json | jq -c '.[]' | while read -r user; do
			echoContent skyBlue "\n ---> 帐号：$(echo "${user}" | jq -r .email)_$(echo "${user}" | jq -r .password)"
			echo
			defaultBase64Code trojangrpc "$(echo "${user}" | jq -r .email)" "$(echo "${user}" | jq -r .password)" "${currentHost}:${currentPort}" "${serviceName}" "${currentAdd}"
		done
	fi

	if [[ -z ${show} ]]; then
		echoContent red " ---> 未安装"
	fi
}

# 更新伪装站
updateNginxBlog() {
	echoContent skyBlue "\n进度 $1/${totalProgress} : 更换伪装站点"
	echoContent red "=============================================================="
	echoContent yellow "# 如需自定义，请手动复制模版文件到 /usr/share/nginx/html \n"
	echoContent yellow "1.新手引导"
	echoContent yellow "2.游戏网站"
	echoContent yellow "3.个人博客01"
	echoContent yellow "4.企业站"
	echoContent yellow "5.解锁加密的音乐文件模版[https://github.com/ix64/unlock-music]"
	echoContent yellow "6.mikutap[https://github.com/HFIProgramming/mikutap]"
	echoContent yellow "7.企业站02"
	echoContent yellow "8.个人博客02"
	echoContent yellow "9.404自动跳转baidu"
	echoContent red "=============================================================="
	read -r -p "请选择:" selectInstallNginxBlogType

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
		echoContent green " ---> 更换伪站成功"
	else
		echoContent red " ---> 选择错误，请重新选择"
		updateNginxBlog
	fi
}

# 添加新端口
addCorePort() {
	echoContent skyBlue "\n功能 1/${totalProgress} : 添加新端口"
	echoContent red "\n=============================================================="
	echoContent yellow "# 注意事项\n"
	echoContent yellow "支持批量添加"
	echoContent yellow "不影响443端口的使用"
	echoContent yellow "查看帐号时，只会展示默认端口443的帐号"
	echoContent yellow "不允许有特殊字符，注意逗号的格式"
	echoContent yellow "录入示例:2053,2083,2087\n"

	echoContent yellow "1.添加端口"
	echoContent yellow "2.删除端口"
	echoContent red "=============================================================="
	read -r -p "请选择:" selectNewPortType
	if [[ "${selectNewPortType}" == "1" ]]; then
		read -r -p "请输入端口号：" newPort
		if [[ -n "${newPort}" ]]; then

			while read -r port; do
				cat <<EOF >"${configPath}02_dokodemodoor_inbounds_${port}.json"
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

			echoContent green " ---> 添加成功"
			reloadCore
		fi
	elif [[ "${selectNewPortType}" == "2" ]]; then

		find ${configPath} -name "*dokodemodoor*" | awk -F "[c][o][n][f][/]" '{print ""NR""":"$2}'
		read -r -p "请输入要删除的端口编号：" portIndex
		local dokoConfig
		dokoConfig=$(find ${configPath} -name "*dokodemodoor*" | awk -F "[c][o][n][f][/]" '{print ""NR""":"$2}' | grep "${portIndex}:")
		if [[ -n "${dokoConfig}" ]]; then
			rm "${configPath}/$(echo "${dokoConfig}" | awk -F "[:]" '{print $2}')"
			reloadCore
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

	handleNginx stop
	if [[ -z $(pgrep -f "nginx") ]]; then
		echoContent green " ---> 停止Nginx成功"
	fi

	handleV2Ray stop
	#	handleTrojanGo stop

	if [[ -f "/root/.acme.sh/acme.sh.env" ]] && grep -q 'acme.sh.env' </root/.bashrc; then
		sed -i 's/. "\/root\/.acme.sh\/acme.sh.env"//g' "$(grep '. "/root/.acme.sh/acme.sh.env"' -rl /root/.bashrc)"
	fi
	rm -rf /root/.acme.sh
	echoContent green " ---> 删除acme.sh完成"
	rm -rf /etc/systemd/system/v2ray.service
	echoContent green " ---> 删除V2Ray开机自启完成"

	rm -rf /tmp/v2ray-agent-tls/*
	if [[ -d "/etc/v2ray-agent/tls" ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.key") ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.crt") ]]; then
		mv /etc/v2ray-agent/tls /tmp/v2ray-agent-tls
		if [[ -n $(find /tmp/v2ray-agent-tls -name '*.key') ]]; then
			echoContent yellow " ---> 备份证书成功，请注意留存。[/tmp/v2ray-agent-tls]"
		fi
	fi

	rm -rf /etc/v2ray-agent
	rm -rf ${nginxConfigPath}alone.conf
	rm -rf /usr/bin/vasma
	rm -rf /usr/sbin/vasma
	echoContent green " ---> 卸载快捷方式完成"
	echoContent green " ---> 卸载v2ray-agent脚本完成"
}

# 修改V2Ray CDN节点
updateV2RayCDN() {

	# todo 重构此方法
	echoContent skyBlue "\n进度 $1/${totalProgress} : 修改CDN节点"

	if [[ -n "${currentAdd}" ]]; then
		echoContent red "=============================================================="
		echoContent yellow "1.CNAME www.digitalocean.com"
		echoContent yellow "2.CNAME www.cloudflare.com"
		echoContent yellow "3.CNAME hostmonit.com"
		echoContent yellow "4.手动输入"
		echoContent red "=============================================================="
		read -r -p "请选择:" selectCDNType
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
			read -r -p "请输入想要自定义CDN IP或者域名:" setDomain
			;;
		esac

		if [[ -n ${setDomain} ]]; then
			if [[ -n "${currentAdd}" ]]; then
				sed -i "s/\"${currentAdd}\"/\"${setDomain}\"/g" "$(grep "${currentAdd}" -rl ${configPath}${frontingType}.json)"
			fi
			if [[ $(jq -r .inbounds[0].settings.clients[0].add ${configPath}${frontingType}.json) == "${setDomain}" ]]; then
				echoContent green " ---> CDN修改成功"
				reloadCore
			else
				echoContent red " ---> 修改CDN失败"
			fi
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
	read -r -p "是否自定义UUID ？[y/n]:" customUUIDStatus
	echo
	if [[ "${customUUIDStatus}" == "y" ]]; then
		read -r -p "请输入合法的UUID:" currentCustomUUID
		echo
		if [[ -z "${currentCustomUUID}" ]]; then
			echoContent red " ---> UUID不可为空"
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
	fi
}

# 自定义email
customUserEmail() {
	read -r -p "是否自定义email ？[y/n]:" customEmailStatus
	echo
	if [[ "${customEmailStatus}" == "y" ]]; then
		read -r -p "请输入合法的email:" currentCustomEmail
		echo
		if [[ -z "${currentCustomEmail}" ]]; then
			echoContent red " ---> email不可为空"
		else
			jq -r -c '.inbounds[0].settings.clients[].email' ${configPath}${frontingType}.json | while read -r line; do
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
	fi
}

# 添加用户
addUser() {

	echoContent yellow "添加新用户后，需要重新查看订阅"
	read -r -p "请输入要添加的用户数量：" userNum
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
			email=${currentCustomEmail}
		else
			email=${currentHost}_${uuid}
		fi

		#	兼容v2ray-core
		users="{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-direct\",\"email\":\"${email}\",\"alterId\":0}"

		if [[ "${coreInstallType}" == "2" ]]; then
			users="{\"id\":\"${uuid}\",\"email\":\"${email}\",\"alterId\":0}"
		fi

		if echo ${currentInstallProtocolType} | grep -q 0; then
			local vlessUsers="${users//\,\"alterId\":0/}"

			local vlessTcpResult
			vlessTcpResult=$(jq -r ".inbounds[0].settings.clients += [${vlessUsers}]" ${configPath}${frontingType}.json)
			echo "${vlessTcpResult}" | jq . >${configPath}${frontingType}.json
		fi

		if echo ${currentInstallProtocolType} | grep -q trojan; then
			local trojanXTLSUsers="${users//\,\"alterId\":0/}"
			trojanXTLSUsers=${trojanXTLSUsers//"id"/"password"}

			local trojanXTLSResult
			trojanXTLSResult=$(jq -r ".inbounds[0].settings.clients += [${trojanXTLSUsers}]" ${configPath}${frontingType}.json)
			echo "${trojanXTLSResult}" | jq . >${configPath}${frontingType}.json
		fi

		if echo ${currentInstallProtocolType} | grep -q 1; then
			local vlessUsers="${users//\,\"alterId\":0/}"
			vlessUsers="${vlessUsers//\"flow\":\"xtls-rprx-direct\"\,/}"
			local vlessWsResult
			vlessWsResult=$(jq -r ".inbounds[0].settings.clients += [${vlessUsers}]" ${configPath}03_VLESS_WS_inbounds.json)
			echo "${vlessWsResult}" | jq . >${configPath}03_VLESS_WS_inbounds.json
		fi

		if echo ${currentInstallProtocolType} | grep -q 2; then
			local trojangRPCUsers="${users//\"flow\":\"xtls-rprx-direct\"\,/}"
			trojangRPCUsers="${trojangRPCUsers//\,\"alterId\":0/}"
			trojangRPCUsers=${trojangRPCUsers//"id"/"password"}

			local trojangRPCResult
			trojangRPCResult=$(jq -r ".inbounds[0].settings.clients += [${trojangRPCUsers}]" ${configPath}04_trojan_gRPC_inbounds.json)
			echo "${trojangRPCResult}" | jq . >${configPath}04_trojan_gRPC_inbounds.json
		fi

		if echo ${currentInstallProtocolType} | grep -q 3; then
			local vmessUsers="${users//\"flow\":\"xtls-rprx-direct\"\,/}"

			local vmessWsResult
			vmessWsResult=$(jq -r ".inbounds[0].settings.clients += [${vmessUsers}]" ${configPath}05_VMess_WS_inbounds.json)
			echo "${vmessWsResult}" | jq . >${configPath}05_VMess_WS_inbounds.json
		fi

		if echo ${currentInstallProtocolType} | grep -q 5; then
			local vlessGRPCUsers="${users//\"flow\":\"xtls-rprx-direct\"\,/}"
			vlessGRPCUsers="${vlessGRPCUsers//\,\"alterId\":0/}"

			local vlessGRPCResult
			vlessGRPCResult=$(jq -r ".inbounds[0].settings.clients += [${vlessGRPCUsers}]" ${configPath}06_VLESS_gRPC_inbounds.json)
			echo "${vlessGRPCResult}" | jq . >${configPath}06_VLESS_gRPC_inbounds.json
		fi

		if echo ${currentInstallProtocolType} | grep -q 4; then
			local trojanUsers="${users//\"flow\":\"xtls-rprx-direct\"\,/}"
			trojanUsers="${trojanUsers//id/password}"
			trojanUsers="${trojanUsers//\,\"alterId\":0/}"

			local trojanTCPResult
			trojanTCPResult=$(jq -r ".inbounds[0].settings.clients += [${trojanUsers}]" ${configPath}04_trojan_TCP_inbounds.json)
			echo "${trojanTCPResult}" | jq . >${configPath}04_trojan_TCP_inbounds.json
		fi
	done

	reloadCore
	echoContent green " ---> 添加完成"
	manageAccount 1
}

# 移除用户
removeUser() {

	if echo ${currentInstallProtocolType} | grep -q 0 || echo ${currentInstallProtocolType} | grep -q trojan; then
		jq -r -c .inbounds[0].settings.clients[].email ${configPath}${frontingType}.json | awk '{print NR""":"$0}'
		read -r -p "请选择要删除的用户编号[仅支持单个删除]:" delUserIndex
		if [[ $(jq -r '.inbounds[0].settings.clients|length' ${configPath}${frontingType}.json) -lt ${delUserIndex} ]]; then
			echoContent red " ---> 选择错误"
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
	manageAccount 1
}
# 更新脚本
updateV2RayAgent() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : 更新v2ray-agent脚本"
	rm -rf /etc/v2ray-agent/install.sh
	if wget --help | grep -q show-progress; then
		wget -c -q --show-progress -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
	else
		wget -c -q -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
	fi

	sudo chmod 700 /etc/v2ray-agent/install.sh
	local version
	version=$(grep '当前版本：v' "/etc/v2ray-agent/install.sh" | awk -F "[v]" '{print $2}' | tail -n +2 | head -n 1 | awk -F "[\"]" '{print $1}')

	echoContent green "\n ---> 更新完毕"
	echoContent yellow " ---> 请手动执行[vasma]打开脚本"
	echoContent green " ---> 当前版本:${version}\n"
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
	if [[ -z ${configPath} ]]; then
		echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
	fi
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

# 脚本快捷方式
aliasInstall() {

	if [[ -f "$HOME/install.sh" ]] && [[ -d "/etc/v2ray-agent" ]] && grep <"$HOME/install.sh" -q "作者：mack-a"; then
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
	# pingIPv6=$(ping6 -c 1 www.google.com | sed '2{s/[^(]*(//;s/).*//;q;}' | tail -n +2)
	pingIPv6=$(ping6 -c 1 www.google.com | sed -n '1p' | sed 's/.*(//g;s/).*//g')

	if [[ -z "${pingIPv6}" ]]; then
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
	echoContent yellow "1.添加域名"
	echoContent yellow "2.卸载IPv6分流"
	echoContent red "=============================================================="
	read -r -p "请选择:" ipv6Status
	if [[ "${ipv6Status}" == "1" ]]; then
		echoContent red "=============================================================="
		echoContent yellow "# 注意事项\n"
		echoContent yellow "1.规则仅支持预定义域名列表[https://github.com/v2fly/domain-list-community]"
		echoContent yellow "2.详细文档[https://www.v2fly.org/config/routing.html]"
		echoContent yellow "3.如内核启动失败请检查域名后重新添加域名"
		echoContent yellow "4.不允许有特殊字符，注意逗号的格式"
		echoContent yellow "5.每次添加都是重新添加，不会保留上次域名"
		echoContent yellow "6.录入示例:google,youtube,facebook\n"
		read -r -p "请按照上面示例录入域名:" domainList

		if [[ -f "${configPath}09_routing.json" ]]; then

			unInstallRouting IPv6-out

			routing=$(jq -r ".routing.rules += [{\"type\":\"field\",\"domain\":[\"geosite:${domainList//,/\",\"geosite:}\"],\"outboundTag\":\"IPv6-out\"}]" ${configPath}09_routing.json)

			echo "${routing}" | jq . >${configPath}09_routing.json

		else
			cat <<EOF >"${configPath}09_routing.json"
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

		echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

		echoContent green " ---> 添加成功"

	elif [[ "${ipv6Status}" == "2" ]]; then

		unInstallRouting IPv6-out

		unInstallOutbounds IPv6-out

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
		echoContent yellow "当前状态：已禁用"
	else
		echoContent yellow "当前状态：未禁用"
	fi

	echoContent yellow "1.禁用"
	echoContent yellow "2.打开"
	echoContent red "=============================================================="
	read -r -p "请选择:" btStatus
	if [[ "${btStatus}" == "1" ]]; then

		if [[ -f "${configPath}09_routing.json" ]]; then

			unInstallRouting blackhole-out

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

		unInstallRouting blackhole-out outboundTag

		unInstallOutbounds blackhole-out

		echoContent green " ---> BT下载打开成功"
	else
		echoContent red " ---> 选择错误"
		exit 0
	fi

	reloadCore
}

# 根据tag卸载Routing
unInstallRouting() {
	local tag=$1
	local type=$2

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

				if [[ ${delStatus} == 1 ]]; then
					routing=$(jq -r 'del(.routing.rules['"$(("${index}" - 1))"'])' ${configPath}09_routing.json)
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
			routing=$(jq -r 'del(.outbounds['$(("${ipv6OutIndex}" - 1))'])' ${configPath}10_ipv4_outbounds.json)
			echo "${routing}" | jq . >${configPath}10_ipv4_outbounds.json
		fi
	fi

}

# 卸载嗅探
unInstallSniffing() {

	find ${configPath} -name "*inbounds.json*" | awk -F "[c][o][n][f][/]" '{print $2}' | while read -r inbound; do
		sniffing=$(jq -r 'del(.inbounds[0].sniffing)' "${configPath}${inbound}")
		echo "${sniffing}" | jq . >"${configPath}${inbound}"
	done
}

# 安装嗅探
installSniffing() {

	find ${configPath} -name "*inbounds.json*" | awk -F "[c][o][n][f][/]" '{print $2}' | while read -r inbound; do
		sniffing=$(jq -r '.inbounds[0].sniffing = {"enabled":true,"destOverride":["http","tls"]}' "${configPath}${inbound}")
		echo "${sniffing}" | jq . >"${configPath}${inbound}"
	done
}

# warp分流
warpRouting() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : WARP分流"
	echoContent red "=============================================================="
	echoContent yellow "# 注意事项\n"
	echoContent yellow "1.官方warp经过几轮测试有bug，重启会导致warp失效，并且无法启动，也有可能CPU使用率暴涨"
	echoContent yellow "2.不重启机器可正常使用，如果非要使用官方warp，建议不重启机器"
	echoContent yellow "3.有的机器重启后仍正常使用"
	echoContent yellow "4.重启后无法使用，也可卸载重新安装"
	# 安装warp
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
	echoContent yellow "1.添加域名"
	echoContent yellow "2.卸载WARP分流"
	echoContent red "=============================================================="
	read -r -p "请选择:" warpStatus
	if [[ "${warpStatus}" == "1" ]]; then
		echoContent red "=============================================================="
		echoContent yellow "# 注意事项\n"
		echoContent yellow "1.规则仅支持预定义域名列表[https://github.com/v2fly/domain-list-community]"
		echoContent yellow "2.详细文档[https://www.v2fly.org/config/routing.html]"
		echoContent yellow "3.只可以把流量分流给warp，不可指定是ipv4或者ipv6"
		echoContent yellow "4.如内核启动失败请检查域名后重新添加域名"
		echoContent yellow "5.不允许有特殊字符，注意逗号的格式"
		echoContent yellow "6.每次添加都是重新添加，不会保留上次域名"
		echoContent yellow "7.录入示例:google,youtube,facebook\n"
		read -r -p "请按照上面示例录入域名:" domainList

		if [[ -f "${configPath}09_routing.json" ]]; then
			unInstallRouting warp-socks-out outboundTag

			routing=$(jq -r ".routing.rules += [{\"type\":\"field\",\"domain\":[\"geosite:${domainList//,/\",\"geosite:}\"],\"outboundTag\":\"warp-socks-out\"}]" ${configPath}09_routing.json)

			echo "${routing}" | jq . >${configPath}09_routing.json

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

		local outbounds
		outbounds=$(jq -r '.outbounds += [{"protocol":"socks","settings":{"servers":[{"address":"127.0.0.1","port":31303}]},"tag":"warp-socks-out"}]' ${configPath}10_ipv4_outbounds.json)

		echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

		echoContent green " ---> 添加成功"

	elif [[ "${warpStatus}" == "2" ]]; then

		${removeType} cloudflare-warp >/dev/null 2>&1

		unInstallRouting warp-socks-out outboundTag

		unInstallOutbounds warp-socks-out

		echoContent green " ---> WARP分流卸载成功"
	else
		echoContent red " ---> 选择错误"
		exit 0
	fi
	reloadCore
}
# 流媒体工具箱
streamingToolbox() {
	echoContent skyBlue "\n功能 1/${totalProgress} : 流媒体工具箱"
	echoContent red "\n=============================================================="
	#	echoContent yellow "1.Netflix检测"
	echoContent yellow "1.任意门落地机解锁流媒体"
	echoContent yellow "2.DNS解锁流媒体"
	read -r -p "请选择:" selectType

	case ${selectType} in
	1)
		dokodemoDoorUnblockStreamingMedia
		;;
	2)
		dnsUnlockNetflix
		;;
	esac

}

# 任意门解锁流媒体
dokodemoDoorUnblockStreamingMedia() {
	echoContent skyBlue "\n功能 1/${totalProgress} : 任意门落地机解锁流媒体"
	echoContent red "\n=============================================================="
	echoContent yellow "# 注意事项"
	echoContent yellow "任意门解锁详解，请查看此文章[https://github.com/mack-a/v2ray-agent/blob/master/documents/netflix/dokodemo-unblock_netflix.md]\n"

	echoContent yellow "1.添加出站"
	echoContent yellow "2.添加入站"
	echoContent yellow "3.卸载"
	read -r -p "请选择:" selectType

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

# 设置任意门解锁Netflix【出站】
setDokodemoDoorUnblockStreamingMediaOutbounds() {
	read -r -p "请输入解锁流媒体 vps的IP:" setIP
	echoContent red "=============================================================="
	echoContent yellow "# 注意事项\n"
	echoContent yellow "1.规则仅支持预定义域名列表[https://github.com/v2fly/domain-list-community]"
	echoContent yellow "2.详细文档[https://www.v2fly.org/config/routing.html]"
	echoContent yellow "3.如内核启动失败请检查域名后重新添加域名"
	echoContent yellow "4.不允许有特殊字符，注意逗号的格式"
	echoContent yellow "5.每次添加都是重新添加，不会保留上次域名"
	echoContent yellow "6.录入示例:netflix,disney,hulu\n"
	read -r -p "请按照上面示例录入域名:" domainList

	if [[ -n "${setIP}" ]]; then

		unInstallOutbounds streamingMedia-80
		unInstallOutbounds streamingMedia-443

		outbounds=$(jq -r ".outbounds += [{\"tag\":\"streamingMedia-80\",\"protocol\":\"freedom\",\"settings\":{\"domainStrategy\":\"AsIs\",\"redirect\":\"${setIP}:22387\"}},{\"tag\":\"streamingMedia-443\",\"protocol\":\"freedom\",\"settings\":{\"domainStrategy\":\"AsIs\",\"redirect\":\"${setIP}:22388\"}}]" ${configPath}10_ipv4_outbounds.json)

		echo "${outbounds}" | jq . >${configPath}10_ipv4_outbounds.json

		if [[ -f "${configPath}09_routing.json" ]]; then
			unInstallRouting streamingMedia-80 outboundTag
			unInstallRouting streamingMedia-443 outboundTag

			local routing

			routing=$(jq -r ".routing.rules += [{\"type\":\"field\",\"port\":80,\"domain\":[\"ip.sb\",\"geosite:${domainList//,/\",\"geosite:}\"],\"outboundTag\":\"streamingMedia-80\"},{\"type\":\"field\",\"port\":443,\"domain\":[\"ip.sb\",\"geosite:${domainList//,/\",\"geosite:}\"],\"outboundTag\":\"streamingMedia-443\"}]" ${configPath}09_routing.json)

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
		echoContent green " ---> 添加出站解锁成功"
		exit 0
	fi
	echoContent red " ---> ip不可为空"
}

# 设置任意门解锁Netflix【入站】
setDokodemoDoorUnblockStreamingMediaInbounds() {

	echoContent skyBlue "\n功能 1/${totalProgress} : 任意门添加入站"
	echoContent red "\n=============================================================="
	echoContent yellow "# 注意事项\n"
	echoContent yellow "1.规则仅支持预定义域名列表[https://github.com/v2fly/domain-list-community]"
	echoContent yellow "2.详细文档[https://www.v2fly.org/config/routing.html]"
	echoContent yellow "3.如内核启动失败请检查域名后重新添加域名"
	echoContent yellow "4.不允许有特殊字符，注意逗号的格式"
	echoContent yellow "5.每次添加都是重新添加，不会保留上次域名"
	echoContent yellow "6.ip录入示例:1.1.1.1,1.1.1.2"
	echoContent yellow "7.下面的域名一定要和出站的vps一致"
	echoContent yellow "8.域名录入示例:netflix,disney,hulu\n"
	read -r -p "请输入允许访问该解锁 vps的IP:" setIPs
	if [[ -n "${setIPs}" ]]; then
		read -r -p "请按照上面示例录入域名:" domainList

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

		if [[ -f "${configPath}09_routing.json" ]]; then
			unInstallRouting streamingMedia-80 inboundTag
			unInstallRouting streamingMedia-443 inboundTag

			local routing
			routing=$(jq -r ".routing.rules += [{\"source\":[\"${setIPs//,/\",\"}\"],\"type\":\"field\",\"inboundTag\":[\"streamingMedia-80\",\"streamingMedia-443\"],\"outboundTag\":\"direct\"},{\"domains\":[\"geosite:${domainList//,/\",\"geosite:}\"],\"type\":\"field\",\"inboundTag\":[\"streamingMedia-80\",\"streamingMedia-443\"],\"outboundTag\":\"blackhole-out\"}]" ${configPath}09_routing.json)
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
		echoContent green " ---> 添加落地机入站解锁成功"
		exit 0
	fi
	echoContent red " ---> ip不可为空"
}

# 移除任意门解锁Netflix
removeDokodemoDoorUnblockStreamingMedia() {

	unInstallOutbounds streamingMedia-80
	unInstallOutbounds streamingMedia-443

	unInstallRouting streamingMedia-80 inboundTag
	unInstallRouting streamingMedia-443 inboundTag

	unInstallRouting streamingMedia-80 outboundTag
	unInstallRouting streamingMedia-443 outboundTag

	rm -rf ${configPath}01_netflix_inbounds.json

	reloadCore
	echoContent green " ---> 卸载成功"
}

# 重启核心
reloadCore() {
	if [[ "${coreInstallType}" == "1" ]]; then
		handleXray stop
		handleXray start
	elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
		handleV2Ray stop
		handleV2Ray start
	fi
}

# dns解锁Netflix
dnsUnlockNetflix() {
	if [[ -z "${configPath}" ]]; then
		echoContent red " ---> 未安装，请使用脚本安装"
		menu
		exit 0
	fi
	echoContent skyBlue "\n功能 1/${totalProgress} : DNS解锁流媒体"
	echoContent red "\n=============================================================="
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

# 设置dns
setUnlockDNS() {
	read -r -p "请输入解锁流媒体DNS:" setDNS
	if [[ -n ${setDNS} ]]; then
		echoContent red "=============================================================="
		echoContent yellow "# 注意事项\n"
		echoContent yellow "1.规则仅支持预定义域名列表[https://github.com/v2fly/domain-list-community]"
		echoContent yellow "2.详细文档[https://www.v2fly.org/config/routing.html]"
		echoContent yellow "3.如内核启动失败请检查域名后重新添加域名"
		echoContent yellow "4.不允许有特殊字符，注意逗号的格式"
		echoContent yellow "5.每次添加都是重新添加，不会保留上次域名"
		echoContent yellow "6.录入示例:netflix,disney,hulu"
		echoContent yellow "7.默认方案请输入1，默认方案包括以下内容"
		echoContent yellow "netflix,bahamut,hulu,hbo,disney,bbc,4chan,fox,abema,dmm,niconico,pixiv,bilibili,viu"
		read -r -p "请按照上面示例录入域名:" domainList
		if [[ "${domainList}" = "1" ]]; then
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

# 移除Netflix解锁
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

# v2ray-core个性化安装
customV2RayInstall() {
	echoContent skyBlue "\n========================个性化安装============================"
	echoContent yellow "VLESS前置，默认安装0，如果只需要安装0，则只选择0即可"
	echoContent yellow "0.VLESS+TLS/XTLS+TCP"
	echoContent yellow "1.VLESS+TLS+WS[CDN]"
	echoContent yellow "2.Trojan+TLS+gRPC[CDN]"
	echoContent yellow "3.VMess+TLS+WS[CDN]"
	echoContent yellow "4.Trojan"
	echoContent yellow "5.VLESS+TLS+gRPC[CDN]"
	read -r -p "请选择[多选]，[例如:123]:" selectCustomInstallType
	echoContent skyBlue "--------------------------------------------------------------"
	if [[ -z ${selectCustomInstallType} ]]; then
		selectCustomInstallType=0
	fi
	if [[ "${selectCustomInstallType}" =~ ^[0-5]+$ ]]; then
		cleanUp xrayClean
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
	echoContent yellow "0.VLESS+TLS/XTLS+TCP"
	echoContent yellow "1.VLESS+TLS+WS[CDN]"
	echoContent yellow "2.Trojan+TLS+gRPC[CDN]"
	echoContent yellow "3.VMess+TLS+WS[CDN]"
	echoContent yellow "4.Trojan"
	echoContent yellow "5.VLESS+TLS+gRPC[CDN]"
	read -r -p "请选择[多选]，[例如:123]:" selectCustomInstallType
	echoContent skyBlue "--------------------------------------------------------------"
	if [[ -z ${selectCustomInstallType} ]]; then
		echoContent red " ---> 不可为空"
		customXrayInstall
	elif [[ "${selectCustomInstallType}" =~ ^[0-5]+$ ]]; then
		cleanUp v2rayClean
		totalProgress=17
		installTools 1
		# 申请tls
		initTLSNginxConfig 2
		installTLS 3
		handleNginx stop
		# 随机path
		if echo "${selectCustomInstallType}" | grep -q 1 || echo "${selectCustomInstallType}" | grep -q 2 || echo "${selectCustomInstallType}" | grep -q 3 || echo "${selectCustomInstallType}" | grep -q 5; then
			randomPathFunction 5
			customCDNIP 6
		fi
		nginxBlog 7
		updateRedirectNginxConf
		handleNginx start

		# 安装V2Ray
		installXray 8
		installXrayService 9
		initXrayConfig custom 10
		cleanUp v2rayDel

		installCronTLS 14
		handleXray stop
		handleXray start
		# 生成账号
		checkGFWStatue 15
		showAccounts 16
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
	selectCustomInstallType=
	totalProgress=13
	installTools 2
	# 申请tls
	initTLSNginxConfig 3
	installTLS 4
	handleNginx stop
	#	initNginxConfig 5
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
	selectCustomInstallType=
	totalProgress=13
	installTools 2
	# 申请tls
	initTLSNginxConfig 3
	installTLS 4
	handleNginx stop
	randomPathFunction 5
	# 安装Xray
	# handleV2Ray stop
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
	# 生成账号
	checkGFWStatue 12
	showAccounts 13
}

# 核心管理
coreVersionManageMenu() {

	if [[ -z "${coreInstallType}" ]]; then
		echoContent red "\n ---> 没有检测到安装目录，请执行脚本安装内容"
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
# 定时任务检查证书
cronRenewTLS() {
	if [[ "${renewTLS}" == "RenewTLS" ]]; then
		renewalTLS
		exit 0
	fi
}
# 账号管理
manageAccount() {
	echoContent skyBlue "\n功能 1/${totalProgress} : 账号管理"
	echoContent red "\n=============================================================="
	echoContent yellow "# 每次删除、添加账号后，需要重新查看订阅生成订阅\n"
	echoContent yellow "1.查看账号"
	echoContent yellow "2.查看订阅"
	echoContent yellow "3.添加用户"
	echoContent yellow "4.删除用户"
	echoContent red "=============================================================="
	read -r -p "请输入:" manageAccountStatus
	if [[ "${manageAccountStatus}" == "1" ]]; then
		showAccounts 1
	elif [[ "${manageAccountStatus}" == "2" ]]; then
		subscribe 1
	elif [[ "${manageAccountStatus}" == "3" ]]; then
		addUser
	elif [[ "${manageAccountStatus}" == "4" ]]; then
		removeUser
	else
		echoContent red " ---> 选择错误"
	fi
}

# 订阅
subscribe() {
	if [[ -n "${configPath}" ]]; then
		echoContent skyBlue "-------------------------备注---------------------------------"
		echoContent yellow "# 查看订阅时会重新生成订阅"
		echoContent yellow "# 每次添加、删除账号需要重新查看订阅"
		rm -rf /etc/v2ray-agent/subscribe/*
		rm -rf /etc/v2ray-agent/subscribe_tmp/*
		showAccounts >/dev/null
		mv /etc/v2ray-agent/subscribe_tmp/* /etc/v2ray-agent/subscribe/

		if [[ -n $(ls /etc/v2ray-agent/subscribe/) ]]; then
			find /etc/v2ray-agent/subscribe/* | while read -r email; do
				email=$(echo "${email}" | awk -F "[s][u][b][s][c][r][i][b][e][/]" '{print $2}')
				local base64Result
				base64Result=$(base64 -w 0 "/etc/v2ray-agent/subscribe/${email}")
				echo "${base64Result}" >"/etc/v2ray-agent/subscribe/${email}"
				echoContent skyBlue "--------------------------------------------------------------"
				echoContent yellow "email：$(echo "${email}" | awk -F "[_]" '{print $1}')\n"
				echoContent yellow "url：https://${currentHost}/s/${email}\n"
				echoContent yellow "在线二维码：https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://${currentHost}/s/${email}\n"
				echo "https://${currentHost}/s/${email}" | qrencode -s 10 -m 1 -t UTF8
				echoContent skyBlue "--------------------------------------------------------------"
			done
		fi
	else
		echoContent red " ---> 未安装"
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
	echoContent green "当前alpn首位为：${currentAlpn}"
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
		frontingTypeJSON=$(jq -r ".inbounds[0].streamSettings.xtlsSettings.alpn = [\"h2\",\"http/1.1\"]" ${configPath}${frontingType}.json)
		echo "${frontingTypeJSON}" | jq . >${configPath}${frontingType}.json

	elif [[ "${selectSwitchAlpnType}" == "1" && "${currentAlpn}" == "h2" ]]; then
		local frontingTypeJSON
		frontingTypeJSON=$(jq -r ".inbounds[0].streamSettings.xtlsSettings.alpn =[\"http/1.1\",\"h2\"]" ${configPath}${frontingType}.json)
		echo "${frontingTypeJSON}" | jq . >${configPath}${frontingType}.json
	else
		echoContent red " ---> 选择错误"
		exit 0
	fi
	reloadCore
}
# 主菜单
menu() {
	cd "$HOME" || exit
	echoContent red "\n=============================================================="
	echoContent green "作者：mack-a"
	echoContent green "当前版本：v2.5.45"
	echoContent green "Github：https://github.com/mack-a/v2ray-agent"
	echoContent green "描述：八合一共存脚本\c"
	showInstallStatus
	echoContent red "\n=============================================================="
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

	echoContent skyBlue "-------------------------工具管理-----------------------------"
	echoContent yellow "4.账号管理"
	echoContent yellow "5.更换伪装站"
	echoContent yellow "6.更新证书"
	echoContent yellow "7.更换CDN节点"
	echoContent yellow "8.IPv6分流"
	echoContent yellow "9.WARP分流"
	echoContent yellow "10.流媒体工具"
	echoContent yellow "11.添加新端口"
	echoContent yellow "12.BT下载管理"
	echoContent yellow "13.切换alpn"
	echoContent skyBlue "-------------------------版本管理-----------------------------"
	echoContent yellow "14.core管理"
	echoContent yellow "15.更新脚本"
	echoContent yellow "16.安装BBR、DD脚本"
	echoContent skyBlue "-------------------------脚本管理-----------------------------"
	echoContent yellow "17.查看日志"
	echoContent yellow "18.卸载脚本"
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
		switchAlpn 1
		;;
	14)
		coreVersionManageMenu 1
		;;
	15)
		updateV2RayAgent 1
		;;
	16)
		bbrInstall
		;;
	17)
		checkLog 1
		;;
	18)
		unInstall 1
		;;
	esac
}
cronRenewTLS
menu
