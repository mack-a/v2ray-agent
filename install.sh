#!/usr/bin/env bash

installType='yum -y install'
removeType='yum -y remove'
upgrade="yum -y update"
echoType='echo -e'
iplc=$1

# echo颜色方法
echoContent(){
    case $1 in
        # 红色
        "red")
            ${echoType} "\033[31m$2 \033[0m"
        ;;
        # 天蓝色
        "skyBlue")
            ${echoType} "\033[36m$2 \033[0m"
        ;;
        # 绿色
        "green")
            ${echoType} "\033[32m$2 \033[0m"
        ;;
        # 白色
        "white")
            ${echoType} "\033[37m$2 \033[0m"
        ;;
        "magenta")
            ${echoType} "\033[31m$2 \033[0m"
        ;;
        "skyBlue")
            ${echoType} "\033[36m$2 \033[0m"
        ;;
        # 黄色
        "yellow")
            ${echoType} "\033[33m$2 \033[0m"
        ;;
    esac
}
fixBug(){
    if [[ "${release}" = "ubuntu" ]]
    then
        cd /var/lib/dpkg/

    fi
}

# 安装工具包
installTools(){
    # echo "export LC_ALL=en_US.UTF-8"  >>  /etc/profile
    # source /etc/profile
    # kill lock
    if [[ ! -z `ps -ef|grep -v grep|grep apt`  ]]
    then
        ps -ef|grep -v grep|grep apt|awk '{print $2}'|xargs kill -9
    fi

    echoContent yellow "删除Nginx、V2Ray，请等待--->"
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

    if [[ ! -z `find /usr/bin/ -name "v2ray*"` ]]
    then
        if [[ ! -z `ps -ef|grep v2ray|grep -v grep`  ]]
        then
            ps -ef|grep v2ray|grep -v grep|awk '{print $2}'|xargs kill -9
        fi
        rm -rf  /usr/bin/v2ray
    fi

    if [[ ! -z `cat /root/.bashrc|grep -n acme` ]]
    then
        acmeBashrcLine=`cat /root/.bashrc|grep -n acme|awk -F "[:]" '{print $1}'|head -1`
        sed -i "${acmeBashrcLine}d" /root/.bashrc
    fi
    rm -rf /etc/systemd/system/v2ray.service
    if [[ ! -z `find /bin -name "systemctl"` ]]
    then
        systemctl daemon-reload
    else
        echo 'Centos6'
    fi

    #  rm -rf ~/.acme.sh > /dev/null
    echoContent green "  删除完成"

    echoContent skyBlue "检查、安装工具包："

    echoContent green "  更新中，请等待"
    ${upgrade} > /dev/null
    rm -rf /var/run/yum.pid
    echoContent green "更新完毕"

    echoContent yellow "检查、安装wget--->"
    progressTool wget &
    ${installType} wget > /dev/null

    echoContent yellow "检查、安装unzip--->"
    progressTool unzip &
    ${installType} unzip > /dev/null

    # echoContent yellow "检查、安装qrencode--->"
    # progressTool qrencode &
    # ${installType} qrencode > /dev/null

    echoContent yellow "检查、安装socat--->"
    progressTool socat &
    ${installType} socat > /dev/null

    echoContent yellow "检查、安装crontabs--->"
    progressTool crontabs &
    if [[ "${release}" = "ubuntu" ]] || [[ "${release}" = "debian" ]]
    then
        ${installType} cron > /dev/null
    else
        ${installType} crontabs > /dev/null
    fi

    echoContent yellow "检查、安装jq--->"
    progressTool jq &
    ${installType} jq > /dev/null

    # echoContent skyBlue "检查、安装bind-utils--->"
    # progressTool bind-utils
    # 关闭防火墙

}
# 安装Nginx tls证书
installNginx(){
    echoContent skyBlue "检查、安装Nginx、TLS："
    echoContent yellow  "请输入要配置的域名 例：worker.v2ray-agent.com --->"
    rm -rf /etc/nginx/nginx.conf
    read domain
    if [[ -z ${domain} ]]
    then
        echoContent red "  域名不可为空--->"
        installNginx
    else
        # 安装nginx
        echoContent yellow "  检查、安装Nginx--->"
        progressTool nginx &
        ${installType} nginx > /dev/null

        if [[ ! -z `ps -ef|grep -v grep|grep nginx` ]]
        then
            nginx -s stop
            # ps -ef|grep -v grep|grep nginx|awk '{print $2}'|xargs kill -9
        fi

        # 修改配置
        echoContent yellow "修改配置文件--->"


        touch /etc/nginx/conf.d/alone.conf
        # installLine=`cat /etc/nginx/nginx.conf|grep -n root|awk -F "[:]" '{print $1+1}'|head -1`
        # ${installLine}
        # ${domain}
        echo "server {listen 80;server_name ${domain};root /usr/share/nginx/html;location ~ /.well-known {allow all;}location /test {return 200 'fjkvymb6len';}}" > /etc/nginx/conf.d/alone.conf
        # sed -i "1i 1" /etc/nginx/conf.d/alone.conf
        # installLine=`expr ${installLine} + 1`
        # sed -i "${installLine}i location /test {return 200 'fjkvymb6len';}" /etc/nginx/nginx.conf
        # 启动nginx
        nginx

        # 测试nginx
        echoContent yellow "检查Nginx是否正常访问，请等待--->"
        # ${domain}
        domainResult=`curl -s ${domain}/test|grep fjkvymb6len`
        if [[ ! -z ${domainResult} ]]
        then
            echoContent green "  Nginx访问成功--->\n"
            ps -ef|grep nginx|grep -v grep|awk '{print $2}'|xargs kill -9
            installTLS ${domain}
        else
            echoContent red "    无法正常访问服务器，请检测域名是否正确、域名的DNS解析以及防火墙设置是否正确--->"
            exit 0;
        fi
    fi
}
# 安装TLS
installTLS(){
    mkdir -p /etc/nginx/v2ray-agent-https/
    touch /etc/nginx/v2ray-agent-https/config
    mkdir -p /tmp/tls
    if [[ -z `find /tmp -name "$1*"` ]]
    then

        echoContent yellow "安装TLS证书--->"
        echoContent yellow "  安装acme--->"
        curl -s https://get.acme.sh | sh >> /tmp/tls/acme.log
        if [[ -z `find ~/.acme.sh -name "acme.sh"` ]]
        then
            echoContent red "  acme安装失败--->"
            echoContent yellow "错误排查："
            echoContent red "  1.获取Github文件失败，请等待GitHub恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
            echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
            echoContent red "  3.反馈给开发者[私聊：https://t.me/mack_a] 或 [提issues]"
            exit 0
        fi
        echoContent green  "  acme安装完毕--->"
        echoContent yellow "生成TLS证书中，请等待--->"
        sudo ~/.acme.sh/acme.sh --issue -d $1 --standalone -k ec-256 >/dev/null
        ~/.acme.sh/acme.sh --installcert -d $1 --fullchainpath /etc/nginx/v2ray-agent-https/$1.crt --keypath /etc/nginx/v2ray-agent-https/$1.key --ecc >/dev/null
        if [[ -z `cat /etc/nginx/v2ray-agent-https/$1.crt` ]]
        then
            echoContent red "    TLS安装失败，请检查acme日志--->"
            exit 0
        elif [[ -z `cat /etc/nginx/v2ray-agent-https/$1.key` ]]
        then
            echoContent red "    TLS安装失败，请检查acme日志--->"
            exit 0
        fi
        echoContent green "  TLS生成成功--->"
        echo $1 `date +%s` > /etc/nginx/v2ray-agent-https/config

        cp -R /etc/nginx/v2ray-agent-https/config /tmp/tls/config
        cp -R /etc/nginx/v2ray-agent-https/$1.crt /tmp/tls/$1.crt
        cp -R /etc/nginx/v2ray-agent-https/$1.key /tmp/tls/$1.key
        echoContent green "  TLS证书备份成功，证书位置：/tmp/tls--->"
    elif  [[ -z `cat /tmp/tls/$1.crt` ]] || [[ -z `cat /tmp/tls/$1.key` ]]
    then
        echoContent red "    检测到错误证书，需重新生成，重新生成中--->"
        rm -rf /tmp/tls
        installTLS $1
    else
        echoContent yellow "检测到备份证书，使用--->"
        cp -R /tmp/tls/$1.crt /etc/nginx/v2ray-agent-https/$1.crt
        cp -R /tmp/tls/$1.key /etc/nginx/v2ray-agent-https/$1.key
        cp -R /tmp/tls/config /etc/nginx/v2ray-agent-https/config
    fi

    # nginxInstallLine=`cat /etc/nginx/nginx.conf|grep -n "}"|awk -F "[:]" 'END{print $1-1}'`
    # sed -i "${nginxInstallLine}i server {listen 443 ssl;server_name $1;root /usr/share/nginx/html;ssl_certificate /etc/nginx/$1.crt;ssl_certificate_key /etc/nginx/$1.key;ssl_protocols TLSv1 TLSv1.1 TLSv1.2;ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;ssl_prefer_server_ciphers on;location / {} location /alone { proxy_redirect off;proxy_pass http://127.0.0.1:31299;proxy_http_version 1.1;proxy_set_header Upgrade \$http_upgrade;proxy_set_header Connection "upgrade";proxy_set_header X-Real-IP \$remote_addr;proxy_set_header Host \$host;proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;}}" /etc/nginx/nginx.conf

    echo "server {listen 443 ssl;server_name $1;root /usr/share/nginx/html;ssl_certificate /etc/nginx/v2ray-agent-https/$1.crt;ssl_certificate_key /etc/nginx/v2ray-agent-https/$1.key;ssl_protocols TLSv1 TLSv1.1 TLSv1.2;ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;ssl_prefer_server_ciphers on;location / {} location /alone { proxy_redirect off;proxy_pass http://127.0.0.1:31299;proxy_http_version 1.1;proxy_set_header Upgrade \$http_upgrade;proxy_set_header Connection "upgrade";proxy_set_header X-Real-IP \$remote_addr;proxy_set_header Host \$host;proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;}}" > /etc/nginx/conf.d/alone.conf

    # 自定义路径
    echoContent yellow "请输入自定义路径[例: alone]，不需要斜杠，[回车]默认路径"
    read customPath

    if [[ ! -z "${customPath}" ]]
    then
        sed -i "s/alone/${customPath}/g" `grep alone -rl /etc/nginx/conf.d/alone.conf`
    fi

    rm -rf /usr/share/nginx/html
    wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/blog/unable/html.zip >> /dev/null
    unzip  /usr/share/nginx/html.zip -d /usr/share/nginx/html > /dev/null
    nginx
    if [[ -z `ps -ef|grep -v grep|grep nginx` ]]
    then
        echoContent red "  Nginx启动失败，请检查日志--->"
        exit 0
    fi
    echoContent green "  Nginx启动成功，TLS配置成功--->\n"
    # 增加定时任务定时维护证书
    reInstallTLS $1
    installV2Ray $1 ${customPath}
}

