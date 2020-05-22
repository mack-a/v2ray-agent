#!/usr/bin/env bash
purple="\033[35m"   # 紫色
skyBlue="\033[36m"  # 天蓝色
red="\033[31m"      # 红色
green="\033[32m"    # 绿色
yellow="\e[93m"     # 黄色
magenta="\e[95m"    # 红酒色
cyan="\e[96m"       # 蓝绿色
none="\e[0m"        # 无
installType='yum -y install'
remove='yum -y remove'
upgrade="yum -y update"
echoType='echo -e'

# echo颜色方法
echoContent(){
    case $1 in
        "red")
            color=${red}
        ;;
        "skyBlue")
            color=${skyBlue}
        ;;
        "green")
            color=${green}
        ;;
        "cyan")
            color=${cyan}
        ;;
        "magenta")
            color=${magenta}
        ;;
        "skyBlue")
            color=${skyBlue}
        ;;

    esac
    ${echoType} ${color}"$2"
}

# 安装工具包
installTools(){
    # echo "export LC_ALL=en_US.UTF-8"  >>  /etc/profile
    # source /etc/profile
    echoContent skyBlue "删除Nginx、V2Ray、acme"
    if [[ ! -z `find /usr/sbin/ -name nginx` ]]
    then
        if [[ ! -z `ps -ef|grep nginx|grep -v grep`  ]]
        then
            nginx -s stop
        fi
        removeLog=`yum remove nginx -y`
    fi

    if [[ ! -z `find /usr/bin/v2ray/ -name v2ray` ]]
    then
        if [[ ! -z `ps -ef|grep v2ray|grep -v grep`  ]]
        then
            ps -ef|grep v2ray|grep -v grep|awk '{print $2}'|xargs kill -9
        fi
        rm -rf  /usr/bin/v2ray/v2ray
        rm -rf  /usr/bin/v2ray/v2ctl
    fi

    if [[ ! -z `cat /root/.bashrc|grep -n acme` ]]
    then
        acmeBashrcLine=`cat /root/.bashrc|grep -n acme|awk -F "[:]" '{print $1}'|head -1`
        echo ${acmeBashrcLine}
        sed -i "${acmeBashrcLine}d" /root/.bashrc
    fi
    rm -rf ~/.acme.sh > /dev/null
    echoContent skyBlue "删除完成"

    echoContent skyBlue "检查、安装工具包："

    echoContent skyBlue "更新中"
    ${upgrade} > /dev/null
    echoContent skyBlue "更新完毕"

    echoContent skyBlue "   检查、安装wget--->"
    progressTool wget

    echoContent skyBlue "   检查、安装unzip--->"
    progressTool unzip

    echoContent skyBlue "   检查、安装qrencode--->"
    progressTool qrencode

    echoContent skyBlue "   检查、安装socat--->"
    progressTool socat

    echoContent skyBlue "   检查、安装crontabs--->"
    progressTool crontabs

    # echoContent skyBlue "   检查、安装bind-utils--->"
    # progressTool bind-utils
    # 关闭防火墙

}
# 安装Nginx tls证书
installNginx(){
    echoContent skyBlue "检查、安装Nginx、TLS："
    echoContent skyBlue "   请输入要配置的域名 例如：worker.v2ray-agent.com --->"
    read domain
    if [[ -z ${domain} ]]
    then
        echoContent skyBlue "   域名不可为空--->"
        installNginx
    else
        # 安装nginx
        echoContent skyBlue "   检查、安装Nginx--->"
        progressTool nginx

        # 修改配置
        echoContent skyBlue "   修改配置文件--->"
        installLine=`cat /etc/nginx/nginx.conf|grep -n root|awk -F "[:]" '{print $1+1}'|head -1`
        echo ${installLine}
        sed -i "${installLine}i location ~ /.well-known {allow all;}" /etc/nginx/nginx.conf
        installLine=`expr ${installLine} + 1`
        sed -i "${installLine}i location /test {return 200 'fjkvymb6len';}" /etc/nginx/nginx.conf

        # 启动nginx
        nginx

        # 测试nginx
        echoContent skyBlue "   检查Nginx是否正常访问--->"
        # ${domain}
        domainResult=`curl -s ${domain}/test|grep fjkvymb6len`
        if [[ ! -z ${domainResult} ]]
        then
            echoContent skyBlue "   Nginx访问成功--->"
            nginx -s stop
            installTLS ${domain}
        else
            echoContent skyBlue "   无法正常访问服务器，请检查域名的DNS解析是否正确--->"
        fi
    fi
}
# 安装TLS
installTLS(){

    if [[ -z `find /tmp/tls/$1` ]] || [[ -z `cat /tmp/tls/$1.crt` ]] || [[ -z `cat /tmp/tls/$1.key` ]]
    then
        rm -rf /tmp/tls
        echoContent skyBlue "   生成TLS证书--->"
        echoContent skyBlue "   安装acme--->"
        curl -s https://get.acme.sh | sh
        echoContent skyBlue "   acme安装完毕--->"
        sudo ~/.acme.sh/acme.sh --issue -d $1 --standalone -k ec-256
        ~/.acme.sh/acme.sh --installcert -d $1 --fullchainpath /etc/nginx/$1.crt --keypath /etc/nginx/$1.key --ecc
        if [[ -z `cat /etc/nginx/$1.crt` ]]
        then
            echoContent skyBlue "   TLS安装失败，请检查acme日志--->"
            exit 0
        elif [[ -z `cat /etc/nginx/$1.key` ]]
        then
            echoContent skyBlue "   TLS安装失败，请检查acme日志--->"
            exit 0
        fi
        echoContent skyBlue "   TLS安装成功--->"
        mkdir -p /tmp/tls
        cp -R /etc/nginx/$1.crt /tmp/tls/$1.crt
        cp -R /etc/nginx/$1.key /tmp/tls/$1.key
        echoContent skyBlue "   TLS证书备份成功，证书位置：/tmp/tls--->"
    else
        echoContent skyBlue "   检测到备份证书，如需重新生成，请执行 【rm -rf /tmp/tls】，然后重新执行脚本--->"
        cp -R /tmp/tls/$1.crt /etc/nginx/$1.crt
        cp -R /tmp/tls/$1.key /etc/nginx/$1.key
    fi

    nginxInstallLine=`cat /etc/nginx/nginx.conf|grep -n "}"|awk -F "[:]" 'END{print $1-1}'`
    sed -i "${installLine}i server {listen 443 ssl;server_name $1;root /usr/share/nginx/html;ssl_certificate /etc/nginx/$1.crt;ssl_certificate_key /etc/nginx/$1.key;ssl_protocols TLSv1 TLSv1.1 TLSv1.2;ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;ssl_prefer_server_ciphers on;location / {}location /mmtest { proxy_redirect off;proxy_pass http://127.0.0.1:31299;proxy_http_version 1.1;proxy_set_header Upgrade $http_upgrade;proxy_set_header Connection "upgrade";proxy_set_header X-Real-IP $remote_addr;proxy_set_header Host $host;proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;}}" /etc/nginx/nginx.conf
    nginx
    if [[ -z `ps -ef|grep -v grep|grep nginx` ]]
    then
        echoContent skyBlue "   Nginx启动失败，请检查日志--->"
    fi
    echoContent skyBlue "   Nginx启动成功，TLS配置成功--->"
}
# V2Ray
installV2Ray(){
    if [[ -z `find /tmp/v2ray -name "v2ray"` ]]
    then
        if [[ -z `find /usr/bin/v2ray/ -name "v2ray"` ]]
        then
            echoContent skyBlue "   安装V2Ray--->"
            version=`curl -s https://github.com/v2ray/v2ray-core/releases|grep /v2ray/v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[V]" '{print $2}'|awk -F "[<]" '{print $1}'`
            wget -P /tmp/v2ray https://github.com/v2ray/v2ray-core/releases/download/v${version}/v2ray-linux-64.zip
            unzip /tmp/v2ray/v2ray-linux-64.zip -d /tmp/v2ray
            cp /tmp/v2ray/v2ray /usr/bin/v2ray/ && cp /tmp/v2ray/v2ctl /usr/bin/v2ray/
            rm -rf /tmp/v2ray/v2ray-linux-64.zip
        fi
        echoContent skyBlue "   V2Ray安装成功--->"
    else
         echoContent skyBlue "   检测到V2Ray安装程序，如需安装新版本，请执行【rm -rf /tmp/v2ray】,然后重新执行脚本--->"
         cp /tmp/v2ray/v2ray /usr/bin/v2ray/ && cp /tmp/v2ray/v2ctl /usr/bin/v2ray/
    fi
    installV2RayService
    initV2RayConfig
    systemctl enable v2ray
    systemctl start v2ray
    if [[ -z `ps -ef|grep v2ray|grep -v grep` ]]
    then
        echoContent skyBlue "   V2Ray启动失败，请检查日志后，重新执行脚本--->"
    fi
    echoContent skyBlue "   V2Ray启动成功--->"
}
# 开机自启
installV2RayService(){
    echoContent skyBlue "   配置V2Ray开机自启--->"
    touch /etc/systemd/system/v2ray.sevice

    echo 'Description=V2Ray - A unified platform for anti-censorship' >> /etc/systemd/system/v2ray.sevice
    echo 'Documentation=https://v2ray.com https://guide.v2fly.org' >> /etc/systemd/system/v2ray.sevice
    echo 'After=network.target nss-lookup.target' >> /etc/systemd/system/v2ray.sevice
    echo 'Wants=network-online.target' >> /etc/systemd/system/v2ray.sevice
    echo '' >> /etc/systemd/system/v2ray.sevice
    echo '[Service]' >> /etc/systemd/system/v2ray.sevice
    echo 'Type=simple' >> /etc/systemd/system/v2ray.sevice
    echo 'User=root' >> /etc/systemd/system/v2ray.sevice
    echo 'CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW' >> /etc/systemd/system/v2ray.sevice
    echo 'NoNewPrivileges=yes' >> /etc/systemd/system/v2ray.sevice
    echo 'ExecStart=/usr/bin/v2ray/v2ray -config /etc/v2ray/config.json' >> /etc/systemd/system/v2ray.sevice
    echo 'Restart=on-failure' >> /etc/systemd/system/v2ray.sevice
    echo 'RestartPreventExitStatus=23' >> /etc/systemd/system/v2ray.sevice
    echo '' >> /etc/systemd/system/v2ray.sevice
    echo '' >> /etc/systemd/system/v2ray.sevice
    echo '[Install]' >> /etc/systemd/system/v2ray.sevice
    echo 'WantedBy=multi-user.target' >> /etc/systemd/system/v2ray.sevice
    echoContent skyBlue "   配置V2Ray开机自启成功--->"
}
# 初始化V2Ray 配置文件
initV2RayConfig(){
    touch /etc/v2ray/config.json
    uuid=`/usr/bin/v2ray/v2ctl uuid`
    echo '{"log":{"access":"/usr/src/v2ray/v2ray_access_ws_tls.log","error":"/usr/src/v2ray/v2ray_error_ws_tls.log","loglevel":"debug"},"stats":{},"api":{"services":["StatsService"],"tag":"api"},"policy":{"levels":{"1":{"handshake":4,"connIdle":300,"uplinkOnly":2,"downlinkOnly":5,"statsUserUplink":false,"statsUserDownlink":false}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}},"allocate":{"strategy":"always","refresh":5,"concurrency":3},"inbounds":[{"port":31299,"protocol":"vmess","settings":{"clients":[{"id":"654765fe-5fb1-271f-7c3f-18ed82827f72","alterId":64,"level":1,"email":"test@v2ray.com"}]},"streamSettings":{"network":"ws","wsSettings":{"path":"/alone"}}}],"outbounds":[{"protocol":"freedom","settings":{"OutboundConfigurationObject":{"domainStrategy":"AsIs","userLevel":0}}}],"routing":{"settings":{"rules":[{"inboundTag":["api"],"outboundTag":"api","type":"field"}]},"strategy":"rules"},"dns":{"servers":["8.8.8.8","8.8.4.4"],"tag":"dns_inbound"}}' > /etc/v2ray/config.json
    sed -i "s/654765fe-5fb1-271f-7c3f-18ed82827f72/${uuid}/g" `grep 654765fe-5fb1-271f-7c3f-18ed82827f72 -rl /etc/v2ray/config.json`
}
# 查看dns解析ip
checkDNS(){
    echo '' > /tmp/pingLog
    ping -c 3 $1 >> /tmp/pingLog
    serverStatus=`ping -c 3 $1|head -1|awk -F "[service]" '{print $1}'`
    pingLog=`ping -c 3 $1|tail -n 5|head -1|awk -F "[ ]" '{print $4 $7}'`
    echoContent skyBlue "DNS解析ip:"${pingLog}
}
# 查看本机ip
checkDomainIP(){
    currentIP=`curl -s ifconfig.me|awk '{print}'`
    echoContent skyBlue ${currentIP}
}
progressTool(){
    ${installType} $1 > /dev/null &
    #
    i=0
    toolName=$1
    sp='/-\|'
    n=${#sp}
    printf ' '
    sleep 0.1
    if [[ "${toolName}" = "crontabs" ]]
    then
        toolName="crontab"
    fi
    while true; do
        status=`command -v ${toolName}`
        if [[ -z ${status} ]]
        then
            printf '\b%s' "${sp:i++%n:1}"
        else
            break;
        fi
        sleep 0.1
    done
    sleep 1
}

init(){
    echoContent skyBlue "==============================="
    echoContent skyBlue "欢迎使用v2ray-agent，Cloudflare+WS+TLS+Nginx自动化脚本，如有使用问题欢迎加入TG群【https://t.me/v2rayAgent】，Github【https://github.com/mack-a/v2ray-agent】"
    echoContent skyBlue "注意事项："
    echoContent skyBlue "    1.脚本适合新机器，会删除、卸载已经安装的应用，包括V2Ray、Nginx"
    echoContent skyBlue "    2.如果有使用此脚本生成过TLS证书、V2Ray，会继续使用旧的。"
    echoContent skyBlue "    3.脚本会检查并安装工具包"
    echoContent skyBlue "    4.会自动关闭防火墙"
    echoContent skyBlue "==============================="
    installTools
    installNginx
    installV2Ray
}
checkSystem(){
	if [ -f /etc/redhat-release ]; then
		release="centos"
		installTool='yum -y'
		echoType='echo -e'
		removeType='yum -y remove'
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
		installTools='apt'
		echoType='echo -e'
		removeType='apt -y autoremove'
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
		installTools='apt'
		echoType='echo -e'
		removeType='apt -y autoremove'
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
		installTools='yum'
		echoType='echo -e'
		removeType='yum -y remove'
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
		installTools='apt'
		removeType='apt -y autoremove'
		echoType='echo -e'
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
		installTools='apt'
		removeType='apt -y autoremove'
		echoType='echo -e'
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
		installTools='yum'
		removeType='yum -y remove'
		echoType='echo -e'
    fi
}
#checkSystem
#[ ${release} != "debian" ] && [ ${release} != "ubuntu" ] && [ ${release} != "centos" ] && ${echoType} "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
init
#progressTool

# server {listen 443 ssl;server_name $1;root /usr/share/nginx/html;ssl_certificate /etc/nginx/$1.crt;ssl_certificate_key /etc/nginx/$1.key;ssl_protocols TLSv1 TLSv1.1 TLSv1.2;ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;ssl_prefer_server_ciphers on;location / {}location /mmtest { proxy_redirect off;proxy_pass http://127.0.0.1:31299;proxy_http_version 1.1;proxy_set_header Upgrade $http_upgrade;proxy_set_header Connection "upgrade";proxy_set_header X-Real-IP $remote_addr;proxy_set_header Host $host;proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;}}
