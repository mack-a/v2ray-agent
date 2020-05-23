#!/usr/bin/env bash
export PATH="/usr/bin/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.nvm/versions/node/v10.17.0/bin:$PATH"
purple="\033[35m"
skyBlue="\033[36m"
red="\033[31m"
green="\033[32m"
yellow="\e[93m"
magenta="\e[95m"
cyan="\e[96m"
none="\e[0m"
installType='yum'
removeType='yum -y remove'
echoType='echo'

#检查Linux版本
check_version(){
	if [[ -s /etc/redhat-release ]]; then
		version=`grep -oE  "[0-9.]+" /etc/redhat-release | cut -d . -f 1`
	else
		version=`grep -oE  "[0-9.]+" /etc/issue | cut -d . -f 1`
	fi
	bit=`uname -m`
	if [[ ${bit} = "x86_64" ]]; then
		bit="x64"
	else
		bit="x32"
	fi
}

installNginx(){
    ## todo 兼容debian
    ${echoType} "${skyBlue}检查Nginx中...${none} "
    existProcessNginx=`ps -ef|grep nginx|grep -v grep`
    existNginx=`command -v nginx`
    if [ -z "$existProcessNginx" ] && [ -z "$existNginx" ]
    then
        ${echoType} "${skyBlue}安装Nginx中，如遇到是否安装输入y${none}"
        ${installType} -y install nginx
        rm -rf /etc/nginx/nginx.conf
        wget -P /etc/nginx/  https://raw.githubusercontent.com/mack-a/v2ray-agent/master/config/nginx.conf
        ${echoType} "${green}步骤二：Nginx安装成功，执行下一步 ${none}"
    else
        ${echoType} "${purple}===============================${none}"
        ${echoType} "${purple}检测到已安装Nginx，是否卸载${none}"
        ${echoType} "${red}    1.卸载并重新安装【会把默认的安装目录的内容删除】${none}"
        ${echoType} "${red}    2.跳过并使用已经安装的Nginx以及配置文件【请确认是否是此脚本的配置文件】${none}"
        ${echoType} "${purple}===============================${none}"
        ${echoType} "${skyBlue}请选择【数字编号】:${none}"
        read nginxStatus
        if [ "${nginxStatus}" = 1 ]
        then
            if [ -n "$existProcessNginx" ]
            then
                ${echoType} "${purple}Nginx已启动，关闭中...${none}"
                nginx -s stop
            fi
            ${echoType} "${skyBlue}卸载Nginx中... ${none}"
            ${removeType} nginx
            ${echoType} "${skyBlue}卸载Nginx完毕，重装中... ${none}"
            installNginx;
        else
            echo "不卸载，返回主目录"
            echo
            manageFun
        fi
    fi
}
installHttps(){
    ${echoType} "${skyBlue}安装https中,请输入你要生成tls证书的域名${none}"
    read domain
    # grep "domain" * -R|awk -F: "{print $1}"|sort|uniq|xargs sed -i "s/domain/$domain/g"
    # cat /etc/nginx/nginx.conf |grep "domain" * -R|awk -F: "{print $1}"|sort|uniq|xargs sed -i "s/domain/$domain/g"
    existProcessNginx=`ps -ef|grep nginx|grep -v grep`
    if [ ! -z "${existProcessNginx}" ]
    then
        echo '检测到Nginx正在运行，关闭中...'
        nginx -s stop
    fi

    if [ -f "/etc/nginx/nginx.conf" ]
    then
        noExistNginxConfigDomain=`cat /etc/nginx/nginx.conf|grep $domain|grep -v grep`
        if [ ! -z "${noExistNginxConfigDomain}" ]
        then
            sed -i "s/$domain/domain/g" `grep $domain -rl /etc/nginx/nginx.conf`
        fi
        sed -i "s/domain/$domain/g" `grep domain -rl /etc/nginx/nginx.conf`
    fi

    uninstallAcmeStatus="false"
    if [ ! -d "/root/.acme.sh" ]
    then
        ${echoType} "${skyBlue}安装acme.sh中...${none}"
        curl https://get.acme.sh | sh
        sudo ~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
    else
        ${echoType} "${purple}===============================${none}"
        ${echoType} "${purple}检测到已安装acme.sh，是否卸载${none}"
        ${echoType} "${red}    1.卸载并重新安装【以前生成的TLS证书会被删除，需要重新输入域名】${none}"
        ${echoType} "${red}    2.跳过并使用已经安装的acme.sh${none}"
        ${echoType} "${purple}===============================${none}"
        ${echoType} "${skyBlue}请选择【数字编号】:${none}"
        read acmeStatus
        if [ "${acmeStatus}" = 1 ]
        then
            rm -rf ~/.acme.sh
            uninstallAcmeStatus="true"
        else
            ${echoType} "${skyBlue}生成证书中...${none}"
        fi
    fi

    if [ "${uninstallAcmeStatus}" = "true" ]
    then
        installHttps
    else
        ~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/nginx/$domain.crt --keypath /etc/nginx/$domain.key --ecc
        sed -i "s/# ssl_certificate/ssl_certificate/g" `grep "# ssl_certificate" -rl /etc/nginx/nginx.conf`
        sed -i "s/listen 443/listen 443 ssl/g" `grep "listen 443" -rl /etc/nginx/nginx.conf`
        ${echoType} "${green}步骤三：HTTPS执行完毕，请手动确认上方是否有错误，执行下一步${none}"
    fi
}
installV2Ray(){
    ${echoType} "${skyBlue}检查V2Ray中...${none} "
    existProcessV2Ray=`ps -ef|grep v2ray|grep -v grep`
    existV2Ray=`command -v v2ray`
    if [ -z "$existProcessV2Ray" ] && [ -z "$existV2Ray" ] && [ ! -x "/usr/bin/v2ray" ]
    then
        ${echoType} "${skyBlue}安装V2Ray中... ${none}"
        wget -P /tmp/V2Ray https://github.com/V2Ray/V2Ray-core/releases/download/v4.21.3/V2Ray-linux-64.zip
        cd /tmp/V2Ray
        unzip /tmp/V2Ray/V2Ray-linux-64.zip
        mv /tmp/V2Ray/v2ray /usr/bin/
        mv /tmp/V2Ray/v2ctl /usr/bin/
        mkdir /usr/bin/V2RayConfig
        wget -P /usr/bin/V2RayConfig https://raw.githubusercontent.com/mack-a/V2Ray-agent/master/config/config_ws_tls.json
        touch /usr/bin/V2RayConfig/V2Ray_access.log
        touch /usr/bin/V2RayConfig/V2Ray_error.log
        ${echoType} "${green} 步骤三：V2Ray安装成功，执行下一步"
    else
        ${echoType} "${purple}===============================${none}"
        ${echoType} "${purple}检测到已安装V2Ray，是否卸载${none}"
        ${echoType} "${red}    1.卸载并重新安装【配置文件会重新生成】${none}"
        ${echoType} "${red}    2.跳过并使用已经安装的V2Ray【请确认Nginx的配置与V2Ray配置相同【端口号、Path】】${none}"
        ${echoType} "${purple}===============================${none}"
        ${echoType} "${skyBlue}请选择【数字编号】:${none}"
        read acmeStatus
        if [ "${acmeStatus}" -eq 1 ]
        then
            rm -rf /tmp/V2Ray
            rm -rf /usr/bin/v2ray
            rm -rf /usr/bin/v2ctl
            rm -rf /usr/bin/V2RayConfig
            if [ -z `ps -ef|grep v2ray|grep -v grep|awk '{print $2}'` ]
            then
                ps -ef|grep v2ray|grep -v grep|awk '{print $2}'|xargs kill -9
            fi
            installV2Ray
        else
            ${echoType} "${green} 忽略V2Ray并继续执行"
        fi
    fi
}
checkOS(){
    systemVersion=`cat /etc/redhat-release|grep CentOS|awk '{print $1}'`
    if [ -n "$systemVersion" ] && [ "$systemVersion" -eq "CentOS" ]
    then
        ${echoType} "${green}步骤一：系统为CentOS脚本可执行  ${none} "
    else
        ${echoType} "${red}目前仅支持Centos${none}"
        ${echoType} "${red}退出脚本${none}"
        exit
    fi
}
# 生成vmess链接
generatorVmess(){
    ${echoType} "${purple}===============================${none}"
    ${echoType} "${purple}选择要生成vmess的V2Ray配置文件${none}"
    ${echoType} "${green}  1.默认【/usr/bin/V2RayConfig/config_ws_tls.json】${none}"
    ${echoType} "${green}  2.官方默认【/etc/v2ray/config.json】${none}"
    ${echoType} "${green}  3.手动输入${none}"
    ${echoType} "${purple}===============================${none}"
    ${echoType} "${skyBlue}请选择【数字编号】:${none}"
    read V2RayPathSelect
    V2RayPath="";

    if [ "$V2RayPathSelect" -eq "3" ]
    then
        ${echoType} "${skyBlue}请输入配置文件路径：${none}"
        read V2RayPath
    fi
    case $V2RayPathSelect in
        1)
            V2RayPath="/usr/bin/V2RayConfig/config_ws_tls.json"
        ;;
        2)
            V2RayPath="/etc/v2ray/config.json"
        ;;
    esac

    if [ -z "${V2RayPath}" ]
    then
        ${echoType} ${red}"V2Ray配置文件读取失败，请检查路径"${none}
        init
    else
        # 读取nginx配置文件
        ${echoType} "${purple}===============================${none}"
        ${echoType} "${purple}选择要生成vmess的Nginx配置文件路径${none}"
        ${echoType} "${green}  1.CDN【默认读取/etc/nginx/nginx.conf】${none}"
        ${echoType} "${green}  2.手动输入Nginx配置文件路径${none}"
        ${echoType} "${green}  3.非CDN${none}"
        ${echoType} "${purple}===============================${none}"
        ${echoType} "${skyBlue}请选择【数字编号】:${none}"
        read NginxPathSelect

        if [ "$NginxPathSelect" -eq "2" ]
        then
            ${echoType} "${skyBlue}请输入Nginx配置文件路径：${none}"
            read NginxPath
        fi

        case $NginxPathSelect in
            1)
                NginxPath="/etc/nginx/nginx.conf"
            ;;
        esac
        if [ -z "${NginxPath}" ]
        then
            ${echoType} ${red}"Nginx配置文件读取失败，请检查路径"${none}
            init
        fi
        # 执行node生成vmess链接
        nodePath='/root/.nvm/versions/node/v10.17.0/bin/node'
        if [ ! -x "/root/.nvm/versions/node/v10.17.0/bin/node" ]
        then
            ${echoType} ${red}"安装工具包中..."${none}
            installTools
        fi
        echo
        ${echoType} "${purple}===============================${none}"
        ${echoType} "${purple}V2Ray配置文件路径:${none}"
        ${echoType} "${green}    ${V2RayPath}${none}"
        ${echoType} "${purple}Nginx配置文件路径:${none}"
        ${echoType} "${green}    ${NginxPath}${none}"
        ${echoType} "${purple}===============================${none}"
        echo
        vmessResult=`curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/generator_client_links.js | ${nodePath} - "${V2RayPath}" "${NginxPath}"`

        ${echoType} "${green}===============================${none}"
        echo
        eval $(echo "$vmessResult" |awk '{split($0,vmess," ");for(i in vmess) print "lenArr["i"]="vmess[i]}')
        for value in ${lenArr[*]}
        do
            ${echoType} "${purple}客户端链接:${none}"
            ${echoType} "${skyBlue}  $value${none}"
            echo
            ${echoType} "${purple}二维码:${none}"
            echo $value | qrencode -s 10 -m 1 -t UTF8
            echo
        done
        ${echoType} "${green}===============================${none}"
        echo
        # curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/generator_client_links.js | /root/.nvm/versions/node/v10.17.0/bin/node - "/usr/bin/V2RayConfig/config_ws_tls.json" "/etc/nginx/nginx.conf"
    fi
}
startServer(){
    ${echoType} "${green}启动服务${none}"
    nginx
    /usr/bin/v2ray -config /usr/bin/V2RayConfig/config_ws_tls.json &
    echo "启动完毕"
}
installTools(){
    existProcessWget=`ps -ef|grep wget|grep -v grep`
    existWget=`command -v wget`
    ${installType} -y update
    if [ -z "$existProcessWget" ] && [ -z "$existWget" ]
    then
        ${echoType} "${skyBlue}安装wget中...${none}"
        ${installType} -y install wget
    else
        echo
    fi
    existUnzip=`command -v unzip`
    if [ -z "$existUnzip" ]
    then
        ${echoType} "${skyBlue}安装zip中...${none}"
        ${installType} -y install unzip
    fi
    existSocat=`command -v socat`
    if [ -z "$existSocat" ]
    then
        ${echoType} "${skyBlue}安装socat中...${none}"
        ${installType} -y install socat
    fi
    existJq=`command -v jq`
    if [ -z "$existJq" ]
    then
        ${echoType} ${skyBlue}安装jq中...${none}
        ${installType} -y install jq
    fi
#    existNode=`/root/.nvm/versions/node/v10.17.0/bin`
    if [ ! -x "/root/.nvm/versions/node/v10.17.0/bin/node" ]
    then
        ${echoType} ${skyBlue}安装nvm中...${none}
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.1/install.sh | bash
        ${echoType} ${skyBlue}安装Node.js中...${none}
        . /root/.nvm/nvm.sh
        nvm install v10.17.0
    fi
    existQrencode=`command -v qrencode`
    if [ -z "$existQrencode" ]
    then
        ${echoType} ${skyBlue}安装qrencode中...${none}
        ${installType} -y install qrencode
    fi
}
unInstall(){
    nginx -s stop
    rm -rf ~/.acme.sh
    ${removeType} nginx
    rm -rf /tmp/V2Ray
    rm -rf /usr/bin/v2ray
    rm -rf /usr/bin/v2ctl
    rm -rf /usr/bin/V2RayConfig
    rm -rf /etc/nginx
    rm -rf /root/.nvm
    ps -ef|grep v2ray|grep -v grep|awk '{print $2}'|xargs kill -9
    if [[ "${release}" -eq "ubuntu" ||  "${release}" -eq "debian" ]]
    then
        sed -i 's/. "\/root\/.acme.sh\/acme.sh.env"//g' `grep '. "/root/.acme.sh/acme.sh.env"' -rl /root/.bashrc`
    fi
    . /root/.bashrc
}
configPath(){
    ${echoType} "${purple}===============================${none}"
    ${echoType} "${red}路径如下${none}"
    ${echoType} "${green} 1.v2ray${none}"
    ${echoType} "${skyBlue}   1./usr/bin/v2ray 【V2Ray 程序】${none}"
    ${echoType} "${skyBlue}   2./usr/bin/v2ctl 【V2Ray 工具】${none}"
    ${echoType} "${skyBlue}   3./usr/bin/V2RayConfig 【V2Ray配置文件，配置文件、log文件】${none}"
    ${echoType} "${green} 2.Nginx${none}"
    ${echoType} "${skyBlue}   1./usr/sbin/nginx 【Nginx 程序】${none}"
    ${echoType} "${skyBlue}   2./etc/nginx/nginx.conf 【Nginx 配置文件】${none}"
    ${echoType} "${purple}===============================${none}"
    echo
}
manageFun(){
    ${echoType} "${purple}===============================${none}"
    ${echoType} "${purple}手动模式功能点目录:${none}"
    ${echoType} "${skyBlue}  1.检查系统版本是否为CentOS${none}"
    ${echoType} "${skyBlue}  2.安装工具包${none}"
    ${echoType} "${skyBlue}  3.检测nginx是否安装并配置${none}"
    ${echoType} "${skyBlue}  4.检测https是否安装并配置${none}"
    ${echoType} "${skyBlue}  5.检测V2Ray是否安装并配置${none}"
    ${echoType} "${skyBlue}  6.启动服务并退出脚本${none}"
    ${echoType} "${skyBlue}  7.卸载安装的所有内容${none}"
    ${echoType} "${skyBlue}  8.查看配置文件路径${none}"
    ${echoType} "${skyBlue}  9.生成Vmess、二维码链接${none}"
    ${echoType} "${skyBlue}  10.返回主目录${none}"
    ${echoType} "${red}  11.退出脚本${none}"
    ${echoType} "${purple}===============================${none}"
    ${echoType} "${skyBlue}请输入要执行的功能【数字编号】:${none}"
    read funType
    echo
    case $funType in
        1)
