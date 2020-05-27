# v2ray-agent
>Everyone is free。
>世界就是这样，当你开始思考时，你已经是小部分中的一员了。祝大家使用愉快。

- 推荐 [全新一键CDN+TLS+WebSocket+Nginx+V2Ray脚本](#一键脚本全自动websockettlscdn一键脚本)
- 此项目采用[CDN+TLS+Nginx+V2Ray](1V2Ray)、[Trojan](2Trojan)、[Cloudflare Workers](#方法3workers) 进行模拟正常网站并突破防火墙，同时包含优化方法，以及简单的原理讲解。
- [自建教程](#自建教程)可以快速入手并知晓其中的步骤。如遇到不懂以及不理解的可以加入[TG群讨论](https://t.me/v2rayAgent)。
- [优化方案](#优化方案)包含对Cloudflare的优化（CNAME优化、DNS优化、断流优化），VPS处理性能优化（bbr、bbr plus【阻塞拥堵算法，加快对流量的处理】）、其余设置（开机启动）、docker镜像、防火墙设置。
- [流量中转教程](#流量转发服务)【大大提高流量传输的速度，减少丢包】、[免费测试账号](#免费账号正常使用点击查看)。
- 接下来会提供V2Ray配置生成器、iptables流量转发、Docker镜像、私有Docker仓库、私有git仓库【gitlab】、以及可供部署k8s容器等方面的内容。
- [测试订阅链接](https://github.com/mack-a/v2ray-agent/blob/master/free_account.md)【如无法使用可加入TG群反馈】。
- 如本项目缺少或者待完善的教程，肯定是群主懒，加入TG群鞭打群主，让群主更有动力，给个Star支持一下😊。

* * *
# 目录
- [一键脚本【CDN+TLS+WebSocket+Nginx+V2Ray【CDN为非必选】、Trojan+TLS】](#一键脚本全自动websockettlscdn一键脚本)
- [技能点列表](#技能点列表)
- [自建教程](#自建教程)
  * [1.V2Ray](#1v2ray)
  * [2.Trojan](#2trojan)
- [流量转发服务](#流量转发服务)
   * [1.tls+ws](1tlsws点击查看)
   * [2.tcp+vmess](#2tcpvmess点击查看)
- [客户端](#客户端)
- [防护墙设置](#防火墙设置点击查看)
- [测试账号](#免费账号正常使用点击查看)
- [维护进程[todo List]](https://github.com/mack-a/v2ray-agent/blob/master/recover_version.md)

* * *
### 优化方案
- [优化v2ray【断流、CNAME自选ip、dnsmasq自定义dns实现cname自选ip】](https://github.com/mack-a/v2ray-agent/blob/master/optimize_V2Ray.md)
- [其余设置【开机自启、bbr加速】](https://github.com/mack-a/v2ray-agent/blob/master/settings.md)

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
```
bash <(curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh)
```
## 全自动Trojan+TLS一键脚本【TODO】

- 1.自动检测并安装所需环境
- 2.自动安装Nginx、TLS并生成TLS证书，并验证是否正常工作。
- 3.自动安装V2Ray、配置文件、生成随机uuid以及开机自启。
- 4.自动验证是否服务搭建成功
- 5.自动伪装博客
- 6.下个版本增加真实可用、并且可以手动书写文章的博客。

# 示例图
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/一键脚本示例图01.png" width=400>
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/一键脚本示例图02.png" width=400>

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
# 测试订阅链接【正常使用】[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/free_account.md)
