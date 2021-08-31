- [1.手动自选ip](#1手动自选ip)
    * [原理解析](#原理解析)
    * [最优ip测试脚本](#最优ip测试脚本)
    * [智能解析DNS对应的IP](#智能解析dns对应的ipcname效果)
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
- 4.目前只有WS流量支持CDN

## 原理解析

- 1.这里的伪装域名、SNI、Peer都是填写的自己真实的域名，当TLS验证域名进行握手时会通过这个进行握手，也就无需关心为什么address不是自己的域名但是还能TLS握手成功。
- 2.domain08.mqcjuc.ml 这个域名是通过中国大陆的DNS解析服务商进行解析，众所周知中国大陆是一个局域网的环境，如果想要使用这个域名进行解析IP，则需要使用国内的DNS服务商，例如114.114.114.114
- 3.当客户端请求DNS解析时，DNS服务商会根据你的本地电信运营商，进行对应设置的DNS解析，例如我设置domain08.mqcjuc.ml这个域名的中国移动解析ip为104.19.41.56，当本地电信运营商为中国移动，解析这个域名时会解析出104.19.41.56。
- 4.如果既想要使用TCP+TLS又想要使用WS+TLS，则不需要开启云朵。
- 5.不开启云朵时，当address为自己的域名时，ip解析为真实的vps服务器ip则为直连，当address为智能DNS解析的IP时，流量则会通过Cloudflare回源机制到Cloudflare服务器来实现CDN进行转发ws，则为CDN转发。
- 6.不开云朵，自选ip同样适用于被阻断的ip。

## 最优ip测试工具

- 支持Linux、Windows、Android
- 下面提供的ip，不一定适合所有人，建议使用下方的工具找到最适合自己的CDN ip。

```
https://github.com/XIU2/CloudflareSpeedTest
https://github.com/badafans/better-cloudflare-ip
```

# 智能解析DNS对应的IP[CNAME效果]

- domain08.mqcjuc.ml是本项目提供的智能解析IP
- www.cloudflare.com、www.digitalocean.com 这两个则是使用Cloudflare的服务的域名，他会根据本地运营商的不同，来分配不同的ip。

域名|移动|联通|电信 
-|-|-|- 
domain08.mqcjuc.ml|104.19.41.56|www.cloudflare.com|www.digitalocean.com
www.cloudflare.com|xx|xx|xx
www.digitalocean.com|xx|xx|xx

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

### 5.Openwrt - Passwall
#### VLESS-WS
- 1.地址（支持域名）（address）填写：科学上网的域名
- 2.域名（tlsServerName）填写：科学上网的域名
- 3.WebSocket Host（ws host）填写：自定义ip或者上方提供的域名

#### VLESS-gRPC
- 1.地址（支持域名）(address)填写：自定义ip或者上方提供的域名
- 2.域名（tlsServerName）填写：科学上网的域名
- 3.注意记得填写serviceName

# 2.断流优化
> [这里贴一下V2Ray白话文指南具体说明](https://guide.v2fly.org/advanced/cdn.html)

## cloudflare gRPC断流
- [grpc协议下UDP通过cloudflare会断](https://github.com/XTLS/Xray-core/issues/671)
- [为什么套用 cloudflare grpc 会断流](https://github.com/v2fly/v2ray-core/discussions/1174)

