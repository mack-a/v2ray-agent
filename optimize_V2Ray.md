* * *
- [1.偶尔断流](#1偶尔断流)
- [2.更换中国大陆地区CDN](#2更换中国大陆地区cdn)
  * [1.腾讯CDN[月免费10GB]](#1腾讯cdn月免费10gb)
    + [1.准备工作](#1准备工作)
    + [2.点击此链接，配置腾讯云CDN](#2点击此链接配置腾讯云cdn)
      - [1.配置域名【域名管理-添加域名】](#1配置域名域名管理-添加域名)
      - [2.配置HTTPS证书](#2配置https证书)
      - [3.回源配置](#3回源配置)
      - [4.增加域名解析CNAME值](#4增加域名解析cname值)
- [3.cloudflare CNAME自选ip优化方案](#3cloudflare-cname自选ip优化方案)
  * [1.准备工作](#1准备工作-1)
    + [1.免费的智能DNS解析](#1免费的智能dns解析)
    + [2.CloudFlare Partner平台（合作伙伴）](#2cloudflare-partner平台合作伙伴)
    + [3.CloudFlare账号](#3cloudflare账号)
  * [2.修改DNS解析【这里使用的是dnspod】](#2修改dns解析这里使用的是dnspod)
  * [3.注册dnspod) 【腾讯】](#3注册dnspod-腾讯)
  * [4.添加域名](#4添加域名)
  * [5.登入CloudFlare Partner平台](#5登入cloudflare-partner平台)
  * [6.登入dnspod](#6登入dnspod)
  * [7.验证是否添加成功](#7验证是否添加成功)
  * [8.自定义CloudFlare ip【示例】](#8自定义cloudflare-ip示例)
  * [9.原理解析](#9原理解析)
  * [10.最优ip选择](#10最优ip选择)
    + [1.联通](#1联通)
    + [2.移动](#2移动)
    + [3.hk直连](3hk直连)
    + [4.自动化脚本测试线路](#4自动化脚本测试线路)
- [4.dnsmasq 实现CNAME方式](#4dnsmasq-实现cname方式)
  * [1.准备工作](#1准备工作)
  * [2.安装](#2安装)
  * [3.修改配置文件](#3修改配置文件)
  * [4.重启dnsmasq](#4重启dnsmasq)
  * [5.测试&使用](#5测试使用)
* * *

# 1.偶尔断流
- 修改cloudflare Firwall Rules->create a Firewall rule
- - 设置Field:URI path
// 这里的/v2 是你的v2ray的path
- - 设置：value:/v2
- - Choose an action:Allow

# 2.更换中国大陆地区CDN
- 只是更换CDN其余配置内容不变
## 1.腾讯CDN[月免费10GB]
### 1.准备工作
- 1.域名【需要大陆备案】
- 2.HTTPS证书【备案的域名的证书，可以使用上方的脚本生成】
### 2.[点击此链接，配置腾讯云CDN](https://console.cloud.tencent.com/cdn/access)
#### 1.配置域名【域名管理-添加域名】
- 1.域名填写备案过的域名（你要加速的域名）
- 2.源站类型-填写自有源站
- 3.源站设置填写你的vps ip
- 4.加速类型选择流媒体点播加速
- 5.关闭过滤参数
- 6.等待部署完成
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/腾讯CDN示例图01.png' width=400/>

#### 2.配置HTTPS证书
- 1.点击配置好的域名-高级设置-HTTPS配置
- 2.证书内容-填写上方生成证书的结尾为 .crt文件里面的全部内容
- 3.私钥内容-填写上方生成证书结尾为 .key文件里面的全部内容
- 4.回源方式-协议跟随

#### 3.回源配置
- 1.点击配置好的域名-回源配置-取消掉Range回源

#### 4.增加域名解析CNAME值
- 1.我这里用的是阿里云的云解析DNS
- 2.记录类型为CNAME
- 3.主机记录则是你要配置的三级域名（国际规范）例如:test.xxx.com 这里填test
- 4.解析线路默认即可
- 5.记录值填写 腾讯CDN-点击域名-基本配置-CNAME值

<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CDN域名解析 CNAME.png' width=400/>

# 3.cloudflare CNAME自选ip优化方案
## 1.准备工作
### 1.免费的智能DNS解析
- 1.[dnspod](https://www.dnspod.cn/)
- 2.[cloudxns](https://www.cloudxns.net/)
- 3.[dns.la](https://www.dns.la/)
- 4.[dns.com](https://www.dns.com/)

### 2.CloudFlare Partner平台（合作伙伴）
- 1.[笨牛](http://cdn.bnxb.com/)
- 2.[萌精灵](https://cdn.moeelf.com/)
- 3.[自建（教程）](https://www.331u.com/461.html)

### 3.CloudFlare账号
- 使用上述第三方CloudFlare Partner时需要使用CloudFlare的账号密码
- 建议新建CloudFlare账号，与自己常用的账号区分（防止第三方平台保存密码并用于其他用途）
- 上述推荐是各大教程推荐，风险自担。也可以自行申请CloudFlare Partner并自行搭建

## 2.修改DNS解析【这里使用的是dnspod】
- 修改域名注册商中的Nameservers改为以下两个
```
f1g1ns1.dnspod.net
f1g1ns2.dnspod.net
```

## 3.注册[dnspod](https://www.dnspod.cn/) 【腾讯】
## 4.添加域名
- 添加完域名后需要等待修改的Nameserver生效

<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/dnspod添加域名.png' width=500/>

## 5.登入CloudFlare Partner平台
- 1.[萌精灵](https://cdn.moeelf.com/)【本教程使用】
- 2.添加域名
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/moeelf添加域名.png' width=400/>

- 3.添加解析记录
- 记录名---填写你要配置的二级域名【严格来说是三级域名】
- 记录类型为---CNAME
- 记录内容为回源地址（服务器的真实ip），CloudFlare只支持网址，不支持直接ip。
- CDN---开启

<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/moeelf添加DNS记录.png' width=400/>

- 记录内容中的xxx.xxx替换成自己域名的部分【例如：你的域名是www.example.com,替换成cf.test.example.com】，提交后进入管理中心会出现下图
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/moeelfDNS管理.png' width=500/>

## 6.登入[dnspod](https://www.dnspod.cn/)
- DNS管理->我的域名->添加记录
- 这里添加CNAME的意义在于防止CloudFlare翻车【CloudFlare不允许使用ip接入，只允许CNAME】
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/dnspod添加记录.png' width=500/>

## 7.验证是否添加成功
- 1.登录[CloudFlare](https://cloudflare.com)
- 2.点击域名->SSL/TLS->Edge Certificates【参考下图】如果存在则添加正确
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare SSLTLS示例图.png' width=500/>

## 8.自定义CloudFlare ip【示例】
- 新添加的记录为类型为A、线路类型是联通、记录值是CloudFlare的ip【多播】
- 这里可以添加不同的线路类型来针对不同的网络环境。
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/dnspod添加记录自定义ip.png' width=500/>

## 9.原理解析
- 使用CloudFlare DNS【默认】
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare默认解析.png' width=500/>

- 使用dnspod智能解析
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare dnspod解析.png' width=1000/>

## 10.最优ip选择
### 1.联通
```
104.23.240.0-104.23.243.254
```

### 2.移动
```
1.0.0.0-1.0.0.254
1.1.1.0-1.1.1.254
104.16.80.0-104.16.95.255
104.16.175.255-104.16.191.255
```

### 3.hk直连
- 移动用此ip段比较好
- hk gcp服务器 ping值大约在40ms左右，回源大约在300ms，但是丢包率达到40%（晚高峰）
```
104.16.0.0-104.16.79.255
104.16.96.0-104.16.175.254
104.16.192.0-104.16.207.255
```

### 4.电信
```
162.159.208.4-162.159.208.103
162.159.209.4-162.159.209.103
162.159.210.4-162.159.210.103
162.159.211.4-162.159.211.103
104.16.160.*
```

### 5.自动化脚本测试线路
- 1.利用ping命令测试（每个ip只测试一次，延迟仅供参考）
- 2.此脚本仅支持Mac、Centos【暂不支持Windows以及其余系统，后续可能会添加】
```
bash <(curl -L -s https://raw.githubusercontent.com/mack-a/v2ray-agent/master/ping_tool.sh)
```
### 6.本人使用
- 联通
```
104.23.240.5 152ms
```
- 移动
```
104.16.192.0 40ms 【丢包严重】
104.24.105.3 100ms 【不丢包】
```
- 电信
```
手里没有电信网络可用上面的ip自行尝试
```

# 4.dnsmasq 实现CNAME方式
- 更加隐私一些 只适用于CDN方式
- 使用自定义DNS服务，类似于本地配置hosts文件
- 需要配置不同的二级域名（三级域名）来进行解析

## 1.准备工作
- 需要一台中国大陆的服务器【最好，但是国外的可以用。但是会拖慢DNS解析的速度】
- 防火墙需要开放53端口

## 2.安装
- 1.Centos/RHEL
```
yum -y install dnsmasq
```

- 2.Ubuntu/Debian
```
apt-get install dnsmasq
```

## 3.修改配置文件
```
# 不使用/etc/hosts
no-hosts

# server为上游DNS服务器
# 同时查询配置的DNS服务器，哪一个快使用哪一个
all-servers
server=223.5.5.5
server=8.8.8.8

# cn域名通过114解析
server=/cn/114.114.114.114

# 一下都是实现hosts文件功能 挑选一种即可
# 添加hosts文件，用来实现类似于hosts文件的功能
# addn-hosts=/etc/dnsmasq.hosts

# 指定域名解析到特定ip中【下面填写自己的域名】
# 同理Nginx也需要修改
# 如果不是泛域名证书，还需要重新配置新加入的域名证书
address=/mobile.xxx.com/39.156.69.100
address=/unicom.xxx.com/39.156.69.101

# 泛域名解析
# address=/baidu.com/39.156.110.100
```

## 4.重启dnsmasq
```
systemctl restart dnsmasq
```
## 5.测试&使用
- 1.测试
```
# xx.xx.xx.xx为配置dnsmasq服务的ip
# mobile.xxx.com 后面为自己的域名
➜ ~ dig @xx.xx.xx.xx mobile.xxx.com

; <<>> DiG 9.10.6 <<>> @xx.xx.xx.xx mobile.xxx.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 43056
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;mobile.xxx.com.	IN	A

# 下面是结果，如果和自己配置的一样则正确
;; ANSWER SECTION:
mobile.xxx.com. 0	IN	A	198.41.214.162

;; Query time: 42 msec
;; SERVER: xx.xx.xx.xx#53(xx.xx.xx.xx)
;; WHEN: Mon Dec 23 16:30:29 CST 2019
;; MSG SIZE  rcvd: 70
```

- 2.使用
```
需要手动修改自己本地的客户端的DNS配置，各终端请自行Google
```
