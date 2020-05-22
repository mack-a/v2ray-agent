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
    echo "export LC_ALL=en_US.UTF-8"  >>  /etc/profile
    source /etc/profile
    echoContent skyBlue "删除Nginx、V2Ray、TLS"
    if [[ ! -z `find /usr/sbin/ -name nginx` ]]
    then
        if [[ ! -z `ps -ef|grep nginx|grep -v grep`  ]]
        then
            nginx -s stop
        fi
        removeLog=`yum remove nginx -y`
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
}
# V2Ray
installV2Ray(){
    echoContent skyBlue "   安装V2Ray--->"

}
installV2RayService(){

    Description=V2Ray - A unified platform for anti-censorship
    Documentation=https://v2ray.com https://guide.v2fly.org
    After=network.target nss-lookup.target
    Wants=network-online.target

    [Service]
    Type=simple
    User=root
    CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
    NoNewPrivileges=yes
    ExecStart=/usr/bin/v2ray/v2ray -config /etc/v2ray/config.json
    Restart=on-failure
    RestartPreventExitStatus=23

    [Install]
    WantedBy=multi-user.target
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
    echoContent skyBlue "    1.脚本适合新机器，会删除、卸载已经安装的应用，包括V2Ray、Nginx、TLS证书"
    echoContent skyBlue "    2.脚本会检查并安装工具包"
    echoContent skyBlue "    3.会自动关闭防火墙"
    echoContent skyBlue "==============================="
    installTools
    installNginx
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
