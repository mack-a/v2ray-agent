- [1.准备工作](#1准备工作)
- [2.配置流量转发服务](#2配置流量转发服务)
- [3.线路建议](#3线路建议)
- [4.游戏代理](#4游戏代理)

# 1.准备工作
## 1.注意事项
- 1.需要一台没被墙的VPS（IPLC除外），建议HK、日本
- 2.必须保证在不用流量转发服务的情况可以使用XTLS/TLS+VLESS、Trojan，这里的Trojan、XTLS/TLS+VLESS、websocket+tls 设置方法相同，下面是用VLESS+TCP/XTLS示例。

## 2.购买流量转发服务

# 2.配置流量转发服务
## 1.VLESS+TCP+TLS
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
- Peer名称 需填写你的域名
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/wikihost/wikihost_Shadowrocket.png" width=400>


#### 2.V2RayN
- 暂无

#### 3.V2RayNG
- 伪装域名需填写你的域名
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/wikihost/wikihost_V2RayNG.png" width=400>

## 2.TCP[IPLC专属]
- [wikihost添加步骤与TCP+TLS相同](#1vlesstcptls)

### 1.配置客户端
- 修改 地址+端口 为wikihost分配的 ip/域名+端口 即可
- 加密不建议选择none
- 其余客户端相同
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/Quantumult_Setting_vmess.png" width=400>

## 3.Trojan[推荐]
- 设置方法与[VLESS+TCP+TLS](#1vlesstcptls)

# 3.线路建议
- 1.广东移动+hk vps
- 2.上海CN2+美西or其他地区
- 3.上海联通+tw vps
- 4.莞港IPLC+hk vps
- 5.苏日IPLC+其他地区
- 6.深港高速内网+hk or 其他地区


# 4.游戏代理
- 游戏代理设置转发规则时必须选择第三个，TCP+UDP同时设置。
- 建议使用[Netch](https://github.com/NetchX/Netch/releases)
- Netch设置不是很复杂，这里不过多描述，[官网入门教程](https://github.com/NetchX/Netch/blob/master/docs/Quickstart.zh-CN.md)。
