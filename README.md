# v2ray-agent
>Everyone is free。
>世界就是这样，当你开始思考时，你已经是小部分中的一员了。祝大家使用愉快。

- 推荐 [全新一键CDN+TLS+WebSocket+Nginx+V2Ray脚本](#全自动websockettlscdn一键脚本)
- 此项目采用[CDN+TLS+Nginx+V2Ray](1V2Ray)、[Trojan](2Trojan)、[Cloudflare Workers](#方法3workers) 进行模拟正常网站并突破防火墙，同时包含优化方法，以及简单的原理讲解。
- [自建教程](#自建教程)可以快速入手并知晓其中的步骤。如遇到不懂以及不理解的可以加入[TG群讨论](https://t.me/v2rayAgent)。
- [优化方案【CDN 自选ip】](https://github.com/mack-a/v2ray-agent/blob/master/optimize_V2Ray.md)包含对Cloudflare的优化（自选ip优化、DNS优化、断流优化。
- [流量中转教程](#流量转发服务)【提高流量传输的速度，减少丢包】。
- [测试订阅链接](https://github.com/mack-a/v2ray-agent/blob/master/free_account.md)【如无法使用可加入[TG群](https://t.me/v2rayAgent)反馈】。
- 个性化需求可以加入[TG群](https://t.me/v2rayAgent)讨论。
- [强烈安装适合自己的BBR，执行脚本前必看](https://github.com/mack-a/v2ray-agent/blob/master/bbr.md)

* * *
# 目录
- [一键脚本](#一键脚本)
  * [WebSocket+TLS+CDN](#全自动websockettlscdn一键脚本)
- [技能点列表](#技能点列表)
- [自建教程](#自建教程)
  * [1.V2Ray](#1v2ray)
  * [2.Trojan](#2trojan)
- [流量转发服务](#流量转发服务)
   * [1.tls+ws](1tlsws点击查看)
   * [2.tcp+vmess](#2tcpvmess点击查看)
- [客户端](#客户端)
- [防护墙设置](#防火墙设置点击查看)
- [维护进程[todo List]](https://github.com/mack-a/v2ray-agent/blob/master/recover_version.md)
* * *


# 技能点列表
- [cloudcone](https://app.cloudcone.com/?ref=5346)【vps】
- [bandwagonhost](https://bandwagonhost.com/aff.php?aff=46893)【vps】
- [freenom](https://freenom.com/)【免费域名【注册时最好使用全局代理、ip所在地和注册地一致并且最好使用手机】】
- [godaddy](https://www.godaddy.com/)【域名厂商】
- [cloudflare](cloudflare.com)【CDN】
- [letsencrypt](https://letsencrypt.org/)【HTTPS】
- [Nginx](https://www.nginx.com/)【域名反向代理】
- [V2Ray](v2ray.com)【代理工具】


## 欢迎加入TG群，共同学习、共同成长。
[点击此链接加入电报群](https://t.me/v2rayAgent)

* * *
# 一键脚本
## 全自动WebSocket+TLS+CDN一键脚本
- 目前支持Centos、Ubuntu、Debian，也可以不使用CDN
- 这里添加了默认的智能解析自选CDN IP，脚本安装完毕后会自动使用，本地dns解析建议使用114.114.114.114
- 如果智能解析后发现不能上网，第一可以升级客户端、第二可以将address填写自己的科学上网的域名，不再使用智能解析CDN的域名。
- 如果对默认的不满意，则可以[点此查看最新的](https://github.com/mack-a/v2ray-agent/blob/master/optimize_V2Ray.md)，或者加入[TG群](https://t.me/v2rayAgent)添加适合自己的CDN ip。

域名|移动|移动测试|联通|电信
-|-|-|-|-
domain04.qiu4.ml|104.17.209.9|上午峰值6w，稳定4k不卡顿、晚八点峰值4w，流畅4k，晚9点峰值1w-3w跨度较大，流畅1440p|104.16.25.4|104.16.25.4

```
bash <(curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh)
```
- 1.自动检测并安装所需环境
- 2.自动安装Nginx、TLS并生成TLS证书，并验证是否正常工作。
- 3.自动安装V2Ray、配置文件、生成随机uuid以及开机自启。
- 4.自动验证是否服务搭建成功
- 5.自动伪装博客
- 6.添加了默认的CDN，自选ip智能解析
- 7.增加定时任务 自动续期tls【todo】

## 全自动生成TLS证书一键脚本
- 针对只需要生成TLS证书的用户

```
bash <(curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh)
```
- 1.会安装依赖所需依赖
- 2.会把Nginx配置文件备份
- 3.会安装Nginx、acme.sh，如果已安装则使用已经存在的
- 4.安装完毕或者安装失败会自动恢复备份，请不要手动关闭脚本
- 5.执行期间请不要重启机器
- 6.备份文件和证书文件都在/tmp下面，请注意留存
- 7.如果多次执行则将上次生成备份和生成的证书强制覆盖
- 8.证书默认ec-256
- 9.下个版本会加入通配符证书生成[todo]
- 10.可以生成多个不同域名的证书[包含子域名]，具体速率请查看[https://letsencrypt.org/zh-cn/docs/rate-limits/]
- 11.兼容Centos、Ubuntu、Debian

# 示例图
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/一键脚本示例图01.png" width=400>
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/一键脚本示例图02.png" width=400>

## 全自动Trojan+TLS一键脚本【TODO】

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
## 1.tls+ws[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/traffic_relay_tls_ws.md)

## 2.tcp+vmess[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/traffic_relay_tcp_vmess.md)

# 客户端
## 1.windows
- [v2rayN](https://github.com/2dust/v2rayN/releases)

## 2.Android
- [v2rayNG](https://github.com/2dust/v2rayNG/releases)

## 3.ios【需要自行购买或者使用共享账号安装】
- Quantumult【推荐使用】
- Shadowrocket

## 4.Mac
- [V2rayU](https://github.com/yanue/V2rayU/releases)


# 防火墙设置[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/firewall.md)
