#!/usr/bin/env bash
# 检测区
# -------------------------------------------------------------
# 检查系统
checkSystem() {
	if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
		centosVersion=$(rpm -q centos-release | awk -F "[-]" '{print $3}' | awk -F "[.]" '{print $1}')

		if [[ -z "${centosVersion}" ]] && grep </etc/centos-release "release 8"; then
			centosVersion=8
		fi
		release="centos"
		installType='yum -y install'
		# removeType='yum -y remove'
		upgrade="yum update -y --skip-broken"

	elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
		if grep </etc/issue -i "8"; then
			debianVersion=8
		fi
		release="debian"
		installType='apt -y install'
		upgrade="apt update -y"
		# removeType='apt -y autoremove'

	elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
		release="ubuntu"
		installType='apt-get -y install'
		upgrade="apt-get update -y"
		# removeType='apt-get --purge remove'
	fi

	if [[ -z ${release} ]]; then
		echo "本脚本不支持此系统，请将下方日志反馈给开发者"
		cat /etc/issue
		cat /proc/version
		exit 0
	fi
}

# 初始化全局变量
initVar() {
	installType='yum -y install'
	removeType='yum -y remove'
	upgrade="yum -y update"
	echoType='echo -e'

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

	# 选择的个性化安装方式
	selectCustomInstallType=

	# v2ray-core配置文件的路径
	configPath=

	# xray-core配置文件的路径
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

	# pingIPv6 pingIPv4
	# pingIPv4=
	pingIPv6=

	# 集成更新证书逻辑不再使用单独的脚本--RenewTLS
	renewTLS=$1
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
					# coreInstallPath=/etc/v2ray-agent/v2ray/v2ray
					ctlPath=/etc/v2ray-agent/v2ray/v2ctl
				elif grep </etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json -q xtls; then
					# 带XTLS的v2ray-core
					# coreInstallPath=/etc/v2ray-agent/v2ray/v2ray
					ctlPath=/etc/v2ray-agent/v2ray/v2ctl
					coreInstallType=3
				fi
			fi
		fi

		if [[ -d "/etc/v2ray-agent/xray" && -f "/etc/v2ray-agent/xray/xray" ]]; then
			# 这里检测xray-core
			if [[ -d "/etc/v2ray-agent/xray/conf" && -f "/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json" ]]; then
				# xray-core
				configPath=/etc/v2ray-agent/xray/conf/
				# coreInstallPath=/etc/v2ray-agent/xray/xray
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
		if echo ${row} | grep -q VLESS_TCP_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'0'
		fi
		if echo ${row} | grep -q VLESS_WS_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'1'
		fi
		if echo ${row} | grep -q VMess_TCP_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'2'
		fi
		if echo ${row} | grep -q VMess_WS_inbounds; then
			currentInstallProtocolType=${currentInstallProtocolType}'3'
		fi
	done < <(ls ${configPath} | grep inbounds.json | awk -F "[.]" '{print $1}')

	if [[ -f "/etc/v2ray-agent/trojan/trojan-go" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]; then
		currentInstallProtocolType=${currentInstallProtocolType}'4'
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
		local path
		path=$(jq .inbounds[0].settings.fallbacks[].path ${configPath}02_VLESS_TCP_inbounds.json | awk -F "[\"][/]" '{print $2}' | awk -F "[\"]" '{print $1}' | tail -n +2 | head -n 1)
		# local path=$(cat ${configPath}02_VLESS_TCP_inbounds.json | jq .inbounds[0].settings.fallbacks | jq -c '.[].path' | awk -F "[\"][/]" '{print $2}' | awk -F "[\"]" '{print $1}' | tail -n +2 | head -n 1)
		# jq .inbounds[0].settings.fallbacks.[].path ${configPath}02_VLESS_TCP_inbounds.json| awk -F "[\"][/]" '{print $2}' | awk -F "[\"]" '{print $1}' | tail -n +2 | head -n 1

		if [[ -n "${path}" ]]; then
			if [[ "${path:0-3}" == "vws" && ${#path} -gt 6 ]]; then
				currentPath=$(echo "${path}" | awk -F "[v][w][s]" '{print $1}')
			elif [[ "${path:0-2}" == "ws" ]]; then
				currentPath=$(echo "${path}" | awk -F "[w][s]" '{print $1}')
			elif [[ "${path:0-2}" == "tcp" ]]; then
				currentPath=$(echo "${path}" | awk -F "[t][c][p]" '{print $1}')
			fi
		fi
	fi
	if [[ "${coreInstallType}" == "1" ]]; then
		currentHost=$(jq .inbounds[0].streamSettings.xtlsSettings.certificates[0].certificateFile ${configPath}02_VLESS_TCP_inbounds.json | awk -F '[t][l][s][/]' '{print $2}' | awk -F '["]' '{print $1}' | awk -F '[.][c][r][t]' '{print $1}')
		currentUUID=$(jq .inbounds[0].settings.clients[0].id ${configPath}02_VLESS_TCP_inbounds.json | awk -F '["]' '{print $2}')
		currentAdd=$(jq .inbounds[0].settings.clients[0].add ${configPath}02_VLESS_TCP_inbounds.json | awk -F '["]' '{print $2}')
		currentPort=$(jq .inbounds[0].port ${configPath}02_VLESS_TCP_inbounds.json)

	elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
		if [[ "${coreInstallType}" == "3" ]]; then
			currentHost=$(jq .inbounds[0].streamSettings.xtlsSettings.certificates[0].certificateFile ${configPath}02_VLESS_TCP_inbounds.json | awk -F '[t][l][s][/]' '{print $2}' | awk -F '["]' '{print $1}' | awk -F '[.][c][r][t]' '{print $1}')
		else
			currentHost=$(jq .inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile ${configPath}02_VLESS_TCP_inbounds.json | awk -F '[t][l][s][/]' '{print $2}' | awk -F '["]' '{print $1}' | awk -F '[.][c][r][t]' '{print $1}')
		fi
		currentAdd=$(jq .inbounds[0].settings.clients[0].add ${configPath}02_VLESS_TCP_inbounds.json | awk -F '["]' '{print $2}')
		currentUUID=$(jq .inbounds[0].settings.clients[0].id ${configPath}02_VLESS_TCP_inbounds.json | awk -F '["]' '{print $2}')
		currentPort=$(jq .inbounds[0].port ${configPath}02_VLESS_TCP_inbounds.json)
	fi
}

# 清理旧残留
cleanUp() {
	if [[ "$1" == "v2rayClean" ]]; then
		rm -rf "$(find /etc/v2ray-agent/v2ray/* | grep -E '(config_full.json|conf)')"
		handleV2Ray stop >/dev/null 2>&1
		rm -f /etc/systemd/system/v2ray.service
	elif [[ "$1" == "xrayClean" ]]; then
		rm -rf "$(find /etc/v2ray-agent/xray/* | grep -E '(config_full.json|conf)')"
		handleXray stop >/dev/null 2>&1
		rm -f /etc/systemd/system/xray.service

	elif [[ "$1" == "v2rayDel" ]]; then
		rm -rf /etc/v2ray-agent/v2ray/*

	elif [[ "$1" == "xrayDel" ]]; then
		rm -rf /etc/v2ray-agent/xray/*
	fi
}

initVar $1
checkSystem
readInstallType
readInstallProtocolType
readConfigHostPathUUID

# -------------------------------------------------------------

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
	echoContent skyBlue "\n进度  $1/${totalProgress} : 安装工具"
	if [[ "${release}" == "centos" ]]; then
		echoContent green " ---> 检查安装jq、nginx epel源、yum-utils、semanage"
		# jq epel源
		if [[ -z $(command -v jq) ]]; then
			rpm -ivh http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm >/dev/null 2>&1
		fi

		nginxEpel=""
		if rpm -qa | grep -q nginx; then
			local nginxVersion
			nginxVersion=$(rpm -qa | grep -v grep | grep nginx | head -1 | awk -F '[-]' '{print $2}')
			if [[ $(echo "${nginxVersion}" | awk -F '[.]' '{print $1}') -le 1 ]] && [[ $(echo "${nginxVersion}" | awk -F '[.]' '{print $2}') -le 17 ]]; then
				rpm -qa | grep -v grep | grep nginx | xargs rpm -e >/dev/null 2>&1
			fi
		fi

		if [[ "${centosVersion}" == "6" ]]; then
			nginxEpel="http://nginx.org/packages/centos/6/x86_64/RPMS/nginx-1.18.0-1.el6.ngx.x86_64.rpm"
			rpm -ivh ${nginxEpel} >/etc/v2ray-agent/error.log 2>&1
		elif [[ "${centosVersion}" == "7" ]]; then
			nginxEpel="http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm"
			policyCoreUtils="policycoreutils-python.x86_64"
			rpm -ivh ${nginxEpel} >/etc/v2ray-agent/error.log 2>&1
		elif [[ "${centosVersion}" == "8" ]]; then
			nginxEpel="http://nginx.org/packages/centos/8/x86_64/RPMS/nginx-1.18.0-1.el8.ngx.x86_64.rpm"
			policyCoreUtils="policycoreutils-python-utils-2.9-9.el8.noarch"
		fi

		# yum-utils
		if [[ "${centosVersion}" == "8" ]]; then
			upgrade="yum update -y --skip-broken --nobest"
			installType="yum -y install --nobest"
			${installType} yum-utils >/etc/v2ray-agent/error.log 2>&1
		else
			${installType} yum-utils >/etc/v2ray-agent/error.log 2>&1
		fi

	fi
	# 修复ubuntu个别系统问题
	if [[ "${release}" == "ubuntu" ]]; then
		dpkg --configure -a
	fi

	if [[ -n $(pgrep -f "apt") ]]; then
		pgrep -f apt | xargs kill -9
	fi

	echoContent green " ---> 检查、安装更新【新机器会很慢，耐心等待】"

	${upgrade} >/dev/null
	if [[ "${release}" == "centos" ]]; then
		rm -rf /var/run/yum.pid
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

	if ! find /usr/bin /usr/sbin | grep -q -w nginx; then
		echoContent green " ---> 安装nginx"
		if [[ "${centosVersion}" == "8" ]]; then
			rpm -ivh ${nginxEpel} >/etc/v2ray-agent/error.log 2>&1
		else
			${installType} nginx >/dev/null 2>&1
		fi

		if [[ -n "${centosVersion}" ]]; then
			systemctl daemon-reload
			systemctl enable nginx
		fi
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w semanage; then
		echoContent green " ---> 安装semanage"
		${installType} bash-completion >/dev/null 2>&1
		if [[ -n "${policyCoreUtils}" ]]; then
			${installType} ${policyCoreUtils} >/dev/null 2>&1
		fi
		if [[ -n $(which semanage) ]]; then
			semanage port -a -t http_port_t -p tcp 31300

		fi
	fi

	if ! find /usr/bin /usr/sbin | grep -q -w sudo; then
		echoContent green " ---> 安装sudo"
		${installType} sudo >/dev/null 2>&1
	fi
	# todo 关闭防火墙

	if [[ ! -d "$HOME/.acme.sh" ]] || [[ -d "$HOME/.acme.sh" && -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
		echoContent green " ---> 安装acme.sh"
		curl -s https://get.acme.sh | sh >/etc/v2ray-agent/tls/acme.log
		if [[ ! -d "$HOME/.acme.sh" ]] || [[ -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
			echoContent red "  acme安装失败--->"
			echoContent yellow "错误排查："
			echoContent red "  1.获取Github文件失败，请等待Gitub恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
			echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
			exit 0
		fi
	fi
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
			echoContent yellow "请输入要配置的域名 例：blog.v2ray-agent.com --->"
			read -r -p "域名:" domain
		fi
	else
		echo
		echoContent yellow "请输入要配置的域名 例：blog.v2ray-agent.com --->"
		read -r -p "域名:" domain
	fi

	if [[ -z ${domain} ]]; then
		echoContent red "  域名不可为空--->"
		initTLSNginxConfig
	else
		# 修改配置
		echoContent green "\n ---> 配置Nginx"
		touch /etc/nginx/conf.d/alone.conf
		echo "server {listen 80;listen [::]:80;server_name ${domain};root /usr/share/nginx/html;location ~ /.well-known {allow all;}location /test {return 200 'fjkvymb6len';}}" >/etc/nginx/conf.d/alone.conf
		# 启动nginx
		handleNginx start
		echoContent yellow "\n检查IP是否设置为当前VPS"
		checkIP
		# 测试nginx
		echoContent yellow "\n检查Nginx是否正常访问"
		sleep 0.5
		domainResult=$(curl -s "${domain}/test" | grep fjkvymb6len)
		if [[ -n ${domainResult} ]]; then
			handleNginx stop
			echoContent green "\n ---> Nginx配置成功"
		else
			echoContent red " ---> 无法正常访问服务器，请检测域名是否正确、域名的DNS解析以及防火墙设置是否正确--->"
			exit 0
		fi
	fi
}

# 修改nginx重定向配置
updateRedirectNginxConf() {

	cat <<EOF >/etc/nginx/conf.d/alone.conf
    server {
        listen 80;
        listen [::]:80;
        server_name ${domain};
        # shellcheck disable=SC2154
        return 301 https://${domain}$request_uri;
    }
EOF

	if [[ "${debianVersion}" == "8" ]]; then
		cat <<EOF >>/etc/nginx/conf.d/alone.conf
        server {
        listen 31300;
        server_name ${domain};
        root /usr/share/nginx/html;
        location /s/ {
        	add_header Content-Type text/plain;
        	alias /etc/v2ray-agent/subscribe/;
        }
        # location / {
        #   add_header Strict-Transport-Security "max-age=63072000" always;
        # }
#       location ~ /.well-known {allow all;}
#       location /test {return 200 'fjkvymb6len';}
    }
EOF
	else
		cat <<EOF >>/etc/nginx/conf.d/alone.conf
        server {
            listen 31300;
            server_name ${domain};
            root /usr/share/nginx/html;
            location /s/ {
            	add_header Content-Type text/plain;
        		alias /etc/v2ray-agent/subscribe/;
        	}
            location / {
                add_header Strict-Transport-Security "max-age=63072000" always;
            }
    #       location ~ /.well-known {allow all;}
    #       location /test {return 200 'fjkvymb6len';}
        }
EOF
	fi

}

# 检查ip
checkIP() {
	echoContent skyBlue " ---> 检查ipv4中"
	pingIP=$(ping -c 1 -W 1000 ${domain} | sed '2{s/[^(]*(//;s/).*//;q;}' | sed -n '$p')
	if [[ -z $(echo "${pingIP}" | awk -F "[.]" '{print $4}') ]]; then
		echoContent skyBlue " ---> 检查ipv6中"
		pingIP=$(ping6 -c 1 ${domain} | sed '2{s/[^(]*(//;s/).*//;q;}' | sed -n '$p')
		pingIPv6=${pingIP}
	fi

	if [[ -n "${pingIP}" ]]; then # && [[ `echo ${pingIP}|grep '^\([1-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)\.\([0-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)\.\([0-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)\.\([0-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)$'` ]]
		echo
		read -r -p "当前域名的IP为 [${pingIP}]，是否正确[y/n]？" domainStatus
		if [[ "${domainStatus}" == "y" ]]; then
			echoContent green "\n ---> IP确认完成"
		else
			echoContent red "\n ---> 1.检查Cloudflare DNS解析是否正常"
			echoContent red " ---> 2.检查Cloudflare DNS云朵是否为灰色\n"
			exit 0
		fi
	else
		read -r -p "IP查询失败，是否重试[y/n]？" retryStatus
		if [[ "${retryStatus}" == "y" ]]; then
			checkIP
		else
			exit 0
		fi
	fi
}
# 安装TLS
installTLS() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : 申请TLS证书\n"
	local tlsDomain=${domain}
	# 安装tls
	if [[ -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" && -f "/etc/v2ray-agent/tls/${tlsDomain}.key" ]] || [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
		# 存在证书
		echoContent green " ---> 检测到证书"
		checkTLStatus "${tlsDomain}"
		if [[ "${tlsStatus}" == "已过期" ]]; then
			rm -rf $HOME/.acme.sh/${tlsDomain}_ecc/*
			rm -rf /etc/v2ray-agent/tls/${tlsDomain}*
			installTLS "$1"
		else
			echoContent green " ---> 证书有效"

			if ! ls /etc/v2ray-agent/tls/ | grep -q "${tlsDomain}.crt" || ! ls /etc/v2ray-agent/tls/ | grep -q "${tlsDomain}.key"; then
				sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
			else
				echoContent yellow " ---> 如未过期请选择[n]\n"
				read -r -p "是否重新安装？[y/n]:" reInstallStatus
				if [[ "${reInstallStatus}" == "y" ]]; then
					rm -rf /etc/v2ray-agent/tls/*
					installTLS "$1"
				fi
			fi
		fi
	elif [[ -d "$HOME/.acme.sh" ]] && [[ ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" || ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" ]]; then
		echoContent green " ---> 安装TLS证书"
		if [[ -n "${pingIPv6}" ]]; then
			sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 --listen-v6 >/dev/null
		else
			sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 >/dev/null
		fi

		sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
		if [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
			echoContent red " ---> TLS安装失败，请检查acme日志"
			exit 0
		elif [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.key") ]]; then
			echoContent red " ---> TLS安装失败，请检查acme日志"
			exit 0
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
			customPath=$(head -n 50 /dev/urandom | sed 's/[^a-z]//g' | strings -n 4 | tr 'A-Z' 'a-z' | head -1)
			currentPath=${customPath:0:4}
		fi
	fi
	echoContent yellow "path：${customPath}"
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
			wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html1.zip >/dev/null
			unzip -o /usr/share/nginx/html1.zip -d /usr/share/nginx/html >/dev/null
			rm -f /usr/share/nginx/html.zip*
			echoContent green " ---> 添加伪装站点成功"
		fi
	else
		rm -rf /usr/share/nginx/html
		wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html1.zip >/dev/null
		unzip -o /usr/share/nginx/html1.zip -d /usr/share/nginx/html >/dev/null
		rm -f /usr/share/nginx/html1.zip*
		echoContent green " ---> 添加伪装站点成功"
	fi

}
# 操作Nginx
handleNginx() {

	if [[ -z $(pgrep -f "nginx") ]] && [[ "$1" == "start" ]]; then
		nginx
		sleep 0.5
		if ! ps -ef | grep -v grep | grep -q nginx; then
			echoContent red " ---> Nginx启动失败，请检查日志"
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

# 定时任务更新tls证书
installCronTLS() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : 添加定时维护证书"
	if ! crontab -l | grep -v grep | grep -q '/etc/v2ray-agent/install.sh'; then
		crontab -l >/etc/v2ray-agent/backup_crontab.cron
		if grep </etc/v2ray-agent/backup_crontab.cron -q /etc/v2ray-agent/reloadInstallTLS.sh; then
			sed -i "s/30 1 \\* \\* \\* \\/bin\\/bash \\/etc\\/v2ray-agent\\/reloadInstallTLS.sh//g" $(grep "30 1 \* \* \* /bin/bash /etc/v2ray-agent/reloadInstallTLS.sh" -rl /etc/v2ray-agent/backup_crontab.cron)
		fi
		# 定时任务
		echo "30 1 * * * /bin/bash /etc/v2ray-agent/install.sh RenewTLS" >>/etc/v2ray-agent/backup_crontab.cron
		crontab /etc/v2ray-agent/backup_crontab.cron
	fi

	if [[ -n $(crontab -l | grep -v grep | grep '/etc/v2ray-agent/install.sh') ]]; then

		crontab -l | uniq | awk '/./ {print}' >>/etc/v2ray-agent/backup_crontab.cron
		local crontabResult=$(cat /etc/v2ray-agent/backup_crontab.cron | uniq | awk '/./ {print}')
		echo "${crontabResult}" >/etc/v2ray-agent/backup_crontab.cron
		crontab /etc/v2ray-agent/backup_crontab.cron
		echoContent green " ---> 添加定时维护证书成功"
	else
		echo "30 1 * * * /bin/bash /etc/v2ray-agent/install.sh RenewTLS" >>/etc/v2ray-agent/backup_crontab.cron
		crontab /etc/v2ray-agent/backup_crontab.cron
		echoContent green " ---> 添加定时维护证书成功"
	fi
}

# 更新证书
renewalTLS() {
	echoContent skyBlue "\n进度  1/1 : 更新证书"

	if [[ -d "$HOME/.acme.sh/${currentHost}_ecc" ]] && [[ -f "$HOME/.acme.sh/${currentHost}_ecc/${currentHost}.key" ]] && [[ -f "$HOME/.acme.sh/${currentHost}_ecc/${currentHost}.cer" ]]; then
		modifyTime=$(stat $HOME/.acme.sh/${currentHost}_ecc/${currentHost}.key | sed -n '7,6p' | awk '{print $2" "$3" "$4" "$5}')

		modifyTime=$(date +%s -d "${modifyTime}")
		currentTime=$(date +%s)
		stampDiff=$(expr ${currentTime} - ${modifyTime})
		days=$(expr ${stampDiff} / 86400)
		remainingDays=$(expr 90 - ${days})
		tlsStatus=${remainingDays}
		if [[ ${remainingDays} -le 0 ]]; then
			tlsStatus="已过期"
		fi
		echoContent skyBlue " ---> 证书生成日期:$(date -d @"${modifyTime}" +"%F %H:%M:%S")"
		echoContent skyBlue " ---> 证书生成天数:${days}"
		echoContent skyBlue " ---> 证书剩余天数:"${tlsStatus}

		if [[ ${remainingDays} -le 1 ]]; then
			echoContent yellow " ---> 重新生成证书"
			handleNginx stop
			sudo "$HOME/.acme.sh/acme.sh" --cron --home "$HOME/.acme.sh"
			sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${currentHost}" --fullchainpath /etc/v2ray-agent/tls/"${currentHost}.crt" --keypath /etc/v2ray-agent/tls/"${currentHost}.key" --ecc | sudo tee -a /etc/v2ray-agent/tls/acme.log
			handleNginx start

			if [[ "${coreInstallType}" == "1" ]]; then
				handleXray stop
				handleXray start
			elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
				handleV2Ray stop
				handleV2Ray start
			fi

		else
			echoContent green " ---> 证书有效"
		fi
	else
		echoContent red " ---> 未安装"
	fi
}
# 查看TLS证书的状态
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
				tlsStatus="已过期"
			fi
			echoContent skyBlue " ---> 证书生成日期:$(date -d "@${modifyTime}" +"%F %H:%M:%S")"
			echoContent skyBlue " ---> 证书生成天数:${days}"
			echoContent skyBlue " ---> 证书剩余天数:${tlsStatus}"
		fi
	fi
}

# 安装V2Ray、指定版本
installV2Ray() {
	readInstallType
	echoContent skyBlue "\n进度  $1/${totalProgress} : 安装V2Ray"

	if [[ "${coreInstallType}" != "2" && "${coreInstallType}" != "3" ]]; then
		if [[ "${selectCoreType}" == "2" ]]; then
			version=$(curl -s https://github.com/v2fly/v2ray-core/releases | grep /v2ray-core/releases/tag/ | head -1 | awk -F "[/]" '{print $6}' | awk -F "[>]" '{print $2}' | awk -F "[<]" '{print $1}')
		else
			version=${v2rayCoreVersion}
		fi

		echoContent green " ---> v2ray-core版本:${version}"
		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip"
		else
			wget -c -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip" >/dev/null 2>&1
		fi

		unzip -o /etc/v2ray-agent/v2ray/v2ray-linux-64.zip -d /etc/v2ray-agent/v2ray >/dev/null
		rm -rf /etc/v2ray-agent/v2ray/v2ray-linux-64.zip
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
		version=$(curl -s https://github.com/XTLS/Xray-core/releases | grep /XTLS/Xray-core/releases/tag/ | grep "Xray-core v" | head -1 | awk '{print $3}' | awk -F "[<]" '{print $1}')

		echoContent green " ---> Xray-core版本:${version}"
		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/Xray-linux-64.zip"
		else
			wget -c -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/Xray-linux-64.zip" >/dev/null 2>&1
		fi

		unzip -o /etc/v2ray-agent/xray/Xray-linux-64.zip -d /etc/v2ray-agent/xray >/dev/null
		rm -rf /etc/v2ray-agent/xray/Xray-linux-64.zip
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

# 安装Trojan-go
installTrojanGo() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : 安装Trojan-Go"

	if ! ls /etc/v2ray-agent/trojan/ | grep -q trojan-go; then
		version=$(curl -s https://github.com/p4gefau1t/trojan-go/releases | grep /trojan-go/releases/tag/ | head -1 | awk -F "[/]" '{print $6}' | awk -F "[>]" '{print $2}' | awk -F "[<]" '{print $1}')
		echoContent green " ---> Trojan-Go版本:${version}"
		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/trojan/ "https://github.com/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-amd64.zip"
		else
			wget -c -P /etc/v2ray-agent/trojan/ "https://github.com/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-amd64.zip" >/dev/null 2>&1
		fi
		unzip -o /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip -d /etc/v2ray-agent/trojan >/dev/null
		rm -rf /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip
	else
		echoContent green " ---> Trojan-Go版本:$(/etc/v2ray-agent/trojan/trojan-go --version | awk '{print $2}' | head -1)"

		read -r -p "是否重新安装？[y/n]:" reInstallTrojanStatus
		if [[ "${reInstallTrojanStatus}" == "y" ]]; then
			rm -rf /etc/v2ray-agent/trojan/trojan-go*
			installTrojanGo "$1"
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
	echoContent red "=============================================================="
	read -r -p "请选择：" selectV2RayType
	if [[ "${selectV2RayType}" == "1" ]]; then
		updateV2Ray
	elif [[ "${selectV2RayType}" == "2" ]]; then
		echoContent yellow "\n1.只可以回退最近的五个版本"
		echoContent yellow "2.不保证回退后一定可以正常使用"
		echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
		echoContent skyBlue "------------------------Version-------------------------------"
		curl -s https://github.com/v2fly/v2ray-core/releases | grep /v2ray-core/releases/tag/ | head -3 | awk -F "[/]" '{print $6}' | awk -F "[>]" '{print $2}' | awk -F "[<]" '{print $1}' | tail -n 2 | awk '{print ""NR""":"$0}'
		echoContent skyBlue "--------------------------------------------------------------"
		read -r -p "请输入要回退的版本：" selectV2rayVersionType
		version=$(curl -s https://github.com/v2fly/v2ray-core/releases | grep /v2ray-core/releases/tag/ | head -3 | awk -F "[/]" '{print $6}' | awk -F "[>]" '{print $2}' | awk -F "[<]" '{print $1}' | tail -n 2 | awk '{print ""NR""":"$0}' | grep "${selectV2rayVersionType}:" | awk -F "[:]" '{print $2}')
		if [[ -n "${version}" ]]; then
			updateV2Ray ${version}
		else
			echoContent red "\n ---> 输入有误，请重新输入"
			v2rayVersionManageMenu 1
		fi
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
	echoContent red "=============================================================="
	read -r -p "请选择：" selectXrayType
	if [[ "${selectXrayType}" == "1" ]]; then
		updateXray
	elif [[ "${selectXrayType}" == "2" ]]; then
		echoContent yellow "\n1.由于Xray-core频繁更新，只可以回退最近的两个版本"
		echoContent yellow "2.不保证回退后一定可以正常使用"
		echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
		echoContent skyBlue "------------------------Version-------------------------------"
		curl -s https://github.com/XTLS/Xray-core/releases | grep /XTLS/Xray-core/releases/tag/ | grep "Xray-core v" | head -5 | awk -F "[X][r][a][y][-][c][o][r][e][ ]" '{print $2}' | awk -F "[<]" '{print $1}' | tail -n 5 | awk '{print ""NR""":"$0}'
		echoContent skyBlue "--------------------------------------------------------------"
		read -r -p "请输入要回退的版本：" selectXrayVersionType
		version=$(curl -s https://github.com/XTLS/Xray-core/releases | grep /XTLS/Xray-core/releases/tag/ | grep "Xray-core v" | head -5 | awk -F "[X][r][a][y][-][c][o][r][e][ ]" '{print $2}' | awk -F "[<]" '{print $1}' | tail -n 5 | awk '{print ""NR""":"$0}' | grep "${selectXrayVersionType}:" | awk -F "[:]" '{print $2}')
		if [[ -n "${version}" ]]; then
			updateXray "${version}"
		else
			echoContent red "\n ---> 输入有误，请重新输入"
			xrayVersionManageMenu 1
		fi
	fi

}
# 更新V2Ray
updateV2Ray() {
	readInstallType
	if [[ -z "${coreInstallType}" ]]; then

		if [[ -n "$1" ]]; then
			version=$1
		else
			version=$(curl -s https://github.com/v2fly/v2ray-core/releases | grep /v2ray-core/releases/tag/ | head -1 | awk -F "[/]" '{print $6}' | awk -F "[>]" '{print $2}' | awk -F "[<]" '{print $1}')
		fi
		# 使用锁定的版本
		if [[ -n "${v2rayCoreVersion}" ]]; then
			version=${v2rayCoreVersion}
		fi
		echoContent green " ---> v2ray-core版本:${version}"

		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ "https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip"
		else
			wget -c -P "/etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip" >/dev/null 2>&1
		fi

		unzip -o /etc/v2ray-agent/v2ray/v2ray-linux-64.zip -d /etc/v2ray-agent/v2ray >/dev/null
		rm -rf /etc/v2ray-agent/v2ray/v2ray-linux-64.zip
		handleV2Ray stop
		handleV2Ray start
	else
		echoContent green " ---> 当前v2ray-core版本:$(/etc/v2ray-agent/v2ray/v2ray --version | awk '{print $2}' | head -1)"

		if [[ -n "$1" ]]; then
			version=$1
		else
			version=$(curl -s https://github.com/v2fly/v2ray-core/releases | grep /v2ray-core/releases/tag/ | head -1 | awk -F "[/]" '{print $6}' | awk -F "[>]" '{print $2}' | awk -F "[<]" '{print $1}')
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
			version=$(curl -s https://github.com/XTLS/Xray-core/releases | grep /XTLS/Xray-core/releases/tag/ | grep "Xray-core v" | head -1 | awk '{print $3}' | awk -F "[<]" '{print $1}')
		fi

		echoContent green " ---> Xray-core版本:${version}"

		if wget --help | grep -q show-progress; then
			wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/Xray-linux-64.zip"
		else
			wget -c -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/Xray-linux-64.zip" >/dev/null 2>&1
		fi

		unzip -o /etc/v2ray-agent/xray/Xray-linux-64.zip -d /etc/v2ray-agent/xray >/dev/null
		rm -rf /etc/v2ray-agent/xray/Xray-linux-64.zip
		chmod 655 /etc/v2ray-agent/xray/xray
		handleXray stop
		handleXray start
	else
		echoContent green " ---> 当前Xray-core版本:$(/etc/v2ray-agent/xray/xray --version | awk '{print $2}' | head -1)"

		if [[ -n "$1" ]]; then
			version=$1
		else
			version=$(curl -s https://github.com/XTLS/Xray-core/releases | grep /XTLS/Xray-core/releases/tag/ | grep "Xray-core v" | head -1 | awk '{print $3}' | awk -F "[<]" '{print $1}')
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
# 更新Trojan-Go
updateTrojanGo() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : 更新Trojan-Go"
	if [[ ! -d "/etc/v2ray-agent/trojan/" ]]; then
		echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
		menu
		exit 0
	fi
	if find /etc/v2ray-agent/trojan/ | grep -q "trojan-go"; then
		version=$(curl -s https://github.com/p4gefau1t/trojan-go/releases | grep /trojan-go/releases/tag/ | head -1 | awk -F "[/]" '{print $6}' | awk -F "[>]" '{print $2}' | awk -F "[<]" '{print $1}')
		echoContent green " ---> Trojan-Go版本:${version}"
		if [[ -n $(wget --help | grep show-progress) ]]; then
			wget -c -q --show-progress -P /etc/v2ray-agent/trojan/ "https://github.com/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-amd64.zip"
		else
			wget -c -P /etc/v2ray-agent/trojan/ "https://github.com/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-amd64.zip" >/dev/null 2>&1
		fi
		unzip -o /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip -d /etc/v2ray-agent/trojan >/dev/null
		rm -rf /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip
		handleTrojanGo stop
		handleTrojanGo start
	else
		echoContent green " ---> 当前Trojan-Go版本:$(/etc/v2ray-agent/trojan/trojan-go --version | awk '{print $2}' | head -1)"
		if [[ -n $(/etc/v2ray-agent/trojan/trojan-go --version) ]]; then
			version=$(curl -s https://github.com/p4gefau1t/trojan-go/releases | grep /trojan-go/releases/tag/ | head -1 | awk -F "[/]" '{print $6}' | awk -F "[>]" '{print $2}' | awk -F "[<]" '{print $1}')
			if [[ "${version}" == "$(/etc/v2ray-agent/trojan/trojan-go --version | awk '{print $2}' | head -1)" ]]; then
				read -r -p "当前版本与最新版相同，是否重新安装？[y/n]:" reInstalTrojanGoStatus
				if [[ "${reInstalTrojanGoStatus}" == "y" ]]; then
					handleTrojanGo stop
					rm -rf /etc/v2ray-agent/trojan/trojan-go
					updateTrojanGo 1
				else
					echoContent green " ---> 放弃重新安装"
				fi
			else
				read -r -p "最新版本为：${version}，是否更新？[y/n]：" installTrojanGoStatus
				if [[ "${installTrojanGoStatus}" == "y" ]]; then
					rm -rf /etc/v2ray-agent/trojan/trojan-go
					updateTrojanGo 1
				else
					echoContent green " ---> 放弃更新"
				fi
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
# Trojan开机自启
installTrojanService() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : 配置Trojan开机自启"
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
		echoContent green " ---> 配置Trojan开机自启成功"
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
	sleep 0.5

	if [[ "$1" == "start" ]]; then
		if [[ -n $(pgrep -f "v2ray/v2ray") ]]; then
			echoContent green " ---> V2Ray启动成功"
		else
			echoContent red "V2Ray启动失败"
			echoContent red "执行 [ps -ef|grep v2ray] 查看日志"
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
	if [[ -n $(find /bin /usr/bin -name "systemctl") ]] && ls /etc/systemd/system/ | grep -q xray.service; then
		if [[ -z $(pgrep -f "xray/xray") ]] && [[ "$1" == "start" ]]; then
			systemctl start xray.service
		elif [[ -n $(pgrep -f "xray/xray") ]] && [[ "$1" == "stop" ]]; then
			systemctl stop xray.service
		fi
	fi

	sleep 0.5

	if [[ "$1" == "start" ]]; then
		if [[ -n $(pgrep -f "xray/xray") ]]; then
			echoContent green " ---> Xray启动成功"
		else
			echoContent red "xray启动失败"
			echoContent red "执行 [ps -ef|grep xray] 查看日志"
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

# 操作Trojan-Go
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
			echoContent green " ---> Trojan-Go启动成功"
		else
			echoContent red "Trojan-Go启动失败"
			echoContent red "请手动执行【/etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json】,查看错误日志"
			exit 0
		fi
	elif [[ "$1" == "stop" ]]; then
		if [[ -z $(pgrep -f "trojan-go") ]]; then
			echoContent green " ---> Trojan-Go关闭成功"
		else
			echoContent red "Trojan-Go关闭失败"
			echoContent red "请手动执行【ps -ef|grep -v grep|grep trojan-go|awk '{print \$2}'|xargs kill -9】"
			exit 0
		fi
	fi
}
# 初始化V2Ray 配置文件
initV2RayConfig() {
	echoContent skyBlue "\n进度 $2/${totalProgress} : 初始化V2Ray配置"
	if [[ -n "${currentUUID}" ]]; then
		echo
		read -r -p "读取到上次安装记录，是否使用上次安装时的UUID ？[y/n]:" historyUUIDStatus
		if [[ "${historyUUIDStatus}" == "y" ]]; then
			uuid=${currentUUID}
		else
			uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
		fi
	else
		uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
	fi

	if [[ -z "${uuid}" ]]; then
		echoContent red "\n ---> uuid读取错误，重新生成"
		uuid=$(/etc/v2ray-agent/v2ray/v2ctl uuid)
	fi

	rm -rf /etc/v2ray-agent/v2ray/conf/*
	rm -rf /etc/v2ray-agent/v2ray/config_full.json

	cat <<EOF >/etc/v2ray-agent/v2ray/conf/00_log.json
{
  "log": {
    "error": "/etc/v2ray-agent/v2ray/v2ray_error.log",
    "loglevel": "warning"
  }
}
EOF
	# routing
	cat <<EOF >/etc/v2ray-agent/v2ray/conf/09_routing.json
{
    "routing":{
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          }
        ]
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
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {
            "domainStrategy": "UseIPv4"
          },
          "tag": "IPv4-out"
        }
    ]
}
EOF
	fi
	# 取消BT
	#	cat <<EOF >/etc/v2ray-agent/v2ray/conf/10_bt_outbounds.json
	#{
	#    "outbounds": [
	#        {
	#          "protocol": "blackhole",
	#          "settings": {},
	#          "tag": "blocked"
	#        }
	#    ]
	#}
	#EOF

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
	# 回落nginx
	local fallbacksList='{"dest":31300,"xver":0}'

	if echo "${selectCustomInstallType}" | grep -q 4 || [[ "$1" == "all" ]]; then
		# 回落trojan-go
		fallbacksList='{"dest":31296,"xver":0}'
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
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "email": "${domain}_vless_ws"
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

	# VMess_TCP
	if echo "${selectCustomInstallType}" | grep -q 2 || [[ "$1" == "all" ]]; then
		fallbacksList=${fallbacksList}',{"path":"/'${customPath}'tcp","dest":31298,"xver":1}'
		cat <<EOF >/etc/v2ray-agent/v2ray/conf/04_VMess_TCP_inbounds.json
{
"inbounds":[
{
  "port": 31298,
  "listen": "127.0.0.1",
  "protocol": "vmess",
  "tag":"VMessTCP",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "alterId": 1,
        "email": "${domain}_vmess_tcp"
      }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none",
    "tcpSettings": {
      "acceptProxyProtocol": true,
      "header": {
        "type": "http",
        "request": {
          "path": [
            "/${customPath}tcp"
          ]
        }
      }
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
  "port": 31299,
  "protocol": "vmess",
  "tag":"VMessWS",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "alterId": 1,
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

# 初始化Xray 配置文件
initXrayConfig() {
	echoContent skyBlue "\n进度 $2/${totalProgress} : 初始化Xray配置"
	if [[ -n "${currentUUID}" ]]; then
		echo
		read -r -p "读取到上次安装记录，是否使用上次安装时的UUID ？[y/n]:" historyUUIDStatus
		if [[ "${historyUUIDStatus}" == "y" ]]; then
			uuid=${currentUUID}
		else
			uuid=$(/etc/v2ray-agent/xray/xray uuid)
		fi
	else
		uuid=$(/etc/v2ray-agent/xray/xray uuid)
	fi
	if [[ -z "${uuid}" ]]; then
		echoContent red "\n ---> uuid读取错误，重新生成"
		uuid=$(/etc/v2ray-agent/xray/xray uuid)
	fi

	echoContent green "\n ---> 使用成功"

	rm -rf /etc/v2ray-agent/xray/conf/*

	# log
	cat <<EOF >/etc/v2ray-agent/xray/conf/00_log.json
{
  "log": {
    "error": "/etc/v2ray-agent/xray/xray_error.log",
    "loglevel": "warning"
  }
}
EOF
	# routing
	cat <<EOF >/etc/v2ray-agent/xray/conf/09_routing.json
{
    "routing":{
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          }
        ]
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
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {
            "domainStrategy": "UseIPv4"
          },
          "tag": "IPv4-out"
        }
    ]
}
EOF
	fi

	# 取消BT
	#	cat <<EOF >/etc/v2ray-agent/xray/conf/10_bt_outbounds.json
	#{
	#    "outbounds": [
	#        {
	#          "protocol": "blackhole",
	#          "settings": {},
	#          "tag": "blocked"
	#        }
	#    ]
	#}
	#EOF

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
	local fallbacksList='{"dest":31300,"xver":0}'

	if echo "${selectCustomInstallType}" | grep -q 4 || [[ "$1" == "all" ]]; then
		# 回落trojan-go
		fallbacksList='{"dest":31296,"xver":0}'
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
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "email": "${domain}_vless_ws"
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

	# VMess_TCP
	if [[ -n $(echo ${selectCustomInstallType} | grep 2) || "$1" == "all" ]]; then
		fallbacksList=${fallbacksList}',{"path":"/'${customPath}'tcp","dest":31298,"xver":1}'
		cat <<EOF >/etc/v2ray-agent/xray/conf/04_VMess_TCP_inbounds.json
{
"inbounds":[
{
  "port": 31298,
  "listen": "127.0.0.1",
  "protocol": "vmess",
  "tag":"VMessTCP",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "alterId": 1,
        "email": "${domain}_vmess_tcp"
      }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none",
    "tcpSettings": {
      "acceptProxyProtocol": true,
      "header": {
        "type": "http",
        "request": {
          "path": [
            "/${customPath}tcp"
          ]
        }
      }
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
  "port": 31299,
  "protocol": "vmess",
  "tag":"VMessWS",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "alterId": 1,
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
        "http/1.1"
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
        "74.82.42.42",
        "8.8.8.8",
        "8.8.4.4",
        "1.1.1.1",
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
	echoContent skyBlue "\n进度 $1/${totalProgress} : 添加DNS智能解析"
	echoContent yellow "\n 移动:104.19.45.117"
	echoContent yellow " 联通:amp.cloudflare.com"
	echoContent yellow " 电信:www.digitalocean.com"
	echoContent skyBlue "----------------------------"
	read -r -p '是否使用？[y/n]:' dnsProxy
	if [[ "${dnsProxy}" == "y" ]]; then
		add="domain08.qiu4.ml"
		echoContent green "\n ---> 使用成功"
	else
		add="${domain}"
	fi
}

# 通用
defaultBase64Code() {
	local type=$1
	local ps=$2
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

	local subAccount=${currentHost}_$(echo "${id//\"/}_currentHost" | md5sum | awk '{print $1}')
	if [[ "${type}" == "vlesstcp" ]]; then
		local VLESSID
		VLESSID=${id//\"/}
		local VLESSEmail
		VLESSEmail=$(echo "${ps}" | awk -F "[\"]" '{print $2}')

		if [[ "${coreInstallType}" == "1" ]]; then
			echoContent yellow " ---> 通用格式(VLESS+TCP+TLS/xtls-rprx-direct)"
			echoContent green "    vless://${VLESSID}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&flow=xtls-rprx-direct#${VLESSEmail}\n"

			echoContent yellow " ---> 格式化明文(VLESS+TCP+TLS/xtls-rprx-direct)"
			echoContent green "协议类型：VLESS，地址：${host}，端口：${port}，用户ID：${VLESSID}，安全：xtls，传输方式：tcp，flow：xtls-rprx-direct，账户名:${VLESSEmail}\n"
			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${VLESSID}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&flow=xtls-rprx-direct#${VLESSEmail}
EOF
			echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS/xtls-rprx-direct)"
			echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${VLESSID}%40${host}%3A${port}%3F${encryption}%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26flow%3Dxtls-rprx-direct%23${VLESSEmail}\n"

			echoContent skyBlue "----------------------------------------------------------------------------------"

			echoContent yellow " ---> 通用格式(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    vless://${VLESSID}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&flow=xtls-rprx-splice#${VLESSEmail}\n"

			echoContent yellow " ---> 格式化明文(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    协议类型：VLESS，地址：${host}，端口：${port}，用户ID：${VLESSID}，安全：xtls，传输方式：tcp，flow：xtls-rprx-splice，账户名:${VLESSEmail}\n"
			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${VLESSID}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&flow=xtls-rprx-splice#${VLESSEmail}
EOF
			echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${VLESSID}%40${host}%3A${port}%3F${encryption}%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26flow%3Dxtls-rprx-splice%23${VLESSEmail}\n"

		elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
			echoContent yellow " ---> 通用格式(VLESS+TCP+TLS)"
			echoContent green "    vless://${VLESSID}@${host}:${port}?security=tls&encryption=none&host=${host}&headerType=none&type=tcp#${VLESSEmail}\n"

			echoContent yellow " ---> 格式化明文(VLESS+TCP+TLS/xtls-rprx-splice)"
			echoContent green "    协议类型：VLESS，地址：${host}，端口：${port}，用户ID：${VLESSID}，安全：tls，传输方式：tcp，账户名:${VLESSEmail}\n"

			cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${VLESSID}@${host}:${port}?security=tls&encryption=none&host=${host}&headerType=none&type=tcp#${VLESSEmail}
EOF
			echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS)"
			echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3a%2f%2f${VLESSID}%40${host}%3a${port}%3fsecurity%3dtls%26encryption%3dnone%26host%3d${host}%26headerType%3dnone%26type%3dtcp%23${VLESSEmail}\n"
		fi

	elif [[ "${type}" == "vmessws" ]]; then

		qrCodeBase64Default=$(echo -n '{"port":"'${port}'","ps":'${ps}',"tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"none","path":"/'${path}'","net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}' | sed 's#/#\\\/#g' | base64)
		qrCodeBase64Default=$(echo ${qrCodeBase64Default} | sed 's/ //g')

		echoContent yellow " ---> 通用json(VMess+WS+TLS)"
		echoContent green '    {"port":"'${port}'","ps":'${ps}',"tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"none","path":"/'${path}'","net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}\n'
		echoContent yellow " ---> 通用vmess(VMess+WS+TLS)链接"
		echoContent green "    vmess://${qrCodeBase64Default}\n"
		echoContent yellow " ---> 二维码 vmess(VMess+WS+TLS)"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vmess://${qrCodeBase64Default}
EOF
		echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

	elif [[ "${type}" == "vmesstcp" ]]; then

		qrCodeBase64Default=$(echo -n '{"port":"'${port}'","ps":'${ps}',"tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"http","path":"/'${path}'","net":"tcp","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'","obfs":"http","obfsParam":"'${host}'"}' | sed 's#/#\\\/#g' | base64)
		qrCodeBase64Default=$(echo ${qrCodeBase64Default} | sed 's/ //g')

		echoContent yellow " ---> 通用json(VMess+TCP+TLS)"
		echoContent green '    {"port":"'${port}'","ps":'${ps}',"tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"http","path":"/'${path}'","net":"tcp","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'","obfs":"http","obfsParam":"'${host}'"}\n'
		echoContent yellow " ---> 通用vmess(VMess+TCP+TLS)链接"
		echoContent green "    vmess://${qrCodeBase64Default}\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vmess://${qrCodeBase64Default}
EOF
		echoContent yellow " ---> 二维码 vmess(VMess+TCP+TLS)"
		echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

	elif [[ "${type}" == "vlessws" ]]; then
		local VLESSID
		VLESSID=$(echo "${id}" | awk -F "[\"]" '{print $2}')
		local VLESSEmail
		VLESSEmail=$(echo "${ps}" | awk -F "[\"]" '{print $2}')

		echoContent yellow " ---> 通用格式(VLESS+WS+TLS)"
		echoContent green "    vless://${VLESSID}@${add}:${port}?encryption=none&security=tls&type=ws&host=${host}&path=%2f${path}#${VLESSEmail}\n"

		echoContent yellow " ---> 格式化明文(VLESS+WS+TLS)"
		echoContent green "    协议类型：VLESS，地址：${add}，伪装域名/SNI：${host}，端口：${port}，用户ID：${VLESSID}，安全：tls，传输方式：ws，路径:/${path}，账户名:${VLESSEmail}\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
vless://${VLESSID}@${add}:${port}?encryption=none&security=tls&type=ws&host=${host}&path=%2f${path}#${VLESSEmail}
EOF

		echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS/XTLS)"
		echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${VLESSID}%40${add}%3A${port}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dws%26host%3D${host}%26path%3D%252f${path}%23${VLESSEmail}"

	elif [[ "${type}" == "trojan" ]]; then
		# URLEncode
		echoContent yellow " ---> Trojan(TLS)"
		echoContent green "    trojan://${id}@${host}:${port}?peer=${host}&sni=${host}\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${host}:${port}?peer=${host}&sni=${host}#${host}_trojan
EOF
		echoContent yellow " ---> 二维码 Trojan(TLS)"
		echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${host}%3a${port}%3fpeer%3d${host}%26sni%3d${host}%23${host}_trojan\n"

	elif [[ "${type}" == "trojangows" ]]; then
		# URLEncode
		echoContent yellow " ---> Trojan-Go(WS+TLS) Shadowrocket"
		echoContent green "    trojan://${id}@${add}:${port}?allowInsecure=0&&peer=${host}&sni=${host}&plugin=obfs-local;obfs=websocket;obfs-host=${host};obfs-uri=${path}#${host}_trojan_ws\n"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan://${id}@${add}:${port}?allowInsecure=0&&peer=${host}&sni=${host}&plugin=obfs-local;obfs=websocket;obfs-host=${host};obfs-uri=${path}#${host}_trojan_ws
EOF
		echoContent yellow " ---> 二维码 Trojan-Go(WS+TLS) Shadowrocket"
		echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${add}%3a${port}%3fallowInsecure%3d0%26peer%3d${host}%26plugin%3dobfs-local%3bobfs%3dwebsocket%3bobfs-host%3d${host}%3bobfs-uri%3d${path}%23${host}_trojan_ws\n"

		path=$(echo "${path}" | awk -F "[/]" '{print $2}')
		echoContent yellow " ---> Trojan-Go(WS+TLS) QV2ray"

		cat <<EOF >>"/etc/v2ray-agent/subscribe_tmp/${subAccount}"
trojan-go://${id}@${add}:${port}?sni=${host}&type=ws&host=${host}&path=%2F${path}#${host}_trojan_ws
EOF

		echoContent green "    trojan-go://${id}@${add}:${port}?sni=${host}&type=ws&host=${host}&path=%2F${path}#${host}_trojan_ws\n"
	fi
}
# 账号
showAccounts() {
	readInstallType
	readConfigHostPathUUID
	readInstallProtocolType
	echoContent skyBlue "\n进度 $1/${totalProgress} : 账号"
	local show
	# VLESS TCP
	if [[ -n "${configPath}" ]]; then
		show=1
		if echo "${currentInstallProtocolType}" | grep -q 0 || [[ -z "${currentInstallProtocolType}" ]]; then
			echoContent skyBlue "===================== VLESS TCP TLS/XTLS-direct/XTLS-splice ======================\n"
			# cat ${configPath}02_VLESS_TCP_inbounds.json | jq .inbounds[0].settings.clients | jq -c '.[]'
			jq .inbounds[0].settings.clients ${configPath}02_VLESS_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
				defaultBase64Code vlesstcp $(echo "${user}" | jq .email) $(echo "${user}" | jq .id) "${currentHost}:${currentPort}" ${currentHost}
			done
		fi

		# VLESS WS
		if echo ${currentInstallProtocolType} | grep -q 1 || [[ -z "${currentInstallProtocolType}" ]]; then
			echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================\n"

			# cat ${configPath}03_VLESS_WS_inbounds.json | jq .inbounds[0].settings.clients | jq -c '.[]'
			jq .inbounds[0].settings.clients ${configPath}03_VLESS_WS_inbounds.json | jq -c '.[]' | while read -r user; do
				defaultBase64Code vlessws $(echo "${user}" | jq .email) $(echo "${user}" | jq .id) "${currentHost}:${currentPort}" "${currentPath}ws" ${currentAdd}
			done
		fi

		# VMess TCP
		if echo ${currentInstallProtocolType} | grep -q 2 || [[ -z "${currentInstallProtocolType}" ]]; then
			echoContent skyBlue "\n================================= VMess TCP TLS  =================================\n"

			# cat ${configPath}04_VMess_TCP_inbounds.json | jq .inbounds[0].settings.clients | jq -c '.[]'
			jq .inbounds[0].settings.clients ${configPath}04_VMess_TCP_inbounds.json | jq -c '.[]' | while read -r user; do
				defaultBase64Code vmesstcp $(echo "${user}" | jq .email) $(echo "${user}" | jq .id) "${currentHost}:${currentPort}" "${currentPath}tcp" "${currentHost}"
			done
		fi

		# VMess WS
		if echo ${currentInstallProtocolType} | grep -q 3 || [[ -z "${currentInstallProtocolType}" ]]; then
			echoContent skyBlue "\n================================ VMess WS TLS CDN ================================\n"
			# cat ${configPath}05_VMess_WS_inbounds.json | jq .inbounds[0].settings.clients | jq -c '.[]'
			jq .inbounds[0].settings.clients ${configPath}05_VMess_WS_inbounds.json | jq -c '.[]' | while read -r user; do
				defaultBase64Code vmessws $(echo "${user}" | jq .email) $(echo "${user}" | jq .id) "${currentHost}:${currentPort}" "${currentPath}vws" ${currentAdd}
			done
		fi
	fi

	# trojan-go
	if [[ -d "/etc/v2ray-agent/" ]] && [[ -d "/etc/v2ray-agent/trojan/" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]; then
		show=1
		# local trojanUUID=`cat /etc/v2ray-agent/trojan/config_full.json |jq .password[0]|awk -F '["]' '{print $2}'`
		local trojanGoPath
		trojanGoPath=$(jq .websocket.path /etc/v2ray-agent/trojan/config_full.json | awk -F '["]' '{print $2}')
		local trojanGoAdd
		trojanGoAdd=$(jq .websocket.add /etc/v2ray-agent/trojan/config_full.json | awk -F '["]' '{print $2}')
		echoContent skyBlue "\n==================================  Trojan TLS  ==================================\n"
		# cat /etc/v2ray-agent/trojan/config_full.json | jq .password
		jq .password /etc/v2ray-agent/trojan/config_full.json | while read -r user; do
			trojanUUID=$(echo "${user}" | awk -F '["]' '{print $2}')
			if [[ -n "${trojanUUID}" ]]; then
				defaultBase64Code trojan trojan ${trojanUUID} ${currentHost}
			fi
		done

		echoContent skyBlue "\n================================  Trojan WS TLS   ================================\n"
		if [[ -z ${trojanGoAdd} ]]; then
			trojanGoAdd=${currentHost}
		fi

		jq .password /etc/v2ray-agent/trojan/config_full.json | while read -r user; do
			trojanUUID=$(echo ${user} | awk -F '["]' '{print $2}')
			if [[ -n "${trojanUUID}" ]]; then
				defaultBase64Code trojangows trojan ${trojanUUID} ${currentHost} ${trojanGoPath} ${trojanGoAdd}
			fi

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
	echoContent yellow "1.数据统计模版"
	echoContent yellow "2.下雪动画用户注册登录模版"
	echoContent yellow "3.物流大数据服务平台模版"
	echoContent yellow "4.植物花卉模版"
	echoContent yellow "5.解锁加密的音乐文件模版[https://github.com/ix64/unlock-music]"
	echoContent yellow "6.mikutap[https://github.com/HFIProgramming/mikutap]"
	echoContent red "=============================================================="
	read -r -p "请选择：" selectInstallNginxBlogType

	if [[ "${selectInstallNginxBlogType}" =~ ^[1-6]$ ]]; then
		rm -rf /usr/share/nginx/html

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

# 卸载脚本
unInstall() {
	read -r -p "是否确认卸载安装内容？[y/n]:" unInstallStatus
	if [[ "${unInstallStatus}" != "y" ]]; then
		echoContent green " ---> 放弃卸载"
		menu
		exit
	fi

	handleNginx stop
	if [[ -z $(pgrep -f "nginx") ]]; then
		echoContent green " ---> 停止Nginx成功"
	fi

	handleV2Ray stop
	handleTrojanGo stop
	rm -rf /etc/systemd/system/v2ray.service
	echoContent green " ---> 删除V2Ray开机自启完成"
	rm -rf /etc/systemd/system/trojan-go.service
	echoContent green " ---> 删除Trojan-Go开机自启完成"
	rm -rf /tmp/v2ray-agent-tls/*
	if [[ -d "/etc/v2ray-agent/tls" ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.key") ]] && [[ -n $(find /etc/v2ray-agent/tls/ -name "*.crt") ]]; then
		mv /etc/v2ray-agent/tls /tmp/v2ray-agent-tls
		if [[ -n $(find /tmp/v2ray-agent-tls -name '*.key') ]]; then
			echoContent yellow " ---> 备份证书成功，请注意留存。[/tmp/v2ray-agent-tls]"
		fi
	fi

	rm -rf /etc/v2ray-agent
	rm -rf /etc/nginx/conf.d/alone.conf
	rm -rf /usr/bin/vasma
	rm -rf /usr/sbin/vasma
	echoContent green " ---> 卸载快捷方式完成"
	echoContent green " ---> 卸载v2ray-agent完成"
}

# 修改V2Ray CDN节点
updateV2RayCDN() {

	# todo 重构此方法
	echoContent skyBlue "\n进度 $1/${totalProgress} : 修改CDN节点"

	if [[ -n ${currentAdd} ]]; then
		echoContent red "=============================================================="
		echoContent yellow "1.CNAME www.digitalocean.com"
		echoContent yellow "2.CNAME amp.cloudflare.com"
		echoContent yellow "3.CNAME domain08.qiu4.ml"
		echoContent yellow "4.手动输入"
		echoContent red "=============================================================="
		read -r -p "请选择:" selectCDNType
		case ${selectCDNType} in
		1)
			setDomain="www.digitalocean.com"
			;;
		2)
			setDomain="amp.cloudflare.com"
			;;
		3)
			setDomain="domain08.qiu4.ml"
			;;
		4)
			read -r -p "请输入想要自定义CDN IP或者域名:" setDomain
			;;
		esac

		if [[ -n ${setDomain} ]]; then
			if [[ -n ${currentAdd} ]]; then
				sed -i "s/\"${currentAdd}\"/\"${setDomain}\"/g" $(grep "${currentAdd}" -rl ${configPath}02_VLESS_TCP_inbounds.json)
			fi
			# if [[ $(grep <./02_VLESS_TCP_inbounds.json add | awk -F '["]' '{print $4}') == "${setDomain}" ]]
			if [[ $(grep <${configPath}02_VLESS_TCP_inbounds.json add | awk -F '["]' '{print $4}') == "${setDomain}" ]]; then
				echoContent green " ---> CDN修改成功"
				if [[ "${coreInstallType}" == "1" ]]; then
					handleXray stop
					handleXray start
				elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
					handleV2Ray stop
					handleV2Ray start
				fi

			else
				echoContent red " ---> 修改CDN失败"
			fi

			# trojan
			if [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]; then
				add=$(jq .websocket.add /etc/v2ray-agent/trojan/config_full.json | awk -F '["]' '{print $2}')
				if [[ -n ${add} ]]; then
					sed -i "s/${add}/${setDomain}/g" $(grep "${add}" -rl /etc/v2ray-agent/trojan/config_full.json)
				fi
			fi

			if [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]] && [[ $(jq .websocket.add /etc/v2ray-agent/trojan/config_full.json | awk -F '["]' '{print $2}') == ${setDomain} ]]; then
				echoContent green "\n ---> Trojan CDN修改成功"
				handleTrojanGo stop
				handleTrojanGo start
			elif [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]; then
				echoContent red " ---> 修改Trojan CDN失败"
			fi
		fi
	else
		echoContent red " ---> 未安装可用类型"
	fi
	menu
}

# manageUser 用户管理
manageUser() {
	echoContent skyBlue "\n进度 $1/${totalProgress} : 多用户管理"
	echoContent skyBlue "-----------------------------------------------------"
	echoContent yellow "1.添加用户"
	echoContent yellow "2.删除用户"
	echoContent skyBlue "-----------------------------------------------------"
	read -r -p "请选择：" manageUserType
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
			local repeat=
			jq '.inbounds[0].settings.clients[].id' ${configPath}02_VLESS_TCP_inbounds.json | awk -F "[\"]" '{print $2}' | while read -r line; do
				if [[ "${line}" == "${currentCustomUUID}" ]]; then
					echo repeat >/tmp/v2ray-agent
				fi
			done
			if [[ -f "/tmp/v2ray-agent" && -n $(cat /tmp/v2ray-agent) ]]; then
				echoContent red " ---> UUID不可重复"
				rm /tmp/v2ray-agent
				exit
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
			local repeat=
			jq '.inbounds[0].settings.clients[].email' ${configPath}02_VLESS_TCP_inbounds.json | awk -F "[\"]" '{print $2}' | while read -r line; do
				if [[ "${line}" == "${currentCustomEmail}" ]]; then
					echo repeat >/tmp/v2ray-agent
				fi
			done
			if [[ -f "/tmp/v2ray-agent" && -n $(cat /tmp/v2ray-agent) ]]; then
				echoContent red " ---> email不可重复"
				rm /tmp/v2ray-agent
				exit
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
		exit
	fi

	# 生成用户
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

			users=${users}{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-direct\",\"email\":\"${email}\",\"alterId\":1}

			if echo ${currentInstallProtocolType} | grep -q 4; then
				trojanGoUsers=${trojanGoUsers}\"${uuid}\"
			fi
		else
			users=${users}{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-direct\",\"email\":\"${email}\",\"alterId\":1},

			if echo ${currentInstallProtocolType} | grep -q 4; then
				trojanGoUsers=${trojanGoUsers}\"${uuid}\",
			fi
		fi
	done

	#	兼容v2ray-core
	if [[ "${coreInstallType}" == "2" ]]; then
		#  | sed 's/"flow":"xtls-rprx-direct",/"alterId":1,/g')
		users="${users//\"flow\":\"xtls-rprx-direct\"\,/}"
	fi

	if [[ -n $(echo ${currentInstallProtocolType} | grep 0) ]]; then
		local vlessUsers="${users//\,\"alterId\":1/}"

		local vlessTcpResult
		vlessTcpResult=$(jq -r '.inbounds[0].settings.clients += ['${vlessUsers}']' ${configPath}02_VLESS_TCP_inbounds.json)
		echo "${vlessTcpResult}" | jq . >${configPath}02_VLESS_TCP_inbounds.json
	fi

	#	users="${users//"flow":"xtls-rprx-direct",/"alterId":1,}"

	if echo ${currentInstallProtocolType} | grep -q 1; then
		local vlessUsers="${users//\,\"alterId\":1/}"
		vlessUsers="${vlessUsers//\"flow\":\"xtls-rprx-direct\"\,/}"
		local vlessWsResult
		vlessWsResult=$(jq -r '.inbounds[0].settings.clients += ['${vlessUsers}']' ${configPath}03_VLESS_WS_inbounds.json)
		echo "${vlessWsResult}" | jq . >${configPath}03_VLESS_WS_inbounds.json
	fi

	if echo ${currentInstallProtocolType} | grep -q 2; then
		local vmessUsers="${users//\"flow\":\"xtls-rprx-direct\"\,/}"

		local vmessTcpResult
		vmessTcpResult=$(jq -r '.inbounds[0].settings.clients += ['${vmessUsers}']' ${configPath}04_VMess_TCP_inbounds.json)
		echo "${vmessTcpResult}" | jq . >${configPath}04_VMess_TCP_inbounds.json
	fi

	if echo ${currentInstallProtocolType} | grep -q 3; then
		local vmessUsers="${users//\"flow\":\"xtls-rprx-direct\"\,/}"

		local vmessWsResult
		vmessWsResult=$(jq -r '.inbounds[0].settings.clients += ['${vmessUsers}']' ${configPath}05_VMess_WS_inbounds.json)
		echo "${vmessWsResult}" | jq . >${configPath}05_VMess_WS_inbounds.json
	fi

	if echo ${currentInstallProtocolType} | grep -q 4; then
		local trojanResult
		trojanResult=$(jq -r '.password += ['${trojanGoUsers}']' ${configPath}../../trojan/config_full.json)
		echo "${trojanResult}" | jq . >${configPath}../../trojan/config_full.json
		handleTrojanGo stop
		handleTrojanGo start
	fi

	if [[ "${coreInstallType}" == "1" ]]; then
		handleXray stop
		handleXray start
	elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
		handleV2Ray stop
		handleV2Ray start
	fi
	echoContent green " ---> 添加完成"
	showAccounts 1
}

# 移除用户
removeUser() {

	if echo ${currentInstallProtocolType} | grep -q 0; then
		jq .inbounds[0].settings.clients[].email ${configPath}02_VLESS_TCP_inbounds.json | awk -F "[\"]" '{print $2}' | awk '{print NR""":"$0}'
		read -r -p "请选择要删除的用户编号[仅支持单个删除]:" delUserIndex
		if [[ $(jq -r '.inbounds[0].settings.clients|length' ${configPath}02_VLESS_TCP_inbounds.json) -lt ${delUserIndex} ]]; then
			echoContent red " ---> 选择错误"
		else
			delUserIndex=$((${delUserIndex} - 1))
			local vlessTcpResult
			vlessTcpResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}02_VLESS_TCP_inbounds.json)
			echo "${vlessTcpResult}" | jq . >${configPath}02_VLESS_TCP_inbounds.json
		fi
	fi
	if [[ -n "${delUserIndex}" ]]; then
		if echo ${currentInstallProtocolType} | grep -q 1; then
			local vlessWSResult
			vlessWSResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}03_VLESS_WS_inbounds.json)
			echo "${vlessWSResult}" | jq . >${configPath}03_VLESS_WS_inbounds.json
		fi

		if echo ${currentInstallProtocolType} | grep -q 2; then
			local vmessTCPResult
			vmessTCPResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}04_VMess_TCP_inbounds.json)
			echo "${vmessTCPResult}" | jq . >${configPath}04_VMess_TCP_inbounds.json
		fi

		if echo ${currentInstallProtocolType} | grep -q 3; then
			local vmessWSResult
			vmessWSResult=$(jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])' ${configPath}05_VMess_WS_inbounds.json)
			echo "${vmessWSResult}" | jq . >${configPath}05_VMess_WS_inbounds.json
		fi

		if echo ${currentInstallProtocolType} | grep -q 4; then
			local trojanResult
			trojanResult=$(jq -r 'del(.password['${delUserIndex}'])' ${configPath}../../trojan/config_full.json)
			echo "${trojanResult}" | jq . >${configPath}../../trojan/config_full.json
			handleTrojanGo stop
			handleTrojanGo start
		fi
		if [[ "${coreInstallType}" == "1" ]]; then
			handleXray stop
			handleXray start
		elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
			handleV2Ray stop
			handleV2Ray start
		fi
	fi
}
# 更新脚本
updateV2RayAgent() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : 更新v2ray-agent脚本"
	if wget --help | grep -q show-progress; then
		wget -c -q --show-progress -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
	else
		wget -c -q -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh"
	fi

	sudo chmod 700 /etc/v2ray-agent/install.sh
	local version=$(cat /etc/v2ray-agent/install.sh | grep '当前版本：v' | awk -F "[v]" '{print $2}' | tail -n +2 | head -n 1 | awk -F "[\"]" '{print $1}')

	echoContent green "\n ---> 更新完毕"
	echoContent yellow " ---> 请手动执行[vasma]打开脚本"
	echoContent green " ---> 当前版本:${version}\n"
	exit 0
}

# 安装BBR
bbrInstall() {
	echoContent red "\n=============================================================="
	echoContent green "BBR脚本用的[ylx2016]的成熟作品，地址[https://github.com/ylx2016/Linux-NetSpeed]，请熟知"
	echoContent yellow "1.安装【推荐原版BBR+FQ】"
	echoContent yellow "2.回退主目录"
	echoContent red "=============================================================="
	read -r -p "请选择：" installBBRStatus
	if [[ "${installBBRStatus}" == "1" ]]; then
		wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
	else
		menu
	fi
}

# 查看、检查日志
checkLog() {
	echoContent skyBlue "\n功能 $1/${totalProgress} : 查看日志"
	echoContent red "\n=============================================================="
	local coreType=
	if [[ "${coreInstallType}" == "1" ]]; then
		coreType=xray/xray

	elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
		coreType=v2ray/v2ray
	else
		echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
		menu
		exit 0
	fi

	echoContent skyBlue "-------------------------V2Ray/Xray--------------------------------"
	echoContent yellow "1.查看error日志"
	echoContent yellow "2.监听error日志"
	echoContent yellow "3.清空日志"
	echoContent skyBlue "-----------------------Trojan-Go------------------------------"
	echoContent yellow "4.查看Trojan-Go日志"
	echoContent yellow "5.监听Trojan-GO日志"
	echoContent yellow "6.清空Trojan-GO日志"
	echoContent skyBlue "-------------------------Nginx--------------------------------"
	echoContent yellow "7.查看Nginx日志"
	echoContent yellow "8.清空Nginx日志"
	echoContent red "=============================================================="

	read -r -p "请选择：" selectLogType
	case ${selectLogType} in
	1)
		cat /etc/v2ray-agent/xray/xray_error.log
		;;
	2)
		tail -f /etc/v2ray-agent/xray/xray_error.log
		;;
	3)
		echo '' >/etc/v2ray-agent/xray/xray_error.log
		echoContent green " ---> 清空完毕"
		;;
	4)
		cat /etc/v2ray-agent/trojan/trojan.log
		;;
	5)
		tail -f /etc/v2ray-agent/trojan/trojan.log
		;;
	6)
		echo '' >/etc/v2ray-agent/trojan/trojan.log
		echoContent green " ---> 清空完毕"
		;;
	7)
		cat /var/log/nginx/access.log
		;;
	8)
		echo '' >/var/log/nginx/access.log
		;;
	esac
	sleep 1
	menu
}

# 脚本快捷方式
aliasInstall() {

	if [[ -f "$HOME/install.sh" ]] && [[ -d "/etc/v2ray-agent" ]] && grep <$HOME/install.sh -q "作者：mack-a"; then
		mv "$HOME/install.sh" /etc/v2ray-agent/install.sh
		if [[ -d "/usr/bin/" ]] && [[ ! -f "/usr/bin/vasma" ]]; then
			ln -s /etc/v2ray-agent/install.sh /usr/bin/vasma
			chmod 700 /usr/bin/vasma
			rm -rf "$HOME/install.sh"
		elif [[ -d "/usr/sbin" ]] && [[ ! -f "/usr/sbin/vasma" ]]; then
			ln -s /etc/v2ray-agent/install.sh /usr/sbin/vasma
			chmod 700 /usr/sbin/vasma
			rm -rf "$HOME/install.sh"
		fi
		echoContent green "快捷方式创建成功，可执行[vasma]重新打开脚本"
	fi
}

# 检查ipv6、ipv4
checkIPv6() {
	pingIPv6=$(ping6 -c 1 www.google.com | sed '2{s/[^(]*(//;s/).*//;q;}' | tail -n +2)
	if [[ -z "${pingIPv6}" ]]; then
		echoContent red " ---> 不支持ipv6"
		exit
	fi
}

# ipv6 人机验证
ipv6HumanVerification() {
	if [[ -z "${configPath}" ]]; then
		echoContent red " ---> 未安装，请使用脚本安装"
		menu
		exit
	fi

	checkIPv6
	echoContent skyBlue "\n功能 1/${totalProgress} : ipv6人机验证"
	echoContent red "\n=============================================================="
	echoContent yellow "1.添加"
	echoContent yellow "2.卸载"
	read -r -p "请选择:" ipv6Status
	if [[ "${ipv6Status}" == "1" ]]; then
		cat <<EOF >${configPath}09_routing.json
{
    "routing":{
        "domainStrategy": "IPOnDemand",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          },
          {
            "type": "field",
            "domain": [
              "domain:google.com",
              "domain:google.com.hk"
            ],
            "outboundTag": "IP6-out"
          }
        ]
  }
}
EOF

		cat <<EOF >${configPath}10_ipv4_outbounds.json
{
  "outbounds": [
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
      "tag": "IP6-out"
    }
  ]
}
EOF
		echoContent green " ---> 人机验证修改成功"

	elif [[ "${ipv6Status}" == "2" ]]; then
		cat <<EOF >${configPath}09_routing.json
{
    "routing":{
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          }
        ]
  }
}
EOF

		cat <<EOF >${configPath}10_ipv4_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {
            "domainStrategy": "UseIPv4"
          },
          "tag": "IPv4-out"
        }
    ]
}
EOF
		echoContent green " ---> 人机验证卸载成功"
	else
		echoContent red " ---> 选择错误"
		ipv6HumanVerification
		exit
	fi

	if [[ "${coreInstallType}" == "1" ]]; then
		handleXray stop
		handleXray start

	elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
		handleV2Ray stop
		handleV2Ray start
	fi
}

