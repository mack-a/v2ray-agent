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
uuidws=
uuidtcp=
uuidVlessWS=
uuidtcpdirect=

trap 'onCtrlC' INT
function onCtrlC () {
    echo
    killSleep > /dev/null 2>&1
    exit;
}
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
    mkdir -p /etc/v2ray-agent/v2ray
    mkdir -p /etc/v2ray-agent/trojan
    mkdir -p /etc/systemd/system/
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
            killSleep > /dev/null 2>&1
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
            killSleep > /dev/null 2>&1
            exit 0
        fi
    fi
}
# 初始化Nginx申请证书配置
initTLSNginxConfig(){
    handleNginx stop
    killSleep > /dev/null 2>&1
    killSleep > /dev/null 2>&1
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
        # 测试nginx
        echoContent green " ---> 检查Nginx是否正常访问"
        domainResult=`curl -s ${domain}/test|grep fjkvymb6len`
        if [[ ! -z ${domainResult} ]]
        then
            handleNginx stop
            echoContent green " ---> Nginx配置成功"
        else
            echoContent red "    无法正常访问服务器，请检测域名是否正确、域名的DNS解析以及防火墙设置是否正确--->"
            killSleep > /dev/null 2>&1
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
            progressTools "yellow" "    TLS安装失败，请检查acme日志--->"
            exit 0
        elif [[ -z `cat /etc/v2ray-agent/tls/${domain}.key` ]]
        then
            progressTools "yellow" "    TLS安装失败，请检查acme日志--->"
            exit 0
        fi
        echoContent green " ---> TLS生成成功"
        # 记录证书生成的时间
        # echo ${domain} `date +%s` > /etc/v2ray-agent/tls/config
    elif  [[ -z `cat /etc/v2ray-agent/tls/${domain}.crt` ]] || [[ -z `cat /etc/v2ray-agent/tls/${domain}.key` ]]
    then
        progressTools "red" "  检测到错误证书，需重新生成，重新生成中--->" 18
        rm -rf /etc/v2ray-agent/tls/*
        installTLS
    else
        echoContent green " ---> 检测到证书"
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
    progressTools "yellow" "请输入自定义路径[例: alone]，不需要斜杠，[回车]随机路径"
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
    unzip  /usr/share/nginx/html.zip -d /usr/share/nginx/html > /dev/null
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
            progressTools "red" "  Nginx启动失败，请检查日志--->"
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
if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]] && [[ -d "/etc/v2ray-agent/tls" ]] && [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]] && [[ -f "/etc/v2ray-agent/v2ray/config.json" ]] && [[ -d "/root/.acme.sh" ]]
then
    tcp=\`cat /etc/v2ray-agent/v2ray/config.json|jq .inbounds[0]\`
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
    if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]] && [[ -d "/etc/v2ray-agent/tls" ]] && [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]] && [[ -f "/etc/v2ray-agent/v2ray/config.json" ]] && [[ -d "/root/.acme.sh" ]]
    then
        tcp=`cat /etc/v2ray-agent/v2ray/config.json|jq .inbounds[0]`
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
    if [[ -z `ls -F /etc/v2ray-agent/v2ray/|grep "v2ray"` ]] || [[ -z `ls -F /etc/v2ray-agent/v2ray/|grep "v2ctl"` ]]
    then
        version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        # version="v4.27.4"
        echoContent green " ---> v2ray-core版本:${version}"
        wget -q -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip
        unzip /etc/v2ray-agent/v2ray/v2ray-linux-64.zip -d /etc/v2ray-agent/v2ray > /dev/null
        rm -rf /etc/v2ray-agent/v2ray/v2ray-linux-64.zip
    else
        # progressTools "green" "  v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
        echoContent green " ---> v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
        read -p "是否重新安装？[y/n]:" reInstalV2RayStatus
        if [[ "${reInstalV2RayStatus}" = "y" ]]
        then
            rm -rf /etc/v2ray-agent/v2ray/*
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
        unzip /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip -d /etc/v2ray-agent/trojan > /dev/null
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
        updateV2Ray 1 1
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
            updateV2Ray 1 1 ${version}
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
        if [[ ! -z "$3" ]]
        then
            version=$3
        else
            version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        fi
        echoContent green " ---> v2ray-core版本:${version}"
        wget -q -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip
        unzip /etc/v2ray-agent/v2ray/v2ray-linux-64.zip -d /etc/v2ray-agent/v2ray > /dev/null
        if [[ "$2" = "backup" ]]
        then
            cp /tmp/config.json /etc/v2ray-agent/v2ray/config.json
        fi

        rm -rf /etc/v2ray-agent/v2ray/v2ray-linux-64.zip
        handleV2Ray stop
        handleV2Ray start
    else
        echoContent green " ---> 当前v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
        if [[ ! -z `/etc/v2ray-agent/v2ray/v2ray --version` ]]
        then
            if [[ ! -z "$3" ]]
            then
                version=$3
            else
                version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
            fi

            # echo version:${version}
            # echo version2:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`
            if [[ ! -z "$3" ]]
            then
                read -p "回退版本为${version}，是否继续？[y/n]:" rollbackV2RayStatus
                if [[ "${rollbackV2RayStatus}" = "y" ]]
                then
                    handleV2Ray stop
                    cp /etc/v2ray-agent/v2ray/config.json /tmp/config.json
                    rm -rf /etc/v2ray-agent/v2ray/*
                    updateV2Ray $1 backup $3
                else
                    echoContent green " ---> 放弃回退版本"
                fi
            elif [[ "${version}" = "v`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`" ]]
            then
                read -p "当前版本与最新版相同，是否重新安装？[y/n]:" reInstalV2RayStatus
                if [[ "${reInstalV2RayStatus}" = "y" ]]
                then
                    handleV2Ray stop
                    cp /etc/v2ray-agent/v2ray/config.json /tmp/config.json
                    rm -rf /etc/v2ray-agent/v2ray/*
                    updateV2Ray $1 backup
                else
                    echoContent green " ---> 放弃重新安装"
                fi
            else
                read -p "最新版本为：${version}，是否更新？[y/n]：" installV2RayStatus
                if [[ "${installV2RayStatus}" = "y" ]]
                then
                    cp /etc/v2ray-agent/v2ray/config.json /tmp/config.json
                    rm -rf /etc/v2ray-agent/v2ray/*
                    updateV2Ray $1 backup
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
        unzip /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip -d /etc/v2ray-agent/trojan > /dev/null
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
    wget -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod +x install.sh && ./install.sh
}
# 验证整个服务是否可用
checkGFWStatue(){
    # 验证整个服务是否可用
#    progressTools "yellow" "验证服务是否可用--->"
    echoContent skyBlue "\n进度 $1/${totalProgress} : 验证服务是否可用"
    if [[ "${globalType}" = "wss" ]]
    then

        sleep 3
        if [[ ! -z `curl -s -L https://${domain}/${customPath}|grep -v grep|grep "Bad Request"` ]]
        then
            echoContent green " ---> 服务可用"
        else
            echoContent red " ---> 服务不可用"
            progressTools "red" "    1.请检查Cloudflare->域名->SSL/TLS->Overview->Your SSL/TLS encryption mode is 是否是Full--->"
            progressTools "red" "    2.请执行[ps -ef|grep v2ray]查看结果是否有如下信息，如果存在则执行脚本选择[4查看账号]即可--->"
            progressTools "red" "       /etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config.json"
            progressTools "red" "       /etc/v2ray-agent/v2ray/v2ray -config /etc/v2ray-agent/v2ray/config.json"
            progressTools "red" "    3.如以上都无法解决，请联系开发者[https://t.me/mack_a]"

            progressTools "red" "  错误日志:`curl -s -L https://${domain}/${customPath}`"
            exit 0
        fi
    elif [[ "${globalType}" = "tcp" ]]
    then
        echo '' > /etc/v2ray-agent/v2ray/v2ray_access.log
        curl --connect-time 3  --max-time 1 --url https://${domain} > /dev/null 2>&1
        sleep 0.1
        if [[ ! -z `cat /etc/v2ray-agent/v2ray/v2ray_access.log|grep -v grep|grep "Not Found"` ]]
        then
            echoContent green " ---> 服务可用"
        else
            progressTools "red" "    服务不可用"
            progressTools "red" "     1.请检查云朵是否关闭"
            progressTools "red" "     2.请手动尝试使用账号并观察日志，日志路径[/etc/v2ray-agent/v2ray/v2ray_access.log]"
            exit 0
        fi
    elif [[ "${globalType}" = "vlesstcpws" ]]
    then
        echoContent green " ---> 等待三秒"
        sleep 3
        if [[ ! -z `curl -s -L https://${domain}/${customPath}|grep -v grep|grep "Bad Request"` ]]
        then
            echoContent green " ---> 服务可用"
        else
            progressTools "red" "    服务不可用，请检查Cloudflare->域名->SSL/TLS->Overview->Your SSL/TLS encryption mode is 是否是Full--->"
            progressTools "red" "  错误日志:`curl -s -L https://${domain}/${customPath}`"
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
        ExecStart=/etc/v2ray-agent/v2ray/v2ray -config /etc/v2ray-agent/v2ray/config.json
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
            /usr/bin/v2ray/v2ray -config /etc/v2ray-agent/v2ray/config.json & > /dev/null 2>&1
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
            echoContent red "请手动执行【/etc/v2ray-agent/v2ray/v2ray -config /etc/v2ray-agent/v2ray/config.json】,查看错误日志"
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
            /etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config.json & > /dev/null 2>&1
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
            echoContent red "请手动执行【/etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config.json】,查看错误日志"
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

    uuidtcp=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    uuidws=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    uuidVmessTcp=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    uuidVlessWS=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    uuidtcpdirect=`/etc/v2ray-agent/v2ray/v2ctl uuid`

    echoContent skyBlue "\n进度 $2/${totalProgress} : 初始化V2Ray配置"

    if [[ "$1" = "vlesstcpws" ]]
    then
        cat << EOF > /etc/v2ray-agent/v2ray/config.json
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
            "id": "${uuidtcp}",
            "flow":"xtls-rprx-origin",
            "email": "${domain}_VLESS_XTLS/TLS-origin_TCP"
          },
          {
            "id": "${uuidtcpdirect}",
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
            "id": "${uuidws}",
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
    },
    {
      "port": 31298,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuidVmessTcp}",
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
            "id": "${uuidVlessWS}",
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
    fi
}
# 初始化Trojan-Go配置
initTrojanGoConfig(){
    uuidTrojanGo=`/etc/v2ray-agent/v2ray/v2ctl uuid`
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
        "${uuidTrojanGo}"
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
        echoContent yellow " ---> Trojan-Go(WS+TLS)"
        echoContent green "    trojan://${id}@${add}:443?allowInsecure=0&&peer=${host}&sni=${host}&plugin=obfs-local;obfs=websocket;obfs-host=${host};obfs-uri=${path}#${host}_trojan_ws\n"
        echoContent yellow " ---> 二维码 Trojan-Go(WS+TLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${add}%3a443%3fallowInsecure%3d0%26peer%3d${host}%26plugin%3dobfs-local%3bobfs%3dwebsocket%3bobfs-host%3d${host}%3bobfs-uri%3d${path}%23${host}_trojan_ws\n"
    fi
}
# quanMult base64Code
quanMultBase64Code(){
    local ps=$1
    local id=$2
    local host=$3
    local path=$4
    qrCodeBase64Quanmult=`echo -n ''${ps}' = vmess, '${add}', 443, aes-128-cfb, '${id}', over-tls=true, tls-host='${host}', certificate=1, obfs=ws, obfs-path='${path}', obfs-header="Host: '${host}'[Rr][Nn]User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 11_2_6 like Mac OS X) AppleWebKit/604.5.6 (KHTML, like Gecko) Mobile/15D100"'|base64`
    qrCodeBase64Quanmult=`echo ${qrCodeBase64Quanmult}|sed 's/ //g'`
    echoContent red "Quantumult vmess--->"
    echoContent green "    vmess://${qrCodeBase64Quanmult}\n"
    echo '' >> /etc/v2ray-agent/v2ray/usersv2ray.conf
    echo "Quantumult:" >> /etc/v2ray-agent/v2ray/usersv2ray.conf
    echo "  vmess://${qrCodeBase64Quanmult}" >> /etc/v2ray-agent/v2ray/usersv2ray.conf
    echoContent red "Quantumult 明文--->"
    echoContent green  '    '${ps}' = vmess, '${add}', 443, aes-128-cfb, '${id}', over-tls=true, tls-host='${host}', certificate=1, obfs=ws, obfs-path='${path}', obfs-header="Host: '${host}'[Rr][Nn]User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 11_2_6 like Mac OS X) AppleWebKit/604.5.6 (KHTML, like Gecko) Mobile/15D100"'
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
    if [[ -d "/etc/v2ray-agent/" ]] && [[ -d "/etc/v2ray-agent/v2ray/" ]] && [[ -f "/etc/v2ray-agent/v2ray/config.json" ]]
    then
        showStatus=true
        # VLESS tcp
        local tcp=`cat /etc/v2ray-agent/v2ray/config.json|jq .inbounds[0]`
        local tcpID=`echo ${tcp}|jq .settings.clients[0].id`
        local tcpEmail="`echo ${tcp}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"

        # XTLS Direct
        local tcpIDirect=`echo ${tcp}|jq .settings.clients[1].id`
        local tcpDirectEmail="`echo ${tcp}|jq .settings.clients[1].email|awk -F '["]' '{print $2}'`"
        host=`echo ${tcp}|jq .streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`

         # VLESS ws
        local vlessWS=`cat /etc/v2ray-agent/v2ray/config.json|jq .inbounds[3]`
        local vlessWSID=`echo ${vlessWS}|jq .settings.clients[0].id`
        local vlessWSAdd=`echo ${vlessWS}|jq .settings.clients[0].add|awk -F '["]' '{print $2}'`
        local vlessWSEmail="`echo ${vlessWS}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local vlessWSPath=`echo ${vlessWS}|jq .streamSettings.wsSettings.path`

        # Vmess ws
        local ws=`cat /etc/v2ray-agent/v2ray/config.json|jq .inbounds[1]`
        local wsID=`echo ${ws}|jq .settings.clients[0].id`
        local wsAdd=`echo ${ws}|jq .settings.clients[0].add|awk -F '["]' '{print $2}'`
        local wsEmail="`echo ${ws}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local wsPath=`echo ${ws}|jq .streamSettings.wsSettings.path`

        # Vmess tcp
        local vmessTCP=`cat /etc/v2ray-agent/v2ray/config.json|jq .inbounds[2]`
        local vmessTCPID=`echo ${vmessTCP}|jq .settings.clients[0].id`
        local vmessTCPAdd=`echo ${vmessTCP}|jq .settings.clients[0].add|awk -F '["]' '{print $2}'`
        local vmessTCPEmail="`echo ${vmessTCP}|jq .settings.clients[0].email|awk -F '["]' '{print $2}'`"
        local vmessTCPath=`echo ${vmessTCP}|jq .streamSettings.tcpSettings.header.request.path[0]`


        echoContent skyBlue "\n============================ VLESS TCP TLS/XTLS-origin ==========================="
        defaultBase64Code vlesstcp ${tcpEmail} "${tcpID}" "${host}" ${add}

        echoContent skyBlue "\n============================ VLESS TCP TLS/XTLS-direct ==========================="
        defaultBase64Code vlesstcp ${tcpDirectEmail} "${tcpIDirect}" "${host}" ${add}

        echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================"
        defaultBase64Code vlessws ${vlessWSEmail} "${vlessWSID}" "${host}" "${vlessWSPath}" ${wsAdd}

        echoContent skyBlue "\n================================ VMess WS TLS CDN ================================"
        defaultBase64Code vmessws ${wsEmail} "${wsID}" "${host}" "${wsPath}" ${wsAdd}

        echoContent skyBlue "\n================================= VMess TCP TLS  ================================="
        defaultBase64Code vmesstcp ${vmessTCPEmail} "${vmessTCPID}" "${host}" "${vmessTCPath}" "${host}"
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

    rm -rf /etc/systemd/system/v2ray.service
    echoContent green " ---> 删除V2Ray开机自启完成"
    rm -rf /etc/systemd/system/trojan-go.service
    echoContent green " ---> 删除Trojan-Go开机自启完成"

    if [[ -d "/etc/v2ray-agent/tls" ]] && [[ ! -z `find /etc/v2ray-agent/tls/ -name "*.key"` ]] && [[ ! -z `find /etc/v2ray-agent/tls/ -name "*.crt"` ]]
    then
        mv /etc/v2ray-agent/tls /tmp
        if [[ ! -z `find /tmp/tls -name '*.key'` ]]
        then
            echoContent yellow " ---> 备份证书成功，请注意留存。[/tmp/tls]"
        fi
    fi

    rm -rf /etc/v2ray-agent
    rm -rf /etc/nginx/conf.d/alone.conf
    echoContent green " ---> 卸载V2Ray完成"
    echoContent green " ---> 卸载完成"
}
# 检查错误
checkFail(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 检查错误"
    if [[ -d "/etc/v2ray-agent" ]]
    then
        if [[ -d "/etc/v2ray-agent/v2ray/" ]]
        then
            if [[ -z `ls -F /etc/v2ray-agent/v2ray/|grep "v2ray"` ]] || [[ -z `ls -F /etc/v2ray-agent/v2ray/|grep "v2ctl"` ]]
            then
                echoContent red " ---> V2Ray 未安装"
            else
                echoContent green " ---> v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
                if [[ -z `/etc/v2ray-agent/v2ray/v2ray --test /etc/v2ray-agent/v2ray/config.json|tail -n +3|grep "Configuration OK"` ]]
                then
                    echoContent red " ---> V2Ray 配置文件异常"
                    /etc/v2ray-agent/v2ray/v2ray --test /etc/v2ray-agent/v2ray/config.json
                elif [[ -z `ps -ef|grep -v grep|grep v2ray` ]]
                then
                    echoContent red " ---> V2Ray 未启动"
                else
                    echoContent green " ---> V2Ray 正常运行"
                fi
            fi
        else
            echoContent red " ---> V2Ray 未安装"
        fi

        if [[ -z `ps -ef|grep -v grep|grep nginx` ]]
        then
            echoContent red " ---> Nginx 未启动，伪装博客无法使用"
        else
            echoContent green " ---> Nginx 正常运行"
        fi
    else
        echoContent red " ---> 未使用脚本安装"
    fi
}
# 修改V2Ray CDN节点
updateV2RayCDN(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 修改CDN节点"
    if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]] && [[ -f "/etc/v2ray-agent/v2ray/config.json" ]]
    then
        local add=`cat /etc/v2ray-agent/v2ray/config.json|grep -v grep|grep add`
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
                    sed -i "s/${add}/${setDomain}/g"  `grep "${add}" -rl /etc/v2ray-agent/v2ray/config.json`
                fi
                # sed -i "s/domain08.qiu4.ml1/domain08.qiu4.ml/g"  `grep "domain08.qiu4.ml1" -rl /etc/v2ray-agent/v2ray/config.json`
                if [[ `cat /etc/v2ray-agent/v2ray/config.json|grep -v grep|grep add|awk -F '["]' '{print $4}'` = ${setDomain} ]]
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

                if [[ `cat /etc/v2ray-agent/trojan/config.json|jq .websocket.add|awk -F '["]' '{print $2}'` = ${setDomain} ]]
                then
                    echoContent green "\n ---> Trojan CDN修改成功"
                    handleTrojanGo stop
                    handleTrojanGo start
                else
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
# 主菜单
menu(){
    cd
    echoContent red "\n=============================================================="
    echoContent green "作者：mack-a"
    echoContent green "当前版本：v2.0.12"
    echoContent green "Github：https://github.com/mack-a/v2ray-agent"
    echoContent green "描述：七合一共存脚本"
    echoContent red "=============================================================="
    echoContent yellow "1.安装"
    echoContent skyBlue "-------------------------工具管理-----------------------------"
    echoContent yellow "2.查看账号"
    echoContent yellow "3.自动排错"
    echoContent yellow "4.更新证书"
    echoContent yellow "5.更换CDN节点"
    echoContent skyBlue "-------------------------版本管理-----------------------------"
    echoContent yellow "6.V2Ray版本管理"
    echoContent yellow "7.升级Trojan-Go"
    echoContent yellow "8.升级脚本"
    echoContent yellow "9.安装BBR"
    echoContent skyBlue "-------------------------脚本管理-----------------------------"
    echoContent yellow "10.查看日志"
    echoContent yellow "11.卸载脚本"
    echoContent yellow "12.重置uuid[todo]"
    echoContent yellow "13.任意组合安装[todo]"
    echoContent red "=============================================================="
    automaticUpgrade
    read -p "请选择:" selectInstallType
     case ${selectInstallType} in
        1)
            installV2RayVLESSTCPWSTLS
        ;;
        2)
            showAccounts 1
        ;;
        3)
            checkFail 1
        ;;
        4)
            renewalTLS 1
        ;;
        5)
            updateV2RayCDN 1
        ;;
        6)
            v2rayVersionManageMenu 1
        ;;
        7)
            updateTrojanGo 1
        ;;
        8)
            updateV2RayAgent 1
        ;;
        9)
            bbrInstall
        ;;
        10)
            checkLog 1
        ;;
        11)
            unInstall 1
        ;;
    esac
    exit 0;
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
installV2RayVLESSTCPWSTLS(){
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
    initTrojanGoConfig 12
    initV2RayConfig vlesstcpws 13
    installCronTLS 14
    nginxBlog 15
    handleV2Ray stop
    handleV2Ray start
    handleNginx start
    handleTrojanGo stop
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
	if [[ ! -z `find /etc -name "redhat-release"` ]] || [[ ! -z `cat /proc/version | grep -i "centos" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "red hat" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "redhat" | grep -v grep ` ]]
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
        killSleep > /dev/null 2>&1
        exit 0;
    fi
}

checkSystem
menu
