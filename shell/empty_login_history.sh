#!/usr/bin/env bash
# 清空访问日志
# wget -P /tmp https://raw.githubusercontent.com/mack-a/v2ray-agent/master/shell/empty_login_history.sh && chmod 700 /tmp/empty_login_history.sh && bash /tmp/empty_login_history.sh
echo > /var/log/wtmp
echo > /var/log/btmp
echo > ~/.bash_history
rm -rf /tmp/empty_login_history.sh
history -c
