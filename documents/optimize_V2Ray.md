- [1.手动自选ip](#1手动自选ip)
  * [最优ip测试脚本](#最优ip测试脚本)
  * [客户端配置](#客户端配置)
    + [1.v2rayU](#1v2rayu)
    + [2.Quantumult](#2quantumult)
    + [3.ShadowRocket](#3shadowrocket)
    + [4.v2rayN](#4v2rayn)
- [2.断流优化](#2断流优化)
  
# 1.手动自选ip
- 1.配置简单
- 2.只需要客户端修改，也就是可以多账号实现自选IP。
- 3.需要保证在不自选ip的情况可以正常使用

## 最优ip测试脚本
- 建议使用一下Github仓库的脚本进行测试
- 支持Linux、Windows
```
https://github.com/badafans/better-cloudflare-ip
```

## 客户端配置
### 1.v2rayU
- 1.参考下图
- 2.address部分填写自定义ip或者上方提供的域名，host部分填写科学上网的域名
- 3.tls servername 同样填写科学上网的域名
- 4.如果多个自选ip，则复制刚刚添加好的配置，修改address部分即可。
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 v2rayU.png' width=400/>

### 2.Quantumult
- 1.参考下图
- 2.地址部分填写自选ip或者上方提供的域名
- 3.Host部分填写科学上网的域名
- 4.请求头-->Host部分填写科学上网的域名
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 Quantumult01.png' width=400/>
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 Quantumult02.png' width=400/>

### 3.ShadowRocket
- 1.参考下图
- 2.地址部分填写自选ip或者上方提供的域名
- 3.注意混淆部分->Host部分填写科学上网的域名
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 ShadowRocket01.png' width=400/>
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 ShadowRocket02.png' width=400/>

### 4.v2rayN
- 1.参考下图
- 2.地址部分填写自选ip或者上方提供的域名
- 3.注意伪装域名部分填写科学上网的域名
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare自选ip 手动更改 v2rayN.png' width=400/>

# 2.断流优化
> (这里贴一下V2Ray白话文指南具体说明)[https://guide.v2fly.org/advanced/cdn.html]
## 1.修改 Security Level
- Firewall->Settings->Security Level->Essentially Off
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/firewall_settings.png" width=400>

## 2.添加firewall rules
- Firewall- Firwall Rules->create a Firewall rule
- Rule name可以随便填
- URL Path Value填写翻墙的path
- action则为Allow

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/firewall_settings.png" width=400>