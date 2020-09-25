# v2ray-agent
- 新版教程，如需查看旧版请点击["返回旧版"](https://github.com/mack-a/v2ray-agent/blob/master_backup/README.md)
- [Cloudflare 优化方案](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)
- [流量中转](https://github.com/mack-a/v2ray-agent/blob/master/documents/traffic_relay.md)
- [手动自建教程](https://github.com/mack-a/v2ray-agent/blob/master/documents/Cloudflare_install_manual.md)
- [订阅频道](https://t.me/v2rayagentshare)、[TG群](https://t.me/technologyshare)、[博客地址](https://blog.v2ray-agent.com/)
- [公益订阅链接【1771.40 GB of 2 TB Used 2020-9-25】](https://github.com/mack-a/v2ray-agent/blob/master/documents/free_account.md)。

* * *
# 目录
- [1.脚本安装](#1vlesstcptlsvlesswstlsvmesstcptlsvmesswstlstrojan-伪装博客-五合一共存脚本)
  * [组合推荐](#组合推荐)
  * [注意事项](#注意事项)
* * *

# 1.VLESS+TCP+TLS/VLESS+WS+TLS/VMess+TCP+TLS/VMess+WS+TLS/Trojan +伪装博客 五合一共存脚本
- 如果没有使用过Cloudflare[点击这里](https://github.com/mack-a/v2ray-agent/blob/master/documents/cloudflare_init.md)查看入门教程

## 特性
- VLESS/VMess/Trojan-Go三种工具合并为一个脚本，可以体验不同的工具之间的不同特性、兼容更多的设备。
- 支持Debian、Ubuntu、Centos
- 脚本自动检查升级
- 自动更新TLS证书

## 组合推荐
- 中专/gia ---> VLESS+TCP+TLS/Trojan
- 移动宽带  ---> VLESS+WS+TLS/VMESS+WS+TLS + Cloudflare

## 注意事项
- 修改Cloudflare->SSL/TLS->Overview->Full
- Cloudflare ---> A记录解析的云朵必须为灰色
- wget: command not found [这里需要自己手动安装下wget]
- 脚本安装路径[/etc/v2ray-agent]

## 安装脚本
```
wget -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod +x install.sh && ./install.sh
```
- 示例图
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/install.jpg" width=700>

# 许可证
[MIT](https://github.com/mack-a/v2ray-agent/blob/master/LICENSE)

## Stargazers over time

[![Stargazers over time](https://starchart.cc/mack-a/v2ray-agent.svg)](https://starchart.cc/mack-a/v2ray-agent)
