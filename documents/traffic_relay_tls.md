- [1.准备工作](#1准备工作)
- [2.购买流量转发服务](#2购买流量转发服务)
- [3.配置流量转发服务](#3配置流量转发服务)
  * [1.配置idc.wiki流量转发](#1配置idcwiki流量转发)
- [4.修改客户端](#4修改客户端)
  * [1.客户端示例](#1客户端示例) 
- [6.流量转发、计费方式](#6流量转发计费方式)

>购买之前必看[流量计费规则](6流量转发计费方式)

# 1.准备工作
- 1.需要一台没被墙的VPS（IPLC可使用被墙的）。
- 2.必须保证在不用流量转发服务的情况可以使用XTLS/TLS+VLESS、Trojan，这里的Trojan、XTLS/TLS+VLESS、websocket+tls 设置方法相同，下面是用websocket+tls示例。

# 2.购买流量转发服务

# 3.配置流量转发服务
## 1.配置idc.wiki流量转发
- 1.服务-->我的产品和服务-->管理产品-->添加普通转发 or 添加IPLC转发
- 2.配置转发规则[tcp]，需转发地址，填写自己vps的ip以及https+ws的端口【示例：173.82.112.30:443】
- 3.添加完成后会给分配ip和端口

>示例图
- 添加转发服务示例图

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/wikihost/wikihost_tcp_setting.png" width=400>

- 添加完成后示例图

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/wikihost/wikihost_rules.png" width=700>

# 4.修改客户端
- 思路和CDN手动自选ip一样
- 修改客户端地址、端口为wikihost分配的IP or 域名、端口。
- header or peer部分填写科学上网的域名


## 客户端示例
- 下面的地址、端口都要填写上方示例图中，wikihost分配的ip和端口

### 1.v2rayU
- 1.参考下图
- 2.address、端口部分填写wikihost分配的ip和端口，host部分填写科学上网的域名
- 3.tls servername 同样填写科学上网的域名
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 v2rayU.png' width=400/>

### 2.Quantumult
- 1.参考下图
- 2.地址、端口部分填写wikihost分配的ip和端口
- 3.Host部分填写科学上网的域名
- 4.请求头-->Host部分填写科学上网的域名
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 Quantumult01.png' width=400/>
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 Quantumult02.png' width=400/>

### 3.ShadowRocket
- 1.参考下图
- 2.地址、端口部分填写wikihost分配的ip和端口
- 3.注意混淆部分->Host部分填写科学上网的域名
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 ShadowRocket01.png' width=400/>
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 ShadowRocket02.png' width=400/>

### 4.v2rayN
- 1.参考下图
- 2.地址、端口部分填写wikihost分配的ip和端口
- 3.注意伪装域名部分填写科学上网的域名
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 v2rayN.png' width=400/>
