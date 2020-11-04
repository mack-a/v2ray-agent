#!/usr/bin/env bash

installType='yum -y install'
removeType='yum -y remove'
upgrade="yum -y update"
echoType='echo -e'
domain=
add=
globalType=
customPath=alone
centosVersion=0
totalProgress=1
iplc=$1
uuid=
uuidDirect=
newUUID=
newDirectUUID=
customInstallType=

# trap 'onCtrlC' INT
# function onCtrlC () {
#     echo
#     killSleep > /dev/null 2>&1
#     exit;
# }
# echo颜色方法
echoContent(){
    case $1 in
        # 红色
        "red")
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
        "skyBlue")
            ${echoType} "\033[36m${printN}$2 \033[0m"
        ;;
        # 黄色
        "yellow")
            ${echoType} "\033[33m${printN}$2 \033[0m"
        ;;
    esac
}
# 新建目录
mkdirTools(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 创建文件夹"
    mkdir -p /etc/v2ray-agent/tls
    mkdir -p /etc/v2ray-agent/v2ray/conf
    mkdir -p /etc/v2ray-agent/trojan
    mkdir -p /etc/systemd/system/
    mkdir -p /tmp/v2ray-agent-tls/
}
# 创建基础的文件目录
mkdirBaseDIR(){
    mkdir -p /etc/v2ray-agent
}
# 安装工具包
installTools(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装工具"
    if [[ "${release}" = "centos" ]]
    then
        echoContent green " ---> 检查安装jq、nginx epel源、yum-utils"
        # jq epel源
        if [[ -z `command -v jq` ]]
        then
            rpm -ivh http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm > /dev/null 2>&1
        fi

        nginxEpel=""
        if [[ ! -z `rpm -qa|grep -v grep|grep nginx` ]]
        then
            local nginxVersion=`rpm -qa|grep -v grep|grep nginx|head -1|awk -F '[-]' '{print $2}'`;
            if [[ `echo ${nginxVersion}|awk -F '[.]' '{print $1}'` < 1 ]] && [[ `echo ${nginxVersion}|awk -F '[.]' '{print $2}'` < 17 ]]
            then
                rpm -qa|grep -v grep|grep nginx|xargs rpm -e > /dev/null 2>&1
            fi
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
        rpm -ivh ${nginxEpel} > /etc/v2ray-agent/error.log 2>&1

        # yum-utils
        if [[ "${centosVersion}" = "8" ]]
        then
            upgrade="yum update -y --skip-broken --nobest"
            installType="yum -y install --nobest"
            ${installType} yum-utils > /etc/v2ray-agent/error.log 2>&1
        else
            ${installType} yum-utils > /etc/v2ray-agent/error.log 2>&1
        fi

    fi
    # 修复ubuntu个别系统问题
    if [[ "${release}" = "ubuntu" ]]
    then
        dpkg --configure -a
    fi

    if [[ ! -z `ps -ef|grep -v grep|grep apt`  ]]
    then
        ps -ef|grep -v grep|grep apt|awk '{print $2}'|xargs kill -9
    fi

    echoContent green " ---> 检查、安装更新【新机器会很慢，耐心等待】"
    # if [[ "${release}" = "centos" ]]
    # then
    #    yum-complete-transaction --cleanup-only
    # fi
    ${upgrade} > /dev/null
    if [[ "${release}" = "centos" ]]
    then
        rm -rf /var/run/yum.pid
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w wget` ]]
    then
        echoContent green " ---> 安装wget"
        ${installType} wget > /dev/null
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w curl` ]]
    then
        echoContent green " ---> 安装curl"
        ${installType} curl > /dev/null
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w unzip` ]]
    then
        echoContent green " ---> 安装unzip"
        ${installType} unzip > /dev/null
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w socat` ]]
    then
        echoContent green " ---> 安装socat"
        ${installType} socat > /dev/null
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w tar` ]]
    then
        echoContent green " ---> 安装tar"
        ${installType} tar > /dev/null
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep cron` ]]
    then
        echoContent green " ---> 安装crontabs"
        if [[ "${release}" = "ubuntu" ]] || [[ "${release}" = "debian" ]]
        then
            ${installType} cron > /dev/null
        else
            ${installType} crontabs > /dev/null
        fi
    fi
    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w jq` ]]
    then
        echoContent green " ---> 安装jq"
        ${installType} jq > /dev/null
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep binutils` ]]
    then
        echoContent green " ---> 安装binutils"
        ${installType} binutils > /dev/null  2>&1
    fi
    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w nginx` ]]
    then
        echoContent green " ---> 安装nginx"
        ${installType} nginx > /dev/null
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w sudo` ]]
    then
        echoContent green " ---> 安装sudo"
        ${installType} sudo > /dev/null
    fi
    # todo 关闭防火墙

    # 新建所需目录
    # mkdirTools

    if [[ ! -d "/root/.acme.sh" ]]
    then
        echoContent green " ---> 安装acme.sh"
        curl -s https://get.acme.sh | sh > /etc/v2ray-agent/tls/acme.log
        if [[ -d "~/.acme.sh" ]] && [[ -z `ls -F ~/.acme.sh/|grep -w "acme.sh"` ]]
        then
            echoContent red "  acme安装失败--->"
            echoContent yellow "错误排查："
            echoContent red "  1.获取Github文件失败，请等待GitHub恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
            echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
            echoContent red "  3.反馈给开发者[私聊：https://t.me/mack_a] 或 [提issues]"
            exit 0
        fi
    fi
    if [[ -d "/root/.acme.sh" ]] && [[ -z `find /root/.acme.sh/ -name "acme.sh"` ]]
    then
        echoContent green " ---> 安装acme.sh"
        curl -s https://get.acme.sh | sh > /etc/v2ray-agent/tls/acme.log
        if [[ -d "~/.acme.sh" ]] && [[ -z `find /root/.acme.sh/ -name "acme.sh"` ]]
        then
            echoContent red "  acme安装失败--->"
            echoContent yellow "错误排查："
            echoContent red "  1.获取Github文件失败，请等待GitHub恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
            echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
            echoContent red "  3.反馈给开发者[私聊：https://t.me/mack_a] 或 [提issues]"
            exit 0
        fi
    fi
}
# 初始化Nginx申请证书配置
initTLSNginxConfig(){
    handleNginx stop
    echoContent skyBlue "\n进度  $1/${totalProgress} : 初始化Nginx申请证书配置"
    echoContent yellow  "请输入要配置的域名 例：blog.v2ray-agent.com --->"
    read -p "域名:" domain
    if [[ -z ${domain} ]]
    then
        echoContent red "  域名不可为空--->"
        initTLSNginxConfig
    else
        # 修改配置
        echoContent green " ---> 配置Nginx"
        touch /etc/nginx/conf.d/alone.conf
        echo "server {listen 80;server_name ${domain};root /usr/share/nginx/html;location ~ /.well-known {allow all;}location /test {return 200 'fjkvymb6len';}}" > /etc/nginx/conf.d/alone.conf
        # 启动nginx
        handleNginx start
        echoContent yellow "\n检查IP是否设置为当前VPS"
        checkIP
        # 测试nginx
        echoContent yellow "\n检查Nginx是否正常访问"
        domainResult=`curl -s ${domain}/test|grep fjkvymb6len`
        if [[ ! -z ${domainResult} ]]
        then
            handleNginx stop
            echoContent green " ---> Nginx配置成功"
        else
            echoContent red " ---> 无法正常访问服务器，请检测域名是否正确、域名的DNS解析以及防火墙设置是否正确--->"
            exit 0;
        fi
    fi
}
# 检查ip
checkIP(){
    pingIP=`ping -c 1 -W 1000 ${domain}|sed '1{s/[^(]*(//;s/).*//;q;}'`
    if [[ ! -z "${pingIP}" ]] && [[ `echo ${pingIP}|grep '^\([1-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)\.\([0-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)\.\([0-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)\.\([0-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)$'` ]]
    then
        read -p "当前域名的IP为 [${pingIP}]，是否正确[y/n]？" domainStatus
        if [[ "${domainStatus}" = "y" ]]
        then
            echoContent green "\n ---> IP确认完成"
        else
            echoContent red "\n ---> 1.检查Cloudflare DNS解析是否正常"
            echoContent red " ---> 2.检查Cloudflare DNS云朵是否为灰色\n"
            exit 0;
        fi
    else
        read -p "IP查询失败，是否重试[y/n]？" retryStatus
        if [[ "${retryStatus}" = "y" ]]
        then
            checkIP
        else
            exit 0;
        fi
    fi
}
# 安装TLS
installTLS(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 申请TLS证书"
    if [[ -z `find /etc/v2ray-agent/tls/ -name "${domain}*"` ]]
    then
        echoContent green " ---> 安装TLS证书"

        sudo ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 >/dev/null
        ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/v2ray-agent/tls/${domain}.crt --keypath /etc/v2ray-agent/tls/${domain}.key --ecc >/dev/null
        if [[ -z `cat /etc/v2ray-agent/tls/${domain}.crt` ]]
        then
            echoContent red " ---> TLS安装失败，请检查acme日志"
            exit 0
        elif [[ -z `cat /etc/v2ray-agent/tls/${domain}.key` ]]
        then
            echoContent red " ---> TLS安装失败，请检查acme日志"
            exit 0
        fi
        echoContent green " ---> TLS生成成功"
        # 记录证书生成的时间
        # echo ${domain} `date +%s` > /etc/v2ray-agent/tls/config
    elif  [[ -z `cat /etc/v2ray-agent/tls/${domain}.crt` ]] || [[ -z `cat /etc/v2ray-agent/tls/${domain}.key` ]]
    then
        echoContent yellow " ---> 检测到错误证书，需重新生成，重新生成中"
        rm -rf /etc/v2ray-agent/tls/*
        installTLS $1
    else
        echoContent green " ---> 检测到证书"
        echoContent yellow " ---> 如未过期请选择[n]"
        read -p "是否重新生成？[y/n]:" reInstalTLStatus
        if [[ "${reInstalTLStatus}" = "y" ]]
        then
            rm -rf /etc/v2ray-agent/tls/*
            installTLS $1
        fi
    fi
}
# 配置伪装博客
initNginxConfig(){
    echoContent skyBlue "\n进度  $2/${totalProgress} : 配置Nginx"
    installType=$1

   if [[ "${installType}" = "vlesstcpws" ]]
    then
        cat << EOF > /etc/nginx/conf.d/alone.conf
server {
    listen 80;
    server_name ${domain};
    root /usr/share/nginx/html;
    location ~ /.well-known {allow all;}
    location /test {return 200 'fjkvymb6len';}
}
EOF
    fi
}
# 自定义/随机路径
randomPathFunction(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 生成随机路径"
    echoContent yellow "请输入自定义路径[例: alone]，不需要斜杠，[回车]随机路径"
    read -p '路径:' customPath

    if [[ -z "${customPath}" ]]
    then
        customPath=`head -n 50 /dev/urandom|sed 's/[^a-z]//g'|strings -n 4|tr 'A-Z' 'a-z'|head -1`
    fi
    echoContent yellow "path：${customPath}"
}
# Nginx伪装博客
nginxBlog(){
#    echoContent yellow "添加伪装博客--->"
    echoContent skyBlue "\n进度 $1/${totalProgress} : 添加伪装博客"
    rm -rf /usr/share/nginx/html
    wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html.zip > /dev/null
    unzip -o  /usr/share/nginx/html.zip -d /usr/share/nginx/html > /dev/null
    echoContent green " ---> 添加伪装博客成功"
}
# 操作Nginx
handleNginx(){
    if [[ -z `ps -ef|grep -v grep|grep nginx` ]] && [[ "$1" = "start" ]]
    then
        nginx
        sleep 0.5
        if [[ -z `ps -ef|grep -v grep|grep nginx` ]]
        then
            echoContent red " ---> Nginx启动失败，请检查日志"
            exit 0
        fi
    elif [[  "$1" = "stop" ]] && [[ ! -z `ps -ef|grep -v grep|grep nginx` ]]
    then
        nginx -s stop > /dev/null 2>&1
        sleep 0.5
        if [[ ! -z `ps -ef|grep -v grep|grep nginx` ]]
        then
            ps -ef|grep -v grep|grep nginx|awk '{print $2}'|xargs kill -9
        fi
    fi
}
# 定时任务更新tls证书
installCronTLS(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 添加定时维护证书"
    if [[ -z `crontab -l|grep -v grep|grep 'reloadInstallTLS'` ]]
    then
        crontab -l >> /etc/v2ray-agent/backup_crontab.cron
        # 定时任务
        echo "30 1 * * * /bin/bash /etc/v2ray-agent/reloadInstallTLS.sh" >> /etc/v2ray-agent/backup_crontab.cron
        crontab /etc/v2ray-agent/backup_crontab.cron
    fi
    # 备份

    cat << EOF > /etc/v2ray-agent/reloadInstallTLS.sh
#!/usr/bin/env bash
echoContent(){
    case \$1 in
        # 红色
        "red")
            echo -e "\033[31m\${printN}\$2 \033[0m"
        ;;
        # 天蓝色
        "skyBlue")
            echo -e "\033[1;36m\${printN}\$2 \033[0m"
        ;;
        # 绿色
        "green")
            echo -e "\033[32m\${printN}\$2 \033[0m"
        ;;
        # 白色
        "white")
            echo -e "\033[37m\${printN}\$2 \033[0m"
        ;;
        "magenta")
            echo -e "\033[31m\${printN}\$2 \033[0m"
        ;;
        "skyBlue")
            echo -e "\033[36m\${printN}\$2 \033[0m"
        ;;
        # 黄色
        "yellow")
            echo -e "\033[33m\${printN}\$2 \033[0m"
        ;;
    esac
}
echoContent skyBlue "\n进度  1/1 : 更新证书"
if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]] && [[ -d "/etc/v2ray-agent/tls" ]] && [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]] && [[ -f "/etc/v2ray-agent/v2ray/config_full.json" ]] && [[ -d "/root/.acme.sh" ]]
then
    tcp=\`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[0]\`
    host=\`echo \${tcp}|jq .streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print \$2}'|awk -F '["]' '{print \$1}'|awk -F '[.][c][r][t]' '{print \$1}'\`
    if [[ -d "/root/.acme.sh/\${host}_ecc" ]] && [[ -f "/root/.acme.sh/\${host}_ecc/\${host}.key" ]] && [[ -f "/root/.acme.sh/\${host}_ecc/\${host}.cer" ]]
    then
        modifyTime=\`stat /root/.acme.sh/\${host}_ecc/\${host}.key|sed -n '6,6p'|awk '{print \$2" "\$3" "\$4" "\$5}'\`

        modifyTime=\`date +%s -d "\${modifyTime}"\`
        currentTime=\`date +%s\`
#        currentTime=\`date +%s -d "2021-09-04 02:15:56.438105732 +0000"\`
#        currentTIme=1609459200
        stampDiff=\`expr \${currentTime} - \${modifyTime}\`
        days=\`expr \${stampDiff} / 86400\`
        remainingDays=\`expr 90 - \${days}\`
        tlsStatus=\${remainingDays}
        if [[ \${remainingDays} -le 0 ]]
        then
            tlsStatus="已过期"
        fi
        echoContent skyBlue " ---> 证书生成日期:"\`date -d @\${modifyTime} +"%F %H:%M:%S"\`
        echoContent skyBlue " ---> 证书生成天数:"\${days}
        echoContent skyBlue " ---> 证书剩余天数:"\${tlsStatus}
        if [[ \${remainingDays} -le 1 ]]
        then
            echoContent yellow " ---> 重新生成证书"
            if [[ \`ps -ef|grep -v grep|grep nginx\` ]]
            then
                nginx -s stop
            fi
            sudo ~/.acme.sh/acme.sh --installcert -d \${host} --fullchainpath /etc/v2ray-agent/tls/\${host}.crt --keypath /etc/v2ray-agent/tls/\${host}.key --ecc >> /etc/v2ray-agent/tls/acme.log
            nginx
            if [[ \`ps -ef|grep -v grep|grep nginx\` ]]
            then
                echoContent green " ---> nginx启动成功"
            else
                echoContent red " ---> nginx启动失败，请检查[/etc/v2ray-agent/tls/acme.log]"
            fi
        else
            echoContent green " ---> 证书有效"
        fi
    else
        echoContent red " ---> 无法找到相应路径，请使用脚本重新安装"
    fi
else
    echoContent red " ---> 无法找到相应路径，请使用脚本重新安装"
fi
EOF
    if [[ ! -z `crontab -l|grep -v grep|grep 'reloadInstallTLS'` ]]
    then
        echoContent green " ---> 添加定时维护证书成功"
    else
        crontab -l >> /etc/v2ray-agent/backup_crontab.cron
        # 定时任务
        crontab /etc/v2ray-agent/backup_crontab.cron
        echoContent green " ---> 添加定时维护证书成功"
    fi
}
# 更新证书
renewalTLS(){
    echoContent skyBlue "\n进度  1/1 : 更新证书"
    if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]] && [[ -d "/etc/v2ray-agent/tls" ]] && [[ -d "/root/.acme.sh" ]]
    then
        if [[ ! -z "${customInstallType}" ]] || [[ -f "/etc/v2ray-agent/v2ray/config_full.json" ]]
        then
            tcp=`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[0]`
            if [[ -d "/etc/v2ray-agent/v2ray/conf" ]] && [[ -f "/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json" ]]
            then
                tcp=`cat /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json|jq .inbounds[0]`
            fi

            host=`echo ${tcp}|jq .streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`
            if [[ -d "/root/.acme.sh/${host}_ecc" ]] && [[ -f "/root/.acme.sh/${host}_ecc/${host}.key" ]] && [[ -f "/root/.acme.sh/${host}_ecc/${host}.cer" ]]
            then
                modifyTime=`stat /root/.acme.sh/${host}_ecc/${host}.key|sed -n '6,6p'|awk '{print $2" "$3" "$4" "$5}'`

                modifyTime=`date +%s -d "${modifyTime}"`
                currentTime=`date +%s`
        #        currentTime=`date +%s -d "2021-09-04 02:15:56.438105732 +0000"`
        #        currentTIme=1609459200
                stampDiff=`expr ${currentTime} - ${modifyTime}`
                days=`expr ${stampDiff} / 86400`
                remainingDays=`expr 90 - ${days}`
                tlsStatus=${remainingDays}
                if [[ ${remainingDays} -le 0 ]]
                then
                    tlsStatus="已过期"
                fi
                echoContent skyBlue " ---> 证书生成日期:"`date -d @${modifyTime} +"%F %H:%M:%S"`
                echoContent skyBlue " ---> 证书生成天数:"${days}
                echoContent skyBlue " ---> 证书剩余天数:"${tlsStatus}
                if [[ ${remainingDays} -le 1 ]]
                then
                    echoContent yellow " ---> 重新生成证书"
                    if [[ `ps -ef|grep -v grep|grep nginx` ]]
                    then
                        nginx -s stop
                    fi
                    sudo ~/.acme.sh/acme.sh --installcert -d ${host} --fullchainpath /etc/v2ray-agent/tls/${host}.crt --keypath /etc/v2ray-agent/tls/${host}.key --ecc >> /etc/v2ray-agent/tls/acme.log
                    nginx
                    if [[ `ps -ef|grep -v grep|grep nginx` ]]
                    then
                        echoContent green " ---> nginx启动成功"
                    else
                        echoContent red " ---> nginx启动失败，请检查[/etc/v2ray-agent/tls/acme.log]"
                    fi
                else
                    echoContent green " ---> 证书有效"
                fi
            else
                echoContent red " ---> 无法找到相应证书路径，请使用脚本重新安装"
            fi
        else
            echoContent red " ---> 无法找到相应路径，请使用脚本重新安装"
        fi
    else
        echoContent red " ---> 无法找到相应路径，请使用脚本重新安装"
    fi
}
# 安装V2Ray
installV2Ray(){
    # ls -F /usr/bin/v2ray/|grep "v2ray"
    #    mkdir -p /usr/bin/v2ray/
    #    mkdir -p /etc/v2ray-agent/v2ray/
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装V2Ray"

    # 首先要卸载掉其余途径安装的V2Ray
    if [[ ! -z `ps -ef|grep -v grep|grep v2ray` ]] && [[ -z `ps -ef|grep -v grep|grep v2ray|grep v2ray-agent` ]]
    then
        ps -ef|grep -v grep|grep v2ray|awk '{print $8}'|xargs rm -f
        ps -ef|grep -v grep|grep v2ray|awk '{print $2}'|xargs kill -9 > /dev/null 2>&1
    fi
    if [[ -z `ls -F /etc/v2ray-agent/v2ray/|grep -w "v2ray"` ]] || [[ -z `ls -F /etc/v2ray-agent/v2ray/|grep -w "v2ctl"` ]]
    then
        version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        # version="v4.27.4"
        echoContent green " ---> v2ray-core版本:${version}"
#        echoContent green " ---> 下载v2ray-core核心中"
        if [[ ! -z `wget --help|grep show-progress` ]]
        then
            wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip
        else
            wget -c -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip
        fi

#        echoContent green " ---> 下载完毕，解压中"
        unzip -o /etc/v2ray-agent/v2ray/v2ray-linux-64.zip -d /etc/v2ray-agent/v2ray > /dev/null
#        echoContent green " ---> 解压完毕，删除压缩包"
        rm -rf /etc/v2ray-agent/v2ray/v2ray-linux-64.zip
    else
        # progressTools "green" "  v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
        echoContent green " ---> v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
        read -p "是否重新安装？[y/n]:" reInstalV2RayStatus
        if [[ "${reInstalV2RayStatus}" = "y" ]]
        then
            rm -f /etc/v2ray-agent/v2ray/v2ray
            rm -f /etc/v2ray-agent/v2ray/v2ctl
            installV2Ray $1
        fi
    fi
}
# 安装Trojan-go
installTrojanGo(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装Trojan-Go"
    if [[ -z `ls -F /etc/v2ray-agent/trojan/|grep "trojan-go"` ]] || [[ -z `ls -F /etc/v2ray-agent/trojan/|grep "trojan-go"` ]]
    then
        version=`curl -s https://github.com/p4gefau1t/trojan-go/releases|grep /trojan-go/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        # version="v4.27.4"
        echoContent green " ---> Trojan-Go版本:${version}"
        wget -q -P /etc/v2ray-agent/trojan/ https://github.com/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-amd64.zip
        unzip -o /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip -d /etc/v2ray-agent/trojan > /dev/null
        rm -rf /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip
    else
        # progressTools "green" "  v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
        echoContent green " ---> Trojan-Go版本:`/etc/v2ray-agent/trojan/trojan-go --version|awk '{print $2}'|head -1`"
        read -p "是否重新安装？[y/n]:" reInstalTrojanStatus
        if [[ "${reInstalV2RayStatus}" = "y" ]]
        then
            rm -rf /etc/v2ray-agent/trojan/*
            installTrojanGo $1
        fi
    fi
}
# V2Ray版本管理
v2rayVersionManageMenu(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : V2Ray版本管理"
    if [[ ! -d "/etc/v2ray-agent/v2ray/" ]]
    then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi
    echoContent red "\n=============================================================="
    echoContent yellow "1.升级"
    echoContent yellow "2.回退"
    echoContent red "=============================================================="
    read -p "请选择：" selectV2RayType
    if [[ "${selectV2RayType}" = "1" ]]
    then
        updateV2Ray
    elif [[ "${selectV2RayType}" = "2" ]]
    then
        echoContent yellow "\n1.只可以回退最近的两个版本"
        echoContent yellow "2.不保证回退后一定可以正常使用"
        echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
        echoContent skyBlue "------------------------Version-------------------------------"
        curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -3|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'|tail -n 2|awk '{print ""NR""":"$0}'
        echoContent skyBlue "--------------------------------------------------------------"
        read -p "请输入要回退的版本：" selectV2rayVersionType
        version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -3|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'|tail -n 2|awk '{print ""NR""":"$0}'|grep "${selectV2rayVersionType}:"|awk -F "[:]" '{print $2}'`
        if [[ ! -z "${version}" ]]
        then
            updateV2Ray ${version}
        else
            echoContent red "\n ---> 输入有误，请重新输入"
            v2rayVersionManageMenu 1
        fi
    fi

}
# 更新V2Ray
updateV2Ray(){

    if [[ -z `ls -F /etc/v2ray-agent/v2ray/|grep "v2ray"` ]] || [[ -z `ls -F /etc/v2ray-agent/v2ray/|grep "v2ctl"` ]]
    then
        if [[ ! -z "$1" ]]
        then
            version=$1
        else
            version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        fi
        echoContent green " ---> v2ray-core版本:${version}"
#        echoContent green " ---> 下载v2ray-core核心中"

        if [[ ! -z `wget --help|grep show-progress` ]]
        then
            wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip
        else
            wget -c -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip
        fi

#        echoContent green " ---> 下载完毕，解压中"
        unzip -o  /etc/v2ray-agent/v2ray/v2ray-linux-64.zip -d /etc/v2ray-agent/v2ray > /dev/null
#        echoContent green " ---> 解压完毕，删除压缩包"
        rm -rf /etc/v2ray-agent/v2ray/v2ray-linux-64.zip
        handleV2Ray stop
        handleV2Ray start
    else
        echoContent green " ---> 当前v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
        if [[ ! -z `/etc/v2ray-agent/v2ray/v2ray --version` ]]
        then
            if [[ ! -z "$1" ]]
            then
                version=$1
            else
                version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
            fi

            if [[ ! -z "$1" ]]
            then
                read -p "回退版本为${version}，是否继续？[y/n]:" rollbackV2RayStatus
                if [[ "${rollbackV2RayStatus}" = "y" ]]
                then
                    handleV2Ray stop
                    rm -f /etc/v2ray-agent/v2ray/v2ray
                    rm -f /etc/v2ray-agent/v2ray/v2ctl
                    updateV2Ray ${version}
                else
                    echoContent green " ---> 放弃回退版本"
                fi
            elif [[ "${version}" = "v`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`" ]]
            then
                read -p "当前版本与最新版相同，是否重新安装？[y/n]:" reInstalV2RayStatus
                if [[ "${reInstalV2RayStatus}" = "y" ]]
                then
                    handleV2Ray stop
                    rm -f /etc/v2ray-agent/v2ray/v2ray
                    rm -f /etc/v2ray-agent/v2ray/v2ctl
                    updateV2Ray
                else
                    echoContent green " ---> 放弃重新安装"
                fi
            else
                read -p "最新版本为：${version}，是否更新？[y/n]：" installV2RayStatus
                if [[ "${installV2RayStatus}" = "y" ]]
                then
                    rm -f /etc/v2ray-agent/v2ray/v2ray
                    rm -f /etc/v2ray-agent/v2ray/v2ctl
                    updateV2Ray
                else
                    echoContent green " ---> 放弃更新"
                fi

            fi
        fi
    fi
}

# 更新Trojan-Go
updateTrojanGo(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 更新Trojan-Go"
    if [[ ! -d "/etc/v2ray-agent/trojan/" ]]
    then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi
    if [[ -z `ls -F /etc/v2ray-agent/trojan/|grep "trojan-go"` ]]
    then
        version=`curl -s https://github.com/p4gefau1t/trojan-go/releases|grep /trojan-go/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        echoContent green " ---> Trojan-Go版本:${version}"
        wget -q -P /etc/v2ray-agent/trojan/ https://github.com/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-amd64.zip
        unzip -o /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip -d /etc/v2ray-agent/trojan > /dev/null
        if [[ "$2" = "backup" ]]
        then
            cp /tmp/trojan_config.json /etc/v2ray-agent/trojan/config.json
        fi

        rm -rf /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip
        handleTrojanGo stop
        handleTrojanGo start
    else
        echoContent green " ---> 当前Trojan-Go版本:`/etc/v2ray-agent/trojan/trojan-go --version|awk '{print $2}'|head -1`"
        if [[ ! -z `/etc/v2ray-agent/trojan/trojan-go --version` ]]
        then
            version=`curl -s https://github.com/p4gefau1t/trojan-go/releases|grep /trojan-go/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
#             echo version:${version}
#             echo version2:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`
            if [[ "${version}" = "`/etc/v2ray-agent/trojan/trojan-go --version|awk '{print $2}'|head -1`" ]]
            then
                read -p "当前版本与最新版相同，是否重新安装？[y/n]:" reInstalTrojanGoStatus
                if [[ "${reInstalTrojanGoStatus}" = "y" ]]
                then
                    handleTrojanGo stop
                    cp /etc/v2ray-agent/trojan/config.json /tmp/trojan_config.json
                    rm -rf /etc/v2ray-agent/trojan/*
                    updateTrojanGo $1 backup
                else
                    echoContent green " ---> 放弃重新安装"
                fi
            else
                read -p "最新版本为：${version}，是否更新？[y/n]：" installTrojanGoStatus
                if [[ "${installTrojanGoStatus}" = "y" ]]
                then
                    cp /etc/v2ray-agent/trojan/config.json /tmp/trojan_config.json
                    rm -rf /etc/v2ray-agent/trojan/*
                    updateTrojanGo $1 backup
                else
                    echoContent green " ---> 放弃更新"
                fi
            fi
        fi
    fi
}
# 自动升级
automaticUpgrade(){
    if [[ -f "/root/install.sh" ]] && [[ ! -z `cat ~/install.sh|grep -v grep|grep mack-a` ]] && [[ -d "/etc/v2ray-agent" ]]
    then
        local currentTime=`date +%s`
        local version=0
        local currentVersion=0
        # 首次安装完毕后再次使用时出发
        if [[ ! -f "/etc/v2ray-agent/upgradeStatus" ]]
        then
            echo "firstUpgrade|${currentTime}" > /etc/v2ray-agent/upgradeStatus
        fi

        if [[  -z `cat /etc/v2ray-agent/upgradeStatus` ]]
        then
            echo "firstUpgrade|${currentTime}" > /etc/v2ray-agent/upgradeStatus
        fi

        # 第一次升级不计算时间
        if [[ "`cat /etc/v2ray-agent/upgradeStatus|awk -F '[|]' '{print $1}'`" = "firstUpgrade" ]]
        then
            version=`curl -s https://github.com/mack-a/v2ray-agent/releases|grep -v grep|grep /mack-a/v2ray-agent/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
            currentVersion=`cat /root/install.sh|grep -v grep|grep "当前版本："|awk '{print $3}'|awk -F "[\"]" '{print $2}'|awk -F "[v]" '{print $2}'`
            echo "upgrade|${currentTime}" > /etc/v2ray-agent/upgradeStatus
        elif [[ "`cat /etc/v2ray-agent/upgradeStatus|awk -F '[|]' '{print $1}'`" = "upgrade" ]] && [[ ! -z `cat /etc/v2ray-agent/upgradeStatus|awk -F '[|]' '{print $2}'` ]]
        then
            # 第二次计算时间 三天
            local lastTime=`cat /etc/v2ray-agent/upgradeStatus|awk -F '[|]' '{print $2}'`
            local stampDiff=`expr ${currentTime} - ${lastTime}`
            dayDiff=`expr ${stampDiff} / 86400`
            if [[ ${dayDiff} -gt 3 ]]
            then
                version=`curl -s https://github.com/mack-a/v2ray-agent/releases|grep -v grep|grep /mack-a/v2ray-agent/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
                currentVersion=`cat /root/install.sh|grep -v grep|grep "当前版本："|awk '{print $3}'|awk -F "[\"]" '{print $2}'|awk -F "[v]" '{print $2}'`
                echo "upgrade|${currentTime}" > /etc/v2ray-agent/upgradeStatus
            fi
        fi
        if [[ "v${currentVersion}" != "${version}" ]] && [[ "${version}" != "0" ]] && [[ "${currentVersion}" != "0" ]]
        then
            echoContent yellow " ---> 当前版本：`echo ${version}|grep -v grep|awk -F '[v]' '{print $2}'`"
            echoContent green " ---> 新 版 本：${currentVersion}"
            read -p "发现新版本，是否更新[y/n]？：" upgradeStatus
            if [[ "${upgradeStatus}" = "y" ]]
            then
                updateV2RayAgent 1
                menu
            else
                echo "notUpgrade|${currentTime}" > /etc/v2ray-agent/upgradeStatus
                menu
                exit;
            fi
        fi
    fi
}
updateV2RayAgent(){
    local currentTime=`date +%s`
    echo "upgrade|${currentTime}" > /etc/v2ray-agent/upgradeStatus
    echoContent skyBlue "\n进度  $1/${totalProgress} : 更新v2ray-agent脚本"
    mkdir -p /etc/v2ray-agent
    wget -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /etc/v2ray-agent/install.sh && vasma

}
# 验证整个服务是否可用
checkGFWStatue(){
    # 验证整个服务是否可用
#    progressTools "yellow" "验证服务是否可用--->"
    echoContent skyBlue "\n进度 $1/${totalProgress} : 验证服务是否可用"
    if [[ "${globalType}" = "vlesstcpws" ]]
    then
        if [[ ! -z `ps -ef|grep -v grep|grep v2ray` ]]
        then
            echoContent green " ---> 服务启动成功"
        else
            echoContent red " ---> 服务不可用，请检查终端是否有日志打印"
            exit 0
        fi
    fi
}
# V2Ray开机自启
installV2RayService(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置V2Ray开机自启"
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        rm -rf /etc/systemd/system/v2ray.service
        touch /etc/systemd/system/v2ray.service
        execStart='/etc/v2ray-agent/v2ray/v2ray -config /etc/v2ray-agent/v2ray/config_full.json'
        if [[ ! -z ${customInstallType} ]]
        then
            execStart='/etc/v2ray-agent/v2ray/v2ray -confdir /etc/v2ray-agent/v2ray/conf'
        fi
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
# Trojan开机自启
installTrojanService(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置Trojan开机自启"
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        rm -rf /etc/systemd/system/trojan-go.service
        touch /etc/systemd/system/trojan-go.service

    cat << EOF > /etc/systemd/system/trojan-go.service
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
ExecStart=/etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config.json
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
handleV2Ray(){
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]] && [[ ! -z `ls /etc/systemd/system/|grep -v grep|grep v2ray.service` ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]] && [[ "$1" = "start" ]]
        then
            systemctl start v2ray.service
        elif [[ ! -z `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]] && [[ "$1" = "stop" ]]
        then
            systemctl stop v2ray.service
        fi
    elif [[ -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep v2ray` ]] && [[ "$1" = "start" ]]
        then
            /usr/bin/v2ray/v2ray -config /etc/v2ray-agent/v2ray/config_full.json & > /dev/null 2>&1
        elif [[ ! -z `ps -ef|grep -v grep|grep v2ray` ]] && [[ "$1" = "stop" ]]
        then
            ps -ef|grep -v grep|grep v2ray|awk '{print $2}'|xargs kill -9
        fi
    fi
    sleep 0.5
    if [[ "$1" = "start" ]]
    then
        if [[ ! -z `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]]
        then
            echoContent green " ---> V2Ray启动成功"
        else
            echoContent red "V2Ray启动失败"
            echoContent red "执行 [ps -ef|grep v2ray] 查看日志"
            exit 0;
        fi
    elif [[ "$1" = "stop" ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]]
        then
            echoContent green " ---> V2Ray关闭成功"
        else
            echoContent red "V2Ray关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep v2ray|awk '{print \$2}'|xargs kill -9】"
            exit 0;
        fi
    fi
}
# 操作Trojan-Go
handleTrojanGo(){
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]] && [[ ! -z `ls /etc/systemd/system/|grep -v grep|grep trojan-go.service` ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "start" ]]
        then
            systemctl start trojan-go.service
        elif [[ ! -z `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "stop" ]]
        then
            systemctl stop trojan-go.service
        fi
    elif [[ -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "start" ]]
        then
            /etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json & > /dev/null 2>&1
        elif [[ ! -z `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "stop" ]]
        then
            ps -ef|grep -v grep|grep trojan-go|awk '{print $2}'|xargs kill -9
        fi
    fi
    sleep 0.5
    if [[ "$1" = "start" ]]
    then
        if [[ ! -z `ps -ef|grep -v grep|grep trojan-go` ]]
        then
            echoContent green " ---> Trojan-Go启动成功"
        else
            echoContent red "Trojan-Go启动失败"
            echoContent red "请手动执行【/etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json】,查看错误日志"
            exit 0;
        fi
    elif [[ "$1" = "stop" ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep trojan-go` ]]
        then
            echoContent green " ---> Trojan-Go关闭成功"
        else
            echoContent red "Trojan-Go关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep trojan-go|awk '{print \$2}'|xargs kill -9】"
            exit 0;
        fi
    fi
}
# 初始化V2Ray 配置文件
initV2RayConfig(){
    echoContent skyBlue "\n进度 $2/${totalProgress} : 初始化V2Ray配置"

    if [[ -d "/etc/v2ray-agent" && -d "/etc/v2ray-agent/v2ray" ]] && [[ -f "/etc/v2ray-agent/v2ray/config_full.json" || -f "/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json"  ]]
    then
        echo
        read -p "读取到上次安装记录，是否使用上次安装时的UUID ？[y/n]:" historyUUIDStatus
        if [[ "${historyUUIDStatus}" = "y" ]]
        then
            if [[ -f "/etc/v2ray-agent/v2ray/config_full.json" ]]
            then
                uuid=`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[0].settings.clients[0].id|awk -F '["]' '{print $2}'`
                uuidDirect=`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[0].settings.clients[1].id|awk -F '["]' '{print $2}'`
            elif [[ -f "/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json" ]]
            then

                uuid=`cat /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json|jq .inbounds[0].settings.clients[0].id|awk -F '["]' '{print $2}'`
                uuidDirect=`cat /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json|jq .inbounds[0].settings.clients[1].id|awk -F '["]' '{print $2}'`
            fi
        fi
    else
        uuid=`/etc/v2ray-agent/v2ray/v2ctl uuid`
        uuidDirect=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    fi
    if [[ -z "${uuid}" ]] || [[ -z "${uuidDirect}" ]]
    then
        echoContent red "\n ---> uuid读取错误，重新生成"
        uuid=`/etc/v2ray-agent/v2ray/v2ctl uuid`
        uuidDirect=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    fi

    if [[ "${uuid}" = "${uuidDirect}" ]]
    then
        echoContent red "\n ---> uuid重复，重新生成"
        uuid=`/etc/v2ray-agent/v2ray/v2ctl uuid`
        uuidDirect=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    fi
    echoContent green "\n ---> 使用成功"

    rm -rf /etc/v2ray-agent/v2ray/conf/*
    rm -rf /etc/v2ray-agent/v2ray/config_full.json
    if [[ "$1" = "vlesstcpws" ]]
    then
        cat << EOF > /etc/v2ray-agent/v2ray/config_full.json
{
  "log": {
    "access": "/etc/v2ray-agent/v2ray/v2ray_access.log",
    "error": "/etc/v2ray-agent/v2ray/v2ray_error.log",
    "loglevel": "debug"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "add": "${add}",
            "flow":"xtls-rprx-origin",
            "email": "${domain}_VLESS_XTLS/TLS-origin_TCP"
          },
          {
            "id": "${uuidDirect}",
            "flow":"xtls-rprx-direct",
            "email": "${domain}_VLESS_XTLS/TLS-direct_TCP"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 31296,
            "xver": 0
          },
          {
            "path": "/${customPath}",
            "dest": 31299,
            "xver": 1
          },
          {
            "path": "/${customPath}tcp",
            "dest": 31298,
            "xver": 1
          },
          {
            "path": "/${customPath}ws",
            "dest": 31297,
            "xver": 1
          }
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
    },
    {
      "port": 31299,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "alterId": 1,
            "level": 0,
            "email": "${domain}_vmess_ws"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${customPath}"
        }
      }
    },
    {
      "port": 31298,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
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
    },
    {
      "port": 31297,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
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
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      }
    }
  ],
  "dns": {
    "servers": [
      "74.82.42.42",
      "8.8.8.8",
      "8.8.4.4",
      "1.1.1.1",
      "localhost"
    ]
  }
}
EOF
    elif [[ "$1" = "custom" ]]
    then
        # log
        cat << EOF > /etc/v2ray-agent/v2ray/conf/00_log.json
{
  "log": {
    "access": "/etc/v2ray-agent/v2ray/v2ray_access.log",
    "error": "/etc/v2ray-agent/v2ray/v2ray_error.log",
    "loglevel": "debug"
  }
}
EOF
        # outbounds
       cat << EOF > /etc/v2ray-agent/v2ray/conf/10_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {
            "domainStrategy": "UseIP"
          }
        }
    ]
}
EOF
        # dns
       cat << EOF > /etc/v2ray-agent/v2ray/conf/11_dns.json
{
    "dns": {
        "servers": [
          "74.82.42.42",
          "8.8.8.8",
          "8.8.4.4",
          "1.1.1.1",
          "localhost"
        ]
  }
}
EOF
        # VLESS_TCP_TLS/XTLS
        # 没有path则回落到此端口
        local fallbacksList='{"dest":31296,"xver":0}'

        if [[ -z `echo ${customInstallType}|grep 4` ]]
        then
            fallbacksList='{"dest":80,"xver":0}'
        fi

        # {"dest":31296,"xver":0},{"path":"/${customPath}","dest":31299,"xver":1},{"path":"/${customPath}tcp","dest":31298,"xver":1},{"path":"/${customPath}ws","dest":31297,"xver":1}

        # VLESS_WS_TLS
        if [[ ! -z `echo ${customInstallType}|grep 1` ]]
        then
            fallbacksList=${fallbacksList}',{"path":"/'${customPath}'ws","dest":31297,"xver":1}'
            cat << EOF > /etc/v2ray-agent/v2ray/conf/03_VLESS_WS_inbounds.json
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
            "level": 0,
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
        if [[ ! -z `echo ${customInstallType}|grep 2` ]]
        then
            fallbacksList=${fallbacksList}',{"path":"/'${customPath}'tcp","dest":31298,"xver":1}'
            cat << EOF > /etc/v2ray-agent/v2ray/conf/04_VMess_TCP_inbounds.json
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
            "level": 0,
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
        if [[ ! -z `echo ${customInstallType}|grep 3` ]]
        then
            fallbacksList=${fallbacksList}',{"path":"/'${customPath}'","dest":31299,"xver":1}'
            cat << EOF > /etc/v2ray-agent/v2ray/conf/05_VMess_WS_inbounds.json
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
            "level": 0,
            "email": "${domain}_vmess_ws"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${customPath}"
        }
      }
    }
]
}
EOF
        fi
        # VLESS_TCP
        cat << EOF > /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json
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
            "flow":"xtls-rprx-origin",
            "email": "${domain}_VLESS_XTLS/TLS-origin_TCP"
          },
          {
            "id": "${uuidDirect}",
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
# 初始化Trojan-Go配置
initTrojanGoConfig(){
#    uuidTrojanGo=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    echoContent skyBlue "\n进度 $1/${totalProgress} : 初始化Trojan配置"
    cat << EOF > /etc/v2ray-agent/trojan/config.json
{
    "run_type": "server",
    "local_addr": "127.0.0.1",
    "local_port": 31296,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "log_level":0,
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
customCDNIP(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 添加DNS智能解析"
    echoContent yellow " 移动:104.19.41.56"
    echoContent yellow " 联通:104.16.160.136"
    echoContent yellow " 电信:104.17.78.198"
    read -p '是否使用？[y/n]:' dnsProxy
    if [[ "${dnsProxy}" = "y" ]]
    then
        add="domain08.qiu4.ml"
    else
        add="${domain}"
    fi
}

# 通用
defaultBase64Code(){
    local type=$1
    local ps=$2
    local id=$3
    local host=$4
    local path=$5
    local add=$6
    if [[ ${type} = "tcp" ]]
    then
        qrCodeBase64Default=`echo -n '{"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","net":"tcp","add":"'${host}'","allowInsecure":0,"method":"none","peer":""}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(tcp+tls)"
        echoContent green '    {"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","net":"tcp","add":"'${host}'","allowInsecure":0,"method":"none","peer":""}\n'
        # 通用Vmess
        echoContent yellow " ---> 通用vmess(tcp+tls)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echo "通用vmess(tcp+tls)链接: " > /etc/v2ray-agent/v2ray/usersv2ray.conf
        echo "   vmess://${qrCodeBase64Default}" >> /etc/v2ray-agent/v2ray/usersv2ray.conf
    elif [[ ${type} = "wss" ]]
    then
        qrCodeBase64Default=`echo -n '{"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(ws+tls)"
        echoContent green '    {"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}\n'
        echoContent yellow " ---> 通用vmess(ws+tls)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echo "通用vmess(ws+tls)链接: " > /etc/v2ray-agent/v2ray/usersv2ray.conf
        echo "   vmess://${qrCodeBase64Default}" >> /etc/v2ray-agent/v2ray/usersv2ray.conf
    elif [[ "${type}" = "h2" ]]
    then
        qrCodeBase64Default=`echo -n '{"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"h2","add":"'${add}'","allowInsecure":0,"method":"none","peer":""}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent red "通用json--->"
        echoContent green '    {"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"h2","add":"'${add}'","allowInsecure":0,"method":"none","peer":""}\n'
    elif [[ "${type}" = "vlesstcp" ]]
    then
        qrCodeBase64Default=`echo -n '{"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"tcp","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echo "通用vmess(VLESS+TCP+TLS)链接: " > /etc/v2ray-agent/v2ray/usersv2ray.conf
        echo "   vmess://${qrCodeBase64Default}" >> /etc/v2ray-agent/v2ray/usersv2ray.conf
        echoContent yellow " ---> 通用json(VLESS+TCP+TLS)"
        echoContent green '    {"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"host":"'${host}'","type":"none","net":"tcp","add":"'${host}'","allowInsecure":0,"method":"none","peer":""}\n'
        echoContent green '    V2Ray v4.27.4+ 目前无通用订阅，需要手动配置，VLESS TCP、XTLS和TCP大部分一样，其余内容不变，请注意手动输入的流控flow类型\n'

    elif [[ "${type}" = "vmessws" ]]
    then
        qrCodeBase64Default=`echo -n '{"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(VMess+WS+TLS)"
        echoContent green '    {"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}\n'
        echoContent yellow " ---> 通用vmess(VMess+WS+TLS)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echoContent yellow " ---> 二维码 vmess(VMess+WS+TLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

    elif [[ "${type}" = "vmesstcp" ]]
    then
        qrCodeBase64Default=`echo -n '{"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"http","path":'${path}',"net":"tcp","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'","obfs":"http","obfsParam":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(VMess+TCP+TLS)"
        echoContent green '    {"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"http","path":'${path}',"net":"tcp","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'","obfs":"http","obfsParam":"'${host}'"}\n'
        echoContent yellow " ---> 通用vmess(VMess+TCP+TLS)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echoContent yellow " ---> 二维码 vmess(VMess+TCP+TLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"
    elif [[ "${type}" = "vlessws" ]]
    then
        qrCodeBase64Default=`echo -n '{"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(VLESS+WS+TLS)"
        echoContent green '    {"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"0","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}\n'
    elif [[ "${type}" = "trojan" ]]
    then
        # URLEncode
        echoContent yellow " ---> Trojan(TLS)"
        echoContent green "    trojan://${id}@${host}:443?peer=${host}&sni=${host}\n"
        echoContent yellow " ---> 二维码 Trojan(TLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${host}%3a443%3fpeer%3d${host}%26sni%3d${host}%23${host}_trojan\n"

    elif [[ "${type}" = "trojangows" ]]
    then
        # URLEncode
        echoContent yellow " ---> Trojan-Go(WS+TLS) Shadowrocket"
        echoContent green "    trojan://${id}@${add}:443?allowInsecure=0&&peer=${host}&sni=${host}&plugin=obfs-local;obfs=websocket;obfs-host=${host};obfs-uri=${path}#${host}_trojan_ws\n"
        echoContent yellow " ---> 二维码 Trojan-Go(WS+TLS) Shadowrocket"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${add}%3a443%3fallowInsecure%3d0%26peer%3d${host}%26plugin%3dobfs-local%3bobfs%3dwebsocket%3bobfs-host%3d${host}%3bobfs-uri%3d${path}%23${host}_trojan_ws\n"

        path=`echo ${path}|awk -F "[/]" '{print $2}'`
        echoContent yellow " ---> Trojan-Go(WS+TLS) QV2ray"
        echoContent green "    trojan-go://${id}@${add}:443?sni=${host}&type=ws&host=${host}&path=%2F${path}#${host}_trojan_ws\n"
    fi
}
# 进度条工具 废弃
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
progressTools(){
    color=$1
    content=$2
    installProgress=$3
#    echo ${color},${content},${installProgress}
    echoContent ${color} "${content}"
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

# 账号
showAccounts(){
    showStatus=
    local host=
    echoContent skyBlue "\n进度 $1/${totalProgress} : 账号"
    if [[ -d "/etc/v2ray-agent/" ]] && [[ -d "/etc/v2ray-agent/v2ray/" ]] && [[ -f "/etc/v2ray-agent/v2ray/config_full.json" ]] && [[ -z "${customInstallType}" ]]
    then
        showStatus=true
        # VLESS tcp
        local tcp=`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[0]`
        local tcpID=`echo ${tcp}|jq .settings.clients[0].id`
        local tcpEmail="`echo ${tcp}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local CDNADD=`echo ${tcp}|jq .settings.clients[0].add|awk -F '["]' '{print $2}'`
        # XTLS Direct
        local tcpIDirect=`echo ${tcp}|jq .settings.clients[1].id`
        local tcpDirectEmail="`echo ${tcp}|jq .settings.clients[1].email|awk -F '["]' '{print $2}'`"
        host=`echo ${tcp}|jq .streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`

         # VLESS ws
        local vlessWS=`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[3]`
        local vlessWSID=`echo ${vlessWS}|jq .settings.clients[0].id`
        local vlessWSEmail="`echo ${vlessWS}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local vlessWSPath=`echo ${vlessWS}|jq .streamSettings.wsSettings.path`

        # Vmess ws
        local ws=`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[1]`
        local wsID=`echo ${ws}|jq .settings.clients[0].id`
        local wsEmail="`echo ${ws}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local wsPath=`echo ${ws}|jq .streamSettings.wsSettings.path`

        # Vmess tcp
        local vmessTCP=`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[2]`
        local vmessTCPID=`echo ${vmessTCP}|jq .settings.clients[0].id`
        local vmessTCPEmail="`echo ${vmessTCP}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local vmessTCPath=`echo ${vmessTCP}|jq .streamSettings.tcpSettings.header.request.path[0]`


        echoContent skyBlue "\n============================ VLESS TCP TLS/XTLS-origin ==========================="
        defaultBase64Code vlesstcp ${tcpEmail} "${tcpID}" "${host}" ${add}

        echoContent skyBlue "\n============================ VLESS TCP TLS/XTLS-direct ==========================="
        defaultBase64Code vlesstcp ${tcpDirectEmail} "${tcpIDirect}" "${host}" ${add}
        echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================"
        defaultBase64Code vlessws ${vlessWSEmail} "${vlessWSID}" "${host}" "${vlessWSPath}" ${CDNADD}

        echoContent skyBlue "\n================================ VMess WS TLS CDN ================================"
        defaultBase64Code vmessws ${wsEmail} "${wsID}" "${host}" "${wsPath}" ${CDNADD}

        echoContent skyBlue "\n================================= VMess TCP TLS  ================================="
        defaultBase64Code vmesstcp ${vmessTCPEmail} "${vmessTCPID}" "${host}" "${vmessTCPath}" "${host}"

    elif [[ -d "/etc/v2ray-agent/" ]] && [[ -d "/etc/v2ray-agent/v2ray/" ]] && [[ -d "/etc/v2ray-agent/v2ray/conf" ]] && [[ ! -z "${customInstallType}" ]]
    then
        showStatus=true

        # VLESS tcp
        local tcp=`cat /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json|jq .inbounds[0]`
        local tcpID=`echo ${tcp}|jq .settings.clients[0].id`
        local tcpEmail="`echo ${tcp}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"

        local CDNADD=`echo ${tcp}|jq .settings.clients[0].add|awk -F '["]' '{print $2}'`
        # XTLS Direct
        local tcpIDirect=`echo ${tcp}|jq .settings.clients[1].id`
        local tcpDirectEmail="`echo ${tcp}|jq .settings.clients[1].email|awk -F '["]' '{print $2}'`"
        host=`echo ${tcp}|jq .streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`
        echoContent skyBlue "\n============================ VLESS TCP TLS/XTLS-origin ==========================="
        defaultBase64Code vlesstcp ${tcpEmail} "${tcpID}" "${host}" ${add}

        echoContent skyBlue "\n============================ VLESS TCP TLS/XTLS-direct ==========================="
        defaultBase64Code vlesstcp ${tcpDirectEmail} "${tcpIDirect}" "${host}" ${add}

        if [[ ! -z "${customInstallType}" ]]
        then
            if [[ ! -z `echo ${customInstallType}|grep 1` ]]
            then
                # VLESS ws
                local vlessWS=`cat /etc/v2ray-agent/v2ray/conf/03_VLESS_WS_inbounds.json|jq .inbounds[0]`
                local vlessWSID=`echo ${vlessWS}|jq .settings.clients[0].id`
                local vlessWSAdd=`echo ${tcp}|jq .settings.clients[0].add|awk -F '["]' '{print $2}'`
                local vlessWSEmail="`echo ${vlessWS}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
                local vlessWSPath=`echo ${vlessWS}|jq .streamSettings.wsSettings.path`

                echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================"
                defaultBase64Code vlessws ${vlessWSEmail} "${vlessWSID}" "${host}" "${vlessWSPath}" ${CDNADD}
            fi
            if [[ ! -z `echo ${customInstallType}|grep 2` ]]
            then

                local vmessTCP=`cat /etc/v2ray-agent/v2ray/conf/04_VMess_TCP_inbounds.json|jq .inbounds[0]`
                local vmessTCPID=`echo ${vmessTCP}|jq .settings.clients[0].id`
                local vmessTCPEmail="`echo ${vmessTCP}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
                local vmessTCPath=`echo ${vmessTCP}|jq .streamSettings.tcpSettings.header.request.path[0]`

                echoContent skyBlue "\n================================= VMess TCP TLS  ================================="
                defaultBase64Code vmesstcp ${vmessTCPEmail} "${vmessTCPID}" "${host}" "${vmessTCPath}" "${host}"
            fi
            if [[ ! -z `echo ${customInstallType}|grep 3` ]]
            then

                local ws=`cat /etc/v2ray-agent/v2ray/conf/05_VMess_WS_inbounds.json|jq .inbounds[0]`
                local wsID=`echo ${ws}|jq .settings.clients[0].id`
                local wsEmail="`echo ${ws}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
                local wsPath=`echo ${ws}|jq .streamSettings.wsSettings.path`

                echoContent skyBlue "\n================================ VMess WS TLS CDN ================================"
                defaultBase64Code vmessws ${wsEmail} "${wsID}" "${host}" "${wsPath}" ${CDNADD}
            fi
        fi
    fi

    if [[ -d "/etc/v2ray-agent/" ]] && [[ -d "/etc/v2ray-agent/trojan/" ]] && [[ -f "/etc/v2ray-agent/trojan/config.json" ]]
    then
        showStatus=true
        local trojanUUID=`cat /etc/v2ray-agent/trojan/config.json |jq .password[0]|awk -F '["]' '{print $2}'`
        local trojanGoPath=`cat /etc/v2ray-agent/trojan/config.json|jq .websocket.path|awk -F '["]' '{print $2}'`
        local trojanGoAdd=`cat /etc/v2ray-agent/trojan/config.json|jq .websocket.add|awk -F '["]' '{print $2}'`
        echoContent skyBlue "\n==================================  Trojan TLS  =================================="
        defaultBase64Code trojan trojan ${trojanUUID} ${host}

        echoContent skyBlue "\n================================  Trojan WS TLS   ================================"
        if [[ -z ${trojanGoAdd} ]]
        then
            trojanGoAdd=${host}
        fi
        defaultBase64Code trojangows trojan ${trojanUUID} ${host} ${trojanGoPath} ${trojanGoAdd}
    fi
    if [[ -z ${showStatus} ]]
    then
        echoContent red " ---> 未安装"
    fi
}
# 卸载脚本
unInstall(){
    read -p "是否确认卸载安装内容？[y/n]:" unInstallStatus
    if [[ "${unInstallStatus}" != "y" ]]
    then
        echoContent green " ---> 放弃卸载"
        menu
        exit;
    fi

    handleNginx stop
    if [[ -z `ps -ef|grep -v grep|grep nginx` ]]
    then
        echoContent green " ---> 停止Nginx成功"
    fi

    handleV2Ray stop
    handleTrojanGo stop
    rm -rf /etc/systemd/system/v2ray.service
    echoContent green " ---> 删除V2Ray开机自启完成"
    rm -rf /etc/systemd/system/trojan-go.service
    echoContent green " ---> 删除Trojan-Go开机自启完成"
    rm -rf /tmp/v2ray-agent-tls/*
    if [[ -d "/etc/v2ray-agent/tls" ]] && [[ ! -z `find /etc/v2ray-agent/tls/ -name "*.key"` ]] && [[ ! -z `find /etc/v2ray-agent/tls/ -name "*.crt"` ]]
    then
        mv /etc/v2ray-agent/tls /tmp/v2ray-agent-tls
        if [[ ! -z `find /tmp/v2ray-agent-tls -name '*.key'` ]]
        then
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
# 检查错误
checkFail(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 检查错误"
    if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]]
    then
        V2RayProcessStatus=
        # V2Ray
        if [[ ! -z `ls /etc/v2ray-agent/v2ray/|grep -w v2ray` ]] && [[ ! -z `ls /etc/v2ray-agent/v2ray/|grep -w v2ctl` ]] && [[ ! -z `ps -ef|grep -v grep|grep v2ray-agent/v2ray` ]]
        then
            V2RayProcessStatus=true
            echoContent green " ---> V2Ray 运行正常"
        else
            echoContent yellow "检查V2Ray是否安装"
            if [[ -z `ls /etc/v2ray-agent/v2ray/|grep -w v2ray` ]] || [[ -z `ls /etc/v2ray-agent/v2ray/|grep -w v2ctl` ]]
            then
                echoContent red " ---> V2Ray 未安装"
            else
                echoContent green " ---> V2Ray 已安装"
            fi
            echoContent yellow "\n检查V2Ray开机自启文件是否存在"
            if [[ -f "/etc/systemd/system/v2ray.service" ]]
            then
                if [[ ! -z `cat /etc/systemd/system/v2ray.service|grep v2ray-agent` ]]
                then
                    echoContent green " ---> V2Ray 开机自启文件存在"
                else
                    echoContent red " ---> V2Ray 开机自启文件出现异常，请重新使用此脚本安装"
                fi
            else
                echoContent grep " ---> V2Ray 开机自启不存在"
            fi
            echoContent yellow "\n检查V2Ray配置文件是否存在"
            if [[ ! -z `ls /etc/v2ray-agent/v2ray/|grep -w config_full.json` ]] || [[ ! -z "${customInstallType}" ]]
            then
                echoContent green " ---> V2Ray配置文件存在"
                echoContent yellow "\n验证配置文件是否正常"
                if [[ -f "/etc/v2ray-agent/v2ray/config_full.json" ]]
                then
                    # [安装]方式
                    if [[ ! -z `/etc/v2ray-agent/v2ray/v2ray -test -c /etc/v2ray-agent/v2ray/config_full.json|grep "failed"` ]]
                    then
                        echoContent red " ---> V2Ray配置文件验证失败，错误日志如下，如没有手动更改配置请提issues"
                        /etc/v2ray-agent/v2ray/v2ray -test -c /etc/v2ray-agent/v2ray/config_full.json
                    else
                        V2RayProcessStatus=true
                        echoContent green " ---> V2Ray配置文件验证成功"
                    fi
                elif [[ ! -z "${customInstallType}" ]]
                then
                    # [个性化]安装方式
                    /etc/v2ray-agent/v2ray/v2ray -test -confdir /etc/v2ray-agent/v2ray/conf > /tmp/customV2rayAgentLog 2>&1
                    if [[ ! -z `cat /tmp/customV2rayAgentLog|grep fail` ]]
                    then
                        echoContent red " ---> V2Ray配置文件验证失败，错误日志如下，如没有手动更改配置请提issues"
                        /etc/v2ray-agent/v2ray/v2ray -test -confdir /etc/v2ray-agent/v2ray/conf
                    else
                        V2RayProcessStatus=true
                        echoContent green " ---> V2Ray配置文件验证成功"
                    fi
                    rm -f /tmp/customV2rayAgentLog
                fi
                if [[ "${V2RayProcessStatus}" = "true" ]] && [[ -z `ps -ef|grep -v grep|grep v2ray-agent/v2ray` ]]
                then
                    echoContent yellow "\n尝试重新启动"
                    handleV2Ray start
                fi
            else
                echoContent red " ---> V2Ray配置文件不存在，请重新使用此脚本安装"
            fi
        fi
        # 运行正常的情况需要判定几个连接是否正常 出现400 invalid request

        ########
    else
        echoContent red " ---> 未使用脚本安装"
    fi

    # 检查服务是否可用
    if [[ "${V2RayProcessStatus}" = "true" ]]
    then
        echo
        read -p "是否检查服务是否可用，执行此操作会清空[error]日志，是否执行[y/n]？" checkServerStatus
        if [[ "${checkServerStatus}" = "y" ]]
        then
            filePath=
            host=
            if [[ -f "/etc/v2ray-agent/v2ray/config_full.json" ]] && [[ -z "${customInstallType}" ]]
            then
                filePath="/etc/v2ray-agent/v2ray/config_full.json"
                host=`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[0]|jq .streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`
            elif [[ ! -z "${customInstallType}" ]]
            then
                filePath="/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json"
                host=`cat /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json|jq .inbounds[0]|jq .streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`
            fi

            if [[ ! -z "${host}" ]]
            then
                checkV2RayServer vlesstcp ${host}
                cat ${filePath}|jq .inbounds[0].settings.fallbacks|jq -c '.[]'|while read row
                do
                    if [[ ! -z `echo ${row}|grep 31299` ]]
                    then
                        # vmess ws
                        path=`echo ${row}|awk -F '["]' '{print $4}'`
                        checkV2RayServer vmessws ${host} ${path}
                    fi

                    if [[ ! -z `echo ${row}|grep 31298` ]]
                    then
                        path=`echo ${row}|awk -F '["]' '{print $4}'`
                        checkV2RayServer vmesstcp ${host} ${path}
                    fi

                    if [[ ! -z `echo ${row}|grep 31297` ]]
                    then
                        # vless ws
                        path=`echo ${row}|awk -F '["]' '{print $4}'`
                        checkV2RayServer vlessws ${host} ${path}
                    fi
                done
            fi
        fi
    fi
    exit 0;
}
# 检查V2Ray具体服务是否正常
checkV2RayServer(){
    local type=$1
    local host=$2
    local path=$3

    echo '' > /etc/v2ray-agent/v2ray_error.log

    case ${type} in
    vlesstcp)
        echoContent yellow "\n判断VLESS+TCP是否可用"
        curl -s -L https://${host} > /dev/null
        if [[ ! -z `cat /etc/v2ray-agent/v2ray/v2ray_error.log|grep -w "firstLen = 83"` ]] && [[ ! -z `cat /etc/v2ray-agent/v2ray/v2ray_error.log|grep -w "invalid request version"` ]] && [[ ! -z `cat /etc/v2ray-agent/v2ray/v2ray_error.log|grep -w "realPath = /"` ]]
        then
            echoContent green " ---> 初步判断VLESS+TCP可用，需自己进一步判断是否真正可用"
        else
            echoContent red " ---> 初步判断VLESS+TCP不可用，需自己进一步判断是否真正可用"
        fi
    ;;
    vlessws)
        echoContent yellow "\n判断VLESS+WS是否可用"
        if [[ ! -z `curl -s -L https://${host}${path}|grep -v grep|grep "Bad Request"` ]]
        then
            echoContent green " ---> 初步判断VLESS+WS可用，需自己进一步判断是否真正可用"
        else
            echoContent red " ---> 初步判断VLESS+WS不可用，需自己进一步判断是否真正可用"
        fi
    ;;
    vmessws)
        echoContent yellow "\n判断VMess+WS是否可用"
        if [[ ! -z `curl -s -L https://${host}${path}|grep -v grep|grep "Bad Request"` ]]
        then
            echoContent green " ---> 初步判断VMess+WS可用，需自己进一步判断是否真正可用"
        else
            echoContent red " ---> 初步判断VMess+WS不可用，需自己进一步判断是否真正可用"
        fi
    ;;
    vmesstcp)
        echoContent yellow "\n判断VMess+TCP是否可用"
        curl -s -L https://${host} > /dev/null
        if [[ ! -z `cat /etc/v2ray-agent/v2ray/v2ray_error.log|grep -w "firstLen = 89"` ]] && [[ ! -z `cat /etc/v2ray-agent/v2ray/v2ray_error.log|grep -w "invalid request version"` ]]
        then
            echoContent green " ---> 初步判断VMess+TCP可用，需自己进一步判断是否真正可用"
        else
            echoContent red " ---> 初步判断VMess+TCP不可用，需自己进一步判断是否真正可用"
        fi
    ;;
    esac
}
# 修改V2Ray CDN节点
updateV2RayCDN(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 修改CDN节点"
    if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]]
    then
        local configPath=
        if [[ -f "/etc/v2ray-agent/v2ray/config_full.json" ]]
        then
            configPath="/etc/v2ray-agent/v2ray/config_full.json"
        elif [[ -d "/etc/v2ray-agent/v2ray/conf" ]] && [[ -f "/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json" ]]
        then
            configPath="/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json"
        else
            echoContent red " ---> 未安装"
            exit 0;
        fi
        local add=`cat ${configPath}|grep -v grep|grep add`
        if [[ ! -z ${add} ]]
        then
            echoContent red "=============================================================="
            echoContent yellow "1.CNAME www.digitalocean.com"
            echoContent yellow "2.CNAME amp.cloudflare.com"
            echoContent yellow "3.CNAME domain08.qiu4.ml"
            echoContent yellow "4.手动输入"
            echoContent red "=============================================================="
            read -p "请选择:" selectCDNType
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
                read -p "请输入想要自定义CDN IP或者域名:" setDomain
            ;;
            esac
            if [[ ! -z ${setDomain} ]]
            then
                # v2ray
                add=`echo ${add}|awk -F '["]' '{print $4}'`
                if [[ ! -z ${add} ]]
                then
                    sed -i "s/${add}/${setDomain}/g"  `grep "${add}" -rl ${configPath}`
                fi
                # sed -i "s/domain08.qiu4.ml1/domain08.qiu4.ml/g"  `grep "domain08.qiu4.ml1" -rl ${configPath}`
                if [[ `cat ${configPath}|grep -v grep|grep add|awk -F '["]' '{print $4}'` = ${setDomain} ]]
                then
                    echoContent green " ---> V2Ray CDN修改成功"
                    handleV2Ray stop
                    handleV2Ray start
                else
                    echoContent red " ---> 修改V2Ray CDN失败"
                fi

                # trojan
                if [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config.json" ]]
                then
                    add=`cat /etc/v2ray-agent/trojan/config.json|jq .websocket.add|awk -F '["]' '{print $2}'`
                    if [[ ! -z ${add} ]]
                    then
                        sed -i "s/${add}/${setDomain}/g"  `grep "${add}" -rl /etc/v2ray-agent/trojan/config.json`
                    fi
                fi

                if [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config.json" ]] && [[ `cat /etc/v2ray-agent/trojan/config.json|jq .websocket.add|awk -F '["]' '{print $2}'` = ${setDomain} ]]
                then
                    echoContent green "\n ---> Trojan CDN修改成功"
                    handleTrojanGo stop
                    handleTrojanGo start
                elif [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]
                then
                    echoContent red " ---> 修改Trojan CDN失败"
                fi
            fi
        else
            echoContent red " ---> 未安装可用类型"
        fi
    else
        echoContent red " ---> 未安装"
    fi
    menu
}

# 重置UUID
resetUUID(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 重置UUID"
    local resetStatus=false
    if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]] && [[ -f "/etc/v2ray-agent/v2ray/config_full.json" ]] && [[ -z "${customInstallType}" ]]
    then
        newUUID=`/etc/v2ray-agent/v2ray/v2ctl uuid`
        newDirectUUID=`/etc/v2ray-agent/v2ray/v2ctl uuid`

        currentUUID=`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[0].settings.clients[0].id|awk -F '["]' '{print $2}'`
        currentDirectUUID=`cat /etc/v2ray-agent/v2ray/config_full.json|jq .inbounds[0].settings.clients[1].id|awk -F '["]' '{print $2}'`
        if [[ ! -z "${currentUUID}" ]] && [[ ! -z "${currentDirectUUID}" ]]
        then
            sed -i "s/${currentUUID}/${newUUID}/g"  `grep "${currentUUID}" -rl /etc/v2ray-agent/v2ray/config_full.json`
            sed -i "s/${currentDirectUUID}/${newDirectUUID}/g"  `grep "${currentDirectUUID}" -rl /etc/v2ray-agent/v2ray/config_full.json`
        fi

        echoContent green " ---> V2Ray UUID重置完毕"
        handleV2Ray stop
        handleV2Ray start
        resetStatus=true
    elif [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]] && [[ -d "/etc/v2ray-agent/v2ray/conf" ]] && [[ ! -z "${customInstallType}" ]]
    then
        newUUID=`/etc/v2ray-agent/v2ray/v2ctl uuid`
        newDirectUUID=`/etc/v2ray-agent/v2ray/v2ctl uuid`

        uuidCount=0
        ls /etc/v2ray-agent/v2ray/conf|grep inbounds|while read row
        do
            cat /etc/v2ray-agent/v2ray/conf/${row}|jq .inbounds|jq -c '.[].settings.clients'|jq -c '.[].id'|while read row2
            do
                if [[ "${row}" = "02_VLESS_TCP_inbounds.json" ]]
                then
                    if [[ "${uuidCount}" != "1" ]]
                    then
                        oldUUID=`echo ${row2}|awk -F "[\"]" '{print $2}'`
                        sed -i "s/${oldUUID}/${newUUID}/g"  `grep "${oldUUID}" -rl /etc/v2ray-agent/v2ray/conf/${row}`
                    fi
                    if [[ "${row}" = "02_VLESS_TCP_inbounds.json" ]]
                    then
                        uuidCount=1
                    fi
                else
                    oldUUID=`echo ${row2}|awk -F "[\"]" '{print $2}'`
                    sed -i "s/${oldUUID}/${newUUID}/g"  `grep "${oldUUID}" -rl /etc/v2ray-agent/v2ray/conf/${row}`
                fi

            done
        done

        currentDirectUUID=`cat /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json|jq .inbounds|jq -c '.[].settings.clients[1].id'|awk -F "[\"]" '{print $2}'`
        if [[ ! -z "${currentDirectUUID}" ]]
        then
            echoContent red currentDirectUUID:${currentDirectUUID}
            sed -i "s/${currentDirectUUID}/${newDirectUUID}/g"  `grep "${currentDirectUUID}" -rl /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json`
        fi

        echoContent green " ---> V2Ray UUID重置完毕"
        handleV2Ray stop
        handleV2Ray start
        resetStatus=true
    else
        echoContent red " ---> 未使用脚本安装V2Ray"
        menu
        exit 0;
    fi

    if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config.json" ]]
    then
        cat /etc/v2ray-agent/trojan/config.json|jq .password|jq -c '.[]'|while read row
        do
            oldUUID=`echo ${row}|awk -F "[\"]" '{print $2}'`
            sed -i "s/${oldUUID}/${newUUID}/g"  `grep "${oldUUID}" -rl /etc/v2ray-agent/trojan/config.json`
        done
        echoContent green " ---> Trojan UUID重置完毕"
        handleTrojanGo stop
        handleTrojanGo start
        resetStatus=true
    else
        echoContent red " ---> 未使用脚本安装Trojan"
    fi
    if [[ "${resetStatus}" = "true" ]]
    then
        showAccounts 1
    fi
}
# 个性化安装
customInstall(){
    echoContent skyBlue "\n========================个性化安装============================"
    echoContent yellow "VLESS前置，默认安装0，如果只需要安装0，则只选择0即可"
    echoContent yellow "0.VLESS+TLS/XTLS+TCP"
    echoContent yellow "1.VLESS+TLS+WS[CDN]"
    echoContent yellow "2.VMess+TLS+TCP"
    echoContent yellow "3.VMess+TLS+WS[CDN]"
    echoContent yellow "4.Trojan、Trojan+WS[CDN]"
    read -p "请选择[多选]，[例如:123]:" customInstallType
    echoContent skyBlue "--------------------------------------------------------------"
    if [[ -z ${customInstallType} ]]
    then
        echoContent red " ---> 不可为空"
        customInstall
    elif [[ "${customInstallType}" =~ ^[0-4]+$ ]]
    then
        totalProgress=17
        globalType=vlesstcpws
        mkdirTools 1
        installTools 2
        # 申请tls
        initTLSNginxConfig 3
        installTLS 4
        handleNginx stop
        initNginxConfig vlesstcpws 5
        # 随机path
        if [[ ! -z `echo ${customInstallType}|grep 1` ]] || [[ ! -z `echo ${customInstallType}|grep 3` ]] || [[ ! -z `echo ${customInstallType}|grep 4` ]]
        then
            randomPathFunction 6
            customCDNIP 7
        fi
        nginxBlog 8
        handleNginx start

        # 安装V2Ray
        installV2Ray 9
        installV2RayService 10
        initV2RayConfig custom 11
        if [[ ! -z `echo ${customInstallType}|grep 4` ]]
        then
            installTrojanGo 12
            installTrojanService 13
            initTrojanGoConfig 14
            handleTrojanGo stop
            handleTrojanGo start
        else
            # 这里需要删除trojan的服务
            handleTrojanGo stop
            rm -rf /etc/v2ray-agent/trojan/*
            rm -rf /etc/systemd/system/trojan-go.service
        fi
        installCronTLS 15
        handleV2Ray stop
        handleV2Ray start
        # 生成账号
        checkGFWStatue 16
        showAccounts 17
    else
        echoContent red " ---> 输入不合法"
        customInstall
    fi
}
# 初始化个性化安装类型
initCustomInstallType(){
    if [[ -d "/etc/v2ray-agent/" ]] && [[ -d "/etc/v2ray-agent/v2ray/" ]] && [[ -d "/etc/v2ray-agent/v2ray/conf" ]]
    then
        while read row
        do
             if [[ ! -z `echo ${row}|grep VLESS_TCP_inbounds` ]]
            then
                customInstallType=${customInstallType}'0'
            fi
            if [[ ! -z `echo ${row}|grep VLESS_WS_inbounds` ]]
            then
                customInstallType=${customInstallType}'1'
            fi
            if [[ ! -z `echo ${row}|grep VMess_TCP_inbounds` ]]
            then
                customInstallType=${customInstallType}'2'
            fi
            if  [[ ! -z `echo ${row}|grep VMess_WS_inbounds` ]]
            then
                customInstallType=${customInstallType}'3'
            fi
        done < <(echo `ls /etc/v2ray-agent/v2ray/conf|grep -v grep|grep inbounds.json|awk -F "[.]" '{print $1}'`)
    fi
}
# 主菜单
menu(){
    cd
    echoContent red "\n=============================================================="
    echoContent green "作者：mack-a"
    echoContent green "当前版本：v2.1.5"
    echoContent green "Github：https://github.com/mack-a/v2ray-agent"
    echoContent green "描述：七合一共存脚本"
    echoContent red "=============================================================="
    echoContent yellow "1.安装"
    echoContent yellow "2.任意组合安装"
    echoContent skyBlue "-------------------------工具管理-----------------------------"
    echoContent yellow "3.查看账号"
    echoContent yellow "4.自动排错 [仅V2Ray]"
    echoContent yellow "5.更新证书"
    echoContent yellow "6.更换CDN节点"
    echoContent yellow "7.重置uuid"
    echoContent skyBlue "-------------------------版本管理-----------------------------"
    echoContent yellow "8.V2Ray版本管理"
    echoContent yellow "9.升级Trojan-Go"
    echoContent yellow "10.升级脚本"
    echoContent yellow "11.安装BBR"
    echoContent skyBlue "-------------------------脚本管理-----------------------------"
    echoContent yellow "12.查看日志"
    echoContent yellow "13.卸载脚本"
    echoContent red "=============================================================="
    automaticUpgrade
    initCustomInstallType
    mkdirBaseDIR
    aliasInstall
    read -p "请选择:" selectInstallType
     case ${selectInstallType} in
        1)
            defaultInstall
        ;;
        2)
            customInstall
        ;;
        3)
            showAccounts 1
        ;;
        4)
            checkFail 1
        ;;
        5)
            renewalTLS 1
        ;;
        6)
            updateV2RayCDN 1
        ;;
        7)
            resetUUID 1
        ;;
        8)
            v2rayVersionManageMenu 1
        ;;
        9)
            updateTrojanGo 1
        ;;
        10)
            updateV2RayAgent 1
        ;;
        11)
            bbrInstall
        ;;
        12)
            checkLog 1
        ;;
        13)
            unInstall 1
        ;;
    esac
}
# 安装BBR
bbrInstall(){
    echoContent red "\n=============================================================="
    echoContent green "BBR脚本用的[ylx2016]的成熟作品，地址[https://github.com/ylx2016/Linux-NetSpeed]，请熟知"
    echoContent red "   1.安装【推荐原版BBR+FQ】"
    echoContent red "   2.回退主目录"
    echoContent red "=============================================================="
    read -p "请选择：" installBBRStatus
    if [[ "${installBBRStatus}" = "1" ]]
    then
        wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    else
        menu
    fi
}
# 查看、检查日志
checkLog(){
    echoContent skyBlue "\n功能 $1/${totalProgress} : 查看日志"
    echoContent red "\n=============================================================="
    echoContent skyBlue "-------------------------V2Ray--------------------------------"
    echoContent yellow "1.查看V2Ray Info日志"
    echoContent yellow "2.监听V2Ray Info日志"
    echoContent yellow "3.查看V2Ray Error日志"
    echoContent yellow "4.监听V2Ray Error日志"
    echoContent yellow "5.清空V2Ray日志"
    echoContent skyBlue "-----------------------Trojan-Go------------------------------"
    echoContent yellow "6.查看Trojan-Go日志"
    echoContent yellow "7.监听Trojan-GO日志"
    echoContent yellow "8.清空Trojan-GO日志"
    echoContent skyBlue "-------------------------Nginx--------------------------------"
    echoContent yellow "9.查看Nginx日志"
    echoContent yellow "10.清空Nginx日志"
    echoContent red "=============================================================="
    read -p "请选择：" selectLogType
    case ${selectLogType} in
        1)
            cat /etc/v2ray-agent/v2ray/v2ray_access.log
        ;;
        2)
            tail -f /etc/v2ray-agent/v2ray/v2ray_access.log
        ;;
        3)
            cat /etc/v2ray-agent/v2ray/v2ray_error.log
        ;;
        4)
            tail -f /etc/v2ray-agent/v2ray/v2ray_error.log
        ;;
        5)
            echo '' > /etc/v2ray-agent/v2ray/v2ray_access.log
            echo '' > /etc/v2ray-agent/v2ray/v2ray_error.log
            echoContent green " ---> 清空完毕"
        ;;
        6)
            cat /etc/v2ray-agent/trojan/trojan.log
        ;;
        7)
            tail -f /etc/v2ray-agent/trojan/trojan.log
        ;;
        8)
            echo '' > /etc/v2ray-agent/trojan/trojan.log
            echoContent green " ---> 清空完毕"
        ;;
        9)
            cat /var/log/nginx/access.log
        ;;
        10)
            echo '' > /var/log/nginx/access.log
        ;;
    esac
    sleep 2
    menu
}
# 脚本快捷方式
aliasInstall(){
    if [[ -f "/root/install.sh" ]] && [[ -d "/etc/v2ray-agent" ]] && [[ ! -z `cat /root/install.sh|grep "作者：mack-a"` ]]
    then
        mv /root/install.sh /etc/v2ray-agent/install.sh
        if [[ -d "/usr/bin/" ]] && [[ ! -f "/usr/bin/vasma" ]]
        then
            ln -s /etc/v2ray-agent/install.sh /usr/bin/vasma
            chmod 700 /usr/bin/vasma
            rm -rf /root/install.sh
        elif [[ -d "/usr/sbin" ]] && [[ ! -f "/usr/sbin/vasma" ]]
        then
            ln -s /etc/v2ray-agent/install.sh /usr/sbin/vasma
            chmod 700 /usr/sbin/vasma
            rm -rf /root/install.sh
        fi
        echoContent green "快捷方式创建成功，可执行[vasma]重新打开脚本"
    fi
}
# 默认安装
defaultInstall(){
    customInstallType=
    totalProgress=17
    globalType=vlesstcpws
    mkdirTools 1
    installTools 2
    # 申请tls
    initTLSNginxConfig 3
    installTLS 4
    handleNginx stop
    initNginxConfig vlesstcpws 5
    randomPathFunction 6
    # 安装V2Ray
    installV2Ray 7
    installV2RayService 8
    installTrojanGo 9
    installTrojanService 10
    customCDNIP 11
    initV2RayConfig vlesstcpws 12
    initTrojanGoConfig 13
    installCronTLS 14
    nginxBlog 15
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
# 杀死sleep
killSleep(){
    if [[ ! -z `ps -ef|grep -v grep|grep sleep` ]]
    then
        ps -ef|grep -v grep|grep sleep|awk '{print $3}'|xargs kill -9 > /dev/null 2>&1
        killSleep > /dev/null 2>&1
    fi
}
# 检查系统
checkSystem(){
	if [[ ! -z `find /etc -name "redhat-release"` ]] || [[ ! -z `cat /proc/version | grep -i "centos" | grep -v grep ` ]]
	then
	    centosVersion=`rpm -q centos-release|awk -F "[-]" '{print $3}'|awk -F "[.]" '{print $1}'`
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
menu
