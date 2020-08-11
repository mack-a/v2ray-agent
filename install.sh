#!/usr/bin/env bash

installType='yum -y install'
removeType='yum -y remove'
upgrade="yum -y update"
echoType='echo -e'
centosVersion=0
installProgress=0
totalProgress=20
iplc=$1
trap 'onCtrlC' INT
function onCtrlC () {
    echo
    killSleep > /dev/null 2>&1
    exit;
}
# echo颜色方法
echoContent(){
    printN='\n'
    if [[ ! -z "$3" ]]
    then
        printN=''
    fi
    case $1 in
        # 红色
        "red")
            ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        # 天蓝色
        "skyBlue")
            ${echoType} "\033[36m${printN}$2 \033[0m"
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
        "skyBlue")
            ${echoType} "\033[36m${printN}$2 \033[0m"
        ;;
        # 黄色
        "yellow")
            ${echoType} "\033[33m${printN}$2 \033[0m"
        ;;
    esac
}
# 修复bug
fixBug(){
    echo
}
# 新建目录
mkdirTools(){
    mkdir -p /etc/v2ray/
    mkdir -p /etc/systemd/system/
    mkdir -p /etc/nginx/v2ray-agent-https/
    mkdir -p /usr/bin/v2ray/
    mkdir -p /tmp/v2ray/
    mkdir -p /tmp/tls/
}
# 安装工具包
installTools(){
    # echo "export LC_ALL=en_US.UTF-8"  >>  /etc/profile
    # source /etc/profile
    # kill lock
    if [[ "${release}" = "centos" ]]
    then
        progressTools "yellow" "检查安装jq、nginx epel源、yum-utils--->" 0
        # jq epel源
        rpm -ivh http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm > /dev/null 2>&1

        nginxEpel=""
        if [[ ! -z `rpm -qa|grep -v grep|grep nginx` ]]
        then
            rpm -qa|grep -v grep|grep nginx|xargs rpm -e > /dev/null 2>&1
        fi
        if [[ "${centosVersion}" = "6" ]]
        then
            nginxEpel="http://nginx.org/packages/centos/6/x86_64/RPMS/nginx-1.18.0-1.el6.ngx.x86_64.rpm"
        elif [[ "${centosVersion}" = "7" ]]
        then
            nginxEpel="http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm"
        elif [[ "${centosVersion}" = "8" ]]
        then
            nginxEpel="http://nginx.org/packages/centos/8/x86_64/RPMS/nginx-1.18.0-1.el8.ngx.x86_64.rpm"
        fi
        # nginx epel源
        rpm -ivh ${nginxEpel} > /dev/null 2>&1
        # yum-utils
        yum install yum-utils -y > /dev/null 2>&1
    fi

    if [[ ! -z `ps -ef|grep -v grep|grep apt`  ]]
    then
        ps -ef|grep -v grep|grep apt|awk '{print $2}'|xargs kill -9
    fi
    progressTools "yellow" "卸载Nginx--->" 1
#    echoContent yellow "删除Nginx、V2Ray，请等待--->"
    if [[ ! -z `find /usr/sbin/ -name nginx` ]]
    then
        if [[ ! -z `ps -ef|grep nginx|grep -v grep`  ]]
        then
            ps -ef|grep nginx|grep -v grep|awk '{print $2}'|xargs kill -9
        fi

        if [[ "${release}" = "ubuntu" ]] || [[ "${release}" = "debian" ]]
        then
            dpkg --get-selections | grep nginx|awk '{print $1}'|xargs sudo apt --purge remove -y > /dev/null
        else
            removeLog=`${removeType} nginx`
        fi
        rm -rf /etc/nginx/nginx.conf
        rm -rf /usr/share/nginx/html.zip
    fi

    progressTools "yellow" "卸载V2Ray--->" 2
    if [[ ! -z `find /usr/bin/ -name "v2ray*"` ]]
    then
        if [[ ! -z `ps -ef|grep v2ray|grep -v grep`  ]]
        then
            ps -ef|grep v2ray|grep -v grep|awk '{print $2}'|xargs kill -9
        fi
        rm -rf  /usr/bin/v2ray
    fi

    progressTools "yellow" "卸载V2Ray开机自启--->" 3
    rm -rf /etc/systemd/system/v2ray.service
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        systemctl daemon-reload
    else
        echo
    fi

    progressTools "yellow" "卸载acme.sh--->" 4
    rm -rf ~/.acme.sh > /dev/null
    if [[ ! -z `cat /root/.bashrc|grep -n acme` ]]
    then
        acmeBashrcLine=`cat /root/.bashrc|grep -n acme|awk -F "[:]" '{print $1}'|head -1`
        sed -i "${acmeBashrcLine}d" /root/.bashrc
    fi


    progressTools "yellow" "检查、安装更新【新机器会很慢，耐心等待】--->" 5
    # if [[ "${release}" = "centos" ]]
    # then
    #    yum-complete-transaction --cleanup-only
    # fi
    ${upgrade} > /dev/null

    # yum要删除pid
    rm -rf /var/run/yum.pid

    progressTools "yellow" "检查、安装wget--->" 6
    ${installType} wget > /dev/null

    progressTools "yellow" "检查、安装unzip--->" 7
    ${installType} unzip > /dev/null

    # echoContent yellow "检查、安装qrencode--->"
    # # progressTool qrencode &
    # ${installType} qrencode > /dev/null

    progressTools "yellow" "检查、安装socat--->" 8
    ${installType} socat > /dev/null

    progressTools "yellow" "检查、安装tar--->" 9
    ${installType} tar > /dev/null

    progressTools "yellow" "检查、安装crontabs--->" 10
    if [[ "${release}" = "ubuntu" ]] || [[ "${release}" = "debian" ]]
    then
        ${installType} cron > /dev/null
    else
        ${installType} crontabs > /dev/null
    fi

    progressTools "yellow" "检查、安装jq--->" 11
    ${installType} jq > /dev/null

    # echoContent skyBlue "检查、安装bind-utils--->"
    # # progressTool bind-utils
    # 关闭防火墙

    # 安装nginx
    progressTools "yellow" "检查、安装Nginx--->" 12
    # progressTool nginx &
    ${installType} nginx > /dev/null
    if [[ ! -z `ps -ef|grep -v grep|grep nginx` ]]
    then
        nginx -s stop
    fi
    progressTools "yellow" "检查、安装binutils--->" 13
    # progressTool nginx &
    ${installType} binutils > /dev/null
    # 新建所需目录
    mkdirTools

    progressTools "yellow" "检查、安装acme--->" 14
    mkdir -p /etc/tls/
    curl -s https://get.acme.sh | sh > /etc/tls/acme.log
    if [[ -z `find ~/.acme.sh -name "acme.sh"` ]]
    then
        echoContent red "  acme安装失败--->"
        echoContent yellow "错误排查："
        echoContent red "  1.获取Github文件失败，请等待GitHub恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
        echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
        echoContent red "  3.反馈给开发者[私聊：https://t.me/mack_a] 或 [提issues]"
        killSleep > /dev/null 2>&1
        exit 0
    fi
}
# 安装Nginx tls证书
installNginx(){
    killSleep > /dev/null 2>&1
    killSleep > /dev/null 2>&1
    echoContent yellow  "请输入要配置的域名 例：worker.v2ray-agent.com --->"
    read domain
    if [[ -z ${domain} ]]
    then
        echoContent red "  域名不可为空--->"
        installNginx
    else
        # 修改配置
        progressTools "yellow" "配置Nginx--->" 15
        touch /etc/nginx/conf.d/alone.conf
        echo "server {listen 80;server_name ${domain};root /usr/share/nginx/html;location ~ /.well-known {allow all;}location /test {return 200 'fjkvymb6len';}}" > /etc/nginx/conf.d/alone.conf
        # sed -i "1i 1" /etc/nginx/conf.d/alone.conf
        # installLine=`expr ${installLine} + 1`
        # sed -i "${installLine}i location /test {return 200 'fjkvymb6len';}" /etc/nginx/nginx.conf
        # 启动nginx
        nginx

        # 测试nginx
        progressTools "yellow" "检查Nginx是否正常访问--->" 16
        domainResult=`curl -s ${domain}/test|grep fjkvymb6len`
        if [[ ! -z ${domainResult} ]]
        then
            ps -ef|grep nginx|grep -v grep|awk '{print $2}'|xargs kill -9
            progressTools "green" "Nginx配置成功--->"
            installTLS ${domain}
        else
            echoContent red "    无法正常访问服务器，请检测域名是否正确、域名的DNS解析以及防火墙设置是否正确--->"
            killSleep > /dev/null 2>&1
            exit 0;
        fi
    fi
}
# 安装TLS
installTLS(){
    mkdir -p /etc/nginx/v2ray-agent-https/
    mkdir -p /etc/v2ray-agent/tls/
    touch /etc/nginx/v2ray-agent-https/config
    if [[ -z `find /etc/v2ray-agent/tls/ -name "$1*"` ]]
    then
        progressTools "yellow" "检查、安装TLS证书--->" 17

        sudo ~/.acme.sh/acme.sh --issue -d $1 --standalone -k ec-256 >/dev/null
        ~/.acme.sh/acme.sh --installcert -d $1 --fullchainpath /etc/nginx/v2ray-agent-https/$1.crt --keypath /etc/nginx/v2ray-agent-https/$1.key --ecc >/dev/null
        if [[ -z `cat /etc/nginx/v2ray-agent-https/$1.crt` ]]
        then
            progressTools "yellow" "    TLS安装失败，请检查acme日志--->"
            exit 0
        elif [[ -z `cat /etc/nginx/v2ray-agent-https/$1.key` ]]
        then
            progressTools "yellow" "    TLS安装失败，请检查acme日志--->"
            exit 0
        fi
        progressTools "green" "  TLS生成成功--->>"

        echo $1 `date +%s` > /etc/nginx/v2ray-agent-https/config

        cp -R /etc/nginx/v2ray-agent-https/config /etc/v2ray-agent/tls/config
        cp -R /etc/nginx/v2ray-agent-https/$1.crt /etc/v2ray-agent/tls/$1.crt
        cp -R /etc/nginx/v2ray-agent-https/$1.key /etc/v2ray-agent/tls/$1.key
        progressTools "yellow" "  TLS证书备份成功，证书位置：/etc/v2ray-agent/tls--->"
    elif  [[ -z `cat /etc/v2ray-agent/tls/$1.crt` ]] || [[ -z `cat /etc/v2ray-agent/tls/$1.key` ]]
    then
        progressTools "red" "  检测到错误证书，需重新生成，重新生成中--->" 18
        rm -rf /etc/v2ray-agent/tls/
        installTLS $1
    else
        progressTools "yellow" "检测到备份证书，使用--->"
        cp -R /etc/v2ray-agent/tls/$1.crt /etc/nginx/v2ray-agent-https/$1.crt
        cp -R /etc/v2ray-agent/tls/$1.key /etc/nginx/v2ray-agent-https/$1.key
        cp -R /etc/v2ray-agent/tls/config /etc/nginx/v2ray-agent-https/config
    fi
    # nginxInstallLine=`cat /etc/nginx/nginx.conf|grep -n "}"|awk -F "[:]" 'END{print $1-1}'`
    # sed -i "${nginxInstallLine}i server {listen 443 ssl;server_name $1;root /usr/share/nginx/html;ssl_certificate /etc/nginx/$1.crt;ssl_certificate_key /etc/nginx/$1.key;ssl_protocols TLSv1 TLSv1.1 TLSv1.2;ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;ssl_prefer_server_ciphers on;location / {} location /alone { proxy_redirect off;proxy_pass http://127.0.0.1:31299;proxy_http_version 1.1;proxy_set_header Upgrade \$http_upgrade;proxy_set_header Connection "upgrade";proxy_set_header X-Real-IP \$remote_addr;proxy_set_header Host \$host;proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;}}" /etc/nginx/nginx.conf
    # todo
    cat << EOF > /etc/nginx/conf.d/alone.conf
server {
    listen 443 ssl;
    server_name $1;
    root /usr/share/nginx/html;
    ssl_certificate /etc/nginx/v2ray-agent-https/$1.crt;ssl_certificate_key /etc/nginx/v2ray-agent-https/$1.key;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;ssl_prefer_server_ciphers on;
    location / {}
    location /alone {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:31299;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    location /vlesspath {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:31298;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF


    # 自定义路径
    # todo 随机路径
    progressTools "yellow" "请输入自定义路径Vmess[例: alone]，不需要斜杠，[回车]随机路径，VLESS则为随机路径"
    read customPath

    if [[ ! -z "${customPath}" ]]
    then
        sed -i "s/alone/${customPath}/g" `grep alone -rl /etc/nginx/conf.d/alone.conf`
        sed -i "s/vlesspath/${customPath}vld/g" `grep vlesspath -rl /etc/nginx/conf.d/alone.conf`
    else
        customPath=`head -n 50 /dev/urandom|sed 's/[^a-z]//g'|strings -n 4|tr 'A-Z' 'a-z'|head -1`
        if [[ ! -z "${customPath}" ]]
        then
            sed -i "s/alone/${customPath}/g" `grep alone -rl /etc/nginx/conf.d/alone.conf`
            sed -i "s/vlesspath/${customPath}vld/g" `grep vlesspath -rl /etc/nginx/conf.d/alone.conf`
        fi
    fi
    echoContent yellow "path：${customPath}"
    echoContent yellow "vlessPath：${customPath}vld"
    rm -rf /usr/share/nginx/html
    wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/blog/unable/html.zip >> /dev/null
    unzip  /usr/share/nginx/html.zip -d /usr/share/nginx/html > /dev/null
    nginx
    if [[ -z `ps -ef|grep -v grep|grep nginx` ]]
    then
        progressTools "red" "  Nginx启动失败，请检查日志--->"
        exit 0
    fi

    # 增加定时任务定时维护证书
    reInstallTLS $1
    installV2Ray $1 ${customPath}
}

# 重新安装&更新tls证书
reInstallTLS(){
    progressTools "yellow" "检查、添加定时维护证书--->" 19
    touch /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    touch /etc/nginx/v2ray-agent-https/backup_crontab.cron
    touch /etc/v2ray-agent/tls/tls.log
    if [[ -z `crontab -l|grep -v grep|grep 'reloadInstallTLS'` ]]
    then
        crontab -l >> /etc/nginx/v2ray-agent-https/backup_crontab.cron
        # 定时任务
        echo "30 1 * * * /bin/bash /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh" >> /etc/nginx/v2ray-agent-https/backup_crontab.cron
        crontab /etc/nginx/v2ray-agent-https/backup_crontab.cron
    fi
    # 备份

    domain=$1
    cat << EOF > /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
        domain=$1
        eccPath=\`find ~/.acme.sh -name "\${domain}_ecc"|head -1\`
        mkdir -p /etc/v2ray-agent/tls
        touch /etc/v2ray-agent/tls/tls.log
        touch /etc/v2ray-agent/tls/acme.log
        if [[ ! -z \${eccPath} ]]
        then
            modifyTime=\`stat \${eccPath}/\${domain}.key|sed -n '6,6p'|awk '{print \$2" "\$3" "\$4" "\$5}'\`
            modifyTime=\`date +%s -d "\${modifyTime}"\`
            currentTime=\`date +%s\`
            stampDiff=\`expr \${currentTime} - \${modifyTime}\`
            minutes=\`expr \${stampDiff} / 60\`
            status="正常"
            reloadTime="暂无"
            if [[ ! -z \${modifyTime} ]] && [[ ! -z \${currentTime} ]] && [[ ! -z \${stampDiff} ]] && [[ ! -z \${minutes} ]] && [[ \${minutes} -lt '120' ]]
            then
                nginx -s stop
                ~/.acme.sh/acme.sh --installcert -d \${domain} --fullchainpath /etc/nginx/v2ray-agent-https/\${domain}.crt --keypath /etc/nginx/v2ray-agent-https/\${domain}.key --ecc >> /tmp/tls/acme.log
                nginx
                reloadTime=\`date -d @\${currentTime} +"%F %H:%M:%S"\`
            fi
            echo "域名：\${domain}，modifyTime:"\`date -d @\${modifyTime} +"%F %H:%M:%S"\`,"检查时间:"\`date -d @\${currentTime} +"%F %H:%M:%S"\`,上次生成证书的时:\`expr \${minutes} / 1440\`"天前","证书状态："\${status},"重新生成日期："\${reloadTime} >> /etc/v2ray-agent/tls/tls.log
        else
            echo '无法找到证书路径' >> /etc/v2ray-agent/tls/tls.log
        fi
EOF

    if [[ ! -z `crontab -l|grep -v grep|grep 'reloadInstallTLS'` ]]
    then
        progressTools "green" "  添加定时维护证书成功"
    else
        crontab -l >> /etc/nginx/v2ray-agent-https/backup_crontab.cron
        # 定时任务
        crontab /etc/nginx/v2ray-agent-https/backup_crontab.cron
        progressTools "green" "  检测到已添加定时任务"
    fi
}
# V2Ray
installV2Ray(){
# ls -F /usr/bin/v2ray/|grep "v2ray"
    mkdir -p /usr/bin/v2ray/
    mkdir -p /etc/v2ray-agent/v2ray/
    if [[ -z `ls -F /etc/v2ray-agent/v2ray/|grep "v2ray"` ]] || [[ -z `ls -F /etc/v2ray-agent/v2ray/|grep "v2ctl"` ]]
    then
        if [[ -z `ls -F /usr/bin/v2ray/|grep "v2ray"` ]] || [[ -z `ls -F /usr/bin/v2ray/|grep "v2ctl"` ]]
        then
            progressTools "yellow" "检查、安装V2Ray--->" 20
            version=`curl -s https://github.com/v2ray/v2ray-core/releases|grep /v2ray/v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
            progressTools "green" "  v2ray-core版本:${version}"

            wget -q -P /etc/v2ray-agent/v2ray https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip
            unzip /etc/v2ray-agent/v2ray/v2ray-linux-64.zip -d /etc/v2ray-agent/v2ray > /dev/null
            cp /etc/v2ray-agent/v2ray/v2ray /usr/bin/v2ray/v2ray && cp /etc/v2ray-agent/v2ray/v2ctl /usr/bin/v2ray/v2ctl
            rm -rf /etc/v2ray-agent/v2ray/v2ray-linux-64.zip
        fi
    else
        progressTools "green" "  v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
        cp /etc/v2ray-agent/v2ray/v2ray /usr/bin/v2ray/v2ray && cp /etc/v2ray-agent/v2ray/v2ctl /usr/bin/v2ray/v2ctl
    fi

    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        installV2RayService
    fi

    initV2RayConfig $2
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        systemctl daemon-reload
        systemctl enable v2ray.service
        systemctl start  v2ray.service
    else
        /usr/bin/v2ray/v2ray -config /etc/v2ray/config.json & > /dev/null 2>&1
    fi

    sleep 0.5
    if [[ -z `ps -ef|grep v2ray|grep -v grep` ]]
    then
        progressTools "red" "      V2Ray启动失败，请检查日志后，重新执行脚本--->"
        exit 0;
    fi
#    echoContent green "  V2Ray启动成功--->\n"
    echoContent yellow "V2Ray日志目录："
    echoContent green "  access:  /etc/v2ray/v2ray_access_ws_tls.log"
    echoContent green "  error:  /etc/v2ray/v2ray_error_ws_tls.log"

    # 验证整个服务是否可用
    progressTools "yellow" "验证服务是否可用--->"
    nginxPath=$2;
    if [[ -z "${nginxPath}" ]]
    then
        nginxPath="alone"
    fi

    if [[ ! -z `curl -s -L https://$1/${nginxPath}|grep -v grep|grep "Bad Request"` ]]
    then
        progressTools "green" "  服务可用--->"
    else
        progressTools "red" "    服务不可用，请检查Cloudflare->域名->SSL/TLS->Overview->Your SSL/TLS encryption mode is 是否是Full--->"
        progressTools "red" "  错误日志:`curl -s -L https://$1/${nginxPath}`"
        exit 0
    fi
    qrEncode $1 $2
    progressTools "yellow" "安装完毕[100%]--->"
    echoContent yellow "============================成功分界线============================="

    progressTools "yellow" "监听V2Ray日志中，请使用上方生成的vmess访问，如有日志出现则证明线路可用，退出监听也无妨，Ctrl+c退出监听日志，--->"
    echo '' > /etc/v2ray/v2ray_access_ws_tls.log
    killSleep > /dev/null 2>&1
    tail -f /etc/v2ray/v2ray_access_ws_tls.log
}
# 开机自启
installV2RayService(){
    progressTools "yellow" "  配置V2Ray开机自启--->"

    rm -rf /etc/systemd/system/v2ray.service
    touch /etc/systemd/system/v2ray.service

cat << EOF > /etc/systemd/system/v2ray.service
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
ExecStart=/usr/bin/v2ray/v2ray -config /etc/v2ray/config.json
Restart=on-failure
RestartPreventExitStatus=23


[Install]
WantedBy=multi-user.target
EOF
    progressTools "green" "  配置V2Ray开机自启成功--->"
}

# 初始化V2Ray 配置文件
initV2RayConfig(){

    touch /etc/v2ray/config.json
    uuid=`/usr/bin/v2ray/v2ctl uuid`

    # 自定义IPLC端口
    if [[ ! -z ${iplc} ]]
    then
        cat << EOF > /etc/v2ray/config.json
{
    "log":{
        "access":"/etc/v2ray/v2ray_access_ws_tls.log",
        "error":"/etc/v2ray/v2ray_error_ws_tls.log",
        "loglevel":"debug"
    },
    "stats":{

    },
    "api":{
        "services":[
            "StatsService"
        ],
        "tag":"api"
    },
    "policy":{
        "levels":{
            "1":{
                "handshake":4,
                "connIdle":300,
                "uplinkOnly":2,
                "downlinkOnly":5,
                "statsUserUplink":false,
                "statsUserDownlink":false
            }
        },
        "system":{
            "statsInboundUplink":true,
            "statsInboundDownlink":true
        }
    },
    "allocate":{
        "strategy":"always",
        "refresh":5,
        "concurrency":3
    },
    "inbounds":[
        {
            "port":31299,
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"654765fe-5fb1-271f-7c3f-18ed82827f72",
                        "alterId":64,
                        "level":1,
                        "email":"test@v2ray.com"
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/alone"
                }
            }
        },
        {
            "port":31298,
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"654765fe-5fb1-271f-7c3f-18ed82827f72",
                        "level":1,
                        "email":"test_vless@v2ray.com"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/vlesspath"
                }
            }
        },
        {
            "port":31294,
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"ab11e002-7008-ef16-4363-217aea8dc81c",
                        "alterId":64,
                        "level":1,
                        "email":"HK_深港0.35x IPLC@v2ray.com"
                    },
                    {
                        "id":"246d748a-dd07-2172-a397-ab110aa5ad2a",
                        "alterId":64,
                        "level":1,
                        "email":"HK_莞港IPLC@v2ray.com"
                    }
                ]
            }
        }
    ],
    "outbounds":[
        {
            "protocol":"freedom",
            "settings":{
                "OutboundConfigurationObject":{
                    "domainStrategy":"AsIs",
                    "userLevel":0
                }
            }
        }
    ],
    "routing":{
        "settings":{
            "rules":[
                {
                    "inboundTag":[
                        "api"
                    ],
                    "outboundTag":"api",
                    "type":"field"
                }
            ]
        },
        "strategy":"rules"
    },
    "dns":{
        "servers":[
            "8.8.8.8",
            "8.8.4.4"
        ],
        "tag":"dns_inbound"
    }
}
EOF
    else
        cat << EOF > /etc/v2ray/config.json
{
    "log":{
        "access":"/etc/v2ray/v2ray_access_ws_tls.log",
        "error":"/etc/v2ray/v2ray_error_ws_tls.log",
        "loglevel":"debug"
    },
    "stats":{

    },
    "api":{
        "services":[
            "StatsService"
        ],
        "tag":"api"
    },
    "policy":{
        "levels":{
            "1":{
                "handshake":4,
                "connIdle":300,
                "uplinkOnly":2,
                "downlinkOnly":5,
                "statsUserUplink":false,
                "statsUserDownlink":false
            }
        },
        "system":{
            "statsInboundUplink":true,
            "statsInboundDownlink":true
        }
    },
    "allocate":{
        "strategy":"always",
        "refresh":5,
        "concurrency":3
    },
    "inbounds":[
        {
            "port":31299,
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"654765fe-5fb1-271f-7c3f-18ed82827f72",
                        "alterId":64,
                        "level":1,
                        "email":"test@v2ray.com"
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/alone"
                }
            }
        },
        {
            "port":31298,
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"654765fe-5fb1-271f-7c3f-18ed82827f72",
                        "alterId":64,
                        "level":1,
                        "email":"test_vless@v2ray.com"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/vlesspath"
                }
            }
        }
    ],
    "outbounds":[
        {
            "protocol":"freedom",
            "settings":{
                "OutboundConfigurationObject":{
                    "domainStrategy":"AsIs",
                    "userLevel":0
                }
            }
        }
    ],
    "routing":{
        "settings":{
            "rules":[
                {
                    "inboundTag":[
                        "api"
                    ],
                    "outboundTag":"api",
                    "type":"field"
                }
            ]
        },
        "strategy":"rules"
    },
    "dns":{
        "servers":[
            "8.8.8.8",
            "8.8.4.4"
        ],
        "tag":"dns_inbound"
    }
}
EOF
    fi
    # 自定义路径
    if [[ ! -z "$1" ]]
    then
        sed -i "s/alone/${1}/g" `grep alone -rl /etc/v2ray/config.json`
        sed -i "s/vlesspath/${1}vld/g" `grep vlesspath -rl /etc/v2ray/config.json`
    fi
    sed -i "s/654765fe-5fb1-271f-7c3f-18ed82827f72/${uuid}/g" `grep 654765fe-5fb1-271f-7c3f-18ed82827f72 -rl /etc/v2ray/config.json`
}
qrEncode(){
    user=`cat /etc/v2ray/config.json|jq .inbounds[0]`
    ps="$1"
    id=`echo ${user}|jq .settings.clients[0].id`
    aid=`echo ${user}|jq .settings.clients[0].alterId`
    host="$1"
    add="$1"
    path=`echo ${user}|jq .streamSettings.wsSettings.path`
    echoContent green "是否使用DNS智能解析进行自定义CDN IP？"

    echoContent yellow " 智能DNS提供一下自定义CDN IP，会根据运营商自动切换ip，测试结果请查看[https://github.com/mack-a/v2ray-agent/blob/master/optimize_V2Ray.md]" "no"
    echoContent yellow "  移动:1.0.0.83" "no"
    echoContent yellow "  联通:104.16.160.136" "no"
    echoContent yellow "  电信CNAME:www.digitalocean.com" "no"
    echoContent green   "输入[y]使用，[任意]不使用" "no"
    read dnsProxy
    if [[ "${dnsProxy}" = "y" ]]
    then
        add="domain08.qiu4.ml"
    fi
    echoContent yellow "客户端链接--->\n"
    qrCodeBase64Default=`echo -n '{"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"64","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'"}'|sed 's#/#\\\/#g'|base64`
    qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
    # 通用Vmess
    echoContent red "通用vmess链接--->" "no"
    echoContent green "    vmess://${qrCodeBase64Default}\n"
    echo "通用vmess链接: " > /etc/v2ray/usersv2ray.conf
    echo "   vmess://${qrCodeBase64Default}" >> /etc/v2ray/usersv2ray.conf
    echoContent red "通用json--->" "no"
    echoContent green '    {"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"64","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'"}\n'
    echoContent green '    V2Ray v4.27.0 目前无通用订阅需要手动配置，VLESS和上面大部分一样，path则是"'/${2}vld'"，其余内容不变'
    # Quantumult
    qrCodeBase64Quanmult=`echo -n ''${ps}' = vmess, '${add}', 443, aes-128-cfb, '${id}', over-tls=true, tls-host='${host}', certificate=1, obfs=ws, obfs-path='${path}', obfs-header="Host: '${host}'[Rr][Nn]User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 11_2_6 like Mac OS X) AppleWebKit/604.5.6 (KHTML, like Gecko) Mobile/15D100"'|base64`
    qrCodeBase64Quanmult=`echo ${qrCodeBase64Quanmult}|sed 's/ //g'`

    echoContent red "Quantumult vmess--->" "no"
    echoContent green "    vmess://${qrCodeBase64Quanmult}\n"
    echo '' >> /etc/v2ray/usersv2ray.conf
    echo "Quantumult:" >> /etc/v2ray/usersv2ray.conf
    echo "  vmess://${qrCodeBase64Quanmult}" >> /etc/v2ray/usersv2ray.conf
    echoContent red "Quantumult 明文--->" "no"
    echoContent green  '    '${ps}' = vmess, '${add}', 443, aes-128-cfb, '${id}', over-tls=true, tls-host='${host}', certificate=1, obfs=ws, obfs-path='${path}', obfs-header="Host: '${host}'[Rr][Nn]User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 11_2_6 like Mac OS X) AppleWebKit/604.5.6 (KHTML, like Gecko) Mobile/15D100"'
    # | qrencode -t UTF8
    # echo ${qrCodeBase64}
}
# 查看本机ip
checkDomainIP(){
    currentIP=`curl -s ifconfig.me|awk '{print}'`
    echoContent skyBlue ${currentIP}
}
progressTool(){
    #
    i=0
    toolName=$1
    sp='/-\|'
    n=${#sp}
    printf ' '
    if [[ "${toolName}" = "crontabs" ]]
    then
        toolName="crontab"
    fi
    while true; do
        status=
        if [[ -z `find /usr/bin/ -name ${toolName}` ]] && [[ -z `find /usr/sbin/ -name ${toolName}` ]]
        then
            printf '\b%s' "${sp:i++%n:1}" > /dev/null
        else
            break;
        fi
        sleep 0.1
    done
    echoContent green "  $1已安装--->"
}
# 进度条工具
progressTools(){
    color=$1
    content=$2
    installProgress=$3
#    echo ${color},${content},${installProgress}
    echoContent ${color} "${content}"
    killSleep > /dev/null 2>&1
    if [[ ! -z "${installProgress}" ]]
    then
        installProgressFunction ${installProgress} ${totalProgress} &
    fi

    sleep 0.5
}
installProgressFunction(){
    installProgress=$1
    totalProgress=$2
    currentProgress=0
    i=0
    sp='/-\|'
    n=${#sp}

    progressNum=`awk 'BEGIN{printf "%.0f\n",('${installProgress}'/'${totalProgress}')*100}'`
#    echoContent red ${progressNum}
    printf '\b%s' "[${progressNum}%]   "
    while true; do
        if [[ ${installProgress} -gt ${currentProgress} ]] && [[ ${installProgress} -lt ${totalProgress} ]]
        then
            printf '\b%s' "${sp:i++%n:1}"
        else
            break
        fi
        sleep 0.1
    done
}

# 卸载安装的内容
removeInstall(){
    rm -rf /etc/v2ray-agent/v2ray
    rm -rf /etc/v2ray-agent/tls
    rm -rf /etc/v2ray
    rm -rf /root/.acme.sh
    echo ${removeType},${installType}
    `${removeType} nginx` > /dev/null 2>&1
}
init(){
     # 新建所需目录
    mkdirTools
    cd
    echoContent red "=============================================================="
    echoContent green "CDN+WebSocket+TLS+Nginx+伪装博客一键脚本"
    echoContent green "作者：mack-a"
    echoContent green "Version：v1.0.9"
    echoContent green "Github：https://github.com/mack-a/v2ray-agent"
    echoContent green "TG群：https://t.me/technologyshare"
    echoContent green "欢迎找我请求协助与反馈问题"
    echoContent red "=============================================================="
    echoContent red "状态展示"
    echoContent green "已安装账号："
    if [[ ! -z `find /etc|grep usersv2ray.conf`  ]] && [[ ! -z `cat /etc/v2ray/usersv2ray.conf` ]]
    then
        cat /etc/v2ray/usersv2ray.conf
    else
        echoContent yellow "    暂无配置"
    fi
    echoContent green "\nV2Ray信息："

    v2rayStatus=0
    if [[ ! -z `ls -F /usr/bin/v2ray/|grep "v2ray"` ]] && [[ ! -z `find /etc/v2ray/ -name "config.json"` ]]
    then
        v2rayVersion=`/usr/bin/v2ray/v2ray -version|awk '{print $2}'|head -1`
        v2rayStatus=1
        echoContent yellow "    version：${v2rayVersion}"
        echoContent yellow "    安装路径：/usr/bin/v2ray/"
        echoContent yellow "    配置文件：/etc/v2ray/config.json"
        echoContent yellow "    日志路径："
        echoContent yellow "      access:  /etc/v2ray/v2ray_access_ws_tls.log"
        echoContent yellow "      error:  /etc/v2ray/v2ray_error_ws_tls.log"
    else
        echoContent yellow "    暂未安装"
    fi
    tlsStatus=0
    echoContent green "\nTLS证书状态："

    if [[ ! -z `find /etc/nginx/v2ray-agent-https/ -name config` ]] && [[ ! -z `cat /etc/nginx/v2ray-agent-https/config` ]]
    then
        tlsStatus=1
        domain=`cat /etc/nginx/v2ray-agent-https/config|awk '{print $1}'`
        tlsCreateTime=`cat /etc/nginx/v2ray-agent-https/config|awk '{print $2}'`
        currentTime=`date +%s`
        stampDiff=`expr ${currentTime} - ${tlsCreateTime}`
        dayDiff=`expr ${stampDiff} / 86400`
        echoContent yellow "    证书域名：${domain}"
        echoContent yellow "    安装日期：`date -d @${tlsCreateTime} +"%F %H:%M:%S"`，剩余天数：`expr 90 - ${dayDiff}`"
        echoContent yellow "    证书路径："
        echoContent yellow "      /etc/nginx/v2ray-agent-https/${domain}.key"
        echoContent yellow "      /etc/nginx/v2ray-agent-https/${domain}.crt"
    else
        echoContent yellow "    暂未安装或未使用最新的脚本安装"
    fi

    echoContent green "\n定时任务相关文件路径："
    if [[ ! -z `find  /etc/nginx/v2ray-agent-https/ -name backup_crontab.cron`  ]]
    then
        echoContent yellow "    定时更新tls脚本路径：/etc/nginx/v2ray-agent-https/reloadInstallTLS.sh"
        echoContent yellow "    定时任务文件路径：/etc/nginx/v2ray-agent-https/backup_crontab.cron"
        echoContent yellow "    定时任务日志路径：/etc/v2ray-agent/tls/tls.log"
        echoContent yellow "    acme.sh日志路径：/etc/v2ray-agent/tls/acme.log"
    else
        echoContent yellow "    暂未安装或未使用最新的脚本安装"
    fi

    echoContent green "\n软件运行状态："
    if [[ ! -z `ps -ef|grep -v grep|grep nginx`  ]]
    then
        echoContent yellow "    Nginx:【运行中】"
    elif [[ ! -z `find /usr/sbin/ -name 'nginx'` ]]
    then
        echoContent yellow "    Nginx:【未运行】，执行【nginx】运行"
    else
        echoContent yellow "    Nginx:【未安装】"
    fi

    if [[ ! -z `ps -ef|grep -v grep|grep v2ray`  ]]
    then
        echoContent yellow "    V2Ray:【运行中】"
    elif [[ ! -z `ls -F /usr/bin/v2ray/|grep "v2ray"` ]]
    then
        echoContent yellow "    V2Ray:【未运行】，执行【/usr/bin/v2ray/v2ray -config /etc/v2ray/config.json &】运行"
    else
        echoContent yellow "    V2Ray:【未安装】"
    fi


    echoContent red "==============================================================" "no"
    echoContent red "注意事项："
    echoContent green "    1.脚本会检查并安装工具包"
    echoContent green "    2.如果使用此脚本生成过TLS证书、V2Ray，会继续使用上次生成、安装的内容。" "no"
    echoContent green "    3.会删除、卸载已经安装的应用，包括V2Ray、Nginx。" "no"
    echoContent green "    4.如果显示Nginx不可用，请检查防火墙端口是否开放。" "no"
    echoContent green "    5.证书会在每天的1点30分检查更新" "no"
    echoContent green "    6.重启机器后，日志、缓存文件会被删除，不影响正常使用【tls更新日志、缓存|V2Ray执行文件、日志】" "no"
    echoContent red "==============================================================" "no"
    echoContent red "错误处理【这里请仔细阅读】" "no"
    echoContent yellow "Debian：" "no"
    echoContent green "     错误1：WARNING: apt does not have a stable CLI interface. Use with caution in scripts.【这个错误无需处理】" "no"
    echoContent green "     错误2：如果错误很多，且安装失败，则需要重启vps，无需重新安装OS。这种情况是在安装过程中意外断开导致。" "no"
    echoContent red "==============================================================" "no"
    installSelect=0
    if [[ ${tlsStatus} = "1" ]] && [[ ${v2rayStatus} = "1" ]]
    then
        echoContent green "检测到已使用本脚本安装" "no"
        echoContent yellow "    1.重新安装【使用缓存的文件（TLS证书、V2Ray）】" "no"
        echoContent yellow "    2.完全重装【会清理tmp缓存文件（TLS证书、V2Ray）】" "no"
    else
        echoContent green "未监测到使用本脚本安装" "no"
        echoContent yellow "    1.安装【未安装】" "no"
        echoContent yellow "    2.完全安装【会清理tmp缓存文件（TLS证书、V2Ray）】" "no"
    fi

    echoContent yellow "    3.BBR安装[推荐BBR+FQ 或者 BBR+Cake]" "no"
    echoContent yellow "    4.完全卸载[清理Nginx、TLS证书、V2Ray、acme.sh]" "no"
    echoContent red "==============================================================" "no"
    echoContent green "请输入上列数字，[任意]结束：" "no"
    read installStatus

    if [[ "${installStatus}" = "1" ]]
    then
        rm -rf /etc/v2ray/usersv2ray.conf
        installTools
        installNginx
    elif [[ "${installStatus}" = "2" ]]
    then
        rm -rf /usr/bin/v2ray
        rm -rf /etc/v2ray-agent/v2ray
        rm -rf /etc/v2ray-agent/tls
        rm -rf /etc/v2ray
        installTools
        installNginx
    elif [[ "${installStatus}" = "3" ]]
    then
        echoContent red "==============================================================" "no"
        echoContent green "BBR脚本用的[ylx2016]的成熟作品，地址[https://github.com/ylx2016/Linux-NetSpeed/releases/download/sh/tcp.sh]，请熟知" "no"
        echoContent red "    1.安装" "no"
        echoContent red "    2.回退主目录" "no"
        echoContent red "==============================================================" "no"
        echoContent green "请输入[1]安装，[2]回到上层目录" "no"
        read installBBRStatus
        if [[ "${installBBRStatus}" = "1" ]]
        then
            wget -N --no-check-certificate "https://github.com/ylx2016/Linux-NetSpeed/releases/download/sh/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
        else
            init
        fi
    elif [[ "${installStatus}" = "4" ]]
    then
        removeInstall
        echoContent yellow "卸载完成" "no"
        killSleep > /dev/null 2>&1
        exit 0;
    else
        echoContent yellow "欢迎下次使用--->" "no"
        killSleep > /dev/null 2>&1
        exit 0;
    fi
}
# 杀死sleep
killSleep(){
    if [[ ! -z `ps -ef|grep -v grep|grep sleep` ]]
    then
        ps -ef|grep -v grep|grep sleep|awk '{print $3}'|xargs kill -9 > /dev/null 2>&1
        killSleep > /dev/null 2>&1
    fi
}
checkSystem(){

	if [[ ! -z `find /etc -name "redhat-release"` ]] || [[ ! -z `cat /proc/version | grep -i "centos" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "red hat" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "redhat" | grep -v grep ` ]]
	then
	    centosVersion=`rpm -q centos-release|awk -F "[-]" '{print $3}'`
		release="centos"
		installType='yum -y install'
		removeType='yum -y remove'
		upgrade="yum update -y --skip-broken"
	elif [[ ! -z `cat /etc/issue | grep -i "debian" | grep -v grep` ]] || [[ ! -z `cat /proc/version | grep -i "debian" | grep -v grep` ]]
    then
		release="debian"
		installType='apt -y install'
		upgrade="apt update -y"
		removeType='apt -y autoremove'
	elif [[ ! -z `cat /etc/issue | grep -i "ubuntu" | grep -v grep` ]] || [[ ! -z `cat /proc/version | grep -i "ubuntu" | grep -v grep` ]]
	then
		release="ubuntu"
		installType='apt -y install'
		upgrade="apt update -y"
		removeType='apt --purge remove'
    fi
    if [[ -z ${release} ]]
    then
        echoContent red "本脚本不支持此系统，请将下方日志反馈给开发者"
        cat /etc/issue
        cat /proc/version
        killSleep > /dev/null 2>&1
        exit 0;
    fi
}
checkSystem
init
