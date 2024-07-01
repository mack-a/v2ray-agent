#!/usr/bin/env bash
# wget -P /tmp -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/shell/ufw_remove.sh" && chmod 700 /tmp/ufw_remove.sh && /tmp/ufw_remove.sh
systemctl stop ufw
systemctl disable ufw
iptables -F
iptables -I INPUT -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -I OUTPUT -o eth0 -d 0.0.0.0/0 -j ACCEPT
