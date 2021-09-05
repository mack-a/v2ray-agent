> 脚本功能介绍

# 目录

- [1.快速开始](#1快速开始)
- [2.进阶教学](#2进阶教学)
- [3.常见错误处理](#3常见错误处理)
- [4.答疑](#4答疑)

# 1.快速开始

## 1.安装/重新安装/任意组合安装

- 安装/重新安装

此操作会安装根据选择不同内核进行全部协议的安装【VLESS、VMess、trojan】

- 任意组合安装

必选VLESS TCP，其余的可以任意组合

### 1.选择内核

- Xray-core
- v2ray-core

此版本不支持xtls

- v2ray-core[XTLS]

最后一个支持xtls的v2ray-core版本

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/01.png" width=700>

### 2.检测域名的ip

这里会先检测IPv4后检测IPv6

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/02.png" width=700>

### 3.申请TLS证书

1.首次签发证书会自动签发。 2.如果使用acme.sh申请过证书，这里会直接使用而不会重复签发，如果在【是否重新安装】选择y，则会把证书重新安装一遍不是重新签发。

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/03.png" width=700>

### 4.生成随机路径

这里会先读取上次安装时路径，如果没有读取到则会手动输入或者随机路径

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/04.png" width=700>

### 5.安装Xray/v2ray

根据选择的内核进行安装，如果安装过则会提示是否更新或者升级

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/05.png" width=700>

### 6.安装Trojan-Go

如果安装时选择安装trojan协议或者全部安装，则这里会自动安装trojan-go核心，与上面相同如果安装过则会提示是否更新或者升级。

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/06.png" width=700>

### 7.添加智能DNS智能解析

如果选择y，则查看帐号的时候 address是优选后的域名解析，则会出现address是脚本提供的域名，伪装域名或SNI或peer则是个人的域名，详情原理解析请查看[此文章](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)，仅支持ws的传输方式

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/07.png" width=700>

### 8.初始化xray/v2ray配置文件

这里会提供自定义uuid的入口，如果不提供自定义的uuid则会尝试读取上次安装时的uuid，如果以上都没读取到会随机生成uuid。

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/08.png" width=700>

### 9.定时任务维护证书

每天凌晨一点半会检查证书的有效性，如果无效会自动更新、安装、重启。

### 10.添加伪装站点

会检测上次是否安装了伪装站点，如检测不到会自动安装默认的伪装站点，如果后续不满意可以使用脚本提供的伪站更换或自定义伪站

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/08.png" width=700>

### 11.完成

恭喜到这里就是最后一步了，接下来会检测服务是否正常，正常则会展示帐号

# 2.进阶教学

## 1.账号管理

### 1.查看订阅

当【查看订阅】时脚本会自动创建一个唯一的订阅地址，不【查看订阅】时不会自动生成。 每次帐号更改时需要重新【查看订阅】才会生成新的内容。 此操作完全在你的服务器存放，不需要担心是否泄漏。

### 2.添加用户/删除用户

脚本支持多用户管理，如果添加用户后相应的订阅也就产生多个

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/11.png" width=700>

### 3.更换伪站点

脚本提供了多个可供更换的伪站

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/10.png" width=700>

### 4.修改CDN节点

脚本提供多个优选ip的CNAME，可以根据自己本地的运营商进行更换，详情原理解析请查看[此文章](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)，仅支持ws的传输方式

### 5.IPv6分流

可以指定网站只走IPv6，应用场景【1.Google人机验证 2.流媒体解锁】

### 6.流媒体工具

- Netflix检测，检测vps是否支持Netflix解锁，脚本内置的可能不准确。
- 任意门落地机解锁Netflix

[详情请查看此文章](https://github.com/mack-a/v2ray-agent/blob/master/documents/netflix/dokodemo-unblock_netflix.md)

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/12.png" width=700>

- DNS解锁流媒体
一般购买的DNS流媒体解锁支持解锁的流媒体相对较多，支持解锁以下网站
```
netflix、bahamut、hulu、hbo、disney、bbc、4chan、fox、abema、dmm、niconico、pixiv、bilibili、viu
```

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/13.png" width=700>


### 7.添加新端口
不影响443端口的使用，查看帐号时仅展示443端口的帐号，支持多个端口的添加和删除。

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/14.png" width=700>

### 8.core管理
支持核心的升级、回退、重启、打开、关闭，仅限xray、v2ray

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/15.png" width=700>


### 9.安装BBR、DD脚本
支持BBR的安装、支持重新安装系统，[这里使用的是【ylx2016】的脚本](https://github.com/ylx2016/Linux-NetSpeed)

### 10.查看日志
默认关闭access日志，如果想要调试则需要打开。此日志会产生大量的访问记录，建议调试完后关闭。

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/16.png" width=700>

### 11.卸载脚本

卸载脚本时会删除脚本产生的数据文件以及脚本本身，但是不会删除安装的linux命令，比如curl、wget、nginx等，会将当前安装的证书备份到【/tmp/v2ray-agent-tls】，重启后此文件消失。

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/how_to_use/17.png" width=700>

# 3.常见错误处理

## 1.下载脚本失败

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/shell_error_01.jpg" width=700>

- 需要手动更改dns

```
# 文件位置
/etc/resolv.conf

# 文件内容
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
```

## 2.生成证书失败

- 请更换Debian或者Ubuntu

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/shell_error_02.jpg" width=700>

## 3.Debian8启动nginx失败

### 解决方法一

- 手动删除add_header选项

```
vim /etc/nginx/conf.d/alone.conf
# 删除下方代码
add_header Strict-Transport-Security "max-age=63072000" always;
```

## 4.低版本升级高版本后无法启动核心
- 1.先分别执行下方命令
- 2.使用脚本中[13.core管理]启动即可
```
systemctl stop trojan-go
systemctl disable trojan-go
```
# 4.答疑

## 1.哪一种线路是最好的？

- 没有最好的只有最适合的
- 建议自己多测试找出适合自己的


## 2.流控[xtls-rprx-direct、xtls-rprx-splice]答疑

- xtls-rprx-direct为服务端，xtls-rprx-splice为客户端，并且仅支持linux[路由器、软路由]、android

## 3.GCP挖矿或者其余警告被封实例

- GCP不建议使用代理，自从GCP改为3个月后，开始封禁大流量实例，和脚本无关。

## 4.VLESS+WS+TLS、VMess+WS+TLS，如果套CF，开启CF的小云朵了，那么如果把域名给换成优选IP的话 小云朵需要关闭不?

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

## v2ray-core

- 主目录

```
/etc/v2ray-agent/v2ray
```

- 配置文件目录

```
/etc/v2ray-agent/v2ray/conf
```

## Trojan

- 目录

```
/etc/v2ray-agent/trojan
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

