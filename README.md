# v2ray-agent
>我始终相信人是自由的，这是本项目设立的初衷，同时也感谢各种软件的开发者与维护者。
>世界就是这样，当你开始思考时，你已经是小部分中的一员了。祝大家使用愉快。

- 本项目涉及知识点较多请耐心看完，知其然知其所以然。
- 极力推荐 [全新一键CDN+TLS+Nginx+V2Ray脚本](#一键脚本全自动websockettlscdn一键脚本)
- 此项目分别采用CDN+TLS+Nginx+V2Ray、Trojan进行模拟正常网站并突破防火墙，同时包含优化方法，以及简单的原理讲解。
- 【[自建教程](#自建教程)】，自建教程可以快速入手并知晓其中的步骤。如遇到不懂以及不理解的可以加入[TG群讨论【对小白尤其友好】](https://t.me/v2rayAgent)。
- 优化方案包含对Cloudflare的优化（[CNAME优化、DNS优化、断流优化、](#优化方案)），VPS处理性能优化（bbr、bbr plus【阻塞拥堵算法，加快对流量的处理】）、其余设置（开机启动）、docker镜像、防火墙设置。
- 同时提供[流量中转教程](#流量转发服务)【大大提高流量传输的速度，减少丢包】、[免费测试账号](#免费账号正常使用点击查看)。
- 接下来会提供V2Ray配置生成器、iptables流量转发、Docker镜像、私有Docker仓库、私有git仓库【gitlab】、以及可供部署k8s容器等方面的内容。
- 提供免费订阅链接【[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/free_account.md)】【如无法使用可加入TG群反馈】。
- 如本项目缺少还未加入或者完善的教程，肯定是群主懒，加入TG群鞭打群主，让群主更有动力。

* * *
# 目录
- [一键脚本](#一键脚本全自动websockettlscdn一键脚本)
- [技能点列表](#技能点列表)
- [自建教程](#自建教程)
  * [1.V2Ray](#1v2ray)
      + [1.方法1](#方法1flexible建议使用该方法)
      + [2.方法2](#方法2full)
  * [2.Trojan](#2trojan)
- [流量转发服务](#流量转发服务)
   * [1.tls+ws](1tlsws点击查看)
   * [2.tcp+vmess](#2tcpvmess点击查看)
- [客户端](#客户端)
  * [1.windows](#1windows)
  * [2.Android](#2android)
  * [2.ios](#3ios需要自行购买或者使用共享账号安装)
  * [2.Mac](#4mac)
- [防护墙设置](#防火墙设置点击查看)
- [免费账号【正常使用】](#免费账号正常使用点击查看)
- [备注](#备注)
  * [1.推荐使用v2ray+CDN的方式](#1推荐使用v2ray-cdn的方式)
      + [1.优点](#1优点)
      + [2.缺点](#2缺点)
      + [3.数据包解析](#3数据包解析)
      + [4.建议](#4建议)
  * [2.速度首选V2Ray TCP方式](#2速度首选v2ray-tcp方式)
  * [3.本地网络环境不稳定首选mKCP](#3本地网络环境不稳定首选mkcp)
  * [4.目前不推荐使用ss、ssr](#4目前不推荐使用ss-ssr)
- [维护进程[todo List]](#维护进程todo-list)
  * [1.一键脚本](#1一键脚本)
    + [1.自动模式](#1自动模式)
    + [2.手动模式](#2手动模式)

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
# 一键脚本【全自动WebSocket+TLS+CDN一键脚本】
- 目前支持Centos、Ubuntu、Debian
```
bash <(curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh)
```
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
# 免费账号【正常使用】[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/free_account.md)
# 备注
## 1.推荐使用v2ray+CDN的方式
### 1.优点
- 1.防止境外vps被墙
- 2.由于CDN的方式是通过完全模拟正常网站，也可以是说本来就是一个正常的网站，同时又使用正常的CDN厂商（全球最大），有很多的外贸以及国外公司使用，墙一般不敢ban这些ip
- 3.可以用于被墙vps的搭建
- 4.相对来说更加安全

### 2.缺点
- 1.配置过程复杂
- 2.知识点相对比较多
- 3.维护相对复杂
- 4.由于CloudFlare不是国内的CDN厂商，速度相对来说慢一些（可以尝试CNAME优化方案[CNAME因为要使用国内的dns，相对于来说有风险]、或者使用自定义dns服务器[分享相对小一些]）

### 3.数据包解析
- 1.首先运营商以及GFW获取到的数据包，无法作为中间人进行攻击（中间人可以直接获取到v2ray的加密数据包）
- 2.即使获取到数据包之后，还需要对数据包进行解密，所以证书推荐使用第三方的，而不使用官方提供的，用了TLS加密的数据不是说不能解密，而是需要耗费巨大的时间以及运算能力
- 3.解密完成后 还需要对v2ray加密的数据进行解密、嗅探等操作
- 4.不建议使用不明来历的机场，如果机场主是国内的某些关系户，你用的代理相当于实名翻墙（违法）

### 4.建议
- 1.注意隐私保护（今日不同往日）
- 2.建议只用做学习以及娱乐使用，不建议发表一些敏感言论（不管是诋毁自己所在的国家，还是诋毁别的国家）
- 3.不建议人身攻击（有被起底的先例）

## 2.速度首选V2Ray TCP方式
- 1.本脚本目前不支持（后续可能会添加）

## 3.本地网络环境不稳定首选mKCP
- 1.本脚本目前不支持（后续可能会添加）

## 4.目前不推荐使用ss、ssr

# 维护进程[todo List]
## 1.一键脚本
### 1.自动模式
- [x] 1.检查系统版本是否为Ubuntu、Centos、Debian
- [x] 2.安装工具包
- [x] 3.检测nginx是否安装并配置
- [x] 4.检测https是否安装并配置
- [x] 5.检测V2Ray是否安装并配置
- [x] 6.生成vmess、二维码链接
- - [x] 1.shadowrocket
- - [ ] 2.Quantumult
- [x] 7.启动服务并退出脚本
- [ ] 8.HTTPS续签
- [ ] 9.开机自启动
- [ ] 10.面板搭建
- - [ ] 1.在线创建、删除、修改账户
- - [ ] 2.一键管理Nginx、TLS
- - [ ] 3.开机自启动
- - [ ] 4.流量控制
- - [ ] 5.日志查看
- [x] 11.Docker[开箱即用]
- [x] 12.自定义DNS服务器替换CNAME优化方案
- [ ] 13.k8s+docker一键构建V2Ray Nginx

### 2.手动模式
- [x] 1.检查系统版本是否为Ubuntu、Centos、Debian
- [x] 2.安装工具包
- [x] 3.检测nginx是否安装并配置
- [x] 4.检测https是否安装并配置
- [x] 5.检测V2Ray是否安装并配置
- [x] 6.启动服务并退出脚本
- [x] 7.卸载安装的所有内容
- [x] 8.查看配置文件路径
- [x] 9.生成Vmess链接
- [x] 10.返回主目录
- [x] 11.退出脚本

## 1.手动搭建
- [x] 手动搭建
