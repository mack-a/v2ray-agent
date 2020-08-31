- [1.准备工作](#1准备工作)
  * [1.注意事项](#1注意事项)
  * [2.购买流量转发服务](#2购买流量转发服务)
- [2.配置流量转发服务](#2配置流量转发服务)
  * [1.V2Ray(Vmess/VLESS)+TCP+TLS[推荐VLESS]](#1v2rayvmessvlesstcptls推荐vless)
  * [2.TCP[IPLC专属]](#2tcpiplc专属)
  * [3.V2Ray+WS+TLS[不推荐]](#3wstls不推荐)
  * [4.Trojan+TCP+TLS[推荐]](#3trojantcptls)
- [3.线路建议](#3线路建议)
- [4.流量转发、计费方式](#4流量转发计费方式)

# 1.准备工作
## 1.注意事项
- 1.需要一台没被墙的VPS（IPLC除外），建议HK、日本
- 2.必须保证在不用流量转发服务的情况可以使用相应的方式科学上网（TCP+TLS、WS+TLS、TCP）
## 2.购买流量转发服务
- 1.注册-->[idc.wiki，无aff](https://idc.wiki)
- 2.注册完成后，服务-->购买新服务-->左侧显示菜单-->左侧列表最下面【流量转发服务】

# 2.配置流量转发服务
## 1.V2Ray(Vmess/VLESS)+TCP+TLS[推荐VLESS]
### 1.添加普通转发[协议tcp]

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/wikihost/wikihost_add_01.png" width=800>

### 2.填写ip+端口号

- 格式
```
ip:port
# 例子
103.11.119.22:443
```

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/wikihost/wikihost_add_02.png" width=400>

### 3.添加完毕后会给分配ip/域名+port
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/wikihost/wikihost_show_01.png" width=600>

### 4.配置客户端
- 地址位置填写wikihost分配的ip/域名
- 端口则为wikihost分配的端口
- 加密算法建议***none***并且***不打开***允许不安全连接


#### 1.Shadowrocket[VLESS]
- peer需填写你的域名
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/wikihost/wikihost_Shadowrocket.png" width=400>

#### 2.V2rayU[Vmess]
- tls servername填写你的域名
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/wikihost/wikihost_V2RayU.png" width=400>

#### 3.V2RayN
- 暂无

#### 4.V2RayNG
- 伪装域名需填写你的域名
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/wikihost/wikihost_V2RayU.png" width=400>

## 2.TCP[IPLC专属]
- [wikihost添加步骤与TCP+TLS相同](添加普通转发协议tcp)
### 1.配置客户端
- 修改 地址+端口 为wikihost分配的 ip/域名+端口 即可
- 加密不建议选择none
- 其余客户端相同
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/Quantumult_Setting_vmess.png" width=400>

## 3.WS+TLS[不推荐]
- [wikihost添加步骤与TCP+TLS相同](添加普通转发协议tcp)
- 加密算法建议none并且不打开允许不安全连接

## 1.配置客户端
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

## 4.Trojan+TCP+TLS
- 暂无

# 3.线路建议
- 1.广东移动+hk vps
- 2.上海CN2+美西or其他地区
- 3.上海联通+tw vps
- 4.莞港IPLC+hk vps
- 5.苏日IPLC+其他地区
- 6.深港高速内网+hk or 其他地区


# 4.流量转发、计费方式
## 1.流量转发方式
- 普通
```
设备 <=> 流量转发 <=> 目标
```
- IPLC
```
设备 <=> 入口 <=> IPLC内网 <=> 出口 <=> 目标
```
## 2.计费方式
```
设备 <=> 入口
```

