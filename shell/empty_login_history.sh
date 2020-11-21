#!/usr/bin/env bash
# 清空访问日志
# wget -P /tmp -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/shell/empty_login_history.sh" && chmod 700 /tmp/empty_login_history.sh && /tmp/empty_login_history.sh
echo "清空中"
echo > /var/log/wtmp
echo > /var/log/btmp
echo > /var/log/lastlog
echo > ~/.bash_history
echo "清空完毕"
echo "删除脚本"
rm -rf /tmp/empty_login_history.sh
history -c
echo "done"
