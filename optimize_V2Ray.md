* * *
- [1.CloudFlare自选IP【必看】](#1cloudflare自选ip必看)
  * [1.手动自选ip【推荐】](#1手动自选ip建议使用该种方法)
  * [2.CloudFlare CNAME自选ip优化方案](#2cloudflare-cname自选ip优化方案)
  * [3.dnsmasq 实现CNAME方式【不推荐】](#3dnsmasq-实现cname方式)
- [2.更换中国大陆地区CDN](#2更换中国大陆地区cdn)
- [3.最优ip选择](#3最优ip选择)

* * *
# 1.CloudFlare自选IP【必看】
## 1.手动自选ip【建议使用该种方法】
- 1.配置简单
- 2.只需要客户端修改
- 3.保证在不自选ip的情况可以正常使用

>这里提供了国内dns分流，只需要将下方教程提到的自定义ip写成下方表格中的域名，即可根据你的运营商自动切换自选ip。这里的自选ip不是很全，如果有更加适合你的可以加入[TG群](https://t.me/v2rayAgent)提一下。【手头没电信运营商的网络，这里的ip是默认的】
- 以下测试地址为 [Japan in 8K 60fps](https://youtu.be/zCLOJ9j1k2Y)。
- vps均使用5.6 kenrel bbr-fq
- 以下结果均参考

域名|移动|移动测试|联通|电信
-|-|-|-|-
domain01.qiu4.ml|1.0.0.1|上午峰值2.3w，4k稍显卡顿、晚九点峰值1.5w，1440p较为流畅|104.20.157.0|104.27.165.3
domain02.qiu4.ml|172.64.32.1|上午峰值7.5w，稳定4k不卡顿、晚九点1.3w，流畅1080p|104.20.157.5|104.27.165.3
domain03.qiu4.ml|104.16.25.4|上午峰值4.5w，稳定4k不卡顿、晚九点2w，流畅1440p|104.20.157.10|104.16.24.4
domain04.qiu4.ml|104.17.209.9|上午峰值6w，稳定4k不卡顿、晚八点峰值4w，流畅4k，晚9点峰值1w-3w跨度较大，流畅1440p|172.67.223.77|172.67.223.77
domain05.qiu4.ml|104.16.133.229|上午峰值7w，稳定8k不卡顿、晚九点峰值1w，流畅1080p|104.20.157.10|104.16.24.4

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

## 2.CloudFlare CNAME自选ip优化方案【dns自选ip】
#### 1.准备工作
###### 1.免费的智能DNS解析
- 1.[dnspod](https://www.dnspod.cn/)【现在已经和微信绑定】
- 2.[cloudxns](https://www.cloudxns.net/)【不免费】
- 3.[dns.la](https://www.dns.la/)
- 4.[dns.com](https://www.dns.com/)

###### 2.CloudFlare Partner平台（合作伙伴）
- 1.[笨牛](http://cdn.bnxb.com/)
- 2.[萌精灵](https://cdn.moeelf.com/)
- 3.[自建（教程）](https://www.331u.com/461.html)

###### 3.CloudFlare账号
- 使用上述第三方CloudFlare Partner时需要使用CloudFlare的账号密码
- 建议新建CloudFlare账号，与自己常用的账号区分（防止第三方平台保存密码并用于其他用途）
- 上述推荐是各大教程推荐，风险自担。也可以自行申请CloudFlare Partner并自行搭建

#### 2.修改DNS解析【这里使用的是dnspod】
- 修改域名注册商中的Nameservers改为以下两个
```
f1g1ns1.dnspod.net
f1g1ns2.dnspod.net
```

#### 3.注册[dnspod](https://www.dnspod.cn/) 【腾讯】
#### 4.添加域名
- 添加完域名后需要等待修改的Nameserver生效

<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/dnspod添加域名.png' width=500/>

#### 5.登入CloudFlare Partner平台
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

#### 6.登入[dnspod](https://www.dnspod.cn/)
- DNS管理->我的域名->添加记录
- 这里添加CNAME的意义在于防止CloudFlare翻车【CloudFlare不允许使用ip接入，只允许CNAME】
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/dnspod添加记录.png' width=500/>

#### 7.验证是否添加成功
- 1.登录[CloudFlare](https://CloudFlare.com)
- 2.点击域名->SSL/TLS->Edge Certificates【参考下图】如果存在则添加正确
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare SSLTLS示例图.png' width=500/>

#### 8.自定义CloudFlare ip【示例】
- 新添加的记录为类型为A、线路类型是联通、记录值是CloudFlare的ip【多播】
- 这里可以添加不同的线路类型来针对不同的网络环境。
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/dnspod添加记录自定义ip.png' width=500/>

#### 9.原理解析
- 使用CloudFlare DNS【默认】
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare默认解析.png' width=500/>

- 使用dnspod智能解析
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare dnspod解析.png' width=1000/>

## 4.dnsmasq 实现CNAME方式
- 不建议使用，有几率会被警告，UDP 53端口在没有运营资质的情况下不可以使用
- 更加隐私一些 只适用于CDN方式
- 使用自定义DNS服务，类似于本地配置hosts文件
- 需要配置不同的二级域名（三级域名）来进行解析

#### 1.准备工作
- 需要一台中国大陆的服务器【最好，但是国外的可以用。但是会拖慢DNS解析的速度】
- 防火墙需要开放53端口

#### 2.安装
- 1.Centos/RHEL
```
yum -y install dnsmasq
```

- 2.Ubuntu/Debian
```
apt-get install dnsmasq
```

#### 3.修改配置文件
```
## 不使用/etc/hosts
no-hosts

## server为上游DNS服务器
## 同时查询配置的DNS服务器，哪一个快使用哪一个
all-servers
server=223.5.5.5
server=8.8.8.8

## cn域名通过114解析
server=/cn/114.114.114.114

## 一下都是实现hosts文件功能 挑选一种即可
## 添加hosts文件，用来实现类似于hosts文件的功能
## addn-hosts=/etc/dnsmasq.hosts

## 指定域名解析到特定ip中【下面填写自己的域名】
## 同理Nginx也需要修改
## 如果不是泛域名证书，还需要重新配置新加入的域名证书
address=/mobile.xxx.com/39.156.69.100
address=/unicom.xxx.com/39.156.69.101

## 泛域名解析
## address=/baidu.com/39.156.110.100
```

#### 4.重启dnsmasq
```
systemctl restart dnsmasq
```
#### 5.测试&使用
- 1.测试
```
## xx.xx.xx.xx为配置dnsmasq服务的ip
## mobile.xxx.com 后面为自己的域名
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

## 下面是结果，如果和自己配置的一样则正确
;; ANSWER SECTION:
mobile.xxx.com. 0	IN	A	198.41.214.162

;; Query time: 42 msec
;; SERVER: xx.xx.xx.xx##53(xx.xx.xx.xx)
;; WHEN: Mon Dec 23 16:30:29 CST 2019
;; MSG SIZE  rcvd: 70
```

- 2.使用
```
需要手动修改自己本地的客户端的DNS配置，各终端请自行Google
```

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

# 3.最优ip选择
## 1.移动
### 1.推荐节点
- hk
```
1.0.0.0-1.0.0.254
1.1.1.0-1.1.1.254
172.64.32.0-172.64.32.254
172.64.0.0-172.64.0.254
104.16.25.4
141.101.115.0-141.101.115.254
```
- 香港cloudflare1-100g.hkix.net
```
104.16.80.0-95.255
104.16.175.255-104.16.191.255
# IPOWER.COM endurance.com专用
66.235.200.0-254
```
- shopify.com专用
```
23.227.63.0-23.227.63.254
104.16.0.0-104.16.79.255
104.16.96.0-104.16.175.254
104.16.192.0-104.16.207.255
```
- 欧洲
```
162.158.133.0-162.158.133.254
```
- 新加坡
```
104.18.48.0-104.18.63.255
104.24.112.0-104.24.127.255
104.27.128.0-104.27.143.255
104.28.0.0-104.28.15.255
```
- 圣何塞 cogentco.com
```
104.28.16.0-104.28.31.255
104.27.144.0-104.27.243.254
104.23.240.0-104.23.243.254
```

## 2.联通
```
104.16.160.0-104.16.160.254
104.23.240.0-104.23.243.254
108.162.236.0-108.162.236.254
```

- 日本
```
104.20.157.0-104.20.157.254
```

- 伦敦
```
172.64.19.16
```

## 3.电信
```
104.16.160.0-104.16.160.254
```

- 百度合作
```
162.159.208.4-162.159.208.103
162.159.209.4-162.159.209.103
162.159.210.4-162.159.210.103
162.159.211.4-162.159.211.103
```

- 美国
```
# 洛杉矶
104.16.160.1-104.16.160.254
# 旧金山
172.64.0.0-172.64.0.254
# 圣何塞
104.16.160.0-104.16.160.254
# 亚特兰大
108.162.236.0-108.162.236.254
```

- 欧洲
```
104.23.240.0-104.23.240.254
```

- 新加坡
```
172.64.32.0-172.64.32.254
```

## 5.自动化脚本测试线路【开发中】

## 6.本人使用
- 移动
```
1.0.0.1
172.64.32.1
104.16.25.4
```
