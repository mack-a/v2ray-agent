# v2ray-agent
- 新版教程，如需查看旧版请点击["返回旧版"](https://github.com/mack-a/v2ray-agent/blob/master_backup/README.md)
- [Cloudflare 优化方案](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)
- [流量中转](https://github.com/mack-a/v2ray-agent/blob/master/documents/traffic_relay.md)
- [手动自建教程](#3手动自建教程)
- [订阅频道](https://t.me/v2rayagentshare)、[TG群](https://t.me/technologyshare)、[博客地址](https://blog.v2ray-agent.com/)
- [公益订阅链接【313.23 GB of 2 TB Used 2020-9-7】](https://github.com/mack-a/v2ray-agent/blob/master/documents/free_account.md)。

* * *
# 目录
- [1.(VLESS+TCP+TLS/VMess+TCP+TLS/VMess+WS+TLS)+伪装博客 三合一共存脚本[Cloudflare云朵需为灰色]](#1vlesstcptls伪装博客vmesswstls伪装博客cloudflare-云朵需设置灰色-二合一脚本)
- [2.手动自建教程](#2手动自建教程)
* * *
# 1.(VLESS+TCP+TLS/VMess+TCP+TLS/VMess+WS+TLS)+伪装博客 三合一共存脚本【Cloudflare云朵需为灰色】
- 安装脚本
```
bash <(curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh)
```
- 示例图
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/dev/fodder/install/install_尝鲜版_01.png" width=400>
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/dev/fodder/install/install_尝鲜版_02.png" width=400>

# 2.手动自建教程
## 1.V2Ray
### 方法1(Flexible)【建议使用该方法】
- 只使用CloudFlare的证书
- 客户端->CloudFlare使用TLS+vmess加密，CloudFlare->VPS只使用vmess，[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/documents/Cloudflare_Flexible.md)
- 不需要自己维护自己的https证书
- 少一步解析证书的过程，速度理论上会快一点

### 方法2(Full)
- 需要自己生成https证书，并自己维护，一般使用let's encrypt生成有效期为三个月。
- 客户端->CloudFlare使用CLoudFlare TLS+vmess加密，CloudFlare->VPS使用let's encrypt TLS+vmess加密，[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/documents/Cloudflare_Full.md)
- 与方法1不同的是，CloudFlare和VPS通讯时也会使用TLS加密。两个方法安全方面区别不是很大。

### 方法3(Workers)
- [点击查看](https://github.com/mack-a/v2ray-agent/blob/master/documents/cloudflare_workers.md)
