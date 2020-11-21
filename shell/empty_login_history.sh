#!/usr/bin/env bash
# 清空访问日志
echo > /var/log/wtmp
echo > /var/log/btmp
echo > ~/.bash_history
history -c