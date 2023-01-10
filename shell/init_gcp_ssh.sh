#!/usr/bin/env bash
# bash <(curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/init_GCP_ssh.sh)
if [[ -z `find ~/.ssh -name authorized_keys` ]]
then
    echo -e "\033[36m 初始化 authorized_keys \033[0m"
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi

sed -i "s/PasswordAuthentication/#PasswordAuthentication/g"  `grep "PasswordAuthentication" -rl /etc/ssh/sshd_config`
sed -i "s/RSAAuthentication/#RSAAuthentication/g"  `grep "RSAAuthentication" -rl /etc/ssh/sshd_config`
sed -i "s/PubkeyAuthentication/#PubkeyAuthentication/g"  `grep "PubkeyAuthentication" -rl /etc/ssh/sshd_config`
sed -i "s/AuthorizedKeysFile/#AuthorizedKeysFile/g"  `grep "AuthorizedKeysFile" -rl /etc/ssh/sshd_config`
sed -i "s/PermitRootLogin/#PermitRootLogin/g"  `grep "PermitRootLogin" -rl /etc/ssh/sshd_config`

sed -i '1iAuthorizedKeysFile .ssh/authorized_keys ' /etc/ssh/sshd_config
sed -i '1iPubkeyAuthentication yes' /etc/ssh/sshd_config
sed -i '1iRSAAuthentication yes' /etc/ssh/sshd_config
sed -i '1iPasswordAuthentication no' /etc/ssh/sshd_config
service sshd restart

#if [[ ! -z `cat /etc/ssh/sshd_config|grep -v grep|grep -n "PermitRootLogin no"|awk -F "[:]" '{print $1}'` ]]
#then
#    deleteLine=`cat /etc/ssh/sshd_config|grep -v grep|grep -n "PermitRootLogin no"|awk -F "[:]" '{print $1}'`
#    sed -i "${deleteLine}d" /etc/ssh/sshd_config
#fi

# echo '' >> ~/.ssh/authorized_keys