#            checkOS
        ;;
        2)
            installTools
        ;;
        3)
            installNginx
        ;;
        4)
            ${echoType} "${red}此步骤依赖【3.检测nginx是否安装并配置】${none}"
            installHttps
        ;;
        5)
            installV2Ray
        ;;
        6)
            startServer
        ;;
        7)
            unInstall
        ;;
        8)
           configPath
        ;;
        9)
           generatorVmess
        ;;
        10)
           init
        ;;
        11)
           exit
        ;;
    esac
    manageFun
}
automationFun(){
    case $1 in
        1)
#            checkOS
            installTools
            automationFun 2
        ;;
        2)
            installNginx
            automationFun 3
        ;;
        3)
           installHttps
           automationFun 4
        ;;
        4)
            installV2Ray
            automationFun 5
        ;;
        5)
            generatorVmess
            automationFun 6
        ;;
        6)
            startServer
            exit
        ;;
    esac
}

init(){
    ${echoType} "${purple}目前此脚本支持Ubuntu、Centos、Debian${none}"
    ${echoType} "${purple}===============================${none}"
    ${echoType} "${purple}支持两种模式：${none}"
    ${echoType} "${red}    1.自动模式${none}"
    ${echoType} "${red}    2.手动模式${none}"
    ${echoType} "${purple}===============================${none}"
    ${echoType} "${skyBlue}请选择【数字编号】:${none}"
    read automatic
    if [ "${automatic}" = 1 ]
    then
        ${echoType} "${purple}===============================${none}"
        ${echoType} "${purple}自动模式会执行以下内容:${none}"
        ${echoType} "${skyBlue}  1.检查系统版本是否为Ubuntu、Centos、Debian${none}"
        ${echoType} "${skyBlue}  2.安装工具包${none}"
        ${echoType} "${skyBlue}  3.检测nginx是否安装并配置${none}"
        ${echoType} "${skyBlue}  4.检测https是否安装并配置${none}"
        ${echoType} "${skyBlue}  5.检测V2Ray是否安装并配置${none}"
        ${echoType} "${skyBlue}  6.生成vmess、二维码链接${none}"
        ${echoType} "${skyBlue}  7.启动服务并退出脚本${none}"
        ${echoType} "${purple}===============================${none}"
        automationFun 1
    elif [ "${automatic}" = 2 ]
    then
        manageFun
    fi
}
# 检查系统

checkSystem(){
	if [ -f /etc/redhat-release ]; then
		release="centos"
		installType='yum'
		echoType='echo -e'
		removeType='yum -y remove'
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
		installType='apt'
		echoType='echo -e'
		removeType='apt -y autoremove'
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
		installType='apt'
		echoType='echo -e'
		removeType='apt -y autoremove'
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
		installType='yum'
		echoType='echo -e'
		removeType='yum -y remove'
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
		installType='apt'
		removeType='apt -y autoremove'
		echoType='echo -e'
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
		installType='apt'
		removeType='apt -y autoremove'
		echoType='echo -e'
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
		installType='yum'
		removeType='yum -y remove'
		echoType='echo -e'
    fi
}
checkSystem
[ ${release} != "debian" ] && [ ${release} != "ubuntu" ] && [ ${release} != "centos" ] && ${echoType} "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
init
