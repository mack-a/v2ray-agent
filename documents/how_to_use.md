> 脚本功能介绍

# 目录

- [1.快速开始](#1快速开始)
- [2.进阶教学](#2进阶教学)
- [3.常见错误处理](#3常见错误处理)
- [4.答疑](#4答疑)

# 1.快速开始

## 1.安装/重新安装/任意组合安装

>安装/重新安装

- 此操作会安装根据选择不同内核进行全部协议的安装【VLESS、VMess、trojan】,不会安装hysteria
 
>任意组合安装

- 必选VLESS TCP，其余的可以任意组合 

### 1.选择内核

- 1.Xray-core[推荐]
- 2.v2ray-core

### 2.输入域名

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_01.png" width=700>

### 3.是否自定义端口
- 如果自定义端口后只可使用dns申请证书
- 如回车默认，则申请证书时会提示是否使用dns申请证书

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_02.png" width=700>

### 4.检测域名的ip

- 这里会全自动检查域名的IP是否正确
  
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_03.png" width=700> 
 
- 如提示不正确请按照步骤依次检测，如检测后确认无误请卸载脚本或者重新安装系统重新尝试

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_04.png" width=700>


### 5.申请TLS证书

- 提供三种不同的厂商
#### 1.安装成功

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_05.png" width=700>

#### 2.安装失败
- 如果是防火墙问题脚本打开对应端口后请重新尝试即可

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_06.png" width=700>
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_07.png" width=700>

#### 3.已安装过

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_11.png" width=700>

### 6.生成随机路径
- 这里会先读取上次安装时路径，如果没有读取到则会手动输入或者随机路径

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_08.png" width=700>


### 7.安装Xray-core/v2ray-core

- 根据选择的内核自动安装，如果安装过则会提示是否更新或者升级

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_09.png" width=700>

### 8.配置开机自启

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_10.png" width=700>

### 9.添加cloudflare自选CNAME

- [详看此文章](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)，仅支持ws的传输方式

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_12.png" width=700>

### 10.初始化xray/v2ray配置文件

- 可自定义、随机生成uuid

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_11.png" width=700>

### 11.定时任务维护证书

- 每天凌晨一点半会检查证书的有效性，如果无效会自动更新、安装、重启。
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_11.png" width=700>

### 12.添加伪装站点

会检测上次是否安装了伪装站点，如检测不到会自动安装默认的伪装站点，如果后续不满意可以使用脚本提供的伪站更换或自定义伪站

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_14.png" width=700>

### 13.验证服务状态

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_15.png" width=700>

### 14.完成，展示账号
- 恭喜到这里就是最后一步了，接下来会检测服务是否正常，正常则会展示账号
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_16.png" width=700>

## 2.安装Hysteria

- 按照提示安装即可
- 首先必须执行[安装]后才能安装Hysteria

# 2.进阶教学

## 1.账号管理

### 1.查看订阅

- 当【查看订阅】时脚本会自动创建一个唯一的订阅地址，
- 不查看订阅时不会自动生成
- 每次账号更改时需要重新【查看订阅】才会生成新的内容
- 此操作完全在你的服务器存放。

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_17.png" width=700>

### 2.添加用户/删除用户

- 脚本支持多用户管理，如果添加用户后相应的订阅也就产生多个

## 2.更换伪站点

- 脚本提供了多个可供更换的伪站
- 建议使用404或者302重定向网站

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_18.png" width=700>

## 3.更新证书
- 如发现自动更新未正常更新，可以手动更新证书

## 4.修改CDN节点

- 脚本提供多CNAME地址，可以根据自己本地的运营商进行更换，也可以优选后手动输入
- 详情原理解析请查看[此文章](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)
- 仅支持ws的传输方式
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_19.png" width=700>

## 5.IPv6分流

- 可以指定网站只走IPv6，应用场景【1.Google人机验证 2.流媒体解锁】
- vps需支持IPv6

## 6.WARP分流

- 指定网站通过WARP分流

## 7.流媒体工具

- 任意门落地机解锁Netflix，[详情请查看此文章](https://github.com/mack-a/v2ray-agent/blob/master/documents/netflix/dokodemo-unblock_netflix.md)
- DNS解锁流媒体
- VMess+WS+TLS解锁流媒体


## 8.添加新端口
- 可以设置订阅端口以及节点端口
- 支持多个端口的添加和删除
- 不支持范围添加端口

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02_20.png" width=700>

## 9.BT下载管理

- 可以禁用服务端使用BT下载

## 10.域名黑名单

- 可以对指定的域名、类型进行屏蔽

## 11.core管理
- 支持核心的升级、回退、重启、打开、关闭
- 支持geosite和geoip的升级，文件来源[https://github.com/Loyalsoldier/v2ray-rules-dat]

## 12.安装BBR、DD脚本

- 支持BBR的安装、重新安装系统
- [这里使用的是【ylx2016】的脚本](https://github.com/ylx2016/Linux-NetSpeed)


## 13.查看日志
- 默认关闭access日志，如果想要调试则需要打开。
- 此日志会产生大量的访问记录，建议调试完后关闭。

## 14.卸载脚本

- 卸载时会删除脚本产生的数据文件以及脚本本身
- 但是不会删除安装的linux命令，比如curl、wget、nginx等
- 会将当前安装的证书备份到【/tmp/v2ray-agent-tls】，重启后此文件消失。

# 3.常见错误处理

# 4.答疑

## 1.哪一种线路是最好的？

- 没有最好的只有最适合的
- 建议自己多测试找出适合自己的

## 2.GCP挖矿或者其余警告被封实例

- GCP不建议使用代理，自从GCP改为3个月后，开始封禁大流量实例，和脚本无关。

## 3.VLESS+WS/gRPC+TLS、VMess+WS/gRPC+TLS，如果套CF，开启CF的小云朵了，那么如果把域名给换成优选IP的话 小云朵需要关闭不?

- [自选ip的情况下，不需要开启云朵](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)

# 5.脚本目录

## Xray-core

- 主目录

```
/etc/v2ray-agent/xray
```

- 配置文件目录

```
/etc/v2ray-agent/xray/conf
```

## hysteria

- 主目录

```
/etc/v2ray-agent/hysteria
```

- 配置文件目录

```
/etc/v2ray-agent/xray/conf
```

## 订阅文件
 
```
/etc/v2ray-agent/subscribe
```

## v2ray-core

- 主目录

```
/etc/v2ray-agent/v2ray
```

- 配置文件目录

```
/etc/v2ray-agent/v2ray/conf
```

## TLS证书

- 目录

```
/etc/v2ray-agent/tls
```

## Nginx

- Nginx配置文件

```
/etc/nginx/conf.d/alone.conf
```

- Nginx伪装站点目录

```
/usr/share/nginx/html
```

