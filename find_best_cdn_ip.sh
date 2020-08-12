#!/usr/bin/env bash
num=5
ip=()
timeout=1000
echoType='echo -e'
trap 'onCtrlC' INT
function onCtrlC () {
    statisticalContent
    exit;
}
# 计算
statisticalContent(){
    if [[ ! -z `ls /tmp|grep -v grep|grep ping.log` ]]
    then
        echoContent red "============================================="
        echoContent yellow '计算中--->'
        # 排序计算
        echoContent red "排序规则：丢包率>波动>平均延迟，只展示最优的三十条"
        echoContent red "依次展示为:[ ip 丢包率 最小延迟 平均延迟 最大延迟 波动 ]"
        cat /tmp/ping.log|sort -t ' ' -k 2n -k 6n -k 4n|head -30
        echoContent red "============================================="
    fi

}
# echo工具类
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
# 测试
pingTool(){
    echo ''>/tmp/ping.log
    echoContent red "============================================="
    echoContent green "默认测试为五次，超时为1000ms"
    echoContent red "============================================="
    read -p "请输入单个ip测试次数【默认为5次】：" testNum
    if [[ "$testNum" =~ ^[0-9]+$ ]]
    then
        num=${testNum}
    else
        echoContent red '使用默认'
    fi
    echoContent yellow "一共${#ip[*]}个IP，每个ip测试${num}次,大约耗时`expr ${#ip[*]} \* ${num} / 60`分钟"
    echoContent yellow "可以中途Ctrl+c，这样只会计算、统计已经记录下来的"
    for ((i=0;i<${#ip[*]};i++))
    do
        if [[ -z ${ip[$i]} ]]
        then
            continue;
        fi
        pingResult=`ping -c ${num} -W ${timeout} ${ip[$i]}`
        packetLoss=`echo ${pingResult}|awk -F "[%]" '{print $1}'|awk -F "[p][a][c][k][e][t][s][ ][r][e][c][e][i][v][e][d][,][ ]" '{print $2}'`
        roundTrip=`echo ${pingResult}|awk -F "[r][o][u][n][d][-][t][r][i][p]" '{print $2}'|awk '{print $3}'|awk -F "[/]" '{print $1"."$2"."$3"."$4}'|awk -F "[/]" '{print $1$2$3$4}'|awk -F "[.]" '{print $1" "$3" "$5" "$7}'`
        if [[ "${release}" = "ubuntu" ]] || [[ "${release}" = "debian" ]] || [[ "${release}" = "centos" ]]
        then
            packetLoss=`echo ${pingResult}|awk -F "[%]" '{print $1}'|awk -F "[r][e][c][e][i][v][e][d][,][ ]" '{print $2}'`
            roundTrip=`echo ${pingResult}|awk -F "[r][t][t]" '{print $2}'|awk '{print $3}'|awk -F "[/]" '{print $1"."$2"."$3"."$4}'|awk -F "[/]" '{print $1$2$3$4}'|awk -F "[.]" '{print $1" "$3" "$5" "$7}'`
        fi

        ## |awk -F "[/]" '{print $1$2$3}'|awk -F "[.]" '{print $1" "$3" "$5" "$7}'
        if [[ -z ${roundTrip} ]]
        then
            roundTrip="无"
        fi
        echo "ip:${ip[$i]},丢包率:${packetLoss}%,最小/平均/最大/波动:${roundTrip}"
        echo "${ip[$i]} ${packetLoss} ${roundTrip}" >> /tmp/ping.log
    done
    statisticalContent
}
# 查找国家和地区
findCountry(){
    if [[ -z  `ls /tmp|grep -v grep|grep ips` ]]
    then
        echoContent red "缺少ip库，请联系作者。"
        exit 0;
    fi
    echoContent red "============================================="
    cat /tmp/ips|awk -F "[|]" '{print $1}'|awk  -F "[-]" '{print $3}'|uniq|awk '{print NR":"$0}'
    echoContent red "============================================="
    read -p "输入上述数字：" selectType
    if [[ -z `cat /tmp/ips|awk -F "[|]" '{print $1}'|awk  -F "[-]" '{print $3}'|uniq|awk '{print NR":"$0}'|grep -v grep|grep ${selectType}` ]]
    then
        echoContent red '输入有误，请重新输入'
        findCountry
    fi
    findIPList ${selectType}
}
# 查找ip
findIPList(){
    country=`cat /tmp/ips|awk -F "[|]" '{print $1}'|awk  -F "[-]" '{print $3}'|uniq|awk '{print NR":"$0}'|grep -v grep|grep ${selectType}|sort -t ':' -k 1n|head -1|awk -F "[:]" '{print $2}'`
    # cat /tmp/ips|awk -F "[|]" '{print $1}'|awk  -F "[-]" '{print $3}'|uniq|awk '{print NR":"$0}'|grep -v grep|grep 1|sort -t ':' -k 1n|head -1|awk -F "[:]" '{print $2}'
    echoContent red "============================================="
    cat /tmp/ips|grep -v grep|grep ${country}|awk -F "[|]" '{print $1}'|awk -F "[-]" '{print $1"-"$2}'|awk '{print "["NR"]"":"$0}'
    read -p "请输入上述数字进行测试相应的ip段:" selectType
    if [[ -z ${selectType} ]]
    then
        echoContent red '输入有误请重新输入！'
        findIPList $1
    fi
    echo ${country}
    # cat /tmp/ips|grep -v grep|grep 中国移动|awk -F "[|]" '{print NR"-"$2}'|grep 174-|head -1 |awk -F "[|]" '{print $2}'
    eval $(cat /tmp/ips|grep -v grep|grep ${country}|awk -F "[|]" '{print NR"-"$2}'|grep ${selectType}-|head -1|awk -F "[-]" '{print $2}'|awk '{split($0,serverNameList," ");for(i in serverNameList) print "ip["i"]="serverNameList[i]}')
    pingTool
}
# 检查系统
checkSystem(){
    if [[ "`uname`" = "Darwin" ]]
	then
	    release="Darwin"
	elif [[ ! -z `find /etc -name "redhat-release"` ]] || [[ ! -z `cat /proc/version | grep -i "centos" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "red hat" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "redhat" | grep -v grep ` ]]
    then
        release="centos"
	elif [[ ! -z `cat /etc/issue | grep -i "ubuntu" | grep -v grep` ]] || [[ ! -z `cat /proc/version | grep -i "ubuntu" | grep -v grep` ]]
	then
		release="ubuntu"
    elif [[ ! -z `cat /etc/issue | grep -i "debian" | grep -v grep` ]] || [[ ! -z `cat /proc/version | grep -i "debian" | grep -v grep` ]]
	then
		release="debian"
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
# 下载ip库
downloadIPs(){
    if [[ -z `ls /tmp|grep -v grep|grep ips` ]]
    then
        echoContent yellow '开始下载ip库'
        wget -q -P /tmp/ https://raw.githubusercontent.com/mack-a/v2ray-agent/dev/fodder/ips/ips
        echoContent yellow '下载结束'
    fi
}
downloadIPs
checkSystem
findCountry

