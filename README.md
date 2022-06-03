# v2ray-agent

> [感谢 JetBrains 提供的非商业开源软件开发授权](https://www.jetbrains.com/?from=v2ray-agent)

> [Thanks for non-commercial open source development authorization by JetBrains](https://www.jetbrains.com/?from=v2ray-agent)

> [English Version](https://github.com/mack-a/v2ray-agent/blob/master/documents/en/README_EN.md)

- [Cloudflare 优化方案](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)
- [流量中转](https://github.com/mack-a/v2ray-agent/blob/master/documents/traffic_relay.md)
- [手动自建教程](https://github.com/mack-a/v2ray-agent/blob/master/documents/Cloudflare_install_manual.md)
- [ssh入门教程](https://www.v2ray-agent.com/2020-12-16-ssh%E5%85%A5%E9%97%A8%E6%95%99%E7%A8%8B)

- [TG群](https://t.me/technologyshare)、[TG频道-更新通知](https://t.me/v2rayAgentChannel)、[博客地址](https://www.v2ray-agent.com/)
- **请给个⭐支持一下**

* * *

# 目录

- [1.脚本安装](#1vlesstcptlsvlesswstlsvmesstcptlsvmesswstlstrojan-伪装站点-五合一共存脚本)
    - [组合方式](#组合方式)
    - [组合推荐](#组合推荐)
    - [特性](#特性)
    - [注意事项](#注意事项)
    - [安装脚本](#安装脚本)

* * *

# 1.八合一共存脚本+伪装站点

- [Cloudflare入门教程](https://github.com/mack-a/v2ray-agent/blob/master/documents/cloudflare_init.md)

## 特性
- 支持[Xray-core[XTLS]](https://github.com/XTLS/Xray-core)、[v2ray-core](https://github.com/v2fly/v2ray-core)
- 支持VLESS/Trojan前置[VLESS XTLS -> Trojan XTLS]、[Trojan XTLS -> VLESS XTLS]
- 支持不同核心之间的配置文件互相读取
- 支持 VLESS/VMess/trojan 协议
- 支持Debian、Ubuntu、Centos系统，支持主流的cpu架构。
- 支持任意组合安装、支持多用户管理、支持DNS流媒体解锁、支持添加多端口、[支持任意门解锁Netflix](https://github.com/mack-a/v2ray-agent/blob/master/documents/netflix/dokodemo-unblock_netflix.md)
- 支持卸载后保留tls证书
- 支持IPv6，[IPv6注意事项](https://github.com/mack-a/v2ray-agent/blob/master/documents/ipv6_help.md)
- 支持WARP分流、IPv6分流
- 支持BT下载管理、日志管理、域名黑名单管理、核心管理、伪装站点管理
- [支持自定义证书安装](https://github.com/mack-a/v2ray-agent/blob/master/documents/install_tls.md)

## 支持的安装类型

- VLESS+TCP+TLS
- VLESS+TCP+xtls-rprx-direct【**推荐**】
- VLESS+gRPC+TLS【支持CDN、IPv6、延迟低】
- VLESS+WS+TLS【支持CDN、IPv6】
- Trojan+TCP+TLS【**推荐**】
- Trojan+TCP+xtls-rprx-direct【**推荐**】
- Trojan+gRPC+TLS【支持CDN、IPv6、延迟低】
- VMess+WS+TLS【支持CDN、IPv6】

## 线路推荐

- [CN2 GIA](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#1cn2-gia)
- 上海CN2+HK
- [AS9929](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#2%E8%81%94%E9%80%9A-as9929a%E7%BD%91)
- [AS4837](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#3%E8%81%94%E9%80%9A-as4837%E6%99%AE%E9%80%9A%E6%B0%91%E7%94%A8%E7%BD%91)
- [联通日本软银](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#4%E8%81%94%E9%80%9A-%E6%97%A5%E6%9C%AC%E8%BD%AF%E9%93%B6)
- 联通+台湾TFN
- 联通+NTT
- 广移/珠移+HKIX/CMI/NTT
- 广移/CN2+Cloudflare+全球
- 广移/CN2/南联+香港AZ+全球
- 中转+cloudflare+落地机【可拉全球】

## 组合推荐

- 中转/gia/AS4837/AS9929 ---> VLESS+TCP+TLS/XTLS、Trojan
- 移动宽带 ---> VMESS+WS+TLS/VLESS+WS+TLS/VLESS+gRPC+TLS/Trojan+gRPC+TLS + Cloudflare
- cloudflare-> VLESS+gRPC+TLS/Trojan+gRPC+TLS[多路复用、延迟低]

## 注意事项

- **修改Cloudflare->SSL/TLS->Overview->Full**
- **Cloudflare ---> A记录解析的云朵必须为灰色【如非灰色，会影响到定时任务自动续签证书】**
- **如用CDN又同时使用直连，关闭云朵+自选IP，自选IP参考上方的[Cloudflare 优化方案](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)**
- **使用纯净系统安装，如使用其他脚本安装过并且自己无法修改错误，请重新安装系统后再次尝试安装**
- wget: command not found [**这里需要自己手动安装下wget**]
  ，如未使用过Linux，[点击查看](https://github.com/mack-a/v2ray-agent/tree/master/documents/install_tools.md)安装教程
- 不支持非root账户
- **如发现Nginx相关问题，请卸载掉自编译的nginx或者重新安装系统**
- **为了节约时间，反馈请带上详细截图或者按照模版规范，无截图或者不按照规范的issue会被直接关闭**
- **不推荐GCP用户使用**
- **不推荐使用Centos以及低版本的系统，如果Centos安装失败，请切换至Debian10重新尝试，脚本不再支持Centos6、Ubuntu 16.x**
- **[如有使用不明白的地方请先查看脚本使用指南](https://github.com/mack-a/v2ray-agent/blob/master/documents/how_to_use.md)**
- **Oracle Cloud有一个额外的防火墙，需要手动设置**
- **Oracle Cloud仅支持Ubuntu**
- **如果使用gRPC通过cloudflare转发,需要在cloudflare设置允许gRPC，路径：cloudflare Network->gRPC**
- **gRPC目前处于测试阶段，可能对你使用的客户端不兼容，如不能使用请忽略**
- **低版本脚本升级高版本时无法启动问题，[请点击此链接查看解决方案](https://github.com/mack-a/v2ray-agent/blob/master/documents/how_to_use.md#4%E4%BD%8E%E7%89%88%E6%9C%AC%E5%8D%87%E7%BA%A7%E9%AB%98%E7%89%88%E6%9C%AC%E5%90%8E%E6%97%A0%E6%B3%95%E5%90%AF%E5%8A%A8%E6%A0%B8%E5%BF%83)**

## [脚本使用指南](https://github.com/mack-a/v2ray-agent/blob/master/documents/how_to_use.md)、[脚本目录](https://github.com/mack-a/v2ray-agent/blob/master/documents/how_to_use.md#5脚本目录)

## 捐赠

[您可以使用我的AFF进行购买VPS捐赠-博客](https://www.v2ray-agent.com/%E6%82%A8%E5%8F%AF%E4%BB%A5%E9%80%9A%E8%BF%87%E6%88%91%E7%9A%84AFF%E8%B4%AD%E4%B9%B0vps%E6%8D%90%E8%B5%A0)

[您可以使用我的AFF进行购买VPS捐赠-Github](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md)

[支持通过虚拟币向我捐赠](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation.md)

## 安装脚本

- 支持快捷方式启动，安装完毕后，shell输入【**vasma**】即可打开脚本，脚本执行路径[**/etc/v2ray-agent/install.sh**]

- Latest Version【推荐】

```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
```

- shadowsocks 动态IP白名单模式【Beta】

```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/dev_ss/install.sh" && chmod 700 /root/install.sh && /root/install.sh
```

# 示例图

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/install.jpg" width=700>

# 许可证

[AGPL-3.0](https://github.com/mack-a/v2ray-agent/blob/master/LICENSE)

## Stargazers over time

[![Stargazers over time](https://starchart.cc/mack-a/v2ray-agent.svg)](https://starchart.cc/mack-a/v2ray-agent)
