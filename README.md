# v2ray-agent

> [感谢 JetBrains 提供的非商业开源软件开发授权](https://www.jetbrains.com/?from=v2ray-agent)

> [Thanks for non-commercial open source development authorization by JetBrains](https://www.jetbrains.com/?from=v2ray-agent)

> [English Version](https://github.com/mack-a/v2ray-agent/blob/master/documents/en/README_EN.md)

- [Cloudflare 优化方案](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)
- [流量中转](https://github.com/mack-a/v2ray-agent/blob/master/documents/traffic_relay.md)
- [手动自建教程](https://github.com/mack-a/v2ray-agent/blob/master/documents/Cloudflare_install_manual.md)
- [ssh入门教程](https://www.v2ray-agent.com/2020-12-16-ssh%E5%85%A5%E9%97%A8%E6%95%99%E7%A8%8B)
- [TG群](https://t.me/technologyshare)、[订阅频道-及时获取更新通知](https://t.me/v2rayagentshare)、[博客地址](https://www.v2ray-agent.com/)
- [公益订阅链接](https://github.com/mack-a/v2ray-agent/blob/master/documents/free_account.md)。
- **请给个🌟支持一下**

* * *

# 目录

- [1.脚本安装](#1vlesstcptlsvlesswstlsvmesstcptlsvmesswstlstrojan-伪装站点-五合一共存脚本)
    * [组合方式](#组合方式)
    * [组合推荐](#组合推荐)
    * [特性](#特性)
    * [注意事项](#注意事项)
    * [安装脚本](#安装脚本)

* * *

# 1.七合一共存脚本+伪装站点

- [Cloudflare入门教程](https://github.com/mack-a/v2ray-agent/blob/master/documents/cloudflare_init.md)

## 特性

- 支持[Xray-core[XTLS]](https://github.com/XTLS/Xray-core)、v2ray-core [XTLS]、v2ray-core
- 支持不同核心之间的配置文件互相读取
- 支持 VLESS/VMess/trojan/trojan-go[ws]
- 支持Debian、Ubuntu、Centos，支持主流的cpu架构。**不建议使用Centos以及低版本的系统，2.3.x后不再支持Centos6**
- 支持个性化安装
- 支持多用户管理
- 支持Netflix检测、支持DNS流媒体解锁
- 无需卸载即可安装、重装任意组合。卸载脚本时无多余文件残留
- 支持纯IPv6，[IPv6注意事项](https://github.com/mack-a/v2ray-agent/blob/master/documents/IPv6_help.md)
- 支持利用IPv6排除Google的人机验证，**需自己申请IPv6隧道，不建议使用自带的IPv6**
- [支持自定义证书安装](https://github.com/mack-a/v2ray-agent/blob/master/documents/install_tls.md)

## 支持的安装类型

- VLESS+TCP+TLS
- VLESS+TCP+xtls-rprx-direct【**推荐**】
- VLESS+WS+TLS【支持CDN、IPv6】
- VMess+TCP+TLS
- VMess+WS+TLS【支持CDN、IPv6】
- Trojan【**推荐**】
- Trojan-Go+WS【支持CDN、不支持IPv6】

## 线路推荐

- 1.GIA
- 2.上海CN2+HK
- 3.上海联通+台湾TFN
- 4.上海联通+Vultr东京
- 5.广移/珠移+HKIX/CMI/NTT
- 6.苏日IPLC+日本/美国
- 7.莞港IPLC+HK
- 8.广移/CN2+Cloudflare+全球
- 9.广移/CN2/南联+香港AZ+全球
- 10.北联+西伯利亚、伯力ttk/RT
- 11.CN2+HE
- 12.电信+台湾远传电信

## 组合推荐

- 中专/gia ---> VLESS+TCP+TLS/XTLS、Trojan【推荐使用XTLS的xtls-rprx-direct】
- 移动宽带 ---> VMESS+WS+TLS/Trojan-Go+WS + Cloudflare
- Trojan建议开启Mux【**多路复用**】，仅需客户端开启，服务端自适应。
- VMess/VLESS也可开启Mux，效果需要自己尝试，XTLS不支持Mux。仅需客户端开启，服务端自适应。

## 注意事项

- 修改Cloudflare->SSL/TLS->Overview->Full
- Cloudflare ---> A记录解析的云朵必须为灰色
- **使用纯净系统安装，如使用其他脚本安装过，请重新build系统再安装**
- wget: command not found [**这里需要自己手动安装下wget**]
  ，如未使用过Linux，[点击查看](https://github.com/mack-a/v2ray-agent/tree/master/documents/install_tools.md)安装教程
- 不支持非root账户
- **中间的版本号升级意味可能不兼容之前安装的内容，如果不是追新用户或者必须升级的版本请谨慎升级。** 例如 2.2.\*，不兼容2.1.\*
- **如发现Nginx相关问题，请卸载掉自编译的nginx或者重新build系统**
- **为了节约时间，反馈请带上详细截图或者按照模版规范，无截图或者不按照规范的issue会被直接关闭**
- **不建议GCP用户使用**
- **不建议使用Centos以及低版本的系统，2.3.x后不再支持Centos6**

## 脚本目录

- v2ray-core 【**/etc/v2ray-agent/v2ray**】
- Xray-core 【**/etc/v2ray-agent/xray**】
- Trojan 【**/etc/v2ray-agent/trojan**】
- TLS证书 【**/etc/v2ray-agent/tls**】
- Nginx配置文件 【**/etc/nginx/conf.d/alone.conf**】、Nginx伪装站点目录 【**/usr/share/nginx/html**】

## [脚本功能详解、错误处理、常用命令](https://github.com/mack-a/v2ray-agent/blob/master/documents/how_to_use.md)

## 安装脚本

- 支持快捷方式启动，安装完毕后，shell输入[**vasma**]即可打开脚本，脚本执行路径[**/etc/v2ray-agent/install.sh**]

- 最新版

```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
```

- 稳定-v2.2.24

```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/9ae23c13a56460d8c14f27c8eb65efc73b173f46/install.sh" && chmod 700 /root/install.sh && /root/install.sh
```

- 稳定-v2.1.27

```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/3f8ea0aa364ae2e1e407056074c11b448396261f/install.sh" && chmod 700 /root/install.sh && /root/install.sh
```

- 示例图

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/install.jpg" width=700>

# 许可证

[GPL-3.0](https://github.com/mack-a/v2ray-agent/blob/master/LICENSE)

## Stargazers over time

[![Stargazers over time](https://starchart.cc/mack-a/v2ray-agent.svg)](https://starchart.cc/mack-a/v2ray-agent)
