#!/usr/bin/env bash
# bash <(curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/init_GCP_ssh.sh)
if [[ -z `find ~/.ssh -name authorized_keys` ]]
then
    echo -e "\033[36m 初始化 authorized_keys \033[0m"
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi

sed -i '1iRSAAuthentication yes' /etc/ssh/sshd_config
if [[ ! -z `cat /etc/ssh/sshd_config|grep -v grep|grep -n "PermitRootLogin no"|awk -F "[:]" '{print $1}'` ]]
then
    deleteLine=`cat /etc/ssh/sshd_config|grep -v grep|grep -n "PermitRootLogin no"|awk -F "[:]" '{print $1}'`
    sed -i "${deleteLine}d" /etc/ssh/sshd_config
fi
service sshd restart
# echo '' >> ~/.ssh/authorized_keys