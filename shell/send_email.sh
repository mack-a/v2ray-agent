#!/usr/bin/env bash
touch /var/local/mail.log

currentIP=$(curl -s -4 whatismyip.akamai.com)
historyIP=$(cat /var/local/mail.log)
if [[ ${currentIP} = ${historyIP} ]];then
	echo '不发送邮件'
	echo '不发送邮件' >> /tmp/mail.log
	exit
fi
echo ${currentIP}|mail -s ${currentIP} xxx@163.com
echo ${currentIP} > /var/local/mail.log