# 重新安装&更新tls证书
reInstallTLS(){
    echoContent yellow "添加定时维护证书，请等待--->"
    touch /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh

#    echo '' > /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
#    echo '' > /etc/nginx/v2ray-agent-https/backup_crontab.cron

    touch /etc/nginx/v2ray-agent-https/backup_crontab.cron

    mkdir -p /tmp/tls
    touch /tmp/tls/tls.log
    if [[ -z `crontab -l|grep -v grep|grep 'reloadInstallTLS'` ]]
    then
        echoContent yellow "  未添加定时更新tls证书，添加中，请等待--->"
        crontab -l >> /etc/nginx/v2ray-agent-https/backup_crontab.cron
        # 定时任务
        echo "30 1 * * * /bin/bash /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh" >> /etc/nginx/v2ray-agent-https/backup_crontab.cron
        crontab /etc/nginx/v2ray-agent-https/backup_crontab.cron
    fi
    # 备份

    domain=$1
    echo "#!/usr/bin/env bash" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "domain=${domain}" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "eccPath=\`find ~/.acme.sh -name \"\${domain}_ecc\"|head -1\`" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "mkdir -p /tmp/tls" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "touch /tmp/tls/tls.log" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "touch /tmp/tls/acme.log" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "if [[ ! -z \${eccPath} ]]" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "then" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "modifyTime=\`stat \${eccPath}/\${domain}.key|sed -n '6,6p'|awk '{print \$2\" \"\$3\" \"\$4\" \"\$5}'\`" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "modifyTime=\`date +%s -d \"\${modifyTime}\"\`" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "currentTime=\`date +%s\`" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "stampDiff=\`expr \${currentTime} - \${modifyTime}\`" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "minutes=\`expr \${stampDiff} / 60\`" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "status=\"正常\"" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "reloadTime=\"暂无\"" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "if [[ ! -z \${modifyTime} ]] && [[ ! -z \${currentTime} ]] && [[ ! -z \${stampDiff} ]] && [[ ! -z \${minutes} ]] && [[ \${minutes} -lt '120' ]]" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "then" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "nginx -s stop" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "~/.acme.sh/acme.sh --installcert -d \${domain} --fullchainpath /etc/nginx/v2ray-agent-https/\${domain}.crt --keypath /etc/nginx/v2ray-agent-https/\${domain}.key --ecc >> /tmp/tls/acme.log" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "nginx" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "reloadTime=\`date -d @\${currentTime} +\"%F %H:%M:%S\"\`" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "fi" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "echo \"域名：\${domain}，modifyTime:\"\`date -d @\${modifyTime} +\"%F %H:%M:%S\"\`,\"检查时间:\"\`date -d @\${currentTime} +\"%F %H:%M:%S\"\`,"上次生成证书的时:"\`expr \${minutes} / 1440\`\"天前\",\"证书状态：\"\${status},\"重新生成日期：\"\${reloadTime} >> /tmp/tls/tls.log" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "else" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "echo '无法找到证书路径' >> /tmp/tls/tls.log" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo "fi" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh

    if [[ ! -z `crontab -l|grep -v grep|grep 'reloadInstallTLS'` ]]
    then
        echoContent green "  添加定时维护证书成功"
    else
        crontab -l >> /etc/nginx/v2ray-agent-https/backup_crontab.cron
        # 定时任务
        crontab /etc/nginx/v2ray-agent-https/backup_crontab.cron
        echoContent green "  检测到已添加定时任务，继续使用"
    fi
}
# V2Ray
installV2Ray(){
    if [[ -z `find /tmp -name "v2ray*"` ]]
    then
        if [[ -z `find /usr/bin/ -name "v2ray*"` ]]
        then
            echoContent yellow "\n安装V2Ray--->"
            version=`curl -s https://github.com/v2ray/v2ray-core/releases|grep /v2ray/v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
            echoContent green "  v2ray-core版本:${version}"
            mkdir -p /tmp/v2ray
            mkdir -p /usr/bin/v2ray/
            wget -q -P /tmp/v2ray https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip
            unzip /tmp/v2ray/v2ray-linux-64.zip -d /tmp/v2ray > /dev/null
            cp /tmp/v2ray/v2ray /usr/bin/v2ray/
            cp /tmp/v2ray/v2ctl /usr/bin/v2ray/
            rm -rf /tmp/v2ray/v2ray-linux-64.zip
        fi
        echoContent green "  V2Ray安装成功--->"
    else
         echoContent yellow "\n检测到V2Ray安装程序，使用--->\n"
         mkdir -p /usr/bin/v2ray/
         cp /tmp/v2ray/v2ray /usr/bin/v2ray/ && cp /tmp/v2ray/v2ctl /usr/bin/v2ray/
    fi
    if [[ ! -z `find /bin -name "systemctl"` ]]
    then
        installV2RayService
    fi

    initV2RayConfig $2
    if [[ ! -z `find /bin -name "systemctl"` ]]
    then
        systemctl daemon-reload
        systemctl enable v2ray.service
        systemctl start  v2ray.service
    else
        /usr/bin/v2ray/v2ray -config /etc/v2ray/config.json &
    fi


    if [[ -z `ps -ef|grep v2ray|grep -v grep` ]]
    then
        echoContent red "    V2Ray启动失败，请检查日志后，重新执行脚本--->"
        exit 0;
    fi
    echoContent green "  V2Ray启动成功--->\n"
    echoContent yellow "V2Ray日志目录："
    echoContent green "  access:  /tmp/v2ray/v2ray_access_ws_tls.log"
    echoContent green "  error:  /tmp/v2ray/v2ray_error_ws_tls.log"

    # 验证整个服务是否可用
    echoContent yellow "验证服务是否可用--->"
    sleep 0.5
    nginxPath=$2;
    if [[ -z "${nginxPath}" ]]
    then
        nginxPath="alone"
    fi

    echo "https://$1/${nginxPath}"
    if [[ ! -z `curl -s -L https://$1/${nginxPath}|grep -v grep|grep "Bad Request"` ]]
    then
        echoContent green "  服务可用--->\n"
    else

        echoContent red "  服务不可用，请检查Cloudflare->域名->SSL/TLS->Overview->Your SSL/TLS encryption mode is 是否是Full--->"
        echoContent red "  错误日志:`curl -s -L https://$1/${nginxPath}`"
        exit 0
    fi
    qrEncode $1
    echoContent yellow "监听V2Ray日志中，请使用上方生成的vmess访问，如有日志出现则证明线路可用，退出监听也无妨，Ctrl+c退出监听日志，--->"
    echo '' > /tmp/v2ray/v2ray_access_ws_tls.log
    tail -f /tmp/v2ray/v2ray_access_ws_tls.log
}
# 开机自启
installV2RayService(){
    echoContent skyBlue "  配置V2Ray开机自启--->"
    mkdir -p /etc/systemd/system/
    rm -rf /etc/systemd/system/v2ray.service
    touch /etc/systemd/system/v2ray.service

    echo '[Unit]' >> /etc/systemd/system/v2ray.service
    echo 'Description=V2Ray - A unified platform for anti-censorship' >> /etc/systemd/system/v2ray.service
    echo 'Documentation=https://v2ray.com https://guide.v2fly.org' >> /etc/systemd/system/v2ray.service
    echo 'After=network.target nss-lookup.target' >> /etc/systemd/system/v2ray.service
    echo 'Wants=network-online.target' >> /etc/systemd/system/v2ray.service
    echo '' >> /etc/systemd/system/v2ray.service
    echo '[Service]' >> /etc/systemd/system/v2ray.service
    echo 'Type=simple' >> /etc/systemd/system/v2ray.service
    echo 'User=root' >> /etc/systemd/system/v2ray.service
    echo 'CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW' >> /etc/systemd/system/v2ray.service
    echo 'NoNewPrivileges=yes' >> /etc/systemd/system/v2ray.service
    echo 'ExecStart=/usr/bin/v2ray/v2ray -config /etc/v2ray/config.json' >> /etc/systemd/system/v2ray.service
    echo 'Restart=on-failure' >> /etc/systemd/system/v2ray.service
    echo 'RestartPreventExitStatus=23' >> /etc/systemd/system/v2ray.service
    echo '' >> /etc/systemd/system/v2ray.service
    echo '' >> /etc/systemd/system/v2ray.service
    echo '[Install]' >> /etc/systemd/system/v2ray.service
    echo 'WantedBy=multi-user.target' >> /etc/systemd/system/v2ray.service
    echoContent green "  配置V2Ray开机自启成功--->"
}

