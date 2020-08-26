# 目录
- [技能点列表](#技能点列表)
- [一键脚本](#一键脚本)
  * [1.自动模式](#1自动模式)
  * [2.手动模式](#2手动模式)
- [1.准备工作](#1准备工作)
  * [1.注册cloudflare](#1注册cloudflare)
  * [2.注册godaddy并购买域名](#2注册godaddy并购买域名)
  * [3.修改godaddy域名的DNS解析](#3修改godaddy域名的dns解析)
    + [1.登录cloudflare，添加域名](#1登录cloudflare添加域名)
    + [2.选择套餐](#2选择套餐)
    + [3.根据提示修改godaddy的dns解析](#3根据提示修改godaddy的dns解析)
  * [4.增加cloudflare域名解析](#4增加cloudflare域名解析)
  * [5.修改godaddy SSL/TLS](#5修改godaddy-ssltls)
- [2.vps配置Nginx](#2vps配置nginx)
  * [1.安装Nginx](#1安装Nginx)
  * [2.nginx配置文件](#2nginx配置文件)
- [3.配置v2ray](#3配置v2ray)
  * [1.安装v2ray](#1安装v2ray)
  * [2.v2ray配置文件](#v2ray配置文件)
  * [3.启动v2ray](#3启动v2ray)
- [4.客户端](#4客户端)
  * [1.MacOS](#1macos)
  * [2.windows](#2windows)


# 技能点列表
- [bandwagonhost[Ubuntu、Centos、Debian]链接一](https://bandwagonhost.com)
- [bandwagonhost[Ubuntu、Centos、Debian]链接二](https://bwh1.net)【境外vps或者其他vps厂商】
- [freenom](https://freenom.com/)【免费域名】
- [godaddy](https://www.godaddy.com/)【域名厂商】
- [cloudflare](cloudflare.com)【CDN】
- [letsencrypt](https://letsencrypt.org/)【HTTPS】
- [Nginx](https://www.nginx.com/)【反向代理】
- [V2Ray](v2ray.com)【代理工具】

# 1.准备工作
## 1.注册[cloudflare](cloudflare.com)
## 2.注册[godaddy](https://www.godaddy.com/)并购买域名或者使用免费域名[freenom](https://freenom.com/)
- 这里使用godaddy作为示例
- 域名可选择xyz结尾的国际域名，可采用多字符乱码的方式组合域名，(比如wk1c.xyz)首年大概8RMB左右，第二年可以直接买一个新的。

## 3.修改godaddy域名的DNS解析
### 1.登录cloudflare，添加域名
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare.png" width=400>

### 2.选择套餐
- 如果仅仅只享受科学上网功能，选择free即可
- 如果需要更好的网络环境、更快的速度，可选择相应的套餐
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare_plan.png" width=400>

### 3.根据提示修改godaddy的dns解析
- cloudflare提示界面
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare_dns.png" width=400>

- godaddy DNS管理，根据上面的cloudflare提示界面修改为相应的dns
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/godayddy_dns.png" width=400>

## 4.增加cloudflare域名解析
- 添加域名解析(记录)，可以选择二级域名，这样就可以一个月解析到不同的服务器，name填写你要解析的二级域名的host部分，比如ls.example.com 只填写ls即可
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare_record_dns.png" width=400>

## 5.修改godaddy SSL/TLS
- 如果vps选择使用https，需要把类型修改为Flexible
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare_tls_Flexible.png" width=400>

# 2.vps配置Nginx
## 1.安装Nginx
```
yum install nginx
```
## 2.nginx配置文件

- 1.下载配置文件并替换默认文件
```
cd /etc/nginx&&rm -rf /etc/nginx/nginx.conf&&wget https://raw.githubusercontent.com/mack-a/v2ray-agent/master/config/nginx_Flexible.conf&&mv /etc/nginx/nginx_Flexible.conf /etc/nginx/nginx.conf
# 如果缺少wget 则执行下面的命令，然后重复上面的命令
yum install wget
```
- 将下载好的文件中关于ls.xxx.xyz的内容都替换成你的二级域名

# 3.配置v2ray
## 1.安装v2ray

```
bash <(curl -L -s https://install.direct/go.sh)
```

## 2.v2ray配置文件

- 下载config_ws_tls.json
```
cd&&wget https://raw.githubusercontent.com/mack-a/v2ray-agent/master/config/config_ws_tls.json
```

- 配置文件的id可以自己生成一个新的，替换即可
```
/usr/bin/v2ray/v2ctl  uuid
```

## 3.启动v2ray
```
/usr/bin/v2ray/v2ray -config ./config_ws_tls.json&
```

# 4.客户端
## 1.MacOS
- 下载V2RayU[点我下载](https://github.com/yanue/V2rayU/releases/download/1.4.1/V2rayU.dmg)
- 下载后打开，服务器设置，修改address即可
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/v2rayU_服务器配置.png" width=400>

- pac设置，添加下面的链接并选择使用Pac模式，即可
```
https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
```

## 2.windows
- 下载v2rayN[点我下载](https://github.com/2dust/v2rayN/releases/download/2.44/v2rayN.zip)
- 使用方法 [点我查看](https://github.com/233boy/v2ray/wiki/V2RayN%E4%BD%BF%E7%94%A8%E6%95%99%E7%A8%8B)

## 3.Android
- [v2rayNG](https://github.com/2dust/v2rayNG/releases)

## 4.ios【需要自行购买或者使用共享账号安装】
- Quantumult【推荐使用】
- Shadowrocket
