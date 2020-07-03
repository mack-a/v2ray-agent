#!/usr/bin/env bash
touch /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
echo '' > /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
echo '#!/usr/bin/env bash' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
echo 'domain=$1' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
echo 'if [[ ! -z `find ~/.acme.sh/ -name ${domain}.key` ]]' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
echo 'then' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  key=`find ~/.acme.sh/ -name ${domain}.key|head -1`' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  echo ${key}' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  modifyTime=`stat ${key}|sed -n '\'6,6p\''|awk '{print \$2\" \"\$3\" \"\$4\" \"\$5}'`' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  modifyTime=`date +%s -d "${modifyTime}"`' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  currentTime=`date +%s`' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  stampDiff=`expr ${currentTime} - ${modifyTime}`' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  minutes=`expr ${stampDiff} / 60`' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  echo ${minutes}' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  if [[ ! -z ${modifyTime} ]] && [[ ! -z ${currentTime} ]] && [[ ! -z ${stampDiff} ]] && [[ ! -z ${minutes} ]] && [[ ${minutes} -lt '\'200000\'' ]]' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  then' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
        echo '      echo "符合条件"' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
        #echo '      nginx -s stop' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
        #echo '      ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/nginx/v2ray-agent-https/${domain}.crt --keypath /etc/nginx/v2ray-agent-https/${domain}.key --ecc' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
    echo '  fi' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
echo 'fi' >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
echo "exit 0" >> /etc/nginx/v2ray-agent-https/reloadInstallTLS.sh