# 初始化V2Ray 配置文件
initV2RayConfig(){
    mkdir -p /etc/v2ray/
    touch /etc/v2ray/config.json
    uuid=`/usr/bin/v2ray/v2ctl uuid`

    # 自定义IPLC端口
    if [[ ! -z ${iplc} ]]
    then
        echo '{"log":{"access":"/tmp/v2ray/v2ray_access_ws_tls.log","error":"/tmp/v2ray/v2ray_error_ws_tls.log","loglevel":"debug"},"stats":{},"api":{"services":["StatsService"],"tag":"api"},"policy":{"levels":{"1":{"handshake":4,"connIdle":300,"uplinkOnly":2,"downlinkOnly":5,"statsUserUplink":false,"statsUserDownlink":false}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}},"allocate":{"strategy":"always","refresh":5,"concurrency":3},"inbounds":[{"port":31299,"protocol":"vmess","settings":{"clients":[{"id":"654765fe-5fb1-271f-7c3f-18ed82827f72","alterId":64,"level":1,"email":"test@v2ray.com"}]},"streamSettings":{"network":"ws","wsSettings":{"path":"/alone"}}},{"port":31294,"protocol":"vmess","settings":{"clients":[{"id":"ab11e002-7008-ef16-4363-217aea8dc81c","alterId":64,"level":1,"email":"HK_深港0.35x IPLC@v2ray.com"},{"id":"246d748a-dd07-2172-a397-ab110aa5ad2a","alterId":64,"level":1,"email":"HK_莞港IPLC@v2ray.com"}]}}],"outbounds":[{"protocol":"freedom","settings":{"OutboundConfigurationObject":{"domainStrategy":"AsIs","userLevel":0}}}],"routing":{"settings":{"rules":[{"inboundTag":["api"],"outboundTag":"api","type":"field"}]},"strategy":"rules"},"dns":{"servers":["8.8.8.8","8.8.4.4"],"tag":"dns_inbound"}}' > /etc/v2ray/config.json
    else
        echo '{"log":{"access":"/tmp/v2ray/v2ray_access_ws_tls.log","error":"/tmp/v2ray/v2ray_error_ws_tls.log","loglevel":"debug"},"stats":{},"api":{"services":["StatsService"],"tag":"api"},"policy":{"levels":{"1":{"handshake":4,"connIdle":300,"uplinkOnly":2,"downlinkOnly":5,"statsUserUplink":false,"statsUserDownlink":false}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}},"allocate":{"strategy":"always","refresh":5,"concurrency":3},"inbounds":[{"port":31299,"protocol":"vmess","settings":{"clients":[{"id":"654765fe-5fb1-271f-7c3f-18ed82827f72","alterId":64,"level":1,"email":"test@v2ray.com"}]},"streamSettings":{"network":"ws","wsSettings":{"path":"/alone"}}}],"outbounds":[{"protocol":"freedom","settings":{"OutboundConfigurationObject":{"domainStrategy":"AsIs","userLevel":0}}}],"routing":{"settings":{"rules":[{"inboundTag":["api"],"outboundTag":"api","type":"field"}]},"strategy":"rules"},"dns":{"servers":["8.8.8.8","8.8.4.4"],"tag":"dns_inbound"}}' > /etc/v2ray/config.json
    fi
    # 自定义路径
    if [[ ! -z "$1" ]]
    then
        sed -i "s/alone/${1}/g" `grep alone -rl /etc/v2ray/config.json`
    else
        sed -i "s/654765fe-5fb1-271f-7c3f-18ed82827f72/${uuid}/g" `grep 654765fe-5fb1-271f-7c3f-18ed82827f72 -rl /etc/v2ray/config.json`
    fi

}
qrEncode(){
    user=`cat /etc/v2ray/config.json|jq .inbounds[0]`
    ps="$1"
    id=`echo ${user}|jq .settings.clients[0].id`
    aid=`echo ${user}|jq .settings.clients[0].alterId`
    host="$1"
    add="$1"
    path=`echo ${user}|jq .streamSettings.wsSettings.path`
    echoContent green '是否使用DNS智能解析进行自定义CDN IP？'
    echoContent yellow " 智能DNS提供一下自定义CDN IP，会根据运营商自动切换ip，测试结果请查看[https://github.com/mack-a/v2ray-agent/blob/master/optimize_V2Ray.md]"
    echoContent yellow "   移动:1.0.0.1"
    echoContent yellow "   联通:www.digitalocean.com"
    echoContent yellow "   电信:www.digitalocean.com"
    echoContent yellow '输入[y]使用，[任意]不使用'
    read dnsProxy
    if [[ "${dnsProxy}" = "y" ]]
    then
        add="domain07.qiu4.ml"
    fi
    echoContent yellow "客户端链接--->\n"
    qrCodeBase64Default=`echo -n '{"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"64","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'"}'|sed 's#/#\\\/#g'|base64`
    qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
    # 通用Vmess
    echoContent red "通用vmess链接--->"
    echoContent green "    vmess://${qrCodeBase64Default}\n"
    echo "通用vmess链接: " > /etc/v2ray/usersv2ray.conf
    echo "   vmess://${qrCodeBase64Default}" >> /etc/v2ray/usersv2ray.conf
    echoContent red "通用json--->"
    echoContent green '    {"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"64","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'"}\n'

    # Quantumult
    qrCodeBase64Quanmult=`echo -n ''${ps}' = vmess, '${add}', 443, aes-128-cfb, '${id}', over-tls=true, tls-host='${host}', certificate=1, obfs=ws, obfs-path='${path}', obfs-header="Host: '${host}'[Rr][Nn]User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 11_2_6 like Mac OS X) AppleWebKit/604.5.6 (KHTML, like Gecko) Mobile/15D100"'|base64`
    qrCodeBase64Quanmult=`echo ${qrCodeBase64Quanmult}|sed 's/ //g'`

    echoContent red "Quantumult vmess--->"
    echoContent green "    vmess://${qrCodeBase64Quanmult}\n"
    echo '' >> /etc/v2ray/usersv2ray.conf
    echo "Quantumult:" >> /etc/v2ray/usersv2ray.conf
    echo "  vmess://${qrCodeBase64Quanmult}" >> /etc/v2ray/usersv2ray.conf
    echoContent red "Quantumult 明文--->"
    echoContent green  '    '${ps}' = vmess, '${add}', 443, aes-128-cfb, '${id}', over-tls=true, tls-host='${host}', certificate=1, obfs=ws, obfs-path='${path}', obfs-header="Host: '${host}'[Rr][Nn]User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 11_2_6 like Mac OS X) AppleWebKit/604.5.6 (KHTML, like Gecko) Mobile/15D100"'
    # | qrencode -t UTF8
    # echo ${qrCodeBase64}
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
            printf '\b%s' "${sp:i++%n:1}"
        else
            break;
        fi
        sleep 0.1
    done
    echoContent green "  $1已安装--->"
}
# 卸载安装的内容
removeInstall(){
    rm -rf /tmp/v2ray
    rm -rf /tmp/tls
    rm -rf /etc/v2ray
    rm -rf /root/.acme.sh
    echo ${removeType},${installType}
    `${removeType} nginx` > /dev/null 2>&1
}
init(){
    cd
    echoContent red "=============================================================="
    echoContent red "脚本概述"
    echoContent green "欢迎使用Cloudflare+WebSocket+TLS+Nginx+伪装博客 一键脚本"
    echo
    echoContent green "作者：mack-a [https://t.me/mack_a]"
    echo
    echoContent green "Version：v1.0.1"
    echo
    echoContent green "Github：https://github.com/mack-a/v2ray-agent"
    echo
    echoContent green "TG：https://t.me/technologyshare"
    echo
    echoContent green "如遇到解决不了的问题可以提issues或者直接私聊作者，欢迎聊骚"
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
    mkdir -p /usr/bin/v2ray
    mkdir -p /etc/v2ray/
    v2rayStatus=0
    if [[ ! -z `ls -F /usr/bin/v2ray/|grep "v2ray"` ]] && [[ ! -z `find /etc/v2ray/ -name "config.json"` ]]
    then
        v2rayVersion=`/usr/bin/v2ray/v2ray -version|awk '{print $2}'|head -1`
        v2rayStatus=1
        echoContent yellow "    version：${v2rayVersion}"
        echoContent yellow "    安装路径：/usr/bin/v2ray/"
        echoContent yellow "    配置文件：/etc/v2ray/config.json"
        echoContent yellow "    日志路径："
        echoContent yellow "      access:  /tmp/v2ray/v2ray_access_ws_tls.log"
        echoContent yellow "      error:  /tmp/v2ray/v2ray_error_ws_tls.log"
    else
        echoContent yellow "    暂未安装"
    fi
    tlsStatus=0
    echoContent green "\nTLS证书状态："
    mkdir -p /etc/nginx/v2ray-agent-https/
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
        echoContent yellow "    定时任务日志路径：/tmp/tls/tls.log"
        echoContent yellow "    acme.sh日志路径：/tmp/tls/acme.log"
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
    elif [[ ! -z `find /usr/bin/v2ray/ -name 'v2ray'` ]]
    then
        echoContent yellow "    V2Ray:【未运行】，执行【/usr/bin/v2ray/v2ray -config /etc/v2ray/config.json &】运行"
    else
        echoContent yellow "    V2Ray:【未安装】"
    fi


    echoContent red "=============================================================="
    echoContent red "注意事项："
    echoContent green "    1.脚本会检查并安装工具包"
    echoContent green "    2.如果使用此脚本生成过TLS证书、V2Ray，会继续使用上次生成、安装的内容。"
    echoContent green "    3.会删除、卸载已经安装的应用，包括V2Ray、Nginx。"
    echoContent green "    4.如果显示Nginx不可用，请检查防火墙端口是否开放。"
    echoContent green "    5.证书会在每天的1点30分检查更新"
    echoContent green "    6.重启机器后，日志、缓存文件会被删除，不影响正常使用【tls更新日志、缓存|V2Ray执行文件、日志】"
    echoContent red "=============================================================="
    echoContent red "错误处理【这里请仔细阅读】"
    echoContent yellow "Debian："
    echoContent green "     错误1：WARNING: apt does not have a stable CLI interface. Use with caution in scripts.【这个错误无需处理】"
    echoContent green "     错误2：如果错误很多，且安装失败，则需要重启vps，无需重新安装OS。这种情况是在安装过程中意外断开导致。"
    echoContent red "=============================================================="
    installSelect=0
    if [[ ${tlsStatus} = "1" ]] && [[ ${v2rayStatus} = "1" ]]
    then
        echoContent green "检测到已使用本脚本安装"
        echoContent yellow "    1.重新安装【使用缓存的文件（TLS证书、V2Ray）】"
        echoContent yellow "    2.完全重装【会清理tmp缓存文件（TLS证书、V2Ray）】"
    else
        echoContent green "未监测到使用本脚本安装"
        echoContent yellow "    1.安装【未安装】"
        echoContent yellow "    2.完全安装【会清理tmp缓存文件（TLS证书、V2Ray）】"
    fi

    echoContent yellow "    3.BBR安装[推荐BBR+FQ 或者 BBR+Cake]"
    echoContent yellow "    4.完全卸载[清理Nginx、TLS证书、V2Ray、acme.sh]"
    echoContent red "=============================================================="
    echoContent green "请输入上列数字，[任意]结束："
    read installStatus

    if [[ "${installStatus}" = "1" ]]
    then
        rm -rf /etc/v2ray/usersv2ray.conf
        installTools
        installNginx
    elif [[ "${installStatus}" = "2" ]]
    then
        rm -rf /tmp/v2ray
        rm -rf /tmp/tls
        rm -rf /etc/v2ray/usersv2ray.conf
        installTools
        installNginx
    elif [[ "${installStatus}" = "3" ]]
    then
        echoContent red "=============================================================="
        echoContent green "BBR脚本用的[ylx2016]的成熟作品，地址[https://github.com/ylx2016/Linux-NetSpeed/releases/download/sh/tcp.sh]，请熟知"
        echoContent red "    1.安装"
        echoContent red "    2.回退主目录"
        echoContent red "=============================================================="
        echoContent green "请输入[1]安装，[2]回到上层目录"
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
        echoContent yellow "卸载完成"
        exit 0;
    else
        echoContent yellow "欢迎下次使用--->"
        exit 0;
    fi
}

checkSystem(){

	if [[ ! -z `find /etc -name "redhat-release"` ]] || [[ ! -z `cat /proc/version | grep -i "centos" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "red hat" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "redhat" | grep -v grep ` ]]
	then
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
        exit 0;
    fi
}
checkSystem
init
