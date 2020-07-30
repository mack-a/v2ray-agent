# v2ray-agent

- 推荐 [一键CDN+TLS+WebSocket+Nginx+V2Ray脚本【小白推荐】](#全自动websockettlscdn智能优选cloudflare-ip一键脚本)
- 此项目采用[CDN+TLS+Nginx+V2Ray](#全自动websockettlscdn智能优选cloudflare-ip一键脚本)、[Trojan](#2Trojan)、[Cloudflare Workers](#方法3workers) 进行模拟正常网站并突破防火墙，同时包含优化方法，以及简单的原理讲解。
- [优化方案【CDN 自选ip】](https://github.com/mack-a/v2ray-agent/blob/master/optimize_V2Ray.md)包含对Cloudflare的优化（自选ip优化、DNS优化、[断流优化【CDN必看】](https://github.com/mack-a/v2ray-agent/blob/master/optimize_V2Ray.md#4%E6%96%AD%E6%B5%81%E4%BC%98%E5%8C%96)),如果您使用Cloudflare断流优化这个一定要看。
- [流量中转教程](#流量转发服务)【提高流量传输的速度，减少丢包】。
- [自建教程](#自建教程)可以快速入手并知晓其中的步骤。如遇到不懂以及不理解的可以加入[TG群讨论](https://t.me/technologyshare)。
- [免费订阅链接【1888.86 GB of 2 TB Used 2020-7-30】](https://github.com/mack-a/v2ray-agent/blob/master/free_account.md)。
- [建议安装脚本前先安装适合自己的BBR](https://github.com/mack-a/v2ray-agent/blob/master/bbr.md)
- 以上有问题可以提issues或者可以加入[TG群](https://t.me/technologyshare)反馈，欢迎加入TG群，共同学习、共同成长。

* * *
# 目录
- [一键脚本](#一键脚本)
  * [1.WebSocket+TLS+CDN+智能优选Cloudflare IP](#全自动websockettlscdn智能优选cloudflare-ip一键脚本)
- [自建教程](#自建教程)
  * [1.V2Ray](#1v2ray)
  * [2.Trojan](#2trojan)
- [流量转发服务](#流量转发服务)
   * [1.TLS+WS](#1tlsws点击查看)
   * [2.TCP+Vmess](#2tcpvmess点击查看)
* * *

* * *
# 一键脚本
## 全自动WebSocket+TLS+CDN+智能优选Cloudflare IP一键脚本
- 目前已在GCP上测试Centos[6【不稳定】、7、8]、Debian[9、10]、Ubuntu[16、18、19、20]通过，不开启云朵则为直连。
- 这里添加了默认的智能解析自选CDN IP，脚本安装时可手动选择是否使用，本地dns解析建议使用114.114.114.114
- 如果智能解析后发现不能上网，第一可以升级客户端、第二可以将address填写自己的科学上网的域名，不再使用智能解析CDN的域名，~~Shadowrocket可以将伪装域名添加到外层的Peer【Shadowrocket不兼容所致，请升级客户端】~~。
- 如果对默认的不满意，则可以[点此查看最新的](https://github.com/mack-a/v2ray-agent/blob/master/optimize_V2Ray.md)，或者加入[TG群](https://t.me/technologyshare)添加适合自己的CDN ip。
- [脚本更新日志](https://github.com/mack-a/v2ray-agent/releases)

域名|移动|移动测试|联通|电信
-|-|-|-|-
domain07.qiu4.ml|1.0.0.1|上午峰值2.3w，4k稍显卡顿、晚九点峰值1.5w，1440p较为流畅，晚十点半峰值7000，流畅1080|www.digitalocean.com|www.digitalocean.com

```
bash <(curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh)
```
- 1.自动检测并安装所需环境
- 2.自动安装Nginx、生成TLS证书，验证是否正常工作。
- 3.自动安装V2Ray、配置文件、生成随机uuid、开机自启。
- 4.自动验证是否服务搭建成功
- 5.自动添加伪装博客。
- 6.添加默认的CDN，自选ip智能解析。
- 7.默认安装最新的V2Ray版本。
- 8.定时任务，自动续期tls，tls证书状态
- 9.状态展示（V2Ray、TLS、定时任务）路径日志
- 10.常见错误处理

# 示例图
- 未安装
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/一键脚本未安装.png" width=400>

- 已安装
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/一键脚本已安装01.png" width=400>
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/一键脚本已安装02.png" width=400>

# 自建教程
# 1.V2Ray
- ios端建议使用Quantumult，表现要比Trojan好。

## 方法1(Flexible)【建议使用该方法】
- 只使用CloudFlare的证书
- 客户端->CloudFlare使用TLS+vmess加密，CloudFlare->VPS只使用vmess，[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/Cloudflare_Flexible.md)
- 不需要自己维护自己的https证书
- 少一步解析证书的过程，速度理论上会快一点

## 方法2(Full)
- 需要自己生成https证书，并自己维护，一般使用let's encrypt生成有效期为三个月。
- 客户端->CloudFlare使用CLoudFlare TLS+vmess加密，CloudFlare->VPS使用let's encrypt TLS+vmess加密，[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/Cloudflare_Full.md)
- 与方法1不同的是，CloudFlare和VPS通讯时也会使用TLS加密。两个方法安全方面区别不是很大。

## 方法3(Workers)
- [点击查看](https://github.com/mack-a/v2ray-agent/blob/master/cloudflare_workers.md)

# 2.Trojan
- 需要自己生成证书
- 客户端->使用自己生成的tls加密无其他加密->VPS,[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/Trojan.md)
- 少一层加密，理论速度会快一些。
- 速度取决于VPS的线路。
- 需要自己维护证书。
- [官方Github](https://github.com/trojan-gfw/trojan)

# 流量转发服务
## 1.TLS+WS[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/traffic_relay_tls_ws.md)
## 2.TCP+Vmess[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/traffic_relay_tcp_vmess.md)
