#!/usr/bin/env bash
domain="test3.am1z.xyz"
eccPath=`find ~/.acme.sh -name "${domain}_ecc"|head -1`
mkdir -p /tmp/tls
touch /tmp/tls/tls.log
touch /tmp/tls/acme.log
if [[ ! -z ${eccPath} ]]
then
    modifyTime=`stat ${eccPath}/${domain}.key|sed -n '6,6p'|awk '{print $2" "$3" "$4" "$5}'`
    modifyTime=`date +%s -d "${modifyTime}"`
    currentTime=`date +%s`
    stampDiff=`expr ${currentTime} - ${modifyTime}`
    minutes=`expr ${stampDiff} / 60`
    status="正常"
    reloadTime="暂无"
    if [[ ! -z ${modifyTime} ]] && [[ ! -z ${currentTime} ]] && [[ ! -z ${stampDiff} ]] && [[ ! -z ${minutes} ]] && [[ ${minutes} -lt '120' ]]
    then
        nginx -s stop
        ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/nginx/v2ray-agent-https/${domain}.crt --keypath /etc/nginx/v2ray-agent-https/${domain}.key --ecc >> /tmp/tls/acme.log
        nginx
        reloadTime=`date -d @${currentTime} +"%F %H:%M:%S"`
    fi
    echo "域名：${domain}，modifyTime:"`date -d @${modifyTime} +"%F %H:%M:%S"`,"检查时间:"`date -d @${currentTime} +"%F %H:%M:%S"`,"上次生成证书的时:"`expr ${minutes} / 1440`"天前","证书状态："${status},"重新生成日期："${reloadTime} >> /tmp/tls/tls.log
else
    echo '无法找到证书路径' >> /tmp/tls/tls.log
fi
