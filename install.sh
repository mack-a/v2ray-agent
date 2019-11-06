#!/usr/bin/env bash
export PATH="/usr/bin/:#$PATH"
nginxStatus=false
v2rayStatus=false
httpsStatus=false
# todo 先完善正常步骤
initNginx(){
    echo -e '\033[36m   检查Nginx中... \033[0m'
    existProcessNginx=`ps -ef|grep nginx|grep -v grep`
    existNginx=`command -v nginx`
    if [ -z "$existProcessNginx" ] && [ -z "$existNginx" ]
    then
        echo '安装Nginx中，如遇到是否安装输入y'
        yum update
        yum install nginx
        echo '步骤二：Nginx安装成功，执行下一步'
        installV2Ray
    else
        # todo
        echo '检查到Nginx存在，是否停止并卸载，输入y/Y确认：'
        read -e unstallStatus
        if [[ $unstallStatus -eq "y" ||  $unstallStatus -eq "Y" ]]
        then
            echo '卸载'
        else
            echo '不卸载，停止脚本'
        fi
    fi
}
installHttps(){
    echo 'https'
}
installV2Ray(){
    echo -e '\033[36m   检查V2Ray中... \033[0m'

}
checkOS(){
    systemVersion=`cat /etc/redhat-release|grep CentOS|awk '{print $1}'`
    if [ -n "$systemVersion" ] && [ "$systemVersion" == "CentOS" ]
    then
        echo ''
        echo -e '\033[35m步骤一：系统为CentOS，执行下一步 \033[0m'
        return 1
    else
        echo '目前仅支持Centos'
    fi
}
init(){
    echo -e "\033[35m此脚本会执行以下内容: \033[0m"
    echo -e "\033[36m  1.检查系统版本是否为CentOS \033[0m"
    echo -e "\033[36m  2.检测nginx是否安装并配置 \033[0m"
    echo -e "\033[36m  3.检测https是否安装并配置 \033[0m"
    echo -e "\033[36m  4.检测V2Ray是否安装并配置 \033[0m"
    echo -e "\033[35m是否进入手动模式y，键入回车进入自动模式: \033[0m"
    read -e automatic
    if [ "$automatic" = "y" ]
    then
        echo '手动模式'
    else
        checkOS
        echo "$?"
    fi
}
init