# 流媒体工具箱
streamingToolbox() {
	echoContent skyBlue "\n功能 1/${totalProgress} : 流媒体工具箱"
	echoContent red "\n=============================================================="
	echoContent yellow "1.Netflix检测"
	echoContent yellow "2.DNS解锁Netflix"
	read -r -p "请选择:" selectType

	case ${selectType} in
	1)
		checkNetflix
		;;
	2)
		dnsUnlockNetflix
		;;
	esac
}

# 检查 vps是否支持Netflix
checkNetflix() {
	echoContent red "\n注意事项"
	echoContent yellow " 1.只可检测vps是否支持Netflix"
	echoContent yellow " 2.无法检测代理配置dns解锁后是否支持Netflix"
	echoContent yellow " 3.可检测vps配置dns解锁后是否支持Netflix\n"
	echoContent skyBlue " ---> 检测中"
	netflixResult=$(curl -s -m 2 https://www.netflix.com | grep "Not Available")
	if [[ -n ${netflixResult} ]]; then
		echoContent red " ---> Netflix不可用"
		exit
	fi

	netflixResult=$(curl -s -m 2 https://www.netflix.com | grep "NSEZ-403")
	if [[ -n ${netflixResult} ]]; then
		echoContent red " ---> Netflix不可用"
		exit
	fi

	echoContent skyBlue " ---> 检测绝命毒师是否可以播放"
	result=$(curl -s -m 2 https://www.netflix.com/title/70143836 | grep "page-404")
	if [[ -n ${result} ]]; then
		echoContent green " ---> 仅可看自制剧"
		exit
	fi
	echoContent green " ---> Netflix解锁"
	exit
}

# dns解锁Netflix
dnsUnlockNetflix() {
	echoContent skyBlue "\n功能 1/${totalProgress} : DNS解锁Netflix"
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
	read -r -p "请输入解锁Netflix的DNS:" setDNS
	if [[ -n ${setDNS} ]]; then
		cat <<EOF >${configPath}/11_dns.json
{
	"dns": {
		"servers": [
			{
				"address": "${setDNS}",
				"port": 53,
				"domains": [
					"domain:netflix.com",
					"domain:netflix.net",
					"domain:nflximg.net",
					"domain:nflxvideo.net",
					"domain:nflxso.net",
					"domain:nflxext.com"
				]
			},
		"localhost"
		]
	}
}
EOF
		if [[ "${coreInstallType}" == "1" ]]; then
			handleXray stop
			handleXray start

		elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
			handleV2Ray stop
			handleV2Ray start
		fi
		echoContent green "\n ---> DNS解锁添加成功，该设置对Trojan-Go无效"
		echoContent yellow "\n ---> 如还无法观看可以尝试以下两种方案"
		echoContent yellow " 1.重启vps"
		echoContent yellow " 2.卸载dns解锁后，修改本地的[/etc/resolv.conf]DNS设置并重启vps\n"
	else
		echoContent red " ---> dns不可为空"
	fi
	exit
}

# 移除Netflix解锁
removeUnlockDNS() {
	cat <<EOF >${configPath}/11_dns.json
{
	"dns": {
		"servers": [
			"localhost"
		]
	}
}
EOF
	if [[ "${coreInstallType}" == "1" ]]; then
		handleXray stop
		handleXray start

	elif [[ "${coreInstallType}" == "2" || "${coreInstallType}" == "3" ]]; then
		handleV2Ray stop
		handleV2Ray start
	fi

	echoContent green " ---> 卸载成功"

	exit
}
# v2ray-core个性化安装
customV2RayInstall() {
	echoContent skyBlue "\n========================个性化安装============================"
	echoContent yellow "VLESS前置，必须安装0，如果只需要安装0，回车即可"
	if [[ "${selectCoreType}" == "2" ]]; then
		echoContent yellow "0.VLESS+TLS+TCP"
	else
		echoContent yellow "0.VLESS+TLS/XTLS+TCP"
	fi

	echoContent yellow "1.VLESS+TLS+WS[CDN]"
	echoContent yellow "2.VMess+TLS+TCP"
	echoContent yellow "3.VMess+TLS+WS[CDN]"
	echoContent yellow "4.Trojan、Trojan+WS[CDN]"
	read -r -p "请选择[多选]，[例如:123]:" selectCustomInstallType
	echoContent skyBlue "--------------------------------------------------------------"
	if [[ -z ${selectCustomInstallType} ]]; then
		selectCustomInstallType=0
	fi
	if [[ "${selectCustomInstallType}" =~ ^[0-4]+$ ]]; then
		cleanUp xrayClean
		totalProgress=17
		installTools 1
		# 申请tls
		initTLSNginxConfig 2
		installTLS 3
		handleNginx stop
		initNginxConfig 4
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
		if echo ${selectCustomInstallType} | grep -q 4; then
			installTrojanGo 11
			installTrojanService 12
			initTrojanGoConfig 13
			handleTrojanGo stop
			handleTrojanGo start
		else
			# 这里需要删除trojan的服务
			handleTrojanGo stop
			rm -rf /etc/v2ray-agent/trojan/*
			rm -rf /etc/systemd/system/trojan-go.service
		fi
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
	echoContent yellow "2.VMess+TLS+TCP"
	echoContent yellow "3.VMess+TLS+WS[CDN]"
	echoContent yellow "4.Trojan、Trojan+WS[CDN]"
	read -r -p "请选择[多选]，[例如:123]:" selectCustomInstallType
	echoContent skyBlue "--------------------------------------------------------------"
	if [[ -z ${selectCustomInstallType} ]]; then
		echoContent red " ---> 不可为空"
		customXrayInstall
	elif [[ "${selectCustomInstallType}" =~ ^[0-4]+$ ]]; then
		cleanUp v2rayClean
		totalProgress=17
		installTools 1
		# 申请tls
		initTLSNginxConfig 2
		installTLS 3
		handleNginx stop
		initNginxConfig 4
		# 随机path
		if echo "${selectCustomInstallType}" | grep -q 1 || echo "${selectCustomInstallType}" | grep -q 3 || echo "${selectCustomInstallType}" | grep -q 4; then
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
		if echo "${selectCustomInstallType}" | grep -q 4; then
			installTrojanGo 11
			installTrojanService 12
			initTrojanGoConfig 13
			handleTrojanGo stop
			handleTrojanGo start
		else
			# 这里需要删除trojan的服务
			handleTrojanGo stop
			rm -rf /etc/v2ray-agent/trojan/*
			rm -rf /etc/systemd/system/trojan-go.service
		fi
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

# 选择核心安装---v2ray-core、xray-core、锁定版本的v2ray-core[xtls]
selectCoreInstall() {
	echoContent skyBlue "\n功能 1/${totalProgress} : 选择核心安装"
	echoContent red "\n=============================================================="
	echoContent yellow "1.Xray-core"
	echoContent yellow "2.v2ray-core"
	echoContent yellow "3.v2ray-core[XTLS]"
	echoContent red "=============================================================="
	read -r -p "请选择：" selectCoreType
	case ${selectCoreType} in
	"1")
		if [[ "${selectInstallType}" == "2" ]]; then
			customXrayInstall
		else
			xrayCoreInstall
		fi
		;;
	"2")
		v2rayCoreVersion=
		if [[ "${selectInstallType}" == "2" ]]; then
			customV2RayInstall
		else
			v2rayCoreInstall
		fi
		;;
	"3")
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
	totalProgress=17
	installTools 2
	# 申请tls
	initTLSNginxConfig 3
	installTLS 4
	handleNginx stop
	initNginxConfig 5
	randomPathFunction 6
	# 安装V2Ray
	installV2Ray 7
	installV2RayService 8
	installTrojanGo 9
	installTrojanService 10
	customCDNIP 11
	initV2RayConfig all 12
	cleanUp xrayDel
	initTrojanGoConfig 13
	installCronTLS 14
	nginxBlog 15
	updateRedirectNginxConf
	handleV2Ray stop
	sleep 2
	handleV2Ray start
	handleNginx start
	handleTrojanGo stop
	sleep 1
	handleTrojanGo start
	# 生成账号
	checkGFWStatue 16
	showAccounts 17
}

# xray-core 安装
xrayCoreInstall() {
	cleanUp v2rayClean
	selectCustomInstallType=

	totalProgress=17
	installTools 2
	# 申请tls
	initTLSNginxConfig 3
	installTLS 4
	handleNginx stop
	initNginxConfig 5
	randomPathFunction 6
	# 安装Xray
	handleV2Ray stop
	installXray 7
	installXrayService 8
	installTrojanGo 9
	installTrojanService 10
	customCDNIP 11
	initXrayConfig all 12
	cleanUp v2rayDel
	initTrojanGoConfig 13
	#    installCronTLS 14
	nginxBlog 15
	updateRedirectNginxConf
	handleXray stop
	sleep 2
	handleXray start

	handleNginx start
	handleTrojanGo stop
	sleep 1
	handleTrojanGo start
	# 生成账号
	checkGFWStatue 16
	showAccounts 17
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
		echoContent skyBlue "-------------------------备注----------------------------------"
		echoContent yellow "# 查看订阅时会重新生成订阅"
		echoContent yellow "# 每次添加、删除账号需要重新查看订阅"
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
				echoContent yellow "在线二维码：https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://${currentHost}/s/${email}\n"
				echo "https://${currentHost}/s/${email}" | qrencode -s 10 -m 1 -t UTF8
				echoContent skyBlue "--------------------------------------------------------------"
			done
		fi
	else
		echoContent red " ---> 未安装"
	fi
}

# 主菜单
menu() {
	cd "$HOME" || exit
	echoContent red "\n=============================================================="
	echoContent green "作者：mack-a"
	echoContent green "当前版本：v2.3.21"
	echoContent green "Github：https://github.com/mack-a/v2ray-agent"
	echoContent green "描述：七合一共存脚本"
	echoContent red "=============================================================="
	echoContent yellow "1.安装"
	echoContent yellow "2.任意组合安装"
	echoContent skyBlue "-------------------------工具管理-----------------------------"
	echoContent yellow "3.账号管理"
	echoContent yellow "4.更换伪装站"
	echoContent yellow "5.更新证书"
	echoContent yellow "6.更换CDN节点"
	echoContent yellow "7.ipv6人机验证"
	echoContent yellow "8.流媒体工具"
	echoContent skyBlue "-------------------------版本管理-----------------------------"
	echoContent yellow "9.core版本管理"
	echoContent yellow "10.更新Trojan-Go"
	echoContent yellow "11.更新脚本"
	echoContent yellow "12.安装BBR、DD脚本"
	echoContent skyBlue "-------------------------脚本管理-----------------------------"
	echoContent yellow "13.查看日志"
	echoContent yellow "14.卸载脚本"
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
		manageAccount 1
		;;
	4)
		updateNginxBlog 1
		;;
	5)
		renewalTLS 1
		;;
	6)
		updateV2RayCDN 1
		;;
	7)
		ipv6HumanVerification
		;;
	8)
		streamingToolbox 1
		;;
	9)
		coreVersionManageMenu 1
		;;
	10)
		updateTrojanGo 1
		;;
	11)
		updateV2RayAgent 1
		;;
	12)
		bbrInstall
		;;
	13)
		checkLog 1
		;;
	14)
		unInstall 1
		;;
	esac
}
cronRenewTLS
menu
