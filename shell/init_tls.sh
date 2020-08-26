#!/usr/bin/env bash
installType='yum -y install'
removeType='yum -y remove'
upgrade="yum -y update"
echoType='echo -e'
cp=`which cp`
# 打印
echoColor(){
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
# 选择系统执行工具
checkSystem(){

	if [[ ! -z `find /etc -name "redhat-release"` ]] || [[ ! -z `cat /proc/version | grep -i "centos" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "red hat" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "redhat" | grep -v grep ` ]]
	then
		release="centos"
		installType='yum -y install'
		removeType='yum -y remove'
		upgrade="yum update -y"
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
# 安装工具包
installTools(){
    echoColor yellow "更新"
    ${upgrade}
    if [[ -z `find /usr/bin/ -executable -name "socat"` ]]
    then
        echoColor yellow "\nsocat未安装，安装中\n"
        ${installType} socat >/dev/null
        echoColor green "socat安装完毕"
    fi
    echoColor yellow "\n检测是否安装Nginx"
    if [[ -z `find /sbin/ -executable -name 'nginx'` ]]
    then
        echoColor yellow "nginx未安装，安装中\n"
        ${installType} nginx >/dev/null
        echoColor green "nginx安装完毕"
    else
        echoColor green "nginx已安装\n"
    fi
    echoColor yellow "检测是否安装acme.sh"
    if [[ -z `find ~/.acme.sh/ -name "acme.sh"` ]]
    then
        echoColor yellow "\nacme.sh未安装，安装中\n"
        curl -s https://get.acme.sh | sh >/dev/null
        echoColor green "acme.sh安装完毕\n"
    else
        echoColor green "acme.sh已安装\n"
    fi

}
# 恢复配置
resetNginxConfig(){
    `cp -Rrf /tmp/mack-a/nginx/nginx.conf /etc/nginx/nginx.conf`
    rm -rf /etc/nginx/conf.d/5NX2O9XQKP.conf
    echoColor green "\n恢复配置完毕"
}
# 备份
bakConfig(){
    mkdir -p /tmp/mack-a/nginx
    `cp -Rrf /etc/nginx/nginx.conf /tmp/mack-a/nginx/nginx.conf`
}
# 安装证书
installTLS(){
    echoColor yellow "请输入域名【例:blog.v2ray-agent.com】："
    read domain
    if [[ -z ${domain} ]]
    then
        echoColor red "域名未填写\n"
        installTLS
    fi
    # 备份
    bakConfig
    # 替换原始文件中的域名
    if [[ ! -z `cat /etc/nginx/nginx.conf|grep -v grep|grep "${domain}"` ]]
    then
        sed -i "s/${domain}/X655Y0M9UM9/g"  `grep "${domain}" -rl /etc/nginx/nginx.conf`
    fi

    touch /etc/nginx/conf.d/6GFV1ES52V2.conf
    echo "server {listen 80;server_name ${domain};root /usr/share/nginx/html;location ~ /.well-known {allow all;}location /test {return 200 '5NX2O9XQKP';}}" > /etc/nginx/conf.d/5NX2O9XQKP.conf
    nginxStatus=1;
    if [[ ! -z `ps -ef|grep -v grep|grep nginx` ]]
    then
        nginxStatus=2;
        ps -ef|grep -v grep|grep nginx|awk '{print $2}'|xargs kill -9
        sleep 0.5
        nginx
    else
        nginx
    fi
    echoColor yellow "\n验证域名以及服务器是否可用"
    if [[ ! -z `curl -s ${domain}/test|grep 5NX2O9XQKP` ]]
    then
        ps -ef|grep -v grep|grep nginx|awk '{print $2}'|xargs kill -9
        sleep 0.5
        echoColor green "服务可用，生成TLS中，请等待\n"
    else
        echoColor red "服务不可用请检测dns配置是否正确"
        # 恢复备份
        resetNginxConfig
        exit 0;
    fi
    sudo ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 >/dev/null
    ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /tmp/mack-a/nginx/${domain}.crt --keypath /tmp/mack-a/nginx/${domain}.key --ecc >/dev/null
    if [[ -z `cat /tmp/mack-a/nginx/${domain}.key` ]]
    then
        echoColor red "证书key生成失败，请重新运行"
        resetNginxConfig
        exit
    elif [[ -z `cat /tmp/mack-a/nginx/${domain}.crt` ]]
    then
        echoColor red "证书crt生成失败，请重新运行"
        resetNginxConfig
        exit
    fi
    echoColor green "证书生成成功"
    echoColor green "证书目录/tmp/mack-a/nginx"
    ls /tmp/mack-a/nginx

    resetNginxConfig
    if [[ ${nginxStatus} = 2  ]]
    then
        nginx
    fi
}

init(){
    echoColor red "\n=============================="
    echoColor yellow "此脚本注意事项"
    echoColor green "   1.会安装依赖所需依赖"
    echoColor green "   2.会把Nginx配置文件备份"
    echoColor green "   3.会安装Nginx、acme.sh，如果已安装则使用已经存在的"
    echoColor green "   4.安装完毕或者安装失败会自动恢复备份，请不要手动关闭脚本"
    echoColor green "   5.执行期间请不要重启机器"
    echoColor green "   6.备份文件和证书文件都在/tmp下面，请注意留存"
    echoColor green "   7.如果多次执行则将上次生成备份和生成的证书强制覆盖"
    echoColor green "   8.证书默认ec-256"
    echoColor green "   9.下个版本会加入通配符证书生成[todo]"
    echoColor green "   10.可以生成多个不同域名的证书[包含子域名]，具体速率请查看[https://letsencrypt.org/zh-cn/docs/rate-limits/]"
    echoColor green "   11.兼容Centos、Ubuntu、Debian"
    echoColor green "   12.Github[https://github.com/mack-a]"
    echoColor red "=============================="
    echoColor yellow "请输入[y]执行脚本，[任意]结束:"
    read isExecStatus
    if [[ ${isExecStatus} = "y" ]]
    then
        installTools
        installTLS
    else
        echoColor green "欢迎下次使用"
        exit
    fi
}
checkSystem
init
