# v2ray-agent
- [Cloudflare 优化方案](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)
- [流量中转](https://github.com/mack-a/v2ray-agent/blob/master/documents/traffic_relay.md)
- [手动自建教程](https://github.com/mack-a/v2ray-agent/blob/master/documents/Cloudflare_install_manual.md)
- [TG群](https://t.me/technologyshare)、[订阅频道-及时获取更新通知](https://t.me/v2rayagentshare)、[博客地址](https://www.v2ray-agent.com/)
- [公益订阅链接【4T】](https://github.com/mack-a/v2ray-agent/blob/master/documents/free_account.md)。

* * *
# 目录
- [1.脚本安装](#1vlesstcptlsvlesswstlsvmesstcptlsvmesswstlstrojan-伪装博客-五合一共存脚本)
  * [组合方式](#组合方式)
  * [组合推荐](#组合推荐)
  * [特性](#特性)
  * [注意事项](#注意事项)
  * [安装脚本](#安装脚本)
* * *
>使用必读此[issue](https://github.com/mack-a/v2ray-agent/issues/32)

# 1.七合一共存脚本+伪装博客
- 如果没有使用过Cloudflare[点击这里](https://github.com/mack-a/v2ray-agent/blob/master/documents/cloudflare_init.md)查看入门教程

## 组合方式
- VLESS+TCP+TLS
- VLESS+TCP+xtls-rprx-origin
- VLESS+TCP+xtls-rprx-direct【推荐】
- VLESS+WS+TLS 
- VMess+TCP+TLS
- VMess+WS+TLS
- Trojan【推荐】
- Trojan-Go+WS

## 线路推荐
- 1.GIA
- 2.上海CN2+HK
- 3.上海联通+台湾TFN
- 4.上海联通+Vultr东京
- 5.广移/珠移+HKIX/CMI
- 6.苏日IPLC+日本/美国
- 7.莞港IPLC+HK

## 组合推荐
- 中专/gia ---> VLESS+TCP+TLS/XTLS、Trojan【推荐使用XTLS的xtls-rprx-direct】
- 移动宽带  ---> VMESS+WS+TLS/Trojan-Go+WS + Cloudflare
- Trojan建议开启Mux【多路复用】，仅需客户端开启，服务端自适应。
- VMess/VLESS也可开启Mux，效果需要自己尝试，XTLS不支持Mux。仅需客户端开启，服务端自适应。

## 特性
- VLESS/VMess/Trojan-Go三种工具合并为一个脚本，可以体验不同的工具之间的不同特性、兼容更多的设备。
- 支持Debian、Ubuntu、Centos
- 支持个性化安装，VLESS+TCP为必选，其余为可选项。
- 脚本自动检查升级
- 自动更新TLS证书
- 支持快捷方式启动，安装完毕后，shell输入[vasma]即可打开脚本，脚本执行路径[/etc/v2ray-agent/install.sh]
- 未来会支持Xray-core
- 未来会支持ipv6【手头暂时没有ipv6的机器，如有闲置的ipv6机器可以赞助给我】

## 注意事项
- 修改Cloudflare->SSL/TLS->Overview->Full
- Cloudflare ---> A记录解析的云朵必须为灰色
- wget: command not found [这里需要自己手动安装下wget]，如未使用过Linux，[点击查看](https://github.com/mack-a/v2ray-agent/tree/master/documents/install_tools.md)安装教程
- 脚本安装路径[/etc/v2ray-agent]
- 不支持非root账户
- 现在脚本进入相对稳定的时期，如果有功能不完善的地方，请提issues。
 
## 关于v2ray-core即将移除XTLS，未来的脚本修改说明 
- 具体请[点击查看](https://github.com/mack-a/v2ray-agent/issues/32)

## 安装脚本
```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
```

- 示例图
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/install.jpg" width=700>

# 许可证
[MIT](https://github.com/mack-a/v2ray-agent/blob/master/LICENSE)

## Stargazers over time

[![Stargazers over time](https://starchart.cc/mack-a/v2ray-agent.svg)](https://starchart.cc/mack-a/v2ray-agent)
